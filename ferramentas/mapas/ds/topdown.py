"""Vista de cima (sem inclinação) de um mundo de DS, uma amostra por célula.

Para cada célula de 16 unidades devolve o que está por cima: o material do
terreno (nome da textura e cor média) ou o prédio (índice da instância).
Serve para repintar o mapa com metatiles de GBA.
"""
import math
import numpy as np
import raster
from raster import Canvas


def mean_color(img):
    if img is None:
        return (128, 128, 128)
    a = img[..., 3] >= 128
    if not a.any():
        return (128, 128, 128)
    return tuple(int(v) for v in img[..., :3][a].mean(0))


def classify(g, chunks, W, H):
    """chunks {(cx,cy): (land, area)} -> (top, mats, props).

    top: array HxW int32; >=0 índice em mats, <=-2 prédio -(k+2), -1 vazio.
    mats: lista de (nome da textura, cor média, tem 'tree').
    props: lista de (bid, cx, cy, x0, z0, x1, z1) em células do mundo."""
    old = raster.K
    raster.K = 0
    cv = Canvas(W * 32, H * 32, 0, 0, 1 / 16)
    mats, mat_idx, props = [], {}, []
    code = lambda v: np.array([[[v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, 255]]], np.uint8)
    try:
        for (cx, cy), (li, area) in sorted(chunks.items()):
            ox, oz = cx * 512 + 256, cy * 512 + 256
            bset, tset = g.area(area)
            mbank = [g.bank("map", tset)]
            for m, tris in g.land_model(li):
                if m["alpha"] < 31 or "wind" in (m["tex"] or ""):
                    continue
                key = m["tex"]
                if key not in mat_idx:
                    mat_idx[key] = len(mats)
                    mats.append((key, mean_color(g.tex(mbank, m)), "tree" in (key or "")))
                t = code(mat_idx[key] + 1)
                for tri in tris:
                    pts = [(v[0][0] + ox, v[0][1], v[0][2] + oz) for v in tri]
                    cv.tri(pts, [(0, 0)] * 3, t, 0)
            for bid, pos, rot, scale in g.objects(li):
                if bid >= len(g.bmodels):
                    continue
                m_list, _ = g.building(bid)
                ang = -rot[1] / 65536 * 2 * math.pi if abs(rot[1]) < 1 << 20 else -rot[1] / 4096 * math.pi / 180
                ca, sa = math.cos(ang), math.sin(ang)
                k = len(props)
                t = code(0x800000 | k)
                xs, zs = [], []
                for m, tris in m_list:
                    if m["alpha"] < 31:
                        continue
                    for tri in tris:
                        pts = []
                        for v in tri:
                            x, y, z = v[0][0] * scale[0], v[0][1] * scale[1], v[0][2] * scale[2]
                            x, z = x * ca + z * sa, -x * sa + z * ca
                            pts.append((x + pos[0] + ox, y + pos[1], z + pos[2] + oz))
                            xs.append(pts[-1][0]); zs.append(pts[-1][2])
                        cv.tri(pts, [(0, 0)] * 3, t, 0)
                if xs:
                    props.append((bid, (pos[0] + ox) / 16, (pos[2] + oz) / 16, min(xs) / 16, min(zs) / 16, max(xs) / 16, max(zs) / 16))
                else:
                    props.append((bid, 0, 0, 0, 0, 0, 0))
    finally:
        raster.K = old
    rgb = cv.rgba.astype(np.int64)
    v = rgb[..., 0] | (rgb[..., 1] << 8) | (rgb[..., 2] << 16)
    top = np.where(cv.rgba[..., 3] == 0, -1, np.where(v & 0x800000, -((v & 0x7FFFFF) + 2), v - 1))
    return top.astype(np.int32), mats, props, cv.top
