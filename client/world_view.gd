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

# Mapas de DS (Johto, Sinnoh): imagens já desenhadas por chunk, em vez de tiles.
func draw_image_layer(m:Dictionary,key:String):
	var img:Dictionary=m.image
	var base="res://assets/maps/%s/"%img.dir
	var suffix="" if key=="tiles" else "_up"
	if img.get("crop")!=null:
		var t=image_tex(base+"0_0"+suffix+".png")
		if t:draw_texture_rect(t,Rect2(Vector2(float(img.crop[0]),float(img.crop[1]))*2,t.get_size()*2),false)
		return
	if not m.has("_tiles"):
		var have={}
		for pair in img.get("tiles",[]):have[Vector2i(int(pair[0]),int(pair[1]))]=true
		m["_tiles"]=have
	var size=float(img.chunk)*2
	var c0=int(floor((camera.x-224)/size));var r0=int(floor((camera.y-78)/size))
	for r in range(r0,r0+int(540/size)+2):
		for c in range(c0,c0+int(960/size)+2):
			if not m._tiles.has(Vector2i(c,r)):continue
			var t=image_tex(base+"%d_%d%s.png"%[c,r,suffix])
			if t:draw_texture_rect(t,Rect2(c*size,r*size,size,size),false)

func image_tex(path:String)->Texture2D:
	if not textures.has(path):
		textures[path]=load(path) if ResourceLoader.exists(path) else null
	return textures[path]

# Altura do chão na posição (mapas de DS): o desenho sobe K*altura na tela.
func lift(m:Dictionary,pos:Vector2)->Vector2:
	if not m.has("heights"):return pos
	var cell=float(m.cell);var x=int(pos.x/cell);var y=int(pos.y/cell);var w=int(m.w)
	if x<0 or y<0 or x>=w or y>=int(m.h):return pos
	return pos-Vector2(0,float(m.heights[y*w+x])*float(m.image.k)*2)

func draw_map_layer(m:Dictionary,key:String):
	if m.has("image"):
		draw_image_layer(m,key)
		return
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
	var player_pos=lift(m,smooth_position("trainer:"+str(p.id),Vector2(p.pos.x,p.pos.y),input_dir*speed))
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
	for wm in game.data.get("wild",[]):actors.append({"y":float(wm.pos.y),"wild":wm})
	actors.append({"y":player_pos.y,"me":true})
	actors.sort_custom(func(a,b):return a.y<b.y)
	for a in actors:
		if a.has("wild"):
			var wm=a.wild;var wpos=smooth_position("wild:"+str(wm.id),Vector2(wm.pos.x,wm.pos.y))
			if bool(wm.get("water",false)):draw_arc(wpos+Vector2(0,4),18+sin(Time.get_ticks_msec()/280.0)*2,PI*.1,PI*.9,14,Color(1,1,1,.5),2)
			else:draw_circle(wpos+Vector2(0,2),9,Color(0,0,0,.18))
			follower({"species":wm.species,"id":wm.id},wpos,int(wm.get("facing",0)),true)
		elif a.has("npc"):
			var n=a.npc;var pos=lift(m,Vector2(n.x,n.y));trainer(pos,"green",n.sprite,{},{},"walk",int(n.get("facing",0)))
			if str(n.name)!="":txt(pos-Vector2(12,58),n.name,10)
		elif a.has("other"):
			var other=a.other;var other_pos=lift(m,smooth_position("trainer:"+str(other.id),Vector2(other.pos.x,other.pos.y)))
			trainer(other_pos,other.color,"",other.get("look",{}),other.get("colors",{}));txt(other_pos-Vector2(20,58),other.name,10)
		else:
			var ridden=game.mon_by_id(str(p.get("mount","")))
			var partner=game.team_mon(0)
			if not partner.is_empty() and partner.get("id","")!=ridden.get("id","-"):follower(partner,player_pos+Vector2(-30,-4),int(p.get("facing",0)),game.moving)
			if ridden.is_empty():trainer(player_pos,p.color,"",p.get("look",{}),p.get("colors",{}),mode,int(p.get("facing",0)))
			else:rider(ridden,player_pos,p.get("look",{}),p.get("colors",{}),int(p.get("facing",0)),str(p.get("transport","")))
	draw_map_layer(m,"above")
	# Fundo do mar: luz azulada por cima de tudo.
	if str(p.get("transport",""))=="dive":
		draw_rect(Rect2(camera,Vector2(512,384)),Color(0.05,0.25,0.55,.28))
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

