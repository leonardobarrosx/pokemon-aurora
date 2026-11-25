extends SceneTree

const Regions=preload("res://pokemon_regions.gd")
var failures=0

func _initialize():call_deferred("run")

func check(ok:bool,message:String):
	if not ok:failures+=1;push_error(message)

func caption(parent:Node,text:String,pos:Vector2,size:int=18):
	var label=Label.new();label.text=text;label.position=pos;label.add_theme_font_size_override("font_size",size);parent.add_child(label)

func picture(parent:Node,image:Image,pos:Vector2,dimensions:Vector2):
	var sprite=TextureRect.new();sprite.texture=ImageTexture.create_from_image(image);sprite.position=pos;sprite.size=dimensions
	sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;parent.add_child(sprite)

func run():
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/indigo/manifest.json"))
	var canvas=Control.new();root.add_child(canvas)
	caption(canvas,"AURORA  /  REGIÕES DE APARÊNCIA",Vector2(36,24),30)
	caption(canvas,"Original → variação de teste. Sprites Indigo preservados; quatro direções abaixo.",Vector2(36,76))
	var ids=["1","4","7","25","133","94","197"]
	for i in ids.size():
		var sid=ids[i];var entry=manifest.pokemon[sid];var x=36+i*268
		caption(canvas,entry.name,Vector2(x,126),22)
		var look={"regions":{"skin":"#79b9d4","fur":"#b7a0da","flame":"#75dfb3","accessory":"#d3a5d5","effects":"#8aa9ed","eye":"#eec954","mouth":"#e19ea1","markings":"#d699cf","nose":"#766e91"},"pattern":"Pintas","detail":"#cabbdc","mark":"Sinal","mark_color":"#cfd9ec","mark_place":1,"seed":723}
		for mode in ["front","follower","back"]:
			var spec=entry[mode];var source=(load("res://assets/indigo/"+spec.file) as Texture2D).get_image();source.convert(Image.FORMAT_RGBA8)
			var clean=Regions.apply(source.duplicate(),sid,mode,int(spec.frame),{})
			check(clean.get_data()==source.get_data(),sid+mode+": original altered")
			var variant=Regions.apply(source.duplicate(),sid,mode,int(spec.frame),look)
			check(variant.get_data()==Regions.apply(source.duplicate(),sid,mode,int(spec.frame),look).get_data(),sid+mode+": unstable pattern")
			var marked=Regions.apply(source.duplicate(),sid,mode,int(spec.frame),{"mark":"Sinal","mark_color":"#ff00ff","mark_place":1})
			var n=int(spec.frame)
			for fy in range(0,source.get_height(),n):
				for fx in range(0,source.get_width(),n):
					var count=0
					for y in range(n):
						for xx in range(n):
							var a=source.get_pixel(fx+xx,fy+y);var b=marked.get_pixel(fx+xx,fy+y)
							check(a.a==b.a,sid+": alpha changed")
							if a!=b:count+=1
					check(count<=4,sid+mode+": birthmark too large")
			if mode=="front":
				picture(canvas,source.get_region(Rect2i(0,0,n,n)),Vector2(x,180),Vector2(236,200))
				picture(canvas,variant.get_region(Rect2i(0,0,n,n)),Vector2(x,420),Vector2(236,200))
			if mode=="follower":
				for direction in 4:picture(canvas,variant.get_region(Rect2i(0,direction*n,n,n)),Vector2(x+direction*60,694),Vector2(58,76))
		caption(canvas,"Original",Vector2(x,158),15)
		caption(canvas,"Regiões independentes",Vector2(x,396),15)
		caption(canvas,"Sinal: até 4 pixels / quadro",Vector2(x,804),15)
	caption(canvas,"Cores ilustrativas de QA. Regiões sem máscara segura mantêm o desenho original.",Vector2(36,946),20)
	for i in 8:await process_frame
	if not DisplayServer.get_name()=="headless":
		await RenderingServer.frame_post_draw
		var args=OS.get_cmdline_user_args()
		if not args.is_empty():root.get_texture().get_image().save_png(args[0])
	print("PASS: original, determinismo, transparência e limite de sinais nas três poses de sete espécies" if failures==0 else "FAIL: regiões")
	quit(0 if failures==0 else 1)
