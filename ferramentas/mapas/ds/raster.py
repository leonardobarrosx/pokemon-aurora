"""Rasterizador de triângulos com textura, em numpy, com projeção oblíqua.

A câmera olha de cima com inclinação: um ponto (x, y, z) do mundo do DS
vai para a tela em (x, z - K*y). Assim o chão fica em grade quadrada e as
paredes viradas para o sul aparecem, como nos jogos de DS vistos de cima.
"""
import numpy as np

K = 0.9  # inclinação: quanto a altura sobe na tela


class Canvas:
    def __init__(self, w, h, ox, oz, scale=1.0):
        self.w, self.h, self.ox, self.oz, self.s = w, h, ox, oz, scale
        self.rgba = np.zeros((h, w, 4), np.uint8)
        self.depth = np.full((h, w), -1e9, np.float32)
        self.top = np.full((h, w), -1e9, np.float32)  # altura do que está desenhado

    def project(self, p):
        x, y, z = p
        return ((x - self.ox) * self.s, (z - K * y - self.oz) * self.s, y)

    def tri(self, pts, uvs, tex, rep, cols=None):
        P = np.array([self.project(p) for p in pts], np.float64)
        xs, ys = P[:, 0], P[:, 1]
        x0, x1 = int(max(np.floor(xs.min()), 0)), int(min(np.ceil(xs.max()), self.w))
        y0, y1 = int(max(np.floor(ys.min()), 0)), int(min(np.ceil(ys.max()), self.h))
        if x0 >= x1 or y0 >= y1:
            return
        (ax, ay), (bx, by), (cx, cy) = P[:, :2]
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            return
        gx, gy = np.meshgrid(np.arange(x0, x1) + .5, np.arange(y0, y1) + .5)
        w0 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        w1 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        w2 = 1 - w0 - w1
        eps = -1e-4
        inside = (w0 >= eps) & (w1 >= eps) & (w2 >= eps)
        if not inside.any():
            return
        depth = w0 * P[0, 2] + w1 * P[1, 2] + w2 * P[2, 2]
        # Desempate: o que está mais ao sul (z maior) fica na frente.
        zz = w0 * pts[0][2] + w1 * pts[1][2] + w2 * pts[2][2]
        key = depth * 4 + zz * 0.001
        region = self.depth[y0:y1, x0:x1]
        ok = inside & (key >= region - 1e-3)
        if not ok.any():
            return
        if tex is None:
            color = np.zeros(ok.shape + (4,), np.uint8)
            color[...] = (200, 200, 200, 255)
        else:
            th, tw = tex.shape[:2]
            u = w0 * uvs[0][0] + w1 * uvs[1][0] + w2 * uvs[2][0]
            v = w0 * uvs[0][1] + w1 * uvs[1][1] + w2 * uvs[2][1]
            u = np.floor(u).astype(np.int64)
            v = np.floor(v).astype(np.int64)
            u = wrap(u, tw, rep & 1, rep & 4)
            v = wrap(v, th, rep & 2, rep & 8)
            color = tex[v, u]
        if cols is not None:
            c = np.clip(w0[..., None] * cols[0] + w1[..., None] * cols[1] + w2[..., None] * cols[2], 0, 1)
            color = color.copy()
            color[..., :3] = (color[..., :3] * c).astype(np.uint8)
        ok &= color[..., 3] >= 128
        out = self.rgba[y0:y1, x0:x1]
        out[ok] = color[ok]
        out[ok, 3] = 255
        region[ok] = key[ok]
        self.top[y0:y1, x0:x1][ok] = depth[ok]


def wrap(u, n, repeat, flip):
    if not repeat:
        return np.clip(u, 0, n - 1)
    if flip:
        m = np.mod(u, 2 * n)
        return np.where(m >= n, 2 * n - 1 - m, m)
    return np.mod(u, n)
