extends Control

# Ícones vetoriais simples do caderno de campo, desenhados em uma grade 24×24.
# Nenhuma arte externa: cada símbolo usa primitivas do Godot.

var kind:=""
var tint:=Color.WHITE
var follow_parent:=false

static func make(name:String,color:Color,side:float=26)->Control:
	var icon=new()
	icon.kind=name
	icon.tint=color
	icon.custom_minimum_size=Vector2(side,side)
	icon.size=Vector2(side,side)
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	return icon

func _draw():
	var s=minf(size.x,size.y)/24.0
	var o=(size-Vector2(24,24)*s)/2
	var p=func(x:float,y:float)->Vector2:return o+Vector2(x,y)*s
	var w=maxf(1.6,2.1*s)
	var c=tint
	if follow_parent and get_parent() is Button:
		var owner_button=get_parent() as Button
		c=owner_button.get_theme_color("font_disabled_color" if owner_button.disabled else "font_color")
	match kind:
		"inicio","casa":
			draw_colored_polygon(PackedVector2Array([p.call(12,2.5),p.call(22.5,11.5),p.call(19.5,11.5),p.call(12,5.2),p.call(4.5,11.5),p.call(1.5,11.5)]),c)
			draw_rect(Rect2(p.call(5,11),Vector2(14,10.5)*s),c)
			draw_rect(Rect2(p.call(10,15),Vector2(4,6.5)*s),Color(0,0,0,0) if kind=="inicio" else c.darkened(.55))
			if kind=="inicio":draw_rect(Rect2(p.call(10,15),Vector2(4,6.5)*s),Color("#0f2230"))
			else:draw_rect(Rect2(p.call(16,3),Vector2(2.6,5)*s),c)
		"equipe","pokemon":
			draw_arc(p.call(12,12),9.2*s,0,TAU,32,c,w,true)
			draw_line(p.call(3,12),p.call(8.6,12),c,w,true)
			draw_line(p.call(15.4,12),p.call(21,12),c,w,true)
			draw_arc(p.call(12,12),3.2*s,0,TAU,20,c,w,true)
		"mapa":
			var pts=[p.call(2,5),p.call(8,3),p.call(16,5),p.call(22,3),p.call(22,19),p.call(16,21),p.call(8,19),p.call(2,21)]
			draw_colored_polygon(PackedVector2Array([pts[0],pts[1],pts[6],pts[7]]),c)
			draw_colored_polygon(PackedVector2Array([pts[1],pts[2],pts[5],pts[6]]),Color(c,.55))
			draw_colored_polygon(PackedVector2Array([pts[2],pts[3],pts[4],pts[5]]),c)
		"mochila":
			draw_rect(Rect2(p.call(4,7),Vector2(16,14)*s),c,false,w)
			draw_arc(p.call(12,7),4*s,PI,TAU,12,c,w,true)
			draw_rect(Rect2(p.call(7,13),Vector2(10,5)*s),c,false,w)
			draw_line(p.call(4,11),p.call(20,11),c,w)
		"pokedex","linhagens":
			if kind=="pokedex":
				draw_rect(Rect2(p.call(4,3),Vector2(16,18)*s),c,false,w)
				for y in [8,12,16]:draw_line(p.call(8,y),p.call(16,y),c,w)
			else:
				for i in 7:
					var t=i/6.0
					var y=3+t*18
					var a=sin(t*TAU)*6
					draw_line(p.call(12-a,y),p.call(12+a,y),c,w*.8)
				var left=PackedVector2Array();var right=PackedVector2Array()
				for i in 13:
					var t=i/12.0;var y=3+t*18;var a=sin(t*TAU)*6
					left.append(p.call(12-a,y));right.append(p.call(12+a,y))
				draw_polyline(left,c,w,true);draw_polyline(right,c,w,true)
		"treino":
			draw_rect(Rect2(p.call(1.5,8),Vector2(3,8)*s),c)
			draw_rect(Rect2(p.call(4.5,6),Vector2(3,12)*s),c)
			draw_rect(Rect2(p.call(16.5,6),Vector2(3,12)*s),c)
			draw_rect(Rect2(p.call(19.5,8),Vector2(3,8)*s),c)
			draw_rect(Rect2(p.call(7.5,10.8),Vector2(9,2.4)*s),c)
		"mercado","loja":
			draw_colored_polygon(PackedVector2Array([p.call(3,4),p.call(21,4),p.call(22.5,10),p.call(1.5,10)]),c)
			draw_rect(Rect2(p.call(4,10),Vector2(16,11)*s),c,false,w)
			draw_rect(Rect2(p.call(9,14),Vector2(6,7)*s),c)
		"profissao":
			draw_line(p.call(5,19),p.call(14,10),c,w*1.6,true)
			draw_arc(p.call(16.5,7.5),4.5*s,deg_to_rad(-200),deg_to_rad(70),14,c,w*1.4,true)
		"ranking":
			draw_colored_polygon(PackedVector2Array([p.call(6,3),p.call(18,3),p.call(17,10),p.call(12,14),p.call(7,10)]),c)
			draw_arc(p.call(6,7),3.4*s,PI*.5,PI*1.5,10,c,w)
			draw_arc(p.call(18,7),3.4*s,-PI*.5,PI*.5,10,c,w)
			draw_rect(Rect2(p.call(10.8,13),Vector2(2.4,4)*s),c)
			draw_rect(Rect2(p.call(7,17),Vector2(10,3.5)*s),c)
		"roupa":
			draw_colored_polygon(PackedVector2Array([p.call(8,3),p.call(10,5),p.call(14,5),p.call(16,3),p.call(22,7),p.call(19.5,11.5),p.call(17,10),p.call(17,21),p.call(7,21),p.call(7,10),p.call(4.5,11.5),p.call(2,7)]),c)
		"ps":
			draw_colored_polygon(PackedVector2Array([p.call(12,21),p.call(3,12),p.call(3,7),p.call(7,4),p.call(12,7),p.call(17,4),p.call(21,7),p.call(21,12)]),Color(0,0,0,0))
			draw_polyline(PackedVector2Array([p.call(12,20),p.call(3.5,11.5),p.call(3.5,7.5),p.call(7,4.5),p.call(12,7.5),p.call(17,4.5),p.call(20.5,7.5),p.call(20.5,11.5),p.call(12,20)]),c,w,true)
		"atq","def","res":
			var shield=PackedVector2Array([p.call(12,3),p.call(20,6),p.call(19,14),p.call(12,21),p.call(5,14),p.call(4,6),p.call(12,3)])
			if kind=="atq":
				draw_line(p.call(5,19),p.call(19,5),c,w*1.3,true)
				draw_line(p.call(4,14),p.call(10,20),c,w,true)
			else:
				draw_polyline(shield,c,w,true)
				if kind=="res":draw_colored_polygon(PackedVector2Array([p.call(12,6),p.call(17,8),p.call(16.3,13.5),p.call(12,18)]),c)
		"vel":
			draw_colored_polygon(PackedVector2Array([p.call(14,2),p.call(5,14),p.call(11,14),p.call(9,22),p.call(19,9),p.call(13,9)]),c)
		"esp","brilho":
			draw_colored_polygon(PackedVector2Array([p.call(12,2),p.call(14.2,9.8),p.call(22,12),p.call(14.2,14.2),p.call(12,22),p.call(9.8,14.2),p.call(2,12),p.call(9.8,9.8)]),c)
		"folha":
			draw_colored_polygon(PackedVector2Array([p.call(4,20),p.call(5,11),p.call(10,5),p.call(20,3),p.call(19,13),p.call(13,19)]),c)
			draw_line(p.call(4,20),p.call(15,8),Color("#fbf6ea"),w*.7,true)
		"agua":
			var drop=PackedVector2Array([p.call(12,2.5)])
			for i in 17:
				var a=deg_to_rad(-30+i*240.0/16)
				drop.append(p.call(12+cos(a)*6.5,15+sin(a)*6.5))
			draw_colored_polygon(drop,c)
		"relogio":
			draw_arc(p.call(12,12),9*s,0,TAU,28,c,w,true)
			draw_line(p.call(12,12),p.call(12,6.5),c,w,true)
			draw_line(p.call(12,12),p.call(16,14),c,w,true)
		"calendario":
			draw_rect(Rect2(p.call(3,5),Vector2(18,16)*s),c,false,w)
			draw_rect(Rect2(p.call(3,5),Vector2(18,4.5)*s),c)
			for x in [7,12,17]:for y in [13,17]:draw_rect(Rect2(p.call(x-1.2,y-1.2),Vector2(2.4,2.4)*s),c)
		"cesta","carrinho":
			if kind=="cesta":
				draw_colored_polygon(PackedVector2Array([p.call(2,10),p.call(22,10),p.call(19,21),p.call(5,21)]),c)
				draw_arc(p.call(12,10),6*s,PI,TAU,12,c,w,true)
			else:
				draw_polyline(PackedVector2Array([p.call(1.5,4),p.call(5,4),p.call(8,16),p.call(19,16),p.call(21.5,7),p.call(6.2,7)]),c,w,true)
				draw_circle(p.call(9,20),1.8*s,c);draw_circle(p.call(18,20),1.8*s,c)
		"troca":
			draw_line(p.call(3,8),p.call(19,8),c,w,true);draw_colored_polygon(PackedVector2Array([p.call(21.5,8),p.call(16,4),p.call(16,12)]),c)
			draw_line(p.call(21,16),p.call(5,16),c,w,true);draw_colored_polygon(PackedVector2Array([p.call(2.5,16),p.call(8,12),p.call(8,20)]),c)
		"genes":
			for pt in [[12,3],[3,12],[21,12],[12,21]]:draw_circle(p.call(pt[0],pt[1]),2.6*s,c)
			draw_arc(p.call(12,12),9*s,0,TAU,4,c,w*.8)
			draw_rect(Rect2(p.call(9,9),Vector2(6,6)*s),c,false,w)
		"golpes":
			draw_colored_polygon(PackedVector2Array([p.call(4,4),p.call(20,4),p.call(14,12),p.call(20,20),p.call(4,20),p.call(10,12)]),Color(0,0,0,0))
			draw_polyline(PackedVector2Array([p.call(4,4),p.call(20,4),p.call(13,12),p.call(20,20),p.call(4,20),p.call(11,12),p.call(4,4)]),c,w,true)
		"lutar":
			draw_line(p.call(4,20),p.call(18,6),c,w*1.6,true)
			draw_colored_polygon(PackedVector2Array([p.call(16,3),p.call(21,3),p.call(21,8)]),c)
			draw_line(p.call(3,15),p.call(9,21),c,w*1.3,true)
		"esquiva","fugir":
			draw_circle(p.call(15,4.5),2.4*s,c)
			draw_polyline(PackedVector2Array([p.call(7,9),p.call(12,7.5),p.call(15,10),p.call(12,15),p.call(15,18),p.call(14,22)]),c,w*1.2,true)
			draw_polyline(PackedVector2Array([p.call(12,15),p.call(8,19),p.call(4,19)]),c,w*1.2,true)
			draw_polyline(PackedVector2Array([p.call(15,10),p.call(19,12)]),c,w*1.2,true)
		"evoluir":
			draw_polyline(PackedVector2Array([p.call(5,13),p.call(12,6),p.call(19,13)]),c,w*1.4,true)
			draw_polyline(PackedVector2Array([p.call(5,20),p.call(12,13),p.call(19,20)]),c,w*1.4,true)
		"salvar":
			draw_rect(Rect2(p.call(3,3),Vector2(18,18)*s),c,false,w)
			draw_rect(Rect2(p.call(7,3),Vector2(9,6)*s),c)
			draw_rect(Rect2(p.call(7,13),Vector2(10,8)*s),c,false,w)
		"chat":
			draw_rect(Rect2(p.call(2.5,4),Vector2(19,12)*s),c,false,w)
			draw_colored_polygon(PackedVector2Array([p.call(6,15.5),p.call(11,15.5),p.call(6,20.5)]),c)
			for x in [8,12,16]:draw_circle(p.call(x,10),1.3*s,c)
		"tv":
			draw_rect(Rect2(p.call(2.5,5),Vector2(19,13)*s),c,false,w)
			draw_line(p.call(8,21),p.call(16,21),c,w)
			draw_colored_polygon(PackedVector2Array([p.call(10,8.5),p.call(15,11.5),p.call(10,14.5)]),c)
		"enviar":
			draw_colored_polygon(PackedVector2Array([p.call(2,11),p.call(22,3),p.call(15,21),p.call(11,13)]),c)
		"moeda":
			draw_circle(p.call(12,12),9.5*s,c)
			draw_arc(p.call(12,12),6.5*s,0,TAU,24,Color("#fbf6ea"),w*.8,true)
			draw_line(p.call(5.5,12),p.call(18.5,12),Color("#fbf6ea"),w*.8)
		"ovo":
			var egg=PackedVector2Array()
			for i in 32:
				var a=TAU*i/32.0
				var r=Vector2(7,9.5)
				if sin(a)<0:r.y=10.5
				egg.append(p.call(12+cos(a)*r.x,12.5+sin(a)*r.y*.95))
			draw_colored_polygon(egg,c)
		"paleta":
			draw_arc(p.call(12,12),9*s,deg_to_rad(40),deg_to_rad(330),24,c,w*1.3,true)
			for pt in [[8,8],[13,6.5],[17,9.5],[7.5,13.5]]:draw_circle(p.call(pt[0],pt[1]),1.7*s,c)
		"chapeu":
			draw_colored_polygon(PackedVector2Array([p.call(5,15),p.call(6,9),p.call(12,6),p.call(18,9),p.call(19,15)]),c)
			draw_rect(Rect2(p.call(2,15),Vector2(20,3)*s),c)
		"seta":
			draw_polyline(PackedVector2Array([p.call(6,9),p.call(12,15),p.call(18,9)]),c,w*1.2,true)
		"broto":
			draw_line(p.call(12,21),p.call(12,10),c,w,true)
			draw_colored_polygon(PackedVector2Array([p.call(12,12),p.call(5,9),p.call(4,4),p.call(10,6)]),c)
			draw_colored_polygon(PackedVector2Array([p.call(12,10),p.call(19,7),p.call(20,2),p.call(14,4)]),c)
			draw_rect(Rect2(p.call(5,20),Vector2(14,2.5)*s),c)
		"alerta":
			draw_colored_polygon(PackedVector2Array([p.call(12,2.5),p.call(22,20.5),p.call(2,20.5)]),c)
			draw_rect(Rect2(p.call(11,9),Vector2(2,6)*s),Color("#fbf6ea"))
			draw_rect(Rect2(p.call(11,16.5),Vector2(2,2)*s),Color("#fbf6ea"))
		"fechar":
			draw_line(p.call(5,5),p.call(19,19),c,w*1.2,true)
			draw_line(p.call(19,5),p.call(5,19),c,w*1.2,true)
		_:
			draw_circle(p.call(12,12),4*s,c)
