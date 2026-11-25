package main

import (
	"encoding/json"
	"math"
	mathrand "math/rand/v2"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"
)

func TestChargedBeamAndMassResistance(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "A", 1)
	q := testPlayer(w, "B", 95)
	_ = w.startBattle(p, "pvp", 1, q, 1000)
	b := w.Battles[p.Battle]
	b.Fighters[0].Pos = Vec{100, 200}
	b.Fighters[1].Pos = Vec{220, 200}
	hp := b.Fighters[1].HP
	if err := b.shoot(0, Vec{220, 200}, 1000, true); err != nil {
		t.Fatal(err)
	}
	b.tickBeams(1000.5)
	if b.Fighters[1].HP != hp {
		t.Fatal("beam damaged before charge")
	}
	b.tickBeams(1001.2)
	if b.Fighters[1].HP >= hp {
		t.Fatal("beam failed to hit")
	}
	hp = b.Fighters[1].HP
	b.tickBeams(1001.3)
	if b.Fighters[1].HP != hp {
		t.Fatal("beam damage duplicated per frame")
	}
}

func TestStoryGardenAndAreaGates(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "A", 1)
	if w.action(p, Command{Type: "travel", Area: "mina"}, 1001) == nil {
		t.Fatal("locked area accessible")
	}
	_ = w.action(p, Command{Type: "travel", Area: "vila"}, 1002)
	_ = w.action(p, Command{Type: "talk", Value: "Íris"}, 1003)
	if err := w.action(p, Command{Type: "quest"}, 1004); err != nil {
		t.Fatal(err)
	}
	if err := w.action(p, Command{Type: "travel", Area: "rota"}, 1005); err != nil {
		t.Fatal(err)
	}
	_ = w.action(p, Command{Type: "travel", Area: "jardim"}, 1006)
	_ = w.action(p, Command{Type: "plant", Index: 0}, 1007)
	_ = w.action(p, Command{Type: "water", Index: 0}, 1008)
	if w.action(p, Command{Type: "harvest", Index: 0}, 1009) == nil {
		t.Fatal("instant harvest")
	}
	if err := w.action(p, Command{Type: "harvest", Index: 0}, 1100); err != nil || p.Berries != 3 {
		t.Fatal("garden cycle failed")
	}
	if w.action(p, Command{Type: "harvest", Index: 0}, 1101) == nil {
		t.Fatal("duplicate harvest")
	}
}

func TestMultiplayerQueueChatAndSpectatorOverTCP(t *testing.T) {
	world := newWorld()
	a, b, viewer := testPlayer(world, "Alice", 1), testPlayer(world, "Bruno", 7), testPlayer(world, "Clara", 4)
	for _, p := range []*Player{a, b, viewer} {
		p.Area = "ginasio"
		p.Quest = 3
		world.Sessions[p.ID] = p.ID
	}
	server := &Server{world: world, path: filepath.Join(t.TempDir(), "world.json")}
	httpServer := httptest.NewServer(server)
	defer httpServer.Close()
	call := func(p *Player, body string) map[string]any {
		t.Helper()
		time.Sleep(100 * time.Millisecond)
		req, _ := http.NewRequest("POST", httpServer.URL+"/api", strings.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+p.ID)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		var out map[string]any
		if err = json.NewDecoder(resp.Body).Decode(&out); err != nil {
			t.Fatal(err)
		}
		if out["error"] != nil {
			t.Fatal(out["error"])
		}
		return out
	}
	call(a, `{"type":"chat","text":"Vamos duelar?"}`)
	call(a, `{"type":"queue"}`)
	out := call(b, `{"type":"queue"}`)
	if out["battle"].(map[string]any)["kind"] != "pvp" {
		t.Fatal("no shared PvP")
	}
	spectator := call(viewer, `{"type":"poll"}`)
	if len(spectator["battles"].([]any)) != 1 || len(spectator["chat"].([]any)) != 1 {
		t.Fatal("spectator or lobby snapshot absent")
	}
	if a.Battle == "" || a.Battle != b.Battle {
		t.Fatal("players did not share match")
	}
}

