# Créditos — Pokémon Aurora Online

## Fonte principal: Pokémon Indigo / Añil

Os recursos em `indigo/` foram importados da instalação do proprietário em `C:\dev\Pokemon Anil V4.13`. Tilesets, sprites, seguidores, itens e animações mantêm a autoria original. Não são desenhos novos atribuídos a Aurora. `indigo/manifest.json` registra os caminhos de origem, dimensões e hashes SHA-256; a folha original `indigo/tilesets/Creditos.png` foi preservada.

Os mapas de Aurora são novos layouts montados com esses tilesets. Nenhum mapa `.rxdata` foi copiado ou modificado. Os atlas altos são apenas divididos em faixas para compatibilidade com a GPU.

## Criador de personagem

**Gen 4 Character Customization**, de **Coffee Cup / Poltergeist**, com a adaptação do criador de personagem do projeto Pokémon Indigo. O catálogo existente `Data/char_g4.dat` foi convertido para camadas PNG e JSON, preservando peças, ordem de sobreposição, paletas, grupos de cor e poses. O hash do catálogo original está em `indigo/character/catalog.json`.

Uso e edição do pack são permitidos com crédito conforme as instruções do projeto original. Os charsets seguem 256×256 com quatro direções e quatro quadros; pesca usa a folha correspondente do catálogo.

## Pokémon

Os Pokémon na coleção usam os sprites de `Graphics/Pokemon/Front` da instalação indicada. **No mundo e nas batalhas são usados os charsets de `Graphics/Characters/Followers`**, com caminhada e direção. A recoloração genética altera paletas sobre os desenhos existentes; máscaras mais precisas por espécie ainda estão previstas.

Pokémon, personagens e designs pertencem a Nintendo / Creatures / GAME FREAK e aos respectivos autores dos recursos comunitários. Fangame não oficial. Os autores individuais dos tilesets permanecem identificados na folha de créditos importada.

## Referências de mecânicas e recursos complementares

- [Complete Fire Red Upgrade — Skeli789 e colaboradores](https://github.com/Skeli789/Complete-Fire-Red-Upgrade): referência de sistemas; nenhum código desse motor foi incorporado.
- [pret/pokefirered — colaboradores pret](https://github.com/pret/pokefirered): referência complementar de recursos FireRed. Os tiles usados nesta alfa vieram da instalação Indigo/Añil.
- [Godot Engine](https://godotengine.org/license/): motor sob licença MIT. O pacote local inclui o runtime oficial sem modificações.

O protótipo inicial usou sprites externos do PokéAPI; eles foram substituídos pelos recursos da instalação indicada e não fazem parte da versão atual.

## Arte de interface Aurora

Os estudos de composição, a cartografia `ui/atlas-panorama.png` e a ilustração `ui/lago-celeste.png` foram criados com o gerador de imagens do ChatGPT a partir de capturas do Aurora. A galeria comparativa está em `previews/atlas/index.html`.

Moldura trainer-frame.png, cenário aurora-night.png e botão indigo-button.png em ui/ gerados com o gerador integrado de imagens do ChatGPT em 24/11/2026. Prompts e integração documentados em docs/GENERATED_UI.md. Não substituem os sprites e tilesets dos autores acima.
