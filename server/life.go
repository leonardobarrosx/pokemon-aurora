package main

import (
	"math"
	mathrand "math/rand/v2"
)

// Size/mass are species-relative and genetically inherited. Clamps keep combat readable.
type Physique struct {
	Height float64 `json:"height"`
	Mass   float64 `json:"mass"`
	Scale  float64 `json:"scale"`
	Radius float64 `json:"radius"`
}

var measures = map[int][2]float64{1: {.7, 6.9}, 2: {1, 13}, 4: {.6, 8.5}, 5: {1.1, 19}, 7: {.5, 9}, 8: {1, 22.5}, 16: {.3, 1.8}, 19: {.3, 3.5}, 25: {.4, 6}, 26: {.8, 30}, 41: {.8, 7.5}, 74: {.4, 20}, 95: {8.8, 210}, 129: {.9, 10}, 130: {6.5, 235}, 131: {2.5, 220}, 133: {.3, 6.5}, 134: {1, 29}, 135: {.8, 24.5}, 136: {.9, 25}, 151: {.4, 4}}

func physique(m Mon) Physique {
	base := measures[m.Species]
	if base[0] == 0 {
		base = [2]float64{1, 20}
	}
	pair := m.Genes.Loci["size"]
	factor := .8 + float64(pair[0].Value+pair[1].Value)/20
	factor = clamp(factor, .8, 1.2)
	height := base[0] * factor
	mass := base[1] * math.Pow(factor, 3)
	scale := clamp(.82+math.Log1p(height)*.28, .85, 1.45)
	return Physique{height, mass, scale, 12 * scale}
}
func family(s int) int {
	switch s {
	case 1, 2, 3:
		return 1
	case 4, 5, 6:
		return 4
	case 7, 8, 9:
		return 7
	case 129, 130:
		return 129
	case 25, 26, 172:
		return 25
	case 133, 134, 135, 136, 196, 197, 470, 471, 700:
		return 133
	}
	return s
}
func (w *World) eat(p *Player, meal string, now float64) error {
	switch meal {
	case "salada":
		if p.Berries < 2 {
			return errMsg("precisa de 2 berries")
		}
		p.Berries -= 2
	case "ensopado":
		if p.Berries < 3 {
			return errMsg("precisa de 3 berries")
		}
		p.Berries -= 3
	case "iguaria":
		if p.Coins < 80 {
			return errMsg("precisa de 80 moedas")
		}
		p.Coins -= 80
		for i := range p.Mons {
			if family(p.Mons[i].Species) == 129 {
				p.Mons[i].Affinity = max(0, p.Mons[i].Affinity-15)
			}
		}
	default:
		return errMsg("receita desconhecida")
	}
	p.Meal = meal
	p.MealUntil = now + 300
	p.Notice = "Refeição consumida. Um único buff de comida ativo por vez, durante 5 minutos."
	return nil
}
func (w *World) fish(p *Player, now float64) error {
	if p.Area != "lago" {
		return errMsg("pesque à beira do Lago Celeste")
	}
	if p.Fishing == 0 {
		p.Fishing = now + 2 + mathrand.Float64()*3
		p.Notice = "Vara lançada! Pressione E quando sentir a fisgada."
		return nil
	}
	bite := p.Fishing
	p.Fishing = 0
	if now < bite {
		return errMsg("puxou cedo demais; lance novamente")
	}
	if now > bite+2 {
		return errMsg("o peixe escapou; tente novamente")
	}
	return w.startBattle(p, "capture", []int{129, 129, 7, 131}[mathrand.IntN(4)], nil, now)
}
func (w *World) evolve(p *Player, id, stone string, now float64) error {
	m := p.mon(id)
	if m == nil {
		return errMsg("parceiro inexistente")
	}
	target := map[int]int{1: 2, 4: 5, 7: 8, 129: 130}[m.Species]
	level := 16
	if m.Species == 129 {
		level = 20
	}
	requiredStone := ""
	if m.Species == 25 {
		target = 26
		requiredStone = "Pedra do Trovão"
	}
	if m.Species == 133 {
		target = map[string]int{"Pedra da Água": 134, "Pedra do Trovão": 135, "Pedra de Fogo": 136}[stone]
		requiredStone = stone
	}
	if target == 0 {
		return errMsg("evolução ainda indisponível para esta espécie")
	}
	b := w.Battles[p.Battle]
	var f *Fighter
	var index int
	if b != nil {
		for i, c := range b.Fighters {
			if c.Owner == p.ID && c.Mon.ID == id {
				f = c
				index = i
			}
		}
		if f == nil {
			return errMsg("evolua o parceiro que está no campo")
		}
	}
	breakthrough := f != nil && m.Level >= level-2 && m.Affinity >= 70 && f.HP/f.MaxHP <= .25 && f.Damage >= f.MaxHP*.5 && now-b.Start >= 30
	if requiredStone != "" {
		if p.Stones[requiredStone] < 1 {
			return errMsg("pedra de evolução insuficiente")
		}
	} else if m.Level < level && !breakthrough {
		return errMsg("ainda não atingiu o nível ou as condições de superação")
	}
	if requiredStone != "" {
		p.Stones[requiredStone]--
	}
	m.Species = target
	if f != nil {
		next := makeFighter(p, *m, f.Pos)
		next.HP = next.MaxHP * (f.HP / f.MaxHP)
		next.Energy = f.Energy
		next.ShotAt = f.ShotAt
		next.SpecialAt = f.SpecialAt
		next.DashAt = f.DashAt
		next.Used = f.Used
		next.Damage = f.Damage
		next.Auto = f.Auto
		b.Fighters[index] = next
		b.PauseUntil = now + 1.2
		b.Log = "Evolução! A linhagem continua."
	}
	p.Notice = "Evolução concluída! Genes, IVs, afinidade e proporção de vida preservados."
	return nil
}
