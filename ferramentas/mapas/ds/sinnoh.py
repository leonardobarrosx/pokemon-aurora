"""Importa Sinnoh (pret/pokeplatinum) para Aurora, no mesmo formato de Johto.

O Platinum guarda quase tudo em arquivos soltos e JSON: matrizes em
res/field/maps/groups.json, cabeçalhos e eventos por pasta de mapa, terreno em
res/field/mapmodels, prédios em res/field/props e sprites de NPC em PNG.

Uso: python3 sinnoh.py x <raiz do Aurora> [--skip-world]
"""
import glob, json, os, re, sys
from collections import deque
import numpy as np
from PIL import Image
from nitro import textures
from raster import K
from scene import Game
import ds_region as R

PT = os.environ.get("PT_ROOT", "/home/claude/ext/pokeplatinum")
ROOT = sys.argv[2] if len(sys.argv) > 2 else os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
CELL, CH = 32, 512
PREFIX, WORLD = "sn_", "sn_sinnoh"
SPECIES = R.SPECIES
CITIES = {"TWINLEAF_TOWN": "Twinleaf Town", "SANDGEM_TOWN": "Sandgem Town", "JUBILIFE_CITY": "Jubilife City",
          "OREBURGH_CITY": "Oreburgh City", "FLOAROMA_TOWN": "Floaroma Town", "ETERNA_CITY": "Eterna City",
          "HEARTHOME_CITY": "Hearthome City", "SOLACEON_TOWN": "Solaceon Town", "VEILSTONE_CITY": "Veilstone City",
          "PASTORIA_CITY": "Pastoria City", "CELESTIC_TOWN": "Celestic Town", "CANALAVE_CITY": "Canalave City",
          "SNOWPOINT_CITY": "Snowpoint City", "SUNYSHORE_CITY": "Sunyshore City", "POKEMON_LEAGUE": "Pokémon League",
          "FIGHT_AREA": "Fight Area", "SURVIVAL_AREA": "Survival Area", "RESORT_AREA": "Resort Area"}


def nice(hid):
    base = hid.replace("MAP_HEADER_", "")
    for k, v in CITIES.items():
        if base.startswith(k):
            rest = base[len(k):].strip("_")
            return v + (" " + R.nice("MAP_" + rest) if rest else "")
    return R.nice("MAP_" + base)


class PtGame(Game):
    """Mesma interface do Game do HeartGold, lendo os arquivos soltos do Platinum."""

    def __init__(self):
        base = PT + "/res/field/"
        self.land = [open(base + "mapmodels/data/" + l.strip(), "rb").read()
                     for l in open(base + "mapmodels/data/map_data.order") if l.strip()]
        order = [l.strip() for l in open(base + "props/models/map_prop_models.order") if l.strip()]
        self.bmodels = [open(base + "props/models/" + n, "rb").read() for n in order]
        self.maptex = sorted(glob.glob(base + "mapmodels/texture_sets/map_texture_set_*.nsbtx"))
        self.btex = sorted(glob.glob(base + "props/texture_sets/prop_texture_set_*.nsbtx"))
        self.areas = []
        self._models, self._banks, self._tex = {}, {}, {}

    def area(self, name):
        d = json.load(open(PT + "/res/field/area_data/%s.json" % name))
        return int(d["mapPropSet"][-3:]), int(d["mapTextureSet"][-3:])

    def bank(self, kind, idx):
        key = (kind, idx)
        if key not in self._banks:
            src = self.maptex if kind == "map" else self.btex
            self._banks[key] = textures(open(src[idx], "rb").read()) if 0 <= idx < len(src) else None
        return self._banks[key]


def headers():
    hdr = {}
    for p in glob.glob(PT + "/res/field/maps/*/header.json"):
        folder = os.path.basename(os.path.dirname(p))
        d = json.load(open(p))
        d["folder"] = folder
        hdr["MAP_HEADER_" + folder.upper()] = d
    return hdr


def events(hdr, hid):
    p = PT + "/res/field/maps/%s/events.json" % hdr[hid]["folder"]
    return json.load(open(p)) if os.path.exists(p) else {}


def encounters(hdr, hid):
    p = PT + "/res/field/maps/%s/encounters.json" % hdr[hid]["folder"]
    if not os.path.exists(p):
        return [], []
    d = json.load(open(p))
    pick = lambda mons: sorted({SPECIES[m["species"].replace("SPECIES_", "")] for m in mons
                                if isinstance(m, dict) and str(m.get("species", "")).replace("SPECIES_", "") in SPECIES})
    return pick(d.get("land_encounters", [])), pick(d.get("surf_encounters", []))


