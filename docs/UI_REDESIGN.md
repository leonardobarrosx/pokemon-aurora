# Interface desktop Aurora

Referência visual: https://www.youtube.com/watch?v=SJMsDaHhAQM (trechos iniciais observados no navegador). O HUD espelhado, o relógio central e a prioridade visual do campo foram adaptados para o combate existente. A exploração usa um HUD próprio.

- Tema compartilhado azul-escuro/ciano, foco de teclado visível, menus com navegação lateral e conteúdo rolável.
- Equipe com cards de sprites originais, IVs, EVs e cores; criador mantém as camadas do Indigo e os créditos.
- Combate com HP, energia, nível, massa, relógio real e ações contextuais de captura/duelo; espectadores têm ação de saída.
- Menus de equipe, mapa, loja, linhagens, treino, mercado, casa, profissão e liga usam a nova estrutura.

As imagens `previews/ui-*.png` são renderizadas no Godot com fixtures de teste, não capturas de sessões de jogadores. A prévia de arena representa um encontro selvagem; ginásio usa o mesmo HUD com ações próprias. Esta mudança é visual e não implementa novos sistemas de gameplay.

Validação: smoke de dois clientes TCP e fluxo do cliente Godot; renderização das telas; testes Go e empacotamento desktop pelo script de build.
