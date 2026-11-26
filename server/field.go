package main

import (
	"embed"
	"encoding/json"
	"math"
	"strings"
)

// Field é a arena oficial de um ginásio: uma grade de terreno maior que a
// tela (a câmera do cliente acompanha a luta e permite afastar o zoom). As
// letras seguem server/terrain.go; ferramentas/arenas/build.py desenha as
// arenas de cada ginásio.
type Field struct {
	ID     string       `json:"id"`
	Theme  string       `json:"theme"`
	Title  string       `json:"title"`
	Cols   int          `json:"cols"`
	Rows   int          `json:"rows"`
	X      float64      `json:"x"`
	Y      float64      `json:"y"`
	Cell   float64      `json:"cell"`
	Cells  string       `json:"cells"`
	Events []FieldEvent `json:"events"`
	Spawn  [2]Vec       `json:"spawn"`

	Timers  []FieldTimer    `json:"-"`
	HP      map[int]float64 `json:"-"`
	Next    map[int]float64 `json:"-"` // próximo gêiser / afundamento
	Started float64         `json:"-"`
}

// FieldEvent é algo que acontece numa área do campo: aviso no chão antes
// (Start..At) e efeito depois (At..Until). O cliente desenha o aviso só
// enquanto ele importa.
type FieldEvent struct {
	Kind   string  `json:"kind"`
	Pos    Vec     `json:"pos"`
	Radius float64 `json:"radius"`
	Start  float64 `json:"start"`
	At     float64 `json:"at"`
	Until  float64 `json:"until"`
	Done   bool    `json:"-"`
}

type FieldTimer struct {
	Cell int
	To   byte
	At   float64
}

const fieldCell = 32.0

// Tema de cada ginásio, pelo tipo do líder.
var gymTheme = map[string]string{
	"aurora_1": "planta",
	"kanto_1":  "rocha", "kanto_2": "agua", "kanto_3": "eletrico", "kanto_4": "planta",
	"kanto_5": "veneno", "kanto_6": "psiquico", "kanto_7": "fogo", "kanto_8": "terra",
	"hoenn_1": "rocha", "hoenn_2": "lutador", "hoenn_3": "eletrico", "hoenn_4": "fogo",
	"hoenn_5": "normal", "hoenn_6": "voador", "hoenn_7": "psiquico", "hoenn_8": "agua",
	"johto_1": "voador", "johto_2": "inseto", "johto_3": "normal", "johto_4": "fantasma",
	"johto_5": "lutador", "johto_6": "aco", "johto_7": "gelo", "johto_8": "dragao",
	"sinnoh_1": "rocha", "sinnoh_2": "planta", "sinnoh_3": "fantasma", "sinnoh_4": "lutador",
	"sinnoh_5": "agua", "sinnoh_6": "aco", "sinnoh_7": "gelo", "sinnoh_8": "eletrico",
}

//go:embed arenas/*.json
var arenaFiles embed.FS

type arenaFile struct {
	ID    string    `json:"id"`
	Theme string    `json:"theme"`
	Title string    `json:"title"`
	W     int       `json:"w"`
	H     int       `json:"h"`
	Cells string    `json:"cells"`
	Spawn [2][2]int `json:"spawn"`
}

var arenas = map[string]arenaFile{}

func init() {
	entries, _ := arenaFiles.ReadDir("arenas")
	for _, e := range entries {
		raw, err := arenaFiles.ReadFile("arenas/" + e.Name())
		if err != nil {
			panic(err)
		}
		var a arenaFile
		if err := json.Unmarshal(raw, &a); err != nil {
			panic(err)
		}
		arenas[strings.TrimSuffix(e.Name(), ".json")] = a
	}
}

// plainArena é a arena simples para quando um ginásio ainda não tem projeto.
func plainArena(id string) arenaFile {
	w, h := 32, 24
	var sb strings.Builder
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			switch {
			case y < 2 || y >= h-2:
				sb.WriteByte('A')
			case y == 2 || y == h-3 || x == 0 || x == w-1:
				sb.WriteByte('R')
			default:
				sb.WriteByte('.')
			}
		}
	}
	return arenaFile{ID: id, Theme: "normal", W: w, H: h, Cells: sb.String(), Spawn: [2][2]int{{w/2 - 6, h - 6}, {w/2 + 5, 5}}}
}

