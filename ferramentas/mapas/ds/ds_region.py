"""Importa Johto (pret/pokeheartgold) para Aurora.

Os mapas de DS são modelos 3D. Cada chunk (32x32 células) é desenhado em
projeção oblíqua (ver raster.py) e salvo como imagem, com uma segunda imagem
só com o que fica por cima do jogador (copas, telhados). A colisão vem das
permissões de cada chunk.

O mundo aberto vira uma área só (jt_johto), com zonas por chunk para nome e
encontros. Cada interior (casas, Centros, ginásios, cavernas) vira uma área
própria, recortada no tamanho do cômodo.

Saídas: client/assets/maps/<area>.json, client/assets/maps/jt/<area>/*.png,
        server/maps/<area>.json
"""
import json, os, re, struct, sys
from collections import deque, Counter
import numpy as np
from PIL import Image
from narc import narc
from raster import Canvas, K
from scene import Game

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
if len(sys.argv) > 2:
    ROOT = sys.argv[2]
HG = os.environ.get("HG_ROOT", "/home/claude/ext/pokeheartgold")
A = HG + "/files/a/0/"
CELL = 32
CH = 512  # unidades por chunk (32 células de 16)
PREFIX = "jt_"
WORLD = "jt_johto"

SPECIES = {"BULBASAUR": 1, "IVYSAUR": 2, "CHARMANDER": 4, "CHARMELEON": 5, "SQUIRTLE": 7, "WARTORTLE": 8,
           "PIDGEY": 16, "RATTATA": 19, "PIKACHU": 25, "RAICHU": 26, "ZUBAT": 41, "GEODUDE": 74, "GENGAR": 94,
           "ONIX": 95, "MAGIKARP": 129, "GYARADOS": 130, "LAPRAS": 131, "EEVEE": 133, "VAPOREON": 134,
           "JOLTEON": 135, "FLAREON": 136, "MEW": 151, "UMBREON": 197}
TALL = {0x02, 0x03}
WATER = {0x10, 0x11, 0x13, 0x15, 0x16, 0x19, 0x1A, 0x22}
JUMP = {0x38: ">", 0x39: "<", 0x3A: "^", 0x3B: "v"}
SKIP_TEX = ("wind",)
NAMES = {"NEW_BARK": "New Bark Town", "CHERRYGROVE": "Cherrygrove City", "VIOLET": "Violet City", "AZALEA": "Azalea Town",
         "GOLDENROD": "Goldenrod City", "ECRUTEAK": "Ecruteak City", "OLIVINE": "Olivine City", "CIANWOOD": "Cianwood City",
         "MAHOGANY": "Mahogany Town", "BLACKTHORN": "Blackthorn City", "LAKE_OF_RAGE": "Lake of Rage",
         "RUINS_OF_ALPH": "Ruins of Alph", "MOUNT_SILVER": "Mt. Silver", "SAFARI_ZONE_GATE": "Safari Zone Gate"}
WORDS = [("POKECENTER", "Centro Pokémon"), ("POKEMON_CENTER", "Centro Pokémon"), ("MART", "Loja"), ("GYM", "Ginásio"),
         ("HOUSE", "Casa"), ("ROUTE", "Rota"), ("PLAYER", "do Jogador"), ("RIVAL", "do Rival"), ("TOWER", "Torre"),
         ("CAVE", "Caverna"), ("FOREST", "Floresta"), ("LAB", "Laboratório"), ("ELMS", "Elm"), ("SOUTHWEST", "Sudoeste"),
         ("NORTHEAST", "Nordeste"), ("NORTHWEST", "Noroeste"), ("SOUTHEAST", "Sudeste"), ("NORTH", "Norte"),
         ("SOUTH", "Sul"), ("EAST", "Leste"), ("WEST", "Oeste")]


def nice(name):
    base = name.replace("MAP_", "")
    for k, v in NAMES.items():
        if base.startswith(k):
            rest = base[len(k):].strip("_")
            base = v + (" " + rest if rest else "")
            break
    out = []
    for w in base.replace("_", " ").split():
        out.append(dict(WORDS).get(w, w if not w.isupper() else w.capitalize()))
    return " ".join(out).replace(" 1 F", " 1F").replace("Rota ", "Rota ")


