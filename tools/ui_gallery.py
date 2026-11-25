"""Package full-size Godot viewport captures into reference boards and a local gallery."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1] / "previews/atlas"
stage = sys.argv[1]
folder = root / stage
boards = root / "pranchas"
boards.mkdir(exist_ok=True)
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
for group in ("menus", "mundo", "arena", "estados"):
    files = sorted((folder / group).glob("*.png"))
    count = 10 if group != "menus" else 9
    for start in range(0, len(files), count):
        batch = files[start:start + count]
        board = Image.new("RGB", (1536, ((len(batch) + 2) // 3) * 322), "#101827")
        draw = ImageDraw.Draw(board)
        for i, file in enumerate(batch):
            x, y = i % 3 * 512, i // 3 * 322
            with Image.open(file) as screenshot:
                assert screenshot.size == (1920, 1080), file
                board.paste(screenshot.convert("RGB").resize((512, 288), Image.Resampling.LANCZOS), (x, y))
            draw.text((x + 12, y + 290), file.stem, font=font, fill="#d8e5ff")
        board.save(boards / f"{stage}-{group}-{start//count+1}.jpg", quality=92)

if stage == "depois":
    keys = sorted({p.relative_to(root/s).as_posix() for s in ("antes","depois") for p in (root/s).glob("*/*.png")})
    names = {
        "entrada":"Cadastro do treinador","equipe":"Equipe","genes":"Mapa genético","genes-rodape":"Mapa genético · rodapé",
        "casa":"Minha casa","guarda-roupa":"Guarda-roupa","mapa":"Mapa da região","loja":"Mochila e loja","breeding":"Laboratório de linhagens",
        "treino":"Treinamento","mercado":"Mercado","profissao":"Ofícios e cozinha","ranking":"Liga e saguão","vila":"Vila Alvorada",
        "jardim":"Jardim de berries","iguaria":"Confirmar iguaria","pc":"Arcade do treinador","lago":"Lago Celeste","ginasio":"Ginásio Raiz",
        "rota":"Trilha das Folhas","safari":"Reserva Orvalho","mina":"Mina da Lua","pesca-aguardando":"Aguardando a fisgada","pesca-fisgada":"Fisgada",
        "capture":"Captura manual","pvp":"Duelo online","gym":"Batalha de ginásio","event":"Encontro de evento","espectador":"Modo espectador",
        "evolucao":"Evolução em combate","arcade":"Chuva de estrelas","corrida":"Circuito Aurora","voo":"Ventos do norte","natacao":"Correnteza azul",
        "anuncio":"Anúncio no mercado","cores":"Seletor de cor","roupas":"Seletor de roupas","saguao-ao-vivo":"Saguão ao vivo",
        "incubadora":"Incubadora ativa","treino-ativo":"Treino ativo","canteiros-plantados":"Canteiros em cultivo"
    }
    inventory = [{s: (s+"/"+k if (root/s/k).exists() else None) for s in ("antes","depois")} | {"id": k[:-4], "name": names.get(Path(k).stem, Path(k).stem)} for k in keys]
    template = """<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pokémon Aurora · interfaces</title><style>*{box-sizing:border-box}body{background:#f5edde;color:#112d38;font:17px system-ui;margin:0}header{background:#112d38;color:#fff9ed;padding:22px 3vw}h1{font-size:clamp(25px,3vw,44px);margin:0 0 6px}header a{color:#9ee2c7;margin-right:18px}nav,main{padding:18px 3vw}nav{display:flex;flex-wrap:wrap;align-items:center;gap:10px}main{display:grid;grid-template-columns:1fr 1fr;gap:1.2vw;padding-top:0}figure{margin:0}img{width:100%;height:auto;border:1px solid #b7ad9b}select,button{font:inherit;padding:.4em .7em}button{cursor:pointer}h2{font-size:20px}@media(max-width:800px){main{display:block}}</style>
<header><h1>Interfaces de Pokémon Aurora</h1><p>Capturas do jogo em 1920 × 1080, com dados de teste. Clique em uma imagem para ampliá-la.</p><a href="conceito.png">Conceito geral</a><a href="conceito-estados.png">Conceito do saguão e jardim</a></header>
<nav><button id="prev" aria-label="Tela anterior">←</button><label>Tela <select></select></label><button id="next" aria-label="Próxima tela">→</button><span id="count"></span></nav><main></main>
<script>const pages=DATA,sel=document.querySelector('select');const groups={arena:'Arena e arcade',estados:'Estados de jogo',menus:'Menus',mundo:'Exploração'};for(const p of pages){let [group,name]=p.id.split('/');sel.add(new Option(groups[group]+' · '+p.name,p.id))}sel.value='menus/equipe';function show(){let p=pages[sel.selectedIndex];document.querySelector('#count').textContent=(sel.selectedIndex+1)+' / '+pages.length;document.querySelector('main').innerHTML=['antes','depois'].map(s=>'<figure><h2>'+(s==='antes'?'Antes':'Depois')+'</h2>'+(p[s]?'<a href="'+p[s]+'"><img alt="'+s+' / '+p.id+'" src="'+p[s]+'"></a>':'Todo o conteúdo cabe na primeira captura.')+'</figure>').join('')}function step(d){sel.selectedIndex=(sel.selectedIndex+d+pages.length)%pages.length;show()}document.querySelector('#prev').onclick=()=>step(-1);document.querySelector('#next').onclick=()=>step(1);sel.onchange=show;show()</script></html>"""
    (root / "index.html").write_text(template.replace("DATA", json.dumps(inventory)), encoding="utf-8")
