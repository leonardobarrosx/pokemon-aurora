extends Control

var game:Node
var signature=""
var bars:Dictionary={}
var clock_label:Label
var action_buttons:Dictionary={}
const Design=preload("res://aurora_theme.gd")
const CYAN=Design.MINT
const Icons=preload("res://aurora_icons.gd")
var score_label:Label
var context_label:Label
var live_label:Label
const GOLD=Color("eac57d")

func _ready():
	size=Vector2(1920,1080);mouse_filter=Control.MOUSE_FILTER_IGNORE

func active_battle():
	if game.data.get("battle")!=null:return game.data.battle
	for b in game.data.get("battles",[]):
		if b.id==game.spectate:return b
	return null

func floating(pos:Vector2,dimensions:Vector2,_color:Color=Color("111b2c"))->PanelContainer:
	return battle_box(pos,dimensions)

func refresh():
	if game.data.is_empty():return
	var p=game.data.player;var b=active_battle()
	var combat_key=[]
	if b!=null:
		for f in b.fighters:combat_key.append([f.owner,f.mon.id,f.mon.species,f.mon.level])
	var portraits=[]
	for i in p.team.size():
		var mon=game.team_mon(i)
		portraits.append([mon.id,mon.species,mon.get("look",{})])
	var activity=p.get("arcade")
	var kind="" if activity==null else str(activity.kind)
	var battle_mode=b.kind if b!=null else ""
	var key=JSON.stringify([p.area,p.name,portraits,p.quest,p.coins,p.points,p.xp,p.balls,game.data.players.size(),game.spectate,combat_key,battle_mode,kind])
	if key==signature:return
	signature=key
	for child in get_children():child.queue_free()
	game.arena_backdrop.visible=false
	game.view_clip.clip_contents=false
	bars.clear();action_buttons.clear();clock_label=null;score_label=null;context_label=null;live_label=null
	if b!=null:arena(b)
	elif activity!=null:minigame(activity)
	else:exploration(p)
	update_values()

func portrait(parent:Node,m:Dictionary,dimensions:Vector2):
	var im=TextureRect.new();im.texture=game.view.mon_texture(m);im.custom_minimum_size=dimensions
	im.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;im.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	im.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(im)

func meter(parent:Node,color:Color,width:float=280,height:float=12)->ProgressBar:
	var bar=ProgressBar.new();bar.custom_minimum_size=Vector2(width,height);bar.show_percentage=false
	var style=Design.surface(color,3,color.darkened(.25),0);style.set_content_margin_all(0);bar.add_theme_stylebox_override("fill",style)
	var background=Design.surface(Color("#0a1620"),3,Color("#33505a"),1);background.set_content_margin_all(0);bar.add_theme_stylebox_override("background",background)
	parent.add_child(bar);return bar

func battle_box(pos:Vector2,dimensions:Vector2)->PanelContainer:
	var p=PanelContainer.new()
	var style=Design.surface(Design.NIGHT,12,Color("#d8cbb0"),3)
	style.set_content_margin_all(14)
	style.shadow_color=Color(0,0,0,.25);style.shadow_size=6;style.shadow_offset=Vector2(0,3)
	p.add_theme_stylebox_override("panel",style)
	p.position=pos;p.size=dimensions
	add_child(p)
	return p

