extends Node2D

var game: Node
var textures: Dictionary = {}
var looks: Dictionary = {}
var font = ThemeDB.fallback_font
var indigo=preload("res://indigo_character.gd").new()
var maps=preload("res://indigo_maps.gd").new()
var source_manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/indigo/manifest.json"))
var atlases:Dictionary={}
var render_positions:Dictionary={}
var previous_hp:Dictionary={}
var flash_until:Dictionary={}
var shake_until=0.0
var action_pulse_until=0.0
var action_pulse=""
const INK = Color("273e42")
var map_cache:Dictionary={}
var camera:=Vector2.ZERO

# Mapas externos gerados com os tilesets do FireRed (ferramentas/mapas).
func map_for(area:String)->Dictionary:
	if map_cache.has(area):return map_cache[area]
	var path="res://assets/maps/%s.json"%area
	var data:Dictionary={}
	if FileAccess.file_exists(path):data=JSON.parse_string(FileAccess.get_file_as_string(path))
	map_cache[area]=data
	return data

func world_mouse()->Vector2:
	return get_local_mouse_position()+camera

func draw_map_layer(m:Dictionary,key:String):
	var tex=texture("res://assets/maps/%s_%s.png"%[m.atlas,"below" if key=="tiles" else "above"])
	if tex==null:return
	var cell=float(m.cell);var cols=int(m.columns);var w=int(m.w);var h=int(m.h)
	# A vista cobre a tela inteira (1920×1080 = 960×540 do mundo), não só a moldura.
	var x0=maxi(0,int((camera.x-224)/cell));var y0=maxi(0,int((camera.y-78)/cell))
	var x1=mini(w,x0+int(960/cell)+2);var y1=mini(h,y0+int(540/cell)+2)
	var cells:Array=m[key]
	var border:Array=m.get("border",[])
	if key=="tiles" and border.size()==4:
		# Fora do mapa, repete a borda do jogo original (árvores, água...).
		var bx0=int(floor((camera.x-224)/cell));var by0=int(floor((camera.y-78)/cell))
		for y in range(by0,by0+int(540/cell)+2):
			for x in range(bx0,bx0+int(960/cell)+2):
				if x>=0 and y>=0 and x<w and y<h:continue
				var b=int(border[posmod(y,2)*2+posmod(x,2)])
				draw_texture_rect_region(tex,Rect2(x*cell,y*cell,cell,cell),Rect2((b%cols)*16,(b/cols)*16,16,16))
	for y in range(y0,y1):
		for x in range(x0,x1):
			var t=int(cells[y*w+x])
			if t<0:continue
			draw_texture_rect_region(tex,Rect2(x*cell,y*cell,cell,cell),Rect2((t%cols)*16,(t/cols)*16,16,16))