func newField(id string, now float64) *Field {
	a, ok := arenas[id]
	if !ok {
		a = plainArena(id)
	}
	fl := &Field{ID: id, Theme: a.Theme, Title: a.Title, Cols: a.W, Rows: a.H, Cell: fieldCell, Cells: a.Cells,
		Events: []FieldEvent{}, HP: map[int]float64{}, Next: map[int]float64{}, Started: now}
	for k, s := range a.Spawn {
		fl.Spawn[k] = fl.center(s[1]*a.W + s[0])
	}
	for i := 0; i < len(fl.Cells); i++ {
		c := fl.Cells[i]
		if t := terrainOf(c); t.HP > 0 {
			fl.HP[i] = t.HP
		}
		if c == 'V' || c == 'k' {
			// Cada gêiser e plataforma tem seu ritmo: os primeiros só depois
			// de alguns segundos, para o jogador entender a arena.
			fl.Next[i] = now + 5 + math.Mod(float64(i)*1.37, 6)
		}
	}
	return fl
}

func (fl *Field) index(v Vec) int {
	c := int(math.Floor((v.X - fl.X) / fl.Cell))
	r := int(math.Floor((v.Y - fl.Y) / fl.Cell))
	if c < 0 || r < 0 || c >= fl.Cols || r >= fl.Rows {
		return -1
	}
	return r*fl.Cols + c
}

func (fl *Field) at(v Vec) byte {
	i := fl.index(v)
	if i < 0 {
		return 'R'
	}
	return fl.Cells[i]
}

func (fl *Field) center(i int) Vec {
	return Vec{fl.X + (float64(i%fl.Cols)+.5)*fl.Cell, fl.Y + (float64(i/fl.Cols)+.5)*fl.Cell}
}

func (fl *Field) size() Vec { return Vec{float64(fl.Cols) * fl.Cell, float64(fl.Rows) * fl.Cell} }

// set troca a casa; com revertAfter > 0 ela volta ao que era depois.
func (fl *Field) set(i int, c byte, revertAfter, now float64) {
	if i < 0 || i >= len(fl.Cells) || fl.Cells[i] == c {
		return
	}
	b := []byte(fl.Cells)
	old := b[i]
	b[i] = c
	fl.Cells = string(b)
	timers := fl.Timers[:0]
	for _, t := range fl.Timers {
		if t.Cell != i {
			timers = append(timers, t)
		} else {
			old = t.To // uma mudança nova mantém o terreno original
		}
	}
	fl.Timers = timers
	if revertAfter > 0 {
		fl.Timers = append(fl.Timers, FieldTimer{Cell: i, To: old, At: now + revertAfter})
	}
	if t := terrainOf(c); t.HP > 0 {
		if _, ok := fl.HP[i]; !ok || old != c {
			fl.HP[i] = t.HP
		}
	} else {
		delete(fl.HP, i)
	}
}

func (fl *Field) event(kind string, pos Vec, radius, warn, last, now float64) {
	fl.Events = append(fl.Events, FieldEvent{Kind: kind, Pos: pos, Radius: radius, Start: now, At: now + warn, Until: now + warn + last})
}

func flies(f *Fighter) bool {
	s := species[f.Mon.Species]
	return s.Ride == "Voo" || s.Type == "Voador"
}

func swims(f *Fighter) bool {
	s := species[f.Mon.Species]
	return s.Ride == "Natação" || s.Type == "Água"
}

// bodyRadius: o tamanho do Pokémon vale para a colisão com o cenário.
func bodyRadius(f *Fighter) float64 {
	return math.Max(8, 13*f.Physique.Scale*f.Physique.Scale)
}

// bounds limita a posição à arena (ou ao campo antigo, fora dos ginásios).
func (b *Battle) bounds(v Vec) Vec {
	if b.Field == nil {
		return bounds(v)
	}
	s := b.Field.size()
	return Vec{clamp(v.X, b.Field.X+fieldCell, b.Field.X+s.X-fieldCell), clamp(v.Y, b.Field.Y+fieldCell, b.Field.Y+s.Y-fieldCell)}
}

