import sys
from PIL import Image
from gba import Pair, layout, tileset_dir
game, name, out = sys.argv[1:4]
l, cells = layout(game, name)
pair = Pair(game, tileset_dir(l["primary_tileset"]), tileset_dir(l["secondary_tileset"]))
w, h = l["width"], l["height"]
img = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 255))
for i, c in enumerate(cells):
    lo, hi = pair.layers(c & 0x3FF)
    img.alpha_composite(lo, ((i % w) * 16, (i // w) * 16)); img.alpha_composite(hi, ((i % w) * 16, (i // w) * 16))
img.save(out)
print(w, h, pair.s.dir)
