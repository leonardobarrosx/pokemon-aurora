"""Leitura de tilesets e layouts dos projetos de decompilação (pret/pokefirered
e cRz-Shadows/Pokemon_Emerald_Legacy) para gerar atlas de metatiles."""
import json, os, struct
from PIL import Image

GAMES = {
    "frlg": {"root": "/home/claude/ext/pokefirered", "tiles": 640, "metas": 640, "pals": 7, "attr": 4},
    "rse": {"root": "/home/claude/crz-shadows/pokemon_emerald_legacy", "tiles": 512, "metas": 512, "pals": 6, "attr": 2},
}


def read_pal(path):
    lines = open(path).read().split()
    n = int(lines[2])
    vals = list(map(int, lines[3:3 + n * 3]))
    return [tuple(vals[i * 3:i * 3 + 3]) for i in range(n)]


def snake(name):
    out = ""
    for i, c in enumerate(name):
        if c.isupper() and i and (not name[i - 1].isupper() or (i + 1 < len(name) and name[i + 1].islower())):
            out += "_"
        out += c.lower()
    return out


_SOURCES = {}


def tileset_sources(game):
    """Lê src/data/tilesets/*.h: para cada tileset, as pastas reais dos tiles,
    das paletas e dos metatiles. Alguns tilesets usam gráficos de outro (o
    Silph Co. usa os do Condominiums; as bases secretas guardam metatiles numa
    pasta e gráficos noutra)."""
    if game in _SOURCES:
        return _SOURCES[game]
    import re
    root = GAMES[game]["root"]
    src = os.path.join(root, "src/data/tilesets")
    out = {}
    if not os.path.isdir(src):
        _SOURCES[game] = out
        return out
    text = "".join(open(os.path.join(src, f)).read() for f in ("graphics.h", "metatiles.h") if os.path.exists(os.path.join(src, f)))
    paths = {}
    for m in re.finditer(r"(g\w+)\[\](?:\[\d+\])?\s*=\s*(?:INCBIN_U\d+\(\s*)?\{?\s*(?:INCBIN_U\d+\()?\"([^\"]+)\"", text):
        paths[m.group(1)] = os.path.dirname(m.group(2))
    headers = open(os.path.join(src, "headers.h")).read()
    for m in re.finditer(r"const struct Tileset (gTileset_\w+) =\s*\{(.*?)\};", headers, re.S):
        body = dict(re.findall(r"\.(\w+) = (\w+)", m.group(2)))
        dirs = {k: paths.get(body.get(k, ""), "") for k in ("tiles", "palettes", "metatiles")}
        if dirs["palettes"].endswith("palettes"):
            dirs["palettes"] = os.path.dirname(dirs["palettes"])
        out[m.group(1)] = {k: os.path.join(root, v) for k, v in dirs.items() if v}
    _SOURCES[game] = out
    return out


def _resolve(game, kind, name):
    here = os.path.join(GAMES[game]["root"], "data/tilesets", kind, name)
    if os.path.exists(os.path.join(here, "tiles.png")) and os.path.exists(os.path.join(here, "metatiles.bin")):
        return here, here, here
    for sym, d in tileset_sources(game).items():
        if tileset_dir(sym, game) == name and d.get("metatiles"):
            tiles = d.get("tiles", here)
            return tiles, d.get("palettes", tiles), d["metatiles"]
    return here, here, here


