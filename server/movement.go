package main

type obstacle struct{ x, y, w, h float64 }

func blocked(area string, v Vec) bool {
	objects := []obstacle{}
	switch area {
	case "casa":
		if v.X < 40 || v.X > 472 || v.Y < 144 || v.Y > 338 {
			return true
		}
		objects = []obstacle{{48, 176, 128, 80}, {208, 216, 96, 48}, {352, 220, 96, 52}}
	case "vila":
		objects = []obstacle{{16, 132, 192, 134}, {304, 132, 192, 134}}
	case "lago":
		if v.X < 224 || v.X > 288 {
			objects = []obstacle{{48, 112, 368, 160}}
		}
	}
	for _, o := range objects {
		if v.X > o.x-7 && v.X < o.x+o.w+7 && v.Y > o.y-7 && v.Y < o.y+o.h+7 {
			return true
		}
	}
	return false
}
func movePlayer(p *Player, dt float64) {
	speed := 80.0
	if p.Transport == "bike" && p.Area != "casa" {
		speed = 120
	}
	desired := bounds(p.Pos.Add(p.Input.Mul(speed * dt)))
	x := Vec{desired.X, p.Pos.Y}
	if !blocked(p.Area, x) {
		p.Pos = x
	}
	y := Vec{p.Pos.X, desired.Y}
	if !blocked(p.Area, y) {
		p.Pos = y
	}
}
