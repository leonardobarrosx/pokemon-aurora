package main

import (
	"crypto/rand"
	"encoding/hex"
	"math"
	mathrand "math/rand/v2"
	"time"
)

type Vec struct {
	X float64 `json:"x"`
	Y float64 `json:"y"`
}

func (v Vec) Add(b Vec) Vec     { return Vec{v.X + b.X, v.Y + b.Y} }
func (v Vec) Mul(s float64) Vec { return Vec{v.X * s, v.Y * s} }
func (v Vec) Len() float64      { return math.Hypot(v.X, v.Y) }
func (v Vec) Unit() Vec {
	if v.Len() < .001 {
		return Vec{1, 0}
	}
	return v.Mul(1 / v.Len())
}
func distance(a, b Vec) float64     { return a.Add(b.Mul(-1)).Len() }
func clamp(x, a, b float64) float64 { return math.Max(a, math.Min(b, x)) }
func bounds(v Vec) Vec              { return Vec{clamp(v.X, 24, 488), clamp(v.Y, 100, 344)} }
func uid() string {
	b := make([]byte, 24)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return hex.EncodeToString(b)
}
func nowSec() float64 { return float64(time.Now().UnixMilli()) / 1000 }

type Species struct {
	Name   string  `json:"name"`
	Type   string  `json:"type"`
	Group  string  `json:"group"`
	HP     float64 `json:"hp"`
	Attack float64 `json:"attack"`
	Ride   string  `json:"ride"`
}

var species = map[int]Species{
	130: {"Gyarados", "Água", "Água", 95, 125, "Natação"},
	2:   {"Ivysaur", "Planta", "Monstro", 60, 62, ""}, 5: {"Charmeleon", "Fogo", "Monstro", 58, 64, ""}, 8: {"Wartortle", "Água", "Monstro", 59, 63, ""}, 26: {"Raichu", "Elétrico", "Campo", 60, 90, ""}, 134: {"Vaporeon", "Água", "Campo", 130, 65, "Natação"}, 135: {"Jolteon", "Elétrico", "Campo", 65, 65, ""}, 136: {"Flareon", "Fogo", "Campo", 65, 130, ""},
	1: {"Bulbasaur", "Planta", "Monstro", 45, 49, ""}, 4: {"Charmander", "Fogo", "Monstro", 39, 52, ""}, 7: {"Squirtle", "Água", "Monstro", 44, 48, ""},
	16: {"Pidgey", "Voador", "Voador", 40, 45, "Voo"}, 19: {"Rattata", "Normal", "Campo", 30, 56, "Corrida"}, 25: {"Pikachu", "Elétrico", "Campo", 35, 55, ""},
	41: {"Zubat", "Voador", "Voador", 40, 45, "Voo"}, 74: {"Geodude", "Pedra", "Mineral", 40, 80, ""}, 95: {"Onix", "Pedra", "Mineral", 35, 45, "Corrida"},
	94: {"Gengar", "Fantasma", "Amorfo", 60, 65, ""}, 197: {"Umbreon", "Noturno", "Campo", 95, 65, ""},
	129: {"Magikarp", "Água", "Água", 20, 10, ""}, 131: {"Lapras", "Água", "Monstro", 130, 85, "Natação"}, 133: {"Eevee", "Normal", "Campo", 55, 55, ""}, 151: {"Mew", "Psíquico", "Lendário", 100, 100, "Voo"},
}

type Mon struct {
	Affinity  int        `json:"affinity"`
	ID        string     `json:"id"`
	Species   int        `json:"species"`
	Level     int        `json:"level"`
	IV        [6]int     `json:"iv"`
	EV        [6]int     `json:"ev"`
	Sex       string     `json:"sex"`
	Phenotype string     `json:"phenotype"`
	Held      string     `json:"held"`
	Genes     Genome     `json:"genes"`
	Look      Appearance `json:"look"`
}

func newMon(s int) Mon {
	m := Mon{ID: uid(), Species: s, Level: 5, Sex: "F", Phenotype: "Original", Affinity: 50, Genes: randomGenome()}
	if mathrand.IntN(2) == 0 {
		m.Sex = "M"
	}
	for i := range m.IV {
		m.IV[i] = mathrand.IntN(32)
	}
	m.Look = appearance(m.Genes)
	m.Phenotype = m.Look.Pattern
	return m
}

