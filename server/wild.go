package main

import (
	"math"
	mathrand "math/rand/v2"
)

// Pokémon selvagens visíveis: andam pelo mato (ou pela água e pelo chão das
// cavernas) perto dos treinadores. Encostar num deles começa a batalha ali
// mesmo, no mapa, em tempo real.

type Wild struct {
	ID      string  `json:"id"`
	Species int     `json:"species"`
	Level   int     `json:"level"`
	Pos     Vec     `json:"pos"`
	Dir     Vec     `json:"-"`
	Facing  int     `json:"facing"`
	Water   bool    `json:"water"`
	Turn    float64 `json:"-"`
	Born    float64 `json:"born"`
}

const (
	wildNear    = 360.0 // raio onde aparecem em volta do treinador
	wildFar     = 620.0 // longe assim de todos, somem
	wildPerSeat = 4     // por treinador no mapa
	wildTouch   = 26.0
)

// habitat diz se o selvagem pode estar naquela célula.
func habitat(m *AreaMap, v Vec, water bool) bool {
	c := m.at(v)
	if water {
		return c == '~'
	}
	if m.Cave {
		return c == '.' || c == '"'
	}
	return c == '"'
}

// wildPool escolhe os Pokémon possíveis naquele ponto do mapa.
func wildPool(area string, m *AreaMap, v Vec, water bool) []int {
	if water {
		return m.Water
	}
	if z := m.zone(v); z != nil && len(z.Encounters) > 0 {
		return z.Encounters
	}
	if len(m.Encounters) > 0 {
		return m.Encounters
	}
	return routePool[area]
}

func (w *World) tickWild(dt, now float64) {
	if w.Wild == nil {
		w.Wild = map[string][]*Wild{}
	}
	seats := map[string][]*Player{}
	for _, p := range w.Players {
		if areaMaps[p.Area] != nil && now-p.Seen < 30 {
			seats[p.Area] = append(seats[p.Area], p)
		}
	}
	for area, list := range w.Wild {
		m := areaMaps[area]
		kept := list[:0]
		for _, wm := range list {
			near := false
			for _, p := range seats[area] {
				if distance(p.Pos, wm.Pos) < wildFar {
					near = true
				}
			}
			if !near {
				continue
			}
			wm.wander(m, dt, now)
			kept = append(kept, wm)
		}
		w.Wild[area] = kept
	}
	for area, players := range seats {
		m := areaMaps[area]
		for _, p := range players {
			count := 0
			for _, wm := range w.Wild[area] {
				if distance(p.Pos, wm.Pos) < wildNear {
					count++
				}
			}
			if count >= wildPerSeat || mathrand.Float64() > dt*1.5 {
				continue
			}
			if wm := spawnWild(area, m, p, now); wm != nil {
				w.Wild[area] = append(w.Wild[area], wm)
			}
		}
	}
}

func spawnWild(area string, m *AreaMap, p *Player, now float64) *Wild {
	water := mathrand.IntN(3) == 0 && len(m.Water) > 0
	for try := 0; try < 24; try++ {
		a := mathrand.Float64() * 2 * math.Pi
		r := 120 + mathrand.Float64()*(wildNear-120)
		v := Vec{p.Pos.X + math.Cos(a)*r, p.Pos.Y + math.Sin(a)*r}
		if !habitat(m, v, water) {
			continue
		}
		pool := wildPool(area, m, v, water)
		if len(pool) == 0 {
			return nil
		}
		s := pool[mathrand.IntN(len(pool))]
		if _, ok := species[s]; !ok {
			continue
		}
		return &Wild{ID: uid(), Species: s, Level: 3 + mathrand.IntN(5), Pos: v, Water: water, Born: now}
	}
	return nil
}

// wander: passos curtos em direções aleatórias, sem sair do habitat.
func (wm *Wild) wander(m *AreaMap, dt, now float64) {
	if now > wm.Turn {
		wm.Turn = now + 1 + mathrand.Float64()*2.5
		if mathrand.IntN(3) == 0 {
			wm.Dir = Vec{}
		} else {
			a := mathrand.Float64() * 2 * math.Pi
			wm.Dir = Vec{math.Cos(a), math.Sin(a)}
		}
	}
	if wm.Dir.Len() == 0 {
		return
	}
	next := wm.Pos.Add(wm.Dir.Mul(dt * 34))
	if !habitat(m, next, wm.Water) {
		wm.Dir = wm.Dir.Mul(-1)
		return
	}
	wm.Pos = next
	wm.Facing = facingOf(wm.Dir)
}