func (b *Battle) inside(v Vec) bool {
	if b.Field == nil {
		return v.X > 0 && v.X < 512 && v.Y > 80 && v.Y < 364
	}
	s := b.Field.size()
	return v.X > b.Field.X && v.Y > b.Field.Y && v.X < b.Field.X+s.X && v.Y < b.Field.Y+s.Y
}

// blockedCell diz se uma casa segura o lutador.
func blockedCell(f *Fighter, c byte) bool {
	t := terrainOf(c)
	if flies(f) {
		return t.Solid && !t.Low
	}
	return t.Solid || t.Void
}

// solid confere o corpo inteiro: o centro e quatro pontos na borda.
func (b *Battle) solid(f *Fighter, v Vec) bool {
	if b.Field == nil {
		return false
	}
	r := bodyRadius(f) * .7
	for _, d := range []Vec{{0, 0}, {r, 0}, {-r, 0}, {0, r * .6}, {0, -r * .6}} {
		if blockedCell(f, b.Field.at(v.Add(d))) {
			return true
		}
	}
	return false
}

// shotBlocked: obstáculos sólidos (inclusive rochas baixas) seguram disparos.
func (b *Battle) shotBlocked(v Vec) (int, bool) {
	if b.Field == nil {
		return -1, false
	}
	i := b.Field.index(v)
	if i < 0 {
		return -1, true
	}
	return i, terrainOf(b.Field.Cells[i]).Solid
}

// ray devolve o ponto onde um raio bate no primeiro obstáculo.
func (b *Battle) ray(from, to Vec) (Vec, int) {
	if b.Field == nil {
		return to, -1
	}
	d := to.Add(from.Mul(-1))
	n := int(d.Len()/8) + 1
	for k := 1; k <= n; k++ {
		p := from.Add(d.Mul(float64(k) / float64(n)))
		if i, hit := b.shotBlocked(p); hit {
			return p, i
		}
	}
	return to, -1
}

func (b *Battle) terrainAt(f *Fighter) Terrain {
	if b.Field == nil {
		return terrains['.']
	}
	return terrainOf(b.Field.at(f.Pos))
}

// terrainSpeed: multiplicador de velocidade pelo chão, tipo e porte.
func (b *Battle) terrainSpeed(f *Fighter) float64 {
	if b.Field == nil || flies(f) {
		return 1
	}
	t := b.terrainAt(f)
	kind := species[f.Mon.Species].Type
	if t.friend(kind) {
		return t.Bonus
	}
	if (t.Wet || t.Swim) && swims(f) {
		return 1.25
	}
	speed := t.Speed
	big := f.Physique.Scale > 1.25
	if big && t.Wet && !t.Swim {
		speed = math.Max(speed, .9) // um Onix não se importa com água rasa
	}
	if big && t.Name == "neve" {
		speed *= .9 // e afunda na neve
	}
	return speed
}

// grip: quanto o lutador consegue mudar de direção (gelo = derrapa; os
// pesados derrapam mais).
func (b *Battle) grip(f *Fighter) float64 {
	if b.Field == nil || flies(f) {
		return 1
	}
	t := b.terrainAt(f)
	if t.Slippery && !t.friend(species[f.Mon.Species].Type) {
		return .25 / math.Sqrt(1+f.Physique.Mass/60)
	}
	return 1
}

func (b *Battle) slippery(f *Fighter) bool { return b.grip(f) < 1 }

// terrainPower: dentro da água funda quem não nada perde força.
func (b *Battle) terrainPower(f *Fighter) float64 {
	if b.Field == nil || flies(f) {
		return 1
	}
	t := b.terrainAt(f)
	kind := species[f.Mon.Species].Type
	switch {
	case t.Swim && !swims(f):
		return .8
	case t.friend(kind) && t.Name != "areia":
		return 1.1
	}
	return 1
}

