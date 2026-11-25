extends RefCounted

static func wire(button:Button):
	button.mouse_entered.connect(func():animate(button,Color("c4f5ff"),.12))
	button.mouse_exited.connect(func():animate(button,Color.WHITE,.16))
	button.focus_entered.connect(func():animate(button,Color("c4f5ff"),.12))
	button.focus_exited.connect(func():animate(button,Color.WHITE,.16))
	button.button_down.connect(func():animate(button,Color("d6e0db"),.06))
	button.button_up.connect(func():animate(button,Color.WHITE,.12))

static func animate(node:Control,color:Color,duration:float):
	if node.has_meta("motion"):
		var previous=node.get_meta("motion") as Tween
		if previous and previous.is_valid():previous.kill()
	var tween=node.create_tween();node.set_meta("motion",tween)
	tween.tween_property(node,"self_modulate",color,duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func reveal(node:Control,content:Control):
	var origin=content.position
	content.position.x+=18
	content.create_tween().tween_property(content,"position",origin,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	node.modulate.a=0
	node.create_tween().tween_property(node,"modulate:a",1.0,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
