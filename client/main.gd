extends Node2D

const AREAS={"casa":"Meu cantinho","vila":"Vila Alvorada","rota":"Trilha das Folhas","jardim":"Jardim de berries","mina":"Mina da Lua","ginasio":"Ginásio Raiz","safari":"Reserva Orvalho","lago":"Lago Celeste"}
const QUESTS=["Converse com Íris na vila","Capture um parceiro na rota","Plante, regue e colha uma berry","Encontre um cristal na mina","Vença Flora no Ginásio Raiz"]
const Design=preload("res://aurora_theme.gd")
var display_font:Font
var header_actions:HBoxContainer
var arena_backdrop:Control
var view_clip:Control
const Icons=preload("res://aurora_icons.gd")
const Paper=preload("res://aurora_paper.gd")
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
	display_font=Design.display_font()
	page_theme=Design.make(font,true)
	page_theme.set_font("font","Button",display_font)
	page_theme.set_font_size("font_size","Button",20)
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
	arena_backdrop=Paper.make("panel",Rect2(208,150,1504,922))
	arena_backdrop.seed_value=31
	arena_backdrop.visible=false
	add_child(arena_backdrop)
	view_clip=Control.new();view_clip.position=Vector2(448,156);view_clip.size=Vector2(1024,768);view_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(view_clip)
	view=Node2D.new();view.set_script(load("res://world_view.gd"));view.game=self;view.scale=Vector2(2,2);view_clip.add_child(view)
	ui=Control.new();ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	ui.theme=preload("res://aurora_theme.gd").make(font)
	ui.theme.set_font("font","Button",display_font)
	ui.theme.set_font_size("font_size","Button",20)
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

func btn(parent:Node,text:String,callback:Callable,width:float=0,icon_name:String="")->Button:
	var b=Button.new()
	b.text=text.to_upper()
	if icon_name!="":with_icon(b,icon_name)
	b.custom_minimum_size=Vector2(width,50)
	if is_instance_valid(overlay_body) and (parent==overlay_body or (parent is VBoxContainer and parent.get_parent() is PanelContainer)):b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(callback)
	parent.add_child(b)
	preload("res://ui_motion.gd").wire(b)
	return b

func with_icon(b:Button,icon_name:String,side:float=24):
	var spacer=Image.create(int(side),int(side),false,Image.FORMAT_RGBA8)
	b.icon=ImageTexture.create_from_image(spacer)
	b.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("h_separation",12)
	var mark=Icons.make(icon_name,Design.INK,side)
	mark.follow_parent=true
	b.add_child(mark)
	var place=func():mark.position=Vector2(b.get_theme_stylebox("normal").content_margin_left,(b.size.y-side)/2-1);mark.queue_redraw()
	b.resized.connect(place)
	b.draw.connect(mark.queue_redraw)
	place.call()

func panel(parent:Node,color:Color=Color("172237"),_illustrated:bool=true)->PanelContainer:
	var p=PanelContainer.new()
	var style=Design.surface(Design.CARD,14,Color("#d3c4a5"),2) if on_page(parent) else Design.surface(Design.INK)
	if on_page(parent):style.set_content_margin_all(18)
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
			var aim=view.world_mouse()
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

const NAV_ROUTES=[["inicio","Início"],["equipe","Equipe"],["mapa","Mapa"],["loja","Mochila"],["breeding","Linhagens"],["treino","Treino"],["mercado","Mercado"],["casa","Minha casa"],["profissao","Profissão"],["ranking","Liga e saguão"]]

func brand(parent:Node,origin:Vector2,scale_factor:float=1.0):
	var seal=Paper.make("logo",Rect2(origin,Vector2(70,70)*scale_factor))
	parent.add_child(seal)
	var small=Label.new()
	small.text="POKÉMON"
	small.add_theme_font_override("font",Design.spaced_font())
	small.add_theme_font_size_override("font_size",roundi(17*scale_factor))
	small.add_theme_color_override("font_color",Color("#f4ead6"))
	small.position=origin+Vector2(78,2)*scale_factor
	parent.add_child(small)
	var big=Label.new()
	big.text="AURORA"
	big.add_theme_font_override("font",Design.spaced_font())
	big.add_theme_font_size_override("font_size",roundi(46*scale_factor))
	big.add_theme_color_override("font_color",Color("#fbf6ea"))
	big.position=origin+Vector2(74,14)*scale_factor
	parent.add_child(big)
	var kana=Label.new()
	kana.text="ポケモン オーロラ"
	var jp=SystemFont.new()
	jp.font_names=PackedStringArray(["Yu Gothic UI","Meiryo UI","Meiryo","MS Gothic","Noto Sans CJK JP","WenQuanYi Zen Hei"])
	kana.add_theme_font_override("font",jp)
	kana.add_theme_font_size_override("font_size",roundi(13*scale_factor))
	kana.add_theme_color_override("font_color",Color("#c9d6d6"))
	kana.position=origin+Vector2(96,78)*scale_factor
	parent.add_child(kana)

