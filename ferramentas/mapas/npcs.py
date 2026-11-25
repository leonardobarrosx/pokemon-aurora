"""Coloca os NPCs dos jogos de GBA nos mapas importados (Kanto e Hoenn).

Lê os object_events de cada map.json, converte o sprite de cada NPC para o
formato de personagem de Aurora (4 colunas x 4 direções, células de 64 px)
e grava a lista de NPCs no JSON do cliente. No JSON do servidor a célula do
NPC vira parede, para ninguém atravessar.

Uso: python3 npcs.py kanto | hoenn   (rodar depois de region.py)
"""
import json, os, re, sys
from PIL import Image
from gba import GAMES

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
CELL = 32
PREFIX = {"kanto": ("frlg", "kt_"), "hoenn": ("rse", "hn_")}
# Itens no chão, pedras e árvores cortáveis já aparecem como objetos; ficam de fora
# os que não são pessoas nem Pokémon.
SKIP = ("ITEM_BALL", "CUT_TREE", "PUSHABLE_BOULDER", "ROCK_SMASH_ROCK", "BREAKABLE_ROCK", "TRUCK", "BERRY_TREE",
        "INVISIBLE", "VAR_", "BIRTH_ISLAND", "MOVING_BOX", "CABLE_CAR", "SS_ANNE", "FOSSIL", "SEAGALLOP", "STATUE",
        "SUBMARINE", "APRICORN", "BOAT", "MYSTERY_EVENT", "CUSHION", "DOLL", "CABLE", "MART_COUNTER", "BALL_CUSHION")
FACING = {"DOWN": 0, "SOUTH": 0, "LEFT": 1, "WEST": 1, "RIGHT": 2, "EAST": 2, "UP": 3, "NORTH": 3}


def sprite_table(root):
    """OBJ_EVENT_GFX_X -> (caminho do png, largura, altura do quadro)."""
    base = os.path.join(root, "src/data/object_events")
    ptr = dict(re.findall(r"\[(OBJ_EVENT_GFX_\w+)\]\s*=\s*&(gObjectEventGraphicsInfo_\w+)",
                          open(os.path.join(base, "object_event_graphics_info_pointers.h")).read()))
    info, ptag = {}, {}
    for m in re.finditer(r"(gObjectEventGraphicsInfo_\w+)\s*=\s*\{(.*?)\};", open(os.path.join(base, "object_event_graphics_info.h")).read(), re.S):
        body = m.group(2)
        w = re.search(r"\.width\s*=\s*(\d+)", body); h = re.search(r"\.height\s*=\s*(\d+)", body)
        img = re.search(r"\.images\s*=\s*(\w+)", body)
        tag = re.search(r"\.paletteTag\s*=\s*(\w+)", body)
        ptag[m.group(1)] = tag.group(1) if tag else None
        if not (w and h and img):  # Emerald antigo usa inicialização posicional
            parts = [p.strip() for p in body.split(",")]
            try:
                w, h, img = int(parts[4]), int(parts[5]), parts[14]
            except (IndexError, ValueError):
                continue
            info[m.group(1)] = (w, h, img)
        else:
            info[m.group(1)] = (int(w.group(1)), int(h.group(1)), img.group(1))
    pics = {}
    for m in re.finditer(r"(sPicTable_\w+)\[\]\s*=\s*\{\s*(?:overworld_frame|obj_frame_tiles)\((\w+)", open(os.path.join(base, "object_event_pic_tables.h")).read()):
        pics[m.group(1)] = m.group(2)
    paths = dict(re.findall(r"(gObjectEventPic_\w+)\[\]\s*=\s*INCBIN_U(?:16|32)\(\"([^\"]+)\.4bpp\"\)",
                            open(os.path.join(base, "object_event_graphics.h")).read()))
    # Paleta de cada NPC: tag -> símbolo -> arquivo .pal (o png traz uma paleta genérica).
    pal_sym = {}
    mov = os.path.join(root, "src/event_object_movement.c")
    if os.path.exists(mov):
        pal_sym = {t: s for s, t in re.findall(r"\{\s*(gObjectEventPal_\w+),\s*(OBJ_EVENT_PAL_TAG_\w+)\s*\}", open(mov).read())}
    pal_path = dict(re.findall(r"(gObjectEventPal_\w+)\[\]\s*=\s*INCBIN_U16\(\"([^\"]+)\.gbapal\"\)",
                               open(os.path.join(base, "object_event_graphics.h")).read()))
    out = {}
    for gfx, inf in ptr.items():
        if inf not in info:
            continue
        w, h, table = info[inf]
        pic = pics.get(table)
        if pic in paths:
            pal = pal_path.get(pal_sym.get(ptag.get(inf)))
            pal = os.path.join(root, pal + ".pal") if pal else None
            out[gfx] = (os.path.join(root, paths[pic] + ".png"), w, h, pal if pal and os.path.exists(pal) else None)
    return out


