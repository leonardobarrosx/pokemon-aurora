# Interface desktop Aurora

Referência visual: https://www.youtube.com/watch?v=SJMsDaHhAQM (trechos iniciais observados no navegador). O HUD espelhado, o relógio central e a prioridade visual do campo foram adaptados para o combate existente. A exploração usa um HUD próprio.

- Tema compartilhado azul-escuro/ciano, foco de teclado visível, menus com navegação lateral e conteúdo rolável.
- Equipe com cards de sprites originais, IVs, EVs e cores; criador mantém as camadas do Indigo e os créditos.
- Combate com HP, energia, nível, massa, relógio real e ações contextuais de captura/duelo; espectadores têm ação de saída.
- Menus de equipe, mapa, loja, linhagens, treino, mercado, casa, profissão e liga usam a nova estrutura.

As imagens `previews/ui-*.png` são renderizadas no Godot com fixtures de teste, não capturas de sessões de jogadores. A prévia de arena representa um encontro selvagem; ginásio usa o mesmo HUD com ações próprias. Esta mudança é visual e não implementa novos sistemas de gameplay.

Validação: smoke de dois clientes TCP e fluxo do cliente Godot; renderização das telas; testes Go e empacotamento desktop pelo script de build.

## Caderno de campo (mockups do gerador de imagens)

Referências: `docs/referencias/mockup_telas1.png`, `mockup_telas2.png` e o banner `client/assets/ui/aurora-banner.png`.

- Moldura comum: banner do mapa no topo, selo e logo de Aurora, trilho lateral azul-noite com ícones e rótulos em caixa alta, folha de pergaminho com curvas de nível, montanhas e pinheiros desenhados em tempo de execução (`aurora_paper.gd`). Títulos em Oswald (OFL, `client/assets/fonts`) com subtítulo espaçado e traço laranja.
- Botões em relevo: laranja para a ação principal, pergaminho com contorno para as demais, todos com ícones vetoriais (`aurora_icons.gd`).
- Equipe: retrato em disco, nome, nível/tipo, barras segmentadas PS/ATQ/DEF/VEL/ESP/RES (IVs) e "golpe mais forte". Ações da página ficam no cabeçalho.
- Batalha: o jogo continua em **tempo real**. Em vez dos botões por turno do mockup (Lutar/Mochila/Pokémon/Fugir), a barra traz Lutar (clique), golpe especial (Q), Esquiva (Espaço), Capturar (B), Evoluir (V) e Fugir (F), com recarga visível. A arena é recortada e emoldurada; equipe e adversário ficam nas margens. Sem menu lateral durante o combate, para não tirar foco do campo.
- Guarda-roupa: prévia em disco, listas de peças e seletor de cores por amostras (cor principal, secundária, cabelo, pele, chapéu), com uma cor livre no "+".
- Liga e saguão: selo da temporada, prévia "ao vivo" da arena, ranking com medalhas e chat com envio.
- Jardim: contadores no topo, canteiros com desenho da planta por estágio, progresso em %, aviso "Precisa de água!" e colheita.
- Mercado: card de anúncio com preço em destaque e botão Comprar. Linhagens: incubadora com cápsula, progresso e tempo restante.
- HUD de exploração e minijogos usam os mesmos painéis e botões.

As capturas em `previews/atlas/depois/` foram refeitas no Godot 4.3 (Linux, fontes de sistema diferentes das do Windows) com as fixtures de QA.