func nav_item(parent:Node,route:String,text:String,active:bool)->Button:
	var item=Button.new()
	item.text=text.to_upper()
	item.alignment=HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size=Vector2(222,54)
	item.add_theme_font_override("font",display_font)
	item.add_theme_font_size_override("font_size",20)
	var idle=Design.surface(Color.TRANSPARENT,12,Color.TRANSPARENT,0)
	idle.content_margin_left=20
	var hover=Design.surface(Color("#1d3a48"),12,Color("#1d3a48"),0)
	hover.content_margin_left=20
	var on=Design.surface(Design.CORAL,12,Design.CORAL_DARK,0)
	on.border_width_bottom=3
	on.content_margin_left=20
	item.add_theme_stylebox_override("normal",on if active else idle)
	item.add_theme_stylebox_override("hover",on if active else hover)
	item.add_theme_stylebox_override("pressed",on)
	var focus=Design.surface(Color.TRANSPARENT,12,Design.MINT,3)
	item.add_theme_stylebox_override("focus",focus)
	for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		item.add_theme_color_override(state,Color("#fbf6ea"))
	parent.add_child(item)
	with_icon(item,{"loja":"mochila","breeding":"linhagens"}.get(route,route),26)
	item.add_theme_constant_override("h_separation",16)
	if route=="inicio":item.pressed.connect(close_panel)
	else:item.pressed.connect(open_panel.bind(route))
	return item

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
	var night=ColorRect.new()
	night.color=Design.NIGHT
	night.size=overlay.size
	overlay.add_child(night)
	# Faixa superior com o banner do mapa de Aurora.
	var banner=TextureRect.new()
	banner.texture=preload("res://assets/ui/aurora-banner.png")
	banner.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode=TextureRect.STRETCH_SCALE
	banner.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	banner.size=Vector2(1920,640)
	banner.position=Vector2(0,-262)
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(banner)
	var shade=ColorRect.new()
	shade.color=Color(Design.NIGHT,.0)
	shade.size=Vector2(1920,150)
	overlay.add_child(shade)
	brand(overlay,Vector2(30,24))
	var x=300 if not data.is_empty() else 238
	var sheet_x=268 if not data.is_empty() else 206
	var rail=Paper.make("rail",Rect2(12,150,244,918))
	overlay.add_child(rail)
	var sheet=Paper.make("panel",Rect2(sheet_x,150,1908-sheet_x,918))
	sheet.seed_value=title.hash()%97
	overlay.add_child(sheet)
	var nav=column(overlay,6)
	nav.position=Vector2(22,170)
	var section={"guarda-roupa":"casa","wardrobe":"casa","pc":"casa","genes":genes_return,"comida":"profissao","lago":"mapa","jardim":"casa","vila":"mapa"}.get(screen,screen)
	for route in NAV_ROUTES:
		nav_item(nav,route[0],route[1],route[0]==section)
	var close=btn(overlay,"Fechar · Esc",close_panel,190,"fechar")
	close.position=Vector2(1700,44)
	var heading=Label.new()
	heading.text=title.to_upper()
	heading.add_theme_font_override("font",display_font)
	heading.add_theme_font_size_override("font_size",58)
	heading.add_theme_color_override("font_color",Design.INK)
	heading.position=Vector2(x,160)
	overlay.add_child(heading)
	var title_width=display_font.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,58).x
	var sub=Label.new()
	sub.text=subtitle.to_upper()
	sub.add_theme_font_override("font",Design.spaced_font())
	sub.add_theme_font_size_override("font_size",15)
	sub.add_theme_color_override("font_color",Color("#3f4d50"))
	sub.position=Vector2(x+title_width+34,200)
	sub.size=Vector2(maxf(200,1180-title_width),24)
	sub.clip_text=true
	overlay.add_child(sub)
	var rule=ColorRect.new()
	rule.color=Design.CORAL
	rule.position=Vector2(x,252)
	rule.size=Vector2(64,4)
	overlay.add_child(rule)
	var hairline=ColorRect.new()
	hairline.color=Color("#d6c9ae")
	hairline.position=Vector2(x+64,253)
	hairline.size=Vector2(1876-x-64-20,2)
	overlay.add_child(hairline)
	header_actions=HBoxContainer.new()
	header_actions.theme=page_theme
	header_actions.add_theme_constant_override("separation",14)
	header_actions.alignment=BoxContainer.ALIGNMENT_END
	header_actions.position=Vector2(1180,176)
	header_actions.size=Vector2(690,56)
	overlay.add_child(header_actions)
	var scroll=ScrollContainer.new()
	scroll.position=Vector2(x,276)
	scroll.size=Vector2(1880-x if not data.is_empty() else 1444,776)
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

const TYPE_TONES={"Planta":"#cdeadb","Fogo":"#f6d2b8","Água":"#cbe3ef","Elétrico":"#f6e7ad","Fantasma":"#ddd0ea","Normal":"#f3d6cf","Pedra":"#e3d8c3","Gelo":"#d6eef3"}
const STAT_ROWS=[["PS","ps",0],["ATQ","atq",1],["DEF","def",2],["VEL","vel",5],["ESP","esp",3],["RES","res",4]]

func special_move(m:Dictionary)->String:
	if int(m.get("species",0))==131:return "Raio de Gelo"
	return {"Planta":"Raio Solar","Fogo":"Explosão de Fogo","Água":"Hidro Bomba","Elétrico":"Trovão","Normal":"Ataque Rápido","Fantasma":"Bola Sombria","Pedra":"Deslize de Pedras"}.get(game_type(m),"Golpe Especial")

