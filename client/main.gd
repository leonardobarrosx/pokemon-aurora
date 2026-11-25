extends Node2D

const AREAS={"casa":"Meu cantinho","vila":"Vila Alvorada","rota":"Trilha das Folhas","jardim":"Jardim de berries","mina":"Mina da Lua","ginasio":"Ginásio Raiz","safari":"Reserva Orvalho","lago":"Lago Celeste"}
const QUESTS=["Converse com Íris na vila","Capture um parceiro na rota","Plante, regue e colha uma berry","Encontre um cristal na mina","Vença Flora no Ginásio Raiz"]
const Design=preload("res://aurora_theme.gd")
var display_font:SystemFont
var page_theme:Theme
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
var picks:Dictionary={}
var lobby_lists:Dictionary={}
var lobby_signature=""
var lobby_auto:Button
var lobby_send:Button
var submitted_chat=""
var genes_return="equipe"
var offers_grid:GridContainer
var offers_key=""

func _ready():
	TranslationServer.set_locale("pt_BR")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=").validate_filename()
		if arg=="--preview":preview_mode=true
		if arg.begins_with("--server="):endpoint=arg.trim_prefix("--server=")
	font=SystemFont.new();font.font_names=PackedStringArray(["Segoe UI","Arial"])
	display_font=SystemFont.new()
	display_font.font_names=PackedStringArray(["Bahnschrift","Segoe UI","Arial"])
	display_font.font_weight=700
	display_font.font_stretch=85
	page_theme=Design.make(font,true)
	var config=ConfigFile.new()
	if config.load("user://%s.cfg"%profile)==OK:
		token=config.get_value("session","token","")
		var saved_endpoint=str(config.get_value("session","server",endpoint))
		var override=false
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--server="):override=true
		if not override:endpoint=saved_endpoint
		elif saved_endpoint!=endpoint:token=""
	var backdrop=TextureRect.new()
	backdrop.texture=preload("res://assets/ui/atlas-panorama.png")
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size=Vector2(1920,1080)
	backdrop.modulate=Color("#586970")
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	view=Node2D.new();view.set_script(load("res://world_view.gd"));view.game=self;view.position=Vector2(448,156);view.scale=Vector2(2,2);add_child(view)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	ui.theme=preload("res://aurora_theme.gd").make(font)
	ui.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	hud=Control.new();hud.set_script(load("res://aurora_hud.gd"));hud.game=self;ui.add_child(hud)
	http=HTTPRequest.new();http.timeout=5;add_child(http);http.request_completed.connect(received)
	if token!="":send({"type":"poll"})
	else:login()
	if preview_mode:
		get_tree().create_timer(3).timeout.connect(func(): get_viewport().get_texture().get_image().save_png("user://aurora-preview.png"))

func box(color:Color,radius:int=4)->StyleBoxFlat:
	return preload("res://aurora_theme.gd").surface(color,mini(radius,4))

func on_page(parent:Node)->bool:
	return is_instance_valid(overlay_body) and (parent==overlay_body or overlay_body.is_ancestor_of(parent))

func label(parent:Node,text:String,size:int=16,color:Color=Color("edf2fa"))->Label:
	var l=Label.new()
	l.text=text
	if size>=20:l.add_theme_font_override("font",display_font)
	if on_page(parent):
		color=Design.INK if color==Color("edf2fa") else (Design.TEAL if color==ACCENT else Color("#55655f"))
	l.add_theme_font_size_override("font_size",maxi(16,roundi(size*1.20)))
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func btn(parent:Node,text:String,callback:Callable,width:float=0)->Button:
	var b=Button.new()
	b.text=text
	b.custom_minimum_size=Vector2(width,50)
	if is_instance_valid(overlay_body) and (parent==overlay_body or (parent is VBoxContainer and parent.get_parent() is PanelContainer)):b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(callback)
	parent.add_child(b)
	preload("res://ui_motion.gd").wire(b)
	return b

func panel(parent:Node,color:Color=Color("172237"),_illustrated:bool=true)->PanelContainer:
	var p=PanelContainer.new()
	var style=Design.surface(Design.CARD,12,Color("#c7bdab")) if on_page(parent) else Design.surface(Design.INK)
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	return p

func column(parent:Node,gap:int=10)->VBoxContainer:
	var c=VBoxContainer.new();c.add_theme_constant_override("separation",gap);parent.add_child(c);return c

func row(parent:Node,gap:int=10)->HBoxContainer:
	var r=HBoxContainer.new();r.add_theme_constant_override("separation",gap);parent.add_child(r);return r

func grid_cards(parent:Node,columns:int)->GridContainer:
	var grid=GridContainer.new()
	grid.columns=columns
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",14)
	parent.add_child(grid)
	return grid

func thumbnail(parent:Node,tex:Texture2D,dimensions:Vector2,region:Rect2=Rect2()):
	var image=TextureRect.new()
	if region.has_area():
		var atlas=AtlasTexture.new()
		atlas.atlas=tex
		atlas.region=region
		image.texture=atlas
	else:image.texture=tex
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image.custom_minimum_size=dimensions
	parent.add_child(image)

