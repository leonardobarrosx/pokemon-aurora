# Direção de Pokémon Aurora Online

Desktop primeiro. Godot para mundo 2D e UI moderna; Go como autoridade de combate, economia e progressão. Casinha como ponto de retorno, vila original e rotas liberadas pela história. Assets existentes do Indigo/Añil, complementados por FireRed somente onde necessário; mapas novos não significam redesenhar tilesets.

## Combate

Pokémon usam os charsets de campo na arena, caminhando em quatro direções. Golpes saem da posição física do parceiro. A direção desejada combina batalha em tempo real, antecipação dos ataques, esquiva, feixes canalizados e interação física. As referências fornecidas incluem PB Ranked e exemplos de Solar Beam, Fire Blast, Ice Beam, Thunderbolt e Hydro Pump. Os links foram registrados; nem todos os vídeos puderam ser reproduzidos no ambiente. A implementação não é apresentada como reprodução visual exata deles.

Porte afeta área de acerto e alcance. Massa afeta aceleração, gasto de esquiva e resistência ao deslocamento. Nível, IVs e EVs afetam atributos. Limites comprimem diferenças extremas de escala para manter leitura e equilíbrio. Criaturas pesadas não devem dominar todas as situações. Capturas exigem controle manual; duelos e desafios permitidos podem usar IA automática.

Evolução em combate não é uma cura: preserva HP proporcional, genes, pedigree, IVs e afinidade. Na alfa, superação exige estar até dois níveis abaixo do requisito, afinidade ≥70, vida ≤25%, dano causado ≥50% do HP máximo e ao menos 30s de desafio. Evolução é opcional (V). Essas regras são ajustáveis, não regras oficiais da franquia.

## Linhagens e criação

DNA fictício com dois alelos por locus, grupos de ligação e recombinação. RNA não é uma segunda herança independente: expressão genética determina o fenótipo. Cores de mesma dominância podem se misturar; recessivos continuam registrados mesmo quando não aparecem. Duas linhagens portadoras podem gerar descendentes com características aparentemente ausentes nos pais.

Seleção da aparência e seleção de IVs são objetivos independentes. O criador pode formar pares, comparar genes, selecionar melhores exemplares, fixar características e comercializar descendentes no mercado compartilhado. O pedigree acompanha cada exemplar. A probabilidade depende dos genótipos concretos: vermelho/amarelo homozigotos podem produzir 100% intermediários; pares portadores produzem distribuições diferentes. A prévia é amostral e deve ser rotulada como estimativa.

Manchas, olhos, língua/boca, cores secundárias e porte devem ser expressos por máscaras autorais do sprite de cada espécie. A alfa usa máscaras aproximadas; a próxima etapa é editar máscaras de indexação sobre os sprites existentes, mantendo o desenho original. Evolução conserva os loci e transforma apenas a maneira de aplicá-los à anatomia nova.

## Vida, economia e comida

Cultivo de berries, pesca, mineração e ofícios se conectam às missões da vila. A visão inclui fazenda com animais comuns, produção de ingredientes e restaurante. Pokémon capturados são parceiros; pratos são itens culinários separados. Iguarias de uma espécie reduzem afinidade apenas na mesma família evolutiva, conforme escolha explícita do usuário. O card deve avisar quais parceiros serão afetados e exigir escolha consciente; alimentação nunca remove um parceiro silenciosamente.

Comida concede bônus curtos e limitados. Presentes, cuidado e convivência recuperam confiança. PvP é a principal fonte de dinheiro recorrente; minijogos pagam pouco e priorizam fichas cosméticas. Repetição do mesmo adversário tem limite de recompensa para reduzir conluio. O servidor deve validar toda transferência, conquista e recompensa.

## Expansões pendentes

Mundo conectado com transições contínuas, mais regiões e líderes, partidas simultâneas por salas, contas e recuperação, banco de dados transacional, ferramentas de moderação, eventos administráveis, temporadas/rankings por regras fixas, replay com equipe usada e normalização de recordes. Rankings competitivos precisam separar nível/faixa de regras; dano bruto e tempo isolados não resumem qualidade de um time.

## Referências fornecidas

- https://github.com/Skeli789/Complete-Fire-Red-Upgrade
- https://github.com/pret/pokefirered
- https://www.youtube.com/shorts/UqGdv9UquEk
- https://youtu.be/23gz_hdNsrc
- https://www.youtube.com/watch?v=ZXRJ48wgikM
- https://youtu.be/h2QvDa3kxUg
- https://youtu.be/TwOK0kxuQJU
- https://youtu.be/w20VtFrVlXE
- https://youtu.be/doMDEKR6nos
- https://youtu.be/LbPZVMoktAU
