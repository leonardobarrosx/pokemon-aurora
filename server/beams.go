package main

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
	Move   string  `json:"move"`
	Knock  float64 `json:"knock"`
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
func (b *Battle) tickBeams(now float64) {
	active := b.Beams[:0]
	for _, beam := range b.Beams {
		if now >= beam.At && !beam.Done {
			for i, target := range b.Fighters {
				if target.Owner != beam.Owner && target.Invincible < now && segmentDistance(target.Pos, beam.From, beam.To) < target.Physique.Radius+beam.Width {
					b.hit(1-i, target, beam.Damage, beam.Knock, beam.To.Add(beam.From.Mul(-1)), beam.Type, now)
				}
			}
			beam.Done = true
			b.shapeBeam(beam.From, beam.To, beam.Type, beam.Damage, now)
		}
		if now < beam.End {
			active = append(active, beam)
		}
	}
	b.Beams = active
}