func server_time()->float:return Time.get_unix_time_from_system()+clock_offset

func send(command:Dictionary):
	commands.append(command.duplicate(true))

func dispatch(command:Dictionary):
	request_busy=true
	submitted_chat=str(command.text) if command.type=="chat" else ""
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
		if view:view.observe_snapshot(response)
		data=response;clock_offset=float(response.now)-Time.get_unix_time_from_system();refresh_sidebar()
		if data.player.notice!=last_notice:last_notice=data.player.notice;notice(last_notice)
		if refresh_pending and screen in ["equipe","breeding","treino","loja","casa","vila","jardim","pc","profissao","mercado","mapa"]:open_panel(screen)
	if submitted_chat!="" and not response.has("error") and screen=="ranking" and is_instance_valid(message_input) and message_input.text.strip_edges()==submitted_chat:
		message_input.clear()
	if response.has("error"):notice(str(response.error).capitalize())
	view.queue_redraw()

func _process(delta:float):
	timer+=delta
	if view:view.queue_redraw()
	if hud and not data.is_empty():hud.update_values()
	# Match the authoritative 20 Hz simulation when the connection can keep up.
	if not data.is_empty() and token!="" and timer>=.05:
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
	status=label(ui,text,14,Color("f2e3bd"));status.position=Vector2(570,942);status.size=Vector2(840,40)
	status.add_theme_stylebox_override("normal",box(Color("192239"),4));status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var current_id=status.get_instance_id()
	get_tree().create_timer(5).timeout.connect(func():
		if is_instance_id_valid(current_id):instance_from_id(current_id).queue_free())

func login():
	screen="login"
	modal("Crie seu treinador","Escolha um parceiro para começar a jornada.")
	var c=column(overlay_body,18)
	label(c,"NOME DO TREINADOR",13,ACCENT);name_input=LineEdit.new();name_input.placeholder_text="Como podemos chamar você?";name_input.max_length=20;name_input.custom_minimum_size.y=44;c.add_child(name_input);name_input.grab_focus()
	label(c,"SEU PRIMEIRO PARCEIRO",13,ACCENT)
	var starters=row(c,16)
	var starter_group=ButtonGroup.new()
	for id in [1,4,7]:
		var card=panel(starters);card.custom_minimum_size.x=440;var cc=column(card);var im=TextureRect.new();im.texture=view.mon_texture({"species":id});im.custom_minimum_size=Vector2(140,130);im.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;im.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;cc.add_child(im)
		var pick=btn(cc,{1:"Bulbasaur",4:"Charmander",7:"Squirtle"}[id],func():starter=id)
		pick.toggle_mode=true
		pick.button_group=starter_group
		pick.button_pressed=starter==id
		for state in ["pressed","hover_pressed"]:
			pick.add_theme_stylebox_override(state,Design.surface(Design.CORAL,8,Design.CORAL))
			pick.add_theme_color_override("font_"+state+"_color",Color.WHITE)
	label(c,"ENDEREÇO DO SERVIDOR",13,ACCENT);server_input=LineEdit.new();server_input.text=endpoint;c.add_child(server_input)
	var start=btn(c,"Começar minha jornada",func():endpoint=server_input.text.strip_edges().trim_suffix("/");send({"type":"register","name":name_input.text,"starter":starter}),300)
	start.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	Design.primary(start)
	label(c,"O progresso fica no servidor. Esta instalação guarda sua chave de acesso.",14,Color("9eb2ad"))

func modal(title:String,subtitle:String):
	if not is_instance_valid(overlay):previous_focus=get_viewport().gui_get_focus_owner()
	else:overlay.queue_free()
	hud.hide()
	picks.clear()
	offers_grid=null
	offers_key=""
	lobby_lists.clear()
	lobby_signature=""
	overlay=Control.new()
	overlay.size=Vector2(1920,1080)
	ui.add_child(overlay)
	var paper=ColorRect.new()
	paper.color=Design.PAPER
	paper.size=overlay.size
	overlay.add_child(paper)
	var rail=ColorRect.new()
	rail.color=Design.INK
	rail.size=Vector2(256,1080)
	overlay.add_child(rail)
	var panorama=TextureRect.new()
	panorama.texture=preload("res://assets/ui/atlas-panorama.png")
	panorama.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	panorama.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panorama.size=Vector2(1920,136)
	panorama.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(panorama)
	var brand=label(overlay,"POKÉMON",14,Design.MINT)
	brand.position=Vector2(38,27)
	var brand_title=label(overlay,"AURORA",43)
	brand_title.position=Vector2(32,44)
	var nav=column(overlay,10)
	nav.position=Vector2(16,166)
	var routes={"equipe":"Equipe","mapa":"Mapa","loja":"Mochila e loja","breeding":"Linhagens","treino":"Treinamento","mercado":"Mercado","casa":"Minha casa","profissao":"Profissão","ranking":"Liga e saguão"}
	var section={"guarda-roupa":"casa","wardrobe":"casa","pc":"casa","genes":genes_return,"comida":"profissao","lago":"mapa","jardim":"mapa","vila":"mapa"}.get(screen,screen)
	for route in routes:
		var item=btn(nav,routes[route],open_panel.bind(route),224)
		item.alignment=HORIZONTAL_ALIGNMENT_LEFT
		item.custom_minimum_size.y=60
		if route==section:Design.primary(item)
		else:item.add_theme_stylebox_override("normal",Design.surface(Design.INK,8,Design.INK))
	var close=btn(overlay,"Fechar   Esc",close_panel,150)
	close.position=Vector2(1730,40)
	var x=300 if not data.is_empty() else 238
	var heading=label(overlay,title,35,Design.INK)
	heading.position=Vector2(x,151)
	var sub=label(overlay,subtitle,16,Design.TEAL)
	sub.position=Vector2(x,207)
	var rule=ColorRect.new()
	rule.color=Design.CORAL
	rule.position=Vector2(x,246)
	rule.size=Vector2(82,4)
	overlay.add_child(rule)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(x,271)
	scroll.size=Vector2(1874-x if not data.is_empty() else 1444,783)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	overlay.add_child(scroll)
	overlay_body=column(scroll,20)
	overlay_body.theme=page_theme
	overlay_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if data.is_empty():
		nav.hide()
		rail.hide()
		close.hide()
	else:close.grab_focus()
	preload("res://ui_motion.gd").reveal(overlay,scroll)

