package main

// Sistema universal de terreno. Cada letra da grade tem propriedades, e as
// regras de movimento, dano e transformação leem só essas propriedades. Assim
// as mesmas regras servem para ginásios, rotas, cavernas e lendários.
type Terrain struct {
	Name       string
	Solid      bool     // bloqueia passos e disparos
	Low        bool     // sólido baixo: voadores passam por cima
	Void       bool     // vão: só voadores ficam em cima
	HP         float64  // integridade de obstáculo destrutível (0 = indestrutível)
	Broken     byte     // no que vira ao ser destruído
	Cracked    byte     // estado intermediário (rachado)
	Swim       bool     // água funda: só quem nada se move bem
	Wet        bool     // molha e conduz eletricidade
	Conductive bool     // metal: também conduz
	Slippery   bool     // derrapa
	Flammable  bool     // pega fogo
	Hide       bool     // esconde Pokémon pequenos
	Dig        bool     // escavável
	Speed      float64  // velocidade de quem não tem afinidade
	Friends    []string // tipos com afinidade (mais rápidos, sem penalidade)
	Bonus      float64  // velocidade de quem tem afinidade
	Damage     float64  // fração da vida por segundo para quem não é imune
	Push       Vec      // correnteza ou vento
	Wind       bool     // empurra também voadores (e mais forte neles)
}

var terrains = map[byte]Terrain{
	'.': {Name: "piso", Speed: 1},
	',': {Name: "madeira", Speed: 1},
	's': {Name: "areia", Speed: .94, Dig: true, Friends: []string{"Pedra", "Terra"}, Bonus: 1.15},
	'm': {Name: "lama", Speed: .6, Wet: true, Friends: []string{"Terra", "Água"}, Bonus: 1},
	'n': {Name: "neve", Speed: .85, Friends: []string{"Gelo"}, Bonus: 1.15},
	'M': {Name: "metal", Speed: 1, Conductive: true, Friends: []string{"Aço"}, Bonus: 1.1},
	'b': {Name: "ponte", Speed: 1},
	'p': {Name: "plataforma", Speed: 1},
	'k': {Name: "plataforma frágil", Speed: 1},
	'w': {Name: "água rasa", Speed: .72, Wet: true, Friends: []string{"Água"}, Bonus: 1.2},
	'u': {Name: "fonte termal", Speed: .75, Wet: true, Friends: []string{"Água", "Fogo"}, Bonus: 1.15},
	'W': {Name: "água funda", Speed: .45, Wet: true, Swim: true, Friends: []string{"Água"}, Bonus: 1.3},
	'_': {Name: "plataforma afundada", Speed: .45, Wet: true, Swim: true, Friends: []string{"Água"}, Bonus: 1.3},
	'>': {Name: "correnteza", Speed: .45, Wet: true, Swim: true, Friends: []string{"Água"}, Bonus: 1.3, Push: Vec{55, 0}},
	'<': {Name: "correnteza", Speed: .45, Wet: true, Swim: true, Friends: []string{"Água"}, Bonus: 1.3, Push: Vec{-55, 0}},
	'^': {Name: "correnteza", Speed: .45, Wet: true, Swim: true, Friends: []string{"Água"}, Bonus: 1.3, Push: Vec{0, -55}},
	'v': {Name: "correnteza", Speed: .45, Wet: true, Swim: true, Friends: []string{"Água"}, Bonus: 1.3, Push: Vec{0, 55}},
	'z': {Name: "água eletrificada", Speed: .45, Wet: true, Swim: true, Friends: []string{"Elétrico"}, Bonus: 1, Damage: .06},
	'i': {Name: "gelo", Speed: 1.05, Slippery: true, Friends: []string{"Gelo"}, Bonus: 1.2, Cracked: 'j'},
	'j': {Name: "gelo rachado", Speed: 1.05, Slippery: true, Friends: []string{"Gelo"}, Bonus: 1.2, Broken: 'W'},
	'g': {Name: "grama alta", Speed: .9, Hide: true, Flammable: true, Friends: []string{"Planta", "Inseto"}, Bonus: 1.2},
	'o': {Name: "flores", Speed: .95, Flammable: true, Friends: []string{"Planta", "Inseto", "Fada"}, Bonus: 1.15},
	'X': {Name: "teia", Speed: .45, Flammable: true, Friends: []string{"Inseto"}, Bonus: 1.1},
	'f': {Name: "fogo", Speed: .85, Damage: .03, Friends: []string{"Fogo"}, Bonus: 1.15},
	'l': {Name: "lava", Speed: .8, Damage: .05, Friends: []string{"Fogo"}, Bonus: 1.15},
	'e': {Name: "placa elétrica", Speed: 1, Conductive: true, Friends: []string{"Elétrico"}, Bonus: 1.25},
	'x': {Name: "veneno", Speed: .85, Damage: .025, Friends: []string{"Veneno", "Fantasma"}, Bonus: 1.1},
	'V': {Name: "gêiser", Speed: 1},
	'Y': {Name: "teleporte", Speed: 1},
	'}': {Name: "vento", Speed: 1, Push: Vec{60, 0}, Wind: true},
	'{': {Name: "vento", Speed: 1, Push: Vec{-60, 0}, Wind: true},
	')': {Name: "vento", Speed: 1, Push: Vec{0, 60}, Wind: true},
	'(': {Name: "vento", Speed: 1, Push: Vec{0, -60}, Wind: true},
	'r': {Name: "rocha", Solid: true, Low: true, HP: 70, Cracked: 'q', Broken: 's'},
	'q': {Name: "rocha rachada", Solid: true, Low: true, HP: 35, Broken: 's'},
	'h': {Name: "cerca viva", Solid: true, Low: true, HP: 45, Broken: '.', Flammable: true},
	'I': {Name: "pilar de gelo", Solid: true, HP: 55, Broken: 'w'},
	't': {Name: "árvore", Solid: true, Flammable: false},
	'P': {Name: "pilar", Solid: true},
	'R': {Name: "parede", Solid: true},
	'F': {Name: "fóssil", Solid: true},
	'T': {Name: "máquina", Solid: true},
	'G': {Name: "vidro", Solid: true},
	'~': {Name: "cascata", Solid: true},
	'A': {Name: "arquibancada", Solid: true},
	'L': {Name: "camarote", Solid: true},
	'C': {Name: "camarote", Solid: true},
	'O': {Name: "vão", Void: true},
}

func terrainOf(c byte) Terrain {
	if t, ok := terrains[c]; ok {
		return t
	}
	return terrains['.']
}

func (t Terrain) friend(kind string) bool {
	for _, k := range t.Friends {
		if k == kind {
			return true
		}
	}
	return false
}

// Danos de cada tipo contra obstáculos: quebrar pedra é coisa de Lutador,
// Pedra e Terra; fogo derrete gelo e queima cerca viva.
func obstacleDamage(c byte, kind string, dmg float64) float64 {
	switch c {
	case 'r', 'q':
		switch kind {
		case "Lutador", "Pedra", "Terra", "Aço":
			return dmg * 2
		case "Fogo", "Elétrico", "Fantasma", "Planta":
			return dmg * .25
		}
	case 'h':
		switch kind {
		case "Fogo":
			return dmg * 3
		case "Voador", "Inseto", "Lutador":
			return dmg * 1.5
		}
	case 'I':
		switch kind {
		case "Fogo":
			return dmg * 3
		case "Lutador", "Pedra", "Aço":
			return dmg * 1.5
		case "Gelo", "Água":
			return 0
		}
	}
	return dmg
}