def load_headers():
    ids = {}
    for l in open(HG + "/include/constants/maps.h"):
        m = re.match(r"#define (MAP_\w+)\s+(\d+)", l)
        if m:
            ids[m.group(1)] = int(m.group(2))
    txt = open(HG + "/src/data/map_headers.h").read()
    hdr = {}
    for m in re.finditer(r"\[(MAP_\w+)\]\s*=\s*\{(.*?)\n\s*\},", txt, re.S):
        f = dict(re.findall(r"\.(\w+)\s*=\s*([^,]+),", m.group(2)))
        f["name"] = m.group(1)
        hdr[ids[m.group(1)]] = f
    return ids, hdr


def matrix_file(mid):
    name = mid.replace("NARC_map_matrix_", "").replace("_bin", ".bin")
    return HG + "/files/fielddata/mapmatrix/map_matrix/" + name


def read_matrix(path):
    mm = open(path, "rb").read()
    w, h, hh, ha, nl = mm[:5]
    o = 5 + nl
    hdrs = None
    if hh:
        hdrs = list(struct.unpack_from("<%dH" % (w * h), mm, o)); o += 2 * w * h
    if ha:
        o += w * h
    land = list(struct.unpack_from("<%dH" % (w * h), mm, o))
    return w, h, hdrs, land


def events(hd):
    name = hd["eventsBank"].replace("NARC_zone_event_", "").replace("_bin", ".json")
    p = HG + "/files/fielddata/eventdata/zone_event/" + name
    return json.load(open(p)) if os.path.exists(p) else {}


def species_names(mon):
    out, stack = [], [mon.get("species", "")]
    while stack:
        v = stack.pop()
        if isinstance(v, dict):
            stack += list(v.values())
        elif isinstance(v, list):
            stack += v
        elif isinstance(v, str):
            out.append(v)
    return out


def pick(mons):
    return sorted({SPECIES[n.replace("SPECIES_", "")] for m in mons for n in species_names(m) if n.replace("SPECIES_", "") in SPECIES})


def encounters():
    out = {}
    for e in json.load(open(HG + "/files/fielddata/encountdata/gs_enc_data.json"))["encounters"]:
        land = pick(e.get("land", {}).get("mons", []))
        surf = pick(e.get("surf", {}).get("mons", []))
        out["ENCDATA_" + e["map"]] = (land, surf)
    return out


def cell_code(v):
    b = v & 0xFF
    if b in JUMP:
        return JUMP[b]
    if b in WATER:
        return "~"
    if v & 0x8000:
        return "#"
    if b in TALL:
        return '"'
    return "."


def surfaces(g, li, with_objects):
    for m, tris in g.land_model(li):
        if m["tex"] and "tree" in m["tex"]:
            continue
        for t in tris:
            yield [v[0] for v in t]
    if not with_objects:
        return
    import math
    for bid, pos, rot, scale in g.objects(li):
        if bid >= len(g.bmodels):
            continue
        for m, tris in g.building(bid)[0]:
            for t in tris:
                yield [(v[0][0] * scale[0] + pos[0], v[0][1] * scale[1] + pos[1], v[0][2] * scale[2] + pos[2]) for v in t]


def heights(g, chunks, w, h, with_objects=False):
    """Altura do chão em cada célula (para desenhar o jogador no relevo)."""
    hm = np.zeros((h, w), np.float32)
    have = np.zeros((h, w), bool)
    for (cx, cy), (li, area) in chunks.items():
        if True:
            for pts in surfaces(g, li, with_objects):
                p = np.array(pts, np.float64)
                n = np.cross(p[1] - p[0], p[2] - p[0])
                if abs(n[1]) < .5 * np.linalg.norm(n) + 1e-9:
                    continue
                xs = (p[:, 0] + 256) / 16 + cx * 32 - .5
                zs = (p[:, 2] + 256) / 16 + cy * 32 - .5
                x0, x1 = max(int(np.ceil(xs.min())), 0), min(int(np.floor(xs.max())), w - 1)
                z0, z1 = max(int(np.ceil(zs.min())), 0), min(int(np.floor(zs.max())), h - 1)
                if x0 > x1 or z0 > z1:
                    continue
                gx, gz = np.meshgrid(np.arange(x0, x1 + 1), np.arange(z0, z1 + 1))
                (ax, az), (bx, bz), (qx, qz) = zip(xs, zs)
                den = (bz - qz) * (ax - qx) + (qx - bx) * (az - qz)
                if abs(den) < 1e-9:
                    continue
                w0 = ((bz - qz) * (gx - qx) + (qx - bx) * (gz - qz)) / den
                w1 = ((qz - az) * (gx - qx) + (ax - qx) * (gz - qz)) / den
                w2 = 1 - w0 - w1
                inside = (w0 >= -1e-3) & (w1 >= -1e-3) & (w2 >= -1e-3)
                y = w0 * p[0, 1] + w1 * p[1, 1] + w2 * p[2, 1]
                reg = hm[z0:z1 + 1, x0:x1 + 1]; hv = have[z0:z1 + 1, x0:x1 + 1]
                upd = inside & (~hv | ((y < reg) if with_objects else (y > reg)))
                reg[upd] = y[upd]; hv[upd] = True
    return hm