func close_panel():
	if is_instance_valid(overlay):overlay.queue_free();overlay=null
	screen="";selected.clear()
	if hud:hud.visible=true;hud.refresh()
	if is_instance_valid(previous_focus):previous_focus.grab_focus()

func refresh_sidebar():
	if hud and not data.is_empty():hud.refresh()
	if screen=="ranking":update_lobby()
	if screen=="mercado":update_offers()

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

func game_type(m:Dictionary)->String:
	return str(data.get("species",{}).get(str(int(m.species)),{}).get("type",""))

func mon_card(parent:Node,m:Dictionary,choose:bool=false):
	var card=panel(parent,Color("17273b") if selected.has(m.id) else Color("131f32"));card.custom_minimum_size.x=446
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var c=column(card,14)
	var top=row(c,8)
	var index=label(top,"#%03d"%int(m.species),14,ACCENT)
	index.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(top,"Nv. %d"%m.level,17)
	label(c,mon_name(m),30)
	var description=game_type(m)+"   ·   "+str(m.sex)+"   ·   Geração %d"%m.genes.generation
	label(c,description,15,ACCENT)
	var specimen=row(c,18)
	specimen.alignment=BoxContainer.ALIGNMENT_CENTER
	var plate=PanelContainer.new()
	var tones={"Planta":"#c8e9d5","Fogo":"#f5cdac","Água":"#c3e0eb","Elétrico":"#f4dfa3","Fantasma":"#dccde6"}
	var plate_style=Design.surface(Color(tones.get(game_type(m),"#eed7c5")),90,Color.TRANSPARENT)
	plate.add_theme_stylebox_override("panel",plate_style)
	specimen.add_child(plate)
	var image=TextureRect.new()
	image.texture=view.mon_texture(m)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2(142,150)
	plate.add_child(image)
	var stats=column(specimen,1)
	label(stats,"IVs  /  31",13,ACCENT)
	var names=["PS","ATQ","DEF","AT. E","DF. E","VEL"]
	for i in names.size():
		var line=row(stats,6)
		var stat_name=label(line,names[i],12)
		stat_name.custom_minimum_size.x=52
		var track=ProgressBar.new()
		track.max_value=31
		track.value=m.iv[i]
		track.show_percentage=false
		track.custom_minimum_size=Vector2(74,8)
		track.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		var fill=StyleBoxFlat.new()
		fill.bg_color=Design.TEAL
		var empty=StyleBoxFlat.new()
		empty.bg_color=Color("#e0d8c7")
		track.add_theme_stylebox_override("fill",fill)
		track.add_theme_stylebox_override("background",empty)
		line.add_child(track)
		label(line,str(int(m.iv[i])),13)
	label(c,"EVs   "+stat_numbers(m.ev),13)
	label(c,"Vínculo %d/100   ·   %s"%[m.get("affinity",50),m.look.pattern],15,ACCENT)
	if choose:
		var select=btn(c,"Selecionar parceiro",func():toggle_partner(m.id))
		picks[m.id]=select
		style_pick(m.id)
		btn(c,"Aparência e genes",func():genome_panel(m))
	elif screen!="genes":btn(c,"Ver genes e linhagem",func():genome_panel(m))

func toggle_partner(id:String):
	if selected.has(id):selected.erase(id)
	else:
		var limit={"mercado":1,"breeding":2}.get(screen,6)
		if limit==1:selected.clear()
		if selected.size()>=limit:
			notice("Escolha até %d parceiros."%limit)
			return
		selected.append(id)
	for key in picks:style_pick(key)

func style_pick(id:String):
	var button=picks[id] as Button
	var order=selected.find(id)
	button.text="Selecionado · %d"%(order+1) if order>=0 else "Selecionar parceiro"
	if order>=0:Design.primary(button)
	else:
		for state in ["normal","hover","pressed"]:button.remove_theme_stylebox_override(state)
		for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:button.remove_theme_color_override(state)

