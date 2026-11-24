extends Node2D

var game: Node
var textures: Dictionary = {}
var looks: Dictionary = {}
var font = ThemeDB.fallback_font
var indigo=preload("res://indigo_character.gd").new()
var maps=preload("res://indigo_maps.gd").new()
var source_manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/indigo/manifest.json"))
var atlases:Dictionary={}
const INK = Color("273e42")

func rect(x: float,y: float,w: float,h: float,c: String):
	draw_rect(Rect2(round(x/2)*2,round(y/2)*2,round(w/2)*2,round(h/2)*2),Color(c))

func txt(at: Vector2, text: String, size: int=12, color: Color=Color("fff4d4")):
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path]=load(path)
	return textures[path]

func mon_atlas(m:Dictionary,mode:String="front")->Texture2D:
	var sid=str(int(m.get("species",1)))
	var look:Dictionary=m.get("look",{})
	var key=sid+mode+JSON.stringify(look)
	if atlases.has(key):return atlases[key]
	var entry=source_manifest.pokemon.get(sid,{})
	if not entry.has(mode):mode="front"
	if not entry.has(mode):return null
	var img:Image=texture("res://assets/indigo/"+entry[mode].file).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var frame_width=int(entry[mode].frame)
	# Original animated palettes are retained; variants change opaque color regions only.
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c=img.get_pixel(x,y)
			if c.a<.5 or c.v<.25:continue
			var local_x=x%frame_width
			var local_y=y%frame_width
			var region="body"
			# Saturated red/pink pixels in the face are an explicit prototype palette mask.
			if (c.h<.08 or c.h>.9) and c.s>.55 and local_y<float(frame_width)*.7:region="eye" if local_y<float(frame_width)*.47 else "mouth"
			var pat=str(look.get("pattern","Liso"));var seed_value=int(look.get("seed",0))%997
			if region=="body":
				if pat=="Pintas" and posmod((local_x/4)*7+(local_y/4)*11+seed_value,17)<3:region="detail"
				if pat=="Listras" and posmod(local_x+local_y/2+seed_value,10)<3:region="detail"
				if pat=="Mosaico" and posmod(local_x/8+local_y/7+seed_value,3)==0:region="detail"
				if look.get("mark","")=="Sinal":
					var positions=[Vector2(.5,.24),Vector2(.3,.5),Vector2(.65,.5),Vector2(.5,.78),Vector2(.75,.3)]
					var pos=positions[int(look.get("mark_place",0))%5]*Vector2(frame_width,frame_width)
					if Vector2(local_x,local_y).distance_to(pos)<3:region="mark_color"
			var chosen=str(look.get(region,"original"))
			if chosen!="original":
				var target=Color(chosen);var out=Color.from_hsv(target.h,target.s,clampf(c.v*target.v,0,1));out.a=c.a;img.set_pixel(x,y,out)
	var tex=ImageTexture.create_from_image(img);atlases[key]=tex;return tex

func mon_texture(m:Dictionary)->Texture2D:
	var sid=str(int(m.get("species",1)));var key=sid+JSON.stringify(m.get("look",{}))
	if looks.has(key):return looks[key]
	var atlas=mon_atlas(m)
	if atlas==null:return null
	var n=atlas.get_height();var image=atlas.get_image().get_region(Rect2i(0,0,n,n));var tex=ImageTexture.create_from_image(image);looks[key]=tex;return tex

func mon(m:Dictionary,pos:Vector2,_sz:float=80,mode:String="front"):
	var sid=str(int(m.get("species",1)));var entry=source_manifest.pokemon.get(sid,{})
	if not entry.has(mode):mode="front"
	var t=mon_atlas(m,mode)
	if t==null:return
	var n=int(entry[mode].frame);var count=int(entry[mode].frames);var frame=int(Time.get_ticks_msec()/75)%max(1,count)
	# Source battle sprites are 1x pixels, rendered exactly 2x in the 512x384 world.
	draw_texture_rect_region(t,Rect2(pos-Vector2(n,n),Vector2(n*2,n*2)),Rect2(frame*n,0,n,n))

