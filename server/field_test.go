package main

import "testing"

func TestFieldLayoutsAreValid(t *testing.T) {
	for theme, rows := range fieldLayouts {
		for r, row := range rows {
			if len(row) != fieldCols {
				t.Errorf("%s linha %d tem %d casas", theme, r, len(row))
			}
		}
		fl := newField(theme)
		for _, spawn := range []Vec{{100, 230}, {410, 200}} {
			if c := fl.at(spawn); c == 'r' || c == 'l' || c == 'x' || c == 'w' {
				t.Errorf("%s: início em casa ruim %q", theme, c)
			}
		}
	}
	for _, g := range gyms {
		if _, ok := fieldLayouts[gymTheme[g.ID]]; !ok {
			t.Errorf("ginásio %s sem campo", g.ID)
		}
	}
}

func gymBattle(t *testing.T, area string, s int) (*World, *Player, *Battle) {
	w := newWorld()
	p := testPlayer(w, "Estádio", s)
	p.Area, p.Seen = area, 1000
	if err := w.action(p, Command{Type: "gym"}, 1000); err != nil {
		t.Fatal(err)
	}
	b := w.Battles[p.Battle]
	if b.Field == nil {
		t.Fatal("ginásio deveria ter campo")
	}
	return w, p, b
}

func TestMistyWaterSlowsLandMonsNotSwimmers(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cerulean_city_gym", 4)
	if b.Field.Theme != "agua" {
		t.Fatalf("Misty deveria ter piscina: %s", b.Field.Theme)
	}
	f := b.Fighters[0]
	f.Pos = Vec{256, 280} // linha 5: toda água
	if b.terrainSpeed(f) >= 1 {
		t.Fatal("Charmander na água deveria ficar lento")
	}
	b.tickTerrain(.1, 1000)
	if f.SlowUntil <= 1000 || f.Terrain != "w" {
		t.Fatal("deveria ficar molhado")
	}
	if b.terrainPower(f) >= 1 {
		t.Fatal("deveria perder força na água")
	}
	f.Mon = newMon(131) // Lapras nada
	f.SlowUntil = 0
	if b.terrainSpeed(f) <= 1 {
		t.Fatal("Lapras deveria nadar mais rápido")
	}
	b.tickTerrain(.1, 1000)
	if f.SlowUntil > 1000 {
		t.Fatal("aquático não sofre debuff na água")
	}
	f.Mon = newMon(16) // Pidgey voa por cima
	if b.terrainSpeed(f) != 1 {
		t.Fatal("voador ignora a água")
	}
}

func TestMovesReshapeTheField(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cerulean_city_gym", 4)
	fl := b.Field
	water := Vec{256, 280}
	i := fl.index(water)
	b.shapeField(water, 30, "Gelo", 1000)
	if fl.Cells[i] != 'i' {
		t.Fatalf("gelo deveria congelar a água: %q", fl.Cells[i])
	}
	b.shapeField(water, 30, "Fogo", 1001)
	if fl.Cells[i] != 'w' {
		t.Fatalf("fogo deveria derreter o gelo: %q", fl.Cells[i])
	}
	b.shapeField(water, 20, "Elétrico", 1002)
	if fl.Cells[i] != 'z' {
		t.Fatalf("choque deveria eletrificar a água: %q", fl.Cells[i])
	}
	fl.tick(1010)
	if fl.Cells[i] != 'w' {
		t.Fatalf("a descarga passa: %q", fl.Cells[i])
	}

	_, _, b = gymBattle(t, "kt_cinnabar_island_gym", 1)
	lava := b.Field.center(0)
	b.shapeField(lava, 20, "Água", 1000)
	if b.Field.Cells[0] != 's' {
		t.Fatalf("água deveria apagar a lava: %q", b.Field.Cells[0])
	}

	_, _, b = gymBattle(t, "kt_celadon_city_gym", 4)
	grass := b.Field.center(0)
	b.shapeField(grass, 20, "Fogo", 1000)
	if b.Field.Cells[0] != 'f' {
		t.Fatalf("fogo deveria queimar a grama: %q", b.Field.Cells[0])
	}
	b.Field.tick(1010)
	if b.Field.Cells[0] != '.' {
		t.Fatalf("grama queimada vira chão: %q", b.Field.Cells[0])
	}
}

func TestRocksBlockMovementAndShots(t *testing.T) {
	_, _, b := gymBattle(t, "kt_pewter_city_gym", 4)
	rock := -1
	for i, c := range b.Field.Cells {
		if c == 'r' {
			rock = i
			break
		}
	}
	f := b.Fighters[0]
	c := b.Field.center(rock)
	start := f.Pos
	f.Pos = Vec{c.X - 30, c.Y}
	if b.Field.at(f.Pos) == 'r' {
		f.Pos = start
	}
	before := f.Pos
	b.step(f, c)
	if b.Field.at(f.Pos) == 'r' || f.Pos != before {
		t.Fatal("pedra deveria bloquear")
	}
}

func TestMistyAIClimbsBackOnPlatform(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cerulean_city_gym", 4)
	foe := b.Fighters[1]
	foe.Mon = newMon(4) // um lutador terrestre caído na água
	foe.Pos = Vec{256, 280}
	for k := 0; k < 120 && b.cellCost(foe, foe.Pos) >= 3; k++ {
		if safe, ok := b.safeCell(foe); ok {
			b.autoStep(foe, safe.Add(foe.Pos.Mul(-1)), 4)
		}
	}
	if b.cellCost(foe, foe.Pos) >= 3 {
		t.Fatalf("IA deveria sair da água: %v %q", foe.Pos, b.Field.at(foe.Pos))
	}
}