func open_panel(which:String):
	if data.is_empty():return
	if which!=screen:
		selected.clear()
		if which=="equipe":selected.assign(data.player.team)
	screen=which
	var titles={
		"equipe":["Minha equipe","Selecione até seis parceiros na ordem em que vão lutar."],
		"mapa":["Mapa de Aurora","Escolha um destino. Para voar até ele, visite a área primeiro."],
		"loja":["Mochila e loja","Compre suprimentos para a jornada e objetos para sua casa."],
		"breeding":["Laboratório de linhagens","Escolha dois parceiros para prever ou iniciar um cruzamento."],
		"mercado":["Mercado","Escolha um exemplar para anunciar ou consulte as ofertas."],
		"treino":["Treinamento","Escolha seus parceiros e o atributo que deseja treinar."],
		"profissao":["Ofícios e cozinha","Escolha uma profissão, entregue tarefas ou prepare uma refeição."],
		"ranking":["Liga e saguão","Desafie o ginásio, assista a uma partida ou converse com os treinadores."],
		"casa":["Minha casa","Troque de roupa, decore o quarto ou ligue o computador."],
		"vila":["Vila Alvorada","Converse ou presenteie um morador."],
		"jardim":["Jardim de berries","Regue os canteiros e colha as berries após 90 segundos."],
		"pc":["Aurora Arcade","Escolha uma prova de 30 segundos para seu primeiro parceiro."]
	}
	var title=titles.get(which,[which,""])
	modal(title[0],title[1])
	var p:Dictionary=data.player
	match which:
		"mapa":
			var grid=grid_cards(overlay_body,2)
			var unlock={"casa":0,"vila":0,"jardim":0,"rota":1,"mina":2,"ginasio":2,"safari":3,"lago":3}
			var stamps={"casa":["Interior1",Rect2(128,608,128,96)],"vila":["Exterior1",Rect2(0,3360,192,224)],"rota":["Exterior1",Rect2(128,32,32,32)],"jardim":["Exterior1",Rect2(160,160,32,64)],"mina":["Interior1",Rect2(0,1280,64,96)],"ginasio":["Interior1",Rect2(0,2048,128,128)],"safari":["Exterior1",Rect2(128,1312,64,96)],"lago":["Exterior1",Rect2(0,320,64,32)]}
			var can_fly=false
			for mon in p.mons:
				if data.species[str(int(mon.species))].get("ride","")=="Voo":can_fly=true
			for id in AREAS:
				var card=panel(grid)
				card.custom_minimum_size.x=740
				var content=row(card,20)
				var stamp=stamps[id]
				thumbnail(content,view.texture("res://assets/indigo/tilesets/%s-0.png"%stamp[0]),Vector2(92,100),stamp[1])
				var c=column(content,5)
				label(c,AREAS[id],22)
				var visited=p.visits.get(id,false)
				var locked=p.quest<unlock[id]
				var state="Continue a história" if locked else ("Visitado" if visited else "Novo destino")
				label(c,"Você está aqui" if p.area==id else state,13,ACCENT)
				var r=row(c)
				var walk=btn(r,"Ir a pé / bicicleta",func():send({"type":"travel","area":id});close_panel())
				walk.disabled=locked or p.area==id
				var fly=btn(r,"Usar Fly",func():send({"type":"travel","area":id,"fly":true});close_panel())
				fly.disabled=walk.disabled or not visited or not can_fly
				if fly.disabled:fly.tooltip_text="Visite esta área a pé e obtenha um parceiro de voo."
		"equipe","breeding","treino":
			if which=="equipe":
				var actions=row(overlay_body);Design.primary(btn(actions,"Salvar equipe selecionada",func():send({"type":"team","ids":selected})));btn(actions,"Conquista da Pokédex",func():send({"type":"dex"}));btn(actions,"Evoluir selecionado",func():send({"type":"evolve","ids":selected}));label(overlay_body,"A ordem de seleção define quem entra primeiro na batalha. Equipe atual: %d/6."%p.team.size(),14)
			if which=="breeding":
				var r=row(overlay_body);btn(r,"Prever cruzamento",func():send({"type":"predict","ids":selected}));btn(r,"Cruzar · 3 berries",func():send({"type":"breed","ids":selected}));btn(r,"Chocar ovo",func():send({"type":"hatch"}))
				label(overlay_body,"Selecione dois parceiros de sexos diferentes e do mesmo grupo de ovos. Incubação: 3 minutos.",14)
				if p.get("egg")!=null:
					var incubation=row(panel(overlay_body),16)
					label(incubation,"Ovo na incubadora",19)
					var bar=ProgressBar.new()
					bar.max_value=180
					bar.custom_minimum_size=Vector2(260,24)
					bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
					incubation.add_child(bar)
					var remaining=label(incubation,"",16,ACCENT)
					var timer_node=Timer.new()
					timer_node.wait_time=.5
					remaining.add_child(timer_node)
					var refresh_egg=func():
						var age=clampi(int(server_time()-float(p.egg.at)),0,180)
						bar.value=age
						remaining.text="%d s para chocar"%(180-age) if age<180 else "Pronto para chocar"
						if age==180:timer_node.stop()
					timer_node.timeout.connect(refresh_egg)
					timer_node.start()
					refresh_egg.call()
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
				var c=column(panel(grid))
				c.custom_minimum_size.x=446
				var header=row(c,14)
				var icon_size=Vector2(72,72)
				match item[0]:
					"bola","semente":
						var icon="POKEBALL" if item[0]=="bola" else "ORANBERRY"
						thumbnail(header,view.texture("res://assets/indigo/items/"+icon+".png"),icon_size)
					"pelucia":thumbnail(header,view.mon_texture({"species":25}),icon_size)
					_:
						var parts={"planta":Rect2(224,0,32,64),"estante":Rect2(0,512,64,64),"aquario":Rect2(96,1408,64,64)}
						thumbnail(header,view.texture("res://assets/indigo/tilesets/Interior1-0.png"),icon_size,parts[item[0]])
				var info=column(header,2)
				label(info,item[1],21)
				label(info,item[2],16,ACCENT)
				btn(c,"Comprar",func():send({"type":"buy","value":item[0]}))
			for stone in p.stones:label(overlay_body,"%s  ×%d"%[stone,p.stones[stone]],16)
		"casa":
			var layout=row(overlay_body,24)
			var character=column(panel(layout),16)
			character.custom_minimum_size.x=370
			thumbnail(character,view.indigo.compose(p.look,p.colors,"front"),Vector2(330,280))
			label(character,p.name,25)
			Design.primary(btn(character,"Abrir guarda-roupa",wardrobe_menu))
			var room=column(panel(layout),18)
			room.custom_minimum_size.x=650
			label(room,"Decoração do quarto",26)
			label(room,"Papel de parede",16,ACCENT)
			var r=row(room)
			for color in ["verde","azul","lilas"]:
				var theme_button=btn(r,{"verde":"Verde","azul":"Azul","lilas":"Lilás"}[color],func():send({"type":"theme","value":color}))
				if color==p.theme:Design.primary(theme_button)
			label(room,"Móveis",16,ACCENT)
			for d in p.decor:
				var names={"planta":"Samambaia","estante":"Estante de pesquisa","aquario":"Aquário azul","pelucia":"Pelúcia de Pikachu"}
				btn(room,"Mover "+names.get(d.kind,d.kind),func():placing=d.kind;close_panel();notice("Clique no chão para posicionar o móvel."))
			r=row(room,12)
			btn(r,"Abrir computador",open_panel.bind("pc"))
			btn(r,"Sair para a vila",func():send({"type":"travel","area":"vila"});close_panel())
		"vila":
			var neighbors=grid_cards(overlay_body,3)
			var portraits={"Íris":"professor","Lia":"gardener","Theo":"engineer"}
			for npc in portraits:
				var c=column(panel(neighbors),14)
				c.custom_minimum_size.x=444
				var header=row(c,12)
				var npc_tex=view.texture("res://assets/characters/%s.png"%portraits[npc])
				var cell=npc_tex.get_width()/4
				thumbnail(header,npc_tex,Vector2(84,90),Rect2(0,0,cell,cell))
				var info=column(header,4)
				label(info,npc,24)
				label(info,"Amizade  %d"%p.friends.get(npc,0),15,ACCENT)
				var r=row(c)
				btn(r,"Conversar",func():send({"type":"talk","value":npc}))
				btn(r,"Presentear berry",func():send({"type":"gift","value":npc}))
		"jardim":
			var grid=grid_cards(overlay_body,3)
			for i in 6:
				var c=column(panel(grid),12)
				c.custom_minimum_size.x=436
				var plot=p.plots[i]
				var header=row(c,14)
				var spr=Rect2(128,416,32,32) if float(plot.at)==0 else Rect2(160,160,32,64)
				thumbnail(header,view.texture("res://assets/indigo/tilesets/Exterior1-0.png"),Vector2(68,74),spr)
				var info=column(header,2)
				label(info,"Canteiro %d"%(i+1),22)
				var state=label(info,"",14,ACCENT)
				var button:Button
				if float(plot.at)==0:
					state.text="Terra livre"
					button=btn(c,"Plantar semente",func():send({"type":"plant","index":i}))
					button.disabled=p.seeds<1
				elif not plot.water:
					state.text="Precisa de água"
					button=btn(c,"Regar canteiro",func():send({"type":"water","index":i}))
				else:
					button=btn(c,"Colher berries",func():send({"type":"harvest","index":i}))
					var tick=Timer.new()
					tick.wait_time=0.5
					button.add_child(tick)
					var update=func():
						var wait=maxi(0,ceili(float(plot.at)+90-server_time()))
						state.text="Pronto para colher" if wait==0 else "Regado · %d s para colher"%wait
						button.disabled=wait>0
						if wait==0:tick.stop()
					tick.timeout.connect(update)
					tick.start()
					update.call()
				Design.primary(button)
		"pc":
			var games=grid_cards(overlay_body,2)
			for pair in [["arcade","Chuva de estrelas","Desvie dos projéteis com seu primeiro parceiro."],["Corrida","Circuito Aurora","Bicicleta ou montaria. Mantenha-se na pista."],["Voo","Ventos do norte","Requer um parceiro de voo."],["Natação","Correnteza azul","Requer um parceiro de natação."]]:
				var c=column(panel(games));c.custom_minimum_size.x=694;label(c,pair[1],24);label(c,pair[2],16);btn(c,"Jogar",func():send({"type":"arcade","value":pair[0]});close_panel())
		"profissao":profession_menu()
		"mercado":market_menu()
		"ranking":lobby_menu()

