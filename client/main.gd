extends Node2D

const AREAS={"casa":"Meu cantinho","vila":"Vila Alvorada","rota":"Trilha das Folhas","jardim":"Jardim de berries","mina":"Mina da Lua","ginasio":"Ginásio Raiz","safari":"Reserva Orvalho","lago":"Lago Celeste"}
const QUESTS=["Converse com Íris na vila","Capture um parceiro na rota","Plante, regue e colha uma berry","Encontre um cristal na mina","Vença Flora no Ginásio Raiz"]
const ACCENT=Color("64d9e5")
var hud:Control
var previous_focus:Control
var data:Dictionary={}
var token=""
var endpoint="http://127.0.0.1:8787"
var profile="principal"
var http:HTTPRequest
var request_busy=false
var commands:Array=[]
var timer=0.0
var clock_offset=0.0
var moving=false
var spectate=""
var screen=""
var selected:Array[String]=[]
var placing=""
var view:Node2D
var ui:Control
var overlay:Control
var status:Label
var overlay_body:VBoxContainer
var name_input:LineEdit
var server_input:LineEdit
var starter:int=1
var message_input:LineEdit
var last_notice=""
var refresh_pending=false
var font:SystemFont
var preview_mode=false

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=").validate_filename()
		if arg=="--preview":preview_mode=true
		if arg.begins_with("--server="):endpoint=arg.trim_prefix("--server=")
	font=SystemFont.new();font.font_names=PackedStringArray(["Segoe UI","Arial"])
	var config=ConfigFile.new()
	if config.load("user://%s.cfg"%profile)==OK:
		token=config.get_value("session","token","")
		var saved_endpoint=str(config.get_value("session","server",endpoint))
		var override=false
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--server="):override=true
		if not override:endpoint=saved_endpoint
		elif saved_endpoint!=endpoint:token=""
	view=Node2D.new();view.set_script(load("res://world_view.gd"));view.game=self;view.position=Vector2(128,32);view.scale=Vector2(2,2);add_child(view)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	ui.theme=preload("res://aurora_theme.gd").make(font)
	hud=Control.new();hud.set_script(load("res://aurora_hud.gd"));hud.game=self;ui.add_child(hud)
	http=HTTPRequest.new();http.timeout=5;add_child(http);http.request_completed.connect(received)
	if token!="":send({"type":"poll"})
	else:login()
	if preview_mode:
		get_tree().create_timer(3).timeout.connect(func(): get_viewport().get_texture().get_image().save_png("user://aurora-preview.png"))

func box(color:Color,radius:int=4)->StyleBoxFlat:
	return preload("res://aurora_theme.gd").surface(color,mini(radius,4))

func label(parent:Node,text:String,size:int=16,color:Color=Color("edf2fa"))->Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l

func btn(parent:Node,text:String,callback:Callable,width:float=0)->Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(width,40);b.pressed.connect(callback);parent.add_child(b);return b

func panel(parent:Node,color:Color=Color("172237"))->PanelContainer:
	var p=PanelContainer.new();p.add_theme_stylebox_override("panel",box(color));parent.add_child(p);return p

func column(parent:Node,gap:int=10)->VBoxContainer:
	var c=VBoxContainer.new();c.add_theme_constant_override("separation",gap);parent.add_child(c);return c

func row(parent:Node,gap:int=10)->HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",gap);parent.add_child(r);return r

func server_time()->float:return Time.get_unix_time_from_system()+clock_offset

func send(command:Dictionary):
	commands.append(command)

func dispatch(command:Dictionary):
	request_busy=true
	var headers=PackedStringArray(["Content-Type: application/json"])
	if token!="":headers.append("Authorization: Bearer "+token)
	refresh_pending=command.type not in ["poll","input"]
	var err=http.request(endpoint+"/api",headers,HTTPClient.METHOD_POST,JSON.stringify(command))
	if err!=OK:request_busy=false;notice("Não foi possível conectar ao servidor.")

