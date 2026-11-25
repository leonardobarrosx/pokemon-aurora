package main

import "math"

// Field é o terreno do estádio de um ginásio: uma grade de 15x8 casas de
// 32px sobre a área de luta. Cada casa tem um tipo de chão que muda a
// velocidade, machuca ou bloqueia, e os golpes transformam o campo.
//
//	.  chão            p  plataforma        s  areia / terra
//	w  água            r  pedra (bloqueia)  g  grama alta
//	l  lava            i  gelo              e  placa elétrica
//	x  veneno          z  água eletrificada f  grama em chamas
type Field struct {
	Theme  string       `json:"theme"`
	Cols   int          `json:"cols"`
	Rows   int          `json:"rows"`
	X      float64      `json:"x"`
	Y      float64      `json:"y"`
	Cell   float64      `json:"cell"`
	Cells  string       `json:"cells"`
	Base   string       `json:"base"`
	Timers []FieldTimer `json:"-"`
}

type FieldTimer struct {
	Cell int
	To   byte
	At   float64
}

const (
	fieldCols = 15
	fieldRows = 8
	fieldCell = 32.0
	fieldX    = 16.0
	fieldY    = 96.0
)

// Tema de cada ginásio, pelo tipo do líder.
var gymTheme = map[string]string{
	"aurora_1": "planta",
	"kanto_1":  "rocha", "kanto_2": "agua", "kanto_3": "eletrico", "kanto_4": "planta",
	"kanto_5": "veneno", "kanto_6": "psiquico", "kanto_7": "fogo", "kanto_8": "terra",
	"hoenn_1": "rocha", "hoenn_2": "lutador", "hoenn_3": "eletrico", "hoenn_4": "fogo",
	"hoenn_5": "normal", "hoenn_6": "voador", "hoenn_7": "psiquico", "hoenn_8": "agua",
	"johto_1": "voador", "johto_2": "inseto", "johto_3": "normal", "johto_4": "fantasma",
	"johto_5": "lutador", "johto_6": "aco", "johto_7": "gelo", "johto_8": "dragao",
	"sinnoh_1": "rocha", "sinnoh_2": "planta", "sinnoh_3": "fantasma", "sinnoh_4": "lutador",
	"sinnoh_5": "agua", "sinnoh_6": "aco", "sinnoh_7": "gelo", "sinnoh_8": "eletrico",
}

// Campos de 15x8. O treinador começa na coluna 2, linha 4 e o líder na
// coluna 12, linha 3: essas casas sempre são pisáveis.
var fieldLayouts = map[string][fieldRows]string{
	"agua": {
		"ppppwwwwwwwpppp",
		"ppppwwwwwwwpppp",
		"pppwwwwpwwwwppp",
		"pppwwwpppwwwppp",
		"pppwwwwpwwwwppp",
		"wwwwwwwwwwwwwww",
		"wwppwwwppwwwppw",
		"wwppwwwppwwwppw",
	},
	"rocha": {
		"sssrsssssssrsss",
		"ssssssrssssssss",
		"srsssssssssssrs",
		"sssssrsssrsssss",
		"sssssssssssssss",
		"ssssrsssssssrss",
		"srsssssrsssssss",
		"sssssssssssrsss",
	},
	"terra": {
		"sss.sssssss.sss",
		"s.ssssrsssss.ss",
		"ssssssssssrssss",
		"ss.ssss.sssssss",
		"sssssssssss.sss",
		"ssrsssssrssssss",
		"s.sssss.sssss.s",
		"sss.sssssss.sss",
	},
	"eletrico": {
		"...............",
		".eee.......eee.",
		"...............",
		"..e..eeeee..e..",
		"...............",
		".eee.......eee.",
		"...............",
		"......eee......",
	},
	"planta": {
		"ggg.........ggg",
		"gg..ggg.ggg..gg",
		"g......g......g",
		"..ggg.....ggg..",
		"..g..gg.gg..g..",
		"g......g......g",
		"gg..ggg.ggg..gg",
		"ggg.........ggg",
	},
	"inseto": {
		"gggrgggggggrggg",
		"gg...ggggg...gg",
		"g...ggg.ggg...g",
		"..ggg.....ggg..",
		"..g.ggg.ggg.g..",
		"g...ggg.ggg...g",
		"gg...ggggg...gg",
		"gggrgggggggrggg",
	},
	"veneno": {
		"xx...........xx",
		"x....xxxxx....x",
		"...............",
		"..xx......xx...",
		"......xxx......",
		"...............",
		"x....xxxxx....x",
		"xx...........xx",
	},
	"fogo": {
		"lll.........lll",
		"ll...........ll",
		"....lll........",
		"......l...r....",
		"..........lll..",
		"r...........ll.",
		"ll...lll.....ll",
		"lll.........lll",
	},
	"gelo": {
		"iiiiiiiiiiiiiii",
		"ii....iii....ii",
		"i..iiiiiiiii..i",
		"i..ii.www.ii..i",
		"i..ii.www.ii..i",
		"i..iiiiiiiii..i",
		"ii....iii....ii",
		"iiiiiiiiiiiiiii",
	},
	"dragao": {
		"lll.........lll",
		"l..ppp...ppp..l",
		"...........r...",
		"..r..lllll.....",
		".....lllll..r..",
		"...r...........",
		"l..ppp...ppp..l",
		"lll.........lll",
	},
	"psiquico": {
		"...............",
		"..r.........r..",
		"...............",
		"......r.r......",
		"...............",
		"......r.r......",
		"..r.........r..",
		"...............",
	},
	"fantasma": {
		"x.............x",
		"..r....x....r..",
		"...............",
		".....r...r.....",
		"...x.......x...",
		".....r...r.....",
		"..r....x....r..",
		"x.............x",
	},
	"aco": {
		"...............",
		".r...........r.",
		"....r.....r....",
		"...............",
		"...............",
		"....r.....r....",
		".r...........r.",
		"...............",
	},
	"voador": {
		"ppppppppppppppp",
		"pp...........pp",
		"p...ppp.ppp...p",
		"p..ppppppppp..p",
		"p..ppppppppp..p",
		"p...ppp.ppp...p",
		"pp...........pp",
		"ppppppppppppppp",
	},
	"lutador": {
		"rsssssssssssssr",
		"s.............s",
		"s.............s",
		"s.............s",
		"s.............s",
		"s.............s",
		"s.............s",
		"rsssssssssssssr",
	},
	"normal": {
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
		"...............",
	},
}