func wardrobe_menu():
	screen="wardrobe"
	modal("Guarda-roupa","Personalização do Indigo · Coffee Cup / Poltergeist")
	var draft:Dictionary=data.player.get("look",{}).duplicate(true)
	if draft.is_empty():draft={"gender":"m","hair":"boy2","top":"jacket","bottom":"jeans","hat":"","acc":"","bag":""}
	var colors:Dictionary=data.player.get("colors",{}).duplicate(true)
	var layout=row(overlay_body,28);var preview_card=panel(layout);preview_card.custom_minimum_size=Vector2(408,506);var pc=column(preview_card)
	var portrait=TextureRect.new();portrait.texture=view.indigo.compose(draft,colors,"front");portrait.custom_minimum_size=Vector2(340,386);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;pc.add_child(portrait)
	label(pc,data.player.name,23)
	var controls=column(layout,10);controls.custom_minimum_size.x=728
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
		var c=column(color_row,3);label(c,pair[1],13);var picker=ColorPickerButton.new();picker.theme=ui.theme;picker.color=Color(colors.get(pair[0],{"skin":"#e9bb94","hair":"#775542","top":"#83ac83","bottom":"#527388","hat":"#8aa5bf"}.get(pair[0])));picker.custom_minimum_size=Vector2(92,32);c.add_child(picker);picker.color_changed.connect(func(color):colors[pair[0]]="#"+color.to_html(false);portrait.texture=view.indigo.compose(draft,colors,"front"))
	Design.primary(btn(controls,"Salvar aparência",func():send({"type":"appearance","look":draft,"colors":colors});close_panel()))