func received(_result:int,code:int,_headers:PackedStringArray,body:PackedByteArray):
	request_busy=false
	var response=JSON.parse_string(body.get_string_from_utf8())
	if not response is Dictionary:
		notice("Servidor indisponível. Inicie o servidor Go e tente novamente.");return
	if code==401:token="";login();return
	if response.has("token"):
		token=response.token
		var config=ConfigFile.new();config.set_value("session","token",token);config.set_value("session","server",endpoint);config.save("user://%s.cfg"%profile)
		close_panel()
	if response.has("player"):
		data=response;clock_offset=float(response.now)-Time.get_unix_time_from_system();refresh_sidebar()
		if data.player.notice!=last_notice:last_notice=data.player.notice;notice(last_notice)
		if refresh_pending and screen in ["equipe","breeding","treino","loja","casa","vila","jardim","pc","profissao","mercado","ranking","mapa"]:open_panel(screen)
	if response.has("error"):notice(str(response.error).capitalize())
	view.queue_redraw()

func _process(delta:float):
	timer+=delta
	if view:view.queue_redraw()
	if hud and not data.is_empty():hud.update_values()
	if not data.is_empty() and token!="" and timer>=.1:
		timer=0
		if not request_busy and commands.is_empty():
			var dir=Vector2.ZERO
			if screen=="":
				dir=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
			moving=dir.length()>0
			var aim=view.get_local_mouse_position()
			dispatch({"type":"input","move":{"x":dir.x,"y":dir.y},"aim":{"x":aim.x,"y":aim.y}})
	if not request_busy and not commands.is_empty():dispatch(commands.pop_front())

func notice(text:String):
	if is_instance_valid(status):status.queue_free()
	status=label(ui,text,14,Color("f2e3bd"));status.position=Vector2(250,740);status.size=Vector2(780,36)
	status.add_theme_stylebox_override("normal",box(Color("192239"),4));status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var current_id=status.get_instance_id()
	get_tree().create_timer(5).timeout.connect(func():
		if is_instance_id_valid(current_id):instance_from_id(current_id).queue_free())

func login():
	modal("Sua história começa aqui","Conecte seu treinador ao mundo de Aurora.");screen="login"
	var c=column(overlay_body,18)
	label(c,"NOME DO TREINADOR",13,ACCENT);name_input=LineEdit.new();name_input.placeholder_text="Como podemos chamar você?";name_input.max_length=20;name_input.custom_minimum_size.y=44;c.add_child(name_input)
	label(c,"SEU PRIMEIRO PARCEIRO",13,ACCENT)
	var starters=row(c,16)
	for id in [1,4,7]:
		var card=panel(starters);card.custom_minimum_size.x=250;var cc=column(card);var im=TextureRect.new();im.texture=view.mon_texture({"species":id});im.custom_minimum_size=Vector2(140,130);im.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;im.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;cc.add_child(im)
		btn(cc,{1:"Bulbasaur",4:"Charmander",7:"Squirtle"}[id],func():starter=id;notice("Parceiro escolhido: "+{1:"Bulbasaur",4:"Charmander",7:"Squirtle"}[id]))
	label(c,"ENDEREÇO DO SERVIDOR",13,ACCENT);server_input=LineEdit.new();server_input.text=endpoint;c.add_child(server_input)
	btn(c,"Começar minha jornada",func():endpoint=server_input.text.strip_edges().trim_suffix("/");send({"type":"register","name":name_input.text,"starter":starter}))
	label(c,"O progresso fica no servidor. Esta instalação guarda sua chave de acesso.",14,Color("9eb2ad"))

