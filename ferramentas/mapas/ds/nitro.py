"""Leitor mínimo de modelos NSBMD e texturas NSBTX do Nintendo DS.

Extrai triângulos com coordenadas de textura e o nome da textura de cada
material, e decodifica as texturas para RGBA. Basta para desenhar os mapas
3D de HeartGold e Platinum vistos de cima.
"""
import struct
import numpy as np


def s16(v):
    return v - 0x10000 if v & 0x8000 else v


def sbits(v, n):
    return v - (1 << n) if v & (1 << (n - 1)) else v


def dictionary(d, off):
    """Dicionário 3D da Nitro: devolve [(nome, offset_dos_dados)]."""
    count = d[off + 1]
    hdr = off + 4
    data = hdr + 8 + 4 * count
    esize = struct.unpack_from("<H", d, data)[0]
    names = data + 4 + esize * count
    out = []
    for i in range(count):
        name = d[names + 16 * i:names + 16 * i + 16].split(b"\0")[0].decode("latin1")
        out.append((name, data + 4 + esize * i))
    return out


def blocks(d):
    n = struct.unpack_from("<H", d, 14)[0]
    offs = struct.unpack_from("<%dI" % n, d, 16)
    return {d[o:o + 4]: o for o in offs}


# ---------------------------------------------------------------- texturas
def textures(d):
    """Lê o bloco TEX0 de um BTX0/BMD0: {nome: (w, h, rgba ndarray)}."""
    b = blocks(d)
    if b"TEX0" not in b:
        return {}
    t = b[b"TEX0"]
    tex_info = t + struct.unpack_from("<H", d, t + 0x0E)[0]
    tex_data = t + struct.unpack_from("<I", d, t + 0x14)[0]
    cmp_data = t + struct.unpack_from("<I", d, t + 0x24)[0]
    cmp_info = t + struct.unpack_from("<I", d, t + 0x28)[0]
    pal_info = t + struct.unpack_from("<I", d, t + 0x34)[0]
    pal_data = t + struct.unpack_from("<I", d, t + 0x38)[0]
    pals = {}
    for name, o in dictionary(d, pal_info):
        pals[name] = pal_data + (struct.unpack_from("<H", d, o)[0] << 3)
    out = {}
    for name, o in dictionary(d, tex_info):
        p = struct.unpack_from("<I", d, o)[0]
        out[name] = dict(param=p, off=p & 0xFFFF, w=8 << ((p >> 20) & 7), h=8 << ((p >> 23) & 7),
                         fmt=(p >> 26) & 7, transp=(p >> 29) & 1)
    return dict(tex=out, pals=pals, d=d, tex_data=tex_data, cmp_data=cmp_data, cmp_info=cmp_info, pal_data=pal_data)


