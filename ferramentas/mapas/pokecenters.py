"""Troca os Centros Pokémon de Johto e Sinnoh (desenhados a partir do 3D do DS)
pelos interiores dos jogos de GBA: Johto usa o do FireRed e Sinnoh o do Emerald.

Cada Centro de DS vira uma cópia do modelo GBA (tiles, colisão, enfermeira e
visitantes). As saídas continuam levando para a mesma porta da cidade, a escada
leva ao andar de cima (2F em Sinnoh, B1F em Johto) e as portas da cidade
passam a chegar logo acima do tapete do modelo.

Uso: python3 pokecenters.py   (depois de ds_region.py e sinnoh.py)
"""
import json, os, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
CDIR = os.path.join(ROOT, "client/assets/maps")
SDIR = os.path.join(ROOT, "server/maps")
# região: (prefixo, 1F modelo, 2F modelo, cidade do modelo, sufixo do andar de cima)
TEMPLATES = {
    "johto": ("jt_", "kt_viridian_city_pokemon_center_1f", "kt_viridian_city_pokemon_center_2f", "kt_viridian_city", "b1f"),
    "sinnoh": ("sn_", "hn_oldale_town_pokemon_center_1f", "hn_oldale_town_pokemon_center_2f", "hn_oldale_town", "2f"),
}
CLIENT_KEYS = ("w", "h", "cell", "atlas", "columns", "tiles", "border", "above", "npcs", "points", "default")
SERVER_KEYS = ("w", "h", "cell", "cells", "npcs", "points", "default", "spawns", "connections", "encounters", "water", "cave")


def load(kind, area):
    return json.load(open(os.path.join(CDIR if kind == "c" else SDIR, area + ".json")))


def save(kind, area, d):
    json.dump(d, open(os.path.join(CDIR if kind == "c" else SDIR, area + ".json"), "w"), separators=(",", ":"))


def arrival(src, to):
    """Ponto de chegada (tx, ty) usado pelo modelo ao entrar em `to` vindo de `src`."""
    w = next(w for w in load("s", src)["warps"] if w["to"] == to)
    return w["tx"], w["ty"]


def copy(t1, area, name, region, warps):
    c, s = load("c", t1), load("s", t1)
    client = {k: c[k] for k in CLIENT_KEYS if k in c}
    client.update(name=name, region=region)
    server = {k: s[k] for k in SERVER_KEYS if k in s}
    server.update(name=name, warps=warps)
    save("c", area, client)
    save("s", area, server)


def main():
    servers = {f[:-5]: None for f in os.listdir(SDIR) if f.endswith(".json")}
    done = 0
    for region, (prefix, t1, t2, tcity, up) in TEMPLATES.items():
        door_in = arrival(tcity, t1)        # chegando da cidade
        stairs_up = arrival(t1, t2)         # subindo a escada
        stairs_down = arrival(t2, t1)       # descendo a escada
        for area in sorted(servers):
            m = re.match(r"(%s.*_pokecenter)_1f$" % prefix, area)
            if not m:
                continue
            base = m.group(1)
            upper = base + "_" + up
            old = load("s", area)
            old_c = load("c", area)
            exits = [w for w in old["warps"] if "_pokecenter_" not in w["to"]]
            if not exits:
                print("sem saída:", area)
                continue
            out = exits[0]
            warps = []
            for w in load("s", t1)["warps"]:
                w = dict(w)
                if w["to"] == tcity:
                    w.update(to=out["to"], tx=out["tx"], ty=out["ty"])
                elif w["to"] == t2 and upper in servers:
                    w.update(to=upper, tx=stairs_up[0], ty=stairs_up[1])
                else:
                    continue
                warps.append(w)
            copy(t1, area, old_c.get("name", old.get("name", "")), region, warps)
            if upper in servers:
                up_c = load("c", upper)
                name = re.sub(r"\b[Bb]1[Ff]$", "2F", up_c.get("name", ""))
                warps2 = [dict(w, to=area, tx=stairs_down[0], ty=stairs_down[1]) for w in load("s", t2)["warps"] if w["to"] == t1]
                copy(t2, upper, name, region, warps2)
            # Portas da cidade chegam em cima do tapete do modelo.
            s = load("s", out["to"])
            for w in s["warps"]:
                if w["to"] == area:
                    w["tx"], w["ty"] = door_in
            save("s", out["to"], s)
            done += 1
    print(done, "Centros Pokémon trocados pelo interior do GBA")


if __name__ == "__main__":
    main()