func modal(title:String,subtitle:String):
	if not is_instance_valid(overlay):previous_focus=get_viewport().gui_get_focus_owner()
	else:overlay.queue_free()
	hud.visible=false
	overlay=Control.new();overlay.size=Vector2(1280,832);ui.add_child(overlay)
	var shade=ColorRect.new();shade.color=Color("0a1020");shade.color.a=.94;shade.size=Vector2(1280,832);overlay.add_child(shade)
	var brand=label(overlay,"A U R O R A   /   CENTRAL DO TREINADOR",13,ACCENT);brand.position=Vector2(28,20)
	var heading=label(overlay,title,30);heading.position=Vector2(240,52)
	var sub=label(overlay,subtitle,14,Color("9eaec5"));sub.position=Vector2(240,94)
	var close=btn(overlay,"ESC  Fechar",close_panel,116);close.position=Vector2(1136,12)
	var navigation=column(overlay,7);navigation.position=Vector2(24,138);navigation.size=Vector2(192,650)
	for entry in [["equipe","01   Equipe"],["mapa","02   Mapa"],["loja","03   Mochila e loja"],["breeding","04   Linhagens"],["treino","05   Treinamento"],["mercado","06   Mercado"],["casa","07   Minha casa"],["profissao","08   Profissão"],["ranking","09   Liga e saguão"]]:
		var nav=btn(navigation,entry[1],func():open_panel(entry[0]),192)
		nav.alignment=HORIZONTAL_ALIGNMENT_LEFT
		if entry[0]==screen:nav.add_theme_stylebox_override("normal",box(Color("27475b")))
	var shell=panel(overlay,Color("111b2c"));shell.position=Vector2(236,132);shell.size=Vector2(1020,676)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;shell.add_child(scroll)
	overlay_body=column(scroll,16);overlay_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	close.grab_focus()
	if data.is_empty():navigation.hide();brand.text="A U R O R A   /   UMA NOVA JORNADA"

func close_panel():
	if is_instance_valid(overlay):overlay.queue_free();overlay=null
	screen="";selected.clear()
	if hud:hud.visible=true;hud.refresh()
	if is_instance_valid(previous_focus):previous_focus.grab_focus()

func refresh_sidebar():
	if hud and not data.is_empty():hud.refresh()

func team_mon(index:int)->Dictionary:
	if data.is_empty() or index>=data.player.team.size():return {}
	var id=data.player.team[index]
	for m in data.player.mons:
		if m.id==id:return m
	return {}

func stat_numbers(values:Array)->String:
	var numbers=PackedStringArray()
	for value in values:numbers.append(str(int(value)))
	return " · ".join(numbers)

func mon_name(m:Dictionary)->String:
	return str(data.get("species",{}).get(str(int(m.species)),{}).get("name","Pokémon"))

func mon_card(parent:Node,m:Dictionary,choose:bool=false):
	var card=panel(parent,Color("17273b") if selected.has(m.id) else Color("131f32"));card.custom_minimum_size.x=300
	var c=column(card,9)
	var top=row(c);var index=label(top,"#%03d"%int(m.species),12,ACCENT);index.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(top,"NV. %d"%m.level,13,Color("eac57d"))
	var image=TextureRect.new();image.texture=view.mon_texture(m);image.custom_minimum_size=Vector2(260,100);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;c.add_child(image)
	label(c,mon_name(m),24)
	label(c,"%s  /  Geração %d  /  %s"%[m.sex,m.genes.generation,m.look.pattern],12,Color("a6b6ce"))
	var affinity=row(c);label(affinity,"VÍNCULO",10,ACCENT);label(affinity,"%d / 100"%m.get("affinity",50),12)
	var stats=row(c,8)
	var names=["HP","ATQ","DEF","A.E","D.E","VEL"]
	for i in 6:
		var cell=column(stats,3);cell.custom_minimum_size.x=38;label(cell,names[i],10,Color("9aaec8"));label(cell,str(int(m.iv[i])),18)
	label(c,"EVs  "+stat_numbers(m.ev),11,Color("a7bab2"))
	var gene=row(c,8)
	for key in ["body","detail","eye","mouth"]:
		var swatch=ColorRect.new();swatch.custom_minimum_size=Vector2(24,6);swatch.color=Color(m.look[key]) if m.look[key]!="original" else Color("96bda4");swatch.tooltip_text={"body":"Corpo","detail":"Detalhes","eye":"Olhos","mouth":"Boca"}[key]+": "+m.look[key];gene.add_child(swatch)
	if choose:
		var select=btn(c,("Selecionado  ✓" if selected.has(m.id) else "Selecionar parceiro"),func():
			if selected.has(m.id):selected.erase(m.id)
			else:selected.append(m.id)
			open_panel(screen))
		if selected.has(m.id):select.add_theme_stylebox_override("normal",box(Color("15566b")))
	else:btn(c,"Ver genes e linhagem",func():genome_panel(m))

