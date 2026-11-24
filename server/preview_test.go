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
}
