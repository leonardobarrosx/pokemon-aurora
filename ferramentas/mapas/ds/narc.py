import struct
def narc(path):
    d=open(path,"rb").read()
    assert d[:4]==b"NARC",d[:4]
    off=struct.unpack_from("<H",d,12)[0]
    assert d[off:off+4]==b"BTAF"
    size,n=struct.unpack_from("<IH",d,off+4)
    fat=[struct.unpack_from("<II",d,off+12+8*i) for i in range(n)]
    off+=size
    assert d[off:off+4]==b"BTNF"
    off+=struct.unpack_from("<I",d,off+4)[0]
    assert d[off:off+4]==b"GMIF"
    base=off+8
    return [d[base+a:base+b] for a,b in fat]
