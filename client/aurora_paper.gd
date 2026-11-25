extends Control

# Superfícies decorativas do caderno de campo: pergaminho com curvas de nível,
# silhueta de montanhas e pinheiros, além do selo da marca.

const Design=preload("res://aurora_theme.gd")
var mode:="panel"
var seed_value:=7
var stage:=0

static func make(kind:String,rect:Rect2)->Control:
	var node=new()
	node.mode=kind
	node.position=rect.position
	node.size=rect.size
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _draw():
	match mode:
		"panel":parchment()
		"rail":rail()
		"logo":logo()
		"pines":pines(Rect2(Vector2.ZERO,size),Color("#1c3d47"),1.0)
		"plot":plot()
		"capsule":capsule()
		"field":field()

func rounded(rect:Rect2,radius:float)->PackedVector2Array:
	var pts=PackedVector2Array()
	var corners=[[rect.position+Vector2(rect.size.x-radius,radius),-PI/2],[rect.end-Vector2(radius,radius),0.0],[rect.position+Vector2(radius,rect.size.y-radius),PI/2],[rect.position+Vector2(radius,radius),PI]]
	for corner in corners:
		for i in 7:
			var a=corner[1]+i*(PI/2)/6
			pts.append(corner[0]+Vector2(cos(a),sin(a))*radius)
	return pts

func parchment():
	var r=Rect2(Vector2.ZERO,size)
	var outline=rounded(r,18)
	draw_colored_polygon(outline,Design.PAPER)
	var inner=rounded(r.grow(-6),14)
	# Curvas de nível suaves no fundo, como num mapa topográfico.
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	for k in 9:
		var cx=rng.randf_range(0,size.x);var cy=rng.randf_range(0,size.y)
		var base=rng.randf_range(60,190)
		for ring in 4:
			var pts=PackedVector2Array()
			for i in 49:
				var a=TAU*i/48.0
				var wobble=1.0+.12*sin(a*3+k)+.07*sin(a*5+ring)
				var p=Vector2(cx,cy)+Vector2(cos(a)*1.5,sin(a))*(base+ring*26)*wobble
				pts.append(p)
			draw_polyline(clip(pts,r.grow(-10)),Color("#d9ccb2",.30),1.2,true)
	# Montanhas em traço no canto superior direito.
	var peaks=[[size.x-420,96,60],[size.x-330,96,88],[size.x-220,96,70],[size.x-130,96,98],[size.x-40,96,54]]
	var ridge=PackedVector2Array([Vector2(size.x-500,96)])
	for pk in peaks:
		ridge.append(Vector2(pk[0]-28,pk[1]-pk[2]*.45))
		ridge.append(Vector2(pk[0],pk[1]-pk[2]))
		ridge.append(Vector2(pk[0]+30,pk[1]-pk[2]*.4))
	ridge.append(Vector2(size.x-8,96))
	var hill=ridge.duplicate();hill.append(Vector2(size.x-8,98));hill.append(Vector2(size.x-500,98))
	draw_colored_polygon(clip(hill,r.grow(-8)),Color("#d8ccb4",.22))
	draw_polyline(clip(ridge,r.grow(-8)),Color("#9c917c",.30),1.4,true)
	for pk in peaks:
		draw_line(Vector2(pk[0],pk[1]-pk[2]),Vector2(pk[0]-8,pk[1]-pk[2]*.55),Color("#9c917c",.25),1.0,true)
	pines(Rect2(Vector2(10,size.y-150),Vector2(260,140)),Color("#a99d86",.28),.9)
	pines(Rect2(Vector2(size.x-230,size.y-120),Vector2(220,110)),Color("#a99d86",.22),.7)
	draw_polyline(_closed(inner),Color("#ddd1b9"),1.0,true)
	draw_polyline(_closed(outline),Color("#c9b996"),2.0,true)

func clip(points:PackedVector2Array,area:Rect2)->PackedVector2Array:
	var out=PackedVector2Array()
	for p in points:out.append(Vector2(clampf(p.x,area.position.x,area.end.x),clampf(p.y,area.position.y,area.end.y)))
	return out

func _closed(points:PackedVector2Array)->PackedVector2Array:
	var out=points.duplicate();out.append(points[0]);return out

func pines(area:Rect2,color:Color,scale_factor:float):
	var rng=RandomNumberGenerator.new();rng.seed=seed_value+int(area.position.x)
	var x=area.position.x
	while x<area.end.x:
		var h=rng.randf_range(.45,1.0)*area.size.y*scale_factor
		var w=h*.42
		var base=area.end.y
		var tree=PackedVector2Array([Vector2(x,base-h)])
		for tier in 3:
			var ty=base-h+h*(tier+1)/3.4
			var tw=w*(tier+1)/3.0
			tree.append(Vector2(x+tw*.5,ty))
			tree.append(Vector2(x+tw*.22,ty))
		tree.append(Vector2(x+w*.55,base-h*.08))
		tree.append(Vector2(x-w*.55,base-h*.08))
		for tier in range(2,-1,-1):
			var ty=base-h+h*(tier+1)/3.4
			var tw=w*(tier+1)/3.0
			tree.append(Vector2(x-tw*.22,ty))
			tree.append(Vector2(x-tw*.5,ty))
		draw_colored_polygon(tree,color)
		draw_rect(Rect2(x-2,base-h*.1,4,h*.1),color)
		x+=w*rng.randf_range(.55,.95)