func fighter_card(f:Dictionary,right:bool):
	var shell=battle_box(Vector2(1220 if right else 228,14),Vector2(472,118))
	var r=game.row(shell,14)
	if not right:portrait(r,f.mon,Vector2(76,80))
	var c=game.column(r,4);c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var head=game.row(c,10)
	if right:head.alignment=BoxContainer.ALIGNMENT_END
	var title=game.label(head,game.mon_name(f.mon),20,Color("#fbf6ea"))
	game.label(head,"Nv. %d"%f.mon.level,15,Color("#c9d6d6"))
	var owner=game.label(head,"· "+str(f.name),13,Color("#9fb7bb"))
	if str(f.name)==game.mon_name(f.mon):owner.hide()
	var hp=meter(c,Color("#9c6ad6") if right else Design.GREEN,330,14)
	var energy=meter(c,Color("#5bb8e8"),330,5)
	var values=game.label(c,"",12,Color("#c9d6d6"))
	if right:values.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	bars[f.owner]={"hp":hp,"energy":energy,"values":values}
	if right:portrait(r,f.mon,Vector2(76,80))
	var roster=game.column(self,8);roster.position=Vector2(1500 if right else 236,170)
	var heading=Label.new();heading.text="ADVERSÁRIO" if right else "EQUIPE";heading.add_theme_font_override("font",Design.spaced_font());heading.add_theme_font_size_override("font_size",12);heading.add_theme_color_override("font_color",Color("#4d5856"));roster.add_child(heading)
	roster.theme=game.page_theme
	if f.owner==game.data.player.id:
		for i in 6:
			var slot=PanelContainer.new()
			var used=i<game.data.player.team.size()
			var slot_style=Design.surface(Design.CARD if used else Color("#e7dcc6"),8,Color("#bfae8d"),2);slot_style.set_content_margin_all(3)
			slot.add_theme_stylebox_override("panel",slot_style)
			slot.custom_minimum_size=Vector2(184,48)
			roster.add_child(slot)
			if used:
				var line=game.row(slot,10)
				portrait(line,game.team_mon(i),Vector2(40,38))
				game.label(line,game.mon_name(game.team_mon(i)),14,Design.INK)
	else:
		var slot=PanelContainer.new()
		var slot_style=Design.surface(Design.CARD,8,Color("#bfae8d"),2);slot_style.set_content_margin_all(6)
		slot.add_theme_stylebox_override("panel",slot_style)
		slot.custom_minimum_size=Vector2(184,48)
		roster.add_child(slot)
		var info=game.column(slot,0)
		game.label(info,"Selvagem" if str(f.name)==game.mon_name(f.mon) else str(f.name),15,Design.INK)
		game.label(info,game.mon_name(f.mon)+" · %.1f kg"%float(f.physique.mass),12,Color("#5d6763"))

