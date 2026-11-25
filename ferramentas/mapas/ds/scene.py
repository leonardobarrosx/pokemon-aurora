"""Monta e desenha chunks de mapa de HeartGold (terreno + prédios)."""
import math, struct
import numpy as np
from narc import narc
from nitro import model, textures, decode
from raster import Canvas, K

TREE_WORDS = ("tree", "wood", "roof", "yane")


class Game:
    def __init__(self, land, maptex, areas, bmodels, btex):
        self.land = narc(land)
        self.maptex = narc(maptex)
        self.areas = narc(areas)
        self.bmodels = narc(bmodels)
        self.btex = narc(btex)
        self._models, self._banks, self._tex = {}, {}, {}

    def area(self, idx):
        b, t = struct.unpack_from("<HH", self.areas[idx], 0)
        return b, t

    def bank(self, kind, idx):
        key = (kind, idx)
        if key not in self._banks:
            src = self.maptex if kind == "map" else self.btex
            self._banks[key] = textures(src[idx]) if 0 <= idx < len(src) else None
        return self._banks[key]

    def tex(self, banks, m):
        key = (id(banks[0]) if banks else 0, m["tex"], m["pal"])
        if key in self._tex:
            return self._tex[key]
        img = None
        for bank in banks:
            if bank and m["tex"] in bank["tex"]:
                try:
                    img = decode(bank, m["tex"], m["pal"])
                except Exception:
                    img = None
                if img is not None:
                    break
        self._tex[key] = img
        return img

    def parts(self, li):
        x = self.land[li]
        perm, obj, mdl, bd = struct.unpack_from("<4I", x)
        hs = struct.unpack_from("<HH", x, 16)[1] if struct.unpack_from("<H", x, 16)[0] == 0x1234 else -4
        base = 20 + hs
        return x[base:base + perm], x[base + perm:base + perm + obj], x[base + perm + obj:base + perm + obj + mdl]

    def land_model(self, li):
        if ("land", li) not in self._models:
            self._models[("land", li)] = model(self.parts(li)[2])
        return self._models[("land", li)]

    def building(self, bi):
        if ("b", bi) not in self._models:
            d = self.bmodels[bi]
            try:
                m = model(d)
            except Exception:
                m = []
            try:
                own = textures(d)
            except Exception:
                own = None
            self._models[("b", bi)] = (m, own if own else None)
        return self._models[("b", bi)]

    def objects(self, li):
        obj = self.parts(li)[1]
        out = []
        for i in range(0, len(obj) - 47, 48):
            v = struct.unpack_from("<I3i3i3i", obj, i)
            out.append((v[0], [a / 4096 for a in v[1:4]], v[4:7], [a / 4096 for a in v[7:10]]))
        return out

    def perms(self, li):
        return struct.unpack("<1024H", self.parts(li)[0])

    def draw_chunk(self, cv, li, area_idx, ox, oz, alt=0):
        """Desenha o chunk de terreno li com centro em (ox, oz) no canvas."""
        bset, tset = self.area(area_idx)
        mbank = [self.bank("map", tset)]
        for m, tris in self.land_model(li):
            tex = self.tex(mbank, m)
            if tex is None or any(w in (m["tex"] or "") for w in ("wind",)):
                continue
            rep = (m["teximg"] >> 16) & 15
            tall = bool(m["tex"]) and "tree" in m["tex"]
            base = min((v[0][1] for t in tris for v in t), default=0)
            for t in tris:
                pts = [(v[0][0] + ox, v[0][1] + alt, v[0][2] + oz) for v in t]
                cv.tri(pts, [v[1] for v in t], tex, rep, min_h=(base + alt + 22) if tall else None, alpha=m["alpha"])
        bbank = self.bank("build", bset)
        for bid, pos, rot, scale in self.objects(li):
            if bid >= len(self.bmodels):
                continue
            m_list, own = self.building(bid)
            banks = [own, bbank] if own else [bbank]
            ang = -rot[1] / 65536 * 2 * math.pi if abs(rot[1]) < 1 << 20 else -rot[1] / 4096 * math.pi / 180
            ca, sa = math.cos(ang), math.sin(ang)
            for m, tris in m_list:
                tex = self.tex(banks, m)
                if tex is None or "wind" in (m["tex"] or ""):
                    continue
                rep = (m["teximg"] >> 16) & 15
                for t in tris:
                    pts = []
                    for v in t:
                        x, y, z = v[0][0] * scale[0], v[0][1] * scale[1], v[0][2] * scale[2]
                        x, z = x * ca + z * sa, -x * sa + z * ca
                        pts.append((x + pos[0] + ox, y + pos[1] + alt, z + pos[2] + oz))
                    cv.tri(pts, [v[1] for v in t], tex, rep, min_h=pos[1] + alt + 26, alpha=m["alpha"])