func open_panel(which:String):
	if data.is_empty():return
	screen=which
	var titles={"equipe":["Seus parceiros","Uma equipe, muitas histórias. Escolha até seis Pokémon."],"mapa":["Explore Aurora","Novos caminhos se abrem ao longo da sua jornada."],"loja":["Mochila e suprimentos","Prepare a próxima saída e encontre objetos para sua casa."],"breeding":["Laboratório de linhagens","Observe os genes. Escolha os pais. Descubra novas possibilidades."],"mercado":["Mercado de treinadores","Exemplares com história, genética e potencial."],"treino":["Centro de treinamento","Escolha os parceiros, a rota e o atributo que deseja desenvolver."],"profissao":["Uma vida em Aurora","Escolha seu ofício e prepare refeições."],"ranking":["Liga de Aurora","Batalhas reais, conquistas compartilhadas."],"casa":["Minha casa","Aparência do treinador, decoração e computador."],"vila":["Gente de Alvorada","Pequenos encontros constroem grandes amizades."],"jardim":["Cultive seu cantinho","Plante, regue, espere 90 segundos e colha."],"pc":["Aurora Arcade","30 segundos. Seu parceiro. Um novo recorde."]}
	var title=titles.get(which,[which,""]);modal(title[0],title[1]);screen=which
	var p:Dictionary=data.player
	match which:
		"mapa":
			var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",12);overlay_body.add_child(grid)
			for id in AREAS:
				var card=panel(grid);card.custom_minimum_size.x=462;var c=column(card);label(c,AREAS[id],22);label(c,"Visitado" if p.visits.get(id,false) else "Novo destino",13,ACCENT);var r=row(c);btn(r,"Ir a pé / bicicleta",func():send({"type":"travel","area":id});close_panel());btn(r,"Usar Fly",func():send({"type":"travel","area":id,"fly":true});close_panel())
		"equipe","breeding","treino":
			if which=="equipe":
				var actions=row(overlay_body);btn(actions,"Salvar equipe selecionada",func():send({"type":"team","ids":selected}));btn(actions,"Conquista da Pokédex",func():send({"type":"dex"}));btn(actions,"Evoluir selecionado",func():send({"type":"evolve","ids":selected}));label(overlay_body,"A ordem de seleção define quem entra primeiro na batalha. Equipe atual: %d/6."%p.team.size(),14)
			if which=="breeding":
				var r=row(overlay_body);btn(r,"Prever cruzamento",func():send({"type":"predict","ids":selected}));btn(r,"Cruzar · 3 berries",func():send({"type":"breed","ids":selected}));btn(r,"Chocar ovo",func():send({"type":"hatch"}))
				label(overlay_body,"Selecione dois parceiros de sexos diferentes e do mesmo grupo de ovos. Incubação: 3 minutos.",14)
				if p.get("egg")!=null:label(overlay_body,"Ovo na incubadora · %ds restantes"%max(0,180-int(server_time()-float(p.egg.at))),16,ACCENT)
				var prediction=p.get("prediction",{})
				if prediction.get("samples",0)>0:
					label(overlay_body,"PREVISÃO GENÉTICA · %d amostras · %d ancestrais compartilhados"%[prediction.samples,prediction.shared_ancestors],14,ACCENT)
					var possibilities:Array=[]
					for k in prediction.looks:possibilities.append([prediction.looks[k],k])
					possibilities.sort_custom(func(a,b):return a[0]>b[0])
					for item in possibilities.slice(0,6):label(overlay_body,"%.1f%%  %s"%[100.0*float(item[0])/float(prediction.samples),item[1]],14)
			if which=="treino":
				label(overlay_body,"1 EV a cada 30s · máximo 252 por atributo / 510 no total · até 8h offline",15)
				var r=row(overlay_body)
				for pair in [["rota","Velocidade"],["mina","Defesa"],["lago","HP"]]:btn(r,pair[1],func():send({"type":"train","ids":selected,"area":pair[0]}))
				btn(r,"Parar treino",func():send({"type":"stop_train"}))
				label(overlay_body,"Treino ativo: "+str(p.training.route if p.training!=null else "nenhum"),16,ACCENT)
			var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);overlay_body.add_child(grid)
			for m in p.mons:mon_card(grid,m,true)
		"loja":
			label(overlay_body,"Mochila: %d Poké Bolas · %d berries · %d sementes"%[p.balls,p.berries,p.seeds],18,ACCENT)
			var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);overlay_body.add_child(grid)
			for item in [["bola","Poké Bola","20 moedas"],["semente","Semente de berry","10 moedas"],["planta","Samambaia","60 moedas"],["estante","Estante de pesquisa","120 moedas"],["aquario","Aquário azul","180 moedas"],["pelucia","Pelúcia de Pikachu","15 fichas"]]:
				var c=column(panel(grid));c.custom_minimum_size.x=270;label(c,item[1],20);label(c,item[2],16,ACCENT);btn(c,"Comprar",func():send({"type":"buy","value":item[0]}))
			label(overlay_body,"Pedras e itens: "+str(p.stones),14)
		"casa":
			btn(overlay_body,"Abrir criador de personagem Indigo",wardrobe_menu)
			var r:HBoxContainer

			label(overlay_body,"PAPEL DE PAREDE",14,ACCENT);r=row(overlay_body)
			for color in ["verde","azul","lilas"]:btn(r,color.capitalize(),func():send({"type":"theme","value":color}))
			label(overlay_body,"MÓVEIS · escolha e clique no chão do quarto para posicionar",14,ACCENT)
			for d in p.decor:btn(overlay_body,"Mover "+d.kind,func():placing=d.kind;close_panel();notice("Clique no chão para posicionar o móvel."))
			btn(overlay_body,"Abrir computador",func():open_panel("pc"));btn(overlay_body,"Sair para a vila",func():send({"type":"travel","area":"vila"});close_panel())
		"vila":
			for npc in ["Íris","Lia","Theo"]:
				var c=column(panel(overlay_body));label(c,npc+" · amizade "+str(p.friends.get(npc,0)),22);var r=row(c);btn(r,"Conversar",func():send({"type":"talk","value":npc}));btn(r,"Presentear berry",func():send({"type":"gift","value":npc}))
		"jardim":
			var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);overlay_body.add_child(grid)
			for i in 6:
				var c=column(panel(grid));c.custom_minimum_size.x=270;label(c,"Canteiro %d"%(i+1),22);var plot=p.plots[i];label(c,"Vazio" if float(plot.at)==0 else ("Regado" if plot.water else "Precisa de água"),14,ACCENT);btn(c,"Plantar",func():send({"type":"plant","index":i}));btn(c,"Regar",func():send({"type":"water","index":i}));btn(c,"Colher",func():send({"type":"harvest","index":i}))
		"pc":
			for pair in [["arcade","Chuva de estrelas","Desvie dos projéteis com seu primeiro parceiro."],["Corrida","Circuito Aurora","Bicicleta ou montaria. Mantenha-se na pista."],["Voo","Ventos do norte","Requer um parceiro de voo."],["Natação","Correnteza azul","Requer um parceiro de natação."]]:
				var c=column(panel(overlay_body));label(c,pair[1],22);label(c,pair[2],15);btn(c,"Jogar",func():send({"type":"arcade","value":pair[0]});close_panel())
		"profissao":profession_menu()
		"mercado":market_menu()
		"ranking":lobby_menu()

