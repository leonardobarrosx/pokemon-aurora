"""Gera as texturas das arenas dos ginásios a partir da arte que o jogo já tem.

Para cada ginásio saem dois arquivos em client/assets/stadiums/:

  <id>.png        chão: uma linha por tipo de terreno (na ordem de ORDER, a
                  mesma de client/arena_draw.gd), 4 variações por linha, em
                  casas de 32px (tiles de 16px ampliados).
  <id>_props.png  obstáculos: uma linha por tipo (PROPS), 2 variações, cada
                  uma numa casa de 64x64, apoiada no fundo e centrada (o que
                  passa da casa do obstáculo fica por cima dos Pokémon).

Nada é desenhado do zero: cada terreno é recortado dos mapas do FireRed e do
Emerald que o cliente já carrega (client/assets/maps) ou dos sprites de objeto
dos decomps (pedra do Rock Smash, árvore do Cut, estátua, fóssil). Quando o
jogo não tem o terreno (lama, veneno, teia, vento...), ele é derivado de um
tile real: recolorido, escurecido ou com um detalhe por cima. O piso principal
continua vindo do mapa original do próprio ginásio.
"""
import colorsys
import json
import random
import re
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "client/assets/maps"
SRV = ROOT / "server"
OUT = ROOT / "client/assets/stadiums"
EXT = ROOT.parent
OBJ_FR = EXT / "ext/pokefirered/graphics/object_events/pics/misc"
OBJ_EM = EXT / "crz-shadows/pokemon_emerald_legacy/graphics/object_events/pics/misc"
ORDER = ".,smnMbpkwuW_><^vijgoXflexVY}{)(zRTGOALC|"
PROPS = "rqhItPFT~"
VARIANTS = 4
T = 32

# ---------------------------------------------------------------- recortes


class Maps:
    cache = {}

    @classmethod
    def load(cls, name):
        if name not in cls.cache:
            m = json.loads((MAPS / f"{name}.json").read_text())
            below = Image.open(MAPS / f"{m['atlas']}_below.png").convert("RGBA")
            ap = MAPS / f"{m['atlas']}_above.png"
            above = Image.open(ap).convert("RGBA") if ap.exists() else None
            cls.cache[name] = (m, below, above)
        return cls.cache[name]


