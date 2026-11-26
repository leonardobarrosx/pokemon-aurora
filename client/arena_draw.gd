extends RefCounted
# Arena oficial dos ginásios: o campo é maior que a tela, a câmera acompanha
# a luta e o jogador pode afastar o zoom (Z ou rodinha do mouse). O chão vem
# do atlas do ginásio (assets/stadiums/<id>.png) e os obstáculos de
# assets/stadiums/<id>_props.png, os dois montados por ferramentas/mapas/
# stadiums.py com tiles e sprites do próprio jogo (FireRed e Emerald).

const ORDER=".,smnMbpkwuW_><^vijgoXflexVY}{)(zRTGOALC|"
const WATER="wuW_><^vz"
const DEEP="W_><^vz"
const WALLS="RG"
const PROPS="rqhItPFT~"
const CROWD=[1,4,7,16,19,25,26,41,74,129,133,134,135,136,94,197,2,5,8]

var v:Node2D
var cam:=Vector2(-1,-1)
var zoom:=1.0
var user_zoom:=1.0
var xf:=Transform2D()
var floor_char:={}
var boxes:={}

func size_of(fd:Dictionary)->Vector2:
	return Vector2(int(fd.cols),int(fd.rows))*float(fd.cell)

func fighter_pos(b:Dictionary,i:int)->Vector2:
	var f=b.fighters[i]
	var key=str(b.id)+":"+str(f.owner)
	if v.render_positions.has(key):return v.render_positions[key]
	return Vector2(f.pos.x,f.pos.y)

func mine(b:Dictionary)->int:
	for i in b.fighters.size():
		if str(b.fighters[i].owner)==str(v.game.data.player.get("id","")):return i
	return 0

# Câmera: segue o meio da luta puxando para o seu Pokémon, afasta sozinha
# quando os dois se separam e nunca mostra fora da arena.
func camera(b:Dictionary,shake:Vector2)->Transform2D:
	var fd:Dictionary=b.field
	var size=size_of(fd)
	var me=mine(b)
	var a=fighter_pos(b,me);var c=fighter_pos(b,1-me)
	var whole=minf(512.0/size.x,384.0/size.y)
	var fit=minf(512.0/(absf(a.x-c.x)+260.0),384.0/(absf(a.y-c.y)+200.0))
	var want=clampf(minf(user_zoom,fit),whole,1.0)
	var center=a.lerp(c,.38)
	var dt=v.get_process_delta_time()
	if cam.x<0:cam=center;zoom=want
	var k=1.0-exp(-5.0*dt)
	zoom=lerpf(zoom,want,k)
	var half=Vector2(256,192)/zoom
	center.x=clampf(center.x,half.x,size.x-half.x) if size.x>half.x*2 else size.x/2
	center.y=clampf(center.y,half.y,size.y-half.y) if size.y>half.y*2 else size.y/2
	cam=cam.lerp(center,k)
	xf=Transform2D(0,Vector2(zoom,zoom),0,(Vector2(256,192)-cam*zoom+shake).round())
	return xf

func cycle_zoom():
	user_zoom={1.0:.7,.7:.45,.45:1.0}.get(snappedf(user_zoom,.01),1.0)

func wheel(delta:float):
	user_zoom=clampf(user_zoom+delta,.4,1.0)

func visible_cells(fd:Dictionary)->Rect2i:
	var inv=xf.affine_inverse()
	var a=inv*Vector2(0,0);var z=inv*Vector2(512,384)
	var cs=float(fd.cell)
	return Rect2i(maxi(0,int(a.x/cs)-1),maxi(0,int(a.y/cs)-2),mini(int(fd.cols),int(z.x/cs)+2),mini(int(fd.rows),int(z.y/cs)+3))

func cell_at(fd:Dictionary,c:int,r:int)->String:
	if c<0 or r<0 or c>=int(fd.cols) or r>=int(fd.rows):return "R"
	return str(fd.cells)[r*int(fd.cols)+c]