func TestIndigoCharacterCatalogValidation(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Criador", 1)
	look := map[string]string{"gender": "f", "hair": "girl3", "top": "hoodie", "bottom": "jeans", "hat": "cat", "bag": "sporty", "acc": "glasses"}
	if err := setAppearance(p, look, map[string]string{"top": "#aacc33"}); err != nil {
		t.Fatal(err)
	}
	if p.Look["hair"] != "girl3" {
		t.Fatal("appearance not saved")
	}
	bad := map[string]string{"gender": "m", "hair": "invented", "top": "hoodie", "bottom": "jeans"}
	if setAppearance(p, bad, nil) == nil {
		t.Fatal("accepted nonexistent Indigo asset")
	}
}

func testPlayer(w *World, name string, s int) *Player {
	p := newPlayer(name, s, 1000)
	w.Players[p.ID] = p
	return p
}
func TestRecessiveInheritance(t *testing.T) {
	a, b := newMon(133), newMon(133)
	carrier := Locus{{0, 2}, {1, 1}}
	a.Genes.Loci["mark"] = carrier
	b.Genes.Loci["mark"] = carrier
	r := mathrand.New(mathrand.NewPCG(1, 2))
	n := 0
	for i := 0; i < 10000; i++ {
		g := inherit(a, b, r.Float64)
		if expressed(g.Loci["mark"]) == 1 {
			n++
		}
		for _, key := range geneKeys {
			child := g.Loci[key]
			if child[0] != a.Genes.Loci[key][0] && child[0] != a.Genes.Loci[key][1] {
				t.Fatal("maternal allele invented")
			}
			if child[1] != b.Genes.Loci[key][0] && child[1] != b.Genes.Loci[key][1] {
				t.Fatal("paternal allele invented")
			}
		}
	}
	if n < 2300 || n > 2700 {
		t.Fatalf("expected about 25%%, got %d", n)
	}
}
func TestPigmentBlendingAndHiddenAlleles(t *testing.T) {
	if got := pigment(Locus{{1, 2}, {2, 2}}); got != "#ea8b47" {
		t.Fatalf("red + yellow: %s", got)
	}
	if got := pigment(Locus{{1, 2}, {3, 2}}); got != "#965d8d" {
		t.Fatalf("red + blue: %s", got)
	}
	if got := pigment(Locus{{1, 3}, {3, 1}}); got != pigment(Locus{{1, 3}, {1, 3}}) {
		t.Fatal("recessive color should remain hidden")
	}
}
func TestBreedKeepsPedigreeAndIVs(t *testing.T) {
	a, b := newMon(133), newMon(133)
	a.Sex = "F"
	b.Sex = "M"
	a.IV = [6]int{31, 31, 31, 31, 31, 31}
	b.IV = a.IV
	r := mathrand.New(mathrand.NewPCG(4, 5))
	c := breedMon(a, b, r.Float64)
	inherited := 0
	for _, v := range c.IV {
		if v < 0 || v > 31 {
			t.Fatal("IV out of range")
		}
		if v == 31 {
			inherited++
		}
	}
	if inherited < 3 || c.Genes.Generation != 1 || c.Genes.Parents != [2]string{a.ID, b.ID} {
		t.Fatal("heritage lost")
	}
}
func TestEvolvePreservesGenomeHealthAndAffinity(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Íris", 1)
	p.Mons[0].Level = 16
	p.Mons[0].Affinity = 80
	if err := w.startBattle(p, "gym", 1, nil, 1000); err != nil {
		t.Fatal(err)
	}
	b := w.Battles[p.Battle]
	f := b.Fighters[0]
	f.HP = f.MaxHP * .23
	before := p.Mons[0]
	if err := w.evolve(p, before.ID, "", 1040); err != nil {
		t.Fatal(err)
	}
	after := p.Mons[0]
	if after.Species != 2 || !reflect.DeepEqual(before.Genes, after.Genes) || before.IV != after.IV || after.Affinity != 80 {
		t.Fatal("evolution rerolled identity")
	}
	if math.Abs(b.Fighters[0].HP/b.Fighters[0].MaxHP-.23) > .001 {
		t.Fatal("evolution healed the Pokémon")
	}
}
func TestIntenseEvolutionRequiresBondAndChallenge(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Lia", 4)
	p.Mons[0].Level = 14
	p.Mons[0].Affinity = 80
	_ = w.startBattle(p, "capture", 19, nil, 1000)
	b := w.Battles[p.Battle]
	f := b.Fighters[0]
	f.HP = f.MaxHP * .2
	f.Damage = f.MaxHP * .6
	if err := w.evolve(p, p.Mons[0].ID, "", 1010); err == nil {
		t.Fatal("too early")
	}
	if err := w.evolve(p, p.Mons[0].ID, "", 1040); err != nil {
		t.Fatal(err)
	}
}
func TestFoodAffectsOnlyEvolutionFamily(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Theo", 129)
	p.Mons = append(p.Mons, newMon(130), newMon(7))
	ids := []string{p.Mons[0].ID, p.Mons[1].ID, p.Mons[2].ID}
	if err := w.eat(p, "iguaria", 1000); err != nil {
		t.Fatal(err)
	}
	if len(p.Mons) != 3 || p.Mons[0].Affinity != 35 || p.Mons[1].Affinity != 35 || p.Mons[2].Affinity != 50 {
		t.Fatal("incorrect affinity family")
	}
	for i, id := range ids {
		if p.Mons[i].ID != id {
			t.Fatal("food consumed a party member")
		}
	}
	p.Berries = 5
	_ = w.eat(p, "salada", 1001)
	if p.Meal != "salada" || p.MealUntil != 1301 {
		t.Fatal("food buffs should replace, not stack")
	}
}
func TestCaptureManualOnlyAndNoTrainerTheft(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "A", 1)
	q := testPlayer(w, "B", 4)
	_ = w.startBattle(p, "pvp", 1, q, 1000)
	if w.action(p, Command{Type: "ball"}, 1002) == nil {
		t.Fatal("captured trainer Pokémon")
	}
	w.endBattle(w.Battles[p.Battle], q.ID, 1003)
	p.Auto = true
	_ = w.startBattle(p, "capture", 16, nil, 1004)
	if w.Battles[p.Battle].Fighters[0].Auto {
		t.Fatal("capture started in auto")
	}
	if w.action(p, Command{Type: "auto"}, 1005) == nil {
		t.Fatal("auto capture allowed")
	}
}
func TestMarketSingleTransferAndConservation(t *testing.T) {
	w := newWorld()
	seller := testPlayer(w, "Criador", 1)
	buyer := testPlayer(w, "Comprador", 4)
	extra := newMon(133)
	seller.Mons = append(seller.Mons, extra)
	if err := w.action(seller, Command{Type: "list", IDs: []string{extra.ID}, Index: 100}, 1001); err != nil {
		t.Fatal(err)
	}
	l := w.Market[0]
	if seller.mon(extra.ID) != nil {
		t.Fatal("listed mon remains usable")
	}
	if err := w.action(buyer, Command{Type: "purchase", Value: l.ID}, 1002); err != nil {
		t.Fatal(err)
	}
	if err := w.action(buyer, Command{Type: "purchase", Value: l.ID}, 1003); err == nil {
		t.Fatal("duplicate purchase")
	}
	if seller.Coins+buyer.Coins != 600 || !reflect.DeepEqual(*buyer.mon(extra.ID), extra) {
		t.Fatal("money or genes lost")
	}
}
func TestConcurrentMarketAPI(t *testing.T) {
	w := newWorld()
	seller := testPlayer(w, "Criador", 1)
	extra := newMon(133)
	seller.Mons = append(seller.Mons, extra)
	_ = w.action(seller, Command{Type: "list", IDs: []string{extra.ID}, Index: 100}, 1001)
	id := w.Market[0].ID
	s := &Server{world: w, path: filepath.Join(t.TempDir(), "world.json")}
	var wg sync.WaitGroup
	keys := []string{}
	for i := 0; i < 2; i++ {
		p := testPlayer(w, "Comprador", 4)
		key := uid()
		w.Sessions[key] = p.ID
		keys = append(keys, key)
	}
	for _, key := range keys {
		wg.Add(1)
		go func(k string) {
			defer wg.Done()
			r := httptest.NewRequest("POST", "/api", strings.NewReader(`{"type":"purchase","value":"`+id+`"}`))
			r.Header.Set("Authorization", "Bearer "+k)
			s.ServeHTTP(httptest.NewRecorder(), r)
		}(key)
	}
	wg.Wait()
	count := 0
	for _, p := range w.Players {
		if p.mon(extra.ID) != nil {
			count++
		}
	}
	if count != 1 {
		t.Fatalf("sold to %d owners", count)
	}
}
func TestPersistenceAndAuthPrivacy(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Tester", 7)
	w.Sessions["secret-token"] = p.ID
	s := &Server{world: w, path: filepath.Join(t.TempDir(), "world.json")}
	if err := s.saveLocked(); err != nil {
		t.Fatal(err)
	}
	restored, err := load(s.path)
	if err != nil || restored.Players[p.ID].Mons[0].ID != p.Mons[0].ID {
		t.Fatal("persistence failed")
	}
	r := httptest.NewRequest("POST", "/api", strings.NewReader(`{"type":"poll"}`))
	rec := httptest.NewRecorder()
	s.ServeHTTP(rec, r)
	if rec.Code != 401 {
		t.Fatal("unauthenticated access")
	}
	payload, _ := json.Marshal(s.snapshot(p, 1000))
	if strings.Contains(string(payload), "secret-token") {
		t.Fatal("snapshot leaked session token")
	}
}
func TestEVLimitsAndServerMovement(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Tester", 1)
	p.Mons[0].EV = [6]int{252, 0, 0, 0, 0, 250}
	p.Training = &Training{IDs: p.Team, Route: "rota", At: 1000}
	w.tick(.05, 20000)
	if p.Mons[0].EV[5] != 252 {
		t.Fatal("EV cap")
	}
	before := p.Pos
	p.Seen = 20000
	_ = w.action(p, Command{Type: "input", Move: Vec{100000, 0}}, 20000)
	w.tick(.05, 20000.05)
	if distance(before, p.Pos) > 4.01 {
		t.Fatal("client moved faster than server limit")
	}
}
func TestProjectileCollisionAndDodge(t *testing.T) {
	for _, dodge := range []bool{false, true} {
		w := newWorld()
		p := testPlayer(w, "A", 1)
		q := testPlayer(w, "B", 4)
		_ = w.startBattle(p, "pvp", 1, q, 1000)
		b := w.Battles[p.Battle]
		b.Fighters[0].Pos = Vec{100, 200}
		b.Fighters[1].Pos = Vec{150, 200}
		hp := b.Fighters[1].HP
		_ = b.shoot(0, Vec{150, 200}, 1000, false)
		if dodge {
			b.Fighters[1].Pos.Y = 270
		}
		for i := 1; i < 12; i++ {
			w.tick(.05, 1000+float64(i)*.05)
		}
		if dodge && b.Fighters[1].HP != hp {
			t.Fatal("missed projectile did damage")
		}
		if !dodge && b.Fighters[1].HP >= hp {
			t.Fatal("projectile did not collide")
		}
	}
}
func TestDashIsImmediateFiniteAndHasFeedbackState(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Dash", 1)
	_ = w.startBattle(p, "capture", 25, nil, 1000)
	b := w.Battles[p.Battle]
	f := b.Fighters[0]
	before := f.Pos
	p.Input = Vec{1, 0}
	if err := w.action(p, Command{Type: "dash"}, 1000.2); err != nil {
		t.Fatal(err)
	}
	if f.Pos.X <= before.X || f.Pos.X-before.X > 62.01 || f.Invincible != 1000.5 || f.Energy >= 100 || f.DashAt != 1002.2 {
		t.Fatalf("dash state is not immediately observable: %+v", f)
	}
	if err := w.action(p, Command{Type: "dash"}, 1000.4); err == nil {
		t.Fatal("dash ignored cooldown")
	}
}
func TestMassChangesRadiusAndAcceleration(t *testing.T) {
	small, big := newMon(16), newMon(95)
	if physique(small).Mass >= physique(big).Mass || physique(small).Radius >= physique(big).Radius {
		t.Fatal("size has no physical difference")
	}
}
func TestFishingTiming(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Pesca", 7)
	p.Area = "lago"
	if err := w.fish(p, 1000); err != nil {
		t.Fatal(err)
	}
	if w.fish(p, 1000.1) == nil {
		t.Fatal("early reel succeeded")
	}
	_ = w.fish(p, 1001)
	if err := w.fish(p, p.Fishing+.2); err != nil || p.Battle == "" {
		t.Fatal("timed fishing did not open manual capture")
	}
}
func TestTrainerCutins(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Íris", 1)
	p.Balls = 3
	if err := w.startBattle(p, "gym", 1, nil, 1000); err != nil {
		t.Fatal(err)
	}
	b := w.Battles[p.Battle]
	if len(b.Cutins) != 2 || b.Cutins[0].Kind != "switch" || b.Cutins[1].Side != 1 || b.Fighters[1].Art == "" {
		t.Fatalf("gym should open with both trainers sending out: %+v", b.Cutins)
	}
	if err := w.action(p, Command{Type: "special"}, 1005); err != nil {
		t.Fatal(err)
	}
	last := b.Cutins[len(b.Cutins)-1]
	if last.Kind != "special" || last.Side != 0 {
		t.Fatalf("special command should show the trainer: %+v", last)
	}
	w.endBattle(b, p.ID, 1006)
	_ = w.startBattle(p, "capture", 16, nil, 1010)
	b = w.Battles[p.Battle]
	_ = w.action(p, Command{Type: "ball"}, 1011)
	if last := b.Cutins[len(b.Cutins)-1]; last.Kind != "ball" {
		t.Fatalf("ball throw should show the trainer: %+v", last)
	}
}