// tickTerrain: efeitos do chão, eventos do campo e o próprio campo mudando.
func (b *Battle) tickTerrain(dt, now float64) {
	fl := b.Field
	if fl == nil {
		return
	}
	// Casas que voltam ao normal (gelo derrete, poça seca, pedra erguida cai).
	if len(fl.Timers) > 0 {
		cells := []byte(fl.Cells)
		timers := fl.Timers[:0]
		for _, t := range fl.Timers {
			if now >= t.At && !b.occupiedBy(fl.center(t.Cell), t.To) {
				cells[t.Cell] = t.To
				if tt := terrainOf(t.To); tt.HP > 0 {
					fl.HP[t.Cell] = tt.HP
				}
			} else {
				timers = append(timers, t)
			}
		}
		fl.Cells = string(cells)
		fl.Timers = timers
	}
	b.tickMachines(now)
	b.tickEvents(dt, now)
	for _, f := range b.Fighters {
		b.tickFighterTerrain(f, dt, now)
	}
}

// occupiedBy: não erguer pedra ou parede em cima de alguém.
func (b *Battle) occupiedBy(c Vec, to byte) bool {
	if !terrainOf(to).Solid {
		return false
	}
	return b.occupied(c)
}

func (b *Battle) occupied(c Vec) bool {
	for _, f := range b.Fighters {
		if distance(f.Pos, c) < fieldCell*.5+bodyRadius(f) {
			return true
		}
	}
	return false
}

// tickMachines: gêiseres e plataformas que afundam, com aviso antes.
func (b *Battle) tickMachines(now float64) {
	fl := b.Field
	for i, next := range fl.Next {
		c := fl.Cells[i]
		pos := fl.center(i)
		switch c {
		case 'V':
			if now >= next-1 {
				kind := "steam"
				if fl.Theme == "fogo" {
					kind = "geyser"
				}
				fl.event(kind, pos, 46, 1, .6, now)
				fl.Next[i] = next + 6.5 + math.Mod(float64(i)*.73, 2.5)
			}
		case 'k':
			if now >= next-.9 {
				fl.event("sink", pos, 26, .9, 2.6, now)
				fl.Next[i] = next + 9
			}
		}
	}
}

func (b *Battle) tickEvents(dt, now float64) {
	fl := b.Field
	events := fl.Events[:0]
	for _, e := range fl.Events {
		if now >= e.At && !e.Done {
			e.Done = true
			switch e.Kind {
			case "geyser":
				for i, f := range b.Fighters {
					if distance(f.Pos, e.Pos) < e.Radius+bodyRadius(f) && species[f.Mon.Species].Type != "Fogo" {
						b.hit(1-i, f, f.MaxHP*.09, 30, f.Pos.Add(e.Pos.Mul(-1)), "Fogo", now)
					}
				}
				fl.event("steam", e.Pos, 70, 0, 2.5, now)
			case "sink":
				fl.set(fl.index(e.Pos), '_', e.Until-e.At, now)
			case "tremor":
				for i, f := range b.Fighters {
					if !flies(f) && distance(f.Pos, e.Pos) < e.Radius {
						f.StunUntil = math.Max(f.StunUntil, now+.3)
						_ = i
					}
				}
			}
		}
		if e.Kind == "shock" && now >= e.At && now < e.Until {
			for _, f := range b.Fighters {
				t := b.terrainAt(f)
				if (t.Wet || t.Conductive) && !flies(f) && species[f.Mon.Species].Type != "Elétrico" && distance(f.Pos, e.Pos) < e.Radius {
					f.HP = math.Max(1, f.HP-dt*f.MaxHP*.07)
					f.SlowUntil = math.Max(f.SlowUntil, now+.8)
				}
			}
		}
		if e.Kind == "pollen" && now >= e.At && now < e.Until {
			for _, f := range b.Fighters {
				if species[f.Mon.Species].Type != "Planta" && distance(f.Pos, e.Pos) < e.Radius {
					f.SlowUntil = math.Max(f.SlowUntil, now+1)
				}
			}
		}
		if now < e.Until {
			events = append(events, e)
		}
	}
	fl.Events = events
}

