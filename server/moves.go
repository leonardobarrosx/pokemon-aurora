package main

import (
	"fmt"
	"math"
	mathrand "math/rand/v2"
)

// Golpes em tempo real. Cada Pokémon tem 4 golpes (teclas 1 a 4). O formato
// define como o golpe aparece na arena:
//
//	shot   projétil único          spread  leque de projéteis
//	stream jato contínuo curto     beam    raio com carga
//	blast  área no ponto mirado    wave    onda ao redor do usuário
//	dash   investida corpo a corpo none    não faz nada (Splash)
//
// O Sp. Atk e o nível aumentam o tamanho dos golpes especiais; o Ataque e o
// peso aumentam o empurrão das investidas. Peso e porte do alvo reduzem o
// empurrão que ele sofre e o atordoamento.
type Move struct {
	Name     string  `json:"name"`
	Type     string  `json:"type"`
	Shape    string  `json:"shape"`
	Power    float64 `json:"power"`
	Cooldown float64 `json:"cooldown"`
	Cost     float64 `json:"cost"`
	Delay    float64 `json:"delay"`
	Speed    float64 `json:"speed"`
}

var moveBook = map[string]Move{
	"Tackle":        {"Tackle", "Normal", "dash", 40, .9, 0, 0, 230},
	"Scratch":       {"Scratch", "Normal", "dash", 40, .8, 0, 0, 210},
	"Pound":         {"Pound", "Normal", "dash", 40, .8, 0, 0, 210},
	"Quick Attack":  {"Quick Attack", "Normal", "dash", 40, 1.4, 8, 0, 380},
	"Body Slam":     {"Body Slam", "Normal", "dash", 85, 3, 20, 0, 240},
	"Hyper Fang":    {"Hyper Fang", "Normal", "dash", 80, 3, 20, 0, 300},
	"Flail":         {"Flail", "Normal", "dash", 60, 2, 10, 0, 260},
	"Swift":         {"Swift", "Normal", "spread", 60, 2.4, 18, 0, 240},
	"Hyper Beam":    {"Hyper Beam", "Normal", "beam", 150, 10, 60, 1.2, 0},
	"Splash":        {"Splash", "Normal", "none", 0, 1, 0, 0, 0},
	"Ember":         {"Ember", "Fogo", "shot", 40, .55, 0, 0, 210},
	"Flamethrower":  {"Flamethrower", "Fogo", "stream", 90, 5, 35, 0, 260},
	"Fire Spin":     {"Fire Spin", "Fogo", "blast", 60, 5, 25, .6, 0},
	"Fire Blast":    {"Fire Blast", "Fogo", "blast", 110, 8, 50, .9, 0},
	"Vine Whip":     {"Vine Whip", "Planta", "beam", 45, 1, 0, .12, 0},
	"Razor Leaf":    {"Razor Leaf", "Planta", "spread", 55, 2.4, 15, 0, 250},
	"Solar Beam":    {"Solar Beam", "Planta", "beam", 120, 8, 50, 1.1, 0},
	"Bubble":        {"Bubble", "Água", "shot", 30, .55, 0, 0, 150},
	"Water Gun":     {"Water Gun", "Água", "shot", 40, .55, 0, 0, 230},
	"Bubble Beam":   {"Bubble Beam", "Água", "spread", 65, 2.6, 18, 0, 200},
	"Surf":          {"Surf", "Água", "wave", 90, 6, 40, .3, 0},
	"Hydro Pump":    {"Hydro Pump", "Água", "beam", 110, 7, 45, .45, 0},
	"Waterfall":     {"Waterfall", "Água", "dash", 80, 3, 20, 0, 280},
	"Thunder Shock": {"Thunder Shock", "Elétrico", "shot", 40, .55, 0, 0, 280},
	"Thunderbolt":   {"Thunderbolt", "Elétrico", "beam", 90, 4.5, 30, .25, 0},
	"Thunder":       {"Thunder", "Elétrico", "blast", 110, 8, 50, .8, 0},
	"Gust":          {"Gust", "Voador", "shot", 40, .6, 0, 0, 220},
	"Wing Attack":   {"Wing Attack", "Voador", "dash", 60, 1.8, 10, 0, 320},
	"Air Slash":     {"Air Slash", "Voador", "spread", 75, 3, 22, 0, 270},
	"Leech Life":    {"Leech Life", "Inseto", "dash", 40, 1, 0, 0, 260},
	"Supersonic":    {"Supersonic", "Normal", "wave", 20, 5, 25, .2, 0},
	"Rock Throw":    {"Rock Throw", "Pedra", "shot", 50, .9, 0, 0, 170},
	"Rock Slide":    {"Rock Slide", "Pedra", "blast", 75, 4, 30, .7, 0},
	"Earthquake":    {"Earthquake", "Terra", "wave", 100, 7, 45, .45, 0},
	"Lick":          {"Lick", "Fantasma", "dash", 30, .8, 0, 0, 220},
	"Night Shade":   {"Night Shade", "Fantasma", "beam", 60, 2.5, 15, .3, 0},
	"Shadow Ball":   {"Shadow Ball", "Fantasma", "shot", 80, 3.5, 30, 0, 190},
	"Bite":          {"Bite", "Noturno", "dash", 60, 1.2, 5, 0, 260},
	"Faint Attack":  {"Faint Attack", "Noturno", "shot", 60, 2, 15, 0, 300},
	"Dark Pulse":    {"Dark Pulse", "Noturno", "wave", 80, 5, 35, .3, 0},
	"Confusion":     {"Confusion", "Psíquico", "shot", 50, .7, 0, 0, 240},
	"Psybeam":       {"Psybeam", "Psíquico", "beam", 65, 3, 20, .3, 0},
	"Psychic":       {"Psychic", "Psíquico", "blast", 90, 5, 35, .5, 0},
	"Ice Beam":      {"Ice Beam", "Gelo", "beam", 90, 5, 35, .5, 0},
	"Blizzard":      {"Blizzard", "Gelo", "wave", 110, 8, 50, .5, 0},
}

