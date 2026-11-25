package main

import (
	"fmt"
	"math"
	mathrand "math/rand/v2"
	"slices"
	"strings"
	"time"
)

type Command struct {
	Look    map[string]string `json:"look"`
	Colors  map[string]string `json:"colors"`
	Type    string            `json:"type"`
	Token   string            `json:"token"`
	Name    string            `json:"name"`
	Starter int               `json:"starter"`
	Area    string            `json:"area"`
	Text    string            `json:"text"`
	Value   string            `json:"value"`
	IDs     []string          `json:"ids"`
	Index   int               `json:"index"`
	Pos     Vec               `json:"pos"`
	Move    Vec               `json:"move"`
	Aim     Vec               `json:"aim"`
	Fly     bool              `json:"fly"`
	Run     bool              `json:"run"`
}

var areaNeed = map[string]int{"casa": 0, "vila": 0, "jardim": 0, "rota": 1, "mina": 2, "ginasio": 2, "safari": 3, "lago": 3}
var routePool = map[string][]int{"rota": {16, 19, 25, 133}, "mina": {74, 41, 95}, "lago": {7, 129, 131}}
var questGoals = []string{"talk", "capture", "harvest", "mine", "gym"}

func errMsg(s string) error { return fmt.Errorf("%s", s) }
func (w *World) action(p *Player, c Command, now float64) error {
	if c.Type == "input" {
		if !finite(c.Move.X) || !finite(c.Move.Y) || !finite(c.Aim.X) || !finite(c.Aim.Y) {
			return errMsg("entrada inválida")
		}
		p.Input = c.Move
		p.Running = c.Run
		if p.Input.Len() > 1 {
			p.Input = p.Input.Unit()
		}
		p.Aim = c.Aim
		if p.Battle != "" || areaMaps[p.Area] == nil {
			p.Aim = bounds(c.Aim)
		}
		p.InputAt = now
		if c.Move.X < 0 {
			p.Facing = 1
		}
		if c.Move.X > 0 {
			p.Facing = 2
		}
		if c.Move.Y < 0 {
			p.Facing = 3
		}
		if c.Move.Y > 0 {
			p.Facing = 0
		}
		return nil
	}
	if c.Type == "poll" {
		return nil
	}
	if now-p.LastAction < .09 {
		return errMsg("aguarde um instante")
	}
	p.LastAction = now
	if p.Battle != "" && !slices.Contains([]string{"attack", "special", "move", "dash", "ball", "flee", "auto", "evolve"}, c.Type) {
		return errMsg("termine a batalha primeiro")
	}
	if p.Arcade != nil && c.Type != "arcade_stop" {
		return errMsg("termine o minijogo primeiro")
	}
	switch c.Type {
	case "transport":
		if c.Value != "walk" && c.Value != "bike" {
			return errMsg("transporte inválido")
		}
		p.Transport = c.Value
	case "travel":
		// Viagem entre regiões levando a equipe: cada região tem sua chegada
		// (Aurora na vila, Kanto em Pallet Town, Hoenn em Littleroot).
		if start, ok := regionStarts[c.Area]; ok {
			if !regionOpen(p, c.Area) {
				return errMsg("essa região ainda não foi liberada: siga a jornada em ordem")
			}
			c.Area = start
		}
		if !canEnter(p, c.Area) {
			return errMsg("continue a história para liberar essa área")
		}
		if c.Fly {
			fly := false
			for _, m := range p.Mons {
				if species[m.Species].Ride == "Voo" {
					fly = true
				}
			}
			if !fly || !p.Visits[c.Area] {
				return errMsg("Fly exige um parceiro voador e uma visita anterior a pé")
			}
		}
		w.enter(p, c.Area, now)
	case "appearance":
		return setAppearance(p, c.Look, c.Colors)
	case "wardrobe":
		if !slices.Contains([]string{"green", "blue", "purple", "red"}, c.Value) {
			return errMsg("roupa desconhecida")
		}
		if p.Area != "casa" {
			return errMsg("use o guarda-roupa em casa")
		}
		p.Color = c.Value
	case "theme":
		if !slices.Contains([]string{"verde", "azul", "lilas"}, c.Value) {
			return errMsg("tema inválido")
		}
		p.Theme = c.Value
	case "talk":
		if p.Area != "vila" {
			return errMsg("visite a vila")
		}
		switch c.Value {
		case "Íris":
			p.Flags["talk"] = 1
			p.Notice = "Íris: os faróis de Aurora se apagaram. Capture um parceiro e ajude a reacender a região."
		case "Lia":
			p.Notice = "Lia: plante e regue uma berry no seu jardim. A vila vai florescer com você!"
		case "Theo":
			p.Notice = "Theo: traga pedras da mina. Vamos reconstruir os faróis!"
		default:
			return errMsg("morador desconhecido")
		}
	case "gift":
		if p.Area != "vila" || !slices.Contains([]string{"Íris", "Lia", "Theo"}, c.Value) || p.Berries < 1 {
			return errMsg("encontre um morador com uma berry")
		}
		if now-p.Gifts[c.Value] < 3600 {
			return errMsg("um presente por hora para cada morador")
		}
		p.Berries--
		p.Friends[c.Value] += 10
		p.Gifts[c.Value] = now
		p.XP += 10
		p.Notice = c.Value + " adorou o presente! +10 amizade."
	case "quest":
		if p.Quest >= len(questGoals) || p.Flags[questGoals[p.Quest]] < 1 {
			return errMsg("complete o objetivo antes de resgatar")
		}
		p.Coins += 100 + p.Quest*30
		p.XP += 50
		p.Quest++
		p.Notice = "Missão concluída! Novos caminhos se abrem em Aurora."
	case "encounter":
		pool := routePool[p.Area]
		if len(pool) == 0 {
			return errMsg("procure Pokémon nas rotas ou na mina")
		}
		return w.startBattle(p, "capture", pool[mathrand.IntN(len(pool))], nil, now)
	case "gym":
		if p.Area != "ginasio" {
			return errMsg("vá ao ginásio")
		}
		return w.startBattle(p, "gym", 1, nil, now)
	case "attack", "special", "move", "dash", "ball", "flee":
		b := w.Battles[p.Battle]
		if b == nil || b.End > 0 {
			return errMsg("nenhuma batalha ativa")
		}
		i := 0
		if b.Fighters[1].Owner == p.ID {
			i = 1
		}
		f, foe := b.Fighters[i], b.Fighters[1-i]
		switch c.Type {
		case "attack", "special":
			err := b.shoot(i, p.Aim, now, c.Type == "special")
			if err == nil && c.Type == "special" {
				b.cutin(i, "special", f.Moves[3].Name+"!", now)
			}
			return err
		case "move":
			err := b.useMove(i, c.Index, p.Aim, now)
			if err == nil && c.Index == 3 {
				b.cutin(i, "special", f.Moves[3].Name+"!", now)
			}
			return err
		case "dash":
			if now < f.DashAt || f.Energy < 20 {
				return errMsg("esquiva recarregando")
			}
			dir := p.Input
			if dir.Len() < .01 {
				dir = p.Aim.Add(f.Pos.Mul(-1)).Unit()
			}
			f.Pos = bounds(f.Pos.Add(dir.Mul(62 / math.Pow(1+f.Physique.Mass/40, .2))))
			f.Energy -= math.Min(35, 18+f.Physique.Mass/30)
			f.DashAt = now + 2
			f.Invincible = now + .3
		case "flee":
			w.endBattle(b, foe.Owner, now)
		case "ball":
			if (b.Kind != "capture" && b.Kind != "event") || p.Balls < 1 || len(p.Mons) >= 200 {
				return errMsg("captura indisponível")
			}
			if now < f.SpecialAt {
				return errMsg("aguarde antes de lançar outra bola")
			}
			p.Balls--
			f.SpecialAt = now + 1.5
			b.cutin(i, "ball", "Pokébola, vai!", now)
			chance := .15 + (1-foe.HP/foe.MaxHP)*.78
			if mathrand.Float64() < chance {
				p.Mons = append(p.Mons, foe.Mon)
				if len(p.Team) < 6 {
					p.Team = append(p.Team, foe.Mon.ID)
				}
				p.Flags["capture"]++
				p.XP += 20
				p.Battle = ""
				b.End = now
				b.Winner = p.ID
				if b.Kind == "event" {
					p.Event = time.Unix(int64(now), 0).UTC().Format("2006-01-02")
				}
				p.Notice = species[foe.Mon.Species].Name + " capturado!"
			} else {
				p.Notice = "A bola abriu! Enfraqueça o Pokémon e tente novamente."
			}
		}
	case "auto":
		b := w.Battles[p.Battle]
		if b != nil && (b.Kind == "capture" || b.Kind == "event") {
			return errMsg("capturas são sempre manuais")
		}
		p.Auto = !p.Auto
		if b != nil {
			for _, f := range b.Fighters {
				if f.Owner == p.ID {
					f.Auto = p.Auto
				}
			}
		}
	case "team", "train":
		if len(c.IDs) == 0 || len(c.IDs) > 6 {
			return errMsg("escolha de 1 a 6 parceiros")
		}
		seen := map[string]bool{}
		for _, id := range c.IDs {
			if p.mon(id) == nil || seen[id] {
				return errMsg("parceiro inválido ou duplicado")
			}
			seen[id] = true
		}
		if c.Type == "team" {
			p.Team = c.IDs
		} else {
			if len(routePool[c.Area]) == 0 || !p.Visits[c.Area] {
				return errMsg("visite a rota antes de treinar nela")
			}
			p.Training = &Training{IDs: c.IDs, Route: c.Area, At: now}
			p.Notice = "Treino automático ativo: 1 EV/30s, até 8h offline."
		}
	case "stop_train":
		p.Training = nil
	case "plant", "water", "harvest":
		if p.Area != "jardim" || c.Index < 0 || c.Index >= 6 {
			return errMsg("escolha um canteiro no jardim")
		}
		plot := &p.Plots[c.Index]
		switch c.Type {
		case "plant":
			if plot.At > 0 || p.Seeds < 1 {
				return errMsg("canteiro ocupado ou sementes insuficientes")
			}
			p.Seeds--
			plot.At = now
		case "water":
			if plot.At == 0 {
				return errMsg("plante primeiro")
			}
			plot.Water = true
		case "harvest":
			if !plot.Water || plot.At == 0 || now-plot.At < 90 {
				return errMsg("regue e aguarde 90 segundos")
			}
			p.Berries += 3
			p.Seeds += 2
			p.XP += 10
			p.Flags["harvest"]++
			*plot = Plot{}
			p.Notice = "Colheita: +3 berries e +2 sementes!"
		}
	case "mine":
		if p.Area != "mina" || now-p.MineAt < 4 {
			return errMsg("vá à mina e aguarde a recarga da picareta")
		}
		p.MineAt = now
		items := []string{"Pedra de Fogo", "Pedra da Água", "Pedra do Trovão", "Pedra da Lua", "Pedra Dura", "Lente Foco"}
		item := items[mathrand.IntN(len(items))]
		p.Stones[item]++
		p.Flags["mine"]++
		p.XP += 8
		p.Notice = "Você encontrou " + item + "!"
		if mathrand.IntN(5) == 0 {
			return w.startBattle(p, "capture", []int{74, 41, 95}[mathrand.IntN(3)], nil, now)
		}
	case "buy":
		cost := map[string]int{"bola": 20, "semente": 10, "planta": 60, "estante": 120, "aquario": 180, "pelucia": 15}[c.Value]
		if cost == 0 {
			return errMsg("item desconhecido")
		}
		if c.Value == "pelucia" {
			if p.Points < cost {
				return errMsg("fichas insuficientes")
			}
		} else if p.Coins < cost {
			return errMsg("moedas insuficientes")
		}
		if c.Value != "bola" && c.Value != "semente" {
			for _, d := range p.Decor {
				if d.Kind == c.Value {
					return errMsg("você já tem esse móvel")
				}
			}
		}
		if c.Value == "pelucia" {
			p.Points -= cost
		} else {
			p.Coins -= cost
		}
		switch c.Value {
		case "bola":
			p.Balls++
		case "semente":
			p.Seeds++
		default:
			p.Decor = append(p.Decor, Decor{c.Value, Vec{352, 256}})
		}
	case "decorate":
		if p.Area != "casa" || !finite(c.Pos.X) || !finite(c.Pos.Y) {
			return errMsg("posição inválida")
		}
		found := false
		for i := range p.Decor {
			if p.Decor[i].Kind == c.Value {
				p.Decor[i].Pos = Vec{math.Round(clamp(c.Pos.X, 64, 432)/16) * 16, math.Round(clamp(c.Pos.Y, 144, 304)/16) * 16}
				found = true
			}
		}
		if !found {
			return errMsg("compre esse móvel primeiro")
		}
	case "profession":
		if !slices.Contains([]string{"Treinador", "Professor", "Engenheiro"}, c.Value) {
			return errMsg("profissão inválida")
		}
		p.Profession = c.Value
	case "job":
		key := "job:" + p.Profession
		if now-p.Gifts[key] < 3600 {
			return errMsg("nova tarefa em uma hora")
		}
		if p.Profession == "Professor" {
			dex := map[int]bool{}
			for _, m := range p.Mons {
				dex[m.Species] = true
			}
			if len(dex) < 3 {
				return errMsg("registre 3 espécies na Pokédex")
			}
		} else if p.Profession == "Engenheiro" {
			if p.Stones["Pedra da Lua"] < 1 {
				return errMsg("traga uma Pedra da Lua")
			}
			p.Stones["Pedra da Lua"]--
		} else {
			return errMsg("escolha Professor ou Engenheiro")
		}
		p.Gifts[key] = now
		p.Coins += 80
		p.XP += 40
		p.Notice = "Pesquisa entregue! +80 moedas, +40 XP."
	case "held":
		if len(c.IDs) != 1 || p.mon(c.IDs[0]) == nil || !slices.Contains([]string{"Pedra Dura", "Lente Foco"}, c.Value) || p.Stones[c.Value] < 1 {
			return errMsg("escolha um parceiro e um item que você possui")
		}
		m := p.mon(c.IDs[0])
		if m.Held != "" {
			p.Stones[m.Held]++
		}
		p.Stones[c.Value]--
		m.Held = c.Value
	case "breed":
		if p.Egg != nil || len(c.IDs) != 2 || p.Berries < 3 {
			return errMsg("precisa de dois parceiros, 3 berries e incubadora livre")
		}
		a, b := p.mon(c.IDs[0]), p.mon(c.IDs[1])
		if a == nil || b == nil || a.ID == b.ID || a.Sex == b.Sex || species[a.Species].Group != species[b.Species].Group || species[a.Species].Group == "Lendário" {
			return errMsg("escolha sexos diferentes e o mesmo grupo de ovos")
		}
		child := breedMon(*a, *b, mathrand.Float64)
		p.Berries -= 3
		p.Egg = &Egg{child, now}
	case "predict":
		if len(c.IDs) != 2 || p.mon(c.IDs[0]) == nil || p.mon(c.IDs[1]) == nil {
			return errMsg("selecione dois parceiros")
		}
		p.Prediction = predict(*p.mon(c.IDs[0]), *p.mon(c.IDs[1]))
	case "eat":
		return w.eat(p, c.Value, now)
	case "fish":
		return w.fish(p, now)
	case "care":
		if len(c.IDs) != 1 || p.mon(c.IDs[0]) == nil || p.Berries < 1 {
			return errMsg("escolha um parceiro e tenha uma berry")
		}
		if now-p.Gifts["care:"+c.IDs[0]] < 300 {
			return errMsg("espere 5 minutos antes de oferecer outra berry")
		}
		p.Berries--
		p.Gifts["care:"+c.IDs[0]] = now
		p.mon(c.IDs[0]).Affinity = min(100, p.mon(c.IDs[0]).Affinity+5)
	case "evolve":
		if len(c.IDs) != 1 {
			return errMsg("escolha um parceiro")
		}
		return w.evolve(p, c.IDs[0], c.Value, now)

	case "list":
		if len(c.IDs) != 1 || c.Index < 1 || c.Index > 100000 {
			return errMsg("escolha um parceiro e preço de 1 a 100000 moedas")
		}
		if len(p.Mons) < 2 {
			return errMsg("mantenha ao menos um parceiro")
		}
		m := p.mon(c.IDs[0])
		if m == nil {
			return errMsg("parceiro indisponível")
		}
		if slices.Contains(p.Team, m.ID) {
			return errMsg("retire o parceiro da equipe antes de anunciar")
		}
		if p.Training != nil && slices.Contains(p.Training.IDs, m.ID) {
			return errMsg("pare o treino desse parceiro antes de anunciar")
		}
		if len(w.Market) >= 200 {
			return errMsg("mercado cheio")
		}
		w.Market = append(w.Market, Listing{uid(), p.ID, p.Name, *m, c.Index})
		p.Mons = slices.DeleteFunc(p.Mons, func(x Mon) bool { return x.ID == c.IDs[0] })
		p.Notice = "Parceiro anunciado no mercado. Genes e pedigree acompanham o anúncio."
	case "purchase", "cancel_listing":
		found := -1
		for i, l := range w.Market {
			if l.ID == c.Value {
				found = i
				break
			}
		}
		if found < 0 {
			return errMsg("anúncio não está mais disponível")
		}
		l := w.Market[found]
		if len(p.Mons) >= 200 {
			return errMsg("armazenamento cheio")
		}
		if c.Type == "cancel_listing" {
			if l.Seller != p.ID {
				return errMsg("anúncio de outro treinador")
			}
		} else {
			if l.Seller == p.ID || p.Coins < l.Price {
				return errMsg("compra indisponível ou saldo insuficiente")
			}
			seller := w.Players[l.Seller]
			if seller == nil {
				return errMsg("vendedor indisponível")
			}
			p.Coins -= l.Price
			seller.Coins += l.Price
			seller.Notice = "Seu parceiro foi vendido no mercado global!"
		}
		p.Mons = append(p.Mons, l.Mon)
		w.Market = append(w.Market[:found], w.Market[found+1:]...)
		p.Notice = "Transferência concluída com todos os genes e IVs preservados."
	case "hatch":
		if p.Egg == nil || now-p.Egg.At < 180 || len(p.Mons) >= 200 {
			return errMsg("aguarde 3 minutos de incubação")
		}
		p.Mons = append(p.Mons, p.Egg.Mon)
		p.Egg = nil
		p.XP += 15
		p.Notice = "O ovo chocou! Um novo parceiro chegou."
	case "dex":
		dex := map[int]bool{}
		for _, m := range p.Mons {
			dex[m.Species] = true
		}
		if len(dex) < p.Flags["dex"]+3 {
			return errMsg("registre mais 3 espécies para a conquista")
		}
		p.Flags["dex"] += 3
		p.Coins += 100
		p.Points += 10
	case "safari":
		if p.Area != "safari" {
			return errMsg("vá à Reserva Orvalho")
		}
		pos := Vec{100 + mathrand.Float64()*300, 150 + mathrand.Float64()*140}
		if m := areaMaps[p.Area]; m != nil {
			// Perto do jogador e em chão livre, dentro do mapa maior.
			for try := 0; try < 20; try++ {
				a := mathrand.Float64() * 2 * math.Pi
				cand := m.bounds(p.Pos.Add(Vec{math.Cos(a), math.Sin(a)}.Mul(90 + mathrand.Float64()*110)))
				if !m.solid(cand, Vec{}) {
					pos = cand
					break
				}
			}
		}
		p.Safari = &Safari{Species: []int{16, 19, 25, 133}[mathrand.IntN(4)], Pos: pos, At: now}
	case "throw":
		if p.Area != "safari" || p.Safari == nil || p.Balls < 1 || len(p.Mons) >= 200 || !finite(c.Pos.X) || !finite(c.Pos.Y) {
			return errMsg("encontre um Pokémon e prepare uma bola")
		}
		if now-p.Safari.At < .5 {
			return errMsg("mire antes de lançar")
		}
		p.Balls--
		d := distance(c.Pos, p.Safari.Pos)
		chance := .05
		if d < 40 {
			chance = .5
		}
		if d < 18 {
			chance = .85
		}
		if mathrand.Float64() < chance {
			p.Mons = append(p.Mons, newMon(p.Safari.Species))
			p.XP += 15
			p.Notice = "Boa mira! Pokémon capturado na reserva."
		} else {
			p.Notice = "Ele escapou! Mire no centro do alvo."
		}
		p.Safari = nil
	case "chat":
		if p.Area != "ginasio" || len(c.Text) > 400 || strings.TrimSpace(c.Text) == "" {
			return errMsg("use o chat no saguão; máximo 400 bytes")
		}
		if now-p.Gifts["chat"] < 1.5 {
			return errMsg("aguarde antes de enviar outra mensagem")
		}
		p.Gifts["chat"] = now
		w.Chat = append(w.Chat, Message{p.Name, strings.TrimSpace(c.Text), now})
		if len(w.Chat) > 40 {
			w.Chat = w.Chat[len(w.Chat)-40:]
		}
	case "queue":
		if p.Area != "ginasio" {
			return errMsg("vá ao saguão")
		}
		for i, id := range w.Queue {
			if id == p.ID {
				w.Queue = append(w.Queue[:i], w.Queue[i+1:]...)
				p.Notice = "Busca cancelada."
				return nil
			}
		}
		for i, id := range w.Queue {
			other := w.Players[id]
			if other != nil && other.Battle == "" && now-other.Seen < 10 {
				w.Queue = append(w.Queue[:i], w.Queue[i+1:]...)
				return w.startBattle(p, "pvp", 1, other, now)
			}
		}
		w.Queue = append(w.Queue, p.ID)
		p.Notice = "Procurando outro treinador real no saguão…"
	case "event":
		t := time.Unix(int64(now), 0).UTC()
		if p.Area != "lago" || t.Weekday() != time.Sunday {
			return errMsg("Mew aparece aos domingos (UTC), no Lago Celeste")
		}
		if p.Event == t.Format("2006-01-02") {
			return errMsg("você já capturou Mew neste evento")
		}
		return w.startBattle(p, "event", 151, nil, now)
	case "arcade":
		if p.Area != "casa" || !slices.Contains([]string{"arcade", "Corrida", "Voo", "Natação"}, c.Value) {
			return errMsg("use o computador em casa")
		}
		if c.Value == "Voo" || c.Value == "Natação" {
			ok := false
			for _, m := range p.Mons {
				if species[m.Species].Ride == c.Value {
					ok = true
				}
			}
			if !ok {
				return errMsg("capture um parceiro com essa habilidade")
			}
		}
		p.Arcade = &Arcade{Kind: c.Value, Pos: Vec{256, 310}, Start: now, HP: 5, Seed: mathrand.Float64() * 10}
	case "arcade_stop":
		p.Arcade = nil
	default:
		return errMsg("ação desconhecida")
	}
	return nil
}
func finite(x float64) bool { return !math.IsNaN(x) && !math.IsInf(x, 0) }
