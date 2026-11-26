"""Constrói as arenas oficiais dos 32 ginásios.

Cada arena sai em server/arenas/<id>.json com a grade de terreno (uma letra
por casa de 16px, desenhada a 32px no jogo) e os pontos de entrada.

Planta base (pedido do Leo): arquibancada em cima e embaixo, camarote do
líder em cima, do desafiante embaixo, área de combate no meio com arquitetura
própria de cada ginásio. Só as arenas PvP seriam simétricas; os ginásios têm
formas e desafios próprios.

Terreno (server/terrain.go tem as propriedades):
  .  piso de pedra       ,  piso de madeira/tatame   s  areia/terra
  m  lama                n  neve                     M  metal
  b  ponte de madeira    p  plataforma               k  plataforma que afunda
  w  água rasa           u  fonte termal             W  água funda
  > < ^ v  correnteza    i  gelo                     j  gelo rachado
  g  grama alta          o  canteiro de flores       X  teia
  l  lava                e  placa elétrica           x  veneno
  V  gêiser / válvula    Y  teleporte                } { ) (  vento
  r  rocha destrutível   h  cerca viva               I  pilar de gelo
  t  árvore              P  pilar                    R  parede / penhasco
  F  fóssil na parede    T  máquina / tubulação      G  vidro
  ~  cascata             O  vão (só voadores)        A  arquibancada
  L  camarote do líder   C  camarote do desafiante
  D  base de uma decoração (lanterna, bancada, vitrine): sólida e baixa;
     o desenho vem de client/assets/stadiums/decor.png (ferramentas/mapas/
     stadiums.py) e a arena guarda onde cada peça fica em "decor".
"""
import json
import math
import random
import re
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "server/arenas"

SOLID = set("rhItPRFTG~OALCD")
DECOR = json.loads((ROOT / "client/assets/stadiums/decor.json").read_text())
LAND_BAD = set("WlO_><^v") | SOLID


