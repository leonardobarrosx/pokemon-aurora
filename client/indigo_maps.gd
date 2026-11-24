extends RefCounted

var v:Node2D

func region(name:String,src:Rect2,pos:Vector2):
	# RPG Maker atlas bands keep every original pixel and fit portable GPU limits.
	var band=int(src.position.y)/4096
	var local=src;local.position.y=fmod(src.position.y,4096)
	var tex=v.texture("res://assets/indigo/tilesets/%s-%d.png"%[name,band])
	if tex:v.draw_texture_rect_region(tex,Rect2(pos,src.size),local)

func tile(name:String,source:Vector2,area:Rect2):
	for y in range(int(area.position.y),int(area.end.y),32):
		for x in range(int(area.position.x),int(area.end.x),32):region(name,Rect2(source,Vector2(32,32)),Vector2(x,y))

func plant(pos:Vector2):region("Interior1",Rect2(224,0,32,64),pos-Vector2(0,32))
func tree(pos:Vector2):region("Exterior1",Rect2(128,1312,64,96),pos-Vector2(0,32))
func house(pos:Vector2):region("Exterior1",Rect2(0,3360,192,224),pos)

func room(p:Dictionary):
	v.draw_rect(Rect2(0,0,512,384),Color("152a30"))
	tile("Interior1",Vector2(64,128),Rect2(32,128,448,224))
	for x in range(32,480,32):region("Interior1",Rect2(160,0,32,96),Vector2(x,32))
	region("Interior1",Rect2(64,64,64,64),Vector2(224,48))
	region("Interior1",Rect2(128,96,96,128),Vector2(208,192))
	region("Interior1",Rect2(128,608,128,96),Vector2(48,160))
	region("Interior1",Rect2(0,512,64,64),Vector2(384,96))
	region("Interior1",Rect2(0,736,96,96),Vector2(352,192))
	region("Interior1",Rect2(0,384,96,64),Vector2(208,204))
	region("Interior1",Rect2(0,512,64,64),Vector2(56,80))
	region("Interior1",Rect2(0,192,64,32),Vector2(224,320))
	plant(Vector2(160,104));plant(Vector2(448,288))
	for d in p.get("decor",[]):
		var pos=Vector2(d.pos.x,d.pos.y)
		match d.kind:
			"planta":plant(pos)
			"estante":region("Interior1",Rect2(0,512,64,64),pos-Vector2(0,32))
			"aquario":region("Interior1",Rect2(352-256,1408,64,64),pos-Vector2(0,32))
			"pelucia":v.mon({"species":25},pos+Vector2(16,8),64)

func outdoors(p:Dictionary):
	var area=p.get("area","vila")
	tile("Exterior1",Vector2(0,0),Rect2(0,0,512,384))
	tile("Exterior1",Vector2(32,160),Rect2(224,0,64,384));tile("Exterior1",Vector2(32,160),Rect2(0,256,512,64))
	for x in range(-16,512,64):tree(Vector2(x,0));tree(Vector2(x,336))
	match area:
		"vila":
			house(Vector2(16,48));house(Vector2(304,48))
			v.trainer(Vector2(192,290),"green","professor");v.trainer(Vector2(330,290),"green","gardener");v.trainer(Vector2(396,310),"green","engineer")
			v.txt(Vector2(178,244),"Íris");v.txt(Vector2(316,244),"Lia");v.txt(Vector2(382,270),"Theo")
			region("Exterior1",Rect2(0,704,128,64),Vector2(32,296))
		"jardim":
			for i in 6:
				var pos=Vector2(160+(i%3)*96,128+(i/3)*96)
				for y in 2:
					for x in 2:region("Exterior1",Rect2(128,416,32,32),pos+Vector2(x*32,y*32))
				var plot=p.plots[i]
				if float(plot.at)>0:
					region("Exterior1",Rect2(160,160,32,64),pos+Vector2(16,-16))
					if plot.water and v.game.server_time()-float(plot.at)>=90:region("Exterior1",Rect2(128,64,32,32),pos+Vector2(16,0))
				v.txt(pos+Vector2(28,80),str(i+1))
			region("Exterior1",Rect2(224,320,32,32),Vector2(80,190))
		"mina":
			tile("Cueva1",Vector2(0,0),Rect2(0,0,512,384))
			for pos in [Vector2(64,128),Vector2(352,112),Vector2(320,272)]:region("Exterior1",Rect2(192,1440,64,96),pos)
			for pos in [Vector2(128,180),Vector2(388,174)]:region("Interior1",Rect2(0,1280,64,96),pos)
		"ginasio":
			tile("Interior1",Vector2(64,1440),Rect2(32,96,448,256))
			for x in range(32,480,32):region("Interior1",Rect2(160,0,32,96),Vector2(x,0))
			region("Interior1",Rect2(0,2048,128,128),Vector2(192,136))
			for x in [48,432]:plant(Vector2(x,128));plant(Vector2(x,304))
			v.trainer(Vector2(256,146),"green","gardener")
		"lago":
			for y in range(112,272,32):
				for x in range(48,416,32):region("Exterior1",Rect2(32,608,32,32),Vector2(x,y))
			for y in range(240,336,32):region("Exterior1",Rect2(0,320,64,32),Vector2(224,y))
		_:
			for pos in [Vector2(32,128),Vector2(368,144),Vector2(320,272)]:tree(pos)
			for pos in [Vector2(128,192),Vector2(320,256),Vector2(96,272)]:region("Exterior1",Rect2(128,32,32,32),pos)
			if area=="safari" and p.get("safari")!=null:
				var s=p.safari;var pos=Vector2(s.pos.x,s.pos.y);v.mon({"species":s.species},pos)
				v.draw_arc(pos,18+sin(Time.get_ticks_msec()/220.0)*5,0,TAU,32,Color("f1df93"),2)
			elif area=="rota":v.follower({"species":16},Vector2(150,206));v.follower({"species":19},Vector2(350,296))

func arena():
	tile("Exterior1",Vector2(0,0),Rect2(0,0,512,384))
	tile("Interior1",Vector2(64,1440),Rect2(32,96,448,256))
	for x in range(-16,512,64):tree(Vector2(x,-16))