func newField(theme string) *Field {
	rows, ok := fieldLayouts[theme]
	if !ok {
		theme, rows = "normal", fieldLayouts["normal"]
	}
	cells := make([]byte, 0, fieldCols*fieldRows)
	for _, r := range rows {
		line := []byte(r)
		for len(line) < fieldCols {
			line = append(line, '.')
		}
		cells = append(cells, line[:fieldCols]...)
	}
	return &Field{Theme: theme, Cols: fieldCols, Rows: fieldRows, X: fieldX, Y: fieldY, Cell: fieldCell, Cells: string(cells), Base: string(cells)}
}

func (fl *Field) index(v Vec) int {
	c := int(math.Floor((v.X - fl.X) / fl.Cell))
	r := int(math.Floor((v.Y - fl.Y) / fl.Cell))
	if c < 0 || r < 0 || c >= fl.Cols || r >= fl.Rows {
		return -1
	}
	return r*fl.Cols + c
}

func (fl *Field) at(v Vec) byte {
	i := fl.index(v)
	if i < 0 {
		return '.'
	}
	return fl.Cells[i]
}

func (fl *Field) center(i int) Vec {
	return Vec{fl.X + (float64(i%fl.Cols)+.5)*fl.Cell, fl.Y + (float64(i/fl.Cols)+.5)*fl.Cell}
}

func (fl *Field) set(i int, c byte, revertAfter, now float64) {
	if i < 0 || fl.Cells[i] == c {
		return
	}
	b := []byte(fl.Cells)
	old := b[i]
	b[i] = c
	fl.Cells = string(b)
	// Uma mudança nova substitui o tempo de volta anterior da mesma casa.
	timers := fl.Timers[:0]
	for _, t := range fl.Timers {
		if t.Cell != i {
			timers = append(timers, t)
		} else {
			old = t.To
		}
	}
	fl.Timers = timers
	if revertAfter > 0 {
		fl.Timers = append(fl.Timers, FieldTimer{Cell: i, To: old, At: now + revertAfter})
	}
}

func (fl *Field) tick(now float64) {
	if len(fl.Timers) == 0 {
		return
	}
	b := []byte(fl.Cells)
	timers := fl.Timers[:0]
	for _, t := range fl.Timers {
		if now >= t.At {
			b[t.Cell] = t.To
		} else {
			timers = append(timers, t)
		}
	}
	fl.Cells = string(b)
	fl.Timers = timers
}

func flies(f *Fighter) bool {
	s := species[f.Mon.Species]
	return s.Ride == "Voo" || s.Type == "Voador"
}

func swims(f *Fighter) bool {
	s := species[f.Mon.Species]
	return s.Ride == "Natação" || s.Type == "Água"
}

// solid diz se a casa bloqueia o lutador: pedra bloqueia quem não voa.
func (b *Battle) solid(f *Fighter, v Vec) bool {
	return b.Field != nil && b.Field.at(v) == 'r' && !flies(f)
}

