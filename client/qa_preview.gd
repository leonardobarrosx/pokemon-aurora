extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var args=OS.get_cmdline_user_args()
	if args.size()<2:
		push_error("Uso: --script qa_preview.gd -- fixture.json saida.png [tela]");quit(2);return
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not fixture is Dictionary:quit(2);return
	var scene=load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false);scene.commands.clear();scene.data=fixture;scene.clock_offset=float(fixture.now)-Time.get_unix_time_from_system();scene.close_panel();scene.refresh_sidebar()
	if args.size()>2 and args[2]=="wardrobe":scene.wardrobe_menu()
	elif args.size()>2 and args[2]!="casa":scene.open_panel(args[2])
	scene.view.queue_redraw()
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	var err=root.get_texture().get_image().save_png(args[1])
	if err!=OK:push_error("Falha ao salvar prévia: "+str(err))
	quit(0 if err==OK else 1)