class Arena:
    def __init__(self, w, h, floor, seed):
        self.w, self.h = w, h
        self.g = [[floor] * w for _ in range(h)]
        self.floor = floor
        self.rng = random.Random(seed)
        self.spawn = [(w // 2 - 6, h - 6), (w // 2 + 5, 5)]
        self.decor = []

    def deco(self, key, x, y):
        """Põe uma peça de decoração com a base começando em (x, y)."""
        d = DECOR[key]
        fw, fh = d["foot"]
        self.rect(x, y, x + fw - 1, y + fh - 1, "D")
        self.decor.append({"k": key, "x": x, "y": y, "foot": d["foot"], "src": d["src"]})

    def border(self, c, t, keep="LCA"):
        """Faixa de `t` casas na volta da área de combate (árvores, rochas)."""
        for y in range(2, self.h - 2):
            for x in range(self.w):
                if x < t or x >= self.w - t or y < 2 + t or y > self.h - 3 - t:
                    if self.g[y][x] not in keep:
                        self.g[y][x] = c

    def path(self, pts, c, width=2, on=None):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            self.line(x0, y0, x1, y1, c, width, on)

    def ok(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def get(self, x, y):
        return self.g[y][x] if self.ok(x, y) else "R"

    def put(self, x, y, c, on=None):
        if self.ok(x, y) and (on is None or self.g[y][x] in on):
            self.g[y][x] = c

    def rect(self, x0, y0, x1, y1, c, on=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c, on)

    def ellipse(self, cx, cy, rx, ry, c, on=None, wobble=0.0):
        for y in range(int(cy - ry - 2), int(cy + ry + 3)):
            for x in range(int(cx - rx - 2), int(cx + rx + 3)):
                a = math.atan2(y - cy, x - cx)
                k = 1 + wobble * math.sin(a * 3 + cx) * .5 + wobble * math.cos(a * 5 + cy) * .3
                if ((x - cx) / (rx * k)) ** 2 + ((y - cy) / (ry * k)) ** 2 <= 1:
                    self.put(x, y, c, on)

    def ring(self, cx, cy, rx, ry, c, width=1, on=None):
        for y in range(int(cy - ry - 2), int(cy + ry + 3)):
            for x in range(int(cx - rx - 2), int(cx + rx + 3)):
                d = math.hypot((x - cx) / rx, (y - cy) / ry)
                if 1 - width / max(rx, ry) <= d <= 1:
                    self.put(x, y, c, on)

    def line(self, x0, y0, x1, y1, c, width=1, on=None):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for k in range(n + 1):
            x = round(x0 + (x1 - x0) * k / n)
            y = round(y0 + (y1 - y0) * k / n)
            for dy in range(width):
                for dx in range(width):
                    self.put(x + dx, y + dy, c, on)

    def scatter(self, c, n, region=None, on=None, clear=2):
        x0, y0, x1, y1 = region or (4, 5, self.w - 5, self.h - 6)
        on = on or {self.floor}
        placed, tries = 0, 0
        while placed < n and tries < n * 60:
            tries += 1
            x, y = self.rng.randint(x0, x1), self.rng.randint(y0, y1)
            if self.get(x, y) in on and min(abs(x - sx) + abs(y - sy) for sx, sy in self.spawn) > clear:
                self.put(x, y, c)
                placed += 1

    def blob(self, c, cx, cy, size, on=None):
        """Mancha irregular (rochas agrupadas, poças, moitas)."""
        cells = [(cx, cy)]
        for _ in range(size):
            x, y = self.rng.choice(cells)
            nx, ny = x + self.rng.choice((-1, 0, 1)), y + self.rng.choice((-1, 0, 1))
            if self.ok(nx, ny):
                cells.append((nx, ny))
        for x, y in cells:
            self.put(x, y, c, on)

    def frame(self, wall="R", shape="rect", cut=4):
        """Arquibancada, camarotes e o contorno da área de combate."""
        w, h = self.w, self.h
        self.rect(0, 0, w - 1, 1, "A")
        self.rect(0, h - 2, w - 1, h - 1, "A")
        self.rect(0, 2, w - 1, 2, wall)
        self.rect(0, h - 3, w - 1, h - 3, wall)
        self.rect(0, 2, 0, h - 3, wall)
        self.rect(w - 1, 2, w - 1, h - 3, wall)
        if shape == "oct":
            for k in range(cut):
                self.rect(1, 3 + k, cut - k, 3 + k, wall)
                self.rect(w - 1 - cut + k, 3 + k, w - 2, 3 + k, wall)
                self.rect(1, h - 4 - k, cut - k, h - 4 - k, wall)
                self.rect(w - 1 - cut + k, h - 4 - k, w - 2, h - 4 - k, wall)
        elif shape == "round":
            cx, cy = (w - 1) / 2, (h - 1) / 2
            for y in range(3, h - 3):
                for x in range(1, w - 1):
                    if ((x - cx) / (w / 2 - .5)) ** 2 + ((y - cy) / (h / 2 - 2.2)) ** 2 > 1:
                        self.put(x, y, wall)
        elif shape == "cave":
            for y in range(3, h - 3):
                n = int(1.6 + 1.3 * math.sin(y * .7 + self.rng.random()) + self.rng.random())
                m = int(1.6 + 1.3 * math.cos(y * .55 + self.rng.random()) + self.rng.random())
                self.rect(1, y, n, y, wall)
                self.rect(w - 1 - m, y, w - 2, y, wall)
            for x in range(1, w - 1):
                n = int(.8 + 1.1 * math.sin(x * .6 + self.rng.random()))
                self.rect(x, 3, x, 3 + n, wall)
                self.rect(x, h - 4 - n, x, h - 4, wall)
        mid = w // 2
        self.rect(mid - 3, 2, mid + 2, 3, "L")
        self.rect(mid - 3, h - 4, mid + 2, h - 3, "C")

    def clear_spawns(self, c=None):
        for sx, sy in self.spawn:
            for y in range(sy - 1, sy + 2):
                for x in range(sx - 1, sx + 2):
                    if self.get(x, y) in LAND_BAD | set("gV"):
                        self.put(x, y, c or self.floor)

    def connect(self, bridge="b"):
        """Garante um caminho por terra entre os dois Pokémon."""
        (ax, ay), (bx, by) = self.spawn
        prev = {(ax, ay): None}
        q = deque([(ax, ay)])
        while q:
            x, y = q.popleft()
            if (x, y) == (bx, by):
                return
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if self.ok(*n) and n not in prev and self.get(*n) not in LAND_BAD:
                    prev[n] = (x, y)
                    q.append(n)
        # Sem caminho: abre uma passagem em L.
        x, y = ax, ay
        while (x, y) != (bx, by):
            if x != bx:
                x += 1 if bx > x else -1
            else:
                y += 1 if by > y else -1
            c = self.get(x, y)
            if c in "WlO><^v_":
                self.put(x, y, bridge)
            elif c in SOLID:
                self.put(x, y, self.floor)

    def dump(self, gid, theme, title):
        rows = ["".join(r) for r in self.g]
        # Decoração que algum desenho posterior apagou sai da lista.
        keep = [d for d in self.decor if self.get(d["x"], d["y"]) == "D"]
        return {"id": gid, "theme": theme, "title": title, "w": self.w, "h": self.h,
                "cells": "".join(rows), "spawn": [list(s) for s in self.spawn], "decor": keep}


# --- Ginásios com projeto próprio ------------------------------------------
# Plantas seguindo os conceitos do Leo (previews/conceito_arenas_leo.png):
# borda temática grossa, camarote do líder em cima e do desafiante embaixo,
# um eixo central legível e quatro "quadrantes" com o desafio do ginásio.

def pewter(a):
    """Pedreira monumental: areia, paredões irregulares, um platô de pedra no
    meio, grupos de rochas que viram cobertura, estátuas e a vitrine do fóssil."""
    a.floor = "s"; a.g = [["s"] * a.w for _ in range(a.h)]
    a.frame("R", "cave")
    w, h = a.w, a.h
    # Paredões internos em arco, abrindo corredores laterais.
    a.path([(4, 6), (4, 9), (6, 11)], "R", 1)
    a.path([(4, 14), (4, h - 7), (7, h - 6)], "R", 1)
    a.path([(w - 5, 5), (w - 5, 9)], "R", 1)
    a.path([(w - 7, 13), (w - 5, 15), (w - 5, h - 7)], "R", 1)
    a.path([(8, 5), (11, 5)], "R", 1)
    # Platô de pedra no centro, com degraus para cima e para baixo.
    a.ellipse(w / 2, h / 2 + .5, 6.5, 4, ".", on={"s"}, wobble=.25)
    a.rect(w // 2 - 1, 4, w // 2, h - 5, ".", on={"s"})
    # Estátuas (indestrutíveis) e grupos de rochas (destrutíveis).
    for x, y in ((9, 8), (w - 11, h - 9)):
        a.rect(x, y, x + 1, y + 1, "P")
    for cx, cy, n in ((6, 7, 5), (w - 9, 9, 4), (8, h - 8, 5), (w - 8, h - 7, 3), (w // 2 - 8, h // 2 + 1, 2), (w // 2 + 8, h // 2, 2)):
        a.blob("r", cx, cy, n, on={"s"})
    a.deco("fossil_case", w - 10, 4)
    for x, y in ((2, 7), (w - 3, 12), (3, h - 8)):
        if a.get(x, y) == "R":
            a.put(x, y, "F")
    a.spawn = [(w // 2 - 6, h - 6), (w // 2 + 5, 6)]


def cerulean(a):
    """Estádio aquático: piscina olímpica com passarela em cruz, ponte de
    madeira atravessando, raias com correnteza, plataformas soltas (algumas
    afundam) e duas cascatas no fundo."""
    a.floor = "."
    a.frame("R", "rect")
    w, h = a.w, a.h
    x0, y0, x1, y1 = 4, 6, w - 5, h - 6
    a.rect(x0, y0, x1, y1, "W")
    a.rect(x0, y1, x1, y1, "w")  # degrau raso na borda de baixo
    # Raias com correnteza em sentidos opostos.
    a.rect(x0 + 1, y0 + 2, x1 - 1, y0 + 2, ">")
    a.rect(x0 + 1, y1 - 3, x1 - 1, y1 - 3, "<")
    # Cascatas despejando na piscina.
    for x in (2, w - 4):
        a.rect(x, 3, x + 1, 3, "~")
        a.rect(x, 4, x + 1, y0, "v")
    # Passarela em cruz: do camarote do líder ao do desafiante, e a ponte.
    mid = w // 2
    a.rect(mid - 1, y0, mid, y0 + 4, "p")
    a.rect(mid - 1, y1 - 4, mid, y1, "p")
    a.rect(mid - 2, h // 2 - 2, mid + 1, h // 2 + 1, "p")
    a.rect(x0, h // 2 - 1, mid - 3, h // 2 - 1, "b")
    a.rect(mid + 2, h // 2 - 1, x1, h // 2 - 1, "b")
    # Plataformas soltas: as fixas e as que afundam.
    for x, y in ((x0 + 3, y0 + 4), (x1 - 5, y0 + 4), (x0 + 5, y1 - 2), (x1 - 6, y1 - 2)):
        a.rect(x, y, x + 2, y, "p")
    for x, y in ((mid - 5, y0 + 1), (mid + 4, y0 + 1), (mid - 6, y1 - 5), (mid + 5, y1 - 5), (x0 + 1, h // 2 + 2), (x1 - 2, h // 2 - 4)):
        a.rect(x, y, x + 1, y, "k")
    a.spawn = [(w // 2 - 6, h - 5), (w // 2 + 5, 4)]


def celadon(a):
    """Estufa: parede de vidro, canteiros de flores na borda, caminhos de areia
    em cruz, quatro canteiros de grama alta, pés de fruta e uma praça no meio."""
    a.floor = "."
    a.frame("G", "rect")
    w, h = a.w, a.h
    # Canteiros de flores encostados no vidro, com árvores nos cantos.
    for x in range(1, w - 1):
        a.put(x, 3, "o"); a.put(x, h - 4, "o")
    for y in range(3, h - 3):
        a.put(1, y, "o"); a.put(w - 2, y, "o")
    for x, y in ((2, 4), (w - 3, 4), (2, h - 5), (w - 3, h - 5), (2, h // 2), (w - 3, h // 2)):
        a.put(x, y, "t")
    a.rect(w // 2 - 3, 3, w // 2 + 2, 3, ".")
    a.rect(w // 2 - 3, h - 4, w // 2 + 2, h - 4, ".")
    # Quatro canteiros de grama alta, com cerca viva e pés de fruta.
    q = ((5, 6, w // 2 - 4, h // 2 - 3), (w // 2 + 3, 6, w - 6, h // 2 - 3),
         (5, h // 2 + 2, w // 2 - 4, h - 7), (w // 2 + 3, h // 2 + 2, w - 6, h - 7))
    for k, (qx0, qy0, qx1, qy1) in enumerate(q):
        a.rect(qx0, qy0, qx1, qy1, "g")
        for x, y in ((qx0, qy0), (qx1, qy0), (qx0, qy1), (qx1, qy1)):
            a.put(x, y, ".")
        a.put(qx0 + 1, qy1, "h"); a.put(qx1 - 1, qy0, "h")
    for k, x in enumerate(range(7, 12, 2)):
        a.deco(("berry_cheri", "berry_pecha", "berry_oran")[k], x, 6)
    for k, x in enumerate(range(w - 12, w - 7, 2)):
        a.deco(("berry_oran", "berry_cheri", "berry_pecha")[k], x, h - 7)
    for x, y in ((4, 5), (w - 5, 5), (4, h - 6), (w - 5, h - 6)):
        a.deco("plant", x, y)
    # Praça de tijolos no cruzamento dos caminhos.
    a.rect(w // 2 - 2, h // 2 - 2, w // 2 + 1, h // 2 + 1, ",")
    for x, y in ((w // 2 - 3, h // 2 - 3), (w // 2 + 2, h // 2 + 2)):
        a.put(x, y, "o")


def cinnabar(a):
    """Laboratório vulcânico: piso escuro de metal, passarela clara em cruz,
    duas piscinas de lava, bancadas, a máquina do laboratório, consoles
    nas paredes, rochas soltas e válvulas de vapor."""
    a.floor = "M"
    a.g = [["M"] * a.w for _ in range(a.h)]
    a.frame("R", "rect")
    w, h = a.w, a.h
    cx, cy = w // 2, h // 2
    a.rect(cx - 2, 3, cx + 1, h - 4, ".")
    a.rect(4, cy - 1, w - 5, cy + 1, ".")
    a.rect(cx - 3, cy - 2, cx + 2, cy + 2, ".")
    # Lava contida, com borda de aviso.
    a.ellipse(w - 12, 9, 6, 3.5, "l", on={"M"}, wobble=.3)
    a.ellipse(12, h - 10, 6, 3.5, "l", on={"M"}, wobble=.3)
    # Laboratório: máquina, estantes, bancadas e consoles.
    a.deco("lab_machine", 4, 5)
    a.deco("lab_shelf", 8, 4)
    a.deco("lab_desk", 7, 10)
    a.deco("lab_desk", w - 11, h - 8)
    a.deco("lab_shelf", w - 7, h - 12)
    a.deco("lab_machine", w - 6, h - 7)
    for x, y in ((1, 9), (1, 10), (1, h - 14), (w - 2, 14), (w - 2, 15), (w - 2, h - 6)):
        a.put(x, y, "T")
    # Rochas soltas (cobertura) e válvulas de vapor.
    for x, y in ((cx - 9, 7), (cx + 7, cy - 6), (cx - 8, cy + 6), (cx + 9, h - 8), (5, cy - 4), (w - 6, cy + 4), (cx - 14, cy + 3), (cx + 14, cy - 3)):
        a.put(x, y, "r")
    for x, y in ((cx - 6, cy - 5), (cx + 5, cy + 5), (w - 9, cy - 2), (8, cy + 3)):
        a.put(x, y, "V")


def lavaridge(a):
    """Santuário termal: borda de pedra vulcânica com árvores e lanternas,
    duas fontes termais com margem de pedras, ilhas, gêiseres e uma ponte de
    madeira em S ligando os dois camarotes."""
    a.floor = "."
    a.frame("R", "rect")
    w, h = a.w, a.h
    a.border("R", 2)
    for x, y in ((2, 4), (w - 3, 4), (2, h - 5), (w - 3, h - 5), (2, h // 2), (w - 3, h // 2 - 2)):
        a.put(x, y, "t")
    # Fontes termais com margem de rochas (as rochas quebram).
    for cx in (11, w - 12):
        a.ellipse(cx, h / 2, 7.5, 7, "r", wobble=.15)
        a.ellipse(cx, h / 2, 6.5, 6, "u", wobble=.15)
        a.blob("r", cx - 2, h // 2 - 2, 2, on={"u"})
        a.put(cx + 2, h // 2 + 2, "V")
    # Ponte em S do líder ao desafiante, cortando as duas fontes.
    mid = w // 2
    a.path([(mid - 1, 4), (mid - 1, 7), (mid - 5, 10), (mid - 5, 13), (mid + 3, 17), (mid + 3, 21), (mid - 1, h - 6), (mid - 1, h - 4)], "b", 2)
    for x, y in ((mid - 9, 5), (mid + 8, 5), (mid - 9, h - 6), (mid + 8, h - 6), (4, h // 2 - 4), (w - 5, h // 2 + 3)):
        a.deco("lantern", x, y)
    a.spawn = [(w // 2 - 6, h - 6), (w // 2 + 5, 5)]


def mahogany(a):
    """Lago glacial: margens de neve com pinheiros nevados, um lago de gelo
    com uma rachadura atravessando, cristais de gelo e um buraco na água."""
    a.floor = "n"
    a.g = [["n"] * a.w for _ in range(a.h)]
    a.frame("R", "cave")
    w, h = a.w, a.h
    for x, y in ((3, 5), (5, 4), (w - 4, 5), (w - 6, 4), (3, h - 6), (5, h - 5), (w - 4, h - 6), (w - 6, h - 5), (2, h // 2), (w - 3, h // 2 + 1), (8, 4), (w - 9, h - 5)):
        if a.get(x, y) == "n":
            a.put(x, y, "t")
    a.ellipse(w / 2, h / 2 + .5, w / 2 - 6, h / 2 - 5.5, "i", on={"n"}, wobble=.18)
    # Rachadura em zigue-zague de cima a baixo.
    a.path([(w // 2, 6), (w // 2 - 3, 11), (w // 2 + 2, 16), (w // 2 - 2, 22), (w // 2 + 3, 27), (w // 2, h - 7)], "j", 1, on={"i"})
    a.path([(w // 2 - 3, 11), (w // 2 - 10, 14)], "j", 1, on={"i"})
    a.path([(w // 2 + 2, 16), (w // 2 + 11, 19)], "j", 1, on={"i"})
    # Cristais de gelo (seguram disparos e quebram).
    for cx, cy in ((w // 2 - 11, 10), (w // 2 + 10, 12), (w // 2 - 7, h - 10), (w // 2 + 8, h - 11)):
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            a.put(cx + dx, cy + dy, "I", on={"i", "j", "n"})
    a.ellipse(w / 2 + 1, h / 2 + 1, 2.5, 1.5, "W", on={"i", "j"})


def ecruteak(a):
    """Templo assombrado: assoalho de madeira em cruz sobre a pedra escura,
    quatro fossos (só quem voa atravessa) com pedras soltas, lanternas
    violeta, árvores roxas e portais no meio do templo."""
    a.floor = "."
    a.frame("R", "rect")
    w, h = a.w, a.h
    mid, cy = w // 2, h // 2
    # Alas do templo nos cantos de cima e de baixo.
    for x0, y0 in ((1, 3), (w - 9, 3), (1, h - 6), (w - 9, h - 6)):
        a.rect(x0, y0, x0 + 7, y0 + 2, "R")
    # Fossos em cada quadrante.
    for qx, qy in ((mid - 12, cy - 9), (mid + 4, cy - 9), (mid - 12, cy + 3), (mid + 4, cy + 3)):
        a.rect(qx, qy, qx + 7, qy + 5, "O")
        a.put(qx, qy, "."); a.put(qx + 7, qy + 5, ".")
        a.put(qx + 2, qy + 2, "r"); a.put(qx + 5, qy + 3, "r")
    a.rect(mid - 2, 3, mid + 1, h - 4, ",")
    a.rect(2, cy - 1, w - 3, cy + 1, ",")
    a.put(mid - 1, cy, "Y"); a.put(mid, cy - 1, "Y")
    for x, y in ((mid - 4, 5), (mid + 3, 5), (mid - 4, h - 6), (mid + 3, h - 6), (3, cy - 3), (w - 4, cy + 3)):
        a.deco("lantern_violet", x, y)
    for x, y in ((2, 7), (w - 3, h - 8)):
        a.put(x, y, "t")
    a.spawn = [(mid - 6, h - 6), (mid + 5, 5)]


def eterna(a):
    """Floresta ancestral: mata fechada na borda, trilhas de terra em
    diagonal, canteiros de grama alta, arcos de pedra e o círculo no meio."""
    a.floor = "."
    a.frame("R", "rect")
    w, h = a.w, a.h
    a.border("t", 2)
    for x, y in ((3, 4), (w - 4, 4), (3, h - 5), (w - 4, h - 5), (3, 9), (w - 4, h - 10)):
        a.put(x, y, "t")
    mid = w // 2
    a.path([(mid - 1, 4), (mid - 1, 6), (mid - 7, 11), (mid - 9, h - 6)], "s", 2)
    a.path([(mid - 1, h - 5), (mid + 1, h - 8), (mid + 7, 9), (mid + 9, 5)], "s", 2)
    for x0, y0, x1, y1 in ((4, 5, 9, 8), (w - 12, 11, w - 5, 14), (5, 14, 10, 18), (mid + 3, h - 8, mid + 8, h - 6)):
        a.rect(x0, y0, x1, y1, "g", on={"."})
    a.ring(mid - .5, h / 2 - .5, 3.2, 3.2, "s", width=1)
    a.put(mid - 1, h // 2 - 1, "P")
    for x, y in ((4, 10), (w - 5, 6), (5, h - 7), (w - 6, h - 8)):
        a.put(x, y, "P")
    a.spawn = [(mid - 6, h - 6), (mid + 5, 5)]


# --- Ginásios gerados pelo tema (cada um com sua forma e semente) -------------

def themed(a, theme, gid):
    r = a.rng
    w, h = a.w, a.h
    shapes = ["rect", "oct", "round", "cave"]
    shape = shapes[r.randrange(4)]
    if theme == "eletrico":
        a.floor = "M"; a.g = [["M"] * w for _ in range(h)]
        a.frame("T", shape if shape != "cave" else "oct")
        for k in range(3):
            y = 7 + k * (h - 14) // 2
            a.line(4, y, w - 5, y, "e", on={"M"})
        for _ in range(6):
            x, y = r.randint(5, w - 7), r.randint(6, h - 8)
            a.rect(x, y, x + 1, y + 1, "T", on={"M", "e"})
        a.scatter("V", 3, on={"M"})
    elif theme == "planta":
        celadon(a)
    elif theme == "inseto":
        a.floor = "g"; a.g = [["g"] * w for _ in range(h)]
        a.frame("R", "cave")
        a.ellipse(w / 2, h / 2, w / 2 - 8, h / 2 - 7, ".", on={"g"}, wobble=.4)
        a.scatter("t", 10, on={"g"}); a.scatter("X", 7, on={"g", "."})
        for _ in range(4):
            a.blob("o", r.randint(6, w - 7), r.randint(6, h - 7), 3, on={"g"})
    elif theme == "veneno":
        a.floor = ","; a.g = [[","] * w for _ in range(h)]
        a.frame("R", "rect")
        for _ in range(5):
            a.blob("x", r.randint(6, w - 7), r.randint(6, h - 7), 6, on={","})
        for x in range(6, w - 6, 6):
            a.rect(x, 6 + (x % 4), x, 6 + (x % 4), "P")
            a.rect(x, h - 8 - (x % 3), x, h - 8 - (x % 3), "P")
        a.scatter("V", 4, on={","})  # bombas de fumaça
    elif theme == "psiquico":
        a.frame("R", "round")
        a.ring(w / 2, h / 2, 6, 4.5, "P", width=1)
        a.ellipse(w / 2, h / 2, 5, 3.5, ".", on={"P"})
        for k in range(8):
            ang = k * math.pi / 4
            x, y = int(w / 2 + math.cos(ang) * 6), int(h / 2 + math.sin(ang) * 4.5)
            if k % 2:
                a.put(x, y, ".")
        for x, y in ((6, 6), (w - 7, h - 7), (w - 7, 6), (6, h - 7)):
            a.put(x, y, "Y")
    elif theme == "fogo":
        lavaridge(a) if "hoenn" in gid else cinnabar(a)
    elif theme == "terra":
        a.floor = "s"; a.g = [["s"] * w for _ in range(h)]
        a.frame("R", "cave")
        for _ in range(5):
            x, y = r.randint(6, w - 8), r.randint(6, h - 8)
            a.line(x, y, x + r.randint(-5, 5), y + r.randint(-3, 3), "R", on={"s"})
        for _ in range(4):
            a.blob("m", r.randint(6, w - 7), r.randint(6, h - 7), 6, on={"s"})
        a.scatter("r", 8, on={"s"})
    elif theme == "rocha":
        pewter(a)
    elif theme == "agua":
        if "hoenn" in gid:  # Sootopolis: palácio com nível da água
            a.floor = "."; a.frame("P", "round")
            a.ellipse(w / 2, h / 2, w / 2 - 6, h / 2 - 5, "W", wobble=.15)
            a.ring(w / 2, h / 2, w / 2 - 6, h / 2 - 5, "w", width=1)
            for k in range(6):
                ang = k * math.pi / 3
                a.rect(int(w / 2 + math.cos(ang) * 7) - 1, int(h / 2 + math.sin(ang) * 5), int(w / 2 + math.cos(ang) * 7), int(h / 2 + math.sin(ang) * 5), "p")
            for k in range(4):
                a.put(int(w / 2 + math.cos(k * 1.57 + .7) * 4), int(h / 2 + math.sin(k * 1.57 + .7) * 3), "k")
        elif "sinnoh" in gid:  # Pastoria: pântano esportivo
            a.floor = "m"; a.g = [["m"] * w for _ in range(h)]
            a.frame("R", "oct")
            for _ in range(6):
                a.blob("w", r.randint(6, w - 7), r.randint(6, h - 7), 10, on={"m"})
            for _ in range(3):
                a.blob("W", r.randint(8, w - 9), r.randint(8, h - 9), 6, on={"w", "m"})
            a.scatter("g", 14, on={"m"})
            a.scatter("p", 6, on={"m"})
        else:
            cerulean(a)
    elif theme == "gelo":
        mahogany(a) if "johto" in gid else snowpoint(a)
    elif theme == "voador":
        a.floor = "b"; a.g = [["b"] * w for _ in range(h)]
        a.frame("R", "rect")
        for _ in range(7):
            x, y = r.randint(5, w - 8), r.randint(6, h - 9)
            a.rect(x, y, x + r.randint(1, 3), y + r.randint(1, 2), "O", on={"b"})
        for y in range(6, h - 6, 5):
            c = "}" if (y // 5) % 2 else "{"
            a.rect(4, y, w - 5, y, c, on={"b"})
        a.scatter("p", 5, on={"b"})
    elif theme == "lutador":
        a.floor = ","; a.g = [[","] * w for _ in range(h)]
        a.frame("R", "rect" if "sinnoh" not in gid else "oct")
        a.ring(w / 2, h / 2, 7, 5, ".", width=1)
        for x, y in ((6, 6), (w - 7, 6), (6, h - 7), (w - 7, h - 7)):
            a.rect(x, y, x + 1, y + 1, "P")
        if "johto" in gid:  # Cianwood: cachoeira dentro do dojo
            a.rect(w - 6, 3, w - 5, 3, "~")
            a.rect(w - 6, 4, w - 5, h - 5, "v", on={","})
        if "hoenn" in gid:  # Dewford: caverna escura
            a.frame("R", "cave")
        a.scatter("r", 5)
    elif theme == "normal":
        a.frame("R", "round")
        a.ring(w / 2, h / 2, w / 2 - 4, h / 2 - 4, ",", width=2)
        a.scatter("P", 4)
        if "hoenn" in gid:  # Norman: salas de teste
            for x in range(8, w - 8, 8):
                a.line(x, 5, x, h // 2 - 3, "R")
    elif theme == "fantasma":
        a.frame("R", "cave" if "johto" in gid else "oct")
        for _ in range(8):
            x, y = r.randint(5, w - 7), r.randint(6, h - 8)
            a.rect(x, y, x + r.randint(0, 2), y + r.randint(0, 1), "O")
        a.scatter("P", 6)
        a.scatter("Y", 4, on={"."})
    elif theme == "aco":
        a.floor = "M"; a.g = [["M"] * w for _ in range(h)]
        a.frame("T", "rect")
        for _ in range(8):
            x, y = r.randint(5, w - 8), r.randint(6, h - 8)
            a.rect(x, y, x + 1, y + r.randint(0, 2), "T", on={"M"})
        a.scatter("r", 4, on={"M"})
        if "sinnoh" in gid:  # Canalave: estaleiro com água no meio
            a.rect(w // 2 - 2, 5, w // 2 + 1, h - 6, "W")
            for y in (8, h - 10):
                a.rect(w // 2 - 2, y, w // 2 + 1, y + 1, "M")
    elif theme == "dragao":
        a.floor = "s"; a.g = [["s"] * w for _ in range(h)]
        a.frame("R", "cave")
        a.ellipse(w / 2, h / 2, 7, 4, "l", wobble=.3)
        a.ellipse(w / 2, h / 2, 3, 2, "r", on={"l"})
        for _ in range(3):
            a.blob("W", r.randint(6, w - 7), r.randint(6, h - 7), 5, on={"s"})
        a.scatter("P", 5, on={"s"})
        a.scatter("}", 6, on={"s"})
    return a


def snowpoint(a):
    """Templo nevado: neve funda, gelo, pilares e avalanche nas bordas."""
    a.floor = "n"; a.g = [["n"] * a.w for _ in range(a.h)]
    a.frame("R", "oct")
    w, h = a.w, a.h
    for _ in range(5):
        a.blob("i", a.rng.randint(6, w - 7), a.rng.randint(6, h - 7), 14, on={"n"})
    for x in range(7, w - 7, 7):
        a.put(x, h // 2, "I")
    a.scatter("r", 5, on={"n"})


FEATURED = {"kanto_1": pewter, "kanto_2": cerulean, "kanto_4": celadon,
            "kanto_7": cinnabar, "hoenn_4": lavaridge, "johto_7": mahogany,
            "johto_4": ecruteak, "sinnoh_2": eterna}

TITLES = {
    "kanto_1": "Pedreira Monumental", "kanto_2": "Estádio Aquático", "kanto_3": "Usina Elétrica",
    "kanto_4": "Jardim Botânico", "kanto_5": "Dojo Ninja", "kanto_6": "Templo Psíquico",
    "kanto_7": "Laboratório Vulcânico", "kanto_8": "Fortaleza Subterrânea",
    "hoenn_1": "Museu Geológico", "hoenn_2": "Dojo da Caverna", "hoenn_3": "Central Energética",
    "hoenn_4": "Santuário Termal", "hoenn_5": "Arena de Treinamento", "hoenn_6": "Copas das Árvores",
    "hoenn_7": "Observatório Espacial", "hoenn_8": "Palácio Aquático",
    "johto_1": "Pagode Suspenso", "johto_2": "Floresta dos Insetos", "johto_3": "Estádio Esportivo",
    "johto_4": "Templo Assombrado", "johto_5": "Dojo da Cachoeira", "johto_6": "Fundição",
    "johto_7": "Lago Glacial", "johto_8": "Santuário dos Dragões",
    "sinnoh_1": "Mina Subterrânea", "sinnoh_2": "Floresta Ancestral", "sinnoh_3": "Teatro Gótico",
    "sinnoh_4": "Coliseu Marcial", "sinnoh_5": "Pântano Esportivo", "sinnoh_6": "Estaleiro",
    "sinnoh_7": "Templo Nevado", "sinnoh_8": "Reator Solar", "aurora_1": "Estufa da Alvorada",
}


def size_for(gid):
    n = int(gid.split("_")[1])
    if n <= 3:
        return 32, 24
    if n <= 6:
        return 40, 30
    return 48, 36


def main():
    src = (ROOT / "server/field.go").read_text()
    themes = dict(re.findall(r'"(\w+_\d)":\s*"(\w+)"', src))
    OUT.mkdir(parents=True, exist_ok=True)
    for gid, theme in sorted(themes.items()):
        w, h = size_for(gid)
        a = Arena(w, h, ".", gid)
        if gid in FEATURED:
            FEATURED[gid](a)
        else:
            themed(a, theme, gid)
        a.clear_spawns()
        a.connect()
        (OUT / f"{gid}.json").write_text(json.dumps(a.dump(gid, theme, TITLES.get(gid, "")), ensure_ascii=False))
        print(gid, theme, w, h)


if __name__ == "__main__":
    main()
