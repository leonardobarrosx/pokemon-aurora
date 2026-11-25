extends Control

var game:Node
var signature=""
var bars:Dictionary={}
var clock_label:Label
var action_buttons:Dictionary={}
const Design=preload("res://aurora_theme.gd")
const CYAN=Design.MINT
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

func floating(pos:Vector2,dimensions:Vector2,color:Color=Color("111b2c"))->PanelContainer:
	var p=game.panel(self,color);p.position=pos;p.size=dimensions
	return p

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
	bars.clear();action_buttons.clear();clock_label=null;score_label=null;context_label=null;live_label=null
	if b!=null:arena(b)
	elif activity!=null:minigame(activity)
	else:exploration(p)
	update_values()

func portrait(parent:Node,m:Dictionary,dimensions:Vector2):
	var im=TextureRect.new();im.texture=game.view.mon_texture(m);im.custom_minimum_size=dimensions
	im.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;im.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	im.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(im)

func meter(parent:Node,color:Color)->ProgressBar:
	var bar=ProgressBar.new();bar.custom_minimum_size=Vector2(280,12);bar.show_percentage=false
	var style=StyleBoxFlat.new();style.bg_color=color;bar.add_theme_stylebox_override("fill",style)
	var background=StyleBoxFlat.new();background.bg_color=Color("08101f");bar.add_theme_stylebox_override("background",background)
	parent.add_child(bar);return bar

func fighter_card(f:Dictionary,right:bool):
	var shell=floating(Vector2(1228 if right else 192,16),Vector2(500,126))
	var r=game.row(shell,12)
	if not right:portrait(r,f.mon,Vector2(72,76))
	var c=game.column(r,3);c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	game.label(c,f.name.to_upper(),11,Color("b4a5db") if right else CYAN)
	var title=game.label(c,game.mon_name(f.mon)+"   Nv. %d"%f.mon.level,20)
	if right:title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var hp=meter(c,Color("#f49570") if right else Design.MINT)
	var energy=meter(c,Color("63bde8"));energy.custom_minimum_size.y=4
	var values=game.label(c,"",11,Color("b0bed1"))
	bars[f.owner]={"hp":hp,"energy":energy,"values":values}
	if right:portrait(r,f.mon,Vector2(72,76))
	var roster=game.row(self,6);roster.position=Vector2(1510 if right else 44,164)
	if f.owner==game.data.player.id:
		for i in 6:
			var slot=game.panel(roster,Color("172237"),false);slot.custom_minimum_size=Vector2(42,36)
			if i<game.data.player.team.size():portrait(slot,game.team_mon(i),Vector2(30,26))
			else:game.label(slot,"·",14,Color("67788d"))
	else:
		game.label(game.panel(roster,Color("172237"),false),game.mon_name(f.mon) if str(f.name)==game.mon_name(f.mon) else str(f.name)+"  ·  "+game.mon_name(f.mon),12,Color("dcc7ee"))

func arena(b:Dictionary):
	fighter_card(b.fighters[0],false);fighter_card(b.fighters[1],true)
	var middle=game.column(floating(Vector2(790,22),Vector2(340,120)),4)
	var kind={"capture":"ENCONTRO SELVAGEM","gym":"DESAFIO DE GINÁSIO","pvp":"DUELO DE TREINADORES","event":"ENCONTRO LENDÁRIO"}.get(b.kind,"ARENA AURORA")
	var caption=game.label(middle,kind,11,GOLD);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	clock_label=game.label(middle,"00:00",32);clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	live_label=game.label(middle,"EM TEMPO REAL",11,CYAN);live_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var mine:Dictionary={}
	for f in b.fighters:
		if f.owner==game.data.player.id:mine=f
	if mine.is_empty():
		var leave=game.btn(self,"ESPECTADOR  /  Sair",func():game.spectate="";refresh(),260);leave.position=Vector2(810,988);return
	var dock=game.row(floating(Vector2(230,968),Vector2(1460,84)),10)
	dock.alignment=BoxContainer.ALIGNMENT_CENTER
	var type=game.data.species[str(int(mine.mon.species))].type
	var special={"Planta":"Raio Solar","Fogo":"Explosão de Fogo","Água":"Hidro Bomba","Elétrico":"Trovão"}.get(type,"Especial")
	if int(mine.mon.species)==131:special="Raio de Gelo"
	for entry in [["attack","CLIQUE  Ataque"],["special","Q  "+special],["dash","ESPAÇO  Esquiva"]]:
		var button=game.btn(dock,entry[1],func():game.view.local_action(entry[0]);game.send({"type":entry[0]}),228)
		if entry[0]=="attack":Design.primary(button)
		action_buttons[entry[0]]={"button":button,"label":entry[1]}
	if b.kind in ["capture","event"]:game.btn(dock,"B  Capturar · %d"%game.data.player.balls,func():game.send({"type":"ball"}),200)
	else:game.btn(dock,"Automático",func():game.send({"type":"auto"}),180)
	game.btn(dock,"V  Evoluir",func():game.send({"type":"evolve","ids":[mine.mon.id]}),160)
	game.btn(dock,"F  Sair",func():game.send({"type":"flee"}),120)
	var hint=game.label(self,"WASD  Mover     /     Mouse  Mirar     /     Desvie das áreas de impacto",12,Color("c5d0df"));hint.position=Vector2(650,917);hint.add_theme_stylebox_override("normal",game.box(Color("111b2c")))

