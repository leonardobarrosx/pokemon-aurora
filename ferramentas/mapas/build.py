"""Gera os mapas externos de Aurora com os tilesets do FireRed (pret/pokefirered).

Os mapas são originais: este script desenha o terreno com pincéis (grama,
grama alta, trilha de areia com bordas aprendidas dos mapas do jogo,
floresta, água, cercas) e carimba construções copiadas dos mapas do FireRed.

Saídas:
  client/assets/maps/<tileset>_below.png / _above.png  atlas de metatiles 16x16
  client/assets/maps/<area>.json                       camadas para o cliente
  server/maps/<area>.json                              colisão, passagens e chegadas
"""
import json, os, random
from PIL import Image
from gba import Pair, layout
from learn import learn, mask

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
CELL = 32  # um metatile ocupa 32 px do mundo (pixels do GBA dobrados)

# Tipos de célula para o servidor.
FLOOR, WALL, GRASS, LEDGE, WATER = ".", "#", '"', "v", "~"

GRASS_IDS = [1, 1, 1, 1, 8, 9, 16, 17]
TALL = 13
FLOWER = 4
BUSH = 5
SIGN = 3
FENCE = 231
LEDGE_IDS = (176, 135, 177)
POND = {"tl": 421, "t": 422, "tr": 423, "l": 429, "c": 430, "r": 431}

STAMPS = {
    # nome: (layout, x, y, w, h, porta relativa ou None)
    "casa": ("ViridianCity", 24, 9, 6, 3, (1, 2)),
    "escola": ("ViridianCity", 24, 16, 6, 4, (1, 2)),
    "centro": ("ViridianCity", 24, 23, 6, 4, (2, 3)),
    "loja": ("ViridianCity", 34, 16, 5, 4, (2, 3)),
    "ginasio": ("ViridianCity", 33, 6, 6, 5, (3, 4)),
    "caverna": ("Route4", 16, 0, 8, 6, (3, 5)),
}


class Map:
    def __init__(self, name, w, h, secondary="viridian_city", seed=1):
        self.name, self.w, self.h = name, w, h
        self.secondary = secondary
        self.rng = random.Random(seed)
        self.kind = [["grass"] * w for _ in range(h)]  # pincel por célula
        self.fixed = {}  # (x, y) -> (metatile, tipo servidor)
        self.warps, self.spawns, self.npcs, self.points = [], {}, [], {}

    def rect(self, x, y, w, h, kind):
        for j in range(y, y + h):
            for i in range(x, x + w):
                if 0 <= i < self.w and 0 <= j < self.h:
                    self.kind[j][i] = kind
                    self.fixed.pop((i, j), None)

    def put(self, x, y, metatile, cell=FLOOR):
        self.fixed[(x, y)] = (metatile, cell)
        self.kind[y][x] = "fixed"

    def stamp(self, name, x, y, to=None):
        src, sx, sy, w, h, door = STAMPS[name]
        l, cells = layout("frlg", src)
        lw = l["width"]
        for j in range(h):
            for i in range(w):
                c = cells[(sy + j) * lw + sx + i]
                solid = (c >> 10) & 3
                self.put(x + i, y + j, c & 0x3FF, WALL if solid else FLOOR)
        if door and to:
            dx, dy = x + door[0], y + door[1]
            self.fixed[(dx, dy)] = (self.fixed[(dx, dy)][0], FLOOR)
            self.warps.append({"x": dx, "y": dy, "w": 1, "h": 1, "to": to})
            self.points["porta_" + to] = (dx, dy + 1)
        return door and (x + door[0], y + door[1])

    def exit(self, side, a, b, to):
        """Saída pela borda do mapa: células a..b na borda indicada."""
        if side in ("n", "s"):
            y = 0 if side == "n" else self.h - 1
            self.warps.append({"x": a, "y": y, "w": b - a + 1, "h": 1, "to": to})
            self.spawns[to] = ((a + b + 1) / 2, 1.5 if side == "n" else self.h - 1.5)
        else:
            x = 0 if side == "w" else self.w - 1
            self.warps.append({"x": x, "y": a, "w": 1, "h": b - a + 1, "to": to})
            self.spawns[to] = (1.5 if side == "w" else self.w - 1.5, (a + b + 1) / 2)

    # ---- resolução dos pincéis -------------------------------------------
    def build(self, learned):
        ids = [[0] * self.w for _ in range(self.h)]
        cell = [[FLOOR] * self.w for _ in range(self.h)]
        get = lambda x, y: self.kind[y][x] if 0 <= x < self.w and 0 <= y < self.h else "edge"
        sand = learned.get("sand", {})
        for y in range(self.h):
            for x in range(self.w):
                k = self.kind[y][x]
                if k == "fixed":
                    ids[y][x], cell[y][x] = self.fixed[(x, y)]
                elif k == "grass":
                    ids[y][x] = self.rng.choice(GRASS_IDS)
                    if get(x, y - 1) == "water":
                        ids[y][x] = 307  # margem inferior do lago
                    # Pontas das árvores sobre a grama, logo acima da floresta.
                    if get(x, y + 1) == "forest" and get(x, y + 2) == "forest" and (y + 1) % 2 == 0:
                        ids[y][x] = 14 if x % 2 == 0 else 15
                elif k == "tall":
                    ids[y][x], cell[y][x] = TALL, GRASS
                elif k == "flower":
                    ids[y][x] = FLOWER
                elif k == "bush":
                    ids[y][x], cell[y][x] = BUSH, WALL
                elif k == "sign":
                    ids[y][x], cell[y][x] = SIGN, WALL
                elif k == "fence":
                    ids[y][x], cell[y][x] = FENCE, WALL
                elif k == "ledge":
                    left = get(x - 1, y) != "ledge"
                    right = get(x + 1, y) != "ledge"
                    ids[y][x] = LEDGE_IDS[0] if left else LEDGE_IDS[2] if right else LEDGE_IDS[1]
                    cell[y][x] = LEDGE
                elif k == "sand":
                    m = mask(get, x, y, "sand")
                    ids[y][x] = best(sand, m, 220)
                elif k == "water":
                    up, lf, rt = get(x, y - 1) != "water", get(x - 1, y) != "water", get(x + 1, y) != "water"
                    key = ("t" if up else "") + ("l" if lf else "r" if rt else "")
                    key = {"": "c", "t": "t", "tl": "tl", "tr": "tr", "l": "l", "r": "r"}[key]
                    ids[y][x], cell[y][x] = POND[key], WATER
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
                    ids[y][x], cell[y][x] = base, WALL
        return ids, cell


