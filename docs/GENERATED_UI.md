# Arte de interface gerada

Gerador integrado de imagens do ChatGPT, sem CLI/API externa. Fontes finais em `client/assets/ui/trainer-frame.png` e `aurora-night.png`. A primeira moldura foi revisada para remover transparência indesejada do centro. Masters preservados no projeto; redução nearest para grade 2x feita uma vez pelo Godot. Moldura aplicada como nine-slice; sprites existentes não foram substituídos. Slots pequenos usam estilo simples para evitar excesso de detalhes.

## Prompt da moldura

Use case: stylized-concept. Production game UI asset for Pokemon Aurora, desktop 2D pixel-art RPG. Generate ONE isolated rectangular reusable panel frame, front view, perfectly axis-aligned, centered and almost filling the canvas. Landscape 3:2 canvas. This is an actual nine-slice UI texture, NOT a screenshot or mockup. Flat opaque midnight navy interior (#111b2c), completely uniform empty center taking 85% of width and height. Beautiful restrained futuristic trainer-device frame: dark blue outer outline, crisp teal inner rim, small ivory metallic corner plates and tiny gold corner accents, stepped beveled corners. All ornament strictly within outermost 24 pixels, middle of all four edges straight uniform and tileable. Pokemon handheld-console aesthetic, premium but clean and readable. Strict pixel art, hard square edges, two tones per material, no gradients, no blur, no antialiasing, no lighting bloom, no shadows outside. Exactly one panel, no text, no letters, no symbols, no icons, no creatures, no bars, no controls, no extra panels. Transparent background only outside the frame; interior solid opaque navy. Frame should sit 8 pixels inset from canvas boundary.

## Revisão final da moldura

Make the entire image fully opaque; preserve frame geometry and proportions; interior solid midnight navy #111b2c; no gradients, transparency or text; crisp pixel edges. Preserve 1536x1024, frame inset20px.

## Prompt do cenário

Use case: illustration-story. Asset type: full-screen decorative menu background for Pokemon Aurora desktop game. Landscape 3:2 composition. Strict crisp 2D pixel art in Nintendo DS era aesthetic, square pixel clusters, limited palette, no soft gradients, no antialiasing or blur. A peaceful original trainer village at night, little cozy blue-roof house in bottom left, path winding along bottom edge, trees framing outer edges, distant mountains and angular turquoise aurora ribbons in the upper sky. Warm tiny amber windows. Navy and deep indigo dominant, subdued teal accents. Entire central 70 percent mostly quiet dark navy sky with sparse tiny stars, plenty of negative space to place functional menu panels over it. Atmospheric but low contrast, luminous accents only along far edges. No characters, no Pokemon, no text, no logo, no UI, no frame. This is scenery behind menus, not a playable map.

## Validação

Prévias `previews/art-*.png` renderizadas pelo Godot com fixtures. Testes de fluxo do cliente e dois clientes TCP; build desktop. Referência técnica de recorte nine-slice: https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html

## Revisão Full HD e resposta

O botão `indigo-button.png` foi regenerado depois da auditoria de gameplay, com tab de entrada à esquerda e trilha de recarga na base. Prompt final: botão horizontal vazio para UI 1920×1080, centro navy uniforme, moldura Indigo/DS mais discreta, linha ciano, cantos recortados, tab de estado, marca dourada de habilidade pronta e trilha de cooldown, pixel art rígida sem texto ou efeitos suaves.
## Galeria comparativa Full HD

As 45 vistas anteriores foram capturadas no Godot com dados de teste locais. As cinco pranchas em `previews/atlas/pranchas/antes-*.jpg` serviram de referência ao gerador de imagens do ChatGPT. Os dois estudos de composição estão em `previews/atlas/conceito.png` e `previews/atlas/conceito-estados.png`. O cabeçalho usa `atlas-panorama.png` e a página de pesca usa `lago-celeste.png`. O cliente desenha os controles, textos, barras, retratos e estados em tempo de execução.

Abra `previews/atlas/index.html` para comparar os 45 pares de imagens. Para recriar a galeria no Windows, execute estes comandos a partir de `aurora-desktop`, com Go, Godot e Python com Pillow disponíveis.

```powershell
$env:AURORA_PREVIEW_DIR = (Join-Path (Get-Location) 'build/ui-fixtures')
go -C server test -run '^TestExportPreview$' -count=1
godot --headless --editor --path client --import --quit
godot --path client --resolution 1920x1080 --script qa_gallery.gd -- $env:AURORA_PREVIEW_DIR (Join-Path (Get-Location) 'previews/atlas/depois')
python tools/ui_gallery.py depois
```