var movesets = map[int][4]string{
	1:   {"Tackle", "Vine Whip", "Razor Leaf", "Solar Beam"},
	2:   {"Tackle", "Vine Whip", "Razor Leaf", "Solar Beam"},
	4:   {"Scratch", "Ember", "Flamethrower", "Fire Spin"},
	5:   {"Scratch", "Ember", "Flamethrower", "Fire Blast"},
	7:   {"Tackle", "Water Gun", "Bubble Beam", "Hydro Pump"},
	8:   {"Bite", "Water Gun", "Bubble Beam", "Hydro Pump"},
	16:  {"Quick Attack", "Gust", "Wing Attack", "Air Slash"},
	19:  {"Quick Attack", "Bite", "Swift", "Hyper Fang"},
	25:  {"Quick Attack", "Thunder Shock", "Thunderbolt", "Thunder"},
	26:  {"Quick Attack", "Thunder Shock", "Thunderbolt", "Thunder"},
	41:  {"Leech Life", "Supersonic", "Wing Attack", "Air Slash"},
	74:  {"Tackle", "Rock Throw", "Rock Slide", "Earthquake"},
	95:  {"Body Slam", "Rock Throw", "Rock Slide", "Earthquake"},
	94:  {"Lick", "Night Shade", "Shadow Ball", "Dark Pulse"},
	197: {"Quick Attack", "Bite", "Faint Attack", "Dark Pulse"},
	129: {"Splash", "Tackle", "Bubble", "Flail"},
	130: {"Bite", "Waterfall", "Hydro Pump", "Hyper Beam"},
	131: {"Water Gun", "Ice Beam", "Surf", "Blizzard"},
	133: {"Tackle", "Quick Attack", "Bite", "Swift"},
	134: {"Quick Attack", "Water Gun", "Surf", "Hydro Pump"},
	135: {"Quick Attack", "Thunder Shock", "Thunderbolt", "Thunder"},
	136: {"Quick Attack", "Ember", "Flamethrower", "Fire Blast"},
	151: {"Pound", "Confusion", "Psybeam", "Psychic"},
}

