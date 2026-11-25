# Revisão de gameplay e resposta

Auditoria feita sobre o cliente Godot, o servidor autoritativo Go e o fluxo real de rede local.

- O servidor simula a 20 Hz, mas o cliente enviava entrada a no máximo 10 Hz. O cliente agora tenta acompanhar os 20 Hz; a autoridade e os limites continuam no servidor.
- Posições chegavam em degraus de snapshots. Treinadores e combatentes agora interpolam; projéteis e movimento de combate extrapolam somente até 120 ms e são reconciliados com o estado autoritativo.
- Ataque, especial e esquiva agora dão pulso local imediato. Dano confirmado pelo servidor produz flash curto e tremor de campo.
- O HUD mostra a recarga de ataque, especial e esquiva e bloqueia visualmente comandos sem energia.
- Menus abrem com transição curta; botões respondem a mouse, foco, pressão e teclado sem alterar a ação enviada ao servidor.
- O campo lógico permanece 512×384 em escala 2× para preservar os pixels do Indigo. A camada de interface passa a 1920×1080 e usa as laterais como área segura.

O feedback local é somente visual. Ele não prevê dano, captura, colisão ou resultado de golpe; esses resultados continuam vindo do servidor.

## Aparência por espécie

As máscaras deixam de inferir anatomia apenas pela cor/altura. Paletas explícitas separam pele, pelagem, chama, efeitos, olhos, boca/língua, nariz, desenhos naturais e característica da espécie. Bulbo, casco, gola, bochechas e anéis podem variar sem recolorir todo o corpo. Gengar e Umbreon foram adicionados ao catálogo de validação usando os sprites da instalação Indigo. Sinais ficam limitados a quatro pixels-fonte por quadro. Saves antigos usam os loci anteriores como fallback; descendentes novos persistem loci regionais independentes.