func move_icon(m:Dictionary)->Array:
	return {"Planta":["folha",Design.GREEN],"Fogo":["brilho",Design.CORAL],"Água":["agua",Design.SKY],"Elétrico":["vel",Design.GOLD],"Fantasma":["esp",Color("#7a5ea8")]}.get(game_type(m),["esp",Design.INK])

func segmented(parent:Node,value:float,maximum:float,color:Color=Design.GREEN,segments:int=10,width:float=150,height:float=12)->HBoxContainer:
	var track=HBoxContainer.new()
	track.add_theme_constant_override("separation",2)
	track.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var filled=roundi(clampf(value/maxf(1,maximum),0,1)*segments)
	for i in segments:
		var cell=ColorRect.new()
		cell.color=color if i<filled else Color("#e2d9c6")
		cell.custom_minimum_size=Vector2((width-2*(segments-1))/segments,height)
		track.add_child(cell)
	parent.add_child(track)
	return track

func portrait_disc(parent:Node,m:Dictionary,diameter:float)->PanelContainer:
	var plate=PanelContainer.new()
	var plate_style=Design.surface(Color(TYPE_TONES.get(game_type(m),"#eed7c5")),int(diameter/2),Color.TRANSPARENT,0)
	plate_style.set_content_margin_all(diameter*.08)
	plate.add_theme_stylebox_override("panel",plate_style)
	plate.custom_minimum_size=Vector2(diameter,diameter)
	plate.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	parent.add_child(plate)
	var image=TextureRect.new()
	image.texture=view.mon_texture(m)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_child(image)
	return plate

func mon_card(parent:Node,m:Dictionary,choose:bool=false):
	var card=panel(parent)
	card.custom_minimum_size.x=500 if parent is HBoxContainer else 0
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var c=column(card,12)
	var body=row(c,18)
	portrait_disc(body,m,160)
	var info=column(body,6)
	info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var head=row(info,8)
	var title=label(head,mon_name(m).to_upper(),26)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(head,"#%03d"%int(m.species),13,Color("#8a8a7c"))
	label(info,"Nv. %d  •  %s  •  %s  •  Vínculo %d"%[m.level,game_type(m),str(m.sex),m.get("affinity",50)],15,Color("#3c4a4c"))
	var stats=column(info,3)
	for entry in STAT_ROWS:
		var line=row(stats,8)
		line.add_child(Icons.make(entry[1],Design.INK,16))
		var stat_name=label(line,entry[0],12,Color("#2c3a3d"))
		stat_name.custom_minimum_size.x=40
		var value=float(m.iv[entry[2]])
		var bar=segmented(line,value,31,Design.GREEN,10,130)
		bar.tooltip_text="IV %d / 31 · EV %d"%[int(value),int(m.ev[entry[2]])]
		label(line,str(int(value)),12,Color("#6b6f66"))
	var rule=ColorRect.new()
	rule.color=Color("#e0d5bf")
	rule.custom_minimum_size.y=2
	c.add_child(rule)
	var foot=row(c,12)
	var foot_label=Label.new()
	foot_label.text="GOLPE MAIS FORTE"
	foot_label.add_theme_font_override("font",Design.spaced_font())
	foot_label.add_theme_font_size_override("font_size",12)
	foot_label.add_theme_color_override("font_color",Color("#4d5856"))
	foot_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	foot.add_child(foot_label)
	var icon=move_icon(m)
	foot.add_child(Icons.make(icon[0],icon[1],26))
	var move_name=label(foot,special_move(m),20)
	move_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label(foot,str(m.look.pattern),12,Color("#6b6f66"))
	var actions=row(c,10)
	if choose:
		var select=btn(actions,"Selecionar",func():toggle_partner(m.id),0,"troca")
		picks[m.id]=select
		style_pick(m.id)
		btn(actions,"Genes",func():genome_panel(m),0,"genes")
	elif screen!="genes":btn(actions,"Genes e linhagem",func():genome_panel(m),0,"genes")

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
	button.text=("Na equipe · %d"%(order+1) if screen=="equipe" else "Selecionado · %d"%(order+1)) if order>=0 else "Selecionar"
	button.text=button.text.to_upper()
	if order>=0:Design.primary(button)
	else:
		for state in ["normal","hover","pressed"]:button.remove_theme_stylebox_override(state)
		for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:button.remove_theme_color_override(state)

func spaced(parent:Node,text:String,size:int=13,color:Color=Color("#4d5856"))->Label:
	var l=Label.new()
	l.text=text.to_upper()
	l.add_theme_font_override("font",Design.spaced_font())
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l

func chip(parent:Node,icon_name:String,text:String,tint:Color=Design.INK)->HBoxContainer:
	var shell=PanelContainer.new()
	var style=Design.surface(Design.CARD,10,Color("#cdbd9c"),2)
	style.content_margin_top=8;style.content_margin_bottom=8
	shell.add_theme_stylebox_override("panel",style)
	parent.add_child(shell)
	var line=row(shell,10)
	line.add_child(Icons.make(icon_name,tint,22))
	label(line,text,16,Design.INK)
	return line