func movesFor(m Mon) [4]Move {
	names, ok := movesets[m.Species]
	if !ok {
		names = [4]string{"Tackle", "Quick Attack", "Swift", "Body Slam"}
	}
	var out [4]Move
	for i, n := range names {
		out[i] = moveBook[n]
	}
	return out
}

// Tabela de tipos (subconjunto das gerações clássicas, nomes em PT-BR).
var typeChart = map[string]map[string]float64{
	"Normal":   {"Pedra": .5, "Fantasma": 0},
	"Fogo":     {"Planta": 2, "Gelo": 2, "Inseto": 2, "Fogo": .5, "Água": .5, "Pedra": .5, "Dragão": .5},
	"Água":     {"Fogo": 2, "Pedra": 2, "Terra": 2, "Água": .5, "Planta": .5, "Dragão": .5},
	"Planta":   {"Água": 2, "Pedra": 2, "Terra": 2, "Fogo": .5, "Planta": .5, "Voador": .5, "Inseto": .5, "Dragão": .5},
	"Elétrico": {"Água": 2, "Voador": 2, "Elétrico": .5, "Planta": .5, "Dragão": .5, "Terra": 0},
	"Gelo":     {"Planta": 2, "Voador": 2, "Terra": 2, "Dragão": 2, "Fogo": .5, "Água": .5, "Gelo": .5},
	"Voador":   {"Planta": 2, "Inseto": 2, "Elétrico": .5, "Pedra": .5},
	"Pedra":    {"Fogo": 2, "Gelo": 2, "Voador": 2, "Inseto": 2, "Terra": .5},
	"Terra":    {"Fogo": 2, "Elétrico": 2, "Pedra": 2, "Planta": .5, "Inseto": .5, "Voador": 0},
	"Inseto":   {"Planta": 2, "Psíquico": 2, "Noturno": 2, "Fogo": .5, "Voador": .5, "Fantasma": .5},
	"Fantasma": {"Fantasma": 2, "Psíquico": 2, "Noturno": .5, "Normal": 0},
	"Psíquico": {"Psíquico": .5, "Noturno": 0},
	"Noturno":  {"Fantasma": 2, "Psíquico": 2, "Noturno": .5},
}

func effectiveness(attack, defend string) float64 {
	if v, ok := typeChart[attack][defend]; ok {
		return v
	}
	return 1
}

// potency: tamanho dos golpes especiais, guiado pelo Sp. Atk e pelo nível.
func potency(f *Fighter) float64 {
	spa := float64(f.Mon.IV[3]) + float64(f.Mon.EV[3])/4
	return 1 + spa/94*.35 + float64(f.Mon.Level)/100*.45
}

func physical(m Move) bool { return m.Shape == "dash" }

func moveDamage(a, b *Fighter, m Move) float64 {
	if m.Power <= 0 {
		return 0
	}
	sp := species[a.Mon.Species]
	stat := float64(a.Mon.IV[3]+a.Mon.EV[3]/4) / 8
	defense := float64(b.Mon.IV[4]+b.Mon.EV[4]/4) / 10
	if physical(m) {
		stat = float64(a.Mon.IV[1]+a.Mon.EV[1]/4) / 8
		defense = float64(b.Mon.IV[2]+b.Mon.EV[2]/4) / 10
	}
	base := 10 + sp.Attack/10 + float64(a.Mon.Level)/2 + stat - defense
	factor := effectiveness(m.Type, species[b.Mon.Species].Type)
	if m.Type == sp.Type {
		factor *= 1.25
	}
	factor *= clamp(1+float64(a.Mon.Level-b.Mon.Level)/80, .75, 1.35)
	if a.Meal == "iguaria" && a.MealUntil > nowSec() {
		factor *= 1.08
	}
	if a.Mon.Held == "Pedra Dura" && m.Type == "Pedra" {
		factor *= 1.15
	}
	if factor == 0 {
		return 0
	}
	return math.Max(2, base*m.Power/50*factor)
}

