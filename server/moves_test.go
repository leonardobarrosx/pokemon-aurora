package main

import "testing"

func duel(a, b int) (*World, *Battle) {
	w := newWorld()
	p := testPlayer(w, "A", a)
	q := testPlayer(w, "B", b)
	_ = w.startBattle(p, "pvp", 1, q, 1000)
	bt := w.Battles[p.Battle]
	bt.Fighters[0].Pos = Vec{150, 220}
	bt.Fighters[1].Pos = Vec{200, 220}
	return w, bt
}

func TestEveryFighterHasFourMoves(t *testing.T) {
	for id := range species {
		f := makeFighter(nil, newMon(id), Vec{})
		for k, m := range f.Moves {
			if m.Name == "" {
				t.Fatalf("%s sem golpe %d", species[id].Name, k+1)
			}
		}
	}
}

func TestHeavyTargetsResistKnockback(t *testing.T) {
	push := map[int]float64{}
	for _, target := range []int{25, 95} {
		_, b := duel(74, target)
		b.Fighters[0].Mon.Level, b.Fighters[1].Mon.Level = 20, 20
		start := b.Fighters[1].Pos
		if err := b.useMove(0, 0, b.Fighters[1].Pos, 1000); err != nil {
			t.Fatal(err)
		}
		for i := 0; i < 10; i++ {
			b.tickCharges(.05, 1000+float64(i)*.05)
		}
		push[target] = distance(start, b.Fighters[1].Pos)
	}
	if push[25] <= push[95]*2 {
		t.Fatalf("Pikachu deveria voar mais que Onix: %v", push)
	}
}

func TestSpecialAttackAndLevelGrowMoves(t *testing.T) {
	_, b := duel(4, 1)
	weak := b.Fighters[0]
	weak.Mon.Level, weak.Mon.IV[3] = 5, 0
	_ = b.useMove(0, 1, Vec{300, 220}, 1000)
	small := b.Projectiles[len(b.Projectiles)-1].Radius
	weak.Mon.Level, weak.Mon.IV[3], weak.Mon.EV[3] = 80, 31, 252
	_ = b.useMove(0, 1, Vec{300, 220}, 1010)
	big := b.Projectiles[len(b.Projectiles)-1].Radius
	if big < small*1.4 {
		t.Fatalf("golpe não cresceu: %.1f -> %.1f", small, big)
	}
}

func TestTypeEffectivenessAndMoveCommand(t *testing.T) {
	w, b := duel(25, 7)
	b.tickCharges(0, 1000)
	w.tick(.05, 1000)
	if b.Fighters[0].Eff[1] != 2 {
		t.Fatalf("Thunder Shock contra Squirtle deveria ser 2x, veio %v", b.Fighters[0].Eff[1])
	}
	p := w.Players[b.Fighters[0].Owner]
	p.Aim = b.Fighters[1].Pos
	if err := w.action(p, Command{Type: "move", Index: 2}, 1000.2); err != nil {
		t.Fatal(err)
	}
	if b.Fighters[0].MoveAt[2] <= 1000.2 || len(b.Beams) == 0 {
		t.Fatal("Thunderbolt não saiu pelo comando move")
	}
}