class Tileset:
    def __init__(self, game, kind, name):
        g = GAMES[game]
        tdir, pdir_root, mdir = _resolve(game, kind, name)
        self.dir = mdir
        img = Image.open(os.path.join(tdir, "tiles.png"))
        self.idx = img.convert("P") if img.mode == "P" else img
        w, h = self.idx.size
        self.ntiles = (w // 8) * (h // 8)
        self.tw = w // 8
        raw = open(os.path.join(self.dir, "metatiles.bin"), "rb").read()
        self.metas = [struct.unpack_from("<8H", raw, i) for i in range(0, len(raw), 16)]
        araw = open(os.path.join(self.dir, "metatile_attributes.bin"), "rb").read()
        if g["attr"] == 4:
            self.attrs = [struct.unpack_from("<I", araw, i)[0] for i in range(0, len(araw), 4)]
            self.behavior = [a & 0x1FF for a in self.attrs]
            self.layer = [(a >> 29) & 3 for a in self.attrs]
        else:
            self.attrs = [struct.unpack_from("<H", araw, i)[0] for i in range(0, len(araw), 2)]
            self.behavior = [a & 0xFF for a in self.attrs]
            self.layer = [(a >> 12) & 0xF for a in self.attrs]
        pdir = os.path.join(pdir_root, "palettes")
        self.pals = [read_pal(os.path.join(pdir, "%02d.pal" % i)) for i in range(16)]

    def tile(self, n):
        x, y = (n % self.tw) * 8, (n // self.tw) * 8
        return self.idx.crop((x, y, x + 8, y + 8))


class Pair:
    """Tileset primário + secundário como o jogo carrega na VRAM."""

    def __init__(self, game, primary, secondary):
        self.g = GAMES[game]
        self.p = Tileset(game, "primary", primary)
        self.s = Tileset(game, "secondary", secondary)
        self.cache = {}

    def palette(self, i):
        return (self.p if i < self.g["pals"] else self.s).pals[i]

    def tile_rgba(self, entry):
        n, hf, vf, pal = entry & 0x3FF, entry >> 10 & 1, entry >> 11 & 1, entry >> 12
        key = (n, hf, vf, pal)
        if key in self.cache:
            return self.cache[key]
        ts = self.p if n < self.g["tiles"] else self.s
        local = n if n < self.g["tiles"] else n - self.g["tiles"]
        out = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
        if local < ts.ntiles:
            t = ts.tile(local)
            colors = self.palette(pal)
            px = out.load()
            src = t.load()
            for y in range(8):
                for x in range(8):
                    c = src[x, y]
                    if c:
                        px[x, y] = colors[c] + (255,)
            if hf:
                out = out.transpose(Image.FLIP_LEFT_RIGHT)
            if vf:
                out = out.transpose(Image.FLIP_TOP_BOTTOM)
        self.cache[key] = out
        return out

    def meta(self, m):
        if m < self.g["metas"]:
            return self.p.metas[m] if m < len(self.p.metas) else (0,) * 8, self.p.layer[m] if m < len(self.p.layer) else 0, self.p.behavior[m] if m < len(self.p.behavior) else 0
        k = m - self.g["metas"]
        if k < len(self.s.metas):
            return self.s.metas[k], self.s.layer[k], self.s.behavior[k]
        return (0,) * 8, 0, 0

    def layers(self, m):
        """(abaixo, acima) de um metatile, 16x16 RGBA cada."""
        entries, layer, _ = self.meta(m)
        lo = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        hi = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for half, img in ((0, lo), (1, hi)):
            for q in range(4):
                t = self.tile_rgba(entries[half * 4 + q])
                img.alpha_composite(t, ((q % 2) * 8, (q // 2) * 8))
        # layer 0 NORMAL: camada de cima fica acima do jogador.
        # layer 1 COVERED: as duas ficam abaixo. layer 2 SPLIT: igual a NORMAL.
        if layer == 1:
            lo.alpha_composite(hi)
            hi = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        return lo, hi

    def behavior(self, m):
        return self.meta(m)[2]


def layout(game, name):
    root = GAMES[game]["root"]
    data = json.load(open(os.path.join(root, "data/layouts/layouts.json")))
    for l in data["layouts"]:
        if l and l.get("name") in (name, name + "_Layout"):
            raw = open(os.path.join(root, l["blockdata_filepath"]), "rb").read()
            cells = list(struct.unpack("<%dH" % (len(raw) // 2), raw))
            return l, cells
    raise KeyError(name)


def tileset_dir(symbol, game="frlg"):
    # gTileset_PalletTown -> pallet_town (casando com as pastas existentes)
    want = symbol.replace("gTileset_", "").replace("_", "").lower()
    base = os.path.join(GAMES[game]["root"], "data/tilesets")
    for kind in ("primary", "secondary"):
        for d in os.listdir(os.path.join(base, kind)):
            if d.replace("_", "").lower() == want:
                return d
    return snake(symbol.replace("gTileset_", ""))