def color(c):
    return ((c & 31) * 255 // 31, ((c >> 5) & 31) * 255 // 31, ((c >> 10) & 31) * 255 // 31)


def palette(d, off, n):
    return [color(struct.unpack_from("<H", d, off + 2 * i)[0]) for i in range(n)]


def decode(bank, tname, pname):
    """Decodifica uma textura para um array RGBA (h, w, 4)."""
    t = bank["tex"][tname]
    d = bank["d"]
    w, h, fmt = t["w"], t["h"], t["fmt"]
    img = np.zeros((h, w, 4), np.uint8)
    poff = bank["pals"].get(pname)
    if fmt == 7:
        o = bank["tex_data"] + (t["off"] << 3)
        px = np.frombuffer(d, "<u2", w * h, o).reshape(h, w)
        img[..., 0] = (px & 31) * 255 // 31
        img[..., 1] = ((px >> 5) & 31) * 255 // 31
        img[..., 2] = ((px >> 10) & 31) * 255 // 31
        img[..., 3] = np.where(px & 0x8000, 255, 0)
        return img
    if poff is None:
        return None
    if fmt == 5:
        return decode_4x4(bank, t, poff)
    o = bank["tex_data"] + (t["off"] << 3)
    bits = {1: 8, 2: 2, 3: 4, 4: 8, 6: 8}[fmt]
    count = w * h
    raw = np.frombuffer(d, np.uint8, count * bits // 8, o)
    if bits == 2:
        idx = np.stack([(raw >> s) & 3 for s in (0, 2, 4, 6)], 1).reshape(-1)
    elif bits == 4:
        idx = np.stack([raw & 15, raw >> 4], 1).reshape(-1)
    else:
        idx = raw.astype(np.int32)
    alpha = np.full(count, 255, np.int32)
    if fmt == 1:  # A3I5
        alpha = ((idx >> 5) * 36 + (idx >> 5) // 2).clip(0, 255)
        idx = idx & 31
    elif fmt == 6:  # A5I3
        alpha = ((idx >> 3) * 255 // 31)
        idx = idx & 7
    n = int(idx.max()) + 1
    pal = np.array(palette(d, poff, n), np.uint8)
    rgb = pal[idx]
    if t["transp"] and fmt in (2, 3, 4):
        alpha = np.where(idx == 0, 0, 255)
    img[..., :3] = rgb.reshape(h, w, 3)
    img[..., 3] = np.asarray(alpha, np.uint8).reshape(h, w)
    return img


def decode_4x4(bank, t, poff):
    d = bank["d"]
    w, h = t["w"], t["h"]
    img = np.zeros((h, w, 4), np.uint8)
    o = bank["cmp_data"] + (t["off"] << 3)
    io = bank["cmp_info"] + (t["off"] << 2)
    bw = w // 4
    for bi in range(bw * (h // 4)):
        texel = struct.unpack_from("<I", d, o + 4 * bi)[0]
        info = struct.unpack_from("<H", d, io + 2 * bi)[0]
        pa = poff + ((info & 0x3FFF) << 2)
        mode = info >> 14
        c = palette(d, pa, 4 if mode in (1, 3) else 4)
        c0, c1 = c[0], c[1]
        cols = [c0 + (255,), c1 + (255,)]
        if mode == 0:
            cols += [c[2] + (255,), (0, 0, 0, 0)]
        elif mode == 1:
            cols += [tuple((a + b) // 2 for a, b in zip(c0, c1)) + (255,), (0, 0, 0, 0)]
        elif mode == 2:
            cols += [c[2] + (255,), c[3] + (255,)]
        else:
            cols += [tuple((a * 5 + b * 3) // 8 for a, b in zip(c0, c1)) + (255,),
                     tuple((a * 3 + b * 5) // 8 for a, b in zip(c0, c1)) + (255,)]
        bx, by = (bi % bw) * 4, (bi // bw) * 4
        for k in range(16):
            img[by + k // 4, bx + k % 4] = cols[(texel >> (2 * k)) & 3]
    return img


# ---------------------------------------------------------------- modelos
ARGS = {0x00: 0, 0x10: 1, 0x11: 0, 0x12: 1, 0x13: 1, 0x14: 1, 0x15: 0, 0x16: 16, 0x17: 12, 0x18: 16, 0x19: 12,
        0x1A: 9, 0x1B: 3, 0x1C: 3, 0x20: 1, 0x21: 1, 0x22: 1, 0x23: 2, 0x24: 1, 0x25: 1, 0x26: 1, 0x27: 1,
        0x28: 1, 0x29: 1, 0x2A: 1, 0x2B: 1, 0x30: 1, 0x31: 1, 0x32: 1, 0x33: 1, 0x34: 32, 0x40: 1, 0x41: 0,
        0x50: 1, 0x60: 1, 0x70: 3, 0x71: 2, 0x72: 1}


def display_list(d, off, size):
    """Executa uma display list e devolve triângulos [(pos, uv, cor)] x3."""
    words = struct.unpack_from("<%dI" % (size // 4), d, off)
    i = 0
    vtx = [0.0, 0.0, 0.0]
    uv = (0.0, 0.0)
    col = (1.0, 1.0, 1.0)
    prim, strip = 0, []
    tris = []
    scale = [1.0, 1.0, 1.0]

    def emit(v):
        strip.append(v)
        n = len(strip)
        if prim == 0 and n == 3:
            tris.append(tuple(strip)); strip.clear()
        elif prim == 1 and n == 4:
            a, b, c, e = strip
            tris.append((a, b, c)); tris.append((a, c, e)); strip.clear()
        elif prim == 2 and n >= 3:
            a, b, c = strip[-3:]
            tris.append((a, b, c) if n % 2 else (b, a, c))
        elif prim == 3 and n >= 4 and n % 2 == 0:
            a, b, c, e = strip[-4:]
            tris.append((a, b, e)); tris.append((a, e, c))

    while i < len(words):
        ops = [(words[i] >> (8 * k)) & 0xFF for k in range(4)]
        i += 1
        for op in ops:
            n = ARGS.get(op, 0)
            p = words[i:i + n]
            i += n
            if op == 0x40:
                prim = p[0] & 3; strip = []
            elif op == 0x20:
                c = p[0]; col = ((c & 31) / 31, ((c >> 5) & 31) / 31, ((c >> 10) & 31) / 31)
            elif op == 0x22:
                uv = (s16(p[0] & 0xFFFF) / 16, s16(p[0] >> 16) / 16)
            elif op in (0x23, 0x24, 0x25, 0x26, 0x27, 0x28):
                if op == 0x23:
                    vtx = [s16(p[0] & 0xFFFF) / 4096, s16(p[0] >> 16) / 4096, s16(p[1] & 0xFFFF) / 4096]
                elif op == 0x24:
                    vtx = [sbits(p[0] & 1023, 10) / 64, sbits((p[0] >> 10) & 1023, 10) / 64, sbits((p[0] >> 20) & 1023, 10) / 64]
                elif op == 0x25:
                    vtx = [s16(p[0] & 0xFFFF) / 4096, s16(p[0] >> 16) / 4096, vtx[2]]
                elif op == 0x26:
                    vtx = [s16(p[0] & 0xFFFF) / 4096, vtx[1], s16(p[0] >> 16) / 4096]
                elif op == 0x27:
                    vtx = [vtx[0], s16(p[0] & 0xFFFF) / 4096, s16(p[0] >> 16) / 4096]
                else:
                    vtx = [vtx[0] + sbits(p[0] & 1023, 10) / 4096, vtx[1] + sbits((p[0] >> 10) & 1023, 10) / 4096,
                           vtx[2] + sbits((p[0] >> 20) & 1023, 10) / 4096]
                emit((tuple(v * s for v, s in zip(vtx, scale)), uv, col))
            elif op == 0x1B:
                scale = [s16(x & 0xFFFF) / 4096 if x < 0x10000 else x / 4096 for x in p]
    return tris


def model(d):
    """Lê o primeiro modelo de um BMD0: lista de (textura, paleta, repeat, (w,h), triângulos)."""
    b = blocks(d)
    m0 = b[b"MDL0"]
    (_, mo), = dictionary(d, m0 + 8)[:1]
    mo = m0 + struct.unpack_from("<I", d, mo)[0]
    sbc_off, mat_off, shp_off = struct.unpack_from("<III", d, mo + 4)
    sbc_end = struct.unpack_from("<I", d, mo + 16)[0]
    up = struct.unpack_from("<i", d, mo + 0x1C)[0] / 4096
    # Materiais: textura/paleta associadas e parâmetros.
    mo_mat = mo + mat_off
    tdict_off, pdict_off = struct.unpack_from("<HH", d, mo_mat)
    mats = dictionary(d, mo_mat + 4)
    minfo = []
    for name, o in mats:
        mm = mo_mat + struct.unpack_from("<I", d, o)[0]
        teximg = struct.unpack_from("<I", d, mm + 0x14)[0]
        polyattr = struct.unpack_from("<I", d, mm + 0x0C)[0]
        w, h = struct.unpack_from("<HH", d, mm + 0x20)
        minfo.append(dict(name=name, teximg=teximg, w=w, h=h, alpha=(polyattr >> 16) & 31, tex=None, pal=None))
    for key, doff in (("tex", tdict_off), ("pal", pdict_off)):
        for name, o in dictionary(d, mo_mat + doff):
            lo, cnt = struct.unpack_from("<HB", d, o)
            for k in range(cnt):
                mi = d[mo_mat + lo + k]
                if mi < len(minfo):
                    minfo[mi][key] = name
    shapes = []
    for name, o in dictionary(d, mo + shp_off):
        so = mo + shp_off + struct.unpack_from("<I", d, o)[0]
        dl_off, dl_size = struct.unpack_from("<II", d, so + 8)
        shapes.append((so + dl_off, dl_size))
    # Comandos de render: MAT seleciona material, SHP desenha um shape.
    out = []
    i = mo + sbc_off
    end = mo + sbc_end
    cur = None
    lens = {0x00: 0, 0x01: 0, 0x02: 2, 0x03: 1, 0x04: 1, 0x05: 1, 0x06: 3, 0x26: 4, 0x46: 4, 0x66: 5, 0x07: 1, 0x47: 2,
            0x08: 1, 0x48: 2, 0x0B: 0, 0x2B: 0, 0x0C: 2, 0x0D: 2, 0x24: 1, 0x44: 1}
    while i < end:
        op = d[i]
        if op == 0x01:
            break
        if op in (0x04, 0x24, 0x44):
            cur = d[i + 1]
        elif op == 0x05:
            si = d[i + 1]
            if si < len(shapes) and cur is not None and cur < len(minfo):
                tris = display_list(d, *shapes[si])
                m = minfo[cur]
                out.append((m, [tuple(((p[0] * up, p[1] * up, p[2] * up), uv, c) for p, uv, c in t) for t in tris]))
        if op == 0x09:
            n = d[i + 2]
            i += 3 + 3 * n
            continue
        if op == 0x0A:
            i += 9
            continue
        i += 1 + lens.get(op, 0)
    return out