func pill(parent:Node,text:String,color:Color,text_color:Color=Color.WHITE)->PanelContainer:
	var shell=PanelContainer.new()
	var style=Design.surface(color,14,color.darkened(.2),0)
	style.content_margin_top=4;style.content_margin_bottom=4;style.content_margin_left=12;style.content_margin_right=12
	shell.add_theme_stylebox_override("panel",style)
	shell.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	shell.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	parent.add_child(shell)
	var l=Label.new();l.text=text;l.add_theme_font_override("font",display_font);l.add_theme_font_size_override("font_size",15);l.add_theme_color_override("font_color",text_color)
	shell.add_child(l)
	return shell

func drawing(parent:Node,kind:String,dimensions:Vector2,stage:int=0)->Control:
	var art=Paper.make(kind,Rect2(Vector2.ZERO,dimensions))
	art.stage=stage
	art.custom_minimum_size=dimensions
	art.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	parent.add_child(art)
	return art

func progress(parent:Node,maximum:float,color:Color=Design.GREEN,width:float=260,height:float=16)->ProgressBar:
	var bar=ProgressBar.new()
	bar.max_value=maximum
	bar.show_percentage=false
	bar.custom_minimum_size=Vector2(width,height)
	bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var fill=Design.surface(color,6,color.darkened(.25),0);fill.set_content_margin_all(0)
	var back=Design.surface(Color("#e6dcc8"),6,Color("#b9aa8b"),2);back.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill",fill)
	bar.add_theme_stylebox_override("background",back)
	parent.add_child(bar)
	return bar

func clock_text(seconds:int)->String:
	return "%02dh %02dmin"%[seconds/3600,(seconds%3600)/60] if seconds>=3600 else "%02d:%02d"%[seconds/60,seconds%60]