def land_index(name):
    return int(name.replace("MAP_", "")) if name.startswith("MAP_") and name[4:].isdigit() else None


def sprite_sheet(gfx, dest):
    name = gfx.replace("OBJ_EVENT_GFX_", "").lower()
    found = glob.glob(PT + "/res/graphics/field_sprites/*/%s.png" % name)
    if not found:
        return False
    src = Image.open(found[0]).convert("RGBA")
    fw = src.width
    n = src.height // fw
    frames = [src.crop((0, i * fw, fw, (i + 1) * fw)) for i in range(n)] or [src]
    # Cor 0 da paleta indexada é o fundo.
    raw = Image.open(found[0])
    if raw.mode == "P":
        key = tuple(raw.getpalette()[:3])
        for f in frames:
            px = np.array(f)
            mask = (px[..., 0] == key[0]) & (px[..., 1] == key[1]) & (px[..., 2] == key[2])
            px[mask] = 0
            f.paste(Image.fromarray(px))
    get = lambda i: frames[i] if i < len(frames) else frames[0]
    if n >= 16:
        rows = [[get(4), get(5), get(6), get(7)], [get(8), get(9), get(10), get(11)],
                [get(12), get(13), get(14), get(15)], [get(0), get(1), get(2), get(3)]]
    else:
        rows = [[get(0)] * 4] * 4
    cell = 64
    out = Image.new("RGBA", (cell * 4, cell * 4))
    for r, row in enumerate(rows):
        for c, fr in enumerate(row):
            fr = fr.resize((fr.width * 2, fr.height * 2), Image.NEAREST)
            if fr.width > cell or fr.height > cell:
                fr = fr.crop(((fr.width - cell) // 2, fr.height - cell, (fr.width + cell) // 2, fr.height))
            out.paste(fr, (c * cell + (cell - fr.width) // 2, r * cell + cell - fr.height), fr)
    out.save(dest)
    return True


def main():
    hdr = headers()
    groups = {g["id"]: g for g in json.load(open(PT + "/res/field/maps/groups.json"))}
    g = PtGame()
    cdir = os.path.join(ROOT, "client/assets/maps"); sdir = os.path.join(ROOT, "server/maps")
    world = groups["TownsAndRoutes"]
    mh, mw = len(world["maps"]), len(world["maps"][0])
    cell_hdr = lambda x, y: world["headers"][y][x]
    cells_all = [(x, y) for y in range(mh) for x in range(mw) if land_index(world["maps"][y][x]) is not None]
    named = [(x, y) for x, y in cells_all if cell_hdr(x, y) != "MAP_HEADER_EVERYWHERE" and cell_hdr(x, y) in hdr]
    bx0, bx1 = min(x for x, _ in named), max(x for x, _ in named)
    by0, by1 = min(y for _, y in named), max(y for _, y in named)
    world_headers = {cell_hdr(x, y) for x, y in named}
    area_of = {h: WORLD for h in world_headers}
    queue, seen = deque(world_headers), set(world_headers)
    while queue:
        hid = queue.popleft()
        for wv in events(hdr, hid).get("warp_events", []):
            dest = wv.get("dest_header_id")
            if dest not in hdr or dest in seen:
                continue
            seen.add(dest)
            if hdr[dest].get("mapGroup") == "TownsAndRoutes":
                continue
            if any(k in dest for k in ("UNDERGROUND", "UNION", "BATTLE_TOWER", "DISTORTION", "TRADE")):
                continue
            area_of[dest] = PREFIX + dest.replace("MAP_HEADER_", "").lower()
            queue.append(dest)
    print(len(area_of), "mapas de Sinnoh;", len(set(area_of.values())), "áreas")
    W, H = bx1 - bx0 + 1, by1 - by0 + 1
    chunks = {}
    for x, y in cells_all:
        if bx0 <= x <= bx1 and by0 <= y <= by1:
            hid = cell_hdr(x, y)
            ad = hdr.get(hid, hdr["MAP_HEADER_TWINLEAF_TOWN"])["areaData"]
            chunks[(x - bx0, y - by0)] = (land_index(world["maps"][y][x]), ad)
    areas = {}
    cells = ["#"] * (W * 32 * H * 32)
    for (cx, cy), (li, _) in chunks.items():
        for i, v in enumerate(g.perms(li)):
            cells[(cy * 32 + i // 32) * W * 32 + cx * 32 + i % 32] = R.cell_code(v)
    hm = R.heights(g, chunks, W * 32, H * 32)
    imgs = None
    if "--skip-world" not in sys.argv:
        imgs = R.render_area(g, chunks, W, H, os.path.join(cdir, "sn", WORLD), grid=R.grid_of(cells, hm, W * 32, H * 32))
    zones, zone_info, zidx = [], [], {}
    for cy in range(H):
        for cx in range(W):
            hid = cell_hdr(cx + bx0, cy + by0)
            if hid not in zidx:
                zidx[hid] = len(zone_info)
                land, surf = encounters(hdr, hid) if hid in hdr else ([], [])
                zone_info.append({"name": nice(hid) if hid in hdr and hid != "MAP_HEADER_EVERYWHERE" else "Sinnoh",
                                  "encounters": land, "water": surf})
            zones.append(zidx[hid])
    areas[WORLD] = dict(w=W * 32, h=H * 32, cells=cells, heights=hm, zones=zones, zone_info=zone_info,
                        origin=(bx0 * 32, by0 * 32), imgs=dict(cols=W, rows=H, tiles=imgs, crop=None),
                        headers=world_headers, name="Sinnoh")
    for hid, area in sorted(area_of.items()):
        if area == WORLD:
            continue
        grp = groups.get(hdr[hid].get("mapGroup"))
        if not grp:
            continue
        h, w = len(grp["maps"]), len(grp["maps"][0])
        ch = {(x, y): (land_index(grp["maps"][y][x]), hdr[hid]["areaData"]) for y in range(h) for x in range(w)
              if land_index(grp["maps"][y][x]) is not None}
        if not ch:
            continue
        full = ["#"] * (w * 32 * h * 32)
        for (cx, cy), (li, _) in ch.items():
            for i, v in enumerate(g.perms(li)):
                full[(cy * 32 + i // 32) * w * 32 + cx * 32 + i % 32] = R.cell_code(v)
        fullh = R.heights(g, ch, w * 32, h * 32, with_objects=True)
        crop = R.render_area(g, ch, w, h, os.path.join(cdir, "sn", area), crop=True, grid=R.grid_of(full, fullh, w * 32, h * 32))
        if crop is None:
            continue
        x0, y0, x1, y1 = crop
        c0, r0 = x0 // 16, max(y0, 0) // 16
        c1, r1 = x1 // 16, min(y1, h * CH) // 16
        cw, chh = c1 - c0, r1 - r0
        land, surf = encounters(hdr, hid)
        areas[area] = dict(w=cw, h=chh, cells=[full[(r0 + y) * w * 32 + c0 + x] for y in range(chh) for x in range(cw)],
                           heights=fullh[r0:r1, c0:c1], origin=(c0, r0),
                           imgs=dict(crop=(x0 - c0 * 16, y0 - r0 * 16)), headers={hid}, name=nice(hid),
                           encounters=land, water=surf, cave=hdr[hid].get("mapType") == "MAP_TYPE_DUNGEON")
    hid_area = {h: a for a, d in areas.items() for h in d["headers"]}
    warps_of = {}
    for hid, area in hid_area.items():
        ox, oy = areas[area]["origin"]
        warps_of[hid] = [(wv["x"] - ox, wv["z"] - oy, wv) for wv in events(hdr, hid).get("warp_events", [])]
    for hid, area in hid_area.items():
        d = areas[area]
        for x, y, _ in warps_of[hid]:
            if 0 <= x < d["w"] and 0 <= y < d["h"]:
                d["cells"][y * d["w"] + x] = "."
    for d in areas.values():
        d["warps"], d["npcs"] = [], []
    chars = os.path.join(ROOT, "client/assets/characters/ds"); os.makedirs(chars, exist_ok=True)
    made = {}
    for hid, area in hid_area.items():
        d = areas[area]
        for x, y, wv in warps_of[hid]:
            dest = wv.get("dest_header_id")
            if dest not in hid_area or not (0 <= x < d["w"] and 0 <= y < d["h"]):
                continue
            to = hid_area[dest]
            dw = warps_of.get(dest, [])
            # O destino é o warp do mapa de destino com o id pedido.
            target = [t for t in dw if t[2].get("id") == wv.get("dest_warp_id")] or dw[:1]
            if not target:
                continue
            tx, ty, _ = target[0]
            dd = areas[to]
            for nx, ny in ((tx, ty + 1), (tx, ty - 1), (tx - 1, ty), (tx + 1, ty)):
                if 0 <= nx < dd["w"] and 0 <= ny < dd["h"] and dd["cells"][ny * dd["w"] + nx] in '."' and (nx, ny) not in {(a, b) for a, b, _ in dw}:
                    tx, ty = nx, ny
                    break
            d["warps"].append({"x": x, "y": y, "w": 1, "h": 1, "to": to, "tx": (tx + .5) * CELL, "ty": (ty + .7) * CELL})
        ox, oy = d["origin"]
        for o in events(hdr, hid).get("object_events", []):
            x, y = o["x"] - ox, o["z"] - oy
            gfx = o.get("graphics_id", "")
            if not (0 <= x < d["w"] and 0 <= y < d["h"]) or "VAR_" in gfx:
                continue
            name = "pt_" + gfx.replace("OBJ_EVENT_GFX_", "").lower()
            if name not in made:
                made[name] = sprite_sheet(gfx, os.path.join(chars, name + ".png"))
            if not made[name]:
                continue
            facing = {"DIR_SOUTH": 0, "DIR_WEST": 1, "DIR_EAST": 2, "DIR_NORTH": 3}.get(o.get("initial_dir"), 0)
            d["npcs"].append({"x": (x + .5) * CELL, "y": (y + .9) * CELL, "sprite": "ds/" + name, "name": "", "facing": facing})
    total = 0
    for area, d in areas.items():
        if area == WORLD and "--skip-world" in sys.argv:
            continue
        w, h = d["w"], d["h"]
        code = list("".join(d["cells"]))
        free = [(abs(x - w / 2) + abs(y - h / 2), x, y) for y in range(h) for x in range(w) if code[y * w + x] == "."]
        if area == WORLD:
            cs = [(i % W, i // W) for i, z in enumerate(d["zones"]) if d["zone_info"][z]["name"] == "Twinleaf Town"]
            if cs:
                cx, cy = cs[0]
                free = [(abs(x - cx * 32 - 16) + abs(y - cy * 32 - 18), x, y) for y in range(cy * 32, cy * 32 + 32)
                        for x in range(cx * 32, cx * 32 + 32) if code[y * w + x] == "."]
        default = [(w / 2) * CELL, (h / 2) * CELL]
        if free:
            _, fx, fy = min(free)
            default = [(fx + .5) * CELL, (fy + .7) * CELL]
        for n in d["npcs"]:
            i = int(n["y"] // CELL) * w + int(n["x"] // CELL)
            if 0 <= i < len(code):
                code[i] = "#"
        total += len(d["npcs"])
        server = {"w": w, "h": h, "cell": CELL, "cells": "".join(code), "warps": d["warps"], "connections": [],
                  "encounters": d.get("encounters", []), "water": d.get("water", []), "cave": d.get("cave", False),
                  "spawns": {}, "points": {}, "default": default, "name": d["name"]}
        if "zones" in d:
            server.update(zones=d["zones"], zone_info=d["zone_info"], chunk=32, zone_cols=W)
        json.dump(server, open(os.path.join(sdir, area + ".json"), "w"), separators=(",", ":"))
        client = {"w": w, "h": h, "cell": CELL, "name": d["name"], "region": "sinnoh", "default": default, "points": {},
                  "npcs": d["npcs"], "image": {"dir": "sn/" + area, "chunk": CH, "k": K,
                                               "cols": d["imgs"].get("cols", 1), "rows": d["imgs"].get("rows", 1),
                                               "tiles": d["imgs"].get("tiles"), "crop": d["imgs"].get("crop")},
                  "heights": np.round(d["heights"]).astype(int).reshape(-1).tolist()}
        if "zones" in d:
            client.update(zones=d["zones"], zone_names=[z["name"] for z in d["zone_info"]], chunk=32, zone_cols=W)
        json.dump(client, open(os.path.join(cdir, area + ".json"), "w"), separators=(",", ":"))
    print(len(areas), "áreas,", total, "NPCs,", sum(made.values()), "sprites")


if __name__ == "__main__":
    main()
