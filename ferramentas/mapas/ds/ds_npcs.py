"""Converte os sprites de NPC do HeartGold (texturas NSBTX de 16 quadros)
para folhas 4x4 de Aurora e aponta os NPCs de Johto para elas.

Uso: python3 ds_npcs.py <raiz do Aurora>   (depois de ds_region.py)
"""
import json, os, re, sys
import numpy as np
from PIL import Image
from nitro import textures, decode

HG = os.environ.get("HG_ROOT", "/home/claude/ext/pokeheartgold")
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
SKIP = ("BALL", "ROCK", "TREE", "BOULDER", "DUMMY", "NONE", "INVISIBLE", "DOOR", "SIGN", "BOARD")


def tables():
    mm = {}
    for l in open(HG + "/include/constants/mmodel.h"):
        m = re.match(r"#define (MMODEL_\w+)\s+(\d+)", l)
        if m:
            mm[m.group(1)] = int(m.group(2))
    asm = os.popen("git -C %s show HEAD:asm/overlay_01_sprite_data.s" % HG).read()
    out = {}
    for s, m in re.findall(r"\.short (SPRITE_\w+), (MMODEL_\w+)", asm):
        if m in mm:
            out.setdefault(s, mm[m])
    return out


def sheet(idx, dest):
    path = HG + "/files/data/mmodel/mmodel/mmodel_%08d.NSBTX" % idx
    if not os.path.exists(path):
        return False
    b = textures(open(path, "rb").read())
    if not b or not b["tex"]:
        return False
    names = sorted(b["tex"], key=lambda n: int(n.rsplit(".", 1)[1]) if n.rsplit(".", 1)[-1].isdigit() else 0)
    pal = next(iter(b["pals"]), None)
    frames = []
    for n in names:
        img = decode(b, n, pal)
        if img is None:
            return False
        frames.append(Image.fromarray(img))
    get = lambda i: frames[i] if i < len(frames) else frames[0]
    if len(frames) >= 16:
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
    table = tables()
    cdir = os.path.join(ROOT, "client/assets/maps")
    chars = os.path.join(ROOT, "client/assets/characters/ds"); os.makedirs(chars, exist_ok=True)
    made, bad, total = {}, set(), 0
    for f in sorted(os.listdir(cdir)):
        if not (f.startswith("jt_") and f.endswith(".json")):
            continue
        p = os.path.join(cdir, f)
        d = json.load(open(p))
        keep = []
        for n in d.get("npcs", []):
            s = n["sprite"]
            if s.startswith("ds/hg_"):
                s = "SPRITE_" + s[6:].upper()
            if any(k in s for k in SKIP) or s not in table:
                bad.add(s); continue
            name = "hg_" + s.replace("SPRITE_", "").lower()
            if name not in made:
                made[name] = sheet(table[s], os.path.join(chars, name + ".png"))
            if not made[name]:
                bad.add(s); continue
            n["sprite"] = "ds/" + name
            keep.append(n)
        d["npcs"] = keep
        total += len(keep)
        json.dump(d, open(p, "w"), separators=(",", ":"))
    print(total, "NPCs em Johto,", sum(made.values()), "sprites; ignorados:", len(bad))


if __name__ == "__main__":
    main()