func ground_char(fd:Dictionary)->String:
	var id=str(fd.get("id",""))
	if floor_char.has(id):return floor_char[id]
	var count={}
	for ch in str(fd.cells):
		if ORDER.find(ch)>=0 and ch not in "RTGOALC|" and WATER.find(ch)<0:count[ch]=int(count.get(ch,0))+1
	var best=".";var n=0
	for ch in count:
		if count[ch]>n:best=ch;n=count[ch]
	floor_char[id]=best
	return best

func tile(tex:Texture2D,ch:String,at:Vector2,cs:float,i:int,h:float=-1):
	var row=ORDER.find(ch)
	if row<0:row=0
	var variant=(i*7+i/13*3)%4
	if h<0:h=cs
	v.draw_texture_rect_region(tex,Rect2(at,Vector2(cs,h)),Rect2(variant*32,row*32,32,32.0*h/cs))

# Obstáculo do atlas de sprites: casa de 64x64 apoiada no fundo da célula.
# A metade de baixo vai com o chão; a de cima, depois dos Pokémon.
func prop(fd:Dictionary,ch:String,c:int,r:int,top:bool,alpha:float=1.0):
	var k=PROPS.find(ch)
	if k<0:return
	var tex:Texture2D=v.texture("res://assets/stadiums/%s_props.png"%str(fd.get("id","")))
	if tex==null:return
	var cs=float(fd.cell);var at=Vector2(c,r)*cs
	var variant=(c*7+r*3)%2
	var src=Rect2(variant*64,k*64+(0 if top else 32),64,32)
	var dst=Rect2(at+Vector2(cs/2-32,-cs if top else 0),Vector2(64,32))
	v.draw_texture_rect_region(tex,dst,src,Color(1,1,1,alpha))

func ground(b:Dictionary):
	var fd:Dictionary=b.field
	var tex:Texture2D=v.texture("res://assets/stadiums/%s.png"%str(fd.get("id",b.get("gym",""))))
	var cs=float(fd.cell);var cols=int(fd.cols)
	var now=v.game.server_time()
	var vis=visible_cells(fd)
	var base=ground_char(fd)
	var size=size_of(fd)
	v.draw_rect(Rect2(-400,-400,size.x+800,size.y+800),Color("0b1118"))
	for r in range(vis.position.y,vis.size.y):
		for c in range(vis.position.x,vis.size.x):
			var i=r*cols+c;var ch=cell_at(fd,c,r);var at=Vector2(c,r)*cs
			var under=ch
			if (PROPS.find(ch)>=0 and "F~T".find(ch)<0) or ch=="D":under=base
			if ch=="F":under="R"
			if ch=="~":under="W"
			if tex:tile(tex,under,at,cs,i)
			else:v.draw_rect(Rect2(at,Vector2(cs,cs)),Color("7c8a6a"))
			ground_detail(fd,ch,c,r,at,cs,now,i)
	# Paredes com face frontal (profundidade 3/4) e sombras no chão.
	for r in range(vis.position.y,vis.size.y):
		for c in range(vis.position.x,vis.size.x):
			var ch=cell_at(fd,c,r);var at=Vector2(c,r)*cs
			if WALLS.find(ch)>=0:
				var below=cell_at(fd,c,r+1)
				if WALLS.find(below)<0 and "ALC".find(below)<0:
					# Face da parede (tile do jogo) e a sombra que ela joga no chão.
					if tex and ch=="R":tile(tex,"|",at+Vector2(0,cs),cs,c+r*7,cs*.5)
					else:v.draw_rect(Rect2(at+Vector2(0,cs),Vector2(cs,cs*.5)),Color(.55,.75,.85,.55))
					v.draw_rect(Rect2(at+Vector2(0,cs*1.5),Vector2(cs,6)),Color(0,0,0,.22))
				var right=cell_at(fd,c+1,r)
				if WALLS.find(right)<0 and right!="A":v.draw_rect(Rect2(at+Vector2(cs,6),Vector2(7,cs)),Color(0,0,0,.16))
	stands(b,fd,vis,now)
	for r in range(vis.position.y,vis.size.y):
		for c in range(vis.position.x,vis.size.x):
			var ch=cell_at(fd,c,r)
			if PROPS.find(ch)>=0:prop_low(fd,ch,c,r,Vector2(c,r)*cs,cs,now)
	decor(fd,false,[])
	events_ground(fd,now)

