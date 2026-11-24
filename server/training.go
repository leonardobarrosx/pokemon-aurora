package main

import "math"

func settleTraining(p *Player, now float64) {
	if p.Training == nil {
		return
	}
	tr := p.Training
	end := math.Min(now, p.Seen+8*3600)
	n := int((end - tr.At) / 30)
	if n <= 0 {
		return
	}
	stat := 5
	if tr.Route == "mina" {
		stat = 2
	}
	if tr.Route == "lago" {
		stat = 0
	}
	for _, id := range tr.IDs {
		if m := p.mon(id); m != nil {
			total := 0
			for _, v := range m.EV {
				total += v
			}
			m.EV[stat] += max(0, min(n, 252-m.EV[stat], 510-total))
		}
	}
	tr.At += float64(n) * 30
}