func exploration(p:Dictionary):
	var profile=game.row(floating(Vector2(24,22),Vector2(400,100)),12)
	if not p.team.is_empty():portrait(profile,game.team_mon(0),Vector2(50,52))
	var identity=game.column(profile,2);game.label(identity,p.name,22);game.label(identity,"TREINADOR  /  NÍVEL %d"%(1+int(p.xp)/100),11,CYAN)
	var location=game.column(floating(Vector2(720,22),Vector2(480,94)),3)
	var area=game.label(location,game.AREAS.get(p.area,p.area),22);area.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	context_label=game.label(location,"REGIÃO AURORA",13,GOLD);context_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var wallet=game.column(floating(Vector2(1560,22),Vector2(336,94)),4)
	game.label(wallet,"%d moedas     %d fichas"%[p.coins,p.points],17,GOLD)
	game.label(wallet,"%d treinador(es) online"%(game.data.players.size()+1),11)
	var quest=game.column(floating(Vector2(1560,140),Vector2(336,180)),7)
	game.label(quest,"DIÁRIO DE JORNADA",11,GOLD)
	var task=game.label(quest,game.QUESTS[min(int(p.quest),4)] if int(p.quest)<5 else "Aurora voltou a brilhar!",15)
	task.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;task.custom_minimum_size.x=220
	game.btn(quest,"Resgatar missão",func():game.send({"type":"quest"}))
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
	var dock=game.row(floating(Vector2(316,968),Vector2(1288,84)),10)
	dock.alignment=BoxContainer.ALIGNMENT_CENTER
	for e in [["equipe","Equipe"],["mapa","Mapa"],["loja","Mochila"],["breeding","Linhagens"],["ranking","Liga"],["casa","Casa"]]:
		game.btn(dock,e[1],func():game.open_panel(e[0]),148)
	var verbs={"casa":"Minha casa","vila":"Conversar","jardim":"Canteiros","rota":"Explorar","ginasio":"Saguão","safari":"Procurar","mina":"Minerar","lago":"Pescar"}
	Design.primary(game.btn(dock,"E   "+verbs.get(p.area,"Interagir"),game.interact,172))

func minigame(activity:Dictionary):
	var title=game.column(floating(Vector2(448,38),Vector2(550,92)),2)
	game.label(title,"ARCADE DO TREINADOR",12,CYAN)
	var names={"arcade":"Chuva de estrelas","Corrida":"Circuito Aurora","Voo":"Ventos do norte","Natação":"Correnteza azul"}
	game.label(title,names.get(activity.kind,activity.kind),26)
	var result=game.column(floating(Vector2(1012,38),Vector2(460,92)),2)
	game.label(result,"PLACAR",12,GOLD)
	score_label=game.label(result,"",20)
	var footer=game.row(floating(Vector2(448,950),Vector2(1024,86)),14)
	var hint=game.label(footer,"WASD ou setas para mover",17)
	hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	game.btn(footer,"Encerrar   Esc",func():game.send({"type":"arcade_stop"}))

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
		live_label.text="EVOLUINDO" if float(b.get("pause_until",0))>game.server_time() else "EM TEMPO REAL"
	if is_instance_valid(clock_label):
		var elapsed=maxi(0,int(game.server_time()-float(b.start)))
		clock_label.text="%02d:%02d"%[elapsed/60,elapsed%60]
	for f in b.fighters:
		if not bars.has(f.owner):continue
		var widgets=bars[f.owner]
		widgets.hp.value=100*maxf(0,float(f.hp))/maxf(1,float(f.max_hp));widgets.energy.value=f.energy
		widgets.values.text="HP %d / %d     EN %d     %.1f kg"%[maxi(0,int(f.hp)),int(f.max_hp),int(f.energy),float(f.physique.mass)]
		if f.owner==game.data.player.id:
			var cooldowns={"attack":float(f.get("shot_at",0)),"special":float(f.get("special_at",0)),"dash":float(f.get("dash_at",0))}
			for action in cooldowns:
				if not action_buttons.has(action):continue
				var entry=action_buttons[action];var left=maxf(0,cooldowns[action]-game.server_time())
				entry.button.disabled=left>0 or (action=="special" and float(f.energy)<30) or (action=="dash" and float(f.energy)<20)
				entry.button.text=entry.label+("  %.1fs"%left if left>.05 else "")
