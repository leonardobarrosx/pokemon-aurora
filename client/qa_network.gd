extends SceneTree

var game:Node

func _initialize():call_deferred("run")

func wait_for(predicate:Callable)->bool:
	for i in 160:
		if predicate.call():return true
		await create_timer(.05).timeout
	push_error("Timeout no fluxo desktop real")
	quit(1)
	return false

func find_button(node:Node,text:String)->Button:
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found:return found
	return null

func run():
	var args=OS.get_cmdline_user_args()
	if args.is_empty():quit(2);return
	game=load("res://main.tscn").instantiate()
	game.profile="qa-native-"+str(Time.get_ticks_usec())
	game.endpoint=args[0]
	root.add_child(game)
	game.name_input.text="Teste Desktop"
	game.server_input.text=args[0]
	find_button(game,"Começar minha jornada").pressed.emit()
	if not await wait_for(func():return not game.data.is_empty()):return
	game.wardrobe_menu()
	find_button(game,"Salvar aparência").pressed.emit()
	await create_timer(.2).timeout
	game.send({"type":"travel","area":"vila"})
	if not await wait_for(func():return game.data.player.area=="vila"):return
	game.send({"type":"talk","value":"Íris"})
	if not await wait_for(func():return game.data.player.flags.get("talk",0)==1):return
	await create_timer(.1).timeout
	game.send({"type":"quest"})
	if not await wait_for(func():return int(game.data.player.quest)==1):return
	await create_timer(.1).timeout
	game.send({"type":"travel","area":"rota"})
	if not await wait_for(func():return game.data.player.area=="rota"):return
	await create_timer(.1).timeout
	game.send({"type":"encounter"})
	if not await wait_for(func():return game.data.get("battle")!=null):return
	await create_timer(.2).timeout
	game.send({"type":"input","move":{"x":0,"y":0},"aim":{"x":410,"y":200}})
	game.send({"type":"special"})
	if not await wait_for(func():
		if game.data.battle==null:return false
		for fighter in game.data.battle.fighters:
			if fighter.owner==game.data.player.id:return float(fighter.special_at)>game.server_time()
		return false):return
	if not game.hud.action_buttons.has("special"):push_error("HUD não expôs ação especial");quit(1);return
	game.hud.update_values()
	if not game.hud.action_buttons.special.button.disabled:push_error("HUD não mostrou a recarga");quit(1);return
	var feedback=game.data.duplicate(true)
	feedback.battle.fighters[1].hp=float(feedback.battle.fighters[1].hp)-1
	game.view.observe_snapshot(feedback)
	if game.view.shake_until<=Time.get_ticks_msec():push_error("feedback de dano não foi ativado");quit(1);return
	game.send({"type":"flee"})
	if not await wait_for(func():return game.data.player.battle==""):return
	await create_timer(.2).timeout
	game.send({"type":"travel","area":"casa"})
	if not await wait_for(func():return game.data.player.area=="casa"):return
	for menu in ["equipe","breeding","mercado","loja","mapa","treino","profissao","ranking","jardim","pc"]:
		game.open_panel(menu)
		await process_frame
		game.close_panel()
	game.open_panel("mercado")
	var price=game.overlay_body.find_children("*","SpinBox",true,false)[0]
	price.value=720
	game.toggle_partner(game.data.player.mons[0].id)
	if not is_instance_valid(price) or price.value!=720 or game.selected.size()!=1:
		push_error("Selecionar um exemplar descartou o preço do anúncio");quit(1);return
	game.open_panel("equipe")
	if game.selected!=game.data.player.team:
		push_error("A seleção inicial precisa respeitar a ordem do time salvo");quit(1);return
	game.open_panel("ranking")
	var chat_input=game.message_input
	chat_input.text="Rascunho local"
	game.data.chat.append({"name":"QA","text":"Nova mensagem"})
	game.update_lobby()
	if chat_input!=game.message_input or chat_input.text!="Rascunho local":
		push_error("Atualizar o saguão descartou o rascunho");quit(1);return
	game.close_panel()
	var config=ConfigFile.new()
	if config.load("user://%s.cfg"%game.profile)!=OK or config.get_value("session","token","")=="":push_error("chave de sessão não foi salva");quit(1);return
	DirAccess.remove_absolute("user://%s.cfg"%game.profile)
	print("PASS: cliente Godot real, cadastro, criador, história, rota, combate manual, retorno e menus.")
	quit(0)
