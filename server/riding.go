package main

// Montarias, Surf e Dive. O treinador sobe num Pokémon da equipe: em terra
// os de Corrida (montaria), na água os de Natação (Surf, e Dive onde o mapa
// tem fundo do mar). O cliente desenha o Pokémon com o treinador montado.

// rideMon devolve o primeiro Pokémon da equipe com aquela habilidade de montaria.
func rideMon(p *Player, ride string) string {
	for _, id := range p.Team {
		if m := p.mon(id); m != nil && species[m.Species].Ride == ride {
			return id
		}
	}
	return ""
}

// connection devolve a conexão de Dive/Emerge do mapa, se houver.
func (m *AreaMap) connection(dir string) *Connection {
	for i := range m.Connections {
		if m.Connections[i].Dir == dir {
			return &m.Connections[i]
		}
	}
	return nil
}

func underwater(area string) bool {
	m := areaMaps[area]
	return m != nil && m.connection("emerge") != nil
}

// blocks diz se o jogador pode entrar na célula: água só com Surf (um
// Pokémon de Natação na equipe); no fundo do mar tudo que não é parede.
func (w *World) blocks(p *Player, m *AreaMap, v, dir Vec) bool {
	if underwater(p.Area) {
		return m.at(v) == '#'
	}
	if m.at(v) == '~' {
		return rideMon(p, "Natação") == ""
	}
	return m.solid(v, dir)
}

// updateRide troca entre andar, montaria e Surf conforme o chão.
func updateRide(p *Player, m *AreaMap) {
	switch {
	case underwater(p.Area):
		p.Transport, p.Mount = "dive", rideMon(p, "Natação")
	case m.at(p.Pos) == '~':
		p.Transport, p.Mount = "surf", rideMon(p, "Natação")
	case p.Transport == "surf" || p.Transport == "dive":
		p.Transport, p.Mount = "walk", ""
	case p.Transport == "mount" && rideMon(p, "Corrida") == "":
		p.Transport, p.Mount = "walk", ""
	}
}

// dive mergulha (na água de um mapa com fundo do mar) ou volta à superfície.
func (w *World) dive(p *Player, now float64) error {
	m := areaMaps[p.Area]
	if m == nil {
		return nil
	}
	if c := m.connection("emerge"); c != nil {
		pos := p.Pos
		if c.X > 0 || c.Y > 0 {
			pos = Vec{(float64(c.X) + .5) * m.Cell, (float64(c.Y) + .7) * m.Cell}
		}
		w.enterAt(p, c.To, pos, now)
		updateRide(p, areaMaps[c.To])
		return nil
	}
	c := m.connection("dive")
	if c == nil || p.Transport != "surf" {
		return errMsg("só dá para mergulhar surfando em água funda")
	}
	w.enterAt(p, c.To, p.Pos, now)
	updateRide(p, areaMaps[c.To])
	return nil
}