def best(table, m, default):
    if m in table:
        return table[m]
    # Sem exemplo exato: usa o vizinho cardinal mais parecido.
    card = m & 0b01011010
    for k, v in table.items():
        if k & 0b01011010 == card:
            return v
    return default


# ---------------------------------------------------------------------------
# Mapas originais de Aurora
# ---------------------------------------------------------------------------

def forest_border(m, gaps):
    """Floresta de 2 células na volta do mapa, com aberturas nas saídas."""
    m.rect(0, 0, m.w, 2, "forest"); m.rect(0, m.h - 2, m.w, 2, "forest")
    m.rect(0, 0, 2, m.h, "forest"); m.rect(m.w - 2, 0, 2, m.h, "forest")
    for side, a, b in gaps:
        if side == "n": m.rect(a, 0, b - a + 1, 2, "grass")
        if side == "s": m.rect(a, m.h - 2, b - a + 1, 2, "grass")
        if side == "w": m.rect(0, a, 2, b - a + 1, "grass")
        if side == "e": m.rect(m.w - 2, a, 2, b - a + 1, "grass")


def vila():
    m = Map("vila", 36, 28, seed=3)
    forest_border(m, [("n", 16, 19), ("w", 12, 15), ("e", 12, 15)])
    m.rect(2, 2, 2, 2, "forest"); m.rect(32, 2, 2, 4, "forest"); m.rect(2, 22, 4, 4, "forest"); m.rect(30, 22, 4, 4, "forest")
    # Trilhas
    m.rect(16, 0, 4, 28, "sand")
    m.rect(0, 12, 36, 4, "sand")
    m.rect(6, 8, 24, 2, "sand")
    m.rect(6, 8, 2, 5, "sand"); m.rect(26, 8, 2, 5, "sand")
    m.rect(8, 16, 2, 4, "sand"); m.rect(26, 16, 2, 4, "sand")
    # Construções
    m.stamp("casa", 5, 4, "casa")
    m.stamp("escola", 24, 4)
    m.stamp("centro", 6, 18)
    m.stamp("loja", 24, 19)
    m.rect(5, 7, 2, 1, "sand")
    m.rect(25, 7, 2, 1, "sand")
    # Detalhes
    for x in range(11, 15): m.rect(x, 4, 1, 1, "flower"); m.rect(x, 5, 1, 1, "flower")
    m.rect(11, 3, 4, 1, "fence")
    m.rect(21, 18, 1, 1, "sign"); m.rect(14, 11, 1, 1, "sign")
    for x in (21, 23): m.rect(x, 20, 1, 1, "bush")
    for x in range(20, 24): m.rect(x, 24, 1, 1, "flower")
    m.rect(11, 21, 4, 3, "water")
    m.exit("n", 16, 19, "rota"); m.exit("w", 12, 15, "lago"); m.exit("e", 12, 15, "jardim")
    m.npcs = [{"name": "Íris", "sprite": "professor", "x": 13, "y": 10}, {"name": "Lia", "sprite": "gardener", "x": 22, "y": 10}, {"name": "Theo", "sprite": "engineer", "x": 10, "y": 18}]
    m.default = (17.5, 18)
    return m


