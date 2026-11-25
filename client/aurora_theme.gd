extends RefCounted

const PAPER = Color("#f5edde")
const CARD = Color("#fff9ed")
const INK = Color("#112d38")
const PETROL = Color("#153a44")
const TEAL = Color("#116759")
const CORAL = Color("#b64229")
const MINT = Color("#90debe")

static func surface(color:Color, radius:int=9, border:Color=Color("#315460")) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color=border
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style

static func primary(button:Button):
	button.add_theme_stylebox_override("normal",surface(CORAL,8,CORAL))
	button.add_theme_stylebox_override("hover",surface(Color("#963622"),8,CORAL))
	button.add_theme_stylebox_override("pressed",surface(Color("#812e20"),8,CORAL))
	for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:
		button.add_theme_color_override(state,Color.WHITE)

static func make(font:Font, light:bool=false)->Theme:
	var theme=Theme.new()
	theme.default_font=font
	theme.default_font_size=20
	var text_color=INK if light else CARD
	var border=Color("#a79e8a") if light else Color("#50727a")
	for kind in ["Button","OptionButton"]:
		theme.set_stylebox("normal",kind,surface(Color("#eee4d2") if light else PETROL,8,border))
		theme.set_stylebox("hover",kind,surface(Color("#d0e9dd") if light else Color("#285661"),8,TEAL))
		theme.set_stylebox("pressed",kind,surface(Color("#b8d6c9") if light else Color("#2b6063"),8,TEAL))
		theme.set_stylebox("disabled",kind,surface(Color("#e6e0d3") if light else Color("#182f38"),8,border))
		var focus=surface(Color.TRANSPARENT,8,TEAL if light else MINT)
		focus.set_border_width_all(3)
		theme.set_stylebox("focus",kind,focus)
		for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
			theme.set_color(state,kind,text_color)
		theme.set_color("font_disabled_color",kind,Color("#66675e") if light else Color("#a0b6bd"))
	for kind in ["LineEdit","TextEdit"]:
		theme.set_stylebox("normal",kind,surface(CARD if light else INK,6,border))
		theme.set_stylebox("focus",kind,surface(CARD if light else INK,6,TEAL))
		theme.set_color("font_color",kind,text_color)
		theme.set_color("caret_color",kind,text_color)
		theme.set_color("font_placeholder_color",kind,Color("#5d6c69") if light else Color("#adc3c4"))
	theme.set_color("font_color","Label",text_color)
	theme.set_stylebox("panel","PopupMenu",surface(INK))
	return theme
