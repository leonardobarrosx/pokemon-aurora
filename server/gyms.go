package main

import "strings"

// Gym é um líder de ginásio de uma região e a insígnia que ele entrega.
type Gym struct {
	ID      string `json:"id"`
	Region  string `json:"region"`
	Area    string `json:"area"`
	Town    string `json:"town"`
	Leader  string `json:"leader"`
	Badge   string `json:"badge"`
	Art     string `json:"art"`
	Species int    `json:"species"`
	Level   int    `json:"level"`
	Sprite  string `json:"sprite"`
}

// Oito ginásios por região, na ordem dos jogos. Aurora tem só a Flora por
// enquanto; as outras vagas aparecem como "em construção" no painel.
var gyms = []Gym{
	{"aurora_1", "aurora", "ginasio", "Vila Alvorada", "Flora", "Insígnia Raiz", "in_erika", 1, 12, "ds/hg_gsleader12"},

	{"kanto_1", "kanto", "kt_pewter_city_gym", "Pewter", "Brock", "Insígnia da Rocha", "in_brock", 95, 14, "ds/hg_gsleader14"},
	{"kanto_2", "kanto", "kt_cerulean_city_gym", "Cerulean", "Misty", "Insígnia da Cascata", "in_misty", 130, 18, "ds/hg_gsleader11"},
	{"kanto_3", "kanto", "kt_vermilion_city_gym", "Vermilion", "Lt. Surge", "Insígnia do Trovão", "in_lt_surge", 26, 22, "ds/hg_gsleader9"},
	{"kanto_4", "kanto", "kt_celadon_city_gym", "Celadon", "Erika", "Insígnia Arco-Íris", "in_erika", 2, 26, "ds/hg_gsleader12"},
	{"kanto_5", "kanto", "kt_fuchsia_city_gym", "Fuchsia", "Koga", "Insígnia da Alma", "in_koga", 41, 32, "ds/hg_gsbigfour2"},
	{"kanto_6", "kanto", "kt_saffron_city_gym", "Saffron", "Sabrina", "Insígnia do Pântano", "in_sabrina", 94, 36, "ds/hg_gsleader10"},
	{"kanto_7", "kanto", "kt_cinnabar_island_gym", "Cinnabar", "Blaine", "Insígnia do Vulcão", "in_blaine", 136, 40, ""},
	{"kanto_8", "kanto", "kt_viridian_city_gym", "Viridian", "Giovanni", "Insígnia da Terra", "in_giovanni_gym", 95, 45, "ds/hg_sakaki"},

	{"hoenn_1", "hoenn", "hn_rustboro_city_gym", "Rustboro", "Roxanne", "Insígnia da Pedra", "in_lider1_hoenn", 74, 16, "ds/look_roxanne"},
	{"hoenn_2", "hoenn", "hn_dewford_town_gym", "Dewford", "Brawly", "Insígnia do Punho", "in_lider2_hoenn", 19, 20, "ds/look_brawly"},
	{"hoenn_3", "hoenn", "hn_mauville_city_gym", "Mauville", "Wattson", "Insígnia Dínamo", "in_lider3_hoenn", 135, 24, "ds/look_wattson"},
	{"hoenn_4", "hoenn", "hn_lavaridge_town_gym_1f", "Lavaridge", "Flannery", "Insígnia do Calor", "in_lider4_hoenn", 5, 28, "ds/look_flannery"},
	{"hoenn_5", "hoenn", "hn_petalburg_city_gym", "Petalburg", "Norman", "Insígnia do Equilíbrio", "in_lider5_hoenn", 133, 32, "ds/look_norman"},
	{"hoenn_6", "hoenn", "hn_fortree_city_gym", "Fortree", "Winona", "Insígnia da Pena", "in_lider6_hoenn", 16, 36, "ds/look_winona"},
	{"hoenn_7", "hoenn", "hn_mossdeep_city_gym", "Mossdeep", "Tate e Liza", "Insígnia da Mente", "in_lider7_hoenn", 151, 42, "ds/look_tate"},
	{"hoenn_8", "hoenn", "hn_sootopolis_city_gym_1f", "Sootopolis", "Juan", "Insígnia da Chuva", "in_lider8_hoenn", 134, 46, ""},

	{"johto_1", "johto", "jt_violet_gym", "Violet", "Falkner", "Insígnia Zéfiro", "ds/hg_gsleader1", 16, 18, "ds/hg_gsleader1"},
	{"johto_2", "johto", "jt_azalea_gym", "Azalea", "Bugsy", "Insígnia da Colmeia", "ds/hg_gsleader2", 1, 22, "ds/hg_gsleader2"},
	{"johto_3", "johto", "jt_goldenrod_gym", "Goldenrod", "Whitney", "Insígnia da Planície", "ds/hg_gsleader3", 133, 26, "ds/hg_gsleader3"},
	{"johto_4", "johto", "jt_ecruteak_gym", "Ecruteak", "Morty", "Insígnia da Névoa", "ds/hg_gsleader4", 94, 30, "ds/hg_gsleader4"},
	{"johto_5", "johto", "jt_cianwood_gym", "Cianwood", "Chuck", "Insígnia da Tempestade", "ds/hg_gsleader5", 8, 34, "ds/hg_gsleader5"},
	{"johto_6", "johto", "jt_olivine_gym", "Olivine", "Jasmine", "Insígnia Mineral", "ds/hg_gsleader6", 95, 38, "ds/hg_gsleader6"},
	{"johto_7", "johto", "jt_mahogany_gym_leader_room", "Mahogany", "Pryce", "Insígnia da Geleira", "ds/hg_gsleader7", 131, 42, "ds/hg_gsleader7"},
	{"johto_8", "johto", "jt_blackthorn_gym", "Blackthorn", "Clair", "Insígnia da Ascensão", "ds/hg_gsleader8", 130, 48, "ds/hg_gsleader8"},

	{"sinnoh_1", "sinnoh", "sn_oreburgh_city_gym", "Oreburgh", "Roark", "Insígnia do Carvão", "pt_leader_roark", 74, 20, "ds/pt_roark"},
	{"sinnoh_2", "sinnoh", "sn_eterna_city_gym", "Eterna", "Gardenia", "Insígnia da Floresta", "pt_leader_gardenia", 2, 24, "ds/pt_gardenia"},
	{"sinnoh_3", "sinnoh", "sn_hearthome_city_gym_leader_room", "Hearthome", "Fantina", "Insígnia da Relíquia", "pt_leader_fantina", 94, 28, "ds/pt_fantina"},
	{"sinnoh_4", "sinnoh", "sn_veilstone_city_gym", "Veilstone", "Maylene", "Insígnia do Paralelepípedo", "pt_leader_maylene", 19, 32, "ds/pt_maylene"},
	{"sinnoh_5", "sinnoh", "sn_pastoria_city_gym", "Pastoria", "Wake", "Insígnia do Brejo", "pt_leader_wake", 134, 36, "ds/pt_crasher_wake"},
	{"sinnoh_6", "sinnoh", "sn_canalave_city_gym", "Canalave", "Byron", "Insígnia da Mina", "pt_leader_byron", 95, 40, "ds/pt_byron"},
	{"sinnoh_7", "sinnoh", "sn_snowpoint_city_gym", "Snowpoint", "Candice", "Insígnia do Pingente", "pt_leader_candice", 131, 44, "ds/pt_candice"},
	{"sinnoh_8", "sinnoh", "sn_sunyshore_city_gym_room_3", "Sunyshore", "Volkner", "Insígnia do Farol", "pt_leader_volkner", 135, 50, "ds/pt_volkner"},
}

