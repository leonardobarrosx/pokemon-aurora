package main

import (
	"math"
	"testing"
)

func TestEveryGymHasABigConnectedArena(t *testing.T) {
	for _, g := range gyms {
		a, ok := arenas[g.ID]
		if !ok {
			t.Errorf("%s sem arena", g.ID)
			continue
		}
		fl := newField(g.ID, 0)
		if fl.size().X <= 512 || fl.size().Y <= 384 {
			t.Errorf("%s: arena deveria ser maior que a tela: %v", g.ID, fl.size())
		}
		land := &Fighter{Mon: newMon(4)}
		land.Physique = physique(land.Mon)
		for _, s := range fl.Spawn {
			if blockedCell(land, fl.at(s)) || terrainOf(fl.at(s)).Swim || terrainOf(fl.at(s)).Damage > 0 {
				t.Errorf("%s: início em casa ruim %q", g.ID, fl.at(s))
			}
		}
		// Caminho por terra entre os dois Pokémon.
		start, goal := fl.index(fl.Spawn[0]), fl.index(fl.Spawn[1])
		seen := map[int]bool{start: true}
		queue := []int{start}
		for len(queue) > 0 {
			i := queue[0]
			queue = queue[1:]
			for _, d := range []int{1, -1, a.W, -a.W} {
				j := i + d
				if j < 0 || j >= len(fl.Cells) || seen[j] {
					continue
				}
				c := fl.Cells[j]
				if blockedCell(land, c) || terrainOf(c).Swim || c == 'l' {
					continue
				}
				seen[j] = true
				queue = append(queue, j)
			}
		}
		if !seen[goal] {
			t.Errorf("%s: sem caminho por terra entre os Pokémon", g.ID)
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
		t.Fatal("ginásio deveria ter arena")
	}
	return w, p, b
}

func findCell(fl *Field, c byte) Vec {
	for i := range fl.Cells {
		if fl.Cells[i] == c {
			return fl.center(i)
		}
	}
	return Vec{}
}

func TestMistyPoolSlowsLandMonsNotSwimmers(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cerulean_city_gym", 4)
	f := b.Fighters[0]
	f.Pos = findCell(b.Field, 'W')
	if b.terrainSpeed(f) >= .6 {
		t.Fatal("Charmander na água funda deveria ficar bem lento")
	}
	b.tickTerrain(.05, 1000)
	if f.SlowUntil <= 1000 || f.Terrain != "W" || b.terrainPower(f) >= 1 {
		t.Fatal("deveria ficar molhado e mais fraco")
	}
	f.Mon, f.SlowUntil = newMon(131), 0 // Lapras
	if b.terrainSpeed(f) <= 1 {
		t.Fatal("Lapras deveria nadar mais rápido")
	}
	b.tickTerrain(.05, 1000)
	if f.SlowUntil > 1000 {
		t.Fatal("aquático não sofre debuff")
	}
	f.Mon = newMon(16)
	if b.terrainSpeed(f) != 1 {
		t.Fatal("voador passa por cima")
	}
	// A correnteza leva quem está nela.
	f.Mon = newMon(4)
	f.Pos = findCell(b.Field, '>')
	x := f.Pos.X
	b.tickFighterTerrain(f, .2, 1000)
	if f.Pos.X <= x {
		t.Fatal("correnteza deveria empurrar")
	}
}

func TestMovesReshapeTheArena(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cerulean_city_gym", 4)
	fl := b.Field
	water := findCell(fl, 'W')
	i := fl.index(water)
	b.shapeField(water, 20, "Gelo", 0, 1000)
	if fl.Cells[i] != 'i' {
		t.Fatalf("gelo deveria congelar a água: %q", fl.Cells[i])
	}
	b.shapeField(water, 20, "Fogo", 0, 1001)
	if fl.Cells[i] != 'w' {
		t.Fatalf("fogo deveria derreter o gelo: %q", fl.Cells[i])
	}
	b.shapeField(water, 20, "Elétrico", 0, 1002)
	shock := false
	for _, e := range fl.Events {
		shock = shock || (e.Kind == "shock" && e.At > 1002) // com aviso antes
	}
	if !shock {
		t.Fatal("choque na água deveria eletrificar a área, com aviso")
	}
	f := b.Fighters[0]
	f.Pos = water
	hp := f.HP
	b.tickEvents(.5, 1003)
	if f.HP >= hp {
		t.Fatal("quem está na água eletrificada leva dano")
	}

	_, _, b = gymBattle(t, "kt_cinnabar_island_gym", 1)
	lava := findCell(b.Field, 'l')
	b.shapeField(lava, 20, "Água", 0, 1000)
	if b.Field.at(lava) != 's' {
		t.Fatalf("água deveria apagar a lava: %q", b.Field.at(lava))
	}

	_, _, b = gymBattle(t, "kt_celadon_city_gym", 4)
	grass := findCell(b.Field, 'g')
	b.shapeField(grass, 20, "Fogo", 0, 1000)
	if b.Field.at(grass) != 'f' {
		t.Fatalf("fogo deveria queimar a grama: %q", b.Field.at(grass))
	}
	b.tickTerrain(.05, 1010)
	if b.Field.at(grass) != '.' {
		t.Fatalf("grama queimada vira chão: %q", b.Field.at(grass))
	}
}

func TestQuarryRocksAreCoverAndBreak(t *testing.T) {
	_, _, b := gymBattle(t, "kt_pewter_city_gym", 4)
	fl := b.Field
	// Uma rocha com chão livre de pelo menos um lado (os grupos de rochas
	// podem ter vizinhas dos dois lados).
	rock := Vec{}
	for i := range fl.Cells {
		if fl.Cells[i] == 'r' && i%fl.Cols > 2 && i%fl.Cols < fl.Cols-3 &&
			(!terrainOf(fl.Cells[i-1]).Solid && !terrainOf(fl.Cells[i-2]).Solid ||
				!terrainOf(fl.Cells[i+1]).Solid && !terrainOf(fl.Cells[i+2]).Solid) {
			rock = fl.center(i)
			break
		}
	}
	f := b.Fighters[0]
	f.Pos = rock.Add(Vec{-40, 0})
	if b.solid(f, f.Pos) {
		f.Pos = rock.Add(Vec{40, 0})
	}
	before := f.Pos
	b.step(f, rock)
	if b.Field.at(f.Pos) == 'r' || distance(f.Pos, rock) < 10 {
		t.Fatalf("pedra deveria bloquear: %v -> %v", before, f.Pos)
	}
	if _, hit := b.shotBlocked(rock); !hit {
		t.Fatal("pedra deveria segurar disparos")
	}
	i := fl.index(rock)
	b.damageObstacle(i, "Normal", 40, 1000)
	if fl.Cells[i] != 'q' {
		t.Fatalf("pedra deveria rachar: %q", fl.Cells[i])
	}
	b.damageObstacle(i, "Lutador", 40, 1000)
	if terrainOf(fl.Cells[i]).Solid {
		t.Fatalf("pedra deveria quebrar: %q", fl.Cells[i])
	}
}

func TestOnixSizeAndWeightMatter(t *testing.T) {
	_, _, b := gymBattle(t, "kt_pewter_city_gym", 4)
	onix := &Fighter{Mon: newMon(95)}
	onix.Physique = physique(onix.Mon)
	small := &Fighter{Mon: newMon(19)}
	small.Physique = physique(small.Mon)
	if bodyRadius(onix) <= bodyRadius(small)*1.2 {
		t.Fatal("Onix deveria ocupar mais espaço")
	}
	// Um corredor de uma casa: o Rattata passa, o Onix não.
	fl := b.Field
	gap := Vec{}
	for i := range fl.Cells {
		c := fl.center(i)
		if fl.Cells[i] != 's' {
			continue
		}
		l, r := fl.at(c.Add(Vec{-fieldCell, 0})), fl.at(c.Add(Vec{fieldCell, 0}))
		if terrainOf(l).Solid && terrainOf(r).Solid {
			gap = c
			break
		}
	}
	if gap != (Vec{}) && (b.solid(small, gap) || !b.solid(onix, gap)) {
		t.Fatal("só o Pokémon pequeno passa no corredor estreito")
	}
	// Investida do Onix quebra a pedra da frente.
	rock := findCell(fl, 'r')
	onix.Pos = rock.Add(Vec{-(bodyRadius(onix) + 20), 0})
	b.ram(onix, Vec{1, 0}, 80, 1000)
	if fl.at(rock) == 'r' {
		t.Fatal("Onix deveria rachar a pedra na investida")
	}
	// Gelo cede sob o peso.
	_, _, b = gymBattle(t, "jt_mahogany_gym_leader_room", 4)
	ice := findCell(b.Field, 'i')
	onix.Pos = ice
	b.Fighters[0] = onix
	for k := 0; k < 80 && b.Field.at(ice) == 'i'; k++ {
		b.tickFighterTerrain(onix, .05, 1000+float64(k)*.05)
	}
	if b.Field.at(ice) == 'i' {
		t.Fatal("gelo deveria rachar sob o Onix")
	}
	if b.grip(onix) >= b.grip(small) && terrainOf(b.Field.at(ice)).Slippery {
		t.Fatal("pesado derrapa mais")
	}
}

func TestTallGrassHidesSmallMons(t *testing.T) {
	_, _, b := gymBattle(t, "kt_celadon_city_gym", 4)
	f := b.Fighters[0]
	f.Pos = findCell(b.Field, 'g')
	b.tickFighterTerrain(f, .05, 1000)
	if !f.Hidden {
		t.Fatal("Charmander deveria se esconder na grama alta")
	}
	if distance(b.aimAt(f, 1000), f.Pos) < 30 {
		t.Fatal("a IA deveria errar a mira em quem está escondido")
	}
}

func TestArenaMachinesWarnBeforeActing(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cinnabar_island_gym", 4)
	fl := b.Field
	var vent int
	for i, c := range []byte(fl.Cells) {
		if c == 'V' {
			vent = i
			break
		}
	}
	next := fl.Next[vent]
	b.tickMachines(next - .99)
	warned := false
	for _, e := range fl.Events {
		if e.Kind == "geyser" && distance(e.Pos, fl.center(vent)) < 1 && e.At > next-.99 {
			warned = true
		}
	}
	if !warned {
		t.Fatal("gêiser deveria avisar antes de explodir")
	}

	_, _, b = gymBattle(t, "kt_cerulean_city_gym", 4)
	fl = b.Field
	plat := fl.index(findCell(fl, 'k'))
	at := fl.Next[plat]
	b.tickMachines(at - .5)
	b.tickEvents(0, at+.5)
	if fl.Cells[plat] != '_' {
		t.Fatalf("plataforma frágil deveria afundar: %q", fl.Cells[plat])
	}
	b.tickTerrain(0, at+5)
	if fl.Cells[plat] != 'k' {
		t.Fatalf("e depois voltar: %q", fl.Cells[plat])
	}
}

func TestAIClimbsBackOnPlatform(t *testing.T) {
	_, _, b := gymBattle(t, "kt_cerulean_city_gym", 4)
	foe := b.Fighters[1]
	foe.Mon = newMon(4)
	foe.Physique = physique(foe.Mon)
	foe.Pos = findCell(b.Field, 'W')
	for k := 0; k < 300 && b.cellCost(foe, foe.Pos) >= 3; k++ {
		if safe, ok := b.safeCell(foe); ok {
			b.autoStep(foe, safe.Add(foe.Pos.Mul(-1)), 4)
		}
	}
	if b.cellCost(foe, foe.Pos) >= 3 {
		t.Fatalf("IA deveria sair da água: %v %q", foe.Pos, b.Field.at(foe.Pos))
	}
	_ = math.Pi
}