# Decoração (assets/stadiums/decor.png): a base vai com o chão e o que sobe
# acima dela é desenhado depois dos Pokémon, translúcido se alguém está atrás.
func decor(fd:Dictionary,top:bool,fpos:Array):
	var list=fd.get("decor",[])
	if list==null or list.is_empty():return
	var tex:Texture2D=v.texture("res://assets/stadiums/decor.png")
	if tex==null:return
	var cs=float(fd.cell)
	for d in list:
		var src=Rect2(d.src[0],d.src[1],d.src[2],d.src[3])
		var foot=Vector2(d.foot[0],d.foot[1])*cs
		var base=Vector2(d.x,d.y)*cs
		var bottom=base.y+foot.y
		var left=base.x+(foot.x-src.size.x)/2
		var cut=src.size.y-foot.y # parte acima da base
		if not top:
			v.draw_set_transform_matrix(xf*Transform2D(0,Vector2(1,.35),0,Vector2(base.x+foot.x/2,bottom-4)))
			v.draw_circle(Vector2.ZERO,foot.x*.55,Color(0,0,0,.22))
			v.draw_set_transform_matrix(xf)
			v.draw_texture_rect_region(tex,Rect2(Vector2(left,base.y),Vector2(src.size.x,foot.y)),Rect2(src.position+Vector2(0,maxf(cut,0)),Vector2(src.size.x,foot.y)))
		elif cut>0:
			var r=Rect2(Vector2(left,base.y-cut),Vector2(src.size.x,cut))
			var alpha=1.0
			for p in fpos:
				if r.grow(8).has_point(p):alpha=.45
			v.draw_texture_rect_region(tex,r,Rect2(src.position,Vector2(src.size.x,cut)),Color(1,1,1,alpha))

