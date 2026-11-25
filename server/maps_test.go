package main

import "testing"

func TestMapsWarpBetweenAreas(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "A", 1)
	p.Quest = 3
	p.Area = "vila"
	m := areaMaps["vila"]
	if m == nil || areaMaps["rota"] == nil {
		t.Fatal("mapas não carregados")
	}
	// Anda para o norte pela trilha até sair na rota.
	p.Pos = Vec{18 * 32, 3 * 32}
	for i := 0; i < 80 && p.Area == "vila"; i++ {
		p.Input = Vec{0, -1}
		p.InputAt = 1000 + float64(i)*.05
		w.tick(.05, 1000+float64(i)*.05)
	}
	if p.Area != "rota" {
		t.Fatalf("não chegou à rota: %s %v", p.Area, p.Pos)
	}
	if areaMaps["rota"].at(p.Pos) == '#' {
		t.Fatal("chegou dentro de uma parede")
	}
}

func TestMapsBlockTreesAndLockedAreas(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "A", 1)
	p.Area = "vila"
	p.Quest = 0
	p.Pos = Vec{18 * 32, 3 * 32}
	for i := 0; i < 80; i++ {
		p.Input = Vec{0, -1}
		p.InputAt = 1000 + float64(i)*.05
		w.tick(.05, 1000+float64(i)*.05)
	}
	if p.Area != "vila" {
		t.Fatal("rota deveria estar bloqueada antes da missão")
	}
	m := areaMaps["vila"]
	if !m.solid(Vec{16, 16}, Vec{}) {
		t.Fatal("árvore do canto deveria bloquear")
	}
}