func map_scene(p:Dictionary,m:Dictionary):
	var mode="fish" if float(p.get("fishing",0))>0 else ("bike" if p.get("transport","")=="bike" else "walk")
	var input_dir=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
	var speed=120.0 if mode=="bike" else (112.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 80.0)
	var player_pos=smooth_position("trainer:"+str(p.id),Vector2(p.pos.x,p.pos.y),input_dir*speed)
	var size=Vector2(float(m.w),float(m.h))*float(m.cell)
	camera=(player_pos-Vector2(256,200)).clamp(Vector2(224,78),(size-Vector2(736,462)).max(Vector2(224,78))).round()
	# Mapas menores que a tela (interiores) ficam centralizados.
	if size.x<960:camera.x=round(size.x/2-256)
	if size.y<540:camera.y=round(size.y/2-192)
	draw_set_transform(-camera)
	draw_map_layer(m,"tiles")
	var points:Dictionary=m.get("points",{})
	if p.area=="jardim":
		for i in 6:
			var key="canteiro%d"%i
			if not points.has(key) or i>=p.plots.size():continue
			var pos=Vector2(points[key][0],points[key][1])
			var plot=p.plots[i]
			if float(plot.at)>0:
				maps.v=self;maps.region("Exterior1",Rect2(160,160,32,64),pos-Vector2(16,48))
				if plot.water:draw_circle(pos+Vector2(14,10),3,Color("83c4df"))
			txt(pos+Vector2(-4,30),str(i+1),10)
	if p.area=="safari" and p.get("safari")!=null:
		var s=p.safari;var target=Vector2(s.pos.x,s.pos.y);mon({"species":s.species},target)
		draw_arc(target,18+sin(Time.get_ticks_msec()/220.0)*5,0,TAU,32,Color("f1df93"),2)
	var actors:Array=[]
	for n in m.get("npcs",[]):actors.append({"y":float(n.y),"npc":n})
	for other in game.data.get("players",[]):
		if other.area==p.area:actors.append({"y":float(other.pos.y),"other":other})
	actors.append({"y":player_pos.y,"me":true})
	actors.sort_custom(func(a,b):return a.y<b.y)
	for a in actors:
		if a.has("npc"):
			var n=a.npc;var pos=Vector2(n.x,n.y);trainer(pos,"green",n.sprite,{},{},"walk",int(n.get("facing",0)))
			if str(n.name)!="":txt(pos-Vector2(12,58),n.name,10)
		elif a.has("other"):
			var other=a.other;var other_pos=smooth_position("trainer:"+str(other.id),Vector2(other.pos.x,other.pos.y))
			trainer(other_pos,other.color,"",other.get("look",{}),other.get("colors",{}));txt(other_pos-Vector2(20,58),other.name,10)
		else:
			var partner=game.team_mon(0)
			if not partner.is_empty():follower(partner,player_pos+Vector2(-30,-4),int(p.get("facing",0)),game.moving)
			trainer(player_pos,p.color,"",p.get("look",{}),p.get("colors",{}),mode,int(p.get("facing",0)))
	draw_map_layer(m,"above")
	draw_set_transform(Vector2.ZERO)

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
	img=preload("res://pokemon_regions.gd").apply(img,sid,mode,frame_width,look)
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

func observe_snapshot(snapshot:Dictionary):
	var battle=snapshot.get("battle")
	if battle==null:return
	for fighter in battle.fighters:
		var owner=str(fighter.owner);var hp=float(fighter.hp)
		if previous_hp.has(owner) and hp<float(previous_hp[owner]):
			flash_until[owner]=Time.get_ticks_msec()+150
			shake_until=Time.get_ticks_msec()+110
		previous_hp[owner]=hp

func local_action(kind:String):
	action_pulse=kind;action_pulse_until=Time.get_ticks_msec()+120

func smooth_position(key:String,target:Vector2,velocity:Vector2=Vector2.ZERO)->Vector2:
	var age=clampf(game.server_time()-float(game.data.get("now",game.server_time())),0,.12)
	var predicted=target+velocity*age
	if not render_positions.has(key):render_positions[key]=target
	var weight=1.0-exp(-18.0*get_process_delta_time())
	render_positions[key]=(render_positions[key] as Vector2).lerp(predicted,weight)
	if (render_positions[key] as Vector2).distance_to(target)>90:render_positions[key]=target
	return render_positions[key]

