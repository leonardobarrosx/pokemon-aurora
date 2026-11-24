package main

import (
	mathrand "math/rand/v2"
	"strconv"
)

func colorName(hex string) string {
	if hex == "original" {
		return "Original"
	}
	v, err := strconv.ParseUint(hex[1:], 16, 32)
	if err != nil {
		return "Original"
	}
	r, g, b := float64((v>>16)&255), float64((v>>8)&255), float64(v&255)
	hi, lo := max(r, g, b), min(r, g, b)
	if hi-lo < 30 {
		if hi > 190 {
			return "Marfim"
		}
		return "Cinza"
	}
	if r > g*1.35 && b > g*1.2 {
		return "Violeta"
	}
	if b > r && b > g {
		return "Azul"
	}
	if g > r && g > b {
		return "Verde"
	}
	if r > g*1.8 {
		return "Vermelho"
	}
	if r > g*1.1 {
		return "Laranja"
	}
	return "Amarelo"
}

// A deliberately fictional genetic model, not a claim about real mammalian coat genetics.
// Diploid loci, linked chromosomes, recombination and incomplete pigment dominance.
type Allele struct {
	Value     int `json:"value"`
	Dominance int `json:"dominance"`
}
type Locus [2]Allele
type Genome struct {
	Loci       map[string]Locus `json:"loci"`
	Seed       uint32           `json:"seed"`
	Generation int              `json:"generation"`
	Parents    [2]string        `json:"parents"`
	Lineage    []string         `json:"lineage"`
}
type Appearance struct {
	Body      string `json:"body"`
	Detail    string `json:"detail"`
	Eye       string `json:"eye"`
	Mouth     string `json:"mouth"`
	Pattern   string `json:"pattern"`
	Mark      string `json:"mark"`
	MarkColor string `json:"mark_color"`
	MarkPlace int    `json:"mark_place"`
	Seed      uint32 `json:"seed"`
}

var chromosome = [][]string{{"body", "detail", "pattern"}, {"eye", "mouth"}, {"mark", "mark_color", "mark_place"}, {"size"}}
var pigmentRGB = [][3]int{{0, 0, 0}, {225, 74, 68}, {244, 204, 75}, {76, 113, 215}, {240, 239, 226}, {71, 163, 108}, {155, 102, 192}, {68, 60, 83}}
var geneKeys = []string{"body", "detail", "pattern", "eye", "mouth", "mark", "mark_color", "mark_place", "size"}