func (b *Battle) tickFighterTerrain(f *Fighter, dt, now float64) {
	fl := b.Field
	c := fl.at(f.Pos)
	t := terrainOf(c)
	kind := species[f.Mon.Species].Type
	f.Terrain = string(c)
	f.Hidden = false
	if flies(f) {
		f.Terrain = "voo"
		if t.Wind {
			b.step(f, f.Pos.Add(t.Push.Mul(dt*1.4/math.Sqrt(1+f.Physique.Mass/40))))
		}
		return
	}
	friend := t.friend(kind)
	if t.Damage > 0 && !friend {
		f.HP = math.Max(1, f.HP-dt*f.MaxHP*t.Damage)
	}
	if friend && (c == 'g' || c == 'u') {
		f.HP = math.Min(f.MaxHP, f.HP+dt*f.MaxHP*.01)
	}
	if c == 'e' && friend {
		f.Energy = math.Min(100, f.Energy+dt*6)
	}
	if t.Swim && !swims(f) {
		f.SlowUntil = math.Max(f.SlowUntil, now+1.2) // molhado
	}
	if t.Hide && f.Physique.Scale <= 1.1 {
		f.Hidden = true
	}
	if t.Push.Len() > 0 {
		push := t.Push.Mul(dt / math.Sqrt(1+f.Physique.Mass/40))
		if swims(f) {
			push = push.Mul(.5)
		}
		b.step(f, f.Pos.Add(push))
	}
	// Gelo cede sob os pesados.
	i := fl.index(f.Pos)
	if c == 'i' && f.Physique.Mass > 120 && math.Mod(now*7+float64(i), 3) < dt*7 {
		fl.set(i, 'j', 0, now)
	} else if c == 'j' && f.Physique.Mass > 60 && math.Mod(now*5+float64(i), 4) < dt*5 {
		b.breakIce(i, now)
	}
	if c == 'Y' && now > f.WarpAt {
		b.teleport(f, i, now)
	}
}

func (b *Battle) breakIce(i int, now float64) {
	fl := b.Field
	fl.set(i, 'W', 14, now)
	if len(fl.Timers) > 0 {
		fl.Timers[len(fl.Timers)-1].To = 'i' // recongela inteiro
	}
	fl.event("crack", fl.center(i), 24, 0, .6, now)
}

func (b *Battle) teleport(f *Fighter, from int, now float64) {
	fl := b.Field
	n := len(fl.Cells)
	for k := 1; k < n; k++ {
		j := (from + k*7919) % n
		if fl.Cells[j] == 'Y' && j != from {
			fl.event("teleport", f.Pos, 22, 0, .5, now)
			f.Pos = fl.center(j)
			f.WarpAt = now + 2.5
			fl.event("teleport", f.Pos, 22, 0, .5, now)
			return
		}
	}
}

// cellCost diz o quanto uma casa é ruim para o lutador; a IA desvia das
// casas caras, procura o lugar certo para ficar e usa a grama para emboscar.
func (b *Battle) cellCost(f *Fighter, v Vec) float64 {
	if b.Field == nil {
		return 0
	}
	c := b.Field.at(v)
	if blockedCell(f, c) {
		return 99
	}
	if flies(f) {
		return 0
	}
	t := terrainOf(c)
	kind := species[f.Mon.Species].Type
	switch {
	case t.friend(kind):
		return -1
	case t.Damage > 0:
		return 6
	case t.Swim && !swims(f):
		return 3
	case (t.Wet || t.Swim) && swims(f):
		return -1
	case t.Hide && f.Physique.Scale <= 1.1:
		return -.5
	case t.Slippery || t.Speed < .8:
		return 1
	}
	if c == 'k' || c == 'V' {
		return 1.5
	}
	return 0
}

// autoStep move a IA na direção desejada, desviando de obstáculos e de
// casas ruins para o tipo dela.
func (b *Battle) autoStep(f *Fighter, dir Vec, dist float64) {
	if b.Field == nil || dir.Len() == 0 {
		b.step(f, f.Pos.Add(dir.Unit().Mul(dist)))
		return
	}
	base := math.Atan2(dir.Y, dir.X)
	best, bestCost := Vec{}, math.Inf(1)
	here := b.cellCost(f, f.Pos)
	for k, turn := range []float64{0, .5, -.5, 1, -1, 1.6, -1.6, 2.3, -2.3} {
		d := Vec{math.Cos(base + turn), math.Sin(base + turn)}
		probe := b.bounds(f.Pos.Add(d.Mul(fieldCell*.6 + bodyRadius(f))))
		if b.solid(f, probe) {
			continue
		}
		cost := b.cellCost(f, probe) + float64(k)*.15
		if cost < bestCost {
			best, bestCost = d, cost
		}
	}
	if bestCost == math.Inf(1) || (bestCost > here+.5 && here < 3) {
		return
	}
	b.step(f, f.Pos.Add(best.Mul(dist)))
}