func ground_detail(fd:Dictionary,ch:String,c:int,r:int,at:Vector2,cs:float,now:float,i:int):
	if ch=="." or ch=="M":
		for d in [[0,-1],[1,0],[0,1],[-1,0]]:
			if cell_at(fd,c+d[0],r+d[1])=="l":
				var horiz=d[1]!=0
				var o=at+Vector2(maxf(0,d[0])*(cs-5),maxf(0,d[1])*(cs-5))
				for k in 4:
					var seg=Rect2(o+(Vector2(k*8,0) if horiz else Vector2(0,k*8)),Vector2(8,5) if horiz else Vector2(5,8))
					v.draw_rect(seg,Color("e8b830") if k%2==0 else Color("222222"))
	if WATER.find(ch)>=0:
		# Espuma na borda e reflexo correndo na água.
		for d in [[0,-1],[1,0],[0,1],[-1,0]]:
			var n=cell_at(fd,c+d[0],r+d[1])
			if WATER.find(n)<0:
				var edge=Rect2(at+Vector2(maxf(0,d[0])*(cs-3),maxf(0,d[1])*(cs-3)),Vector2(3 if d[0]!=0 else cs,3 if d[1]!=0 else cs))
				v.draw_rect(edge,Color(1,1,1,.45+.15*sin(now*3+i)))
		var y=at.y+fposmod(now*9+float(i%7)*4,cs)
		v.draw_line(Vector2(at.x+4+float(i%5)*3,y),Vector2(at.x+14+float(i%5)*3,y),Color(1,1,1,.22),1)
		if DEEP.find(ch)>=0 and WATER.find(cell_at(fd,c,r-1))>=0 and "pk".find(cell_at(fd,c,r-1))<0:pass
		if "pk".find(cell_at(fd,c,r-1))>=0 or "pk".find(cell_at(fd,c-1,r))>=0:
			v.draw_rect(Rect2(at,Vector2(cs,6)),Color(0,0,0,.25)) # sombra da plataforma
	match ch:
		"u":
			var t=fposmod(now*.6+float(i)*.37,1.0)
			if i%3==0:v.draw_circle(at+Vector2(cs*.5+sin(now+i)*6,cs*.5-t*22),5+t*6,Color(1,1,1,.16*(1-t)))
		"p","k":
			v.draw_rect(Rect2(at+Vector2(0,cs-4),Vector2(cs,4)),Color(0,0,0,.3))
			if ch=="k":v.draw_rect(Rect2(at+Vector2(2,2),Vector2(cs-4,cs-4)),Color(1,.7,.2,.15+.1*sin(now*4+i)),false,1)
		"l":
			v.draw_rect(Rect2(at,Vector2(cs,cs)),Color(1,.55,.1,.1+.08*sin(now*2.5+i*.7)))
			var bub=at+Vector2(6+fposmod(float(i)*7,20),cs-fposmod(now*12+float(i)*5,cs))
			v.draw_circle(bub,2,Color("ffd060"))
		"f":
			for j in 3:
				var fx=at.x+6+j*10;var h=10+7*absf(sin(now*9+j+i))
				v.draw_colored_polygon(PackedVector2Array([Vector2(fx-5,at.y+cs-2),Vector2(fx+5,at.y+cs-2),Vector2(fx,at.y+cs-2-h)]),Color("f4762b"))
				v.draw_colored_polygon(PackedVector2Array([Vector2(fx-2,at.y+cs-2),Vector2(fx+2,at.y+cs-2),Vector2(fx,at.y+cs-2-h*.55)]),Color("ffe27a"))
		"g":
			var sway=sin(now*2+float(i)*.6)*2
			for j in 4:
				var gx=at.x+4+j*8
				v.draw_line(Vector2(gx,at.y+cs),Vector2(gx+sway,at.y+cs-14-(j%2)*4),Color("2f7d3a"),2)
		"i","j":
			if int(now*1.5+i)%9==0:v.draw_circle(at+Vector2(8+float(i%3)*6,8),1.5,Color.WHITE)
		"e":
			v.draw_rect(Rect2(at,Vector2(cs,cs)),Color(1,.95,.4,.06+.06*sin(now*6+i)))
		"x":
			v.draw_circle(at+Vector2(8+fposmod(float(i)*5,16),10+5*sin(now*2+i)),2.5,Color(.85,.6,1,.6))
		"Y":
			v.draw_arc(at+Vector2(cs/2,cs/2),10+3*sin(now*4),0,TAU,20,Color(.85,.6,1,.7),2)
		"V":
			v.draw_circle(at+Vector2(cs/2,cs/2-6-fposmod(now*10,10)),3,Color(1,1,1,.18))
		"}","{",")","(":
			var dir={"}":Vector2.RIGHT,"{":Vector2.LEFT,")":Vector2.DOWN,"(":Vector2.UP}[ch]
			var p0=at+Vector2(cs/2,cs/2)+dir*(fposmod(now*40+i*5,cs)-cs/2)
			v.draw_line(p0,p0+dir*8,Color(1,1,1,.5),1)

# Sombra no chão e a base do obstáculo (sprite do jogo); a queda d'água
# ganha espuma e fios de água correndo por cima do tile.
func prop_low(fd:Dictionary,ch:String,c:int,r:int,at:Vector2,cs:float,now:float):
	if "rqhItPI".find(ch)>=0:
		var mid=at+Vector2(cs/2,cs*.8)
		var w=cs*(.9 if ch=="t" else .55)
		v.draw_set_transform_matrix(xf*Transform2D(0,Vector2(1,.4),0,mid))
		v.draw_circle(Vector2.ZERO,w,Color(0,0,0,.25))
		v.draw_set_transform_matrix(xf)
	prop(fd,ch,c,r,false)
	if ch=="~":
		for k in 3:
			var x=at.x+6+k*9;var y=at.y+fposmod(now*50+k*11,cs)
			v.draw_line(Vector2(x,y),Vector2(x,y+8),Color(1,1,1,.55),2)
		for k in 3:v.draw_circle(at+Vector2(6+k*10,cs-2+2*sin(now*8+k)),3,Color(1,1,1,.5))
	if ch=="T" and int(now*2+c+r)%3!=0:
		v.draw_circle(at+Vector2(cs*.3,cs*.3),1.5,Color("ff6a4a"))

