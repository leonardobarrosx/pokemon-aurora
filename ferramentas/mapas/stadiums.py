"""Gera as texturas do chão das arenas dos ginásios.

Para cada ginásio sai client/assets/stadiums/<id>.png: uma linha por tipo de
terreno (na ordem de ORDER, a mesma de client/world_view.gd) e 4 variações
por linha, em casas de 32px (pixel art de 16px ampliada). As variações
quebram a repetição do piso.

O piso principal vem do próprio mapa do ginásio (metatiles GBA ou a imagem do
DS); os outros terrenos são pintados no mesmo estilo, com a paleta do tema.
Obstáculos altos (pilares, árvores, rochas, máquinas) são desenhados pelo
cliente por cima, com sombra e profundidade.
"""
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
ORDER = ".,smnMbpkwuW_><^vijgoXflexVY}{)(zRTGO"
VARIANTS = 4
T = 32

# Paleta por tema: piso claro, piso escuro, destaque.
THEME = {
    "rocha": ((176, 150, 112), (140, 116, 84), (204, 184, 148)),
    "terra": ((168, 132, 92), (128, 98, 66), (196, 164, 120)),
    "agua": ((206, 226, 236), (170, 196, 212), (236, 246, 250)),
    "planta": ((150, 140, 120), (118, 108, 92), (180, 172, 150)),
    "inseto": ((112, 140, 72), (84, 108, 52), (150, 176, 96)),
    "fogo": ((112, 100, 100), (82, 72, 74), (150, 136, 132)),
    "gelo": ((226, 236, 246), (196, 212, 230), (250, 252, 255)),
    "eletrico": ((128, 136, 148), (96, 104, 116), (164, 172, 184)),
    "veneno": ((150, 112, 150), (116, 84, 118), (182, 146, 182)),
    "psiquico": ((206, 180, 214), (170, 146, 184), (232, 214, 238)),
    "fantasma": ((96, 92, 120), (70, 66, 92), (128, 124, 156)),
    "lutador": ((196, 160, 104), (160, 126, 80), (222, 192, 140)),
    "normal": ((200, 196, 184), (166, 160, 148), (226, 222, 212)),
    "voador": ((176, 134, 92), (140, 102, 66), (206, 168, 124)),
    "aco": ((150, 156, 164), (116, 122, 132), (184, 190, 198)),
    "dragao": ((150, 112, 96), (114, 82, 70), (184, 146, 128)),
}


def arena_list():
    return sorted(p.stem for p in (SRV / "arenas").glob("*.json"))


def gym_areas():
    src = (SRV / "gyms.go").read_text()
    return {gid: area for gid, _, area in re.findall(r'\{"(\w+)", "(\w+)", "([\w]+)"', src)}


