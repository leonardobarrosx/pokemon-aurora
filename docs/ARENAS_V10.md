# Arenas V10

Oito layouts revisados: Pewter (pedreira), Cerulean (piscina com rotas secas e correntezas), Celadon (estufa), Cinnabar (laboratório com três travessias), Lavaridge (fontes termais concêntricas), Mahogany (gelo e neve), Ecruteak (templo com vãos e portais) e Eterna (floresta com trilhas e lago).

As grades permanecem autoritativas no servidor. Dimensões e spawns originais foram preservados; foi verificada conectividade por terra entre os dois spawns em cada grade, usando vizinhança ortogonal e exclusão dos obstáculos, lava e água profunda. Isso não substitui testes com hitboxes reais ou balanceamento.

Os atlas SVG em `client/assets/stadiums/v10/` são arte procedural original, com quatro variantes por linha, pixels lógicos de 16 ampliados para células de 32. Mantêm a ordem do renderizador, e os sprites de obstáculos continuam usando os PNG existentes. O cliente carrega os novos atlas quando disponíveis; os outros ginásios mantêm seus recursos anteriores. Os atlas não são as imagens conceituais de pintura digital nem uma reprodução fiel delas.

`python ferramentas/arenas/build.py` preserva os layouts V10 armazenados em `layouts_v10.json`. Testes completos de Godot e Go e capturas de gameplay ainda precisam ser executados em ambiente de desenvolvimento.