# Partes altas: copa das árvores, colunas, pilares de gelo. Ficam por cima
# dos Pokémon e ficam transparentes quando um deles está atrás.
func upper(b:Dictionary):
	var fd:Dictionary=b.field
	var cs=float(fd.cell);var now=v.game.server_time()
	var vis=visible_cells(fd)
	var fpos=[fighter_pos(b,0),fighter_pos(b,1)]
	for r in range(vis.position.y,vis.size.y):
		for c in range(vis.position.x,vis.size.x):
			var ch=cell_at(fd,c,r)
			if PROPS.find(ch)<0:continue
			var at=Vector2(c,r)*cs
			var alpha=1.0
			if "tPIT".find(ch)>=0:
				for p in fpos:
					if p.y<at.y+cs*.7 and p.y>at.y-cs*1.2 and absf(p.x-at.x-cs/2)<cs*1.1:alpha=.45
			prop(fd,ch,c,r,true,alpha)
	decor(fd,true,fpos)
	events_air(fd,now)
	lighting(fd,now)

# Arquibancada com plateia de Pokémon e os camarotes dos treinadores.
func stands(b:Dictionary,fd:Dictionary,vis:Rect2i,now:float):
	var cs=float(fd.cell);var cols=int(fd.cols)
	var cheer=0.0
	for c in b.get("cutins",[]):
		if now-float(c.at)>=0 and now-float(c.at)<1.6:cheer=1.0
	for r in range(vis.position.y,vis.size.y):
		for c in range(vis.position.x,vis.size.x):
			var ch=cell_at(fd,c,r)
			if ch!="A":continue
			var at=Vector2(c,r)*cs
			var seed=(c*31+r*17)%97
			if seed%5==0:continue # cadeira vazia
			var sp=CROWD[seed%CROWD.size()]
			var top=r<int(fd.rows)/2
			var hop=absf(sin(now*(4+seed%3)+seed))*(1+cheer*5)
			v.follower({"species":sp,"id":"plateia"},at+Vector2(cs/2,cs*.72-hop),0 if top else 3,cheer>0,.55)
	# Camarotes: plataforma, faixa com a cor do tema e o treinador em cima.
	for key in ["L","C"]:
		var box=box_rect(fd,key)
		if box.size.x<=0:continue
		var col=theme_color(str(fd.theme)) if key=="L" else Color("3d6fa8")
		v.draw_rect(box.grow(2),Color("1a1e26"),false,3)
		v.draw_rect(Rect2(box.position,Vector2(box.size.x,4)),col)
		v.draw_rect(box,Color("e7b443"),false,2)
	var me=mine(b)
	var p=v.game.data.player
	var lc=box_rect(fd,"L");var cc=box_rect(fd,"C")
	if cc.size.x>0 and str(b.fighters[me].owner)==str(p.get("id","")):
		v.trainer(cc.get_center()+Vector2(0,10),p.color,"",p.get("look",{}),p.get("colors",{}),"walk",3)
	if lc.size.x>0 and str(b.get("kind",""))=="gym":
		var sprite=str(v.game.gym_info(str(b.get("gym",""))).get("sprite",""))
		if sprite!="":v.trainer(lc.get_center()+Vector2(0,14),"green",sprite,{},{},"walk",0)

func box_rect(fd:Dictionary,key:String)->Rect2:
	var id=str(fd.get("id",""))+key
	if boxes.has(id):return boxes[id]
	var cells=str(fd.cells);var cols=int(fd.cols);var cs=float(fd.cell)
	var lo=Vector2(1e9,1e9);var hi=Vector2(-1,-1)
	for i in cells.length():
		if cells[i]==key:
			var p=Vector2(i%cols,i/cols)
			lo=lo.min(p);hi=hi.max(p)
	var r=Rect2(lo*cs,(hi-lo+Vector2.ONE)*cs) if hi.x>=0 else Rect2()
	boxes[id]=r
	return r

func theme_color(t:String)->Color:
	return Color({"rocha":"b08a5a","agua":"3f8fd6","planta":"5fae4f","fogo":"e0552e","gelo":"8cc8ea","eletrico":"e8c23a","veneno":"9a5ac0","psiquico":"e06aa8","terra":"a07040","lutador":"c05a3a","normal":"c8c0b0","voador":"8ab4e0","inseto":"9ab43a","fantasma":"6a5aa8","aco":"9aa4b0","dragao":"6a4ad0"}.get(t,"c8c0b0"))