// knockback: empurrão causado pelo golpe. Alvos pesados e grandes resistem;
// investidas de Pokémon pesados empurram mais.
func knockback(a, b *Fighter, m Move) float64 {
	base := m.Power / 4
	if physical(m) {
		base *= math.Sqrt((a.Physique.Mass + 10) / (b.Physique.Mass + 10))
	} else {
		base *= math.Sqrt(potency(a)) / math.Sqrt(1+b.Physique.Mass/15)
	}
	base *= clamp(1+float64(a.Mon.Level-b.Mon.Level)/100, .8, 1.25)
	return clamp(base, 1, 70)
}

func (b *Battle) hit(i int, target *Fighter, dmg, push float64, dir Vec, kind string, now float64) {
	if dmg <= 0 && push <= 0 {
		return
	}
	target.HP = math.Max(0, target.HP-dmg)
	b.Fighters[i].Damage += dmg
	b.step(target, target.Pos.Add(dir.Unit().Mul(push)))
	// Empurrões fortes atordoam; o porte reduz o tempo.
	if push > 22 {
		target.StunUntil = math.Max(target.StunUntil, now+math.Min(.6, push/90)/math.Sqrt(target.Physique.Scale))
	}
	resist := math.Sqrt(1 + target.Physique.Mass/60)
	switch kind {
	case "Elétrico", "Gelo":
		target.SlowUntil = math.Max(target.SlowUntil, now+1.6/resist)
	}
}

func (b *Battle) useMove(i, slot int, aim Vec, now float64) error {
	if slot < 0 || slot > 3 {
		return fmt.Errorf("golpe inválido")
	}
	f, target := b.Fighters[i], b.Fighters[1-i]
	m := f.Moves[slot]
	if m.Name == "" {
		f.Moves = movesFor(f.Mon)
		m = f.Moves[slot]
	}
	if now < f.MoveAt[slot] {
		return fmt.Errorf("%s recarregando", m.Name)
	}
	if f.Energy < m.Cost {
		return fmt.Errorf("energia insuficiente")
	}
	if now < f.StunUntil {
		return fmt.Errorf("atordoado")
	}
	f.MoveAt[slot] = now + m.Cooldown
	f.Energy -= m.Cost
	f.LastMove = slot
	f.LastMoveAt = now
	if slot == 0 {
		f.ShotAt = f.MoveAt[0]
	} else {
		f.SpecialAt = math.Max(f.SpecialAt, f.MoveAt[slot])
	}
	dir := aim.Add(f.Pos.Mul(-1)).Unit()
	f.Facing = facing(dir)
	scale := potency(f) * f.Physique.Scale
	dmg := moveDamage(f, target, m)
	push := knockback(f, target, m)
	switch m.Shape {
	case "none":
		b.Log = f.Mon.displayName() + " usou Splash... nada aconteceu."
	case "shot", "spread", "stream":
		angles := []float64{0}
		speeds := []float64{1}
		if m.Shape == "spread" {
			angles = []float64{-.24, 0, .24}
			if m.Name == "Swift" {
				angles = []float64{-.36, -.18, 0, .18, .36}
			}
			dmg /= float64(len(angles)) / 1.6
		}
		if m.Shape == "stream" {
			angles = []float64{-.05, .04, -.02, .05, 0, -.04}
			speeds = []float64{1, .9, .8, .7, .6, .5}
			dmg /= 3
		}
		radius := 6 * scale
		if m.Power >= 80 {
			radius = 9 * scale
		}
		if f.Mon.Held == "Lente Foco" {
			radius *= 1.3
		}
		for k, a := range angles {
			sp := speeds[0]
			if k < len(speeds) {
				sp = speeds[k]
			}
			d := rotate(dir, a)
			speed := (m.Speed + float64(f.Mon.EV[5])/12) * sp
			life := 2.5
			if m.Shape == "stream" {
				life = .75
			}
			b.Projectiles = append(b.Projectiles, Projectile{Pos: f.Pos.Add(d.Mul(14 + f.Physique.Radius)), Vel: d.Mul(speed), Owner: f.Owner, Type: m.Type, Move: m.Name, Life: life, Damage: dmg, Radius: radius, Knock: push / float64(len(angles)) * 1.5})
		}
	case "beam":
		length := 230 + 60*potency(f)
		b.Beams = append(b.Beams, Beam{From: f.Pos, To: f.Pos.Add(dir.Mul(length)), Owner: f.Owner, Type: m.Type, Move: m.Name, At: now + m.Delay, End: now + m.Delay + .35 + m.Power/400, Width: (5 + m.Power/14) * scale, Damage: dmg, Knock: push})
	case "blast":
		pos := bounds(aim)
		delta := pos.Add(f.Pos.Mul(-1))
		reach := 150 + 40*potency(f)
		if delta.Len() > reach {
			pos = f.Pos.Add(delta.Unit().Mul(reach))
		}
		b.Blasts = append(b.Blasts, Blast{Pos: pos, Owner: f.Owner, Type: m.Type, Move: m.Name, At: now + m.Delay, Radius: (22 + m.Power/4) * scale, Damage: dmg, Knock: push})
	case "wave":
		b.Blasts = append(b.Blasts, Blast{Pos: f.Pos, Owner: f.Owner, Type: m.Type, Move: m.Name, At: now + m.Delay, Radius: (40 + m.Power/2.5) * scale, Damage: dmg, Knock: push, Wave: true})
	case "dash":
		f.ChargeUntil = now + .22 + m.Power/900
		f.ChargeDir = dir
		f.ChargeSpeed = m.Speed / math.Pow(1+f.Physique.Mass/80, .15)
		f.ChargeSlot = slot
		f.ChargeHit = false
		f.Invincible = math.Max(f.Invincible, now+.12)
	}
	return nil
}