func wardrobe_menu():
	modal("Seu treinador, do seu jeito","Catálogo original do Pokémon Indigo · Coffee Cup / Poltergeist");screen="wardrobe"
	var draft:Dictionary=data.player.get("look",{}).duplicate(true)
	if draft.is_empty():draft={"gender":"m","hair":"boy2","top":"jacket","bottom":"jeans","hat":"","acc":"","bag":""}
	var colors:Dictionary=data.player.get("colors",{}).duplicate(true)
	var layout=row(overlay_body,28);var preview_card=panel(layout);preview_card.custom_minimum_size=Vector2(270,420);var pc=column(preview_card)
	var portrait=TextureRect.new();portrait.texture=view.indigo.compose(draft,colors,"front");portrait.custom_minimum_size=Vector2(240,300);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;pc.add_child(portrait)
	label(pc,"PRÉVIA DO TREINADOR",12,ACCENT);label(pc,"Caminhada, corrida, bicicleta,\npesca e retratos preservados.",14)
	var controls=column(layout,10);controls.custom_minimum_size.x=620
	var gender=OptionButton.new();gender.add_item("Base masculina");gender.add_item("Base feminina");gender.selected=0 if draft.gender=="m" else 1;controls.add_child(gender);gender.item_selected.connect(func(i):draft.gender="m" if i==0 else "f";portrait.texture=view.indigo.compose(draft,colors,"front"))
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",10);controls.add_child(grid)
	var names={"hair":"Cabelo","top":"Roupa","bottom":"Parte inferior","hat":"Chapéu","acc":"Acessório","bag":"Mochila"}
	for slot in names:
		var c=column(grid,4);c.custom_minimum_size.x=295;label(c,names[slot],14,ACCENT);var select=OptionButton.new();select.custom_minimum_size.y=38;c.add_child(select)
		var choices:Array=[]
		if slot in ["hat","bag","acc"]:choices.append("")
		choices.append_array(view.indigo.catalog.order[slot])
		for choice in choices:
			var key=slot+"|"+str(choice)+"|"+str(draft.gender);var part=view.indigo.catalog.parts.get(key,view.indigo.catalog.parts.get(slot+"|"+str(choice)+"|x",{}));var name=str(part.get("name",[choice,choice])[1]) if choice!="" else "Nenhum";select.add_item(name)
		select.selected=max(0,choices.find(draft.get(slot,"")))
		select.item_selected.connect(func(i):draft[slot]=choices[i];portrait.texture=view.indigo.compose(draft,colors,"front"))
	var color_row=row(controls)
	for pair in [["skin","Pele"],["hair","Cabelo"],["top","Roupa"],["bottom","Calça"],["hat","Chapéu"]]:
		var c=column(color_row,3);label(c,pair[1],13);var picker=ColorPickerButton.new();picker.color=Color(colors.get(pair[0],{"skin":"#e9bb94","hair":"#775542","top":"#83ac83","bottom":"#527388","hat":"#8aa5bf"}.get(pair[0])));picker.custom_minimum_size=Vector2(92,32);c.add_child(picker);picker.color_changed.connect(func(color):colors[pair[0]]="#"+color.to_html(false);portrait.texture=view.indigo.compose(draft,colors,"front"))
	btn(controls,"Salvar aparência",func():send({"type":"appearance","look":draft,"colors":colors});close_panel())

