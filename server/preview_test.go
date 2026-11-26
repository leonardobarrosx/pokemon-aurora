package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// Explicit QA fixture, never loaded into a running world or presented as online players.
func TestExportPreview(t *testing.T) {
	dir := os.Getenv("AURORA_PREVIEW_DIR")
	if dir == "" {
		t.Skip("optional rendering fixture")
	}
	w := newWorld()
	p := testPlayer(w, "Lumi", 1)
	p.Quest = 2
	p.XP = 180
	p.Color = "green"
	p.Coins = 680
	p.Berries = 6
	p.Decor = []Decor{{"planta", Vec{150, 270}}}
	a, b := newMon(133), newMon(133)
	a.Sex = "F"
	b.Sex = "M"
	a.Genes.Loci["body"] = Locus{{1, 2}, {1, 2}}
	a.Genes.Loci["detail"] = Locus{{3, 2}, {3, 2}}
	b.Genes.Loci["body"] = Locus{{2, 2}, {2, 2}}
	b.Genes.Loci["detail"] = Locus{{1, 2}, {1, 2}}
	a.Genes.Loci["pattern"] = Locus{{1, 2}, {1, 2}}
	b.Genes.Loci["pattern"] = a.Genes.Loci["pattern"]
	for _, m := range []*Mon{&a, &b} {
		m.Genes.Loci["fur"] = m.Genes.Loci["body"]
		m.Genes.Loci["accessory"] = m.Genes.Loci["detail"]
	}
	a.Look = appearance(a.Genes)
	b.Look = appearance(b.Genes)
	p.Mons = append(p.Mons, a, b)
	p.Team = append(p.Team, a.ID, b.ID)
	p.Prediction = predict(a, b)
	s := &Server{world: w}
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"casa", "vila", "battle"} {
		if name == "vila" {
			p.Area = "vila"
		}
		if name == "battle" {
			p.Area = "rota"
			_ = w.startBattle(p, "capture", 25, nil, 1000)
			battle := w.Battles[p.Battle]
			battle.Fighters[0].Pos = Vec{160, 250}
			battle.Fighters[1].Pos = Vec{350, 180}
			_ = battle.shoot(0, Vec{350, 180}, 1000, false)
			_ = battle.shoot(1, Vec{180, 250}, 1000, true)
		}
		raw, _ := json.Marshal(s.snapshot(p, 1000))
		if err := os.WriteFile(filepath.Join(dir, name+".json"), raw, 0600); err != nil {
			t.Fatal(err)
		}
	}
	// Arenas dos ginásios, com alguns golpes já mudando o terreno.
	fields := map[string]*Field{}
	for _, g := range gyms {
		bt := &Battle{Field: newField(g.ID, 990)}
		bt.Fighters[0] = &Fighter{Pos: bt.Field.Spawn[0], Mon: newMon(4)}
		bt.Fighters[1] = &Fighter{Pos: bt.Field.Spawn[1], Mon: newMon(4)}
		fl := bt.Field
		switch g.ID {
		case "kanto_2":
			w := findCell(fl, 'W')
			bt.shapeBeam(w, w.Add(Vec{200, 0}), "Gelo", 0, 1000)
			bt.shapeField(findCell(fl, '<'), 30, "Elétrico", 0, 999)
		case "kanto_4":
			bt.shapeField(findCell(fl, 'g').Add(Vec{40, 40}), 50, "Fogo", 0, 1000)
		case "kanto_7":
			bt.shapeField(findCell(fl, 'l').Add(Vec{0, 200}), 40, "Água", 0, 1000)
			for i := range fl.Cells {
				if fl.Cells[i] == 'V' {
					fl.event("geyser", fl.center(i), 46, 1, .6, 999.6)
					break
				}
			}
		case "kanto_1":
			r := findCell(fl, 'r')
			bt.damageObstacle(fl.index(r), "Lutador", 40, 1000)
		}
		fields[g.ID] = fl
	}
	raw, _ := json.Marshal(fields)
	if err := os.WriteFile(filepath.Join(dir, "fields.json"), raw, 0600); err != nil {
		t.Fatal(err)
	}
}