func arena(b:Dictionary):
	game.arena_backdrop.visible=true
	game.view_clip.clip_contents=true
	# Moldura da arena: o campo é a área de 1024×768 desenhada pelo mundo.
	var frame=Panel.new()
	var frame_style=StyleBoxFlat.new()
	frame_style.draw_center=false
	frame_style.set_border_width_all(5)
	frame_style.border_color=Design.NIGHT
	frame_style.set_corner_radius_all(10)
	frame_style.set_expand_margin_all(5)
	frame.add_theme_stylebox_override("panel",frame_style)
	frame.position=Vector2(448,156);frame.size=Vector2(1024,768)
	frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	fighter_card(b.fighters[0],false);fighter_card(b.fighters[1],true)
	var middle=game.column(battle_box(Vector2(782,14),Vector2(356,118)),0)
	var kind={"capture":"ENCONTRO SELVAGEM","gym":"DESAFIO DE GINÁSIO","pvp":"DUELO DE TREINADORES","event":"ENCONTRO LENDÁRIO"}.get(b.kind,"ARENA AURORA")
	var caption=Label.new();caption.text=kind;caption.add_theme_font_override("font",Design.spaced_font());caption.add_theme_font_size_override("font_size",12);caption.add_theme_color_override("font_color",GOLD);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;middle.add_child(caption)
	clock_label=game.label(middle,"00:00",36,Color("#fbf6ea"));clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	live_label=Label.new();live_label.text="TEMPO REAL";live_label.add_theme_font_override("font",Design.spaced_font());live_label.add_theme_font_size_override("font_size",11);live_label.add_theme_color_override("font_color",CYAN);live_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;middle.add_child(live_label)
	var mine:Dictionary={}
	for f in b.fighters:
		if f.owner==game.data.player.id:mine=f
	var dock=game.row(self,14)
	dock.theme=game.page_theme
	dock.position=Vector2(236,960);dock.size=Vector2(1448,84)
	dock.alignment=BoxContainer.ALIGNMENT_CENTER
	if mine.is_empty():
		var leave=game.btn(dock,"Espectador · Sair",func():game.spectate="";refresh(),300,"fugir");Design.primary(leave);leave.custom_minimum_size.y=64;return
	var special=game.special_move(mine.mon)
	var icon=game.move_icon(mine.mon)[0]
	for entry in [["attack","Lutar · Clique","lutar",232],["special",special+" · Q",icon,300],["dash","Esquiva · Espaço","esquiva",236]]:
		var button=game.btn(dock,entry[1],func():game.view.local_action(entry[0]);game.send({"type":entry[0]}),entry[3],entry[2])
		button.custom_minimum_size.y=64
		if entry[0]=="attack":Design.primary(button)
		action_buttons[entry[0]]={"button":button,"label":entry[1].to_upper()}
	var extra:Button
	if b.kind in ["capture","event"]:extra=game.btn(dock,"Capturar · B  (%d)"%game.data.player.balls,func():game.send({"type":"ball"}),220,"pokemon")
	else:extra=game.btn(dock,"Automático",func():game.send({"type":"auto"}),190,"troca")
	extra.custom_minimum_size.y=64
	game.btn(dock,"Evoluir · V",func():game.send({"type":"evolve","ids":[mine.mon.id]}),170,"evoluir").custom_minimum_size.y=64
	game.btn(dock,"Fugir · F",func():game.send({"type":"flee"}),150,"fugir").custom_minimum_size.y=64
	var hint=game.label(self,"WASD  mover     ·     Mouse  mirar     ·     Desvie das áreas marcadas no chão",12,Color("#3f4d50"));hint.position=Vector2(448,928);hint.size=Vector2(1024,24);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func exploration(p:Dictionary):
	var profile=game.row(floating(Vector2(24,22),Vector2(400,100)),12)
	if not p.team.is_empty():portrait(profile,game.team_mon(0),Vector2(50,52))
	var identity=game.column(profile,2);game.label(identity,p.name,22);game.label(identity,"TREINADOR  /  NÍVEL %d"%(1+int(p.xp)/100),11,CYAN)
	var location=game.column(floating(Vector2(720,22),Vector2(480,94)),3)
	var area=game.label(location,game.AREAS.get(p.area,p.area),22);area.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	context_label=game.label(location,"REGIÃO AURORA",13,GOLD);context_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var wallet=game.column(floating(Vector2(1560,22),Vector2(336,94)),4)
	var money=game.row(wallet,8);money.add_child(Icons.make("moeda",GOLD,20));game.label(money,"%s moedas     %d fichas"%[game._thousands(int(p.coins)),p.points],17,GOLD)
	game.label(wallet,"%d treinador(es) online"%(game.data.players.size()+1),11)
	var quest=game.column(floating(Vector2(1560,140),Vector2(336,180)),7)
	game.label(quest,"DIÁRIO DE JORNADA",11,GOLD)
	var task=game.label(quest,game.QUESTS[min(int(p.quest),4)] if int(p.quest)<5 else "Aurora voltou a brilhar!",15)
	task.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;task.custom_minimum_size.x=220
	var claim=game.btn(quest,"Resgatar missão",func():game.send({"type":"quest"}),0,"ranking");Design.primary(claim)
	var partners=game.column(floating(Vector2(24,148),Vector2(315,104)),6)
	game.label(partners,"MINHA EQUIPE",12,CYAN)
	var team=GridContainer.new()
	team.columns=3
	team.add_theme_constant_override("h_separation",8)
	team.add_theme_constant_override("v_separation",7)
	partners.add_child(team)
	for i in mini(6,p.team.size()):
		var button=game.btn(team,"",func():game.open_panel("equipe"),78)
		button.icon=game.view.mon_texture(game.team_mon(i));button.expand_icon=true;button.custom_minimum_size.y=48
		button.tooltip_text=game.mon_name(game.team_mon(i))
	var dock=game.row(self,12)
	dock.theme=game.page_theme
	dock.position=Vector2(196,972);dock.size=Vector2(1528,72)
	dock.alignment=BoxContainer.ALIGNMENT_CENTER
	for e in [["equipe","Equipe","equipe"],["mapa","Mapa","mapa"],["loja","Mochila","mochila"],["breeding","Linhagens","linhagens"],["ranking","Liga","ranking"],["casa","Casa","casa"]]:
		game.btn(dock,e[1],func():game.open_panel(e[0]),168,e[2]).custom_minimum_size.y=60
	var verbs={"casa":"Minha casa","vila":"Conversar","jardim":"Canteiros","rota":"Explorar","ginasio":"Saguão","safari":"Procurar","mina":"Minerar","lago":"Pescar"}
	var act=game.btn(dock,verbs.get(p.area,"Interagir")+" · E",game.interact,220,"brilho")
	act.custom_minimum_size.y=60
	Design.primary(act)