# Treinador montado: o Pokémon (Natação na água, Corrida em terra) por baixo,
# maior que o normal, e o treinador sentado nas costas dele.
func rider(m:Dictionary,pos:Vector2,look:Dictionary,colors:Dictionary,facing:int,kind:String):
	var entry=source_manifest.pokemon.get(str(int(m.get("species",1))),{})
	if not entry.has("follower"):
		trainer(pos,"green","",look,colors,"surf",facing);return
	var cell=float(entry.follower.frame)
	var scale=clampf(96.0/cell,.5,1.8)
	var bob=sin(Time.get_ticks_msec()/260.0)*2 if kind in ["surf","dive"] else 0.0
	if kind=="surf":
		draw_arc(pos+Vector2(0,2),30+sin(Time.get_ticks_msec()/300.0)*3,PI*.1,PI*.9,18,Color(1,1,1,.55),2)
	var walking=game.moving or kind in ["surf","dive"]
	follower(m,pos+Vector2(0,bob),facing,walking,scale,false)
	var anchors=entry.follower.get("anchors",[])
	var frame=int(Time.get_ticks_msec()/150)%4 if walking else 0
	var back=40.0*scale*cell/64.0*.55
	if not anchors.is_empty():
		var a=anchors[facing*4+frame];back=(float(a.feet[1])-float(a.center[1]))*scale+10
	var seat=pos+Vector2(0,bob-back)
	var tex=indigo.compose(look,colors,"ride")
	if tex:
		var c=int(tex.get_width()/4);var f=int(Time.get_ticks_msec()/180)%4 if walking else 0
		draw_texture_rect_region(tex,Rect2(seat-Vector2(c/2,c-20),Vector2(c,c)),Rect2(f*c,facing*c,c,c))

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
	var field_map=map_for(str(b.get("area",""))) if str(b.get("area",""))!="" else {}
	var field_origin=Vector2(b.get("origin",{}).get("x",0),b.get("origin",{}).get("y",0))
	if not field_map.is_empty():
		# Batalha no próprio mapa: o campo é o pedaço do mapa onde o encontro aconteceu.
		draw_set_transform(shake-field_origin)
		draw_map_layer(field_map,"tiles")
		draw_set_transform(shake)
		var p=game.data.player;var tr=Vector2(b.get("trainer",{}).get("x",60),b.get("trainer",{}).get("y",300))
		if str(b.fighters[0].owner)==str(p.get("id","")):trainer(tr+Vector2(0,24),p.color,"",p.get("look",{}),p.get("colors",{}),"walk",int(p.get("facing",0)))
	else:
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

	if not field_map.is_empty():
		draw_set_transform(shake-field_origin);draw_map_layer(field_map,"above");draw_set_transform(shake)
	if float(b.get("pause_until",0))>game.server_time():
		draw_rect(Rect2(0,72,512,280),Color(1,1,.8,.25))
	cutin(b)
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