def rota():
    m = Map("rota", 36, 44, seed=5)
    forest_border(m, [("s", 16, 19), ("e", 20, 23)])
    m.rect(0, 0, 36, 8, "forest")
    m.stamp("caverna", 8, 2, "mina")
    m.stamp("ginasio", 24, 3, "ginasio")
    m.rect(10, 8, 2, 2, "sand"); m.rect(26, 8, 2, 2, "sand")
    m.rect(10, 9, 18, 2, "sand")
    m.rect(16, 9, 4, 35, "sand")
    m.rect(16, 20, 18, 2, "sand"); m.rect(20, 20, 16, 4, "sand")
    # Grama alta em manchas, como nas rotas de Kanto e Hoenn.
    m.rect(4, 12, 10, 6, "tall"); m.rect(22, 12, 10, 6, "tall")
    m.rect(4, 26, 8, 8, "tall"); m.rect(22, 28, 10, 6, "tall")
    m.rect(4, 36, 10, 4, "tall")
    # Ressaltos para descer de um nível ao outro.
    m.rect(4, 24, 11, 1, "ledge"); m.rect(21, 25, 11, 1, "ledge")
    for (x, y) in [(2, 20), (12, 20), (8, 34)]: m.rect(x, y, 2, 2, "forest")
    for (x, y) in [(14, 13), (14, 14), (21, 30), (13, 38), (22, 38), (24, 37)]: m.rect(x, y, 1, 1, "flower")
    m.rect(15, 41, 1, 1, "sign")
    m.exit("s", 16, 19, "vila"); m.exit("e", 20, 23, "safari")
    m.default = (17.5, 40)
    return m


def lago():
    m = Map("lago", 36, 28, seed=7)
    forest_border(m, [("e", 12, 15)])
    m.rect(2, 2, 4, 6, "forest"); m.rect(28, 2, 6, 4, "forest"); m.rect(2, 22, 6, 4, "forest")
    m.rect(8, 6, 18, 14, "water")
    m.rect(27, 12, 9, 4, "sand"); m.rect(27, 9, 3, 10, "sand")
    m.rect(9, 21, 16, 2, "sand")
    m.rect(28, 18, 4, 4, "tall"); m.rect(10, 23, 8, 2, "tall")
    for (x, y) in [(6, 9), (6, 10), (27, 7), (28, 7), (26, 21), (27, 22)]: m.rect(x, y, 1, 1, "flower")
    m.rect(26, 19, 1, 1, "sign")
    m.exit("e", 12, 15, "vila")
    m.points["pesca"] = (26, 13)
    m.default = (30, 14)
    return m