func minigame(activity:Dictionary):
	var title=game.column(floating(Vector2(448,38),Vector2(550,92)),2)
	game.label(title,"ARCADE DO TREINADOR",12,CYAN)
	var names={"arcade":"Chuva de estrelas","Corrida":"Circuito Aurora","Voo":"Ventos do norte","Natação":"Correnteza azul"}
	game.label(title,names.get(activity.kind,activity.kind),26)
	var result=game.column(floating(Vector2(1012,38),Vector2(460,92)),2)
	game.label(result,"PLACAR",12,GOLD)
	score_label=game.label(result,"",20)
	var footer=game.row(floating(Vector2(448,940),Vector2(1024,86)),14)
	var hint=game.label(footer,"WASD ou setas para mover",17)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	Design.primary(game.btn(footer,"Encerrar · Esc",func():game.send({"type":"arcade_stop"}),0,"fechar"))

func update_values():
	if is_instance_valid(context_label):
		var bite=float(game.data.player.get("fishing",0))
		var now=game.server_time()
		if bite<=0:context_label.text="REGIÃO AURORA"
		elif now<bite:context_label.text="Vara lançada · aguarde a fisgada"
		elif now<=bite+2:context_label.text="Fisgou!   E   Puxar a linha"
		else:context_label.text="E   Recolher a linha"
	if is_instance_valid(score_label):
		var activity=game.data.player.get("arcade")
		if activity!=null:
			var seconds=maxi(0,30-int(game.server_time()-float(activity.start)))
			score_label.text="%d pts    ·    %d vidas    ·    %02d s"%[activity.score,activity.hp,seconds]
	var b=active_battle()
	if b==null:return
	if is_instance_valid(live_label):
		live_label.text="EVOLUINDO" if float(b.get("pause_until",0))>game.server_time() else "TEMPO REAL"
	if is_instance_valid(clock_label):
		var elapsed=maxi(0,int(game.server_time()-float(b.start)))
		clock_label.text="%02d:%02d"%[elapsed/60,elapsed%60]
	for f in b.fighters:
		if not bars.has(f.owner):continue
		var widgets=bars[f.owner]
		widgets.hp.value=100*maxf(0,float(f.hp))/maxf(1,float(f.max_hp));widgets.energy.value=f.energy
		widgets.values.text="PS %d / %d     EN %d     %.1f kg"%[maxi(0,int(f.hp)),int(f.max_hp),int(f.energy),float(f.physique.mass)]
		if f.owner==game.data.player.id:
			var cooldowns={"attack":float(f.get("shot_at",0)),"special":float(f.get("special_at",0)),"dash":float(f.get("dash_at",0))}
			for action in cooldowns:
				if not action_buttons.has(action):continue
				var entry=action_buttons[action];var left=maxf(0,cooldowns[action]-game.server_time())
				entry.button.disabled=left>0 or (action=="special" and float(f.energy)<30) or (action=="dash" and float(f.energy)<20)
				entry.button.text=entry.label+("  %.1fS"%left if left>.05 else "")