func genome_panel(m:Dictionary):
	genes_return=screen if screen in ["equipe","breeding","mercado","treino"] else "equipe"
	screen="genes"
	modal(mon_name(m)+" · mapa genético","Alelos recessivos podem reaparecer nos descendentes.")
	var r=row(overlay_body,32);mon_card(r,m,false);r.get_child(0).size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;var c=column(r,8)
	label(c,"REGIÕES DE APARÊNCIA",16,ACCENT)
	var region_colors=preload("res://pokemon_regions.gd").colors(m.look)
	for region in region_colors:
		label(c,preload("res://pokemon_regions.gd").LABELS[region]+": "+("Original" if region_colors[region]=="original" else region_colors[region]),14)
	c=column(r,8)
	label(c,"ALELOS HERDADOS",16,ACCENT)
	var names={"skin":"Pele","fur":"Pelagem","flame":"Chama","effects":"Efeitos","nose":"Nariz","markings":"Desenhos naturais","accessory":"Características da espécie","body":"Cor base","detail":"Detalhes","pattern":"Padrão","eye":"Olhos","mouth":"Boca","mark":"Sinal","mark_color":"Cor do sinal","mark_place":"Local do sinal","size":"Porte"}
	for key in m.genes.loci:
		var pair=m.genes.loci[key];label(c,"%s   %d/%d  · dominância %d/%d"%[names.get(key,key),pair[0].value,pair[1].value,pair[0].dominance,pair[1].dominance],16)
	if int(m.genes.generation)>0:label(overlay_body,"Geração %d"%m.genes.generation,16)
	label(overlay_body,"Linhagem registrada: %d ancestrais"%m.genes.lineage.size(),15)
	var actions=row(overlay_body)
	btn(actions,"Voltar",open_panel.bind(genes_return))
	if not data.player.mons.any(func(owned):return owned.id==m.id):return
	btn(actions,"Cuidar · 1 berry",func():send({"type":"care","ids":[m.id]}))
	for item in ["Pedra Dura","Lente Foco"]:btn(actions,"Equipar "+item,func():send({"type":"held","ids":[m.id],"value":item}))
	for stone in ["Pedra de Fogo","Pedra da Água","Pedra do Trovão"]:btn(overlay_body,"Evoluir com "+stone,func():send({"type":"evolve","ids":[m.id],"value":stone}))

func market_menu():
	var r=row(overlay_body);label(r,"Anunciar selecionado por",16);var price=SpinBox.new();price.min_value=1;price.max_value=100000;price.value=500;r.add_child(price);btn(r,"Anunciar",func():send({"type":"list","ids":selected,"index":int(price.value)}))
	label(overlay_body,"Retire o Pokémon da equipe e do treino antes de anunciar. A transferência preserva genes e IVs.",14)
	offers_grid=grid_cards(overlay_body,3)
	update_offers()
	label(overlay_body,"SEUS EXEMPLARES",14,ACCENT)
	var own_grid=GridContainer.new();own_grid.columns=3;overlay_body.add_child(own_grid)
	for m in data.player.mons:mon_card(own_grid,m,true)