def jardim():
    m = Map("jardim", 36, 28, seed=9)
    forest_border(m, [("w", 12, 15)])
    m.rect(0, 12, 12, 4, "sand")
    m.rect(10, 6, 20, 1, "fence"); m.rect(10, 21, 20, 1, "fence")
    m.rect(10, 6, 1, 6, "fence"); m.rect(10, 16, 1, 6, "fence"); m.rect(29, 6, 1, 16, "fence")
    # Canteiros: seis quadrados de terra (2x2) dentro da cerca.
    plots = []
    for i in range(6):
        x, y = 13 + (i % 3) * 5, 9 + (i // 3) * 6
        m.rect(x, y, 2, 2, "sand")
        plots.append((x + 1, y + 1))
    m.points.update({"canteiro%d" % i: p for i, p in enumerate(plots)})
    for x in range(12, 28, 3): m.rect(x, 7, 1, 1, "flower"); m.rect(x + 1, 20, 1, 1, "flower")
    m.rect(30, 2, 4, 4, "forest"); m.rect(30, 22, 4, 4, "forest")
    m.rect(9, 11, 1, 1, "sign")
    m.exit("w", 12, 15, "vila")
    m.npcs = [{"name": "Lia", "sprite": "gardener", "x": 8, "y": 9}]
    m.default = (4, 14)
    return m


def safari():
    m = Map("safari", 40, 32, seed=11)
    forest_border(m, [("w", 14, 17)])
    m.rect(0, 14, 10, 4, "sand")
    m.rect(4, 4, 14, 8, "tall"); m.rect(22, 4, 14, 10, "tall"); m.rect(12, 20, 20, 8, "tall")
    m.rect(26, 16, 8, 3, "water")
    for (x, y) in [(18, 14), (20, 14), (6, 22), (34, 24)]: m.rect(x, y, 2, 2, "forest")
    m.rect(10, 13, 1, 1, "sign")
    m.exit("w", 14, 17, "rota")
    m.default = (4, 16)
    return m


def main():
    maps = [vila(), rota(), lago(), jardim(), safari()]
    secondary = "viridian_city"
    learned = learn("frlg", secondary, ["Route1", "Route2", "Route22", "ViridianCity", "Route21_North"])
    learned["sand"] = {k: v for k, v in learned["sand"].items() if v in {211, 212, 213, 219, 220, 221, 227, 228, 229, 258, 259, 260, 261}}
    pair = Pair("frlg", "general", secondary)
    built = {m.name: m.build(learned) for m in maps}
    used = sorted({i for ids, _ in built.values() for row in ids for i in row})
    index = {m: k for k, m in enumerate(used)}
    cols = 32
    rows = (len(used) + cols - 1) // cols
    below = Image.new("RGBA", (cols * 16, rows * 16), (0, 0, 0, 0))
    above = Image.new("RGBA", (cols * 16, rows * 16), (0, 0, 0, 0))
    has_above = set()
    for m_id, k in index.items():
        lo, hi = pair.layers(m_id)
        below.paste(lo, ((k % cols) * 16, (k // cols) * 16))
        above.paste(hi, ((k % cols) * 16, (k // cols) * 16))
        if hi.getbbox():
            has_above.add(k)
    cdir = os.path.join(ROOT, "client/assets/maps"); os.makedirs(cdir, exist_ok=True)
    sdir = os.path.join(ROOT, "server/maps"); os.makedirs(sdir, exist_ok=True)
    below.save(os.path.join(cdir, "kanto_below.png")); above.save(os.path.join(cdir, "kanto_above.png"))
    for m in maps:
        ids, cell = built[m.name]
        tiles = [index[i] for row in ids for i in row]
        client = {"w": m.w, "h": m.h, "cell": CELL, "atlas": "kanto", "columns": cols,
                  "tiles": tiles, "above": [t if t in has_above else -1 for t in tiles],
                  "npcs": [dict(n, x=(n["x"] + .5) * CELL, y=(n["y"] + .9) * CELL) for n in m.npcs],
                  "points": {k: [(v[0] + .5) * CELL, (v[1] + .5) * CELL] for k, v in m.points.items()},
                  "default": [m.default[0] * CELL, m.default[1] * CELL]}
        json.dump(client, open(os.path.join(cdir, m.name + ".json"), "w"), separators=(",", ":"))
        server = {"w": m.w, "h": m.h, "cell": CELL, "cells": "".join("".join(r) for r in cell),
                  "warps": m.warps, "spawns": {k: [v[0] * CELL, v[1] * CELL] for k, v in m.spawns.items()},
                  "points": {k: [(v[0] + .5) * CELL, (v[1] + .5) * CELL] for k, v in m.points.items()},
                  "npcs": [{"name": n["name"], "x": (n["x"] + .5) * CELL, "y": (n["y"] + .9) * CELL} for n in m.npcs],
                  "default": [m.default[0] * CELL, m.default[1] * CELL]}
        json.dump(server, open(os.path.join(sdir, m.name + ".json"), "w"), separators=(",", ":"))
        # Prévia para revisão.
        img = Image.new("RGBA", (m.w * 16, m.h * 16))
        for j in range(m.h):
            for i in range(m.w):
                lo, hi = pair.layers(ids[j][i]); img.alpha_composite(lo, (i * 16, j * 16)); img.alpha_composite(hi, (i * 16, j * 16))
        os.makedirs("/tmp/claude-0/maps", exist_ok=True)
        img.save("/tmp/claude-0/maps/%s.png" % m.name)
    print(len(used), "metatiles")


if __name__ == "__main__":
    main()