func open_panel(which:String):
	if data.is_empty():return
	if which!=screen:
		selected.clear()
		if which=="equipe":selected.assign(data.player.team)
	screen=which
	var titles={
		"equipe":["Minha equipe","Seus Pokémon em Aurora"],
		"mapa":["Mapa de Aurora","Escolha um destino. Para voar até ele, visite a área primeiro."],
		"loja":["Mochila e loja","Compre suprimentos para a jornada e objetos para sua casa."],
		"breeding":["Linhagens","Cruzamentos, genes e incubadora"],
		"mercado":["Mercado","Compre e anuncie exemplares"],
		"treino":["Treinamento","Escolha seus parceiros e o atributo que deseja treinar."],
		"profissao":["Ofícios e cozinha","Escolha uma profissão, entregue tarefas ou prepare uma refeição."],
		"ranking":["Liga e saguão","Batalhas, rankings e conversa"],
		"casa":["Minha casa","Troque de roupa, decore o quarto ou ligue o computador."],
		"vila":["Vila Alvorada","Converse ou presenteie um morador."],
		"jardim":["Jardim de berries","Cultive, regue e colha berries"],
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
				Design.primary(btn(header_actions,"Salvar equipe",func():send({"type":"team","ids":selected}),0,"salvar"));btn(header_actions,"Pokédex",func():send({"type":"dex"}),0,"pokedex");btn(header_actions,"Evoluir",func():send({"type":"evolve","ids":selected}),0,"evoluir");label(overlay_body,"A ordem de seleção define quem entra primeiro na batalha. Equipe atual: %d/6."%p.team.size(),14)
			if which=="breeding":
				btn(header_actions,"Prever",func():send({"type":"predict","ids":selected}),0,"genes");Design.primary(btn(header_actions,"Cruzar · 3 berries",func():send({"type":"breed","ids":selected}),0,"linhagens"));btn(header_actions,"Chocar ovo",func():send({"type":"hatch"}),0,"ovo")
				label(overlay_body,"Selecione dois parceiros de sexos diferentes e do mesmo grupo de ovos. Incubação: 3 minutos.",14)
				if p.get("egg")!=null:
					var incubator=panel(overlay_body)
					incubator.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
					var incubation=row(incubator,28)
					drawing(incubation,"capsule",Vector2(150,190))
					var egg_info=column(incubation,10)
					egg_info.alignment=BoxContainer.ALIGNMENT_CENTER
					spaced(egg_info,"Incubadora de ovos",12)
					label(egg_info,"Ovo de Pokémon",30)
					label(egg_info,"Origem: Laboratório de linhagens",17,Color("#3c4a4c"))
					var bar_line=row(egg_info,12)
					var bar=progress(bar_line,180,Design.GREEN,420,22)
					var pct=label(bar_line,"",20,Design.INK)
					var remaining_line=row(egg_info,8)
					remaining_line.add_child(Icons.make("relogio",Design.INK,22))
					var remaining=label(remaining_line,"",18,Design.INK)
					var timer_node=Timer.new()
					timer_node.wait_time=.5
					remaining.add_child(timer_node)
					var refresh_egg=func():
						var age=clampi(int(server_time()-float(p.egg.at)),0,180)
						bar.value=age
						pct.text="%d%%"%roundi(100.0*age/180)
						remaining.text="Tempo restante: "+clock_text(180-age) if age<180 else "Pronto para chocar!"
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
			var planted=0
			for plot in p.plots:if float(plot.at)>0:planted+=1
			var stats=row(overlay_body,14)
			chip(stats,"broto","Canteiros:  %d / 6"%planted,Design.GREEN)
			chip(stats,"folha","Sementes:  %d"%p.seeds,Design.GREEN)
			chip(stats,"agua","Berries colhidas:  %d"%p.berries,Design.SKY)
			chip(stats,"relogio","Colheita em 90 s após regar",Design.INK)
			var grid=grid_cards(overlay_body,3)
			for i in 6:
				var plot=p.plots[i]
				var card=panel(grid)
				card.custom_minimum_size=Vector2(500,0)
				var c=column(card,10)
				var head=row(c,10)
				head.add_child(Icons.make("broto",Design.GREEN,30))
				var names=column(head,0)
				names.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				label(names,"Canteiro %d"%(i+1),22)
				label(names,"Oran Berry" if float(plot.at)>0 else "Terra livre",14,Color("#5d6763"))
				var body=row(c,16)
				var art=drawing(body,"plot",Vector2(170,110))
				var meters=column(body,8)
				meters.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				meters.alignment=BoxContainer.ALIGNMENT_CENTER
				var leaves=row(meters,4)
				var leaf_icons:Array=[]
				for k in 3:
					var leaf=Icons.make("folha",Color("#cfc6b3"),22);leaves.add_child(leaf);leaf_icons.append(leaf)
				var bar_line=row(meters,8)
				var bar=progress(bar_line,100,Design.GREEN,200,14)
				var pct=label(bar_line,"0%",14,Design.INK)
				var state_line=row(c,8)
				var state_icon=Icons.make("agua",Design.SKY,18);state_line.add_child(state_icon)
				var state=label(state_line,"",14,Design.INK)
				var button:Button
				if float(plot.at)==0:
					state_icon.kind="broto";state_icon.tint=Color("#8a7a5c")
					state.text="Pronto para plantar"
					button=btn(c,"Plantar semente",func():send({"type":"plant","index":i}),0,"broto")
					button.disabled=p.seeds<1
				elif not plot.water:
					art.stage=1
					leaf_icons[0].tint=Design.GREEN
					bar.value=5;pct.text="5%"
					state_line.get_parent().remove_child(state_line)
					var warn=pill(c,"  Precisa de água!",Color("#f9d9d3"),Color("#b23a24"))
					c.move_child(warn,c.get_child_count()-1)
					button=btn(c,"Regar canteiro",func():send({"type":"water","index":i}),0,"agua")
				else:
					button=btn(c,"Colher berry",func():send({"type":"harvest","index":i}),0,"cesta")
					var tick=Timer.new()
					tick.wait_time=0.5
					button.add_child(tick)
					var update=func():
						var wait=maxi(0,ceili(float(plot.at)+90-server_time()))
						var ratio=1.0-wait/90.0
						bar.value=roundi(ratio*100);pct.text="%d%%"%roundi(ratio*100)
						art.stage=3 if wait==0 else (2 if ratio>.4 else 1);art.queue_redraw()
						for k in 3:leaf_icons[k].tint=Design.GREEN if ratio>=k/3.0+.01 or wait==0 else Color("#cfc6b3");leaf_icons[k].queue_redraw()
						state.text="Regado  ·  pronto para colher!" if wait==0 else "Regado  ·  colheita em ~ %s"%clock_text(wait)
						button.disabled=wait>0
						if wait==0:tick.stop()
					tick.timeout.connect(update)
					tick.start()
					update.call()
				button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				Design.primary(button)
		"pc":
			var games=grid_cards(overlay_body,2)
			for pair in [["arcade","Chuva de estrelas","Desvie dos projéteis com seu primeiro parceiro."],["Corrida","Circuito Aurora","Bicicleta ou montaria. Mantenha-se na pista."],["Voo","Ventos do norte","Requer um parceiro de voo."],["Natação","Correnteza azul","Requer um parceiro de natação."]]:
				var c=column(panel(games));c.custom_minimum_size.x=694;label(c,pair[1],24);label(c,pair[2],16);btn(c,"Jogar",func():send({"type":"arcade","value":pair[0]});close_panel())
		"profissao":profession_menu()
		"mercado":market_menu()
		"ranking":lobby_menu()

const SWATCHES={
	"skin":["#f6d7b8","#e9bb94","#d49a6a","#b9794c","#8d5a3b","#6b4330"],
	"hair":["#2b2b2b","#775542","#b4782f","#e6c26b","#c94b2c","#6a6fb0","#e8e8e8"],
	"top":["#3a78c7","#d9483b","#4fa65a","#f0c24a","#8a5cc4","#4a4a4a","#f2f2f2"],
	"bottom":["#f2f2f2","#3a78c7","#d9483b","#f0c24a","#e277b5","#8a5cc4","#a8a8a8"],
	"hat":["#d9483b","#3a78c7","#4fa65a","#f0c24a","#2b2b2b","#f2f2f2","#8a5cc4"]}
const COLOR_DEFAULTS={"skin":"#e9bb94","hair":"#775542","top":"#83ac83","bottom":"#527388","hat":"#8aa5bf"}

func swatch_style(color:Color,chosen:bool)->StyleBoxFlat:
	var style=Design.surface(color,9,Color("#2f6fb3") if chosen else Color("#8b7f68"),4 if chosen else 2)
	style.border_width_bottom=5 if chosen else 4
	return style

func swatch_row(parent:Node,region:String,colors:Dictionary,on_change:Callable):
	var line=row(parent,10)
	var buttons:Array[Button]=[]
	var refresh=func():
		var current=Color(colors.get(region,COLOR_DEFAULTS[region]))
		for button in buttons:
			var chosen=Color(button.get_meta("hex")).is_equal_approx(current)
			for state in ["normal","hover","pressed","focus"]:
				button.add_theme_stylebox_override(state,swatch_style(Color(button.get_meta("hex")),chosen))
			button.get_child(0).visible=chosen
	for hex in SWATCHES[region]:
		var b=Button.new()
		b.custom_minimum_size=Vector2(48,44)
		b.set_meta("hex",hex)
		b.tooltip_text=hex
		var check=PanelContainer.new()
		var check_style=Design.surface(Color("#2f6fb3"),9,Color.WHITE,2)
		check_style.set_content_margin_all(0)
		check.add_theme_stylebox_override("panel",check_style)
		check.size=Vector2(18,18);check.position=Vector2(32,26)
		check.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var mark=Label.new();mark.text="✓";mark.add_theme_font_size_override("font_size",12);mark.add_theme_color_override("font_color",Color.WHITE);mark.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		check.add_child(mark)
		b.add_child(check)
		b.pressed.connect(func():colors[region]=hex;refresh.call();on_change.call())
		line.add_child(b)
		buttons.append(b)
	var custom=ColorPickerButton.new()
	custom.theme=page_theme
	custom.text="+"
	custom.tooltip_text="Outra cor"
	custom.color=Color(colors.get(region,COLOR_DEFAULTS[region]))
	custom.custom_minimum_size=Vector2(48,44)
	custom.color_changed.connect(func(color):colors[region]="#"+color.to_html(false);refresh.call();on_change.call())
	line.add_child(custom)
	refresh.call()

func wardrobe_menu():
	screen="wardrobe"
	modal("Guarda-roupa","Personalize seu treinador")
	var draft:Dictionary=data.player.get("look",{}).duplicate(true)
	if draft.is_empty():draft={"gender":"m","hair":"boy2","top":"jacket","bottom":"jeans","hat":"","acc":"","bag":""}
	var colors:Dictionary=data.player.get("colors",{}).duplicate(true)
	var layout=row(overlay_body,28)
	var preview_card=panel(layout);preview_card.custom_minimum_size=Vector2(440,700)
	var pc=column(preview_card,14)
	pc.alignment=BoxContainer.ALIGNMENT_CENTER
	var disc=PanelContainer.new()
	var disc_style=Design.surface(Color("#e9e0cf"),190,Color("#d8ccb3"),2)
	disc_style.set_content_margin_all(12)
	disc.add_theme_stylebox_override("panel",disc_style)
	disc.custom_minimum_size=Vector2(380,380)
	disc.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	pc.add_child(disc)
	var portrait=TextureRect.new();portrait.texture=view.indigo.compose(draft,colors,"front");portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;disc.add_child(portrait)
	var redraw=func():portrait.texture=view.indigo.compose(draft,colors,"front")
	var name_label=label(pc,data.player.name.to_upper(),28)
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var credit=label(pc,"Camadas Gen 4 · Coffee Cup / Poltergeist",12,Color("#6b6f66"))
	credit.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var controls=column(layout,12);controls.custom_minimum_size.x=760
	var top_line=row(controls,16)
	var base_box=column(top_line,4);base_box.custom_minimum_size.x=372
	label(base_box,"Corpo",15,Color("#2c3a3d"))
	var gender=OptionButton.new();gender.add_item("Base masculina");gender.add_item("Base feminina");gender.selected=0 if draft.gender=="m" else 1;gender.custom_minimum_size.y=50;base_box.add_child(gender);gender.item_selected.connect(func(i):draft.gender="m" if i==0 else "f";redraw.call())
	var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",10);controls.add_child(grid)
	var names={"top":"Estilo de roupa","bottom":"Parte de baixo","hair":"Cabelo","hat":"Chapéu","acc":"Acessório","bag":"Mochila"}
	for slot in names:
		var c=column(grid,4);c.custom_minimum_size.x=372;label(c,names[slot],15,Color("#2c3a3d"));var select=OptionButton.new();select.custom_minimum_size.y=50;c.add_child(select)
		var choices:Array=[]
		if slot in ["hat","bag","acc"]:choices.append("")
		choices.append_array(view.indigo.catalog.order[slot])
		for choice in choices:
			var key=slot+"|"+str(choice)+"|"+str(draft.gender);var part=view.indigo.catalog.parts.get(key,view.indigo.catalog.parts.get(slot+"|"+str(choice)+"|x",{}));var name=str(part.get("name",[choice,choice])[1]) if choice!="" else "Nenhum";select.add_item(name)
		select.selected=max(0,choices.find(draft.get(slot,"")))
		select.item_selected.connect(func(i):draft[slot]=choices[i];redraw.call())
	var palette=panel(controls)
	var swatches=column(palette,8)
	for pair in [["top","Cor principal"],["bottom","Cor secundária"],["hair","Cabelo"],["skin","Pele"],["hat","Chapéu"]]:
		var line=row(swatches,16)
		var caption=label(line,pair[1],15,Color("#2c3a3d"))
		caption.custom_minimum_size.x=150
		caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		swatch_row(line,pair[0],colors,redraw)
	var save=btn(controls,"Salvar aparência",func():send({"type":"appearance","look":draft,"colors":colors});close_panel(),0,"salvar")
	save.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	save.custom_minimum_size.y=62
	Design.primary(save)

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
	var r=row(overlay_body,12);var price_label=label(r,"Anunciar selecionado por",16);price_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER;var price=SpinBox.new();price.min_value=1;price.max_value=100000;price.value=500;price.suffix="moedas";price.custom_minimum_size=Vector2(200,48);r.add_child(price);Design.primary(btn(r,"Anunciar",func():send({"type":"list","ids":selected,"index":int(price.value)}),0,"mercado"))
	label(overlay_body,"Retire o Pokémon da equipe e do treino antes de anunciar. A transferência preserva genes e IVs.",14)
	spaced(overlay_body,"Anúncios do mercado",13)
	offers_grid=grid_cards(overlay_body,2)
	update_offers()
	spaced(overlay_body,"Seus exemplares",13)
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
		var card=panel(offers_grid)
		var line=row(card,22)
		portrait_disc(line,offer.mon,150)
		var info=column(line,6)
		info.custom_minimum_size.x=230
		info.alignment=BoxContainer.ALIGNMENT_CENTER
		label(info,mon_name(offer.mon).to_upper(),30)
		label(info,"Nv. %d  •  %s"%[offer.mon.level,game_type(offer.mon)],17,Color("#3c4a4c"))
		var rule=ColorRect.new();rule.color=Color("#e0d5bf");rule.custom_minimum_size.y=2;info.add_child(rule)
		label(info,"Vendedor: %s"%offer.name,16,Color("#3c4a4c"))
		var genes=btn(info,"Ver genes",func():genome_panel(offer.mon),0,"genes")
		genes.custom_minimum_size.y=42
		var buy=column(line,10)
		buy.alignment=BoxContainer.ALIGNMENT_CENTER
		var price_title=spaced(buy,"Preço",13)
		price_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var price_box=PanelContainer.new()
		var price_style=Design.surface(Color("#fffdf6"),10,Color("#8b7f68"),2)
		price_box.add_theme_stylebox_override("panel",price_style)
		buy.add_child(price_box)
		var price_line=row(price_box,10)
		price_line.alignment=BoxContainer.ALIGNMENT_CENTER
		price_line.add_child(Icons.make("moeda",Design.INK,26))
		label(price_line,_thousands(int(offer.price)),28)
		if offer.seller==data.player.id:btn(buy,"Cancelar anúncio",func():send({"type":"cancel_listing","value":offer.id}),210,"fechar")
		else:
			var purchase=btn(buy,"Comprar",func():send({"type":"purchase","value":offer.id}),210,"carrinho")
			purchase.custom_minimum_size.y=58
			Design.primary(purchase)

func _thousands(value:int)->String:
	var text=str(absi(value))
	var out=""
	while text.length()>3:
		out="."+text.substr(text.length()-3)+out
		text=text.substr(0,text.length()-3)
	return ("-" if value<0 else "")+text+out

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
	var badge=PanelContainer.new()
	var badge_style=Design.surface(Design.CARD,10,Color("#8b7f68"),2)
	badge.add_theme_stylebox_override("panel",badge_style)
	header_actions.add_child(badge)
	var badge_line=row(badge,10)
	badge_line.add_child(Icons.make("ranking",Design.INK,28))
	var badge_text=column(badge_line,0)
	label(badge_text,"LIGA DE AURORA",18,Design.INK)
	label(badge_text,"Temporada 1",12,Color("#5d6763"))
	var r=row(overlay_body,12)
	Design.primary(btn(r,"Desafiar Flora",func():send({"type":"gym"});close_panel(),0,"lutar"))
	btn(r,"Ir ao ginásio",func():send({"type":"travel","area":"ginasio"}),0,"mapa")
	btn(r,"Buscar / cancelar duelo",func():send({"type":"queue"}),0,"troca")
	lobby_auto=btn(r,"",func():send({"type":"auto"}),0,"evoluir")
	var cards=row(overlay_body,16)
	for entry in [["matches","Assistir batalha","tv",660],["ranks","Ranking da liga","ranking",330],["chat","Chat do saguão","chat",430]]:
		var card=panel(cards)
		var content=column(card,12)
		content.custom_minimum_size=Vector2(entry[3],560)
		var head=row(content,10)
		head.add_child(Icons.make(entry[2],Design.INK,24))
		label(head,entry[1].to_upper(),20,Design.INK)
		var rule=ColorRect.new();rule.color=Color("#e0d5bf");rule.custom_minimum_size.y=2;content.add_child(rule)
		lobby_lists[entry[0]]=column(content,10)
		lobby_lists[entry[0]].size_flags_vertical=Control.SIZE_EXPAND_FILL
		if entry[0]=="chat":
			var compose=row(content,8)
			message_input=LineEdit.new()
			message_input.placeholder_text="Converse no saguão…"
			message_input.max_length=200
			message_input.custom_minimum_size=Vector2(300,48)
			message_input.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			compose.add_child(message_input)
			message_input.text_submitted.connect(chat_submit)
			lobby_send=btn(compose,"",func():chat_submit(message_input.text),60,"enviar")
			lobby_send.tooltip_text="Enviar"
			Design.primary(lobby_send)
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
	message_input.placeholder_text="Converse no saguão…" if can_chat else "Visite o ginásio para conversar"
	lobby_send.disabled=not can_chat
	lobby_auto.text=("Automático: "+("sim" if data.player.auto else "não")).to_upper()
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
	if matches.is_empty():
		label(lobby_lists.matches,"Nenhuma batalha em andamento.",18,Design.INK)
		label(lobby_lists.matches,"Desafie Flora ou entre na fila de duelos para aparecer aqui.",15,Color("#5d6763"))
	for battle in data.get("battles",[]):
		var top=row(lobby_lists.matches,12)
		pill(top,"●  AO VIVO",Design.CORAL)
		label(top,{"gym":"Desafio de ginásio","pvp":"Batalha ranqueada","capture":"Encontro selvagem"}.get(str(battle.get("kind","")),"Batalha")+"  ·  tempo real",15,Design.INK)
		var stage=Control.new()
		stage.custom_minimum_size=Vector2(640,300)
		stage.clip_contents=true
		lobby_lists.matches.add_child(stage)
		var field=Paper.make("field",Rect2(0,0,640,300))
		stage.add_child(field)
		for k in battle.fighters.size():
			var fighter=battle.fighters[k]
			var sprite=TextureRect.new()
			sprite.texture=view.mon_texture(fighter.mon)
			sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.size=Vector2(130,130)
			sprite.position=Vector2(150,140) if k==0 else Vector2(400,50)
			stage.add_child(sprite)
			var tag=PanelContainer.new()
			var tag_style=Design.surface(Design.CARD,8,Design.NIGHT,2);tag_style.content_margin_top=4;tag_style.content_margin_bottom=4;tag_style.content_margin_left=10;tag_style.content_margin_right=10
			tag.add_theme_stylebox_override("panel",tag_style)
			tag.position=Vector2(20,226) if k==0 else Vector2(440,14)
			stage.add_child(tag)
			var tag_col=column(tag,2)
			var tag_head=row(tag_col,12)
			label(tag_head,game_mon_label(fighter),15,Design.INK)
			label(tag_head,"Nv. %d"%fighter.mon.level,14,Design.INK)
			var hp=progress(tag_col,maxf(1,float(fighter.max_hp)),Design.GREEN,190,8)
			hp.value=maxf(0,float(fighter.hp))
		var versus=row(lobby_lists.matches,20)
		versus.alignment=BoxContainer.ALIGNMENT_CENTER
		label(versus,str(battle.fighters[0].name),20,Design.INK)
		label(versus,"VS",26,Design.CORAL)
		label(versus,str(battle.fighters[1].name),20,Design.INK)
		var watch=btn(lobby_lists.matches,"Assistir batalha",func():spectate=battle.id;close_panel(),0,"tv")
		Design.primary(watch)
	var medals=[Color("#e7b443"),Color("#b9bec4"),Color("#c98a4b")]
	for i in data.rankings.size():
		var rank=data.rankings[i]
		var line=row(lobby_lists.ranks,10)
		var medal=PanelContainer.new()
		var medal_style=Design.surface(medals[i] if i<3 else Color.TRANSPARENT,14,(medals[i] if i<3 else Color.TRANSPARENT).darkened(.25),2 if i<3 else 0)
		medal_style.set_content_margin_all(0)
		medal.add_theme_stylebox_override("panel",medal_style)
		medal.custom_minimum_size=Vector2(30,30)
		line.add_child(medal)
		var number=label(medal,str(i+1),14,Design.INK)
		number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var who=column(line,0)
		who.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label(who,str(rank.name),16,Design.INK)
		var record=float(rank.records.get("gym",0))
		label(who,"%d V / %d D%s"%[rank.wins,rank.losses,"  ·  %.1f s"%record if record>0 else ""],12,Color("#6b6f66"))
		label(line,"%s pts"%_thousands(int(rank.rating)),15,Design.INK)
	if data.chat.is_empty():label(lobby_lists.chat,"Nenhuma mensagem ainda.",16,Color("#5d6763"))
	for msg in data.chat.slice(-8):
		var bubble=column(lobby_lists.chat,0)
		label(bubble,str(msg.name),16,Design.INK).add_theme_font_override("font",display_font)
		var line=label(bubble,str(msg.text),15,Color("#2c3a3d"))
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x=390

func game_mon_label(fighter:Dictionary)->String:
	return mon_name(fighter.mon)

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
			for k in 4:
				if event.keycode==KEY_1+k or event.keycode==KEY_KP_1+k:view.local_action("move");send({"type":"move","index":k})
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
		elif not event.pressed and data.player.area=="safari" and data.player.safari!=null:
			var target=view.world_mouse();send({"type":"throw","pos":{"x":target.x,"y":target.y}})
		elif event.pressed and data.player.area=="casa":
			if Rect2(340,140,120,100).has_point(pos):open_panel("pc")
			elif Rect2(350,65,110,110).has_point(pos):open_panel("casa")
			elif Rect2(222,320,70,45).has_point(pos):send({"type":"travel","area":"vila"})