// safeCell acha a casa boa mais perto para a IA sair de um lugar ruim.
func (b *Battle) safeCell(f *Fighter) (Vec, bool) {
	best, bestD := Vec{}, math.Inf(1)
	for i := range b.Field.Cells {
		c := b.Field.center(i)
		if b.cellCost(f, c) > 0 {
			continue
		}
		if d := distance(c, f.Pos); d < bestD {
			best, bestD = c, d
		}
	}
	return best, bestD < math.Inf(1)
}

// aimAt: na grama alta ou no vapor o alvo some e a IA erra a mira.
func (b *Battle) aimAt(target *Fighter, now float64) Vec {
	if !target.Hidden && !b.inCloud(target.Pos, now) {
		return target.Pos
	}
	a := now*2.3 + target.Pos.X
	return target.Pos.Add(Vec{math.Cos(a), math.Sin(a)}.Mul(55))
}

func (b *Battle) inCloud(v Vec, now float64) bool {
	if b.Field == nil {
		return false
	}
	for _, e := range b.Field.Events {
		if (e.Kind == "steam" || e.Kind == "pollen") && now >= e.At && now < e.Until && distance(v, e.Pos) < e.Radius {
			return true
		}
	}
	return false
}

// damageObstacle tira integridade de rochas, cercas e pilares de gelo.
func (b *Battle) damageObstacle(i int, kind string, dmg, now float64) {
	fl := b.Field
	if fl == nil || i < 0 || i >= len(fl.Cells) {
		return
	}
	c := fl.Cells[i]
	t := terrainOf(c)
	if t.HP <= 0 {
		return
	}
	hp, ok := fl.HP[i]
	if !ok {
		hp = t.HP
	}
	hp -= obstacleDamage(c, kind, dmg)
	fl.HP[i] = hp
	pos := fl.center(i)
	switch {
	case hp <= 0:
		to := t.Broken
		if c == 'h' && kind == "Fogo" {
			to = 'f'
		}
		delete(fl.HP, i)
		fl.set(i, to, 0, now)
		if to == 'f' {
			fl.Timers = append(fl.Timers, FieldTimer{Cell: i, To: '.', At: now + 4})
		}
		fl.event("dust", pos, 30, 0, .7, now)
	case t.Cracked != 0 && hp <= t.HP/2:
		fl.set(i, t.Cracked, 0, now)
		fl.HP[i] = hp
		fl.event("dust", pos, 18, 0, .4, now)
	default:
		fl.event("chip", pos, 12, 0, .3, now)
	}
}

// ram: investida contra um obstáculo (o Onix abre caminho na pedreira).
func (b *Battle) ram(f *Fighter, dir Vec, power, now float64) {
	if b.Field == nil {
		return
	}
	ahead := f.Pos.Add(dir.Unit().Mul(bodyRadius(f) + 10))
	i := b.Field.index(ahead)
	if i < 0 {
		return
	}
	mass := math.Sqrt(1 + f.Physique.Mass/30)
	b.damageObstacle(i, species[f.Mon.Species].Type, power*.6*mass, now)
}