def jasc(path):
    lines = open(path).read().split("\n")
    out = []
    for l in lines[3:3 + int(lines[2])]:
        out += [int(v) for v in l.split()]
    return out


def sheet(path, w, h, dest, palfile=None):
    """Converte a tira de quadros do GBA na folha 4x4 de Aurora (64 px)."""
    src = Image.open(path)
    if palfile and src.mode == "P":
        src.putpalette(jasc(palfile))
    pal = src.getpalette()
    src = src.convert("RGBA")
    if pal:  # cor 0 da paleta é transparente
        key = tuple(pal[:3])
        px = src.load()
        for y in range(src.height):
            for x in range(src.width):
                if px[x, y][:3] == key:
                    px[x, y] = (0, 0, 0, 0)
    frames = [src.crop((i * w, 0, i * w + w, h)) for i in range(max(1, src.width // w))]
    n = len(frames)
    get = lambda i: frames[i] if i < n else frames[0]
    flip = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    # Quadros padrão: 0 sul, 1 norte, 2 oeste, 3-4 andando sul, 5-6 norte, 7-8 oeste.
    rows = [[get(0), get(3), get(0), get(4)],
            [get(2), get(7), get(2), get(8)],
            [flip(get(2)), flip(get(7)), flip(get(2)), flip(get(8))],
            [get(1), get(5), get(1), get(6)]]
    if n < 9:
        rows = [[get(0)] * 4, [get(2 if n > 2 else 0)] * 4, [flip(get(2 if n > 2 else 0))] * 4, [get(1 if n > 1 else 0)] * 4]
    cell = 64
    out = Image.new("RGBA", (cell * 4, cell * 4))
    for r, row in enumerate(rows):
        for c, fr in enumerate(row):
            fr = fr.resize((w * 2, h * 2), Image.NEAREST)
            out.paste(fr, (c * cell + (cell - w * 2) // 2, r * cell + cell - h * 2 if h * 2 <= cell else r * cell), fr)
    out.save(dest)


def main(region):
    game, prefix = PREFIX[region]
    root = GAMES[game]["root"]
    table = sprite_table(root)
    cdir = os.path.join(ROOT, "client/assets/maps"); sdir = os.path.join(ROOT, "server/maps")
    chars = os.path.join(ROOT, "client/assets/characters/gba"); os.makedirs(chars, exist_ok=True)
    made, total, missing = set(), 0, set()
    for folder in os.listdir(os.path.join(root, "data/maps")):
        p = os.path.join(root, "data/maps", folder, "map.json")
        if not os.path.exists(p):
            continue
        d = json.load(open(p))
        area = prefix + d["id"].replace("MAP_", "").lower()
        cpath = os.path.join(cdir, area + ".json"); spath = os.path.join(sdir, area + ".json")
        if not os.path.exists(cpath):
            continue
        client = json.load(open(cpath)); server = json.load(open(spath))
        cells = list(server["cells"])
        w = server["w"]
        npcs = []
        for o in d.get("object_events") or []:
            gfx = o.get("graphics_id", "")
            if o.get("type", "object") != "object" or any(s in gfx for s in SKIP):
                continue
            if gfx not in table:
                missing.add(gfx)
                continue
            path, fw, fh, palfile = table[gfx]
            if not os.path.exists(path):
                missing.add(gfx)
                continue
            name = "%s_%s" % (game, gfx.replace("OBJ_EVENT_GFX_", "").lower())
            if name not in made:
                sheet(path, fw, fh, os.path.join(chars, name + ".png"), palfile)
                made.add(name)
            x, y = int(o["x"]), int(o["y"])
            mv = o.get("movement_type", "")
            facing = next((v for k, v in FACING.items() if mv.endswith(k)), 0)
            npcs.append({"x": (x + .5) * CELL, "y": (y + .9) * CELL, "sprite": "gba/" + name, "name": "", "facing": facing,
                         "trainer": o.get("trainer_type", "TRAINER_TYPE_NONE") not in ("TRAINER_TYPE_NONE", "0")})
            if 0 <= y * w + x < len(cells):
                cells[y * w + x] = "#"
        client["npcs"] = npcs
        server["cells"] = "".join(cells)
        server["npcs"] = [[n["x"], n["y"]] for n in npcs]
        json.dump(client, open(cpath, "w"), separators=(",", ":"))
        json.dump(server, open(spath, "w"), separators=(",", ":"))
        total += len(npcs)
    print(region, total, "NPCs,", len(made), "sprites; sem sprite:", sorted(missing)[:12])


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "kanto")