type Plot struct {
	At    float64 `json:"at"`
	Water bool    `json:"water"`
}
type Decor struct {
	Kind string `json:"kind"`
	Pos  Vec    `json:"pos"`
}
type Training struct {
	IDs   []string `json:"ids"`
	Route string   `json:"route"`
	At    float64  `json:"at"`
}
type Egg struct {
	Mon Mon     `json:"mon"`
	At  float64 `json:"at"`
}
type Safari struct {
	Species int     `json:"species"`
	Pos     Vec     `json:"pos"`
	At      float64 `json:"at"`
}
type Arcade struct {
	Kind  string  `json:"kind"`
	Pos   Vec     `json:"pos"`
	Start float64 `json:"start"`
	HP    int     `json:"hp"`
	HitAt float64 `json:"hit_at"`
	Seed  float64 `json:"seed"`
	Score int     `json:"score"`
}
type Player struct {
	Facing     int                `json:"facing"`
	Transport  string             `json:"transport"`
	Look       map[string]string  `json:"look"`
	Colors     map[string]string  `json:"colors"`
	Meal       string             `json:"meal"`
	MealUntil  float64            `json:"meal_until"`
	Fishing    float64            `json:"fishing"`
	Prediction Prediction         `json:"prediction"`
	ID         string             `json:"id"`
	Name       string             `json:"name"`
	Area       string             `json:"area"`
	Pos        Vec                `json:"pos"`
	Input      Vec                `json:"-"`
	InputAt    float64            `json:"-"`
	Aim        Vec                `json:"-"`
	Seen       float64            `json:"seen"`
	LastAction float64            `json:"-"`
	Color      string             `json:"color"`
	Theme      string             `json:"theme"`
	Coins      int                `json:"coins"`
	Points     int                `json:"points"`
	XP         int                `json:"xp"`
	Quest      int                `json:"quest"`
	Flags      map[string]int     `json:"flags"`
	Mons       []Mon              `json:"mons"`
	Team       []string           `json:"team"`
	Balls      int                `json:"balls"`
	Seeds      int                `json:"seeds"`
	Berries    int                `json:"berries"`
	Stones     map[string]int     `json:"stones"`
	Plots      [6]Plot            `json:"plots"`
	Decor      []Decor            `json:"decor"`
	Visits     map[string]bool    `json:"visits"`
	Profession string             `json:"profession"`
	Friends    map[string]int     `json:"friends"`
	Gifts      map[string]float64 `json:"gifts"`
	Training   *Training          `json:"training"`
	Egg        *Egg               `json:"egg"`
	Battle     string             `json:"battle"`
	Auto       bool               `json:"auto"`
	Notice     string             `json:"notice"`
	MineAt     float64            `json:"mine_at"`
	Wins       int                `json:"wins"`
	Losses     int                `json:"losses"`
	Rating     int                `json:"rating"`
	Records    map[string]float64 `json:"records"`
	Badges     map[string]bool    `json:"badges"`
	Rewarded   map[string]int     `json:"rewarded"`
	Safari     *Safari            `json:"safari"`
	Arcade     *Arcade            `json:"arcade"`
	Event      string             `json:"event"`
	WarpAt     float64            `json:"-"`
	Running    bool               `json:"running"`
	ReturnArea string             `json:"return_area"`
	ReturnPos  Vec                `json:"return_pos"`
}

func newPlayer(name string, starter int, now float64) *Player {
	m := newMon(starter)
	return &Player{ID: uid(), Name: name, Area: "casa", Pos: Vec{256, 300}, Seen: now, Look: map[string]string{"gender": "m", "hair": "boy2", "top": "jacket", "bottom": "jeans", "hat": "", "acc": "", "bag": ""}, Colors: map[string]string{}, Color: "green", Theme: "verde", Coins: 300, Flags: map[string]int{}, Mons: []Mon{m}, Team: []string{m.ID}, Balls: 10, Seeds: 6, Stones: map[string]int{}, Decor: []Decor{}, Visits: map[string]bool{"casa": true, "vila": true, "jardim": true}, Profession: "Treinador", Friends: map[string]int{}, Gifts: map[string]float64{}, Rating: 1000, Records: map[string]float64{}, Rewarded: map[string]int{}, Badges: map[string]bool{}, Notice: "Bem-vindo a Aurora. Encontre a Professora Íris na vila."}
}
func (p *Player) mon(id string) *Mon {
	for i := range p.Mons {
		if p.Mons[i].ID == id {
			return &p.Mons[i]
		}
	}
	return nil
}