def avg(t):
    px = [p for p in t.convert("RGBA").getdata() if p[3] > 0]
    n = max(1, len(px))
    return tuple(sum(p[i] for p in px) // n for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def mix(a, b, k):
    return tuple(int(a[i] * (1 - k) + b[i] * k) for i in range(3))


def gym_floor(area):
    """O tile de chão mais comum do ginásio original (16px)."""
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
        get = lambda x, y: img.crop((x * 16 - crop[0], y * 16 - crop[1], x * 16 - crop[0] + 16, y * 16 - crop[1] + 16)) \
            if 0 <= x * 16 - crop[0] and x * 16 - crop[0] + 16 <= img.size[0] and 0 <= y * 16 - crop[1] and y * 16 - crop[1] + 16 <= img.size[1] else None
    else:
        below = Image.open(MAPS / f"{m['atlas']}_below.png").convert("RGBA")
        cols = m["columns"]

        def get(x, y):
            k = m["tiles"][y * w + x]
            if k is None or k < 0:
                return None
            box = ((k % cols) * 16, (k // cols) * 16, (k % cols) * 16 + 16, (k // cols) * 16 + 16)
            return below.crop(box) if box[3] <= below.size[1] else None
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
    return keep[tiles.most_common(1)[0][0]].convert("RGBA")


def canvas(c):
    t = Image.new("RGBA", (16, 16), c + (255,))
    return t, ImageDraw.Draw(t)


def specks(d, r, cols, n):
    for _ in range(n):
        d.point((r.randrange(16), r.randrange(16)), fill=r.choice(cols) + (255,))


def paint(kind, pal, v, theme):
    """Uma casa de 16px do terreno `kind`, variação `v`."""
    r = random.Random(f"{theme}{kind}{v}")
    light, dark, hi = pal
    if kind == ".":
        t, d = canvas(light)
        # Lajes: juntas em posições diferentes por variação.
        off = (0, 4, 8, 2)[v]
        d.line((0, 15, 15, 15), fill=dark + (255,))
        d.line(((off + 7) % 16, 0, (off + 7) % 16, 15), fill=dark + (255,))
        d.line((0, 0, 15, 0), fill=hi + (255,))
        specks(d, r, [shade(light, .92), shade(light, 1.06)], 6 + v * 2)
    elif kind == ",":
        wood = mix(light, (168, 122, 76), .65)
        t, d = canvas(wood)
        for y in (3, 7, 11, 15):
            d.line((0, y, 15, y), fill=shade(wood, .72) + (255,))
        for y in (0, 4, 8, 12):
            x = (v * 5 + y * 3) % 16
            d.line((x, y, x, y + 2), fill=shade(wood, .8) + (255,))
        specks(d, r, [shade(wood, 1.1)], 4)
    elif kind == "s":
        sand = mix(light, (196, 160, 108), .7)
        t, d = canvas(sand)
        specks(d, r, [shade(sand, .85), shade(sand, 1.1), shade(sand, .75)], 18 + v * 3)
        if v == 3:
            d.ellipse((4, 6, 8, 9), fill=shade(sand, .7) + (255,))
    elif kind == "m":
        mud = (104, 82, 58)
        t, d = canvas(mud)
        specks(d, r, [shade(mud, .8), shade(mud, 1.15)], 16)
        d.ellipse((3 + v, 5, 9 + v, 9), fill=(86, 104, 112, 255))
    elif kind == "n":
        snow = (236, 242, 250)
        t, d = canvas(snow)
        specks(d, r, [(212, 224, 240), (255, 255, 255)], 10 + v * 3)
    elif kind == "M":
        steel = mix(light, (140, 148, 160), .7)
        t, d = canvas(steel)
        d.rectangle((0, 0, 15, 15), outline=shade(steel, .7) + (255,))
        d.line((1, 1, 14, 1), fill=shade(steel, 1.2) + (255,))
        for x, y in ((3, 3), (12, 3), (3, 12), (12, 12)):
            d.point((x, y), fill=shade(steel, .6) + (255,))
        if v % 2:
            for k in range(2, 14, 4):
                d.line((k, 6, k + 2, 9), fill=shade(steel, .85) + (255,))
    elif kind == "b":
        plank = (150, 104, 64)
        t, d = canvas(plank)
        for x in (0, 5, 10, 15):
            d.line((x, 0, x, 15), fill=shade(plank, .65) + (255,))
        d.point((2 + v, 4), fill=shade(plank, .5) + (255,))
        d.point((7, 11 - v), fill=shade(plank, .5) + (255,))
    elif kind in "pk_":
        stone = mix(light, (220, 216, 206), .5)
        base = paint("W", pal, v, theme) if kind == "_" else canvas(stone)[0]
        t = base
        d = ImageDraw.Draw(t)
        if kind == "_":
            d.rectangle((1, 1, 14, 14), outline=(140, 170, 190, 160))
        else:
            d.rectangle((0, 0, 15, 15), outline=shade(stone, .7) + (255,))
            d.line((1, 1, 14, 1), fill=shade(stone, 1.15) + (255,))
            if kind == "k":
                for k in range(0, 16, 4):
                    d.line((k, 13, k + 2, 13), fill=(230, 160, 40, 255))
            else:
                d.line((7, 4, 8, 11), fill=shade(stone, .85) + (255,))
    elif kind in "wuW><^vz":
        deep = kind in "W><^vz"
        water = (56, 112, 200) if deep else (96, 164, 220)
        if kind == "u":
            water = (58, 142, 150)
        if theme == "agua" and not deep:
            water = (112, 184, 232)
        t, d = canvas(water)
        for y in range(1, 16, 4):
            x = (y * 5 + v * 4) % 16
            d.line((x, y, x + 4, y), fill=shade(water, 1.25) + (255,))
        specks(d, r, [shade(water, .85)], 5)
        if kind in "><^v":
            ax = {">": ((4, 8), (10, 8), (8, 6), (8, 10)), "<": ((12, 8), (6, 8), (8, 6), (8, 10)),
                  "^": ((8, 12), (8, 6), (6, 8), (10, 8)), "v": ((8, 4), (8, 10), (6, 8), (10, 8))}[kind]
            c = (170, 214, 248, 255)
            d.line(ax[0] + ax[1], fill=c)
            d.line(ax[1] + ax[2], fill=c)
            d.line(ax[1] + ax[3], fill=c)
        if kind == "z":
            d.line((3, 2, 7, 8, 5, 9, 10, 14), fill=(255, 236, 90, 255))
    elif kind in "ij":
        ice = (176, 220, 244)
        t, d = canvas(ice)
        d.line((2 + v, 13, 12, 3 + v), fill=(232, 246, 255, 255))
        d.line((7, 15, 15, 7), fill=(214, 238, 252, 255))
        specks(d, r, [(150, 200, 232)], 4)
        if kind == "j":
            d.line((3, 4, 7, 8, 6, 12, 11, 15), fill=(90, 130, 170, 255))
            d.line((7, 8, 13, 6), fill=(90, 130, 170, 255))
    elif kind == "g":
        base = (64, 140, 64)
        t, d = canvas(base)
        for x in range(0, 16, 2):
            hgt = 6 + r.randrange(7)
            col = r.choice([(88, 176, 80), (104, 192, 88), (52, 120, 56)])
            d.line((x, 15, x + r.choice((-1, 0, 1)), 15 - hgt), fill=col + (255,))
    elif kind == "o":
        t = paint(",", pal, v, theme) if theme == "planta" else canvas((84, 150, 70))[0]
        d = ImageDraw.Draw(t)
        for _ in range(5):
            x, y = r.randrange(1, 14), r.randrange(1, 14)
            c = r.choice([(240, 120, 160), (250, 220, 80), (250, 250, 250), (180, 120, 230)])
            d.rectangle((x, y, x + 1, y + 1), fill=c + (255,))
            d.point((x, y + 2), fill=(60, 130, 60, 255))
    elif kind == "X":
        t = paint(".", pal, v, theme)
        d = ImageDraw.Draw(t)
        c = (236, 236, 240, 220)
        for k in range(0, 16, 5):
            d.line((0, k, 15, 15 - k), fill=c)
        d.line((8, 0, 8, 15), fill=c)
        d.ellipse((4, 4, 12, 12), outline=c)
    elif kind == "f":
        t, d = canvas((60, 48, 40))
        specks(d, r, [(240, 120, 40), (255, 200, 70), (120, 40, 20)], 22)
    elif kind == "l":
        lava = (208, 64, 24)
        t, d = canvas(lava)
        for y in range(0, 16, 3):
            x = (y * 7 + v * 5) % 16
            d.line((x, y, x + 5, y + 1), fill=(248, 140, 40, 255))
        for _ in range(3):
            x, y = r.randrange(14), r.randrange(14)
            d.rectangle((x, y, x + 1, y + 1), fill=(255, 224, 96, 255))
    elif kind == "e":
        t = paint("M" if theme in ("eletrico", "fogo", "aco") else ".", pal, v, theme)
        d = ImageDraw.Draw(t)
        d.rectangle((2, 2, 13, 13), fill=(56, 60, 72, 255), outline=(250, 210, 60, 255))
        d.line((9, 3, 6, 8, 10, 8, 7, 13), fill=(255, 236, 110, 255))
    elif kind == "x":
        goo = (122, 64, 150)
        t, d = canvas(goo)
        specks(d, r, [(160, 100, 196), (96, 44, 120)], 16)
        d.ellipse((3 + v, 4, 7 + v, 8), outline=(200, 150, 230, 255))
    elif kind == "V":
        t = paint("M" if theme in ("fogo", "eletrico", "aco") else ".", pal, v, theme)
        d = ImageDraw.Draw(t)
        d.ellipse((2, 2, 13, 13), fill=(40, 40, 44, 255), outline=(90, 90, 96, 255))
        for k in (5, 8, 11):
            d.line((4, k, 11, k), fill=(150, 72, 40, 255) if theme == "fogo" else (120, 130, 140, 255))
    elif kind == "Y":
        t = paint(".", pal, v, theme)
        d = ImageDraw.Draw(t)
        d.ellipse((1, 3, 14, 12), fill=(80, 40, 120, 255), outline=(200, 140, 250, 255))
        d.ellipse((5, 6, 10, 9), fill=(230, 200, 255, 255))
    elif kind in "}{)(":
        t = paint(".", pal, v, theme)
        d = ImageDraw.Draw(t)
        c = (230, 240, 250, 200)
        for y in (4, 10):
            d.line((2 + v, y, 12 + v % 2, y), fill=c)
            d.point((13, y - 1), fill=c)
        if kind in ")(":
            t = t.rotate(90 if kind == "(" else -90)
        elif kind == "{":
            t = t.transpose(Image.FLIP_LEFT_RIGHT)
    elif kind == "R":
        rock = {"agua": (200, 208, 220), "planta": (190, 220, 210), "fogo": (88, 76, 74), "gelo": (120, 140, 168),
                "eletrico": (82, 88, 100), "aco": (90, 96, 106)}.get(theme, mix(dark, (110, 96, 84), .5))
        t, d = canvas(rock)
        specks(d, r, [shade(rock, .82), shade(rock, 1.12)], 20)
        d.line((0, 0, 15, 0), fill=shade(rock, 1.2) + (255,))
        if theme in ("rocha", "terra", "gelo", "dragao", "inseto", "lutador"):
            d.line((3 + v, 2, 6, 9), fill=shade(rock, .7) + (255,))
    elif kind == "T":
        t, d = canvas((70, 74, 86))
        d.rectangle((1, 1, 14, 14), outline=(110, 116, 130, 255))
        d.line((0, 8, 15, 8), fill=(150, 120, 60, 255) if theme == "fogo" else (90, 140, 170, 255))
        d.rectangle((3 + v * 2, 3, 4 + v * 2, 4), fill=(120, 230, 140, 255) if v % 2 else (240, 90, 70, 255))
    elif kind == "G":
        t, d = canvas((150, 200, 220))
        d.line((2, 14, 14, 2), fill=(230, 248, 255, 255))
        d.line((0, 0, 15, 0), fill=(90, 110, 120, 255))
        d.line((0, 15, 15, 15), fill=(90, 110, 120, 255))
    elif kind == "O":
        t, d = canvas((18, 22, 34))
        if theme == "voador":
            t, d = canvas((140, 190, 236))
            d.ellipse((2 + v, 5, 10 + v, 10), fill=(244, 248, 252, 255))
    else:
        t, _ = canvas(light)
    return t


def floor_variants(base, pal, theme):
    """Variações do piso original do ginásio: manchas, desgaste e juntas."""
    out = [base]
    for v in range(1, VARIANTS):
        r = random.Random(f"{theme}floor{v}")
        t = base.copy()
        d = ImageDraw.Draw(t)
        c = avg(base)
        for _ in range(4 + v * 2):
            x, y = r.randrange(16), r.randrange(16)
            d.point((x, y), fill=shade(c, r.choice((.85, .9, 1.08))) + (255,))
        if v == 3:
            d.line((2, 12, 6, 9), fill=shade(c, .8) + (255,))
        out.append(t)
    return out


def build(gid, area, theme):
    pal = THEME.get(theme, THEME["normal"])
    base = gym_floor(area) if area else None
    atlas = Image.new("RGBA", (T * VARIANTS, T * len(ORDER)))
    for row, kind in enumerate(ORDER):
        if kind == "." and base is not None:
            tiles = floor_variants(base, pal, theme)
        else:
            tiles = [paint(kind, pal, v, theme) for v in range(VARIANTS)]
        for v, t in enumerate(tiles):
            atlas.paste(t.resize((T, T), Image.NEAREST), (v * T, row * T))
    atlas.save(OUT / f"{gid}.png")
    return base is not None


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    areas = gym_areas()
    for gid in arena_list():
        theme = json.loads((SRV / "arenas" / f"{gid}.json").read_text())["theme"]
        print(gid, theme, build(gid, areas.get(gid), theme))