func genome_panel(m:Dictionary):
	modal(mon_name(m)+" · mapa genético","Alelos recessivos podem ficar ocultos e reaparecer nos descendentes.");screen="genes"
	var r=row(overlay_body,24);mon_card(r,m,true);var c=column(r,10)
	var names={"body":"Cor base","detail":"Detalhes","pattern":"Padrão","eye":"Olhos","mouth":"Boca","mark":"Sinal","mark_color":"Cor do sinal","mark_place":"Local do sinal","size":"Porte"}
	for key in m.genes.loci:
		var pair=m.genes.loci[key];label(c,"%s   %d/%d  · dominância %d/%d"%[names.get(key,key),pair[0].value,pair[1].value,pair[0].dominance,pair[1].dominance],16)
	label(overlay_body,"Pais: "+str(m.genes.parents),12);label(overlay_body,"Linhagem registrada: %d ancestrais"%m.genes.lineage.size(),15)
	var actions=row(overlay_body)
	btn(actions,"Cuidar · 1 berry",func():send({"type":"care","ids":[m.id]}))
	for item in ["Pedra Dura","Lente Foco"]:btn(actions,"Equipar "+item,func():send({"type":"held","ids":[m.id],"value":item}))
	for stone in ["Pedra de Fogo","Pedra da Água","Pedra do Trovão"]:btn(overlay_body,"Evoluir com "+stone,func():send({"type":"evolve","ids":[m.id],"value":stone}))