func update_offers():
	if not is_instance_valid(offers_grid):return
	var keys=[]
	for item in data.get("market",[]):keys.append(item.id)
	var signature=JSON.stringify(keys)
	if offers_key==signature:return
	offers_key=signature
	for child in offers_grid.get_children():
		offers_grid.remove_child(child)
		child.queue_free()
	if keys.is_empty():
		label(offers_grid,"Nenhum exemplar anunciado.",18,ACCENT)
		return
	for offer in data.market:
		var c=column(panel(offers_grid),8)
		c.custom_minimum_size.x=446
		var head=row(c,16)
		thumbnail(head,view.mon_texture(offer.mon),Vector2(96,96))
		var info=column(head,3)
		label(info,mon_name(offer.mon),23)
		label(info,"%s · Nv. %d"%[game_type(offer.mon),offer.mon.level],15)
		label(c,"%d moedas   ·   %s"%[offer.price,offer.name],17,ACCENT)
		btn(c,"Consultar genes",func():genome_panel(offer.mon))
		if offer.seller==data.player.id:btn(c,"Cancelar anúncio",func():send({"type":"cancel_listing","value":offer.id}))
		else:Design.primary(btn(c,"Comprar exemplar",func():send({"type":"purchase","value":offer.id})))

func profession_menu():
	var p=data.player
	label(overlay_body,"Seu caminho: "+p.profession,22,ACCENT);var r=row(overlay_body)
	for job in ["Treinador","Professor","Engenheiro"]:btn(r,job,func():send({"type":"profession","value":job}))
	label(overlay_body,"Professor: registre 3 espécies. Engenheiro: entregue uma Pedra da Lua. Uma tarefa por hora.",15)
	btn(overlay_body,"Entregar tarefa · 80 moedas / 40 XP",func():send({"type":"job"}))
	label(overlay_body,"COZINHA DE AURORA",14,ACCENT)
	var kitchen=grid_cards(overlay_body,3)
	for meal in [["salada","Salada de berries","2 berries · +5% movimento por 5 min"],["ensopado","Ensopado da horta","3 berries · +5% regeneração de energia por 5 min"],["iguaria","Iguaria de Magikarp","80 moedas · +8% dano por 5 min · −15 afinidade na família Magikarp"]]:
		var c=column(panel(kitchen));c.custom_minimum_size.x=438;label(c,meal[1],21)
		var detail=label(c,meal[2],15);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		btn(c,"Preparar / consumir",func():
			if meal[0]=="iguaria":confirm_delicacy()
			else:send({"type":"eat","value":meal[0]}))

func confirm_delicacy():
	screen="comida"
	modal("Preparar iguaria","Confira o efeito da refeição antes de consumir.")
	label(overlay_body,"Consumir esta iguaria reduz em 15 a afinidade dos seus Magikarp e Gyarados.",18)
	var row_actions=row(overlay_body)
	Design.primary(btn(row_actions,"Voltar à cozinha",open_panel.bind("profissao")))
	btn(row_actions,"Consumir iguaria",func():send({"type":"eat","value":"iguaria"});close_panel())

func lobby_menu():
	var r=row(overlay_body)
	btn(r,"Ir ao ginásio",func():send({"type":"travel","area":"ginasio"}))
	Design.primary(btn(r,"Desafiar Flora",func():send({"type":"gym"});close_panel()))
	btn(r,"Buscar / cancelar duelo",func():send({"type":"queue"}))
	lobby_auto=btn(r,"",func():send({"type":"auto"}))
	var cards=row(overlay_body,16)
	for entry in [["matches","Batalhas ao vivo",474],["ranks","Classificação",432],["chat","Conversa do saguão",480]]:
		var card=panel(cards)
		var content=column(card,16)
		content.custom_minimum_size.x=entry[2]
		label(content,entry[1],24)
		lobby_lists[entry[0]]=column(content,10)
		if entry[0]=="chat":
			var compose=row(content,8)
			message_input=LineEdit.new()
			message_input.placeholder_text="Mensagem ao saguão…"
			message_input.max_length=200
			message_input.custom_minimum_size.x=325
			compose.add_child(message_input)
			message_input.text_submitted.connect(chat_submit)
			lobby_send=btn(compose,"Enviar",func():chat_submit(message_input.text))
	update_lobby()

func chat_submit(message:String):
	var clean=message.strip_edges()
	if clean.is_empty() or data.player.area!="ginasio":return
	send({"type":"chat","text":clean})
	message_input.grab_focus()