// gymAt devolve o ginásio cujo líder fica na área (salas do mesmo ginásio
// contam: quem está em qualquer sala de Hearthome desafia a Fantina).
func gymAt(area string) *Gym {
	for i := range gyms {
		g := &gyms[i]
		if g.Area == area {
			return g
		}
	}
	for i := range gyms {
		g := &gyms[i]
		base := g.Area[:strings.LastIndex(g.Area, "_gym")+4]
		if g.Region != "aurora" && strings.HasPrefix(area, base) {
			return g
		}
	}
	return nil
}

// regionAreas conta as áreas jogáveis de cada região (cache).
var regionAreaCount map[string]int

func regionAreas(region string) int {
	if regionAreaCount == nil {
		regionAreaCount = map[string]int{}
		for area := range areaMaps {
			regionAreaCount[regionOf(area)]++
		}
	}
	return regionAreaCount[region]
}

// journey resume a jornada de uma região: exploração e insígnias.
func journey(p *Player, region string) map[string]any {
	visited := 0
	for area, ok := range p.Visits {
		if ok && regionOf(area) == region && areaMaps[area] != nil {
			visited++
		}
	}
	badges := []map[string]any{}
	for _, g := range gyms {
		if g.Region != region {
			continue
		}
		badges = append(badges, map[string]any{"id": g.ID, "leader": g.Leader, "badge": g.Badge, "town": g.Town, "art": g.Art, "sprite": g.Sprite, "area": g.Area, "done": p.Badges[g.ID], "ready": areaMaps[g.Area] != nil || g.Region == "aurora"})
	}
	return map[string]any{"visited": visited, "areas": regionAreas(region), "badges": badges, "goal": regionGoalName[region]}
}

func gymByID(id string) *Gym {
	for i := range gyms {
		if gyms[i].ID == id {
			return &gyms[i]
		}
	}
	return nil
}