func rail():
	draw_rect(Rect2(Vector2.ZERO,size),Design.NIGHT)
	draw_rect(Rect2(size.x-3,0,3,size.y),Color("#0a1822"))
	pines(Rect2(Vector2(-6,size.y-110),Vector2(size.x+12,100)),Color("#1f4450"),1.0)
	pines(Rect2(Vector2(14,size.y-70),Vector2(size.x,66)),Color("#2a5a62"),1.0)

func logo():
	# Selo próprio de Aurora: esfera laranja com faixa e rastro de cometa.
	var c=size/2
	var r=minf(size.x,size.y)*.40
	draw_arc(c+Vector2(-r*.15,0),r*1.18,deg_to_rad(110),deg_to_rad(250),18,Design.CORAL,r*.22,true)
	draw_circle(c,r,Design.CORAL)
	draw_colored_polygon(PackedVector2Array([c+Vector2(-r,r*.05),c+Vector2(r,r*.05),c+Vector2(r*.86,r*.5),c+Vector2(r*.5,r*.86),c+Vector2(0,r),c+Vector2(-r*.5,r*.86),c+Vector2(-r*.86,r*.5)]),Design.NIGHT)
	draw_rect(Rect2(c.x-r,c.y-r*.08,r*2,r*.2),Design.NIGHT)
	draw_circle(c,r*.32,Design.NIGHT)
	draw_circle(c,r*.18,Color("#fbf6ea"))

func plot():
	# Canteiro: monte de terra e planta conforme o estágio (0 vazio, 1 broto, 2 arbusto, 3 frutos).
	var c=Vector2(size.x/2,size.y*.72)
	var mound=PackedVector2Array()
	for i in 25:
		var a=PI+PI*i/24.0
		mound.append(c+Vector2(cos(a)*size.x*.44,sin(a)*size.y*.26))
	draw_colored_polygon(mound,Color("#7a5232"))
	draw_rect(Rect2(c.x-size.x*.44,c.y-2,size.x*.88,size.y*.12),Color("#5e3d24"))
	for i in 6:draw_circle(c+Vector2(-size.x*.3+i*size.x*.12,-size.y*.08+(i%2)*4),2,Color("#9b6c44"))
	var leaf=Color("#3f9a4f");var dark=Color("#2c7038")
	if stage>=1:
		draw_line(c+Vector2(0,-size.y*.1),c+Vector2(0,-size.y*.32),dark,3)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-size.y*.26),c+Vector2(-16,-size.y*.36),c+Vector2(-4,-size.y*.4)]),leaf)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-size.y*.28),c+Vector2(16,-size.y*.38),c+Vector2(5,-size.y*.42)]),leaf)
	if stage>=2:
		for p in [Vector2(-18,-.36),Vector2(18,-.36),Vector2(0,-.5),Vector2(-10,-.46),Vector2(10,-.46)]:
			draw_circle(c+Vector2(p.x,p.y*size.y),13,leaf)
		for p in [Vector2(-12,-.4),Vector2(10,-.5)]:draw_circle(c+Vector2(p.x,p.y*size.y),6,dark)
	if stage>=3:
		for p in [Vector2(-16,-.38),Vector2(14,-.4),Vector2(0,-.52),Vector2(-4,-.34)]:
			draw_circle(c+Vector2(p.x,p.y*size.y),7,Color("#d9483b"))
			draw_circle(c+Vector2(p.x-2,p.y*size.y-2),2,Color("#ffb3a3"))

func capsule():
	# Incubadora de vidro com o ovo dentro.
	var w=size.x;var h=size.y
	var glass=Rect2(w*.2,h*.18,w*.6,h*.62)
	draw_rect(Rect2(w*.14,h*.06,w*.72,h*.14),Color("#8e9aa3"))
	draw_rect(Rect2(w*.14,h*.06,w*.72,h*.04),Color("#c3ccd2"))
	draw_rect(glass,Color("#bfe6ef",.55))
	draw_rect(glass,Color("#6f8c99"),false,3)
	draw_line(glass.position+Vector2(14,10),glass.position+Vector2(14,glass.size.y-14),Color(1,1,1,.7),5)
	var egg=PackedVector2Array();var ec=Vector2(w*.5,h*.52)
	for i in 32:
		var a=TAU*i/32.0
		var ry=h*.2*(1.08 if sin(a)<0 else .92)
		egg.append(ec+Vector2(cos(a)*w*.17,sin(a)*ry))
	draw_colored_polygon(egg,Color("#f3eccf"))
	for p in [Vector2(-.06,-.1),Vector2(.07,.02),Vector2(-.03,.1)]:draw_circle(ec+Vector2(p.x*w,p.y*h),w*.035,Color("#6fbf73"))
	draw_rect(Rect2(w*.14,h*.8,w*.72,h*.12),Color("#8e9aa3"))
	draw_rect(Rect2(w*.24,h*.82,w*.52,h*.05),Color("#f2b13c"))

func field():
	# Miniatura da arena para o saguão: gramado com duas clareiras.
	draw_rect(Rect2(Vector2.ZERO,size),Color("#7cc96a"))
	for i in 14:draw_circle(Vector2(i*size.x/13.0,0),size.x/18.0,Color("#2f7d45"))
	for i in 14:draw_circle(Vector2(i*size.x/13.0,size.y*.03),size.x/22.0,Color("#3d9653"))
	for spot in [Vector2(.32,.72),Vector2(.68,.42)]:
		var pts=PackedVector2Array()
		for i in 24:
			var a=TAU*i/24.0
			pts.append(Vector2(spot.x*size.x,spot.y*size.y)+Vector2(cos(a)*size.x*.18,sin(a)*size.y*.1))
		draw_colored_polygon(pts,Color("#d9c08b"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("#1b3a2a"),false,3)