func market_menu():
	var r=row(overlay_body);label(r,"Anunciar selecionado por",16);var price=SpinBox.new();price.min_value=1;price.max_value=100000;price.value=500;r.add_child(price);btn(r,"Anunciar",func():send({"type":"list","ids":selected,"index":int(price.value)}))
	label(overlay_body,"Retire o Pokémon da equipe e do treino antes de anunciar. A transferência preserva genes e IVs.",14)
	var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);overlay_body.add_child(grid)
	for listing in data.get("market",[]):
		var c=column(panel(grid));mon_card(c,listing.mon);label(c,"%s · %d moedas"%[listing.name,listing.price],16,ACCENT)
		if listing.seller==data.player.id:btn(c,"Cancelar anúncio",func():send({"type":"cancel_listing","value":listing.id}))
		else:btn(c,"Comprar exemplar",func():send({"type":"purchase","value":listing.id}))
	if data.get("market",[]).is_empty():label(overlay_body,"O mercado ainda está vazio. Os anúncios são de jogadores reais.",18,ACCENT)
	label(overlay_body,"SEUS EXEMPLARES",14,ACCENT)
	var own_grid=GridContainer.new();own_grid.columns=3;overlay_body.add_child(own_grid)
	for m in data.player.mons:mon_card(own_grid,m,true)

func profession_menu():
	var p=data.player
	label(overlay_body,"Seu caminho: "+p.profession,22,ACCENT);var r=row(overlay_body)
	for job in ["Treinador","Professor","Engenheiro"]:btn(r,job,func():send({"type":"profession","value":job}))
	label(overlay_body,"Professor: registre 3 espécies. Engenheiro: entregue uma Pedra da Lua. Uma tarefa por hora.",15)
	btn(overlay_body,"Entregar tarefa · 80 moedas / 40 XP",func():send({"type":"job"}))
	label(overlay_body,"COZINHA DE AURORA",14,ACCENT)
	for meal in [["salada","Salada de berries","2 berries · +5% movimento por 5 min"],["ensopado","Ensopado da horta","3 berries · +5% regeneração de energia por 5 min"],["iguaria","Iguaria de Magikarp","80 moedas · +8% dano por 5 min · −15 afinidade na família Magikarp"]]:
		var c=column(panel(overlay_body));label(c,meal[1],21);label(c,meal[2],14);btn(c,"Preparar / consumir",func():
			if meal[0]=="iguaria":confirm_delicacy()
			else:send({"type":"eat","value":meal[0]}))

func confirm_delicacy():
	modal("Uma escolha com consequências","O prato é um item culinário; nenhum parceiro será removido da coleção.");screen="comida"
	label(overlay_body,"Consumir esta iguaria reduz em 15 a afinidade dos seus Magikarp e Gyarados.",18)
	btn(overlay_body,"Consumir e aceitar a perda de afinidade",func():send({"type":"eat","value":"iguaria"});close_panel())

