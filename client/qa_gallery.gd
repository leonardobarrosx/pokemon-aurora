extends SceneTree

# Offline catalogue of the actual client views. Every capture uses QA data.
var game
var output:String
var home:Dictionary
var combat:Dictionary
var failed=false

func _initialize():
	call_deferred("run")

func shot(group:String, name:String):
	game.view.queue_redraw()
	await create_timer(.28).timeout
	if not game.data.is_empty():game.hud.update_values()
	await RenderingServer.frame_post_draw
	var folder=output.path_join(group)
	DirAccess.make_dir_recursive_absolute(folder)
	var err=root.get_texture().get_image().save_png(folder.path_join(name+".png"))
	if err!=OK:
		push_error("Falha ao salvar "+name)
		failed=true

func load_state(fixture:Dictionary):
	game.spectate=""
	game.data=fixture.duplicate(true)
	game.hud.signature=""
	game.clock_offset=float(game.data.now)-Time.get_unix_time_from_system()
	game.close_panel()

func run():
	var args=OS.get_cmdline_user_args()
	if args.size()<2:
		quit(2)
		return
	output=args[1]
	home=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("casa.json")))
	combat=JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("battle.json")))
	if home.is_empty() or combat.is_empty():
		push_error("Fixtures de QA ausentes ou vazias")
		quit(2)
		return
	game=load("res://main.tscn").instantiate()
	game.profile="galeria-offline"
	root.add_child(game)
	game.set_process(false)
	game.commands.clear()
	if args.size()>2 and args[2] in ["cutins","jornada"]:
		if args[2]=="jornada":
			game.login();load_state(home)
			for r in game.data.regions:
				for g in r.get("badges",[]):g.done=str(g.id) in ["aurora_1","kanto_1","kanto_2","kanto_3"]
				if r.id=="kanto":r.visited=41
			game.open_panel("jornada")
			await shot("menus","jornada")
			var scroll=game.overlay_body.get_parent() as ScrollContainer
			if scroll:scroll.scroll_vertical=99999
			await shot("menus","jornada-rodape")
			game.close_panel();game.data.player.area="kt_pewter_city_gym";game.refresh_sidebar()
			await shot("menus","hud-jornada")
			quit(1 if failed else 0)
			return
	if args.size()>2 and args[2]=="estadio":
		game.login()
		var fields=JSON.parse_string(FileAccess.get_file_as_string(args[0]+"/fields.json"))
		var spots={"kanto_2":[{"x":200,"y":285},{"x":410,"y":200},4],"kanto_1":[{"x":140,"y":250},{"x":380,"y":170},74],"kanto_7":[{"x":120,"y":250},{"x":400,"y":200},4],"kanto_4":[{"x":150,"y":240},{"x":380,"y":180},1]}
		for gid in ["kanto_2","kanto_1","kanto_7","kanto_4","hoenn_4","johto_4","johto_7","sinnoh_2"]:
			var fight=combat.duplicate(true)
			if not fight.has("regions"):fight.regions=home.regions
			var b=fight.battle;b.kind="gym";b.gym=gid
			var info={}
			for r in fight.regions:
				for g in r.badges:
					if g.id==gid:info=g
			b.fighters[1].name=info.get("leader","Líder");b.fighters[1].owner="npc";b.fighters[1].art=info.get("art","")
			b.fighters[1].hp=b.fighters[1].max_hp*.7
			b.cutins=[]
			b.field=fields.get(gid,{})
			if spots.has(gid):
				b.fighters[0].pos=spots[gid][0];b.fighters[1].pos=spots[gid][1];b.fighters[0].mon.species=spots[gid][2]
			for f in b.fighters:
				var fd=b.field;var col=int((float(f.pos.x)-16)/32);var row=int((float(f.pos.y)-96)/32)
				f.terrain=str(fd.cells)[row*15+col] if row>=0 and row<8 and col>=0 and col<15 else "."
			b.fighters[1].mon.species=info.get("species",b.fighters[1].mon.species)
			load_state(fight)
			await shot("arena","estadio-"+gid)
		quit(1 if failed else 0)
		return
	if args.size()>2 and args[2]=="mato":
		game.login()
		var source=home.duplicate(true);source.player.area="kt_route1"
		var m0=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kt_route1.json"))
		var c=Vector2(m0.default[0],m0.default[1])
		source.player.pos={"x":c.x,"y":c.y}
		source.wild=[{"id":"w1","species":16,"level":4,"pos":{"x":c.x+90,"y":c.y-60},"facing":1,"water":false},{"id":"w2","species":19,"level":3,"pos":{"x":c.x-120,"y":c.y+40},"facing":2,"water":false},{"id":"w3","species":25,"level":5,"pos":{"x":c.x+40,"y":c.y+110},"facing":3,"water":false}]
		load_state(source);game.refresh_sidebar()
		await shot("mundo","mato-selvagens")
		var fight=combat.duplicate(true)
		fight.player.area="kt_route1";fight.player.pos={"x":c.x,"y":c.y}
		var b=fight.battle;b.area="kt_route1";b.origin={"x":c.x-256,"y":c.y-222};b.trainer={"x":200,"y":250}
		b.fighters[0].pos={"x":210,"y":230};b.fighters[1].pos={"x":330,"y":190};b.fighters[1].hp=b.fighters[1].max_hp*.6
		load_state(fight)
		await shot("arena","mato-batalha")
		quit(1 if failed else 0)
		return
	if args.size()>2 and args[2]=="montaria":
		game.login()
		for setup in [["surf","hn_route126",131,"~"],["dive","hn_underwater_route126",131,"."],["mount","kt_route1",95,"."],["mount","hn_route101",19,"."]]:
			var source=home.duplicate(true)
			var mon=source.player.mons[0].duplicate(true);mon.id="montaria";mon.species=setup[2]
			source.player.mons.append(mon)
			source.player.transport=setup[0];source.player.mount="montaria";source.player.area=setup[1]
			load_state(source)
			var m=game.view.map_for(setup[1]);var pos=Vector2(m.default[0],m.default[1])
			var cells=FileAccess.get_file_as_string("res://../server/maps/%s.json"%setup[1])
			if setup[3]=="~" and cells!="":
				var sm=JSON.parse_string(cells);var i=str(sm.cells).find("~",int(sm.w)*12)
				if i>=0:pos=Vector2((i%int(sm.w)+.5)*32,(i/int(sm.w)+.5)*32)
			game.data.player.pos={"x":pos.x,"y":pos.y};game.data.player.facing=[0,2,1,3][randi()%4] if setup[0]!="surf" else 2
			game.refresh_sidebar()
			await shot("mundo","montaria-%s-%s"%[setup[0],setup[1]])
		quit(1 if failed else 0)
		return
	if args.size()>2 and args[2]=="cutins":
		await cutin_states()
		quit(1 if failed else 0)
		return
	if args.size()>2 and args[2]=="estados":
		await extra_states()
		quit(1 if failed else 0)
		return
	game.login()
	await shot("menus","entrada")
	for page in ["equipe","jornada","mapa","loja","breeding","treino","mercado","casa","profissao","ranking","vila","jardim","pc","guarda-roupa","genes","iguaria","lago"]:
		load_state(home)
		match page:
			"guarda-roupa":game.wardrobe_menu()
			"genes":game.genome_panel(game.team_mon(0))
			"jornada":
				# Jornada no meio de Kanto: três insígnias e Hoenn ainda fechada.
				for r in game.data.regions:
					for g in r.get("badges",[]):g.done=str(g.id) in ["aurora_1","kanto_1","kanto_2","kanto_3"]
					if r.id=="kanto":r.visited=41
					if r.id=="aurora":r.visited=6
				game.open_panel(page)
			"iguaria":game.confirm_delicacy()
			"lago":
				game.data.player.area="lago"
				game.interact()
			_:game.open_panel(page)
		await shot("menus",page)
		var scroll=game.overlay_body.get_parent() as ScrollContainer
		if scroll and scroll.get_v_scroll_bar().max_value>scroll.size.y+4:
			scroll.scroll_vertical=roundi(scroll.get_v_scroll_bar().max_value)
			await shot("menus",page+"-rodape")
	for area in game.AREAS.keys()+["kt_pallet_town","kt_route1","kt_viridian_city","kt_pallet_town_players_house_1f","kt_mt_moon_1f","kt_cerulean_city","hn_littleroot_town","hn_route101","hn_petalburg_city","hn_rustboro_city","jt_johto","jt_new_bark_player_house_1f","jt_violet_pokecenter_1f","jt_goldenrod_pokecenter_1f","sn_sinnoh","sn_jubilife_city_pokecenter_1f","sn_eterna_city_gym"]:
		load_state(home)
		game.data.player.area=area
		var area_map=game.view.map_for(area)
		if area_map.has("default"):game.data.player.pos={"x":area_map.default[0],"y":area_map.default[1]-64}
		if area=="safari":game.data.player.safari={"species":25,"pos":{"x":float(game.data.player.pos.x)+150,"y":float(game.data.player.pos.y)-40}}
		game.refresh_sidebar()
		await shot("mundo",area)
	for state in ["aguardando","fisgada"]:
		game.data.player.area="lago"
		var lake=game.view.map_for("lago")
		if lake.has("points"):game.data.player.pos={"x":lake.points.pesca[0],"y":lake.points.pesca[1]}
		game.data.player.fishing=game.server_time()+(6 if state=="aguardando" else -.15)
		game.refresh_sidebar()
		await shot("mundo","pesca-"+state)
	for mode in ["capture","gym","pvp","event","espectador","evolucao"]:
		var source=combat.duplicate(true)
		var b=source.battle
		b.kind={"espectador":"gym","evolucao":"capture"}.get(mode,mode)
		b.fighters[1].hp=b.fighters[1].max_hp*.60
		if b.kind=="gym":b.fighters[1].name="Flora"
		if b.kind=="pvp":b.fighters[1].name="Iara"
		if mode=="evolucao":b.pause_until=source.now+2
		if mode=="espectador":
			b.fighters[0].owner="treinador-QA"
			source.battles=[b]
			source.battle=null
			source.player.battle=""
		load_state(source)
		if mode=="espectador":game.spectate=b.id;game.refresh_sidebar()
		await shot("arena",mode)
	await cutin_states()
	for kind in ["arcade","Corrida","Voo","Natação"]:
		var source=home.duplicate(true)
		source.player.arcade={"kind":kind,"start":source.now-4,"score":40,"hp":3,"seed":2,"pos":{"x":240,"y":238}}
		load_state(source)
		await shot("arena",kind.to_lower().replace("ç","c").replace("ã","a"))
	await extra_states()
	quit(1 if failed else 0)