func randomGenome() Genome {
	g := Genome{Loci: map[string]Locus{}, Seed: mathrand.Uint32(), Generation: 0, Lineage: []string{}}
	rare := mathrand.IntN(64) == 0
	for _, key := range geneKeys {
		v := 0
		dominance := 2
		if rare && key != "pattern" && key != "mark" && key != "mark_place" && key != "size" {
			v = 1 + mathrand.IntN(7)
		}
		if key == "pattern" && mathrand.IntN(5) == 0 {
			v = 1 + mathrand.IntN(3)
		}
		if key == "mark" && mathrand.IntN(4) == 0 {
			v = 1
		}
		if key == "size" {
			v = mathrand.IntN(5)
		}
		if key == "mark_place" {
			v = mathrand.IntN(5)
		}
		g.Loci[key] = Locus{{v, dominance}, {v, dominance}}
		if mathrand.IntN(3) == 0 {
			pair := g.Loci[key]
			n := 8
			if key == "pattern" {
				n = 4
			}
			if key == "mark" {
				n = 2
			}
			if key == "size" {
				n = 5
			}
			if key == "mark_place" {
				n = 5
			}
			pair[1] = Allele{mathrand.IntN(n), 1}
			g.Loci[key] = pair
		}
	}
	return g
}
func inherit(a, b Mon, rng func() float64) Genome {
	g := Genome{Loci: map[string]Locus{}, Seed: a.Genes.Seed, Generation: max(a.Genes.Generation, b.Genes.Generation) + 1, Parents: [2]string{a.ID, b.ID}, Lineage: []string{a.ID, b.ID}}
	if rng() < .5 {
		g.Seed = b.Genes.Seed
	}
	seen := map[string]bool{a.ID: true, b.ID: true}
	for _, parent := range []Mon{a, b} {
		for _, id := range parent.Genes.Lineage {
			if !seen[id] && len(g.Lineage) < 30 {
				g.Lineage = append(g.Lineage, id)
				seen[id] = true
			}
		}
	}
	for _, keys := range chromosome {
		for side, parent := range []Mon{a, b} {
			hap := int(rng() * 2)
			if hap > 1 {
				hap = 1
			}
			for i, key := range keys {
				if i > 0 && rng() < .15 {
					hap = 1 - hap
				}
				pair := g.Loci[key]
				pair[side] = parent.Genes.Loci[key][hap]
				g.Loci[key] = pair
			}
		}
	}
	return g
}
func expressed(l Locus) int {
	if l[1].Dominance > l[0].Dominance {
		return l[1].Value
	}
	return l[0].Value
}
func rgbHex(c [3]int) string {
	const h = "0123456789abcdef"
	out := []byte{'#', 0, 0, 0, 0, 0, 0}
	for i, n := range c {
		n = max(0, min(255, n))
		out[1+i*2] = h[n/16]
		out[2+i*2] = h[n%16]
	}
	return string(out)
}
func pigment(l Locus) string {
	a, b := l[0], l[1]
	if a.Dominance != b.Dominance {
		v := expressed(l)
		if v == 0 {
			return "original"
		}
		return rgbHex(pigmentRGB[v%len(pigmentRGB)])
	}
	if a.Value == 0 && b.Value == 0 {
		return "original"
	}
	if a.Value == 0 {
		return rgbHex(pigmentRGB[b.Value%8])
	}
	if b.Value == 0 {
		return rgbHex(pigmentRGB[a.Value%8])
	}
	ca, cb := pigmentRGB[a.Value%8], pigmentRGB[b.Value%8]
	var c [3]int
	for i := range c {
		c[i] = (ca[i] + cb[i]) / 2
	}
	return rgbHex(c)
}
func appearance(g Genome) Appearance {
	pattern := []string{"Liso", "Pintas", "Listras", "Mosaico"}[expressed(g.Loci["pattern"])%4]
	mark := "Sem sinal"
	if expressed(g.Loci["mark"]) > 0 {
		mark = "Sinal"
	}
	return Appearance{Body: pigment(g.Loci["body"]), Detail: pigment(g.Loci["detail"]), Eye: pigment(g.Loci["eye"]), Mouth: pigment(g.Loci["mouth"]), Pattern: pattern, Mark: mark, MarkColor: pigment(g.Loci["mark_color"]), MarkPlace: expressed(g.Loci["mark_place"]) % 5, Seed: g.Seed}
}
func breedMon(a, b Mon, rng func() float64) Mon {
	mother := a
	if b.Sex == "F" {
		mother = b
	}
	m := newMon(mother.Species)
	m.Level = 1
	m.Genes = inherit(a, b, rng)
	m.Look = appearance(m.Genes)
	m.Phenotype = m.Look.Pattern
	indices := []int{0, 1, 2, 3, 4, 5}
	for i := 5; i > 0; i-- {
		j := int(rng() * float64(i+1))
		if j > i {
			j = i
		}
		indices[i], indices[j] = indices[j], indices[i]
	}
	for _, i := range indices[:3] {
		parent := a
		if rng() < .5 {
			parent = b
		}
		m.IV[i] = parent.IV[i]
	}
	return m
}

type Prediction struct {
	Looks           map[string]int `json:"looks"`
	Samples         int            `json:"samples"`
	SharedAncestors int            `json:"shared_ancestors"`
	Note            string         `json:"note"`
}

func predict(a, b Mon) Prediction {
	r := mathrand.New(mathrand.NewPCG(23, 91))
	p := Prediction{Looks: map[string]int{}, Samples: 512, Note: "Estimativa de 512 combinações; não garante o resultado. Três IVs herdados, três sorteados de 0 a 31."}
	for i := 0; i < p.Samples; i++ {
		look := appearance(inherit(a, b, r.Float64))
		p.Looks[colorName(look.Body)+" · detalhes "+colorName(look.Detail)+" · "+look.Pattern+" · "+look.Mark]++
	}
	anc := map[string]bool{a.ID: true}
	for _, id := range a.Genes.Lineage {
		anc[id] = true
	}
	if anc[b.ID] {
		p.SharedAncestors++
	}
	for _, id := range b.Genes.Lineage {
		if anc[id] {
			p.SharedAncestors++
		}
	}
	return p
}