func (b *Battle) tickCharges(dt, now float64) {
	for i, f := range b.Fighters {
		if f.ChargeUntil <= now {
			continue
		}
		b.step(f, f.Pos.Add(f.ChargeDir.Mul(f.ChargeSpeed * dt)))
		target := b.Fighters[1-i]
		if f.ChargeHit || target.Invincible >= now {
			continue
		}
		if distance(f.Pos, target.Pos) < f.Physique.Radius+target.Physique.Radius+4 {
			m := f.Moves[f.ChargeSlot]
			push := knockback(f, target, m)
			b.hit(i, target, moveDamage(f, target, m), push, f.ChargeDir, m.Type, now)
			if m.Name == "Leech Life" {
				f.HP = math.Min(f.MaxHP, f.HP+moveDamage(f, target, m)/2)
			}
			// Recuo: quem bate num alvo muito mais pesado volta para trás.
			recoil := clamp(push*math.Sqrt((target.Physique.Mass+10)/(f.Physique.Mass+10))*.35, 0, 40)
			b.step(f, f.Pos.Add(f.ChargeDir.Mul(-recoil)))
			f.ChargeHit = true
			f.ChargeUntil = now
		}
	}
}

// autoMove escolhe o golpe da IA: o mais forte disponível que faça sentido
// para a distância atual.
func (b *Battle) autoMove(i int, now float64) {
	f, target := b.Fighters[i], b.Fighters[1-i]
	dist := distance(f.Pos, target.Pos)
	order := []int{3, 2, 1, 0}
	if mathrand.Float64() < .6 {
		order = []int{0, 1, 2, 3}
	}
	for _, s := range order {
		m := f.Moves[s]
		if m.Name == "" || now < f.MoveAt[s] || f.Energy < m.Cost || m.Shape == "none" {
			continue
		}
		if m.Shape == "dash" && dist > 130 {
			continue
		}
		if m.Shape == "wave" && dist > 90 {
			continue
		}
		if s > 0 && mathrand.Float64() > .35 {
			continue
		}
		_ = b.useMove(i, s, target.Pos, now)
		return
	}
}

func rotate(v Vec, a float64) Vec {
	c, s := math.Cos(a), math.Sin(a)
	return Vec{v.X*c - v.Y*s, v.X*s + v.Y*c}
}

func (m Mon) displayName() string {
	if s, ok := species[m.Species]; ok {
		return s.Name
	}
	return "Pokémon"
}

func (b *Battle) updateEff() {
	for i, f := range b.Fighters {
		target := b.Fighters[1-i]
		if f == nil || target == nil {
			continue
		}
		for k, m := range f.Moves {
			f.Eff[k] = effectiveness(m.Type, species[target.Mon.Species].Type)
		}
	}
}
