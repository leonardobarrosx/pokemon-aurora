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

func TestKantoConnectionsAndDoors(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "A", 1)
	w.enterAt(p, kantoStart, Vec{12.5 * 32, 1.5 * 32}, 900)
	for i := 0; i < 40 && p.Area == kantoStart; i++ {
		p.Input = Vec{0, -1}
		p.InputAt = 1000 + float64(i)*.05
		w.tick(.05, 1000+float64(i)*.05)
	}
	if p.Area != "kt_route1" {
		t.Fatalf("Pallet Town deveria levar à Rota 1, ficou em %s %v", p.Area, p.Pos)
	}
	if p.Pos.Y < float64(areaMaps["kt_route1"].H-2)*32 {
		t.Fatalf("deveria chegar no sul da Rota 1: %v", p.Pos)
	}
	// Porta da casa do jogador em Pallet (6,7) leva para dentro e volta.
	w.enterAt(p, kantoStart, Vec{6.5 * 32, 8.5 * 32}, 2000)
	for i := 0; i < 30 && p.Area == kantoStart; i++ {
		p.Input = Vec{0, -1}
		p.InputAt = 2001 + float64(i)*.05
		w.tick(.05, 2001+float64(i)*.05)
	}
	if !isKanto(p.Area) || p.Area == kantoStart {
		t.Fatalf("porta não levou para dentro: %s", p.Area)
	}
	if err := w.action(p, Command{Type: "travel", Area: "aurora"}, 3000); err != nil {
		t.Fatal(err)
	}
	if p.Area != "vila" {
		t.Fatal("viagem para Aurora falhou")
	}
}
