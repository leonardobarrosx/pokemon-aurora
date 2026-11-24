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
	game.send({"type":"attack"})
	if not await wait_for(func():return game.data.battle!=null and game.data.battle.projectiles.size()>0):return
	await create_timer(.2).timeout
	game.send({"type":"flee"})
	if not await wait_for(func():return game.data.player.battle==""):return
	await create_timer(.2).timeout
	game.send({"type":"travel","area":"casa"})
	if not await wait_for(func():return game.data.player.area=="casa"):return
	for menu in ["equipe","breeding","mercado","loja","mapa","treino","profissao","ranking","jardim","pc"]:
		game.open_panel(menu)
		await process_frame
		game.close_panel()
	var config=ConfigFile.new()
	if config.load("user://%s.cfg"%game.profile)!=OK or config.get_value("session","token","")=="":push_error("chave de sessão não foi salva");quit(1);return
	DirAccess.remove_absolute("user://%s.cfg"%game.profile)
	print("PASS: cliente Godot real, cadastro, criador, história, rota, combate manual, retorno e menus.")
	quit(0)