// shapeField: o golpe que cai num ponto muda o campo em volta.
func (b *Battle) shapeField(pos Vec, radius float64, kind string, power, now float64) {
	fl := b.Field
	if fl == nil {
		return
	}
	radius = math.Max(radius, 14)
	big := radius >= 40
	hit := map[string]bool{}
	for i := 0; i < len(fl.Cells); i++ {
		c := fl.center(i)
		d := distance(c, pos)
		if d > radius+fl.Cell*.5 {
			continue
		}
		cell := fl.Cells[i]
		t := terrainOf(cell)
		if t.HP > 0 && power > 0 {
			b.damageObstacle(i, kind, power*.5, now)
			continue
		}
		switch kind {
		case "Gelo":
			switch {
			case t.Wet || t.Swim:
				fl.set(i, 'i', 14, now) // a água congela e vira chão
			case cell == 'l':
				fl.set(i, 's', 12, now)
			case cell == 'f':
				fl.set(i, '.', 0, now)
			case big && (cell == '.' || cell == ',' || cell == 'M'):
				fl.set(i, 'i', 8, now)
			}
		case "Fogo":
			switch {
			case cell == 'i' || cell == 'j':
				fl.set(i, 'w', 15, now) // gelo derrete
			case cell == 'n':
				fl.set(i, 'w', 12, now) // neve derrete
			case t.Flammable:
				fl.set(i, 'f', 0, now) // queima e depois vira chão
				fl.Timers = append(fl.Timers, FieldTimer{Cell: i, To: '.', At: now + 4})
			case (cell == 'w' || cell == 'u') && !hit["steam"]:
				hit["steam"] = true
				fl.event("steam", pos, math.Max(50, radius), 0, 2.5, now) // evapora
			}
		case "Água":
			switch cell {
			case 'l':
				fl.set(i, 's', 25, now) // lava apagada
			case 'f':
				fl.set(i, '.', 0, now)
			case 's':
				if big {
					fl.set(i, 'm', 10, now) // areia vira lama
				}
			case '.', ',', 'M':
				if big {
					fl.set(i, 'w', 6, now) // golpes grandes alagam o chão
				}
			}
		case "Elétrico":
			if (t.Wet || t.Conductive) && !hit["shock"] {
				hit["shock"] = true
				fl.event("shock", pos, math.Max(70, radius+30), .5, 2.2, now)
			}
		case "Pedra", "Terra":
			if big && d < fl.Cell && (cell == '.' || cell == 's' || cell == ',' || cell == 'g' || cell == 'n') && !b.occupied(c) {
				fl.set(i, 'r', 12, now) // ergue uma pedra no meio do golpe
			}
			if big && !hit["tremor"] {
				hit["tremor"] = true
				fl.event("tremor", pos, radius*1.5, 0, .8, now)
				for j := range fl.HP {
					if distance(fl.center(j), pos) < radius*1.6 {
						b.damageObstacle(j, kind, 15, now)
					}
				}
			}
		case "Planta":
			if cell == '.' || cell == ',' || cell == 's' || cell == 'm' {
				fl.set(i, 'g', 0, now) // a grama cresce
			}
			if big && d < fl.Cell && cell == '.' && !b.occupied(c) {
				fl.set(i, 'h', 10, now) // barreira de vinhas
			}
		case "Veneno":
			if cell == '.' || cell == ',' || cell == 's' || cell == 'g' {
				fl.set(i, 'x', 8, now)
			}
		}
	}
	if kind == "Voador" {
		// Rajadas dispersam vapor, fumaça e pólen.
		events := fl.Events[:0]
		for _, e := range fl.Events {
			if (e.Kind == "steam" || e.Kind == "pollen") && distance(e.Pos, pos) < e.Radius+radius+40 {
				continue
			}
			events = append(events, e)
		}
		fl.Events = events
	}
	if kind == "Planta" && big {
		for i := 0; i < len(fl.Cells); i++ {
			if fl.Cells[i] == 'o' && distance(fl.center(i), pos) < radius+60 {
				fl.event("pollen", fl.center(i), 60, .3, 3, now) // flores soltam pólen
				break
			}
		}
	}
}

// shapeBeam aplica o efeito do raio ao longo de todo o caminho.
func (b *Battle) shapeBeam(from, to Vec, kind string, power, now float64) {
	if b.Field == nil {
		return
	}
	d := to.Add(from.Mul(-1))
	steps := int(d.Len()/(fieldCell*.75)) + 1
	for k := 0; k <= steps; k++ {
		b.shapeField(from.Add(d.Mul(float64(k)/float64(steps))), 12, kind, 0, now)
	}
	if _, i := b.ray(from, to.Add(d.Unit().Mul(10))); i >= 0 {
		b.damageObstacle(i, kind, power, now)
	}
}
