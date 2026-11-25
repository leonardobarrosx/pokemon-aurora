# Pokémon Aurora Online — alfa desktop

> Jogo próprio, separado do projeto de tradução Pokémon Indigo PT-BR. Este repositório nasceu da pasta `aurora-desktop/` daquele projeto, com o histórico preservado.

Cliente **Godot 4 / GDScript**, servidor autoritativo **Go**. Região original Aurora, com assets reaproveitados do Pokémon Indigo / Añil instalado em `C:\dev\Pokemon Anil V4.13`. Este é um primeiro protótipo jogável, não um MMO terminado nem um serviço público já hospedado.

## Jogar no Windows

Na máquina em que esta alfa foi preparada, abra **`Jogar.cmd`**. O launcher inicia o backend local se necessário e abre o cliente desktop. Para um segundo treinador, use `./Iniciar.ps1 -Perfil segundo`. Perfis separados recebem chaves de acesso independentes. Para outro computador, inicie o servidor com `-listen 0.0.0.0:8787` e use `./Iniciar.ps1 -Perfil amigo -Servidor http://IP-DO-SERVIDOR:8787`. Na internet, o servidor precisa de hospedagem e proxy HTTPS; esta entrega valida o processo local e não publica um servidor de produção.

Progresso do launcher: `%LOCALAPPDATA%\PokemonAurora\server\world.json`. Chave do cliente: `user://<perfil>.cfg` do Godot. Preserve ambos; ainda não há contas com senha, recuperação ou launcher de atualização. O servidor continua salvando em segundo plano depois que o cliente fecha.

Para desenvolver:

```powershell
cd server
go run .
# Em outro terminal, na raiz deste repositório:
godot --path client
```

Para recompilar: `./ferramentas/build.ps1 -Go caminho/go.exe -Godot caminho/Godot_console.exe`. O build local usa o runtime oficial Godot com um PCK; binários e saves ficam fora do Git. Go não depende de bibliotecas de terceiros.

## Controles

WASD/setas: movimentar. E: interagir/puxar a vara/capturar. M: mapa. T: bicicleta. Clique: mirar e lançar ataque. Q: habilidade especial. Espaço: esquiva. B: Poké Bola. V: tentar evolução do parceiro ativo. F: abandonar batalha. Esc: fechar menu/sair do minijogo/espectador.

Comece conversando com Íris na vila, resgate a missão no diário e explore a rota. A história libera mina, ginásio, Safari e lago. Capturas normais exigem batalha manual; o Safari usa pontaria. Os tempos de cultivo e ovos estão acelerados para testar a alfa.

## O que está implementado

- Casa, guarda-roupa de camadas do Indigo, decoração comprável e reposicionável; mapa original com oito áreas e colisões básicas.
- Catálogo original `char_g4.dat`: 127 peças, corpos, cabelos, roupas, mochilas, chapéus e acessórios. Cores por região; poses exportadas do projeto original.
- Pokémon de campo também nas batalhas: sprites `Followers` com quatro direções; movimento, projéteis, áreas anunciadas, feixes, esquiva, energia e recargas. Peso/porte afetam aceleração, colisão e empurrão. Sprites frontais ficam nos cards de coleção.
- Servidor de simulação a 20 Hz; snapshots HTTP a 10 Hz. Dois clientes compartilham presença, fila PvP, chat, espectadores e rankings. Não há jogadores falsos preenchendo as listas.
- Captura, equipe de até seis, troca automática após desmaio, EVs, IVs, itens segurados, jardim, mineração, profissões, presentes e cinco missões de introdução.
- Genética diploide: pigmentos intermediários, dominância/recessividade, regiões anatômicas por espécie, padrões e sinais discretos, porte, recombinação, pedigree, previsão amostral e três IVs herdados. Genes/IVs acompanham evolução e mercado.
- Evoluções iniciais, Eevee com pedras, Raichu e Gyarados. Evolução durante combate por nível ou superação condicionada a vínculo, desempenho e vida baixa; proporção de HP é preservada.
- Mercado compartilhado com reserva do Pokémon anunciado, compra/cancelamento e transferência atômica em memória protegida por mutex.
- Pesca com janela de fisgada, minijogo de desvio de projéteis e circuitos de corrida/voo/natação; recompensas menores que PvP.
- Receitas simples com um buff temporário por vez. Iguaria de Magikarp afeta somente a afinidade de Magikarp/Gyarados e não consome Pokémon da coleção. Cuidado recupera afinidade.
- Evento de Mew aos domingos UTC, instanciado por treinador, com uma captura por conta/evento.

## Limites desta alfa

Não implementa todo o conteúdo de Essentials/CFRU, todas as espécies, todas as evoluções, todos os golpes, campanhas extensas ou um mundo contínuo completo. Ainda faltam matchmaking competitivo robusto, temporadas, moderação, recuperação de contas, migração de banco, otimização para muitos jogadores, testes em internet real e balanceamento. O JSON é um armazenamento de protótipo para um processo; não substitui banco transacional em produção.

A fazenda com animais comuns, restaurante gerenciável e cadeia completa de ingredientes estão no design, não estão construídos como sistemas completos. Os circuitos são protótipos curtos. Safari ainda não calcula a curva física de um arremesso giratório. A máscara genética visual cobre explicitamente as espécies disponíveis e as três poses importadas; novas espécies preservam o desenho original até receberem uma paleta anatômica verificada.

## Assets e preservação

`tools/import_indigo.py` copia tilesets, seguidores, animações, retratos e itens da instalação indicada. `tools/export_indigo_character.rb` lê o catálogo Ruby e exporta as camadas sem executar o jogo. `client/assets/indigo/manifest.json` registra origem, dimensões e SHA-256. Atlas altos são divididos em faixas, sem suavizar ou redesenhar. O mundo usa coordenadas lógicas 512×384; os menus desktop usam uma camada de interface 1280×832.

Não foram alterados os arquivos do jogo instalado, os `.rxdata`, os mapas ou o PBS. Layouts de Aurora estão em `client/indigo_maps.gd`. O mundo permanece em coordenadas 512×384 e os menus usam uma camada Full HD de 1920×1080. Referências e créditos: [CREDITS.md](client/assets/CREDITS.md). As imagens em `previews/` são capturas do cliente com uma fixture de QA, não prova de jogadores conectados em produção.

## Validação

`go test ./...` cobre herança recessiva, mistura de pigmentos, IVs, evolução sem cura gratuita, afinidade por família, captura manual, mercado concorrente, persistência, autorização, movimento, colisão de projéteis e pesca. `go vet ./...` e importação/execução headless do Godot complementam os testes. `tools/smoke_network.py` verifica o servidor real com dois clientes HTTP. `client/qa_preview.gd` renderiza os mesmos menus/cenários para inspeção em PNG.