def grab(name, x, y, layers="ba"):
    """O tile (x,y) do mapa `name`, com as camadas de baixo e de cima."""
    m, below, above = Maps.load(name)
    t = Image.new("RGBA", (16, 16))
    cols, i = m["columns"], y * m["w"] + x
    for key, atlas, layer in (("b", below, m["tiles"]), ("a", above, m.get("above") or [])):
        if key not in layers or atlas is None or i >= len(layer) or layer[i] is None or layer[i] < 0:
            continue
        k = layer[i]
        t.alpha_composite(atlas.crop(((k % cols) * 16, (k // cols) * 16, (k % cols) * 16 + 16, (k // cols) * 16 + 16)))
    return t


def column(name, x, y0, n=2, layers="ba"):
    """Uma coluna de n tiles (16 x 16n), de cima para baixo."""
    out = Image.new("RGBA", (16, 16 * n))
    for k in range(n):
        out.alpha_composite(grab(name, x, y0 + k, layers), (0, 16 * k))
    return out


def obj(path, frame=0, h=16):
    """Quadro de um sprite de objeto (a cor 0 da paleta é transparente)."""
    im = Image.open(path)
    if im.mode == "P":
        im.info["transparency"] = 0
    im = im.convert("RGBA")
    return im.crop((frame * 16, 0, frame * 16 + 16, h))


def block(name, x0, y0, w, h, layers="ba"):
    out = Image.new("RGBA", (16 * w, 16 * h))
    for y in range(h):
        for x in range(w):
            out.alpha_composite(grab(name, x0 + x, y0 + y, layers), (16 * x, 16 * y))
    return out


def keyout(img, *bgs):
    """Tira do recorte o chão em volta, deixando só o objeto: apaga as cores
    do chão que se ligam à borda do recorte (o contorno escuro do objeto
    segura o preenchimento, então o miolo de mesma cor fica)."""
    cols = set()
    for bg in bgs:
        cols |= {p[:3] for p in bg.getdata()}
    out = img.copy()
    px = out.load()
    w, h = out.size
    seen = set()
    todo = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while todo:
        x, y = todo.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if px[x, y][3] and px[x, y][:3] not in cols:
            continue
        px[x, y] = (0, 0, 0, 0)
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return out


def recolor(img, hue=None, sat=None, k=1.0, toward=None, amount=0.0):
    """Recolore um tile real: gira o matiz, ajusta saturação e brilho."""
    out = img.copy()
    px = out.load()
    for y in range(out.size[1]):
        for x in range(out.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if hue is not None:
                h = hue / 360
            if sat is not None:
                s = min(1, s * sat)
            l = min(1, l * k)
            r, g, b = (int(v * 255) for v in colorsys.hls_to_rgb(h, l, s))
            if toward:
                r, g, b = (int(c * (1 - amount) + t * amount) for c, t in zip((r, g, b), toward))
            px[x, y] = (r, g, b, a)
    return out


def blend(a, b, k):
    return Image.blend(a.convert("RGBA"), b.convert("RGBA"), k)


def over(base, fn):
    t = base.copy()
    fn(ImageDraw.Draw(t), random.Random(id(fn)))
    return t


def avg(t):
    px = [p for p in t.convert("RGBA").getdata() if p[3] > 0]
    n = max(1, len(px))
    return tuple(sum(p[i] for p in px) // n for i in range(3))


# ---------------------------------------------------------------- biblioteca
# Coordenadas (mapa, x, y) conferidas nos mapas renderizados.

def lib():
    g = grab
    L = {}
    L["wood"] = [g("kt_pallet_town_players_house_1f", x, y) for x, y in ((8, 7), (9, 7), (8, 8), (9, 8))]
    L["sand"] = [g("kt_route1", 11, 1), g("kt_route1", 12, 1), g("kt_route24", 6, 8), g("kt_route24", 8, 8)]
    L["cave_sand"] = [g("kt_mt_moon_1f", 3, 3), g("kt_mt_moon_1f", 4, 3), g("kt_mt_moon_1f", 3, 4), g("kt_mt_moon_1f", 4, 2)]
    L["cave"] = [g("kt_mt_moon_1f", 8, 10), g("kt_mt_moon_1f", 9, 10), g("kt_mt_moon_1f", 8, 11), g("kt_mt_moon_1f", 9, 11)]
    L["snow"] = [g("kt_four_island_icefall_cave_1f", x, y) for x, y in ((0, 0), (1, 1), (2, 0), (1, 2))]
    L["ice_cave"] = [g("kt_four_island_icefall_cave_1f", x, y) for x, y in ((7, 7), (8, 7), (9, 8), (10, 9 - 1))]
    L["metal"] = [g("kt_power_plant", x, y) for x, y in ((4, 11), (5, 11), (4, 12), (5, 12))]
    L["bridge"] = [g("kt_route24", 11, y) for y in (21, 22, 23, 24)]
    L["platform"] = [g("kt_cerulean_city_gym", x, y) for x, y in ((7, 7),) * 4]
    L["pool"] = [g("kt_cerulean_city_gym", x, y) for x, y in ((4, 6), (5, 6), (4, 9), (3, 12))]
    L["sea"] = [g("kt_route24", x, y) for x, y in ((21, 32), (22, 33), (21, 34), (22, 35))]
    L["pond"] = [g("kt_route24", x, y) for x, y in ((6, 34), (7, 35), (6, 36), (7, 37))]
    L["spring"] = [g("hn_lavaridge_town", x, y) for x, y in ((4, 4), (5, 4), (4, 3), (5, 3))]
    L["ice"] = [g("hn_sootopolis_city_gym_1f", x, y) for x, y in ((3, 7), (4, 7), (5, 7), (6, 7))]
    L["tall"] = [g("kt_route1", x, y) for x, y in ((12, 7), (13, 7), (12, 8), (14, 8))]
    L["grass"] = [g("kt_route1", x, y) for x, y in ((3, 3), (4, 3), (5, 2), (6, 3))]
    L["garden"] = [g("kt_celadon_city_gym", x, y) for x, y in ((2, 5), (3, 5), (5, 4), (6, 5))]
    L["flowers"] = [g("kt_route1", 3, 6), g("hn_lavaridge_town", 12, 4), g("kt_route1", 2, 7), g("hn_lavaridge_town", 13, 4)]
    L["garden_flowers"] = [g("kt_celadon_city_gym", 4, 5), g("kt_celadon_city_gym", 5, 6), g("kt_celadon_city_gym", 6, 6), g("kt_celadon_city_gym", 7, 6)]
    L["volcanic"] = [g("hn_magma_hideout_4f", x, y) for x, y in ((8, 6), (9, 6), (7, 7), (11, 5))]
    L["lava"] = [g("hn_magma_hideout_4f", x, y) for x, y in ((16, 12), (16, 13), (15, 13), (16, 14))]
    L["elec_floor"] = [g("hn_mauville_city_gym", x, y) for x, y in ((4, 9), (5, 9), (4, 12), (5, 11))]
    L["bolt"] = [g("hn_mauville_city_gym", 3, 9), g("hn_mauville_city_gym", 4, 12), g("hn_mauville_city_gym", 8, 9), g("hn_mauville_city_gym", 0, 15)]
    L["pad"] = [g("kt_saffron_city_gym", 1, 4), g("kt_saffron_city_gym", 8, 4), g("kt_saffron_city_gym", 12, 4), g("kt_saffron_city_gym", 16, 4)]
    L["window"] = [g("kt_celadon_city_gym", 4, 1), g("kt_celadon_city_gym", 5, 1), g("kt_celadon_city_gym", 7, 1), g("kt_celadon_city_gym", 8, 1)]
    L["seats"] = [g("hn_battle_frontier_battle_dome_battle_room", x, y) for x, y in ((0, 0), (1, 0), (3, 1), (4, 0))]
    L["banner"] = [g("hn_battle_frontier_battle_dome_battle_room", x, 2) for x in (0, 1, 3, 4)]
    L["mat_red"] = [g("kt_pallet_town_players_house_1f", 4, 8), g("kt_pallet_town_players_house_1f", 5, 8)]
    L["pool_tiles"] = [g("kt_cerulean_city_gym", 1, y) for y in (9, 10, 11, 12)]
    # Paredes: topo (rocha/telhado) e face (a parede vista de frente).
    L["wall_cave"] = [g("kt_mt_moon_1f", x, 0) for x in (2, 3, 4, 5)]
    L["face_cave"] = [g("kt_mt_moon_1f", x, 1) for x in (3, 4, 5, 3)]
    L["wall_mount"] = [g("kt_route24", 1, y) for y in (20, 22, 24, 26)]
    L["wall_volcano"] = [g("hn_magma_hideout_4f", x, 0) for x in (12, 13, 14, 15)]
    L["face_volcano"] = [g("hn_magma_hideout_4f", x, 1) for x in (12, 13, 14, 15)]
    L["wall_ice"] = [g("kt_four_island_icefall_cave_1f", x, 0) for x in (8, 9, 10, 11)]
    L["face_ice"] = [g("kt_four_island_icefall_cave_1f", x, 1) for x in (6, 7, 6, 7)]
    L["wall_plant"] = [g("kt_power_plant", x, 2) for x in (4, 5, 6, 7)]
    L["face_plant"] = [g("kt_power_plant", x, 8) for x in (5, 6, 7, 8)]
    return L


def props():
    """Sprites dos obstáculos com transparência, de até 32x32 (base embaixo)."""
    P = {}
    P["rock"] = [obj(OBJ_FR / "rock_smash_rock.png", 0), obj(OBJ_EM / "breakable_rock.png", 0)]
    P["cracked"] = [obj(OBJ_FR / "rock_smash_rock.png", 1), obj(OBJ_EM / "breakable_rock.png", 1)]
    P["boulder"] = [obj(OBJ_FR / "strength_boulder.png", 0), obj(OBJ_EM / "pushable_boulder.png", 0)]
    P["cut"] = [obj(OBJ_FR / "cut_tree.png", 0), obj(OBJ_EM / "cuttable_tree.png", 0)]
    P["statue"] = [obj(OBJ_EM / "statue.png", 0, 32)] * 2
    P["fossil"] = [obj(OBJ_FR / "fossil.png", 0), obj(OBJ_EM / "fossil.png", 0)]
    grass = [grab("kt_route1", x, y) for x, y in ((4, 13), (5, 14))]
    lava_grass = [grab("hn_lavaridge_town", x, y) for x, y in ((8, 7), (7, 8))]
    P["tree"] = [keyout(block("kt_route1", 2, 14, 2, 2), *grass), keyout(block("hn_lavaridge_town", 12, 5, 2, 2), *lava_grass)]
    ice_bg = [grab("kt_four_island_icefall_cave_1f", x, y) for x, y in ((8, 7), (8, 8))]
    P["ice_pillar"] = [keyout(column("kt_four_island_icefall_cave_1f", 5, 9), *ice_bg)] * 2
    P["ice_rock"] = [keyout(grab("kt_four_island_icefall_cave_1f", 7, 7), *ice_bg),
                     keyout(grab("hn_sootopolis_city_gym_1f", 5, 6), grab("hn_sootopolis_city_gym_1f", 4, 7), grab("hn_sootopolis_city_gym_1f", 5, 7))]
    elec_bg = [grab("hn_mauville_city_gym", x, y) for x, y in ((4, 9), (5, 9), (4, 12), (5, 11), (2, 11), (2, 10), (4, 10), (4, 11))]
    P["tesla"] = [keyout(column("hn_mauville_city_gym", 3, 10), *elec_bg), keyout(column("hn_mauville_city_gym", 6, 10), *elec_bg)]
    P["console"] = [column("kt_power_plant", 29, 14), column("kt_power_plant", 28, 14)]
    volc = [grab("hn_magma_hideout_4f", x, y) for x, y in ((8, 6), (9, 6), (7, 7), (11, 5), (9, 5), (10, 5))]
    P["drill"] = [keyout(block("hn_magma_hideout_4f", 9, 3, 2, 2), *volc), keyout(block("hn_magma_hideout_4f", 12, 2, 2, 2), *volc)]
    P["waterfall"] = [block("hn_sootopolis_city_gym_1f", 4, 1, 2, 2)] * 2
    return P


def decor():
    """Peças grandes de decoração: nome -> (sprite, largura e altura da base
    em casas). A base é a parte que ocupa o chão; o resto sobe por cima."""
    D = {}
    lab = "kt_cinnabar_island_pokemon_lab_experiment_room"
    lab_floor = [grab(lab, 6, 3), grab(lab, 7, 3), grab(lab, 8, 4)]
    D["lab_machine"] = (keyout(block(lab, 12, 0, 2, 3), *lab_floor), 2, 2)
    D["lab_shelf"] = (block(lab, 3, 0, 3, 3), 3, 2)
    D["lab_desk"] = (keyout(block(lab, 2, 3, 3, 2), *lab_floor), 3, 1)
    mus = "kt_pewter_city_museum_1f"
    D["fossil_case"] = (keyout(block(mus, 3, 3, 4, 3), grab(mus, 1, 3), grab(mus, 2, 4), grab(mus, 8, 6), grab(mus, 1, 5)), 4, 2)
    man = "kt_pokemon_mansion_1f"
    D["plant"] = (keyout(block(man, 19, 19, 1, 2), grab(man, 18, 19), grab(man, 18, 20), grab(man, 19, 21)), 1, 1)
    pyre = "hn_mt_pyre_summit"
    marker = keyout(block(pyre, 11, 21, 1, 2), grab(pyre, 10, 21), grab(pyre, 10, 22))
    D["lantern"] = (marker, 1, 1)
    D["lantern_violet"] = (recolor(marker, hue=285, sat=1.1), 1, 1)
    for name in ("cheri", "pecha", "oran"):
        D["berry_" + name] = (obj(OBJ_EM.parent / "berry_trees" / f"{name}.png", 4, 32), 1, 1)
    return D


def build_decor():
    D = decor()
    keys = sorted(D)
    width = sum(img.size[0] for img, _, _ in D.values()) * 2 + 4 * len(keys)
    height = max(img.size[1] for img, _, _ in D.values()) * 2
    sheet = Image.new("RGBA", (width, height))
    meta, x = {}, 0
    for k in keys:
        img, fw, fh = D[k]
        big = img.resize((img.size[0] * 2, img.size[1] * 2), Image.NEAREST)
        sheet.alpha_composite(big, (x, 0))
        meta[k] = {"src": [x, 0, big.size[0], big.size[1]], "foot": [fw, fh]}
        x += big.size[0] + 4
    sheet.save(OUT / "decor.png")
    (OUT / "decor.json").write_text(json.dumps(meta, indent=1))
    return meta


# ---------------------------------------------------------------- derivados

def arrows(base, kind):
    def fn(d, _):
        c = (200, 232, 255, 255)
        pts = {">": [(4, 8), (11, 8), (8, 5), (8, 11)], "<": [(11, 8), (4, 8), (7, 5), (7, 11)],
               "^": [(8, 11), (8, 4), (5, 7), (11, 7)], "v": [(8, 4), (8, 11), (5, 8), (11, 8)]}[kind]
        d.line(pts[0] + pts[1], fill=c)
        d.line(pts[1] + pts[2], fill=c)
        d.line(pts[1] + pts[3], fill=c)
    return over(base, fn)


def wind(base, kind, v):
    def fn(d, _):
        c = (240, 248, 255, 190)
        for y in (4, 11):
            d.line((2 + v, y, 11 + v % 2, y), fill=c)
            d.point((12 + v % 2, y - 1), fill=c)
    t = over(base, fn)
    if kind == "{":
        t = t.transpose(Image.FLIP_LEFT_RIGHT)
    elif kind == ")":
        t = t.rotate(-90)
    elif kind == "(":
        t = t.rotate(90)
    return t


def web(base):
    def fn(d, _):
        c = (238, 238, 242, 210)
        d.line((0, 0, 15, 15), fill=c)
        d.line((15, 0, 0, 15), fill=c)
        d.line((8, 0, 8, 15), fill=c)
        d.line((0, 8, 15, 8), fill=c)
        d.rectangle((4, 4, 12, 12), outline=c)
    return over(base, fn)


def cracks(base):
    def fn(d, _):
        c = (70, 110, 150, 255)
        d.line((3, 3, 7, 8, 6, 12, 10, 15), fill=c)
        d.line((7, 8, 13, 6), fill=c)
    return over(base, fn)


def hazard(base):
    def fn(d, _):
        for k in range(0, 16, 4):
            d.line((k, 14, k + 1, 14), fill=(232, 160, 40, 255))
            d.line((k, 15, k + 1, 15), fill=(232, 160, 40, 255))
    return over(base, fn)


def embers(base, v):
    def fn(d, r):
        r = random.Random(v)
        for _ in range(10):
            x, y = r.randrange(16), r.randrange(16)
            d.point((x, y), fill=r.choice([(255, 140, 40), (255, 210, 80), (200, 60, 20)]) + (255,))
    return over(recolor(base, k=.55, toward=(60, 30, 20), amount=.3), fn)


def vent(base):
    def fn(d, _):
        d.ellipse((2, 3, 13, 13), fill=(44, 40, 42, 255), outline=(110, 104, 100, 255))
        for y in (6, 8, 10):
            d.line((4, y, 11, y), fill=(120, 116, 112, 255))
    return over(base, fn)


def bolt(base):
    def fn(d, _):
        d.line((9, 1, 6, 7, 10, 8, 6, 14), fill=(255, 236, 90, 255))
    return over(base, fn)


def void(theme, v):
    t = Image.new("RGBA", (16, 16), (14, 18, 28, 255))
    if theme == "voador":
        t = Image.new("RGBA", (16, 16), (130, 182, 232, 255))
        d = ImageDraw.Draw(t)
        d.ellipse((1 + v, 5, 11 + v, 11), fill=(244, 248, 252, 255))
    return t


# ---------------------------------------------------------------- por tema

NATURAL = {"rocha", "terra", "lutador", "dragao", "voador", "inseto", "planta", "normal"}


def walls(theme, L):
    if theme in ("fogo",):
        return L["wall_volcano"], L["face_volcano"]
    if theme in ("gelo",):
        return L["wall_ice"], L["face_ice"]
    if theme in ("eletrico", "aco", "psiquico", "veneno", "fantasma", "agua"):
        return L["wall_plant"], L["face_plant"]
    return L["wall_cave"], L["face_cave"]


def ground_rows(theme, floor, L):
    """Lista de 4 tiles por terreno, para o tema."""
    four = lambda xs: (xs * 4)[:4]
    hot = theme in ("fogo", "dragao")
    cold = theme == "gelo"
    water = L["pool"] if theme == "agua" else L["sea"]
    shallow = [blend(t, w, .35) for t, w in zip(L["pool"], L["pond"])] if theme == "agua" else L["pond"]
    rows = {}
    rows["."] = floor
    rows[","] = L["wood"]
    rows["s"] = L["cave_sand"] if theme in ("rocha", "terra", "lutador") else L["sand"]
    rows["m"] = [recolor(t, k=.62, toward=(96, 72, 50), amount=.45) for t in L["sand"]]
    rows["n"] = L["snow"]
    # No laboratório vulcânico o metal é escuro (fuligem), como no conceito.
    rows["M"] = [recolor(t, k=.62, toward=(40, 40, 48), amount=.25) for t in L["metal"]] if hot else L["metal"]
    rows["b"] = L["bridge"]
    rows["p"] = L["platform"]
    rows["k"] = [hazard(t) for t in L["platform"]]
    rows["w"] = shallow
    rows["u"] = L["spring"]
    rows["W"] = water
    rows["_"] = [blend(w, p, .38) for w, p in zip(water, L["platform"])]
    for a in "><^v":
        rows[a] = [arrows(t, a) for t in water]
    rows["i"] = L["ice"]
    rows["j"] = [cracks(t) for t in rows["i"]]
    rows["g"] = L["tall"]
    rows["o"] = L["garden_flowers"] if theme in ("planta", "inseto") else L["flowers"]
    rows["X"] = [web(t) for t in floor]
    rows["f"] = [embers(t, v) for v, t in enumerate(L["volcanic"] if hot else floor)]
    rows["l"] = L["lava"]
    rows["e"] = L["bolt"]
    rows["x"] = [recolor(t, hue=285, sat=.8, k=.95) for t in L["sea"]]
    rows["V"] = [vent(t) for t in (L["metal"] if theme in ("fogo", "eletrico", "aco") else floor)]
    rows["Y"] = L["pad"]
    for a in "}{)(":
        rows[a] = [wind(t, a, v) for v, t in enumerate(floor)]
    rows["z"] = [bolt(t) for t in water]
    top, face = walls(theme, L)
    rows["R"] = top
    rows["T"] = L["metal"]
    rows["G"] = L["window"]
    rows["O"] = [void(theme, v) for v in range(4)]
    rows["A"] = L["seats"]
    rows["L"] = four(L["mat_red"])
    rows["C"] = L["pool_tiles"] if theme == "agua" else L["metal"]
    rows["|"] = face
    if cold:
        rows["s"] = L["snow"]
    return rows


def prop_rows(theme, P):
    rows = {}
    cold, hot = theme == "gelo", theme in ("fogo", "dragao")
    rock = P["rock"]
    if cold:
        rock = P["ice_rock"]
    elif hot:
        rock = [recolor(t, k=.7, toward=(90, 50, 40), amount=.35) for t in P["rock"]]
    rows["r"] = rock
    rows["q"] = [cracks_sprite(t) for t in rock] if cold else P["cracked"]
    rows["h"] = P["cut"]
    if theme in ("rocha", "terra", "lutador"):
        rows["r"] = [P["rock"][0], P["boulder"][0]]
    rows["I"] = P["ice_pillar"]
    tree = P["tree"]
    if cold:
        tree = [recolor(t, hue=205, sat=.35, k=1.25) for t in tree]
    elif hot:
        # Árvores de outono do santuário (o mesmo pinheiro, recolorido).
        tree = [recolor(t, hue=24, sat=1.05) for t in tree]
    elif theme == "fantasma":
        tree = [recolor(t, hue=290, sat=.8) for t in tree]
    rows["t"] = tree
    if theme == "eletrico":
        rows["P"] = P["tesla"]
    elif cold:
        rows["P"] = P["ice_pillar"]
    else:
        rows["P"] = P["statue"]
    rows["F"] = P["fossil"]
    rows["T"] = P["drill"] if hot else P["console"]
    rows["~"] = P["waterfall"]
    return rows


def cracks_sprite(t):
    out = t.copy()
    d = ImageDraw.Draw(out)
    d.line((5, 3, 8, 8, 6, 12), fill=(40, 60, 90, 255))
    return out


# ---------------------------------------------------------------- piso do ginásio

def arena_list():
    return sorted(p.stem for p in (SRV / "arenas").glob("*.json"))


def gym_areas():
    src = (SRV / "gyms.go").read_text()
    return {gid: area for gid, _, area in re.findall(r'\{"(\w+)", "(\w+)", "([\w]+)"', src)}


def gym_floor(area):
    """Os tiles de chão mais comuns do ginásio original (até 4, de 16px)."""
    try:
        m = json.loads((MAPS / f"{area}.json").read_text())
        s = json.loads((SRV / "maps" / f"{area}.json").read_text())
    except FileNotFoundError:
        return None
    w, h, cells = s["w"], s["h"], s["cells"]
    tiles = Counter()
    keep = {}
    if m.get("image"):
        p = MAPS / m["image"]["dir"] / "0_0.png"
        if not p.exists():
            return None
        img = Image.open(p).convert("RGBA")
        crop = m["image"].get("crop") or [0, 0]

        def get(x, y):
            x0, y0 = x * 16 - crop[0], y * 16 - crop[1]
            if 0 <= x0 and x0 + 16 <= img.size[0] and 0 <= y0 and y0 + 16 <= img.size[1]:
                return img.crop((x0, y0, x0 + 16, y0 + 16))
            return None
    else:
        def get(x, y):
            return grab(area, x, y, "b")
    for y in range(3, h - 1):
        for x in range(1, w - 1):
            if cells[y * w + x] != ".":
                continue
            t = get(x, y)
            if t is None or sum(avg(t)) < 150:
                continue
            key = t.tobytes()
            tiles[key] += 1
            keep[key] = t
    if not tiles:
        return None
    top = [keep[k].convert("RGBA") for k, n in tiles.most_common(4) if n >= 3] or [keep[tiles.most_common(1)[0][0]].convert("RGBA")]
    # Só variações parecidas com o piso principal (sem tapetes ou bordas).
    base = avg(top[0])
    top = [t for t in top if sum(abs(a - b) for a, b in zip(avg(t), base)) < 40]
    return (top * 4)[:4]


THEME_FLOOR = {"fogo": "volcanic", "gelo": "ice_cave", "eletrico": "elec_floor", "planta": "garden",
               "inseto": "grass", "rocha": "cave", "terra": "cave_sand", "agua": "pool_tiles", "aco": "metal"}


def build(gid, area, theme, L, P):
    floor = gym_floor(area) if area else None
    if floor is None:
        floor = L[THEME_FLOOR.get(theme, "wood")]
    rows = ground_rows(theme, floor, L)
    atlas = Image.new("RGBA", (T * VARIANTS, T * len(ORDER)))
    for row, kind in enumerate(ORDER):
        for v, t in enumerate(rows[kind]):
            atlas.paste(t.resize((T, T), Image.NEAREST), (v * T, row * T))
    atlas.save(OUT / f"{gid}.png")
    pr = prop_rows(theme, P)
    # Cada obstáculo numa casa de 64x64, centrado e apoiado no fundo.
    sheet = Image.new("RGBA", (2 * T * 2, 2 * T * len(PROPS)))
    for row, kind in enumerate(PROPS):
        for v, t in enumerate(pr[kind][:2]):
            cell = Image.new("RGBA", (32, 32))
            cell.alpha_composite(t, ((32 - t.size[0]) // 2, 32 - t.size[1]))
            sheet.alpha_composite(cell.resize((2 * T, 2 * T), Image.NEAREST), (v * 2 * T, row * 2 * T))
    sheet.save(OUT / f"{gid}_props.png")
    return floor is not None


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    L, P = lib(), props()
    print("decoração:", ", ".join(build_decor()))
    areas = gym_areas()
    for gid in arena_list():
        theme = json.loads((SRV / "arenas" / f"{gid}.json").read_text())["theme"]
        build(gid, areas.get(gid), theme, L, P)
        print(gid, theme)