# Arte de batalha do treinador (estilo DS) por um instante ao lançar a
# Pokébola, trocar de Pokémon ou dar um comando de ataque especial.
const CUTIN_TIME=1.1
func cutin(b:Dictionary):
	var now=game.server_time();var show:Dictionary={}
	for c in b.get("cutins",[]):
		var age=now-float(c.at)
		if age>=0 and age<CUTIN_TIME:show=c
	if show.is_empty():return
	var side=int(show.side);var age=now-float(show.at)
	var f=b.fighters[side] if side<b.fighters.size() else {}
	var slide=clampf(age/.14,0,1)*clampf((CUTIN_TIME-age)/.16,0,1)
	var top=250.0 if side==0 else 92.0
	var accent=Color("e8833a") if side==0 else Color("4f7fd8")
	var dir=1.0 if side==0 else -1.0
	var off=(1.0-slide)*520*-dir
	# Faixa inclinada com linhas de velocidade.
	var band=PackedVector2Array([Vector2(off-20,top+14),Vector2(off+532,top),Vector2(off+532,top+92),Vector2(off-20,top+106)])
	draw_colored_polygon(band,Color(0.06,0.09,0.16,.88*slide))
	draw_line(band[0],band[1],accent,3);draw_line(band[3],band[2],accent,3)
	for k in 7:
		var y=top+18+k*12;var x=fposmod(now*900*dir+k*137,560)-24
		draw_line(Vector2(x,y),Vector2(x+40*dir,y),Color(1,1,1,.18*slide),2)
	var art=trainer_art(f,str(show.kind),age)
	var ax=(40.0 if side==0 else 330.0)+off
	if art.tex:draw_texture_rect_region(art.tex,Rect2(ax,top-30,140,140),art.region)
	var tx=(190.0 if side==0 else 40.0)+off
	var who=str(f.get("name","")) if str(f.get("owner",""))=="npc" else trainer_name(str(f.get("owner","")))
	txt(Vector2(tx,top+40),who.to_upper(),12,accent.lightened(.3))
	txt(Vector2(tx,top+66),str(show.text),20)

func trainer_name(owner:String)->String:
	if owner==game.data.player.get("id",""):return str(game.data.player.get("name",""))
	for other in game.data.get("players",[]):
		if str(other.get("id",""))==owner:return str(other.get("name",""))
	return ""

# Textura e recorte da arte: artes do Platinum são tiras animadas de 80 px
# (pose de lançar), com retrato para o ataque especial; as do Indigo e o
# jogador (criador de personagem) são uma imagem só.
func trainer_art(f:Dictionary,kind:String,age:float)->Dictionary:
	var art=str(f.get("art",""))
	if art!="":
		if art.begins_with("pt_"):
			var mug=texture("res://assets/trainers/%s_mug.png"%art) if kind=="special" and ResourceLoader.exists("res://assets/trainers/%s_mug.png"%art) else null
			if mug:return {"tex":mug,"region":Rect2(Vector2.ZERO,mug.get_size())}
			var strip=texture("res://assets/trainers/%s.png"%art)
			if strip==null:return {"tex":null}
			var n=int(strip.get_width()/80);var frame=clampi(int(age*12),0,n-1)
			return {"tex":strip,"region":Rect2(frame*80,0,80,80)}
		if art.begins_with("ds/"):
			var sheet=texture("res://assets/characters/%s.png"%art)
			if sheet==null:return {"tex":null}
			var cell=sheet.get_width()/4.0
			return {"tex":sheet,"region":Rect2(0,0,cell,cell)}
		var t=texture("res://assets/trainers/%s.png"%art)
		return {"tex":t,"region":Rect2(Vector2.ZERO,t.get_size()) if t else Rect2()}
	var look:Dictionary={};var colors:Dictionary={}
	var owner=str(f.get("owner",""))
	if owner==game.data.player.get("id",""):
		look=game.data.player.get("look",{});colors=game.data.player.get("colors",{})
	else:
		for other in game.data.get("players",[]):
			if str(other.get("id",""))==owner:look=other.get("look",{});colors=other.get("colors",{})
	var front=indigo.compose(look,colors,"front")
	return {"tex":front,"region":Rect2(Vector2.ZERO,front.get_size()) if front else Rect2()}

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
			if b.kind=="gym":
				var sprite=str(game.gym_info(str(b.get("gym",""))).get("sprite",""))
				trainer(at,"green",sprite if sprite!="" else "ds/hg_gsleader12",{},{},"walk",facing)
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
