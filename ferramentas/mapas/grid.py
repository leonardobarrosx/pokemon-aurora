import sys
from PIL import Image, ImageDraw
from gba import Pair, layout, tileset_dir
game, name, out = sys.argv[1:4]
l, cells = layout(game, name)
pair = Pair(game, tileset_dir(l["primary_tileset"]), tileset_dir(l["secondary_tileset"]))
w, h = l["width"], l["height"]
S = 24
img = Image.new("RGBA", (w * S + 20, h * S + 20), (0, 0, 0, 255))
for i, c in enumerate(cells):
    lo, hi = pair.layers(c & 0x3FF)
    t = lo.copy(); t.alpha_composite(hi)
    if (c >> 10) & 3:
        t.alpha_composite(Image.new("RGBA", (16, 16), (255, 0, 0, 60)))
    img.paste(t.resize((S, S), Image.NEAREST), (20 + (i % w) * S, 20 + (i // w) * S))
d = ImageDraw.Draw(img)
for x in range(w):
    d.text((20 + x * S + 4, 4), str(x), fill=(255, 255, 0, 255))
    d.line([(20 + x * S, 20), (20 + x * S, 20 + h * S)], fill=(0, 0, 0, 70))
for y in range(h):
    d.text((2, 20 + y * S + 6), str(y), fill=(255, 255, 0, 255))
    d.line([(20, 20 + y * S), (20 + w * S, 20 + y * S)], fill=(0, 0, 0, 70))
img.save(out)