func lobby_menu():
	var r=row(overlay_body);btn(r,"Ir ao ginásio",func():send({"type":"travel","area":"ginasio"}));btn(r,"Desafiar Flora",func():send({"type":"gym"});close_panel());btn(r,"Buscar / cancelar duelo",func():send({"type":"queue"}));btn(r,"Automático: "+("sim" if data.player.auto else "não"),func():send({"type":"auto"}))
	for b in data.get("battles",[]):btn(overlay_body,"Assistir: %s × %s"%[b.fighters[0].name,b.fighters[1].name],func():spectate=b.id;close_panel())
	label(overlay_body,"CLASSIFICAÇÃO · pontos / vitórias / recorde do ginásio",14,ACCENT)
	for rank in data.rankings:label(overlay_body,"%s     %d pts     %d V / %d D     %.1fs"%[rank.name,rank.rating,rank.wins,rank.losses,rank.records.get("gym",0)],16)
	label(overlay_body,"SAGUÃO · CONVERSA",14,ACCENT)
	for msg in data.chat.slice(-8):label(overlay_body,msg.name+": "+msg.text,14)
	r=row(overlay_body);message_input=LineEdit.new();message_input.placeholder_text="Converse com quem está no ginásio…";message_input.max_length=200;message_input.custom_minimum_size.x=760;r.add_child(message_input);btn(r,"Enviar",func():send({"type":"chat","text":message_input.text}))

func interact():
	if data.is_empty():return
	var p=data.player
	if p.battle!="":send({"type":"ball"});return
	if float(p.get("fishing",0))>0:send({"type":"fish"});return
	match p.area:
		"casa":open_panel("casa")
		"vila":open_panel("vila")
		"jardim":open_panel("jardim")
		"ginasio":open_panel("ranking")
		"mina":send({"type":"mine"})
		"rota":send({"type":"encounter"})
		"safari":send({"type":"safari"});notice("Mire no Pokémon e solte a bola no centro do alvo.")
		"lago":
			modal("À beira do Lago Celeste","Pesque, explore ou acompanhe os encontros especiais.");screen="lago";btn(overlay_body,"Lançar a vara",func():send({"type":"fish"});close_panel());btn(overlay_body,"Explorar margem",func():send({"type":"encounter"});close_panel());btn(overlay_body,"Evento de Mew · domingos UTC",func():send({"type":"event"});close_panel())

func _unhandled_input(event:InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if screen!="":close_panel()
			elif spectate!="":spectate=""
			elif not data.is_empty() and data.player.arcade!=null:send({"type":"arcade_stop"})
			elif not data.is_empty():open_panel("equipe")
			return
		if screen!="":return
		if event.keycode==KEY_E:interact()
		if event.keycode==KEY_M:open_panel("mapa")
		if event.keycode==KEY_T and not data.is_empty():send({"type":"transport","value":"walk" if data.player.get("transport","")=="bike" else "bike"})
		if not data.is_empty() and data.player.battle!="":
			if event.keycode==KEY_SPACE:send({"type":"dash"})
			if event.keycode==KEY_Q:send({"type":"special"})
			if event.keycode==KEY_B:send({"type":"ball"})
			if event.keycode==KEY_F:send({"type":"flee"})
			if event.keycode==KEY_V:
				for fighter in data.battle.fighters:
					if fighter.owner==data.player.id:send({"type":"evolve","ids":[fighter.mon.id]})
	if event is InputEventMouseButton and screen=="" and not data.is_empty() and event.button_index==MOUSE_BUTTON_LEFT:
		var pos=view.get_local_mouse_position()
		if pos.x<0 or pos.x>512 or pos.y<0 or pos.y>384:return
		if event.pressed and data.player.battle!="":send({"type":"attack"})
		elif event.pressed and placing!="":send({"type":"decorate","value":placing,"pos":{"x":pos.x,"y":pos.y}});placing=""
		elif not event.pressed and data.player.area=="safari" and data.player.safari!=null:send({"type":"throw","pos":{"x":pos.x,"y":pos.y}})
		elif event.pressed and data.player.area=="casa":
			if Rect2(340,140,120,100).has_point(pos):open_panel("pc")
			elif Rect2(350,65,110,110).has_point(pos):open_panel("casa")
			elif Rect2(222,320,70,45).has_point(pos):send({"type":"travel","area":"vila"})
