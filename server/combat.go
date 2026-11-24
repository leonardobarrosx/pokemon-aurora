package main

import (
	"fmt"
	"math"
	mathrand "math/rand/v2"
)

func makeFighter(p *Player, m Mon, pos Vec) *Fighter {
	hp := 90 + species[m.Species].HP + float64(m.Level*3+m.IV[0]+m.EV[0]/4)
	f := &Fighter{Owner: "npc", Name: species[m.Species].Name, Mon: m, Pos: pos, HP: hp, MaxHP: hp, Energy: 100, Auto: true, Used: map[string]bool{m.ID: true}, Physique: physique(m)}
	if p != nil {
		f.Owner = p.ID
		f.Name = p.Name
		f.Auto = p.Auto
		f.Meal = p.Meal
		f.MealUntil = p.MealUntil
	}
	return f
}
func (w *World) startBattle(p *Player, kind string, s int, other *Player, now float64) error {
	if p.Battle != "" || p.Arcade != nil {
		return fmt.Errorf("termine a atividade atual")
	}
	if len(p.Team) == 0 {
		return fmt.Errorf("escolha um parceiro")
	}
	b := &Battle{ID: uid(), Kind: kind, Start: now, Projectiles: []Projectile{}, Beams: []Beam{}, Blasts: []Blast{}, Log: "Mova-se, mire com o mouse e ataque!"}
	b.Fighters[0] = makeFighter(p, *p.mon(p.Team[0]), Vec{100, 230})
	m := newMon(s)
	if kind == "gym" {
		m.Level = 12
	}
	b.Fighters[1] = makeFighter(nil, m, Vec{410, 200})
	if kind == "gym" {
		b.Fighters[1].Name = "Flora"
	}
	if other != nil {
		if other.Battle != "" {
			return fmt.Errorf("treinador já está em batalha")
		}
		b.Fighters[1] = makeFighter(other, *other.mon(other.Team[0]), Vec{410, 200})
		other.Battle = b.ID
	}
	if kind == "capture" || kind == "event" {
		b.Fighters[0].Auto = false
	}
	p.Battle = b.ID
	w.Battles[b.ID] = b
	return nil
}
func damage(a, b *Fighter) float64 {
	at, bt := species[a.Mon.Species].Type, species[b.Mon.Species].Type
	factor := 1.0
	if a.Meal == "iguaria" && a.MealUntil > nowSec() {
		factor *= 1.08
	}
	if (at == "Fogo" && bt == "Planta") || (at == "Planta" && (bt == "Água" || bt == "Pedra")) || (at == "Água" && (bt == "Fogo" || bt == "Pedra")) || (at == "Elétrico" && (bt == "Água" || bt == "Voador")) {
		factor = 1.4
	}
	if a.Mon.Held == "Pedra Dura" && at == "Pedra" {
		factor *= 1.15
	}
	return math.Max(3, (10+species[a.Mon.Species].Attack/10+float64(a.Mon.Level)/2+float64(a.Mon.IV[1]+a.Mon.EV[1]/4)/8-float64(b.Mon.EV[2])/40)*factor)
}
func (b *Battle) shoot(i int, aim Vec, now float64, special bool) error {
	f, target := b.Fighters[i], b.Fighters[1-i]
	f.Facing = facing(aim.Add(f.Pos.Mul(-1)))
	if special {
		if now < f.SpecialAt || f.Energy < 30 {
			return fmt.Errorf("habilidade recarregando")
		}
		f.SpecialAt = now + 4
		f.Energy -= 30
		if b.beamSkill(i, aim, now) {
			return nil
		}
		pos := bounds(aim)
		delta := pos.Add(f.Pos.Mul(-1))
		if delta.Len() > 180 {
			pos = f.Pos.Add(delta.Unit().Mul(180))
		}
		b.Blasts = append(b.Blasts, Blast{Pos: pos, Owner: f.Owner, Type: species[f.Mon.Species].Type, At: now + .75, Radius: 42})
		return nil
	}
	if now < f.ShotAt {
		return fmt.Errorf("golpe recarregando")
	}
	f.ShotAt = now + .65
	dir := aim.Add(f.Pos.Mul(-1)).Unit()
	f.Facing = facing(dir)
	speed := 185 + float64(f.Mon.EV[5])/12
	radius := 7.0
	if f.Mon.Held == "Lente Foco" {
		radius = 10
	}
	b.Projectiles = append(b.Projectiles, Projectile{Pos: f.Pos.Add(dir.Mul(18)), Vel: dir.Mul(speed), Owner: f.Owner, Type: species[f.Mon.Species].Type, Life: 2.5, Damage: damage(f, target), Radius: radius})
	return nil
}
func (w *World) endBattle(b *Battle, winner string, now float64) {
	if b.End > 0 {
		return
	}
	b.End = now
	b.Winner = winner
	for _, f := range b.Fighters {
		p := w.Players[f.Owner]
		if p == nil {
			continue
		}
		p.Battle = ""
		p.Input = Vec{}
		p.Notice = "Seus parceiros foram recuperados. Tente novamente!"
		if winner == p.ID {
			p.XP += 25
			if m := p.mon(f.Mon.ID); m != nil && m.Level < 100 {
				m.Level++
			}
			p.Notice = "Vitória! +25 XP de treinador."
			if b.Kind == "gym" {
				p.Coins += 40
				p.Flags["gym"]++
				elapsed := now - b.Start
				if p.Records["gym"] == 0 || elapsed < p.Records["gym"] {
					p.Records["gym"] = elapsed
				}
				p.Records["damage"] = math.Max(p.Records["damage"], f.Damage)
			}
			if b.Kind == "pvp" {
				p.Wins++
				p.Rating += 24
				opponent := ""
				for _, foe := range b.Fighters {
					if foe.Owner != p.ID {
						opponent = foe.Owner
					}
				}
				key := fmt.Sprintf("%s:%d", opponent, int(now)/86400)
				if p.Rewarded[key] < 3 {
					p.Coins += 150
					p.Rewarded[key]++
					p.Notice = "Vitória online! +150 moedas · +24 classificação."
				}
			}
		} else if b.Kind == "pvp" {
			p.Losses++
			p.Rating = max(100, p.Rating-16)
		}
	}
}
func (w *World) nextMon(b *Battle, i int, now float64) bool {
	f := b.Fighters[i]
	p := w.Players[f.Owner]
	if p == nil {
		return false
	}
	for _, id := range p.Team {
		if !f.Used[id] {
			m := p.mon(id)
			if m != nil {
				next := makeFighter(p, *m, f.Pos)
				next.Used = f.Used
				next.Used[id] = true
				next.Damage = f.Damage
				next.Invincible = now + 1
				next.Auto = f.Auto
				b.Fighters[i] = next
				return true
			}
		}
	}
	return false
}
func (w *World) tick(dt, now float64) {
	for _, p := range w.Players {
		if now-p.InputAt > .3 {
			p.Input = Vec{}
		}
		if p.Battle == "" && p.Arcade == nil {
			movePlayer(p, dt)
		}
		settleTraining(p, now)
		if p.Arcade != nil {
			a := p.Arcade
			a.Pos = bounds(a.Pos.Add(p.Input.Mul(dt * 170)))
			t := now - a.Start
			a.Score = int(math.Min(t, 30) * 10)
			hit := false
			if a.Kind == "arcade" {
				for i := 0; i < 9; i++ {
					x := 40 + float64(i)*54 + math.Sin(t*.8+float64(i)+a.Seed)*28
					y := math.Mod(t*65+float64(i)*41, 310) + 50
					if distance(a.Pos, Vec{x, y}) < 13 {
						hit = true
					}
				}
			} else {
				center := 256 + math.Sin(t*.65+a.Seed)*110
				hit = math.Abs(a.Pos.X-center) > 80
			}
			if hit && now > a.HitAt {
				a.HP--
				a.HitAt = now + 1
			}
			if t >= 30 || a.HP <= 0 {
				p.Points += a.Score / 20
				p.Coins += min(12, a.Score/25)
				p.Records[a.Kind] = math.Max(p.Records[a.Kind], float64(a.Score))
				p.Notice = fmt.Sprintf("Minijogo: %d pontos, +%d fichas!", a.Score, a.Score/20)
				p.Arcade = nil
			}
		}
	}
	for id, b := range w.Battles {
		if b.PauseUntil > now {
			continue
		}
		if b.End > 0 {
			if now-b.End > 120 {
				delete(w.Battles, id)
			}
			continue
		}
		for i, f := range b.Fighters {
			target := b.Fighters[1-i]
			p := w.Players[f.Owner]
			if p != nil && now-p.Seen > 20 {
				w.endBattle(b, target.Owner, now)
				break
			}
			regen := 9.0
			if f.Meal == "ensopado" && f.MealUntil > now {
				regen *= 1.05
			}
			f.Energy = math.Min(100, f.Energy+dt*regen)
			if f.Auto {
				delta := target.Pos.Add(f.Pos.Mul(-1))
				f.Facing = facing(delta)
				if delta.Len() > 160 {
					f.Pos = bounds(f.Pos.Add(delta.Unit().Mul(dt * 60)))
				}
				f.Pos = bounds(f.Pos.Add(Vec{0, math.Sin(now*2+float64(i)) * dt * 35}))
				_ = b.shoot(i, target.Pos, now, false)
				if mathrand.Float64() < dt*.25 {
					_ = b.shoot(i, target.Pos, now, true)
				}
			} else if p != nil {
				speed := (105 + float64(f.Mon.EV[5])/10) / math.Pow(1+f.Physique.Mass/50, .12)
				if f.SlowUntil > now {
					speed *= .65
				}
				if f.Meal == "salada" && f.MealUntil > now {
					speed *= 1.05
				}
				if p.Input.Len() > 0 {
					f.Facing = p.Facing
				}
				targetVel := p.Input.Mul(speed)
				accel := clamp(dt*10/math.Pow(1+f.Physique.Mass/30, .3), 0, 1)
				f.Velocity = f.Velocity.Add(targetVel.Add(f.Velocity.Mul(-1)).Mul(accel))
				f.Pos = bounds(f.Pos.Add(f.Velocity.Mul(dt)))
			}
		}
		if b.End > 0 {
			continue
		}
		shots := b.Projectiles[:0]
		for _, s := range b.Projectiles {
			s.Pos = s.Pos.Add(s.Vel.Mul(dt))
			s.Life -= dt
			for i, target := range b.Fighters {
				if target.Owner != s.Owner && target.Invincible < now && distance(target.Pos, s.Pos) < s.Radius+target.Physique.Radius {
					target.HP = math.Max(0, target.HP-s.Damage)
					target.Pos = bounds(target.Pos.Add(s.Vel.Unit().Mul(clamp(18/math.Pow(1+target.Physique.Mass/15, .5), 2, 18))))
					if s.Type == "Elétrico" || s.Type == "Gelo" {
						target.SlowUntil = now + 1.5
					}
					b.Fighters[1-i].Damage += s.Damage
					s.Life = 0
				}
			}
			if s.Life > 0 && s.Pos.X > 0 && s.Pos.X < 512 && s.Pos.Y > 80 && s.Pos.Y < 364 {
				shots = append(shots, s)
			}
		}
		b.Projectiles = shots
		blasts := b.Blasts[:0]
		for _, s := range b.Blasts {
			if now >= s.At && !s.Done {
				for i, target := range b.Fighters {
					if target.Owner != s.Owner && target.Invincible < now && distance(target.Pos, s.Pos) < s.Radius+target.Physique.Radius {
						d := damage(b.Fighters[1-i], target) * 1.8
						target.HP = math.Max(0, target.HP-d)
						b.Fighters[1-i].Damage += d
					}
				}
				s.Done = true
			}
			if now < s.At+.35 {
				blasts = append(blasts, s)
			}
		}
		b.Blasts = blasts
		b.tickBeams(now)
		for i, f := range b.Fighters {
			if f.HP <= 0 {
				winner := b.Fighters[1-i]
				if p := w.Players[winner.Owner]; p != nil {
					if m := p.mon(winner.Mon.ID); m != nil {
						m.Level = min(100, m.Level+1)
						m.Affinity = min(100, m.Affinity+2)
						winner.Mon = *m
						p.Notice = "Seu parceiro subiu de nível! Pressione V se puder evoluir."
					}
				}
				if !w.nextMon(b, i, now) {
					w.endBattle(b, winner.Owner, now)
					break
				}
			}
		}
		if b.End == 0 && now-b.Start > 180 {
			winner := b.Fighters[0]
			if b.Fighters[1].HP/b.Fighters[1].MaxHP > winner.HP/winner.MaxHP {
				winner = b.Fighters[1]
			}
			w.endBattle(b, winner.Owner, now)
		}
	}
	queue := w.Queue[:0]
	for _, id := range w.Queue {
		p := w.Players[id]
		if p != nil && p.Battle == "" && p.Area == "ginasio" && now-p.Seen < 10 {
			queue = append(queue, id)
		}
	}
	w.Queue = queue
}

func facing(v Vec) int {
	if math.Abs(v.X) > math.Abs(v.Y) {
		if v.X < 0 {
			return 1
		}
		return 2
	}
	if v.Y < 0 {
		return 3
	}
	return 0
}
