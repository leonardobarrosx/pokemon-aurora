"""Gera as texturas dos estádios dos ginásios.

Para cada ginásio sai client/assets/stadiums/<id>.png: uma tira de casas de
32px na ordem do campo do servidor (server/field.go):

    .  w  r  p  s  g  l  i  e  x

O chão, a água e as pedras vêm do próprio mapa do ginásio (metatiles GBA ou
a imagem do DS). Os tipos que o ginásio não tem são pintados em pixel art no
mesmo estilo, puxando a cor do chão do ginásio.
"""
import json, re, random
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / "client/assets/maps"
SRV = ROOT / "server"
OUT = ROOT / "client/assets/stadiums"
ORDER = ".wrpsglie x".replace(" ", "")
T = 32
MAP_ROCKS = {"kanto_1"}


def gyms():
    src = (SRV / "gyms.go").read_text()
    out = re.findall(r'\{"(\w+)", "(\w+)", "([\w]+)"', src)
    field = (SRV / "field.go").read_text()
    theme = dict(re.findall(r'"(\w+_\d)":\s*"(\w+)"', field))
    return [(gid, area, theme.get(gid, "normal")) for gid, _, area in out]


def gba_tile(m, atlas_below, atlas_above, idx):
    t = Image.new("RGBA", (16, 16))
    cols = m["columns"]
    for atlas, layer in ((atlas_below, m["tiles"]), (atlas_above, m.get("above") or [])):
        if atlas is None or idx >= len(layer) or layer[idx] is None or layer[idx] < 0:
            continue
        k = layer[idx]
        box = ((k % cols) * 16, (k // cols) * 16, (k % cols) * 16 + 16, (k // cols) * 16 + 16)
        if box[3] > atlas.size[1]:
            continue
        t.alpha_composite(atlas.crop(box))
    return t


def ds_tile(img, crop, x, y):
    px, py = x * 16 - crop[0], y * 16 - crop[1]
    if px < 0 or py < 0 or px + 16 > img.size[0] or py + 16 > img.size[1]:
        return None
    return img.crop((px, py, px + 16, py + 16)).convert("RGBA")


def tiles_by_class(area):
    """Tiles de 16px do mapa, agrupados pela classe da casa do servidor."""
    m = json.loads((MAPS / f"{area}.json").read_text())
    s = json.loads((SRV / "maps" / f"{area}.json").read_text())
    w, h, cells = s["w"], s["h"], s["cells"]
    groups = {}
    if "image" in m and m["image"]:
        im = m["image"]
        p = MAPS / im["dir"] / "0_0.png"
        if not p.exists():
            return groups
        img = Image.open(p).convert("RGBA")
        for y in range(h):
            for x in range(w):
                t = ds_tile(img, im.get("crop") or [0, 0], x, y)
                if t is not None:
                    groups.setdefault(cells[y * w + x], []).append((x, y, t))
    else:
        below = Image.open(MAPS / f"{m['atlas']}_below.png").convert("RGBA")
        ap = MAPS / f"{m['atlas']}_above.png"
        above = Image.open(ap).convert("RGBA") if ap.exists() else None
        for y in range(h):
            for x in range(w):
                groups.setdefault(cells[y * w + x], []).append((x, y, gba_tile(m, below, above, y * w + x)))
    return groups, w, h


def common(items, interior=None):
    c = Counter()
    keep = {}
    for x, y, t in items:
        if interior and not interior(x, y):
            continue
        a = t.getchannel("A").getextrema()[1]
        if a == 0 or sum(avg(t)) < 60:
            continue  # vazio ou o preto fora do desenho do DS
        key = t.tobytes()
        c[key] += 1
        keep[key] = t
    if not c:
        return None
    return keep[c.most_common(1)[0][0]]


def up(t):
    return t.resize((T, T), Image.NEAREST)


def avg(t):
    px = [p for p in t.convert('RGBA').get_flattened_data() if p[3] > 0] if hasattr(t, 'get_flattened_data') else [p for p in t.getdata() if p[3] > 0]
    n = max(1, len(px))
    return tuple(sum(p[i] for p in px) // n for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def paint(kind, base, seed):
    """Casas que o ginásio não tem, em pixel art de 16px."""
    r = random.Random(seed)
    t = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(t)
    pal = {
        "w": [(56, 120, 208), (80, 152, 232), (152, 208, 248)],
        "l": [(200, 56, 24), (240, 120, 32), (255, 208, 72)],
        "i": [(168, 216, 240), (208, 240, 255), (255, 255, 255)],
        "x": [(112, 56, 144), (152, 88, 184), (200, 144, 224)],
        "e": [shade(base, .7), (248, 216, 64), (255, 248, 168)],
        "g": [(48, 120, 56), (80, 168, 72), (136, 208, 96)],
        "s": [(176, 136, 80), (208, 168, 104), (232, 200, 136)],
        "r": [(88, 80, 72), (136, 124, 108), (184, 172, 152)],
        "n": [(232, 240, 248), (200, 220, 240), (255, 255, 255)],
        "f": [(168, 168, 176), (136, 136, 148), (200, 200, 208)],
    }[kind]
    d.rectangle((0, 0, 15, 15), fill=pal[0] + (255,))
    if kind in "wlx":
        for y in range(0, 16, 4):
            off = r.randrange(4)
            for x in range(off, 16, 8):
                d.line((x, y + 1, x + 3, y + 1), fill=pal[1] + (255,))
        for _ in range(3):
            x, y = r.randrange(14), r.randrange(14)
            d.point((x, y), fill=pal[2] + (255,))
    elif kind == "i":
        d.rectangle((0, 0, 15, 15), fill=pal[1] + (255,))
        d.line((2, 12, 12, 2), fill=pal[2] + (255,))
        d.line((6, 14, 14, 6), fill=pal[2] + (255,))
        d.rectangle((0, 0, 15, 15), outline=pal[0] + (255,))
    elif kind == "e":
        d.rectangle((1, 1, 14, 14), fill=shade(base, .85) + (255,), outline=pal[0] + (255,))
        d.line((9, 2, 5, 8, 10, 8, 6, 14), fill=pal[1] + (255,))
    elif kind == "g":
        for x in range(0, 16, 3):
            hgt = 5 + r.randrange(5)
            d.line((x + 1, 15, x + 1, 15 - hgt), fill=pal[1] + (255,))
            d.point((x + 1, 15 - hgt), fill=pal[2] + (255,))
    elif kind == "s":
        for _ in range(14):
            d.point((r.randrange(16), r.randrange(16)), fill=pal[r.randrange(1, 3)] + (255,))
    elif kind == "n":
        for _ in range(10):
            d.point((r.randrange(16), r.randrange(16)), fill=pal[1] + (255,))
    elif kind == "f":
        d.line((0, 7, 15, 7), fill=pal[1] + (255,))
        d.line((0, 15, 15, 15), fill=pal[1] + (255,))
        d.line((7, 0, 7, 7), fill=pal[1] + (255,))
        d.line((15, 8, 15, 15), fill=pal[1] + (255,))
        d.line((0, 0, 6, 0), fill=pal[2] + (255,))
    elif kind == "r":
        t = Image.new("RGBA", (16, 16))
        d = ImageDraw.Draw(t)
        d.ellipse((1, 3, 14, 15), fill=pal[0] + (255,))
        d.ellipse((2, 2, 13, 13), fill=pal[1] + (255,))
        d.ellipse((4, 3, 9, 7), fill=pal[2] + (255,))
    return t


def platform(floor):
    t = floor.copy()
    d = ImageDraw.Draw(t)
    base = avg(floor)
    d.rectangle((0, 0, 15, 15), outline=shade(base, 1.25) + (255,))
    d.line((0, 15, 15, 15), fill=shade(base, .55) + (255,))
    d.line((0, 14, 15, 14), fill=shade(base, .7) + (255,))
    return t


def build(gid, area, theme):
    try:
        groups, w, h = tiles_by_class(area)
    except (FileNotFoundError, ValueError):
        groups, w, h = {}, 1, 1
    inside = lambda x, y: 0 < x < w - 1 and 2 < y < h - 1
    floor = common(groups.get(".", []), inside) or common(groups.get('"', [])) or paint("s", (160, 160, 160), 1)
    if sum(avg(floor)) < 150 or theme == "gelo":
        # Sala escura demais (ou ginásio de gelo): chão pintado claro.
        floor = paint("n" if theme == "gelo" else "f", avg(floor), 10)
    base = avg(floor)
    water = common(groups.get("~", []), inside)
    rock = None
    if gid in MAP_ROCKS:
        # Ginásios com pedregulhos de verdade no mapa (o do Brock).
        rock = common(groups.get("#", []), inside)
    grass = common(groups.get('"', []))
    tiles = {
        ".": floor,
        "w": water or paint("w", base, 2),
        "r": rock or paint("r", base, 3),
        "p": platform(floor),
        "s": paint("s", base, 4) if theme not in ("rocha", "terra") else floor,
        "g": grass or paint("g", base, 5),
        "l": paint("l", base, 6),
        "i": paint("i", base, 7),
        "e": paint("e", base, 8),
        "x": paint("x", base, 9),
    }
    if theme in ("rocha", "terra"):
        # O chão de terra do ginásio é a areia; o "chão liso" fica um tom acima.
        tiles["."] = Image.eval(floor, lambda v: min(255, int(v * 1.12)))
    if rock is not None:
        # A pedra do mapa vem sem fundo: coloca o chão por baixo.
        under = tiles["s"] if theme in ("rocha", "terra") else floor
        r2 = under.copy()
        r2.alpha_composite(rock)
        tiles["r"] = r2
    else:
        r2 = tiles["s"].copy() if theme in ("rocha", "terra") else floor.copy()
        r2.alpha_composite(tiles["r"])
        tiles["r"] = r2
    strip = Image.new("RGBA", (T * len(ORDER), T))
    for i, k in enumerate(ORDER):
        strip.paste(up(tiles[k]), (i * T, 0))
    strip.save(OUT / f"{gid}.png")
    return bool(water), bool(rock)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for gid, area, theme in gyms():
        print(gid, area, theme, build(gid, area, theme))