# Avisos no chão: só aparecem enquanto importam.
func events_ground(fd:Dictionary,now:float):
	for e in fd.get("events",[]):
		var p=Vector2(e.pos.x,e.pos.y);var rad=float(e.radius)
		var warn=now<float(e.at)
		var fill=clampf((now-float(e.start))/maxf(.01,float(e.at)-float(e.start)),0,1)
		match str(e.kind):
			"geyser","steam":
				if warn and str(e.kind)=="geyser":
					var pulse=.5+.5*sin(now*14)
					v.draw_circle(p,rad,Color(1,.3,.2,.12+.1*pulse))
					v.draw_arc(p,rad,0,TAU,32,Color(1,.35,.25,.9),2)
					v.draw_circle(p,rad*fill,Color(1,.4,.2,.18))
					v.draw_string(v.font,p+Vector2(-4,-rad-4),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ff6a4a"))
				elif warn:
					v.draw_arc(p,rad,0,TAU,32,Color(1,1,1,.5+.3*sin(now*12)),2)
			"shock":
				if warn:
					for k in 16:
						var a0=k*TAU/16+now*2
						v.draw_arc(p,rad,a0,a0+TAU/32,4,Color(1,.92,.3,.9),2)
					v.draw_circle(p,rad*fill,Color(1,.92,.3,.12))
				elif now<float(e.until):
					v.draw_circle(p,rad,Color(1,.95,.35,.12+.08*sin(now*30)))
			"sink":
				if warn:
					v.draw_rect(Rect2(p-Vector2(16,16),Vector2(32,32)),Color(1,.6,.1,.6+.4*sin(now*16)),false,2)
				else:
					var g=clampf((now-float(e.at))/.6,0,1)
					v.draw_arc(p,10+g*20,0,TAU,20,Color(1,1,1,.6*(1-g)),2)

func events_air(fd:Dictionary,now:float):
	for e in fd.get("events",[]):
		var p=Vector2(e.pos.x,e.pos.y);var rad=float(e.radius)
		if now<float(e.at):continue
		var life=clampf((now-float(e.at))/maxf(.01,float(e.until)-float(e.at)),0,1)
		match str(e.kind):
			"geyser":
				for k in 6:
					var h=life*90+k*12
					v.draw_circle(p+Vector2(sin(now*20+k)*6,-h),14-k,Color(1,.6-k*.06,.2,.8*(1-life)))
			"steam":
				for k in 8:
					var o=Vector2(cos(k*.8+life*2),sin(k*1.3))*rad*.55+Vector2(0,-life*20)
					v.draw_circle(p+o,rad*.45,Color(.95,.95,.97,.32*(1-life*life)))
			"pollen":
				for k in 18:
					var o=Vector2(cos(k*2.1+now),sin(k*1.7+now*1.3))*rad*fposmod(k*.37,1.0)
					v.draw_circle(p+o,2,Color(1,.95,.4,.8*(1-life)))
			"shock":
				for k in 4:
					var a=Vector2.from_angle(k*1.7+floor(now*12))*rad*.8
					var mid=a*.5+Vector2.from_angle(now*30+k)*10
					v.draw_polyline(PackedVector2Array([p,p+mid,p+a]),Color(1,.95,.4,.9),2)
			"tremor":
				v.draw_arc(p,rad*life,0,TAU,40,Color(.6,.45,.3,.6*(1-life)),6)
				if life<.3:v.shake_until=Time.get_ticks_msec()+120
			"dust","chip":
				for k in 8:
					var o=Vector2.from_angle(k*.79)*rad*life*1.3+Vector2(0,-life*10)
					v.draw_circle(p+o,3*(1-life)+1,Color(.65,.55,.42,.8*(1-life)))
			"crack":
				for k in 6:
					var o=Vector2.from_angle(k*1.05)*rad*life
					v.draw_line(p+o*.5,p+o,Color(.9,.97,1,1-life),2)
			"teleport":
				v.draw_circle(p,rad*(1-life),Color(.8,.5,1,.6))
				v.draw_arc(p,rad*(1+life),0,TAU,24,Color(.9,.7,1,1-life),2)

# Luz e clima de cada arena.
func lighting(fd:Dictionary,now:float):
	var size=size_of(fd);var cs=float(fd.cell)
	match str(fd.theme):
		"planta","inseto":
			for k in 6:
				var x=float(k)*size.x/5.0-120+sin(now*.3+k)*20
				v.draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+70,0),Vector2(x+250,size.y),Vector2(x+150,size.y)]),Color(1,.97,.7,.07))
		"fogo","dragao":
			var cells=str(fd.cells);var cols=int(fd.cols)
			for i in range(0,cells.length(),3):
				if cells[i]=="l":v.draw_circle(Vector2(i%cols+.5,i/cols+.5)*cs,46,Color(1,.45,.1,.05+.02*sin(now*2+i)))
		"gelo":
			for k in 30:
				var p=Vector2(fposmod(k*97.0+now*12,size.x),fposmod(k*53.0+now*25,size.y))
				v.draw_circle(p,1.5,Color(1,1,1,.7))
		"rocha","terra":
			for k in 24:
				var p=Vector2(fposmod(k*131.0+now*6,size.x),fposmod(k*71.0-now*4,size.y))
				v.draw_circle(p,1.2,Color(.9,.8,.6,.45))
		"agua":
			var cells=str(fd.cells);var cols=int(fd.cols)
			for i in range(0,cells.length(),2):
				if DEEP.find(cells[i])>=0:
					var p=(Vector2(i%cols,i/cols)+Vector2(.5,.5))*cs
					v.draw_arc(p+Vector2(sin(now+i)*6,0),8+4*sin(now*1.5+i),0,PI,8,Color(1,1,1,.12),1)