// terrainSpeed é o multiplicador de velocidade da casa onde o lutador está.
func (b *Battle) terrainSpeed(f *Fighter) float64 {
	if b.Field == nil || flies(f) {
		return 1
	}
	t := species[f.Mon.Species].Type
	switch b.Field.at(f.Pos) {
	case 'w', 'z':
		if swims(f) {
			return 1.3
		}
		return .5
	case 'i':
		if t == "Gelo" {
			return 1.2
		}
		return 1.05
	case 'g':
		if t == "Planta" || t == "Inseto" {
			return 1.2
		}
		return .88
	case 's':
		if t == "Pedra" || t == "Terra" {
			return 1.15
		}
		return .92
	case 'e':
		if t == "Elétrico" {
			return 1.25
		}
	case 'l', 'f':
		if t == "Fogo" {
			return 1.15
		}
		return .85
	case 'x':
		if t == "Veneno" || t == "Fantasma" {
			return 1.1
		}
		return .85
	}
	return 1
}

// slippery: no gelo quem não é do tipo Gelo derrapa (acelera devagar).
func (b *Battle) slippery(f *Fighter) bool {
	return b.Field != nil && !flies(f) && b.Field.at(f.Pos) == 'i' && species[f.Mon.Species].Type != "Gelo"
}

// tickTerrain aplica dano e efeitos da casa a cada lutador.
func (b *Battle) tickTerrain(dt, now float64) {
	fl := b.Field
	if fl == nil {
		return
	}
	fl.tick(now)
	for _, f := range b.Fighters {
		c := fl.at(f.Pos)
		f.Terrain = string(c)
		if flies(f) {
			f.Terrain = "voo"
			continue
		}
		t := species[f.Mon.Species].Type
		switch c {
		case 'w':
			if !swims(f) {
				// Molhado: continua lento um pouco depois de sair da água.
				f.SlowUntil = math.Max(f.SlowUntil, now+1.2)
			}
		case 'z':
			if t != "Elétrico" {
				f.HP = math.Max(1, f.HP-dt*f.MaxHP*.06)
				f.SlowUntil = math.Max(f.SlowUntil, now+1.2)
			}
		case 'l':
			if t != "Fogo" {
				f.HP = math.Max(1, f.HP-dt*f.MaxHP*.05)
			}
		case 'f':
			if t != "Fogo" {
				f.HP = math.Max(1, f.HP-dt*f.MaxHP*.03)
			}
		case 'x':
			if t != "Veneno" && t != "Fantasma" {
				f.HP = math.Max(1, f.HP-dt*f.MaxHP*.025)
			}
		case 'e':
			if t == "Elétrico" {
				f.Energy = math.Min(100, f.Energy+dt*6)
			}
		case 'g':
			if t == "Planta" || t == "Inseto" {
				f.HP = math.Min(f.MaxHP, f.HP+dt*f.MaxHP*.01)
			}
		}
	}
}

// terrainPower: quem não nada perde força dentro da água.
func (b *Battle) terrainPower(f *Fighter) float64 {
	if b.Field == nil || flies(f) {
		return 1
	}
	switch b.Field.at(f.Pos) {
	case 'w', 'z':
		if !swims(f) {
			return .8
		}
		return 1.1
	case 'e':
		if species[f.Mon.Species].Type == "Elétrico" {
			return 1.1
		}
	case 'l':
		if species[f.Mon.Species].Type == "Fogo" {
			return 1.1
		}
	}
	return 1
}

// cellCost diz o quanto uma casa é ruim para o lutador; a IA desvia das
// casas caras e procura o lugar certo para ficar.
func (b *Battle) cellCost(f *Fighter, v Vec) float64 {
	if b.Field == nil || flies(f) {
		return 0
	}
	t := species[f.Mon.Species].Type
	switch b.Field.at(v) {
	case 'r':
		return 99
	case 'w':
		if swims(f) {
			return -1
		}
		return 3
	case 'z':
		if t == "Elétrico" {
			return 0
		}
		return 6
	case 'l', 'f':
		if t == "Fogo" {
			return -1
		}
		return 6
	case 'x':
		if t == "Veneno" || t == "Fantasma" {
			return -1
		}
		return 4
	case 'i':
		if t == "Gelo" {
			return -1
		}
		return 1
	case 'g':
		if t == "Planta" || t == "Inseto" {
			return -1
		}
	case 'e':
		if t == "Elétrico" {
			return -1
		}
	case 's':
		if t == "Pedra" || t == "Terra" {
			return -1
		}
	}
	return 0
}

