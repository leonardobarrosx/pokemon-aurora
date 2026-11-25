"""Importa regiões dos jogos de GBA para Aurora: Kanto (pret/pokefirered) e
Hoenn (cRz-Shadows/Pokemon_Emerald_Legacy).

Uso: python3 region.py kanto | hoenn

(Texto original:) Importa a região de Kanto do FireRed para Aurora.

Percorre os mapas a partir de Pallet Town seguindo as conexões de borda e as
portas (warps), e exporta cada mapa com as camadas, a colisão, os ressaltos,
a água, a grama alta, as portas e as conexões. As Ilhas Sevii ficam de fora
(só se chega lá de barco).

Saídas: client/assets/maps/kt_*.json + atlas kt_<tileset>_{below,above}.png
         server/maps/kt_*.json
"""
import json, os, struct
from collections import deque
from PIL import Image
from gba import GAMES, Pair, tileset_dir

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
REGIONS = {
    "kanto": {"game": "frlg", "start": "MAP_PALLET_TOWN", "prefix": "kt_",
              "skip": ("Island", "SeviiIsle", "Navel", "Birth", "Trainer_Tower", "TrainerTower", "Unused", "Prototype")},
    "hoenn": {"game": "rse", "start": "MAP_LITTLEROOT_TOWN", "prefix": "hn_",
              "skip": ("BattleFrontier", "Battle_Frontier", "SouthernIsland", "FarawayIsland", "BirthIsland", "NavelRock",
                       "MarineCave", "TerraCave", "ArtisanCave", "DesertUnderpass", "AlteringCave", "TrainerHill",
                       "Unused", "Prototype", "SecretBase", "InsideOfTruck", "BattleColosseum", "TradeCenter", "RecordCorner", "UnionRoom")},
}
CFG = REGIONS["kanto"]
FR = GAMES["frlg"]["root"]
GAME = "frlg"
CELL = 32

TALL = {0x02, 0x03, 0x07, 0x09, 0x24, 0xD1}  # grama alta, grama longa, grama de caverna
WATER_BY_GAME = {"frlg": {0x10, 0x11, 0x12, 0x13, 0x15, 0x1A, 0x1B}, "rse": {0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x18, 0x19}}
WATER = WATER_BY_GAME["frlg"]
JUMP = {0x38: ">", 0x39: "<", 0x3A: "^", 0x3B: "v"}

# Espécies que Aurora já tem (número nacional).
SPECIES = {"BULBASAUR": 1, "IVYSAUR": 2, "CHARMANDER": 4, "CHARMELEON": 5, "SQUIRTLE": 7, "WARTORTLE": 8,
           "PIDGEY": 16, "RATTATA": 19, "PIKACHU": 25, "RAICHU": 26, "ZUBAT": 41, "GEODUDE": 74, "GENGAR": 94,
           "ONIX": 95, "MAGIKARP": 129, "GYARADOS": 130, "LAPRAS": 131, "EEVEE": 133, "VAPOREON": 134,
           "JOLTEON": 135, "FLAREON": 136, "MEW": 151, "UMBREON": 197}


def area_id(map_id):
    return CFG["prefix"] + map_id.replace("MAP_", "").lower()


def nice_name(folder):
    out = ""
    for i, c in enumerate(folder.replace("_", " ")):
        if c.isupper() and i and out[-1] not in " " and (folder[i - 1].islower() or folder[i - 1].isdigit()):
            out += " "
        if c.isdigit() and i and folder[i - 1].isalpha():
            out += " "
        out += c
    out = out.replace("Route ", "Rota ").replace(" 1 F", " 1F")
    for a, b in [("Pokemon Center", "Centro Pokémon"), ("Players House", "Casa do Jogador"), ("Rivals House", "Casa do Rival"),
                 ("Professor Oaks Lab", "Laboratório do Prof. Oak"), ("Mart", "Loja"), ("Gym", "Ginásio"), ("House", "Casa"),
                 ("Mt Moon", "Mt. Moon"), ("Viridian Forest", "Floresta de Viridian"), ("Pokemon Tower", "Torre Pokémon"),
                 ("Safari Zone", "Zona Safári"), ("Underground Path", "Passagem Subterrânea"), ("Entrance", "Entrada"),
                 ("Department Store", "Loja de Departamentos"), ("Museum", "Museu"), ("School", "Escola"), ("Seafoam Islands", "Ilhas Seafoam")]:
        out = out.replace(a, b)
    return out