# Sobreposição da transmissão (em coordenadas de tela).
func overlay(b:Dictionary):
	var fd:Dictionary=b.field;var now=v.game.server_time()
	var g=v.game.gym_info(str(b.get("gym","")))
	# Vinheta e refletores.
	for k in 6:v.draw_rect(Rect2(k*3,k*3,512-k*6,384-k*6),Color(0,0,0,.07),false,3)
	for x in [30,482]:
		v.draw_colored_polygon(PackedVector2Array([Vector2(x-8,0),Vector2(x+8,0),Vector2(256+(x-256)*.25+70,384),Vector2(256+(x-256)*.25-70,384)]),Color(1,1,.85,.035))
	var plate=Rect2(10,324,230,40)
	v.draw_rect(plate,Color(0.04,0.07,0.12,.9));v.draw_rect(plate,Color("e7b443"),false,2)
	v.draw_rect(Rect2(plate.position,Vector2(6,plate.size.y)),theme_color(str(fd.theme)))
	v.txt(plate.position+Vector2(14,16),("Ginásio de "+str(g.get("town",""))).to_upper(),9,Color("e7b443"))
	v.txt(plate.position+Vector2(14,32),str(fd.get("title",g.get("badge",""))),12)
	var blink=int(now*2)%2==0
	v.draw_rect(Rect2(10,10,62,16),Color(0.06,0.08,0.12,.85))
	v.draw_circle(Vector2(20,18),4,Color("e2553b") if blink else Color("7a2a1e"))
	v.txt(Vector2(28,22),"AO VIVO",9)
	v.draw_rect(Rect2(412,356,92,18),Color(0.06,0.08,0.12,.8))
	v.txt(Vector2(418,369),"Z · zoom %d%%"%int(round(zoom*100)),9,Color("cfe3f0"))
	for corner in [Vector2(6,6),Vector2(506,6),Vector2(6,378),Vector2(506,378)]:
		var dx=12.0 if corner.x<256 else -12.0;var dy=12.0 if corner.y<192 else -12.0
		v.draw_line(corner,corner+Vector2(dx,0),Color(1,1,1,.8),2);v.draw_line(corner,corner+Vector2(0,dy),Color(1,1,1,.8),2)
