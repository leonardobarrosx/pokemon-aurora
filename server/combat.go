package main

import (
	"fmt"
	"math"
)

func makeFighter(p *Player, m Mon, pos Vec) *Fighter {
	hp := 90 + species[m.Species].HP + float64(m.Level*3+m.IV[0]+m.EV[0]/4)
	f := &Fighter{Owner: "npc", Name: species[m.Species].Name, Mon: m, Pos: pos, HP: hp, MaxHP: hp, Energy: 100, Auto: true, Used: map[string]bool{m.ID: true}, Physique: physique(m), Moves: movesFor(m)}
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
	g := gymAt(p.Area)
	if g == nil {
		g = &gyms[0]
	}
	if kind == "gym" {
		m.Level = g.Level
	}
	b.Fighters[1] = makeFighter(nil, m, Vec{410, 200})
	if kind == "gym" {
		b.Gym = g.ID
		b.Fighters[1].Name = g.Leader
		b.Fighters[1].Art = g.Art
		b.Field = newField(g.ID, now)
		b.Fighters[0].Pos = b.Field.Spawn[0]
		b.Fighters[1].Pos = b.Field.Spawn[1]
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
	b.updateEff()
	b.cutin(0, "switch", "Vai, "+monName(b.Fighters[0].Mon)+"!", now)
	if kind == "gym" || kind == "pvp" {
		b.cutin(1, "switch", "Vai, "+monName(b.Fighters[1].Mon)+"!", now+1.2)
	}
	w.Battles[b.ID] = b
	return nil
}

// cutin guarda a arte do treinador para o cliente mostrar por um instante.
func (b *Battle) cutin(side int, kind, text string, at float64) {
	b.Cutins = append(b.Cutins, Cutin{Side: side, Kind: kind, Text: text, At: at})
	if len(b.Cutins) > 4 {
		b.Cutins = b.Cutins[len(b.Cutins)-4:]
	}
}

func monName(m Mon) string {
	return species[m.Species].Name
}

// shoot mantém os comandos antigos: ataque = golpe 1, especial = golpe 4.
func (b *Battle) shoot(i int, aim Vec, now float64, special bool) error {
	if special {
		return b.useMove(i, 3, aim, now)
	}
	return b.useMove(i, 0, aim, now)
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
				if g := gymByID(b.Gym); g != nil {
					if p.Badges == nil {
						p.Badges = map[string]bool{}
					}
					if !p.Badges[g.ID] {
						p.Badges[g.ID] = true
						p.Coins += 200
						p.Notice = "Vitória! Você conquistou a " + g.Badge + " de " + g.Leader + "."
					}
				}
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
				b.updateEff()
				b.cutin(i, "switch", "Vai, "+monName(next.Mon)+"!", now)
				return true
			}
		}
	}
	return false
}
func (w *World) tick(dt, now float64) {
	w.tickWild(dt, now)
	for _, p := range w.Players {
		if now-p.InputAt > .3 {
			p.Input = Vec{}
		}
		if p.Battle == "" && p.Arcade == nil {
			if areaMaps[p.Area] != nil {
				w.walkMap(p, dt, now)
			} else {
				movePlayer(p, dt)
			}
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
			if f.StunUntil > now || f.ChargeUntil > now {
				continue
			}
			if f.Auto {
				delta := target.Pos.Add(f.Pos.Mul(-1))
				f.Facing = facing(delta)
				pace := dt * 60 * b.terrainSpeed(f)
				if b.cellCost(f, f.Pos) >= 3 {
					// Caiu num lugar ruim: procura a casa certa para ficar.
					if safe, ok := b.safeCell(f); ok {
						b.autoStep(f, safe.Add(f.Pos.Mul(-1)), pace*1.4)
					}
				} else if delta.Len() > 160 {
					b.autoStep(f, delta, pace)
				}
				wobble := Vec{0, math.Sin(now*2+float64(i)) * dt * 35}
				if b.cellCost(f, f.Pos.Add(wobble.Unit().Mul(fieldCell*.6))) <= b.cellCost(f, f.Pos) {
					b.step(f, f.Pos.Add(wobble))
				}
				if f.StunUntil < now && f.ChargeUntil < now {
					b.autoMove(i, now)
				}
			} else if p != nil {
				speed := (105 + float64(f.Mon.EV[5])/10) / math.Pow(1+f.Physique.Mass/50, .12)
				if f.SlowUntil > now {
					speed *= .65
				}
				speed *= b.terrainSpeed(f)
				if f.Meal == "salada" && f.MealUntil > now {
					speed *= 1.05
				}
				if p.Input.Len() > 0 {
					f.Facing = p.Facing
				}
				targetVel := p.Input.Mul(speed)
				accel := clamp(dt*10/math.Pow(1+f.Physique.Mass/30, .3), 0, 1)
				accel *= b.grip(f) // derrapa no gelo, mais ainda se for pesado
				f.Velocity = f.Velocity.Add(targetVel.Add(f.Velocity.Mul(-1)).Mul(accel))
				before := f.Pos
				b.step(f, f.Pos.Add(f.Velocity.Mul(dt)))
				if f.Pos == before {
					f.Velocity = Vec{}
				}
			}
		}
		if b.End > 0 {
			continue
		}
		b.tickTerrain(dt, now)
		b.updateEff()
		b.tickCharges(dt, now)
		shots := b.Projectiles[:0]
		for _, s := range b.Projectiles {
			s.Pos = s.Pos.Add(s.Vel.Mul(dt))
			s.Life -= dt
			for i, target := range b.Fighters {
				if target.Owner != s.Owner && target.Invincible < now && distance(target.Pos, s.Pos) < s.Radius+target.Physique.Radius {
					b.hit(1-i, target, s.Damage, s.Knock, s.Vel, s.Type, now)
					s.Life = 0
				}
			}
			if i, hit := b.shotBlocked(s.Pos); hit && s.Life > 0 {
				s.Life = 0 // o obstáculo segura o disparo e leva o dano
				b.damageObstacle(i, s.Type, s.Damage, now)
			}
			if s.Life > 0 && b.inside(s.Pos) {
				shots = append(shots, s)
			} else {
				b.shapeField(s.Pos, s.Radius, s.Type, 0, now)
			}
		}
		b.Projectiles = shots
		blasts := b.Blasts[:0]
		for _, s := range b.Blasts {
			if now >= s.At && !s.Done {
				for i, target := range b.Fighters {
					if target.Owner != s.Owner && target.Invincible < now && distance(target.Pos, s.Pos) < s.Radius+target.Physique.Radius {
						dir := target.Pos.Add(s.Pos.Mul(-1))
						b.hit(1-i, target, s.Damage, s.Knock, dir, s.Type, now)
					}
				}
				s.Done = true
				b.shapeField(s.Pos, s.Radius, s.Type, s.Damage, now)
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