# Arte do treinador entrando na tela: pokébola, troca e ataque especial.
func cutin_states():
	for mode in [["ball","capture",0,"Pokébola, vai!",""],["switch","gym",1,"Vai, Tangela!","in_erika"],["special","pvp",0,"Hiper Raio!",""],["special","gym",1,"Raio Solar!","pt_leader_gardenia"]]:
		var source=combat.duplicate(true)
		var b=source.battle
		b.kind=mode[1]
		if b.kind=="gym":b.fighters[1].name="Flora";b.fighters[1].owner="npc";b.fighters[1].art=mode[4]
		if b.kind=="pvp":b.fighters[1].name="Iara"
		b.cutins=[{"side":mode[2],"kind":mode[0],"text":mode[3],"at":float(source.now)-.35}]
		load_state(source)
		for c in game.data.battle.cutins:c.at=game.server_time()+.28-.35
		await shot("arena","cutin-%s-%s-%d"%[mode[0],mode[1],mode[2]])

func extra_states():
	root.gui_embed_subwindows=true
	load_state(home)
	game.wardrobe_menu()
	await process_frame
	var options=game.overlay_body.find_children("*","OptionButton",true,false)
	options[1].show_popup()
	await shot("estados","roupas")
	options[1].get_popup().hide()
	var picker=game.overlay_body.find_children("*","ColorPickerButton",true,false)[0]
	picker.pressed.emit()
	if not picker.get_popup().visible:
		picker.get_popup().popup_centered()
	await shot("estados","cores")
	picker.get_popup().hide()
	load_state(home)
	game.data.market=[{"id":"oferta-qa","seller":"vendedor-qa","name":"Iara","mon":game.data.player.mons[1],"price":450}]
	game.open_panel("mercado")
	await shot("estados","anuncio")
	load_state(home)
	game.data.player.area="ginasio"
	game.data.battles=[combat.battle.duplicate(true)]
	game.data.chat=[{"name":"Iara","text":"A Flora está na arena. Vem assistir!"}]
	game.open_panel("ranking")
	await shot("estados","saguao-ao-vivo")
	load_state(home)
	game.data.player.egg={"mon":game.team_mon(0),"at":home.now-120}
	game.open_panel("breeding")
	await shot("estados","incubadora")
	load_state(home)
	game.data.player.training={"ids":[game.team_mon(0).id],"route":"rota","at":home.now-60}
	game.open_panel("treino")
	await shot("estados","treino-ativo")
	load_state(home)
	game.data.player.area="jardim"
	for i in 3:
		game.data.player.plots[i]={"at":home.now-(100 if i==2 else 30),"water":i!=0}
	game.open_panel("jardim")
	await shot("estados","canteiros-plantados")
