"""Repinta o mundo aberto de Sinnoh (sn_sinnoh) com os tilesets do FireRed.

O terreno do Platinum é lido de cima (ds/topdown.py): para cada célula sai o
material por cima (grama, areia, pedra, água, árvore) ou o prédio. Cada tipo
vira um pincel de GBA com bordas aprendidas dos mapas do FireRed (montanha,
água, trilha). Prédios com porta viram construções carimbadas do FireRed
(casa, Centro Pokémon, loja, ginásio, caverna) alinhadas com a porta.

O resultado substitui as imagens de sn/sn_sinnoh e a colisão do servidor; as
portas, zonas, encontros e NPCs continuam os mesmos.

Uso: python3 sinnoh_gba.py   (depois de ds/sinnoh.py)
"""
import json, os, random, struct, sys
from collections import Counter, defaultdict
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "ds"))
from gba import GAMES, Pair, layout, tileset_dir
from learn import mask, OFFS
import build as B

ROOT = os.path.abspath(os.path.join(HERE, "../.."))
CDIR = os.path.join(ROOT, "client/assets/maps")
SDIR = os.path.join(ROOT, "server/maps")
WORLD = "sn_sinnoh"
GEN = "viridian_city"
# Metatiles de montanha do tileset geral (Route 3, Route 4, Mt. Moon por fora).
ROCK = {104, 105, 106, 107, 108, 109, 112, 113, 114, 115, 117, 120, 121, 122, 123, 124, 125, 136, 138, 144, 146,
        161, 178, 179, 186, 187}  # secundário dos pincéis de build.py

LEARN = {
    "rock": ["Route3", "Route4", "Route9", "Route10", "Route24", "Route25", "Route2", "Route22", "Route23", "Route11",
             "Route12", "Route18", "Route16", "Route17", "ViridianCity", "PewterCity", "CeruleanCity"],
    "water": ["PalletTown", "Route21_North", "Route21_South", "Route19", "Route20", "CinnabarIsland", "Route24",
              "Route25", "CeruleanCity", "Route12", "Route13", "VermilionCity", "Route4"],
}


def family(img):
    px = np.asarray(img)
    a = px[..., 3] > 0
    if a.sum() < 128:
        return None
    r, g, b = (px[..., i][a].astype(int) for i in range(3))
    n = a.sum()
    if ((b > 150) & (b > r + 40) & (b > g + 10)).sum() > n * .45:
        return "water"
    if ((r > 170) & (r - g > 40) & (r - b > 30)).sum() > n * .5:
        return "rock"
    return None


class Pairs:
    def __init__(self):
        self.p = {}

    def __call__(self, sec):
        if sec not in self.p:
            self.p[sec] = Pair("frlg", "general", sec)
        return self.p[sec]

    def img(self, key):
        sec, m = key
        lo, hi = self(sec).layers(m)
        full = lo.copy(); full.alpha_composite(hi)
        return lo, hi, full