def next_walk(walk):
    """nw[z, x] = primeira linha andável ao sul de z (ou -1)."""
    h, w = walk.shape
    nw = np.full((h, w), -1, np.int32)
    cur = np.full(w, -1, np.int32)
    for z in range(h - 1, -1, -1):
        nw[z] = cur
        cur = np.where(walk[z], z, cur)
    return nw


def occluders(cv, c, r, grid):
    """Pixels que ficam por cima dos personagens.

    Um pixel elevado (acima do chão da própria célula) cobre quem está atrás
    dele, mas não pode cobrir a cabeça de quem está na primeira célula livre à
    frente. Assim telhados, copas e balcões escondem quem passa atrás sem
    tapar quem está na frente."""
    walk, hm, nw = grid
    H, W = walk.shape
    py, px = np.nonzero(cv.rgba[..., 3] > 0)
    if not len(px):
        return cv.up
    s = r * CH + py + .5
    cx = np.clip((c * CH + px) // 16, 0, W - 1)
    zr = np.clip(np.floor(cv.zw[py, px] / 16).astype(int), 0, H - 1)
    zf = nw[zr, cx]
    ok = zf >= 0
    # Chão de referência: o da célula livre à frente (o das paredes não é confiável).
    floor = np.where(ok, hm[np.maximum(zf, 0), cx], hm[zr, cx])
    floor = np.where(walk[zr, cx], np.minimum(floor, hm[zr, cx]), floor)
    elevated = cv.top[py, px] - floor >= 10
    foot = np.where(ok, (zf + .7) * 16 - K * hm[np.maximum(zf, 0), cx], 1e9)
    up = elevated & (s < foot - 30)
    out = np.zeros(cv.up.shape, bool)
    out[py, px] = up
    return out


def grid_of(cells, hm, w, h):
    walk = np.array([ch in '."' for ch in cells], bool).reshape(h, w)
    return walk, hm, next_walk(walk)


def render_area(g, chunks, cols, rows, outdir, crop=False, grid=None):
    """Desenha os chunks {(cx,cy): (land, area)} em imagens de 512 px.

    Linha -1 recebe o que sobe além do topo. Devolve a lista de imagens e,
    com crop, o recorte usado (x0, y0, x1, y1) em pixels do mundo DS."""
    os.makedirs(outdir, exist_ok=True)
    made = []
    for r in range(-1, rows):
        for c in range(cols):
            todo = [(cx, cy) for cx in (c - 1, c, c + 1) for cy in (r, r + 1, r + 2) if (cx, cy) in chunks]
            if not todo:
                continue
            cv = Canvas(CH, CH, c * CH, r * CH)
            for cx, cy in sorted(todo, key=lambda k: k[1]):
                li, area = chunks[(cx, cy)]
                g.draw_chunk(cv, li, area, cx * CH + 256, cy * CH + 256)
            cv.flush()
            if not cv.rgba[..., 3].any():
                continue
            if grid is not None:
                cv.up = occluders(cv, c, r, grid)
            made.append((c, r, cv))
    if crop:
        # Interiores: junta tudo numa imagem só, recortada no que foi desenhado.
        full = np.zeros(((rows + 1) * CH, cols * CH, 4), np.uint8)
        up = np.zeros(full.shape[:2], bool)
        for c, r, cv in made:
            full[(r + 1) * CH:(r + 2) * CH, c * CH:(c + 1) * CH] = cv.rgba
            up[(r + 1) * CH:(r + 2) * CH, c * CH:(c + 1) * CH] = cv.up
        ys, xs = np.nonzero(full[..., 3])
        if not len(xs):
            return None
        x0, x1 = xs.min() // 16 * 16, (xs.max() // 16 + 1) * 16
        y0, y1 = ys.min() // 16 * 16, (ys.max() // 16 + 1) * 16
        img = full[y0:y1, x0:x1]
        save(img, os.path.join(outdir, "0_0.png"))
        a = img.copy(); a[~up[y0:y1, x0:x1]] = 0
        if a[..., 3].any():
            save(a, os.path.join(outdir, "0_0_up.png"))
        return (int(x0), int(y0) - CH, int(x1), int(y1) - CH)
    for c, r, cv in made:
        save(cv.rgba, os.path.join(outdir, "%d_%d.png" % (c, r)))
        a = cv.rgba.copy(); a[~cv.up] = 0
        if a[..., 3].any():
            save(a, os.path.join(outdir, "%d_%d_up.png" % (c, r)))
    return [(c, r) for c, r, _ in made]


def save(rgba, path):
    im = Image.fromarray(rgba, "RGBA")
    q = im.quantize(256, method=Image.Quantize.FASTOCTREE)
    q.save(path, optimize=True)


def main():
    ids, hdr = load_headers()
    names = {v: k for k, v in ids.items()}
    enc = encounters()
    g = Game(A + "6/5", A + "4/4", A + "4/2", A + "4/0", A + "7/0")
    room = Game(A + "6/5", A + "4/4", A + "4/2", HG + "/files/fielddata/build_model/bm_room.narc", A + "7/0")
    cdir = os.path.join(ROOT, "client/assets/maps"); sdir = os.path.join(ROOT, "server/maps")
    world_m = read_matrix(matrix_file("NARC_map_matrix_map_matrix_0000_EVERYWHERE_bin"))
    mw, mh, mhd, mland = world_m
    johto = lambda i: hdr.get(i, {}).get("regionNo") == "MAP_REGION_JOHTO"
    world_cells = [(i % mw, i // mw) for i in range(mw * mh) if mland[i] != 0xFFFF and johto(mhd[i])]
    named = [(x, y) for x, y in world_cells if mhd[y * mw + x] != 0]
    bx0, bx1 = min(x for x, _ in named), max(x for x, _ in named)
    by0, by1 = min(y for _, y in named), max(y for _, y in named)
    world_headers = {mhd[y * mw + x] for x, y in named}
    # Interiores alcançáveis pelas portas a partir do mundo aberto.
    area_of = {}
    for hid in world_headers:
        area_of[hid] = WORLD
    queue = deque(world_headers)
    seen = set(world_headers)
    while queue:
        hid = queue.popleft()
        for wv in events(hdr[hid]).get("warps", []):
            dest = ids.get(wv["header"])
            if dest is None or dest in seen or not johto(dest):
                continue
            seen.add(dest)
            if "EVERYWHERE" in hdr[dest]["matrixId"]:
                continue
            area_of[dest] = PREFIX + names[dest].replace("MAP_", "").lower()
            queue.append(dest)
    print(len(area_of), "mapas de Johto;", len(set(area_of.values())), "áreas")
    # ---------------------------------------------------------- mundo aberto
    W, H = (bx1 - bx0 + 1), (by1 - by0 + 1)
    chunks = {}
    for x, y in world_cells:
        if bx0 <= x <= bx1 and by0 <= y <= by1:
            hid = mhd[y * mw + x]
            chunks[(x - bx0, y - by0)] = (mland[y * mw + x], int(hdr[hid]["areaDataBank"]))
    layout = {WORLD: dict(origin=(bx0 * 32, by0 * 32), w=W * 32, h=H * 32)}
    areas = {}
    cells = ["#"] * (W * 32 * H * 32)
    for (cx, cy), (li, _) in chunks.items():
        perm = g.perms(li)
        for i, v in enumerate(perm):
            x, y = cx * 32 + i % 32, cy * 32 + i // 32
            cells[y * W * 32 + x] = cell_code(v)
    hm = heights(g, chunks, W * 32, H * 32)
    imgs = None
    if "--skip-world" not in sys.argv:
        imgs = render_area(g, chunks, W, H, os.path.join(cdir, "jt", WORLD), grid=grid_of(cells, hm, W * 32, H * 32))
    zones, zone_info, zidx = [], [], {}
    for cy in range(H):
        for cx in range(W):
            hid = mhd[(cy + by0) * mw + cx + bx0]
            if hid not in zidx:
                zidx[hid] = len(zone_info)
                land, surf = enc.get(hdr.get(hid, {}).get("wildEncounterBank", ""), ([], []))
                zone_info.append({"name": nice(names.get(hid, "MAP_JOHTO")) if hid else "Johto", "encounters": land, "water": surf})
            zones.append(zidx[hid])
    areas[WORLD] = dict(w=W * 32, h=H * 32, cells=cells, heights=hm, zones=zones, zone_info=zone_info, chunk=32,
                        origin=(bx0 * 32, by0 * 32), imgs=dict(cols=W, rows=H, tiles=imgs, crop=None), headers=world_headers,
                        name="Johto")
    # ---------------------------------------------------------- interiores
    for hid, area in sorted(area_of.items()):
        if area == WORLD or area in areas:
            continue
        w, h, _, land = read_matrix(matrix_file(hdr[hid]["matrixId"]))
        ch = {(i % w, i // w): (land[i], int(hdr[hid]["areaDataBank"])) for i in range(w * h) if land[i] != 0xFFFF}
        if not ch:
            continue
        full = ["#"] * (w * 32 * h * 32)
        for (cx, cy), (li, _) in ch.items():
            for i, v in enumerate(room.perms(li)):
                full[(cy * 32 + i // 32) * w * 32 + cx * 32 + i % 32] = cell_code(v)
        fullh = heights(room, ch, w * 32, h * 32, with_objects=True)
        crop = render_area(room, ch, w, h, os.path.join(cdir, "jt", area), crop=True, grid=grid_of(full, fullh, w * 32, h * 32))
        if crop is None:
            continue
        x0, y0, x1, y1 = crop
        # Recorte em células (o topo pode ter subido além do chunk por causa da altura).
        c0, r0 = x0 // 16, max(y0, 0) // 16
        c1, r1 = x1 // 16, min(y1, h * CH) // 16
        cw, chh = c1 - c0, r1 - r0
        cells = [full[(r0 + y) * w * 32 + c0 + x] for y in range(chh) for x in range(cw)]
        hm = fullh[r0:r1, c0:c1]
        land, surf = enc.get(hdr[hid].get("wildEncounterBank", ""), ([], []))
        areas[area] = dict(w=cw, h=chh, cells=cells, heights=hm, origin=(c0, r0), imgs=dict(crop=(x0 - c0 * 16, y0 - r0 * 16)),
                           headers={hid}, name=nice(names[hid]), encounters=land, water=surf,
                           cave=hdr[hid].get("mapType") == "MAP_TYPE_DUNGEON")
        layout[area] = dict(origin=(c0, r0))
    # ---------------------------------------------------------- portas e NPCs
    hid_area = {hid: a for a, d in areas.items() for hid in d["headers"]}
    warps_of = {}
    for hid, area in hid_area.items():
        ev = events(hdr[hid])
        ox, oy = (0, 0) if area == WORLD else areas[area]["origin"]
        if area == WORLD:
            ox, oy = bx0 * 32, by0 * 32
        warps_of[hid] = [(wv["x"] - ox, wv["z"] - oy, wv) for wv in ev.get("warps", [])]
    for hid, area in hid_area.items():
        d = areas[area]
        for x, y, _ in warps_of[hid]:
            if 0 <= x < d["w"] and 0 <= y < d["h"]:
                d["cells"][y * d["w"] + x] = "."
    for area, d in areas.items():
        d["warps"], d["npcs"] = [], []
    for hid, area in hid_area.items():
        d = areas[area]
        for x, y, wv in warps_of[hid]:
            dest = ids.get(wv["header"])
            if dest not in hid_area or not (0 <= x < d["w"] and 0 <= y < d["h"]):
                continue
            to = hid_area[dest]
            dw = warps_of.get(dest, [])
            k = int(wv.get("anchor", 0))
            if k >= len(dw):
                continue
            tx, ty, _ = dw[k]
            dd = areas[to]
            for nx, ny in ((tx, ty + 1), (tx, ty - 1), (tx - 1, ty), (tx + 1, ty)):
                if 0 <= nx < dd["w"] and 0 <= ny < dd["h"] and dd["cells"][ny * dd["w"] + nx] in '."' and (nx, ny) not in {(a, b) for a, b, _ in dw}:
                    tx, ty = nx, ny
                    break
            d["warps"].append({"x": x, "y": y, "w": 1, "h": 1, "to": to, "tx": (tx + .5) * CELL, "ty": (ty + .7) * CELL})
        for o in events(hdr[hid]).get("objects", []):
            ox, oy = (bx0 * 32, by0 * 32) if area == WORLD else d["origin"]
            x, y = o["x"] - ox, o["z"] - oy
            if 0 <= x < d["w"] and 0 <= y < d["h"]:
                d["npcs"].append({"x": (x + .5) * CELL, "y": (y + .9) * CELL, "sprite": o["spriteId"], "name": "",
                                  "facing": {0: 3, 1: 0, 2: 1, 3: 2}.get(o.get("facingDirection", 1), 0)})
    # ---------------------------------------------------------- grava
    start = None
    for area, d in areas.items():
        if area == WORLD and "--skip-world" in sys.argv:
            continue
        w, h = d["w"], d["h"]
        code = "".join(d["cells"])
        free = [(abs(x - w / 2) + abs(y - h / 2), x, y) for y in range(h) for x in range(w) if code[y * w + x] == "."]
        default = [(w / 2) * CELL, (h / 2) * CELL]
        if area == WORLD:
            # Chega em New Bark Town.
            nb = ids["MAP_NEW_BARK"]
            cs = [(i % W, i // W) for i, z in enumerate(d["zones"]) if d["zone_info"][z]["name"].startswith("New Bark")]
            if cs:
                cx, cy = cs[0]
                free = [(abs(x - cx * 32 - 16) + abs(y - cy * 32 - 18), x, y) for y in range(cy * 32, cy * 32 + 32)
                        for x in range(cx * 32, cx * 32 + 32) if code[y * w + x] == "."]
        if free:
            _, fx, fy = min(free)
            default = [(fx + .5) * CELL, (fy + .7) * CELL]
        for n in d["npcs"]:
            i = int(n["y"] // CELL) * w + int(n["x"] // CELL)
            if 0 <= i < len(code):
                code = code[:i] + "#" + code[i + 1:]
        server = {"w": w, "h": h, "cell": CELL, "cells": code, "warps": d["warps"], "connections": [],
                  "encounters": d.get("encounters", []), "water": d.get("water", []), "cave": d.get("cave", False),
                  "spawns": {}, "points": {}, "default": default, "name": d["name"]}
        if "zones" in d:
            server.update(zones=d["zones"], zone_info=d["zone_info"], chunk=32, zone_cols=W)
        json.dump(server, open(os.path.join(sdir, area + ".json"), "w"), separators=(",", ":"))
        hm = np.round(d["heights"]).astype(int)
        client = {"w": w, "h": h, "cell": CELL, "name": d["name"], "region": "johto", "default": default, "points": {},
                  "npcs": d["npcs"], "image": {"dir": "jt/" + area, "chunk": CH, "k": K,
                                               "cols": d["imgs"].get("cols", 1), "rows": d["imgs"].get("rows", 1),
                                               "tiles": d["imgs"].get("tiles"), "crop": d["imgs"].get("crop")},
                  "heights": hm.reshape(-1).tolist()}
        if "zones" in d:
            client.update(zones=d["zones"], zone_names=[z["name"] for z in d["zone_info"]], chunk=32, zone_cols=W)
        json.dump(client, open(os.path.join(cdir, area + ".json"), "w"), separators=(",", ":"))
    index = {a: d["name"] for a, d in areas.items()}
    json.dump({"areas": sorted(index), "names": index}, open(os.path.join(cdir, "johto_index.json"), "w"), ensure_ascii=False, indent=0)
    print(len(areas), "áreas gravadas")


if __name__ == "__main__":
    main()
