package main

import (
	"embed"
	"encoding/json"
	"math"
	mathrand "math/rand/v2"
	"strings"
)

// Mapas externos gerados por ferramentas/mapas/build.py a partir dos
// tilesets do FireRed. Áreas sem mapa (casa, mina, ginásio) seguem com a
// tela fixa de 512×384.

//go:embed maps/*.json
var mapFiles embed.FS

type Warp struct {
	X  int    `json:"x"`
	Y  int    `json:"y"`
	W  int    `json:"w"`
	H  int    `json:"h"`
	To string `json:"to"`
}
type AreaMap struct {
	W       int                   `json:"w"`
	H       int                   `json:"h"`
	Cell    float64               `json:"cell"`
	Cells   string                `json:"cells"`
	Warps   []Warp                `json:"warps"`
	Spawns  map[string][2]float64 `json:"spawns"`
	Points  map[string][2]float64 `json:"points"`
	Default [2]float64            `json:"default"`
}

var areaMaps = map[string]*AreaMap{}

func init() {
	entries, _ := mapFiles.ReadDir("maps")
	for _, e := range entries {
		raw, err := mapFiles.ReadFile("maps/" + e.Name())
		if err != nil {
			panic(err)
		}
		m := &AreaMap{}
		if err := json.Unmarshal(raw, m); err != nil {
			panic(err)
		}
		areaMaps[strings.TrimSuffix(e.Name(), ".json")] = m
	}
}

func (m *AreaMap) at(v Vec) byte {
	x, y := int(math.Floor(v.X/m.Cell)), int(math.Floor(v.Y/m.Cell))
	if x < 0 || y < 0 || x >= m.W || y >= m.H {
		return '#'
	}
	return m.Cells[y*m.W+x]
}

func (m *AreaMap) bounds(v Vec) Vec {
	return Vec{clamp(v.X, 6, float64(m.W)*m.Cell-6), clamp(v.Y, 6, float64(m.H)*m.Cell-2)}
}

// solid: paredes e água; ressaltos só deixam passar descendo.
func (m *AreaMap) solid(v Vec, dir Vec) bool {
	switch m.at(v) {
	case '#', '~':
		return true
	case 'v':
		return dir.Y <= 0
	}
	return false
}

func (m *AreaMap) warpAt(v Vec) string {
	x, y := int(math.Floor(v.X/m.Cell)), int(math.Floor(v.Y/m.Cell))
	for _, w := range m.Warps {
		if x >= w.X && x < w.X+w.W && y >= w.Y && y < w.Y+w.H {
			return w.To
		}
	}
	return ""
}

// arrival: onde o jogador aparece ao entrar na área vindo de outra.
func arrival(area, from string) Vec {
	m := areaMaps[area]
	if m == nil {
		return Vec{256, 290}
	}
	if s, ok := m.Spawns[from]; ok {
		return Vec{s[0], s[1]}
	}
	if s, ok := m.Points["porta_"+from]; ok {
		return Vec{s[0], s[1]}
	}
	return Vec{m.Default[0], m.Default[1]}
}

func (w *World) enter(p *Player, area string, now float64) bool {
	need, ok := areaNeed[area]
	if !ok || p.Quest < need {
		p.Notice = "Continue a história para liberar essa área."
		return false
	}
	from := p.Area
	p.Area = area
	p.Visits[area] = true
	p.Pos = arrival(area, from)
	p.Safari = nil
	p.WarpAt = now
	return true
}

func (w *World) walkMap(p *Player, dt, now float64) {
	m := areaMaps[p.Area]
	speed := 80.0
	if p.Transport == "bike" {
		speed = 120
	}
	start := p.Pos
	desired := m.bounds(p.Pos.Add(p.Input.Mul(speed * dt)))
	if x := (Vec{desired.X, p.Pos.Y}); !m.solid(x, p.Input) {
		p.Pos = x
	}
	if y := (Vec{p.Pos.X, desired.Y}); !m.solid(y, p.Input) {
		p.Pos = y
	}
	moved := distance(start, p.Pos)
	if to := m.warpAt(p.Pos); to != "" && now-p.WarpAt > .6 {
		if !w.enter(p, to, now) {
			p.Pos = start.Add(p.Input.Mul(-6))
			p.Pos = m.bounds(p.Pos)
		}
		return
	}
	// Grama alta: encontros aleatórios enquanto o jogador anda nela.
	if moved > 0 && m.at(p.Pos) == '"' && p.Battle == "" && len(p.Team) > 0 && p.Area != "safari" {
		pool := routePool[p.Area]
		if len(pool) > 0 && mathrand.Float64() < moved/32*.09 {
			_ = w.startBattle(p, "capture", pool[mathrand.IntN(len(pool))], nil, now)
		}
	}
}
