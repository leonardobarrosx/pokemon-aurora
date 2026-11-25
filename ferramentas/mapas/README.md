# Mapas externos (FireRed)

Os mapas de Aurora são originais, montados com os tilesets do FireRed da
decompilação [pret/pokefirered](https://github.com/pret/pokefirered).

1. Clone só os dados necessários:
   `git clone --depth 1 --filter=blob:none --sparse https://github.com/pret/pokefirered.git /home/claude/ext/pokefirered`
   e `git sparse-checkout set data/tilesets data/layouts`.
   O Emerald Legacy (cRz-Shadows) fica em `/home/claude/crz-shadows/pokemon_emerald_legacy` (caminhos em `gba.py`).
2. `python3 build.py` gera:
   - `client/assets/maps/kanto_below.png` e `kanto_above.png` (atlas de metatiles 16×16; a camada de cima é desenhada por cima do jogador);
   - `client/assets/maps/<área>.json` (camadas, NPCs, pontos);
   - `server/maps/<área>.json` (colisão, grama alta, ressaltos, água, passagens e pontos de chegada).

Pincéis em `build.py`: grama, grama alta, trilha de areia (bordas aprendidas dos
mapas originais em `learn.py`), floresta, água, ressalto, cerca, flores e
construções carimbadas de mapas do FireRed (casa, escola, centro, loja, ginásio,
entrada de caverna). Cada célula ocupa 32 px do mundo (pixels do GBA dobrados).

`grid.py <jogo> <Layout> saída.png` desenha um layout original com coordenadas
para escolher novos carimbos.