// facingOf: 0 baixo, 1 esquerda, 2 direita, 3 cima (como as folhas de sprite).
func facingOf(d Vec) int {
	if math.Abs(d.X) > math.Abs(d.Y) {
		if d.X < 0 {
			return 1
		}
		return 2
	}
	if d.Y < 0 {
		return 3
	}
	return 0
}

// touchWild: o treinador encostou num selvagem; a batalha começa no mapa.
func (w *World) touchWild(p *Player, now float64) bool {
	if p.Battle != "" || len(p.Team) == 0 {
		return false
	}
	list := w.Wild[p.Area]
	for i, wm := range list {
		if wm.Water != (p.Transport == "surf") || distance(p.Pos, wm.Pos) > wildTouch || now-wm.Born < 1 {
			continue
		}
		w.Wild[p.Area] = append(list[:i:i], list[i+1:]...)
		if w.startBattle(p, "capture", wm.Species, nil, now) != nil {
			return false
		}
		b := w.Battles[p.Battle]
		b.Fighters[1].Mon.Level = wm.Level
		w.placeOnMap(b, p, wm.Pos)
		return true
	}
	return false
}

// placeOnMap leva a batalha para o mapa: a janela de 512x384 centrada no
// encontro vira o campo, e os Pokémon começam onde estavam.
func (w *World) placeOnMap(b *Battle, p *Player, foe Vec) {
	m := areaMaps[p.Area]
	if m == nil {
		return
	}
	mid := p.Pos.Add(foe).Mul(.5)
	size := Vec{float64(m.W) * m.Cell, float64(m.H) * m.Cell}
	origin := Vec{mid.X - 256, mid.Y - 222}
	origin.X = clamp(origin.X, 0, math.Max(0, size.X-512))
	origin.Y = clamp(origin.Y, -100, math.Max(-100, size.Y-344))
	b.Area, b.Origin = p.Area, origin
	b.Trainer = p.Pos.Add(origin.Mul(-1))
	b.Fighters[0].Pos = bounds(p.Pos.Add(origin.Mul(-1)).Add(Vec{0, -6}))
	b.Fighters[1].Pos = bounds(foe.Add(origin.Mul(-1)))
	b.Log = "Um " + monName(b.Fighters[1].Mon) + " selvagem! Lute ali mesmo."
}

// mapBlocked: no campo do mapa, paredes e árvores seguram os Pokémon (a água
// só segura quem não nada).
func (b *Battle) mapBlocked(f *Fighter, v Vec) bool {
	if b.Area == "" {
		return false
	}
	m := areaMaps[b.Area]
	if m == nil {
		return false
	}
	c := m.at(v.Add(b.Origin))
	if c == '~' {
		return species[f.Mon.Species].Ride != "Natação" && species[f.Mon.Species].Ride != "Voo"
	}
	return c == '#' && species[f.Mon.Species].Ride != "Voo"
}

func (w *World) wildNear(p *Player) []*Wild {
	out := []*Wild{}
	for _, wm := range w.Wild[p.Area] {
		if distance(wm.Pos, p.Pos) < wildFar {
			out = append(out, wm)
		}
	}
	return out
}

// step move o lutador respeitando a borda do campo e, no mapa, as paredes.
func (b *Battle) step(f *Fighter, v Vec) {
	v = b.bounds(v)
	if b.free(f, v) {
		f.Pos = v
		return
	}
	// Desliza junto à parede em vez de travar.
	if x := (Vec{v.X, f.Pos.Y}); b.free(f, x) {
		f.Pos = x
	} else if y := (Vec{f.Pos.X, v.Y}); b.free(f, y) {
		f.Pos = y
	}
}

func (b *Battle) free(f *Fighter, v Vec) bool {
	return !b.mapBlocked(f, v) && !b.solid(f, v)
}
