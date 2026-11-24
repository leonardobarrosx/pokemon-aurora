extends Control

var game:Node
var signature=""
var bars:Dictionary={}
var clock_label:Label
var action_buttons:Dictionary={}
const CYAN=Color("64d9e5")
const GOLD=Color("eac57d")

func _ready():
	size=Vector2(1280,832);mouse_filter=Control.MOUSE_FILTER_IGNORE

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
	var key=JSON.stringify([p.area,p.team,p.mons,p.quest,p.coins,p.points,p.xp,p.balls,game.spectate,combat_key])
	if key==signature:return
	signature=key
	for child in get_children():child.queue_free()
	bars.clear();action_buttons.clear();clock_label=null
	if b!=null:arena(b)
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
	var shell=floating(Vector2(804 if right else 24,22),Vector2(452,112))
	var r=game.row(shell,12)
	if not right:portrait(r,f.mon,Vector2(72,76))
	var c=game.column(r,3);c.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	game.label(c,f.name.to_upper(),11,Color("b4a5db") if right else CYAN)
	var title=game.label(c,game.mon_name(f.mon)+"   Nv. %d"%f.mon.level,20)
	if right:title.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var hp=meter(c,Color("d89ce3") if right else Color("71dca2"))
	var energy=meter(c,Color("63bde8"));energy.custom_minimum_size.y=4
	var values=game.label(c,"",11,Color("b0bed1"))
	bars[f.owner]={"hp":hp,"energy":energy,"values":values}
	if right:portrait(r,f.mon,Vector2(72,76))
	var roster=game.row(self,6);roster.position=Vector2(876 if right else 32,142)
	if f.owner==game.data.player.id:
		for i in 6:
			var slot=game.panel(roster);slot.custom_minimum_size=Vector2(42,36)
			if i<game.data.player.team.size():portrait(slot,game.team_mon(i),Vector2(30,26))
			else:game.label(slot,"·",14,Color("67788d"))
	else:
		game.label(game.panel(roster),"ADVERSÁRIO  /  "+game.mon_name(f.mon),12,Color("dcc7ee"))

func arena(b:Dictionary):
	fighter_card(b.fighters[0],false);fighter_card(b.fighters[1],true)
	var middle=game.column(floating(Vector2(500,22),Vector2(280,100)),4)
	var kind={"capture":"ENCONTRO SELVAGEM","gym":"DESAFIO DE GINÁSIO","pvp":"DUELO DE TREINADORES","event":"ENCONTRO LENDÁRIO"}.get(b.kind,"ARENA AURORA")
	var caption=game.label(middle,kind,11,GOLD);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	clock_label=game.label(middle,"00:00",32);clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var live=game.label(middle,"EM TEMPO REAL",10,CYAN);live.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var mine:Dictionary={}
	for f in b.fighters:
		if f.owner==game.data.player.id:mine=f
	if mine.is_empty():
		var leave=game.btn(self,"ESPECTADOR  /  Sair",func():game.spectate="";refresh(),260);leave.position=Vector2(510,762);return
	var dock=game.row(floating(Vector2(138,752),Vector2(1004,64)),8)
	var type=game.data.species[str(int(mine.mon.species))].type
	var special={"Planta":"Raio Solar","Fogo":"Explosão de Fogo","Água":"Hidro Bomba","Elétrico":"Trovão"}.get(type,"Especial")
	if int(mine.mon.species)==131:special="Raio de Gelo"
	for entry in [["attack","CLIQUE  Ataque"],["special","Q  "+special],["dash","ESPAÇO  Esquiva"]]:
		action_buttons[entry[0]]=game.btn(dock,entry[1],func():game.send({"type":entry[0]}),172)
	if b.kind in ["capture","event"]:game.btn(dock,"B  Capturar · %d"%game.data.player.balls,func():game.send({"type":"ball"}),150)
	else:game.btn(dock,"Automático",func():game.send({"type":"auto"}),130)
	game.btn(dock,"V  Evoluir",func():game.send({"type":"evolve","ids":[mine.mon.id]}),110)
	game.btn(dock,"F  Sair",func():game.send({"type":"flee"}),80)
	var hint=game.label(self,"WASD  Mover     /     Mouse  Mirar     /     Desvie das áreas de impacto",12,Color("c5d0df"));hint.position=Vector2(366,710);hint.add_theme_stylebox_override("normal",game.box(Color("111b2c")))

func exploration(p:Dictionary):
	var profile=game.row(floating(Vector2(24,22),Vector2(330,86)),12)
	if not p.team.is_empty():portrait(profile,game.team_mon(0),Vector2(50,52))
	var identity=game.column(profile,2);game.label(identity,p.name,22);game.label(identity,"TREINADOR  /  NÍVEL %d"%(1+int(p.xp)/100),11,CYAN)
	var location=game.column(floating(Vector2(456,22),Vector2(368,72)),3)
	var area=game.label(location,game.AREAS.get(p.area,p.area),22);area.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var region=game.label(location,"REGIÃO AURORA",10,GOLD);region.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var wallet=game.column(floating(Vector2(986,22),Vector2(270,72)),4)
	game.label(wallet,"%d moedas     %d fichas"%[p.coins,p.points],17,GOLD)
	game.label(wallet,"%d treinador(es) online"%(game.data.players.size()+1),11)
	var quest=game.column(floating(Vector2(986,124),Vector2(270,140)),7)
	game.label(quest,"DIÁRIO DE JORNADA",11,GOLD)
	var task=game.label(quest,game.QUESTS[min(int(p.quest),4)] if int(p.quest)<5 else "Aurora voltou a brilhar!",15)
	task.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;task.custom_minimum_size.x=220
	game.btn(quest,"Resgatar missão",func():game.send({"type":"quest"}))
	var team=game.column(floating(Vector2(24,132),Vector2(88,360)),5)
	for i in mini(6,p.team.size()):
		var button=game.btn(team,"",func():game.open_panel("equipe"),58)
		button.icon=game.view.mon_texture(game.team_mon(i));button.expand_icon=true;button.custom_minimum_size.y=48
		button.tooltip_text=game.mon_name(game.team_mon(i))
	var dock=game.row(floating(Vector2(162,752),Vector2(956,64)),8)
	for e in [["equipe","Equipe"],["mapa","Mapa"],["loja","Mochila"],["breeding","Linhagens"],["ranking","Liga"],["casa","Casa"]]:
		game.btn(dock,e[1],func():game.open_panel(e[0]),112)
	game.btn(dock,"E  Interagir",game.interact,160)

func update_values():
	var b=active_battle()
	if b==null:return
	if is_instance_valid(clock_label):
		var elapsed=maxi(0,int(game.server_time()-float(b.start)))
		clock_label.text="%02d:%02d"%[elapsed/60,elapsed%60]
	for f in b.fighters:
		if not bars.has(f.owner):continue
		var widgets=bars[f.owner]
		widgets.hp.value=100*maxf(0,float(f.hp))/maxf(1,float(f.max_hp));widgets.energy.value=f.energy
		widgets.values.text="HP %d / %d     EN %d     %.1f kg"%[maxi(0,int(f.hp)),int(f.max_hp),int(f.energy),float(f.physique.mass)]
