extends RefCounted

static var frame_texture:ImageTexture

static func illustrated_panel(tint:Color=Color.WHITE)->StyleBoxTexture:
	if frame_texture==null:
		var source=load("res://assets/ui/trainer-frame.png") as Texture2D
		var pixels=source.get_image().get_region(Rect2i(20,20,1496,984))
		# Sample the generated master onto the game's 2x pixel grid once.
		pixels.resize(96,64,Image.INTERPOLATE_NEAREST)
		pixels.resize(192,128,Image.INTERPOLATE_NEAREST)
		frame_texture=ImageTexture.create_from_image(pixels)
	var s=StyleBoxTexture.new();s.texture=frame_texture;s.set_texture_margin_all(18)
	s.modulate_color=tint
	s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=10;s.content_margin_bottom=10
	return s

static func surface(color:Color,radius:int=4)->StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color;s.set_corner_radius_all(radius);s.set_border_width_all(2)
	s.border_color=Color("30425b")
	s.content_margin_left=14;s.content_margin_right=14;s.content_margin_top=10;s.content_margin_bottom=10
	return s

static func make(font:Font)->Theme:
	var t=Theme.new();t.default_font=font;t.default_font_size=15
	for kind in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var colors={"normal":"1c2b42","hover":"304966","pressed":"126478","disabled":"151d2d","focus":"263d59"}
			var style=surface(Color(colors[state]))
			if state=="focus":style.border_color=Color("75e6ee");style.bg_color.a=0
			t.set_stylebox(state,kind,style)
		t.set_color("font_color",kind,Color("edf2fa"));t.set_color("font_hover_color",kind,Color.WHITE)
		t.set_color("font_disabled_color",kind,Color("75859c"))
	for kind in ["LineEdit","TextEdit"]:
		t.set_stylebox("normal",kind,surface(Color("0b1424")))
		var focus=surface(Color("102139"));focus.border_color=Color("64d9e5");t.set_stylebox("focus",kind,focus)
		t.set_color("font_color",kind,Color("edf2fa"))
	t.set_color("font_color","Label",Color("edf2fa"))
	t.set_stylebox("panel","PopupMenu",surface(Color("172237")))
	t.set_stylebox("background","ProgressBar",surface(Color("08101f"),2))
	var fill=surface(Color("71dca2"),2);fill.set_border_width_all(0);t.set_stylebox("fill","ProgressBar",fill)
	return t
