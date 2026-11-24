package main

import "math"

type Beam struct {
	From   Vec     `json:"from"`
	To     Vec     `json:"to"`
	Owner  string  `json:"owner"`
	Type   string  `json:"type"`
	At     float64 `json:"at"`
	End    float64 `json:"end"`
	Width  float64 `json:"width"`
	Damage float64 `json:"damage"`
	Done   bool    `json:"done"`
}

func segmentDistance(p, a, b Vec) float64 {
	ab := b.Add(a.Mul(-1))
	den := ab.X*ab.X + ab.Y*ab.Y
	if den == 0 {
		return distance(p, a)
	}
	d := p.Add(a.Mul(-1))
	t := clamp((d.X*ab.X+d.Y*ab.Y)/den, 0, 1)
	return distance(p, a.Add(ab.Mul(t)))
}
func (b *Battle) beamSkill(i int, aim Vec, now float64) bool {
	f := b.Fighters[i]
	kind := species[f.Mon.Species].Type
	if kind != "Planta" && kind != "Água" {
		return false
	}
	delay, width, duration := 1.1, 12.0, .35
	if kind == "Água" {
		delay = .35
		width = 9
		duration = .65
	}
	if f.Mon.Species == 131 {
		kind = "Gelo"
		delay = .5
	}
	direction := aim.Add(f.Pos.Mul(-1)).Unit()
	b.Beams = append(b.Beams, Beam{From: f.Pos, To: f.Pos.Add(direction.Mul(280 + float64(f.Mon.Level))), Owner: f.Owner, Type: kind, At: now + delay, End: now + delay + duration, Width: width * f.Physique.Scale, Damage: damage(f, b.Fighters[1-i]) * 2})
	return true
}
func (b *Battle) tickBeams(now float64) {
	active := b.Beams[:0]
	for _, beam := range b.Beams {
		if now >= beam.At && !beam.Done {
			for i, target := range b.Fighters {
				if target.Owner != beam.Owner && target.Invincible < now && segmentDistance(target.Pos, beam.From, beam.To) < target.Physique.Radius+beam.Width {
					target.HP = math.Max(0, target.HP-beam.Damage)
					b.Fighters[1-i].Damage += beam.Damage
					if beam.Type == "Água" {
						target.Pos = bounds(target.Pos.Add(beam.To.Add(beam.From.Mul(-1)).Unit().Mul(45 / math.Sqrt(1+target.Physique.Mass/10))))
					}
					if beam.Type == "Gelo" {
						target.SlowUntil = now + 2.5
					}
				}
			}
			beam.Done = true
		}
		if now < beam.End {
			active = append(active, beam)
		}
	}
	b.Beams = active
}
