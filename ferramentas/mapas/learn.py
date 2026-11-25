"""Aprende as bordas automáticas (areia, água) a partir dos mapas originais:
para cada célula de uma família, guarda qual metatile o jogo usou para cada
combinação de vizinhos. Assim os mapas novos ganham bordas iguais às do jogo."""
import json, os
from collections import Counter, defaultdict
from gba import GAMES, Pair, tileset_dir

SAND = [(232, 216, 152), (224, 208, 136), (240, 224, 168), (248, 232, 168), (216, 200, 128)]


FAMILIES = {
    "sand": {211, 212, 213, 219, 220, 221, 227, 228, 229, 258, 259, 260, 261},
}


def classify(pair, m):
    for fam, ids in FAMILIES.items():
        if m in ids:
            return fam
    if m < 300 and m not in range(288, 306):
        return None
    lo, hi = pair.layers(m)
    img = lo.copy(); img.alpha_composite(hi)
    px = list(img.get_flattened_data()) if hasattr(img, 'get_flattened_data') else list(img.getdata())
    sand = water = 0
    for r, g, b, a in px:
        if a == 0:
            continue
        if r > 190 and g > 170 and 100 < b < 190 and r - b > 50:
            sand += 1
        if b > 150 and b > r + 40 and b > g + 10:
            water += 1
    n = len(px)
    if water > n * .45:
        return "water"
    if sand > n * .40:
        return "sand"
    return None


OFFS = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]


def mask(get, x, y, fam):
    m = 0
    for i, (dx, dy) in enumerate(OFFS):
        if get(x + dx, y + dy) == fam:
            m |= 1 << i
    return m


def learn(game, secondary, only=None):
    root = GAMES[game]["root"]
    data = json.load(open(os.path.join(root, "data/layouts/layouts.json")))
    pair = Pair(game, "general", secondary)
    cls = {}
    table = defaultdict(lambda: defaultdict(Counter))
    import struct
    for l in data["layouts"]:
        if not l or tileset_dir(l["primary_tileset"]) != "general":
            continue
        if only and l["name"].replace("_Layout", "") not in only:
            continue
        same = tileset_dir(l["secondary_tileset"]) == secondary
        raw = open(os.path.join(root, l["blockdata_filepath"]), "rb").read()
        cells = struct.unpack("<%dH" % (len(raw) // 2), raw)
        w, h = l["width"], l["height"]
        ids = [c & 0x3FF for c in cells]
        if not same and any(i >= GAMES[game]["metas"] for i in ids if 0):
            pass
        def fam(i):
            if not same and i >= GAMES[game]["metas"]:
                return "x"
            if i not in cls:
                cls[i] = classify(pair, i)
            return cls[i]
        grid = [fam(i) for i in ids]
        def get(x, y):
            if 0 <= x < w and 0 <= y < h:
                return grid[y * w + x]
            return "edge"
        for y in range(h):
            for x in range(w):
                f = grid[y * w + x]
                if f in ("sand", "water"):
                    table[f][mask(get, x, y, f)][ids[y * w + x]] += 1
    return {f: {m: c.most_common(1)[0][0] for m, c in t.items()} for f, t in table.items()}


if __name__ == "__main__":
    import sys
    t = learn(sys.argv[1], sys.argv[2], sys.argv[3].split(",") if len(sys.argv) > 3 else None)
    for f, m in t.items():
        print(f, len(m), sorted(set(m.values())))