func follower(m:Dictionary,pos:Vector2,direction:int=0,walking:bool=true,body_scale:float=1.0,centered:bool=false):
	var entry=source_manifest.pokemon.get(str(int(m.get("species",1))),{})
	if not entry.has("follower"):return
	var original=mon_atlas(m,"follower")
	var cell=int(entry.follower.frame)
	var size_pixels=int(round(float(cell)*body_scale/2.0)*2)
	var t:Texture2D=original
	if size_pixels!=cell:
		var key=str(m.get("species",1))+str(m.get("id",""))+"scaled"+str(size_pixels)+JSON.stringify(m.get("look",{}))
		if not looks.has(key):
			var image=original.get_image();image.resize(size_pixels*2,size_pixels*2,Image.INTERPOLATE_NEAREST);image.resize(size_pixels*4,size_pixels*4,Image.INTERPOLATE_NEAREST);looks[key]=ImageTexture.create_from_image(image)
		t=looks[key];cell=size_pixels
	var frame=int(Time.get_ticks_msec()/150)%4 if walking else 0
	var anchor=entry.follower.get("anchors",[])
	var offset=Vector2(cell/2,cell/2) if centered else Vector2(cell/2,cell-8)
	if not anchor.is_empty():
		var point=anchor[direction*4+frame]["center" if centered else "feet"]
		offset=Vector2(point[0],point[1])*float(cell)/float(entry.follower.frame)
		offset=Vector2(round(offset.x/2)*2,round(offset.y/2)*2)
	pos=Vector2(round(pos.x/2)*2,round(pos.y/2)*2)
	draw_texture_rect_region(t,Rect2(pos-offset,Vector2(cell,cell)),Rect2(frame*cell,direction*cell,cell,cell))

func trainer(pos:Vector2,color:String="green",npc:String="",look:Dictionary={},colors:Dictionary={},mode:String="walk",facing:int=0):
	var path="res://assets/characters/trainer-%s.png"%color
	if npc!="": path="res://assets/characters/%s.png"%npc
	var tex=texture(path) if npc!="" else indigo.compose(look,colors,mode)
	var frame=0
	if npc=="" and game.moving: frame=int(Time.get_ticks_msec()/180)%4
	if tex:
		var cell=int(tex.get_width()/4)
		draw_texture_rect_region(tex,Rect2(pos-Vector2(cell/2,cell-12),Vector2(cell,cell)),Rect2(frame*cell,facing*cell,cell,cell))

func room(p:Dictionary):
	maps.v=self;maps.room(p)

func outdoors(p:Dictionary):
	maps.v=self;maps.outdoors(p)

func battle(b:Dictionary):
	maps.v=self;maps.arena()
	for blast in b.get("blasts",[]):
		var v=Vector2(blast.pos.x,blast.pos.y);var col=type_color(blast.type)
		if blast.done:effect(blast.type,v,float(blast.at))
		else:draw_arc(v,blast.radius,0,TAU,32,col,2);draw_arc(v,blast.radius*clampf(1-(float(blast.at)-game.server_time())/.75,0,1),0,TAU,32,col,2)
	for f in b.fighters:
		var v=Vector2(f.pos.x,f.pos.y)
		draw_rect(Rect2(v-Vector2(18,-14),Vector2(36,8)),Color(0.2,0.3,0.25,.4))
		follower(f.mon,v,int(f.get("facing",0)),f.auto or Vector2(f.get("velocity",{}).get("x",0),f.get("velocity",{}).get("y",0)).length()>1,float(f.get("physique",{}).get("scale",1)),true)
		rect(v.x-24,v.y-24,48,6,"354842");rect(v.x-22,v.y-22,44*float(f.hp)/float(f.max_hp),2,"9ce2a8")
		if float(f.invincible)>game.server_time():draw_arc(v,24,0,TAU,24,Color("f6e3ae"),2)
	for shot in b.get("projectiles",[]):
		var v=Vector2(shot.pos.x,shot.pos.y);var col=type_color(shot.type)
		draw_circle(v,shot.radius,col);draw_circle(v,shot.radius*.4,Color("fff2c6"))
	for beam in b.get("beams",[]):
		var a=Vector2(beam.from.x,beam.from.y);var z=Vector2(beam.to.x,beam.to.y);var color=type_color(beam.type)
		if game.server_time()<float(beam.at):draw_line(a,z,Color(color,.4),2)
		else:draw_line(a,z,color,float(beam.width)*2);draw_line(a,z,Color("f7f2d3"),float(beam.width));effect(beam.type,z,float(beam.at))

	if float(b.get("pause_until",0))>game.server_time():
		draw_rect(Rect2(0,72,512,280),Color(1,1,.8,.25));txt(Vector2(174,60),"Um novo poder desperta!",16)
	if game.data.player.battle!="":
		var aim=get_local_mouse_position();draw_line(aim-Vector2(6,0),aim+Vector2(6,0),Color("fff6d5"),2);draw_line(aim-Vector2(0,6),aim+Vector2(0,6),Color("fff6d5"),2)