func TestGymBadgesAndJourney(t *testing.T) {
	w := newWorld()
	p := testPlayer(w, "Insígnias", 1)
	p.Area = "kt_pewter_city_gym"
	if err := w.action(p, Command{Type: "gym"}, 1000); err != nil {
		t.Fatal(err)
	}
	b := w.Battles[p.Battle]
	if b.Gym != "kanto_1" || b.Fighters[1].Name != "Brock" || b.Fighters[1].Mon.Level != 14 || b.Fighters[1].Art != "in_brock" {
		t.Fatalf("ginásio errado: %+v", b.Fighters[1])
	}
	if g := gymAt("sn_hearthome_city_gym_trainer_room_1"); g == nil || g.Leader != "Fantina" {
		t.Fatalf("salas do ginásio devem levar à líder: %+v", g)
	}
	w.endBattle(b, p.ID, 1001)
	if !p.Badges["kanto_1"] {
		t.Fatalf("vitória deveria dar a insígnia: %v / %s", p.Badges, p.Notice)
	}
	var kanto map[string]any
	for _, r := range regionStatus(p) {
		if r["id"] == "kanto" {
			kanto = r
		}
	}
	badges := kanto["badges"].([]map[string]any)
	if len(badges) != 8 || badges[0]["done"] != true || kanto["areas"].(int) < 50 {
		t.Fatalf("painel de Kanto incompleto: %v", kanto)
	}
}
