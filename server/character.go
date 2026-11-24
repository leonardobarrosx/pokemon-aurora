package main

import (
	_ "embed"
	"encoding/json"
	"regexp"
	"slices"
)

//go:embed character_catalog.json
var characterJSON []byte
var characterOrder = func() map[string][]string {
	var c struct {
		Order map[string][]string `json:"order"`
	}
	if err := json.Unmarshal(characterJSON, &c); err != nil {
		panic(err)
	}
	return c.Order
}()
var colorPattern = regexp.MustCompile(`^#[0-9a-fA-F]{6}$`)

func setAppearance(p *Player, look, colors map[string]string) error {
	if p.Area != "casa" {
		return errMsg("use o guarda-roupa da sua casa")
	}
	if look["gender"] != "m" && look["gender"] != "f" {
		return errMsg("base do personagem inválida")
	}
	for key, value := range look {
		if key == "gender" {
			continue
		}
		options, ok := characterOrder[key]
		if !ok {
			return errMsg("categoria de peça inválida")
		}
		if value == "" && (key == "hat" || key == "bag" || key == "acc") {
			continue
		}
		if !slices.Contains(options, value) {
			return errMsg("peça não existe no catálogo Indigo")
		}
	}
	for _, key := range []string{"hair", "top", "bottom"} {
		if look[key] == "" {
			return errMsg("escolha cabelo, roupa e parte inferior")
		}
	}
	allowed := []string{"skin", "hair", "top", "top2", "bottom", "bottom2", "shoes", "hat", "hat2", "bag", "bag2", "acc", "acc2"}
	for key, value := range colors {
		if !slices.Contains(allowed, key) || !colorPattern.MatchString(value) {
			return errMsg("cor de peça inválida")
		}
	}
	p.Look = look
	p.Colors = colors
	return nil
}