def main(region="kanto"):
    global CFG, FR, GAME, WATER
    CFG = REGIONS[region]
    GAME = CFG["game"]
    FR = GAMES[GAME]["root"]
    WATER = WATER_BY_GAME[GAME]
    TALL.discard(0x07) if GAME == "rse" else None
    maps = {}
    for folder in os.listdir(os.path.join(FR, "data/maps")):
        p = os.path.join(FR, "data/maps", folder, "map.json")
        if os.path.exists(p):
            d = json.load(open(p))
            d["folder"] = folder
            maps[d["id"]] = d
    layouts = {l["id"]: l for l in json.load(open(os.path.join(FR, "data/layouts/layouts.json")))["layouts"] if l}
    # Percorre Kanto a partir de Pallet Town.
    seen, queue = set(), deque([CFG["start"]])
    while queue:
        mid = queue.popleft()
        if mid in seen or mid not in maps:
            continue
        name = maps[mid]["folder"]
        if any(k in name for k in CFG["skip"]):
            continue
        seen.add(mid)
        d = maps[mid]
        for c in d.get("connections") or []:
            queue.append(c["map"])
        for w in d.get("warp_events") or []:
            if w["dest_map"] != "MAP_DYNAMIC":
                queue.append(w["dest_map"])
    print(len(seen), "mapas de", region)
    encounters = {}
    for group in json.load(open(os.path.join(FR, "src/data/wild_encounters.json")))["wild_encounter_groups"]:
        for e in group["encounters"]:
            if e.get("base_label", "").endswith("_FireRed") or "_LeafGreen" not in e.get("base_label", ""):
                for kind in ("land_mons", "water_mons"):
                    if kind in e:
                        ids = sorted({SPECIES[m["species"].replace("SPECIES_", "")] for m in e[kind]["mons"] if m["species"].replace("SPECIES_", "") in SPECIES})
                        encounters.setdefault(e.get("map", ""), {})[kind] = ids
    # Carrega cada mapa e agrupa por par de tilesets.
    loaded = {}
    pairs = {}
    for mid in seen:
        d = maps[mid]
        l = layouts[d["layout"]]
        raw = open(os.path.join(FR, l["blockdata_filepath"]), "rb").read()
        cells = list(struct.unpack("<%dH" % (len(raw) // 2), raw))
        key = (tileset_dir(l["primary_tileset"], GAME), tileset_dir(l["secondary_tileset"], GAME))
        if key not in pairs:
            try:
                pairs[key] = Pair(GAME, *key)
            except FileNotFoundError:
                pairs[key] = None
        if pairs[key] is None:
            continue  # tileset sem gráficos próprios na decompilação (ex.: Silph Co.)
        loaded[mid] = (d, l, cells, key)
    pairs = {k: v for k, v in pairs.items() if v}
    cdir = os.path.join(ROOT, "client/assets/maps"); sdir = os.path.join(ROOT, "server/maps")
    atlases = {}
    for key, pair in pairs.items():
        used = sorted({c & 0x3FF for (d, l, cells, k) in loaded.values() if k == key for c in cells})
        index = {m: i for i, m in enumerate(used)}
        cols = 32
        rows = (len(used) + cols - 1) // cols
        below = Image.new("RGBA", (cols * 16, rows * 16)); above = Image.new("RGBA", (cols * 16, rows * 16))
        has_above = set()
        for m, i in index.items():
            lo, hi = pair.layers(m)
            below.paste(lo, ((i % cols) * 16, (i // cols) * 16)); above.paste(hi, ((i % cols) * 16, (i // cols) * 16))
            if hi.getbbox():
                has_above.add(i)
        name = CFG["prefix"] + "%s__%s" % key
        below.save(os.path.join(cdir, name + "_below.png")); above.save(os.path.join(cdir, name + "_above.png"))
        atlases[key] = (name, index, has_above, cols)
    def cell_code(pair, c):
        m = c & 0x3FF
        b = pair.behavior(m)
        if b in JUMP:
            return JUMP[b]
        if b in WATER:
            return "~"
        if (c >> 10) & 3:
            return "#"
        if b in TALL:
            return '"'
        return "."
    codes = {}
    for mid, (d, l, cells, key) in loaded.items():
        row = [cell_code(pairs[key], c) for c in cells]
        # Portas e escadas têm colisão no GBA (o jogo trata pelo comportamento);
        # aqui a célula da passagem precisa ser pisável.
        for wv in d.get("warp_events") or []:
            i = wv["y"] * l["width"] + wv["x"]
            if 0 <= i < len(row):
                row[i] = "."
        codes[mid] = "".join(row)
    for mid, (d, l, cells, key) in loaded.items():
        w, h = l["width"], l["height"]
        name, index, has_above, cols = atlases[key]
        tiles = [index[c & 0x3FF] for c in cells]
        area = area_id(mid)
        cave = d.get("map_type") == "MAP_TYPE_UNDERGROUND"
        warps = []
        for wi, wv in enumerate(d.get("warp_events") or []):
            to = wv["dest_map"]
            if to == "MAP_DYNAMIC":
                warps.append({"x": wv["x"], "y": wv["y"], "w": 1, "h": 1, "to": "@voltar"})
                continue
            if to not in loaded:
                continue
            dd, dl, dcells, dkey = loaded[to]
            dws = dd.get("warp_events") or []
            k = int(wv["dest_warp_id"]) if str(wv["dest_warp_id"]).isdigit() else 0
            if k >= len(dws):
                continue
            tx, ty = dws[k]["x"], dws[k]["y"]
            # Chega ao lado da porta, numa célula livre (abaixo ou acima).
            dcode = codes[to]
            warp_cells = {(x["x"], x["y"]) for x in dws}
            dw, dh = dl["width"], dl["height"]
            for nx, ny in ((tx, ty + 1), (tx, ty - 1), (tx - 1, ty), (tx + 1, ty)):
                if 0 <= nx < dw and 0 <= ny < dh and dcode[ny * dw + nx] in '."' and (nx, ny) not in warp_cells:
                    tx, ty = nx, ny
                    break
            warps.append({"x": wv["x"], "y": wv["y"], "w": 1, "h": 1, "to": area_id(to), "tx": (tx + .5) * CELL, "ty": (ty + .7) * CELL})
        conns = []
        for c in d.get("connections") or []:
            if c["map"] in loaded and c["direction"] in ("up", "down", "left", "right"):
                ol = loaded[c["map"]][1]
                conns.append({"dir": c["direction"], "offset": c["offset"], "to": area_id(c["map"]), "w": ol["width"], "h": ol["height"]})
        enc = encounters.get(mid, {})
        land = enc.get("land_mons") or ([41, 74, 95] if cave else [16, 19, 25, 133] if enc else [])
        server = {"w": w, "h": h, "cell": CELL, "cells": codes[mid], "warps": warps, "connections": conns,
                  "encounters": land, "water": enc.get("water_mons") or [], "cave": cave, "spawns": {}, "points": {},
                  "default": [(w / 2) * CELL, (h / 2 + .5) * CELL], "name": nice_name(d["folder"])}
        # Ponto de chegada padrão numa célula livre perto do centro.
        free = [(abs(x - w / 2) + abs(y - h / 2), x, y) for y in range(h) for x in range(w) if codes[mid][y * w + x] == "."]
        if free:
            _, fx, fy = min(free)
            server["default"] = [(fx + .5) * CELL, (fy + .7) * CELL]
        json.dump(server, open(os.path.join(sdir, area + ".json"), "w"), separators=(",", ":"))
        border = []
        if l.get("border_filepath") and os.path.exists(os.path.join(FR, l["border_filepath"])):
            braw = open(os.path.join(FR, l["border_filepath"]), "rb").read()
            border = [index.get(c & 0x3FF, -1) for c in struct.unpack("<%dH" % (len(braw) // 2), braw)]
            if any(b < 0 for b in border):
                border = []
        client = {"w": w, "h": h, "cell": CELL, "atlas": name, "columns": cols, "tiles": tiles, "border": border,
                  "above": [t if t in has_above else -1 for t in tiles], "npcs": [], "points": {},
                  "default": server["default"], "name": server["name"], "region": region}
        json.dump(client, open(os.path.join(cdir, area + ".json"), "w"), separators=(",", ":"))
    index = {area_id(m): loaded[m][0]["folder"] for m in loaded}
    json.dump({"areas": sorted(index), "names": {a: nice_name(f) for a, f in index.items()}},
              open(os.path.join(cdir, region + "_index.json"), "w"), ensure_ascii=False, indent=0)
    print(len(pairs), "pares de tilesets")


if __name__ == "__main__":
    import sys
    main(sys.argv[1] if len(sys.argv) > 1 else "kanto")