func effect(kind:String,pos:Vector2,at:float):
	var file={"Fogo":"fire blast","Água":"018-Water01","Elétrico":"017-Thunder01","Gelo":"PRAS- Ice"}.get(kind,"015-Fire01")
	var tex=texture("res://assets/indigo/effects/"+file+".png")
	if tex==null:return
	var count=int(tex.get_width()/192)*int(tex.get_height()/192);var frame=clampi(int((game.server_time()-at)*24),0,maxi(0,count-1))
	draw_texture_rect_region(tex,Rect2(pos-Vector2(96,96),Vector2(192,192)),Rect2((frame%5)*192,(frame/5)*192,192,192))

func type_color(t:String)->Color:
	return Color({"Fogo":"e88d63","Água":"83c4df","Planta":"91ce82","Elétrico":"edcf76","Gelo":"c2e6f1","Pedra":"b1a1bc","Voador":"c3d6db"}.get(t,"bf99dd"))

func arcade(a:Dictionary,p:Dictionary):
	var t=game.server_time()-float(a.start)
	rect(0,0,512,384,"263449")
	if a.kind=="arcade":
		for i in 50:rect((i*89)%512,posmod(int(t*20)+i*67,384),2,4,"657589")
		for i in 9:
			var v=Vector2(40+i*54+sin(t*.8+i+float(a.seed))*28,fmod(t*65+i*41,310)+50)
			draw_circle(v,7,Color("db98b4"));draw_circle(v,3,Color("ffe2c2"))
	else:
		var center=256+sin(t*.65+float(a.seed))*110
		rect(center-80,0,160,384,"65928d" if a.kind=="Natação" else "a99c73")
		for i in 10:rect(center-4,posmod(int(t*150)+i*48,384),8,20,"eee0af")
	var m=game.team_mon(0)
	mon(m,Vector2(a.pos.x,a.pos.y),64)
	txt(Vector2(24,44),"%s  ·  %d pontos  ·  %d vidas"%[a.kind,a.score,a.hp],16)
	txt(Vector2(380,44),"%ds"%max(0,30-int(t)),16)

func _draw():
	if game==null or game.data.is_empty():
		room({"theme":"verde","decor":[]});trainer(Vector2(260,280));return
	var p:Dictionary=game.data.player
	if game.data.get("battle")!=null: battle(game.data.battle);return
	if game.spectate!="":
		for b in game.data.get("battles",[]):
			if b.id==game.spectate:battle(b);return
	if p.get("arcade")!=null:arcade(p.arcade,p);return
	if p.area=="casa":room(p)
	else:outdoors(p)
	for other in game.data.get("players",[]):
		if other.area==p.area and p.area!="casa":trainer(Vector2(other.pos.x,other.pos.y),other.color,"",other.get("look",{}),other.get("colors",{}));txt(Vector2(other.pos.x-20,other.pos.y-48),other.name,10)
	var mode="fish" if float(p.get("fishing",0))>0 else ("bike" if p.get("transport","")=="bike" and p.area!="casa" else "walk")
	trainer(Vector2(p.pos.x,p.pos.y),p.color,"",p.get("look",{}),p.get("colors",{}),mode,int(p.get("facing",0)))
	var partner=game.team_mon(0)
	if not partner.is_empty():follower(partner,Vector2(p.pos.x-44,p.pos.y+2),int(p.get("facing",0)),game.moving)
	if float(p.get("fishing",0))>0:
		var bite=float(p.fishing)
		txt(Vector2(150,54),"FISGOU! PRESSIONE E" if game.server_time()>=bite and game.server_time()<=bite+2 else "Aguardando uma fisgada…",16)