func battle(b:Dictionary):
	var shake=Vector2.ZERO
	if Time.get_ticks_msec()<shake_until:
		var phase=float(Time.get_ticks_msec()%40)/40.0*TAU;shake=Vector2(cos(phase),sin(phase))*2
	draw_set_transform(shake)
	maps.v=self;maps.arena()
	arena_field(b)
	var now=game.server_time()
	for blast in b.get("blasts",[]):
		var v=Vector2(blast.pos.x,blast.pos.y);var col=type_color(blast.type);var radius=float(blast.radius)
		if blast.done:
			if blast.get("wave",false):
				var grow=clampf((now-float(blast.at))/.35,0,1)
				draw_arc(v,radius*grow,0,TAU,48,Color(col,1-grow),10*(1-grow)+2)
				draw_circle(v,radius*grow,Color(col,.18*(1-grow)))
			effect(blast.type,v,float(blast.at))
		else:
			# Aviso no chão: a área marcada enche até o golpe cair.
			var fill=clampf(1-(float(blast.at)-now)/.9,0,1)
			draw_circle(v,radius,Color(col,.16))
			draw_arc(v,radius,0,TAU,40,Color(col,.9),2)
			draw_circle(v,radius*fill,Color(col,.22))
	for f in b.fighters:
		var velocity=Vector2(f.get("velocity",{}).get("x",0),f.get("velocity",{}).get("y",0))
		var v=smooth_position(str(b.id)+":"+str(f.owner),Vector2(f.pos.x,f.pos.y),velocity)
		draw_rect(Rect2(v-Vector2(18,-14),Vector2(36,8)),Color(0.2,0.3,0.25,.4))
		follower(f.mon,v,int(f.get("facing",0)),f.auto or Vector2(f.get("velocity",{}).get("x",0),f.get("velocity",{}).get("y",0)).length()>1,float(f.get("physique",{}).get("scale",1)),true)
		if Time.get_ticks_msec()<int(flash_until.get(str(f.owner),0)):draw_circle(v,26,Color(1,1,1,.3))
		rect(v.x-24,v.y-24,48,6,"354842");rect(v.x-22,v.y-22,44*float(f.hp)/float(f.max_hp),2,"9ce2a8")
		if float(f.invincible)>now:draw_arc(v,24,0,TAU,24,Color("f6e3ae"),2)
		if float(f.get("charge_until",0))>now:
			# Investida: rastro de velocidade atrás do Pokémon.
			var back=-velocity.normalized() if velocity.length()>1 else Vector2.LEFT
			for k in 3:draw_line(v+back*(14+k*8)+back.orthogonal()*(k-1)*8,v+back*(34+k*10)+back.orthogonal()*(k-1)*8,Color(1,1,1,.7-k*.18),3)
		if float(f.get("stun_until",0))>now:
			for k in 3:
				var a=now*6+k*TAU/3;draw_circle(v+Vector2(cos(a)*14,-30+sin(a)*4),2.5,Color("ffe27a"))
	for shot in b.get("projectiles",[]):
		var age=clampf(game.server_time()-float(game.data.get("now",game.server_time())),0,.12)
		var v=Vector2(shot.pos.x,shot.pos.y)+Vector2(shot.vel.x,shot.vel.y)*age;var col=type_color(shot.type)
		if str(shot.get("move",""))=="Flamethrower":
			draw_circle(v,shot.radius*1.5,Color(col,.45));draw_circle(v,shot.radius*.8,Color("ffd27a"))
		else:
			var tail=Vector2(shot.vel.x,shot.vel.y).normalized()*-shot.radius*2.2
			draw_line(v,v+tail,Color(col,.5),shot.radius*1.2)
			draw_circle(v,shot.radius,col);draw_circle(v,shot.radius*.4,Color("fff2c6"))
	for beam in b.get("beams",[]):
		var a=Vector2(beam.from.x,beam.from.y);var z=Vector2(beam.to.x,beam.to.y);var color=type_color(beam.type)
		if game.server_time()<float(beam.at):draw_line(a,z,Color(color,.4),2)
		else:draw_line(a,z,color,float(beam.width)*2);draw_line(a,z,Color("f7f2d3"),float(beam.width));effect(beam.type,z,float(beam.at))

	if float(b.get("pause_until",0))>game.server_time():
		draw_rect(Rect2(0,72,512,280),Color(1,1,.8,.25))
	if game.data.player.battle!="":
		var aim=get_local_mouse_position();draw_line(aim-Vector2(6,0),aim+Vector2(6,0),Color("fff6d5"),2);draw_line(aim-Vector2(0,6),aim+Vector2(0,6),Color("fff6d5"),2)
		if Time.get_ticks_msec()<action_pulse_until:
			var mine:Dictionary={}
			for fighter in b.fighters:
				if fighter.owner==game.data.player.id:mine=fighter
			if not mine.is_empty():
				var origin=smooth_position(str(b.id)+":"+str(mine.owner),Vector2(mine.pos.x,mine.pos.y))
				draw_arc(origin,16+(action_pulse_until-Time.get_ticks_msec())*.08,0,TAU,20,type_color(game.data.species[str(int(mine.mon.species))].type),2)
	draw_set_transform(Vector2.ZERO)