def learn_families(pairs):
    root = GAMES["frlg"]["root"]
    data = json.load(open(os.path.join(root, "data/layouts/layouts.json")))
    table = {f: defaultdict(Counter) for f in LEARN}
    cls = {}
    for l in data["layouts"]:
        if not l or tileset_dir(l["primary_tileset"]) != "general":
            continue
        name = l["name"].replace("_Layout", "")
        fams = [f for f, ls in LEARN.items() if name in ls]
        if not fams:
            continue
        sec = tileset_dir(l["secondary_tileset"])
        raw = open(os.path.join(root, l["blockdata_filepath"]), "rb").read()
        ids = [c & 0x3FF for c in struct.unpack("<%dH" % (len(raw) // 2), raw)]
        w, h = l["width"], l["height"]
        keys = [(GEN if i < 640 else sec, i) for i in ids]
        for k in set(keys):
            if k not in cls:
                f = family(pairs.img(k)[2])
                if f == "rock" or (k[1] < 640 and k[1] in ROCK):
                    f = "rock" if k[1] < 640 and k[1] in ROCK else None
                # Montanhas só do tileset geral (telhados vermelhos dos secundários enganam).
                cls[k] = None if f == "rock" and (k[1] >= 640 or k[1] in B.LEDGE_IDS) else f
        grid = [cls[k] for k in keys]
        get = lambda x, y: grid[y * w + x] if 0 <= x < w and 0 <= y < h else "edge"
        for y in range(h):
            for x in range(w):
                f = grid[y * w + x]
                if f in fams:
                    table[f][mask(get, x, y, f)][keys[y * w + x]] += 1
    return {f: {m: c.most_common(1)[0][0] for m, c in t.items()} for f, t in table.items()}


def best(table, m, default):
    if m in table:
        return table[m]
    card = m & 0b01011010
    cands = [v for k, v in table.items() if k & 0b01011010 == card]
    if cands:
        return Counter(cands).most_common(1)[0][0]
    return default


def color_kind(c):
    r, g, b = c
    if b > r + 30 and b > g:
        return "water"
    if g > r + 12 and g > b:
        return "grass"
    if r > 160 and g > 140 and r - b > 40 and abs(r - g) < 60:
        return "sand"
    if abs(r - g) < 28 and abs(g - b) < 34:
        return "pave"
    return "rock"


def classify(top, mats, perm):
    """Pincel por célula a partir do material de cima e do comportamento do DS."""
    H, W = top.shape
    kind = np.full((H, W), "rock", object)
    mk = []
    for name, col, tree in mats:
        n = name or ""
        if tree:
            mk.append("tree")
        elif "fl" in n or "hana" in n:
            mk.append("flower")
        else:
            mk.append(color_kind(col))
    beh = perm & 0xFF
    blocked = (perm & 0x8000) != 0
    for y in range(H):
        for x in range(W):
            t = top[y, x]
            k = mk[t] if t >= 0 else ("prop" if t <= -2 else "void")
            if k == "void" and blocked[y, x]:
                kind[y, x] = "forest"
                continue
            b = beh[y, x]
            if b in (0x10, 0x11, 0x13, 0x15, 0x16, 0x19, 0x1A, 0x22):
                k = "water"
            elif b in (0x02, 0x03):
                k = "tall"
            elif b == 0x3B:
                k = "ledge"
            elif blocked[y, x]:
                if k in ("tree", "grass", "flower"):
                    k = "forest"
                elif k == "prop":
                    k = "prop"
                elif k in ("water",):
                    k = "water"
                else:
                    k = "rock"
            else:
                if k in ("tree", "void"):
                    k = "grass"
                elif k == "prop":
                    k = "sand"  # pontes e calçadas de prédio
                elif k == "rock":
                    k = "sand"
            kind[y, x] = k
    return kind


def tidy(kind):
    """Calçadas pequenas viram trilha de areia; pedras soltas viram arbustos."""
    H, W = kind.shape
    seen = np.zeros((H, W), bool)
    for y0, x0 in zip(*np.nonzero(kind == "pave")):
        if seen[y0, x0]:
            continue
        comp, stack = [], [(y0, x0)]
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < H and 0 <= nx < W and not seen[ny, nx] and kind[ny, nx] == "pave":
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(comp) < 80:
            for y, x in comp:
                kind[y, x] = "sand"
    rock = kind == "rock"
    nb = np.zeros(rock.shape, int)
    nb[1:] += rock[:-1]; nb[:-1] += rock[1:]; nb[:, 1:] += rock[:, :-1]; nb[:, :-1] += rock[:, 1:]
    kind[rock & (nb <= 1)] = "bush"


STAMP_OF = (("pokecenter", "centro"), ("pokemart", "loja"), ("friendly_shop", "loja"), ("gym", "ginasio"),
            ("cave", "caverna"), ("mt_coronet", "caverna"), ("tunnel", "caverna"), ("gate", "escola"),
            ("ruins", "caverna"), ("mine", "caverna"), ("wayward", "caverna"), ("iron_island", "caverna"),
            ("victory_road", "caverna"), ("lake", None), ("forest", None))


def stamp_for(to, cave):
    for k, v in STAMP_OF:
        if k in to:
            return v
    return "caverna" if cave else "casa"


def main():
    sys.argv = [sys.argv[0], "x", ROOT]
    import sinnoh as S, topdown
    hdr = S.headers()
    groups = {x["id"]: x for x in json.load(open(S.PT + "/res/field/maps/groups.json"))}
    g = S.PtGame(); world = groups["TownsAndRoutes"]
    mh, mw = len(world["maps"]), len(world["maps"][0])
    ch = lambda x, y: world["headers"][y][x]
    cells_all = [(x, y) for y in range(mh) for x in range(mw) if S.land_index(world["maps"][y][x]) is not None]
    named = [(x, y) for x, y in cells_all if ch(x, y) != "MAP_HEADER_EVERYWHERE" and ch(x, y) in hdr]
    bx0, bx1 = min(x for x, _ in named), max(x for x, _ in named)
    by0, by1 = min(y for _, y in named), max(y for _, y in named)
    W, H = bx1 - bx0 + 1, by1 - by0 + 1
    chunks = {}
    for x, y in cells_all:
        if bx0 <= x <= bx1 and by0 <= y <= by1:
            ad = hdr.get(ch(x, y), hdr["MAP_HEADER_TWINLEAF_TOWN"])["areaData"]
            chunks[(x - bx0, y - by0)] = (S.land_index(world["maps"][y][x]), ad)
    top, mats, props, _ = topdown.classify(g, chunks, W, H)
    perm = np.full((H * 32, W * 32), 0x8000, np.int32)
    for (cx, cy), (li, _) in chunks.items():
        perm[cy * 32:cy * 32 + 32, cx * 32:cx * 32 + 32] = np.array(g.perms(li)).reshape(32, 32)
    kind = classify(top, mats, perm)
    tidy(kind)
    server = json.load(open(os.path.join(SDIR, WORLD + ".json")))
    client = json.load(open(os.path.join(CDIR, WORLD + ".json")))
    w, h = server["w"], server["h"]
    assert (w, h) == (W * 32, H * 32), (w, h, W, H)
    old = server["cells"]

    pairs = Pairs()
    learned = learn_families(pairs)
    sand = B.learn("frlg", GEN, ["Route1", "Route2", "Route22", "ViridianCity", "Route21_North"])["sand"]
    sand = {k: v for k, v in sand.items() if v in {211, 212, 213, 219, 220, 221, 227, 228, 229, 258, 259, 260, 261}}
    print("aprendido:", {f: len(t) for f, t in learned.items()}, "areia", len(sand))

    # Pincéis -> mapa de build.py (mesma lógica de bordas, floresta e ledges).
    m = B.Map(WORLD, w, h, seed=21)
    m.kind = [[str(kind[y, x]) for x in range(w)] for y in range(h)]
    m.extra = {}
    doors = paint_buildings(m, top, server["warps"])
    ids, cell = build_cells(m, learned, sand)
    # Servidor: colisão da pintura, mantendo ressaltos, grama alta e água do DS.
    out = []
    for y in range(h):
        for x in range(w):
            o = old[y * w + x]
            c = cell[y][x]
            if o in "<>^v" or o == '"' or o == "~":
                c = o
            out.append(c)
    for wp in server["warps"]:
        out[wp["y"] * w + wp["x"]] = "."
    for n in server.get("npcs", []):
        nx, ny = int(n[0] // 32) if isinstance(n, list) else int(n["x"] // 32), int(n[1] // 32) if isinstance(n, list) else int(n["y"] // 32)
        out[ny * w + nx] = "#"
    for n in client.get("npcs", []):
        out[int(n["y"] // 32) * w + int(n["x"] // 32)] = "#"
    server["cells"] = "".join(out)
    # Imagens por chunk de 32x32 metatiles (512 px), no mesmo esquema do DS.
    outdir = os.path.join(CDIR, "sn", WORLD)
    for f in os.listdir(outdir):
        os.remove(os.path.join(outdir, f))
    tiles = {}
    def arr(key):
        if key not in tiles:
            lo, hi = pairs(key[0]).layers(key[1])
            tiles[key] = (np.asarray(lo), np.asarray(hi))
        return tiles[key]
    made = []
    for cy in range(H):
        for cx in range(W):
            lo = np.zeros((512, 512, 4), np.uint8); hi = np.zeros((512, 512, 4), np.uint8)
            for j in range(32):
                for i in range(32):
                    a, b = arr(ids[cy * 32 + j][cx * 32 + i])
                    lo[j * 16:j * 16 + 16, i * 16:i * 16 + 16] = a
                    hi[j * 16:j * 16 + 16, i * 16:i * 16 + 16] = b
            Image.fromarray(lo).save(os.path.join(outdir, "%d_%d.png" % (cx, cy)), optimize=True)
            if hi[..., 3].any():
                Image.fromarray(hi).save(os.path.join(outdir, "%d_%d_up.png" % (cx, cy)), optimize=True)
            made.append([cx, cy])
    client["image"] = {"dir": "sn/" + WORLD, "chunk": 512, "k": 0, "cols": W, "rows": H, "tiles": made, "crop": None}
    client.pop("heights", None)
    json.dump(client, open(os.path.join(CDIR, WORLD + ".json"), "w"), separators=(",", ":"))
    json.dump(server, open(os.path.join(SDIR, WORLD + ".json"), "w"), separators=(",", ":"))
    prev = Image.new("RGB", (W * 32, H * 32))
    for cx, cy in made:
        im = Image.open(os.path.join(outdir, "%d_%d.png" % (cx, cy))).convert("RGBA")
        up = os.path.join(outdir, "%d_%d_up.png" % (cx, cy))
        if os.path.exists(up):
            im.alpha_composite(Image.open(up).convert("RGBA"))
        prev.paste(im.resize((32, 32)), (cx * 32, cy * 32))
    prev.save("/tmp/claude-0/sn_gba_preview.png")
    print("Sinnoh repintado:", W * H, "chunks,", doors, "portas com prédio")


# Prédio de apartamentos do Saffron City (5x6), esticado para caber no prédio do DS.
APT = ("SaffronCity", 19, 25, 5, 6)
APT_DOOR = 703
PAVE = ("saffron_city", 745)


def apartment(m, cells, door=None):
    """Pinta um prédio de cidade nas células dadas (bbox esticada do Saffron)."""
    src, sx, sy, sw, sh = APT
    l, lc = layout("frlg", src)
    lw = l["width"]
    sec = tileset_dir(l["secondary_tileset"])
    xs = [x for x, _ in cells]; ys = [y for _, y in cells]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    bw, bh = x1 - x0 + 1, y1 - y0 + 1
    def col(i):
        if i == 0: return 0
        if i == bw - 1: return 4
        if i == bw - 2 and bw >= 4: return 3
        return 1 + (i - 1) % 2 if bw >= 4 else 2
    def row(j):
        if bh < 4:
            return [0, 4, 5][min(j, 2)] if bh == 3 else [0, 5][min(j, 1)] if bh == 2 else 5
        if j < 3: return j
        if j == bh - 1: return 5
        return 3 + (j - 3) % 2
    for x, y in cells:
        c = lc[(sy + row(y - y0)) * lw + sx + col(x - x0)]
        mt = c & 0x3FF
        m.extra[(x, y)] = ((sec if mt >= 640 else GEN, mt), B.WALL)
        m.kind[y][x] = "extra"
    if door:
        m.extra[door] = ((sec, APT_DOOR), B.FLOOR)
        m.kind[door[1]][door[0]] = "extra"


def paint_buildings(m, top, warps):
    """Prédios do DS: carimbos do FireRed nas portas, apartamentos nos maiores."""
    w, h = m.w, m.h
    cells_of = defaultdict(list)
    for y in range(h):
        for x in range(w):
            if m.kind[y][x] == "prop":
                cells_of[int(top[y, x])].append((x, y))
    door_of = {}
    for wp in warps:
        x, y = wp["x"], wp["y"]
        for ny in range(y, max(-1, y - 4), -1):
            t = int(top[ny, x])
            if t in cells_of:
                door_of.setdefault(t, []).append(wp)
                break
        else:
            door_of.setdefault(None, []).append(wp)
    doors = 0
    done = set()
    for pid, wps in door_of.items():
        for wp in wps:
            to = wp["to"]
            try:
                cave = json.load(open(os.path.join(SDIR, to + ".json"))).get("cave", False)
            except Exception:
                cave = False
            st = stamp_for(to, cave)
            if not st:
                continue
            cells = cells_of.get(pid, [])
            xs = [x for x, _ in cells] or [wp["x"]]; ys = [y for _, y in cells] or [wp["y"]]
            bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
            if st == "casa" and (bw > 7 or bh > 5) and pid is not None and pid not in done:
                apartment(m, cells, (wp["x"], wp["y"]))
                done.add(pid)
            elif pid in done:
                m.extra[(wp["x"], wp["y"])] = ((tileset_dir("gTileset_SaffronCity"), APT_DOOR), B.FLOOR)
                m.kind[wp["y"]][wp["x"]] = "extra"
            else:
                _, sx, sy, sw, shh, door = B.STAMPS[st]
                x0, y0 = wp["x"] - door[0], wp["y"] - door[1]
                if x0 < 0 or y0 < 0 or x0 + sw > w or y0 + shh > h:
                    continue
                for (x, y) in cells:
                    m.kind[y][x] = "grass"  # o resto do prédio de DS vira quintal
                m.stamp(st, x0, y0)
                if pid is not None:
                    done.add(pid)
            dx, dy = wp["x"], wp["y"]
            if (dx, dy) in m.fixed:
                m.fixed[(dx, dy)] = (m.fixed[(dx, dy)][0], B.FLOOR)
            if dy + 1 < h and m.kind[dy + 1][dx] not in ("fixed", "extra"):
                m.kind[dy + 1][dx] = "pave" if m.kind[dy + 1][dx] == "pave" else "sand"
            doors += 1
    # Construções sem porta: grandes viram prédios, pequenas viram arbustos e cercas.
    for pid, cells in cells_of.items():
        if pid in done:
            continue
        cells = [(x, y) for x, y in cells if m.kind[y][x] == "prop"]
        if not cells:
            continue
        xs = [x for x, _ in cells]; ys = [y for _, y in cells]
        bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
        if len(cells) >= 9 and bw >= 3 and bh >= 3:
            apartment(m, cells)
        else:
            for x, y in cells:
                m.kind[y][x] = "fence" if bh == 1 and bw >= 3 else "bush"
    return doors


def build_cells(m, learned, sand):
    """Resolve os pincéis em (secundário, metatile) e tipo de célula do servidor."""
    w, h = m.w, m.h
    get = lambda x, y: m.kind[y][x] if 0 <= x < w and 0 <= y < h else "edge"
    rng = random.Random(21)
    rock, water = learned["rock"], learned["water"]
    rock_mid = (GEN, 113)
    rock[255] = rock_mid
    water_mid = water.get(255) or Counter(water.values()).most_common(1)[0][0]
    ids = [[None] * w for _ in range(h)]
    cell = [[B.FLOOR] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            k = m.kind[y][x]
            if k == "extra":
                ids[y][x], cell[y][x] = m.extra[(x, y)]
            elif k == "pave":
                ids[y][x] = PAVE
            elif k == "fixed":
                mt, c = m.fixed[(x, y)]
                ids[y][x], cell[y][x] = (GEN, mt), c
            elif k == "rock":
                ids[y][x], cell[y][x] = best(rock, mask(get, x, y, "rock"), rock_mid), B.WALL
            elif k == "water":
                ids[y][x], cell[y][x] = best(water, mask(get, x, y, "water"), water_mid), B.WATER
            elif k == "sand":
                ids[y][x] = (GEN, B.best(sand, mask(get, x, y, "sand"), 220))
            elif k == "grass":
                ids[y][x] = (GEN, rng.choice(B.GRASS_IDS))
            elif k == "tall":
                ids[y][x], cell[y][x] = (GEN, B.TALL), B.GRASS
            elif k == "flower":
                ids[y][x] = (GEN, B.FLOWER)
            elif k == "bush":
                ids[y][x], cell[y][x] = (GEN, B.BUSH), B.WALL
            elif k == "fence":
                ids[y][x], cell[y][x] = (GEN, B.FENCE), B.WALL
            elif k == "ledge":
                left, right = get(x - 1, y) != "ledge", get(x + 1, y) != "ledge"
                ids[y][x] = (GEN, B.LEDGE_IDS[0] if left else B.LEDGE_IDS[2] if right else B.LEDGE_IDS[1])
                cell[y][x] = B.LEDGE
            elif k == "forest":
                top = get(x, y - 1) != "forest"
                left = get(x - 1, y) != "forest" and x % 2 == 0
                right = get(x + 1, y) != "forest" and x % 2 == 1
                even = y % 2 == 0
                if top and even:
                    base = 30 if x % 2 == 0 else 31
                elif even:
                    base = 28 if x % 2 == 0 else 29
                else:
                    base = 20 if x % 2 == 0 else 21
                bottom = get(x, y + 1) != "forest" and not even
                if bottom:
                    base = 36 if x % 2 == 0 else 37
                if left:
                    base = 38 if bottom else 30 if even else 22
                if right:
                    base = 39 if bottom else 31 if even else 23
                ids[y][x], cell[y][x] = (GEN, base), B.WALL
            else:
                ids[y][x] = (GEN, 1)
    return ids, cell


if __name__ == "__main__":
    main()