type Fighter struct {
	Facing      int             `json:"facing"`
	Physique    Physique        `json:"physique"`
	Velocity    Vec             `json:"velocity"`
	SlowUntil   float64         `json:"slow_until"`
	Meal        string          `json:"meal"`
	MealUntil   float64         `json:"meal_until"`
	Owner       string          `json:"owner"`
	Name        string          `json:"name"`
	Art         string          `json:"art"`
	Mon         Mon             `json:"mon"`
	Pos         Vec             `json:"pos"`
	HP          float64         `json:"hp"`
	MaxHP       float64         `json:"max_hp"`
	Energy      float64         `json:"energy"`
	ShotAt      float64         `json:"shot_at"`
	SpecialAt   float64         `json:"special_at"`
	DashAt      float64         `json:"dash_at"`
	Invincible  float64         `json:"invincible"`
	Damage      float64         `json:"damage"`
	Auto        bool            `json:"auto"`
	Used        map[string]bool `json:"used"`
	Moves       [4]Move         `json:"moves"`
	MoveAt      [4]float64      `json:"move_at"`
	Eff         [4]float64      `json:"eff"`
	LastMove    int             `json:"last_move"`
	LastMoveAt  float64         `json:"last_move_at"`
	StunUntil   float64         `json:"stun_until"`
	ChargeUntil float64         `json:"charge_until"`
	ChargeDir   Vec             `json:"-"`
	ChargeSpeed float64         `json:"-"`
	ChargeSlot  int             `json:"-"`
	ChargeHit   bool            `json:"-"`
}
type Projectile struct {
	Pos    Vec     `json:"pos"`
	Vel    Vec     `json:"vel"`
	Owner  string  `json:"owner"`
	Type   string  `json:"type"`
	Life   float64 `json:"life"`
	Damage float64 `json:"damage"`
	Radius float64 `json:"radius"`
	Move   string  `json:"move"`
	Knock  float64 `json:"knock"`
}
type Blast struct {
	Pos    Vec     `json:"pos"`
	Owner  string  `json:"owner"`
	Type   string  `json:"type"`
	At     float64 `json:"at"`
	Radius float64 `json:"radius"`
	Done   bool    `json:"done"`
	Move   string  `json:"move"`
	Damage float64 `json:"damage"`
	Knock  float64 `json:"knock"`
	Wave   bool    `json:"wave"`
}
type Battle struct {
	Beams       []Beam       `json:"beams"`
	PauseUntil  float64      `json:"pause_until"`
	ID          string       `json:"id"`
	Kind        string       `json:"kind"`
	Gym         string       `json:"gym"`
	Fighters    [2]*Fighter  `json:"fighters"`
	Projectiles []Projectile `json:"projectiles"`
	Blasts      []Blast      `json:"blasts"`
	Start       float64      `json:"start"`
	End         float64      `json:"end"`
	Winner      string       `json:"winner"`
	Log         string       `json:"log"`
	// Cutins: arte de batalha do treinador ao lançar Pokébola, trocar de
	// Pokémon ou dar um comando de ataque especial.
	Cutins []Cutin `json:"cutins"`
}
type Cutin struct {
	Side int     `json:"side"`
	Kind string  `json:"kind"`
	Text string  `json:"text"`
	At   float64 `json:"at"`
}
type Message struct {
	Name string  `json:"name"`
	Text string  `json:"text"`
	At   float64 `json:"at"`
}
type Listing struct {
	ID     string `json:"id"`
	Seller string `json:"seller"`
	Name   string `json:"name"`
	Mon    Mon    `json:"mon"`
	Price  int    `json:"price"`
}
type World struct {
	Players  map[string]*Player `json:"players"`
	Sessions map[string]string  `json:"sessions"`
	Battles  map[string]*Battle `json:"battles"`
	Chat     []Message          `json:"chat"`
	Queue    []string           `json:"queue"`
	Market   []Listing          `json:"market"`
}

func newWorld() *World {
	return &World{Players: map[string]*Player{}, Sessions: map[string]string{}, Battles: map[string]*Battle{}, Chat: []Message{}, Queue: []string{}, Market: []Listing{}}
}