func update_lobby():
	if lobby_lists.is_empty():return
	var can_chat=data.player.area=="ginasio"
	message_input.editable=can_chat
	message_input.placeholder_text="Mensagem ao saguão…" if can_chat else "Visite o ginásio para conversar"
	lobby_send.disabled=not can_chat
	lobby_auto.text="Automático: "+("sim" if data.player.auto else "não")
	var matches=[]
	for battle in data.get("battles",[]):
		var names=[]
		for fighter in battle.fighters:names.append([fighter.name,fighter.mon.species])
		matches.append([battle.id,names])
	var signature=JSON.stringify([matches,data.rankings,data.chat])
	if signature==lobby_signature:return
	lobby_signature=signature
	for list in lobby_lists.values():
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	if matches.is_empty():label(lobby_lists.matches,"Nenhuma batalha em andamento.",16)
	for battle in data.get("battles",[]):
		var pair=row(lobby_lists.matches,12)
		for fighter in battle.fighters:
			thumbnail(pair,view.mon_texture(fighter.mon),Vector2(90,80))
		var match_title=label(lobby_lists.matches,"%s × %s"%[battle.fighters[0].name,battle.fighters[1].name],18)
		match_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		Design.primary(btn(lobby_lists.matches,"Assistir à batalha",func():spectate=battle.id;close_panel()))
	for i in data.rankings.size():
		var rank=data.rankings[i]
		var line=label(lobby_lists.ranks,"%d.  %s   ·   %d pts"%[i+1,rank.name,rank.rating],18)
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var record=float(rank.records.get("gym",0))
		label(lobby_lists.ranks,"%d V  /  %d D%s"%[rank.wins,rank.losses,"   ·   %.1f s"%record if record>0 else ""],14,ACCENT)
	if data.chat.is_empty():label(lobby_lists.chat,"Nenhuma mensagem ainda.",16)
	for msg in data.chat.slice(-8):
		var line=label(lobby_lists.chat,msg.name+"   "+msg.text,16)
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

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
			lake_menu()

func lake_menu():
	screen="lago"
	modal("Lago Celeste","Pesca, encontros selvagens e o evento de Mew.")
	var spread=row(overlay_body,24)
	var illustration=TextureRect.new()
	illustration.texture=view.texture("res://assets/ui/lago-celeste.png")
	illustration.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	illustration.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	illustration.custom_minimum_size=Vector2(832,506)
	illustration.mouse_filter=Control.MOUSE_FILTER_IGNORE
	spread.add_child(illustration)
	var controls=column(spread,12)
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for entry in [["Pesca","Pressione E assim que o peixe fisgar.","Lançar a vara","fish"],["Margem do lago","Procure um encontro para batalhar e capturar.","Explorar margem","encounter"],["Encontro com Mew","Aos domingos, pelo horário UTC do servidor.","Participar do evento","event"]]:
		var card=column(panel(controls),6)
		label(card,entry[0],21)
		label(card,entry[1],15)
		var go=btn(card,entry[2],func():send({"type":entry[3]});close_panel())
		if entry[3]=="fish":Design.primary(go)
		if entry[3]=="event":
			var now=int(server_time())
			var day=Time.get_datetime_dict_from_unix_time(now)
			go.disabled=day.weekday!=Time.WEEKDAY_SUNDAY or data.player.get("event","")==Time.get_date_string_from_unix_time(now)

func _unhandled_input(event:InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if screen=="login":return
			if screen!="":close_panel()
			elif spectate!="":spectate="";refresh_sidebar()
			elif not data.is_empty() and data.player.arcade!=null:send({"type":"arcade_stop"})
			elif not data.is_empty():open_panel("equipe")
			return
		if screen!="":return
		if not data.is_empty() and (data.player.arcade!=null or spectate!=""):return
		if event.keycode==KEY_E:interact()
		if event.keycode==KEY_M:open_panel("mapa")
		if event.keycode==KEY_T and not data.is_empty():send({"type":"transport","value":"walk" if data.player.get("transport","")=="bike" else "bike"})
		if not data.is_empty() and data.player.battle!="":
			if event.keycode==KEY_SPACE:view.local_action("dash");send({"type":"dash"})
			if event.keycode==KEY_Q:view.local_action("special");send({"type":"special"})
			if event.keycode==KEY_B:send({"type":"ball"})
			if event.keycode==KEY_F:send({"type":"flee"})
			if event.keycode==KEY_V:
				for fighter in data.battle.fighters:
					if fighter.owner==data.player.id:send({"type":"evolve","ids":[fighter.mon.id]})
	if event is InputEventMouseButton and screen=="" and not data.is_empty() and event.button_index==MOUSE_BUTTON_LEFT:
		var pos=view.get_local_mouse_position()
		if pos.x<0 or pos.x>512 or pos.y<0 or pos.y>384:return
		if event.pressed and data.player.battle!="":view.local_action("attack");send({"type":"attack"})
		elif event.pressed and placing!="":send({"type":"decorate","value":placing,"pos":{"x":pos.x,"y":pos.y}});placing=""
		elif not event.pressed and data.player.area=="safari" and data.player.safari!=null:send({"type":"throw","pos":{"x":pos.x,"y":pos.y}})
		elif event.pressed and data.player.area=="casa":
			if Rect2(340,140,120,100).has_point(pos):open_panel("pc")
			elif Rect2(350,65,110,110).has_point(pos):open_panel("casa")
			elif Rect2(222,320,70,45).has_point(pos):send({"type":"travel","area":"vila"})