// autoStep move a IA na direção desejada, desviando de pedras e de casas
// ruins para o tipo dela.
func (b *Battle) autoStep(f *Fighter, dir Vec, dist float64) {
	if b.Field == nil || dir.Len() == 0 {
		b.step(f, f.Pos.Add(dir.Unit().Mul(dist)))
		return
	}
	base := math.Atan2(dir.Y, dir.X)
	best, bestCost := Vec{}, math.Inf(1)
	here := b.cellCost(f, f.Pos)
	for k, turn := range []float64{0, .5, -.5, 1, -1, 1.6, -1.6} {
		d := Vec{math.Cos(base + turn), math.Sin(base + turn)}
		probe := bounds(f.Pos.Add(d.Mul(fieldCell * .8)))
		cost := b.cellCost(f, probe) + float64(k)*.15
		if b.cellCost(f, probe) >= 99 {
			continue
		}
		if cost < bestCost {
			best, bestCost = d, cost
		}
	}
	if bestCost == math.Inf(1) || (bestCost > here+.5 && here < 3) {
		return
	}
	b.step(f, f.Pos.Add(best.Mul(dist)))
}

// shapeField: o golpe que cai num ponto muda as casas em volta.
func (b *Battle) shapeField(pos Vec, radius float64, kind string, now float64) {
	fl := b.Field
	if fl == nil {
		return
	}
	radius = math.Max(radius, 14)
	for i := 0; i < len(fl.Cells); i++ {
		c := fl.center(i)
		if distance(c, pos) > radius+fl.Cell*.5 {
			continue
		}
		cell := fl.Cells[i]
		switch kind {
		case "Gelo":
			switch cell {
			case 'w', 'z':
				fl.set(i, 'i', 14, now) // água congela e vira chão
			case 'l':
				fl.set(i, 's', 12, now) // lava esfria
			case 'f':
				fl.set(i, '.', 0, now)
			}
		case "Fogo":
			switch cell {
			case 'i':
				fl.set(i, 'w', 0, now) // gelo derrete
			case 'g':
				fl.set(i, 'f', 4, now) // grama pega fogo e depois vira chão
				b.burnTimer(i, now)
			}
		case "Água":
			switch cell {
			case 'l':
				fl.set(i, 's', 0, now) // lava apagada vira rocha moída
			case 'f':
				fl.set(i, '.', 0, now)
			case '.', 's':
				if radius >= 40 {
					fl.set(i, 'w', 6, now) // golpes grandes alagam o chão
				}
			}
		case "Elétrico":
			if cell == 'w' {
				fl.set(i, 'z', 3, now) // a água conduz a descarga
			}
		case "Pedra", "Terra":
			if (cell == '.' || cell == 's' || cell == 'g') && radius >= 40 && distance(c, pos) < fl.Cell && !b.occupied(c) {
				fl.set(i, 'r', 10, now) // ergue uma pedra no meio do golpe
			}
		case "Planta":
			if cell == '.' || cell == 's' {
				fl.set(i, 'g', 0, now) // a grama cresce
			}
		case "Lutador":
			if cell == 'r' {
				fl.set(i, '.', 0, now) // quebra a pedra
			}
		case "Veneno":
			if cell == '.' || cell == 's' || cell == 'g' {
				fl.set(i, 'x', 8, now)
			}
		}
	}
}

// burnTimer: grama queimada volta como chão, não como grama.
func (b *Battle) burnTimer(i int, now float64) {
	for k := range b.Field.Timers {
		if b.Field.Timers[k].Cell == i {
			b.Field.Timers[k].To = '.'
		}
	}
}

func (b *Battle) occupied(c Vec) bool {
	for _, f := range b.Fighters {
		if distance(f.Pos, c) < fieldCell {
			return true
		}
	}
	return false
}

// shapeBeam aplica o efeito do raio ao longo de todo o caminho.
func (b *Battle) shapeBeam(from, to Vec, kind string, now float64) {
	if b.Field == nil {
		return
	}
	d := to.Add(from.Mul(-1))
	steps := int(d.Len()/(fieldCell*.75)) + 1
	for k := 0; k <= steps; k++ {
		b.shapeField(from.Add(d.Mul(float64(k)/float64(steps))), 12, kind, now)
	}
}

// safeCell acha a casa boa mais perto para a IA sair de um lugar ruim.
func (b *Battle) safeCell(f *Fighter) (Vec, bool) {
	best, bestD := Vec{}, math.Inf(1)
	for i := range b.Field.Cells {
		c := b.Field.center(i)
		if b.cellCost(f, c) > 0 {
			continue
		}
		if d := distance(c, f.Pos); d < bestD {
			best, bestD = c, d
		}
	}
	return best, bestD < math.Inf(1)
}