# Marcações do campo e treinadores na beira da arena (como nas arenas
# ranqueadas): cada treinador fica fora da área de luta, atrás do parceiro.
func arena_field(b:Dictionary):
	var line=Color(1,1,1,.55)
	var field=Rect2(18,94,476,256)
	draw_rect(field,line,false,2)
	draw_line(Vector2(256,94),Vector2(256,350),line,2)
	draw_arc(Vector2(256,222),38,0,TAU,40,line,2)
	draw_circle(Vector2(256,222),3,line)
	for side in [0,1]:
		var x=18 if side==0 else 494
		var box=Rect2(x-(0 if side==0 else 48),172,48,100)
		draw_rect(box,line,false,2)
	var spots=[Vector2(36,378),Vector2(476,96)]
	for i in b.fighters.size():
		var f=b.fighters[i]
		var at=spots[i] if i<2 else spots[0]
		var facing=3 if i==0 else 0
		if str(f.owner)==game.data.player.get("id",""):
			var p=game.data.player
			trainer(at,p.color,"",p.get("look",{}),p.get("colors",{}),"walk",facing)
		elif str(f.owner)=="npc":
			if b.kind=="gym":trainer(at,"green","gardener",{},{},"walk",facing)
		else:
			for other in game.data.get("players",[]):
				if str(other.get("id",""))==str(f.owner):trainer(at,other.get("color","green"),"",other.get("look",{}),other.get("colors",{}),"walk",facing)

func effect(kind:String,pos:Vector2,at:float):
	var file={"Fogo":"fire blast","Água":"018-Water01","Elétrico":"017-Thunder01","Gelo":"PRAS- Ice"}.get(kind,"015-Fire01")
	var tex=texture("res://assets/indigo/effects/"+file+".png")
	if tex==null:return
	var count=int(tex.get_width()/192)*int(tex.get_height()/192);var frame=clampi(int((game.server_time()-at)*24),0,maxi(0,count-1))
	draw_texture_rect_region(tex,Rect2(pos-Vector2(96,96),Vector2(192,192)),Rect2((frame%5)*192,(frame/5)*192,192,192))

func type_color(t:String)->Color:
	return Color({"Fogo":"e88d63","Água":"83c4df","Planta":"91ce82","Elétrico":"edcf76","Gelo":"c2e6f1","Pedra":"c7a978","Voador":"c3d6db","Normal":"e3dccd","Fantasma":"9c82c8","Noturno":"6b6170","Psíquico":"f08cb4","Terra":"d2a868","Inseto":"b5cf6a"}.get(t,"bf99dd"))

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

func _draw():
	camera=Vector2.ZERO
	if game==null or game.data.is_empty():
		room({"theme":"verde","decor":[]});trainer(Vector2(260,280));return
	var p:Dictionary=game.data.player
	if game.data.get("battle")!=null: battle(game.data.battle);return
	if game.spectate!="":
		for b in game.data.get("battles",[]):
			if b.id==game.spectate:battle(b);return
	if p.get("arcade")!=null:arcade(p.arcade,p);return
	var area_map=map_for(str(p.area))
	if not area_map.is_empty():map_scene(p,area_map);return
	if p.area=="casa":room(p)
	else:outdoors(p)
	for other in game.data.get("players",[]):
		if other.area==p.area and p.area!="casa":
			var other_pos=smooth_position("trainer:"+str(other.id),Vector2(other.pos.x,other.pos.y))
			trainer(other_pos,other.color,"",other.get("look",{}),other.get("colors",{}));txt(other_pos-Vector2(20,48),other.name,10)
	var mode="fish" if float(p.get("fishing",0))>0 else ("bike" if p.get("transport","")=="bike" and p.area!="casa" else "walk")
	var player_target=Vector2(p.pos.x,p.pos.y)
	var input_dir=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
	var local_speed=120.0 if p.get("transport","")=="bike" and p.area!="casa" else 80.0
	var player_pos=smooth_position("trainer:"+str(p.id),player_target,input_dir*local_speed)
	trainer(player_pos,p.color,"",p.get("look",{}),p.get("colors",{}),mode,int(p.get("facing",0)))
	var partner=game.team_mon(0)
	if not partner.is_empty():follower(partner,player_pos+Vector2(-44,2),int(p.get("facing",0)),game.moving)
