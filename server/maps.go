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
	X  int     `json:"x"`
	Y  int     `json:"y"`
	W  int     `json:"w"`
	H  int     `json:"h"`
	To string  `json:"to"`
	TX float64 `json:"tx"`
	TY float64 `json:"ty"`
}

// Connection liga a borda de um mapa a outro (como nas rotas do FireRed).
type Connection struct {
	Dir    string `json:"dir"`
	Offset int    `json:"offset"`
	To     string `json:"to"`
	W      int    `json:"w"`
	H      int    `json:"h"`
}
type AreaMap struct {
	W           int                   `json:"w"`
	H           int                   `json:"h"`
	Cell        float64               `json:"cell"`
	Cells       string                `json:"cells"`
	Warps       []Warp                `json:"warps"`
	Spawns      map[string][2]float64 `json:"spawns"`
	Points      map[string][2]float64 `json:"points"`
	Default     [2]float64            `json:"default"`
	Connections []Connection          `json:"connections"`
	Encounters  []int                 `json:"encounters"`
	Cave        bool                  `json:"cave"`
	Name        string                `json:"name"`
}

// Regiões: Aurora (mapas originais) e Kanto (mapas do FireRed).
const kantoStart = "kt_pallet_town"

func isKanto(area string) bool { return strings.HasPrefix(area, "kt_") }

func regionOf(area string) string {
	if isKanto(area) {
		return "kanto"
	}
	return "aurora"
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
	case '^':
		return dir.Y >= 0
	case '>':
		return dir.X <= 0
	case '<':
		return dir.X >= 0
	}
	return false
}

func (m *AreaMap) warpAt(v Vec) *Warp {
	x, y := int(math.Floor(v.X/m.Cell)), int(math.Floor(v.Y/m.Cell))
	for i, w := range m.Warps {
		if x >= w.X && x < w.X+w.W && y >= w.Y && y < w.Y+w.H {
			return &m.Warps[i]
		}
	}
	return nil
}

// edge: se o jogador sai pela borda e há um mapa conectado ali, devolve a
// área e a posição correspondente no outro mapa.
func (m *AreaMap) edge(v Vec) (string, Vec, bool) {
	size := Vec{float64(m.W) * m.Cell, float64(m.H) * m.Cell}
	for _, c := range m.Connections {
		off := float64(c.Offset) * m.Cell
		var pos Vec
		switch {
		case c.Dir == "up" && v.Y < 4:
			pos = Vec{v.X - off, float64(c.H)*m.Cell - 10}
		case c.Dir == "down" && v.Y > size.Y-1:
			pos = Vec{v.X - off, 12}
		case c.Dir == "left" && v.X < 4:
			pos = Vec{float64(c.W)*m.Cell - 10, v.Y - off}
		case c.Dir == "right" && v.X > size.X-4:
			pos = Vec{10, v.Y - off}
		default:
			continue
		}
		if pos.X > 0 && pos.Y > 0 && pos.X < float64(c.W)*m.Cell && pos.Y < float64(c.H)*m.Cell {
			return c.To, pos, true
		}
	}
	return "", Vec{}, false
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

func canEnter(p *Player, area string) bool {
	if isKanto(area) {
		return areaMaps[area] != nil
	}
	need, ok := areaNeed[area]
	return ok && p.Quest >= need
}

func (w *World) enter(p *Player, area string, now float64) bool {
	if !canEnter(p, area) {
		p.Notice = "Continue a história para liberar essa área."
		return false
	}
	from := p.Area
	p.Area = area
	p.Visits[area] = true
	p.Pos = arrival(area, from)
	p.Safari = nil
	p.Fishing = 0
	p.WarpAt = now
	return true
}

func (w *World) enterAt(p *Player, area string, pos Vec, now float64) {
	p.Area = area
	p.Visits[area] = true
	p.Pos = pos
	p.Safari = nil
	p.Fishing = 0
	p.WarpAt = now
}

func (w *World) walkMap(p *Player, dt, now float64) {
	m := areaMaps[p.Area]
	speed := 80.0
	if p.Running {
		speed = 112 // correr com Shift em qualquer mapa (ideia do Emerald Legacy)
	}
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
	if now-p.WarpAt > .5 && p.Input.Len() > 0 {
		raw := start.Add(p.Input.Mul(speed * dt))
		if to, pos, ok := m.edge(raw); ok {
			w.enterAt(p, to, pos, now)
			return
		}
	}
	if warp := m.warpAt(p.Pos); warp != nil && now-p.WarpAt > .6 {
		back := m.bounds(start.Add(p.Input.Mul(-8)))
		switch {
		case warp.To == "@voltar" && p.ReturnArea != "":
			w.enterAt(p, p.ReturnArea, p.ReturnPos, now)
		case warp.TX > 0 && areaMaps[warp.To] != nil:
			p.ReturnArea, p.ReturnPos = p.Area, back
			w.enterAt(p, warp.To, Vec{warp.TX, warp.TY}, now)
		case warp.To != "@voltar":
			if !w.enter(p, warp.To, now) {
				p.Pos = back
			}
		default:
			p.Pos = back
		}
		return
	}
	// Grama alta: encontros aleatórios enquanto o jogador anda nela.
	if moved > 0 && (m.at(p.Pos) == '"' || m.Cave) && p.Battle == "" && len(p.Team) > 0 && p.Area != "safari" {
		pool := routePool[p.Area]
		if len(m.Encounters) > 0 {
			pool = m.Encounters
		}
		if len(pool) > 0 && mathrand.Float64() < moved/32*.09 {
			_ = w.startBattle(p, "capture", pool[mathrand.IntN(len(pool))], nil, now)
		}
	}
}
