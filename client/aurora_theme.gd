extends RefCounted

# Paleta do caderno de campo de Aurora (mockups do gerador de imagens):
# pergaminho claro, trilho lateral azul-noite e ações em laranja.
const PAPER = Color("#efe5d1")
const CARD = Color("#fbf6ea")
const INK = Color("#132733")
const NIGHT = Color("#0f2230")
const PETROL = Color("#18323f")
const TEAL = Color("#1d6b5c")
const CORAL = Color("#e2553b")
const CORAL_DARK = Color("#b23a24")
const MINT = Color("#90debe")
const LINE = Color("#cfc1a4")
const MUTED = Color("#5d6763")
const GREEN = Color("#3aa36b")
const SKY = Color("#2f8fd0")
const GOLD = Color("#e7b443")

static var _display:Font
static var _spaced:Font

static func display_font()->Font:
	if _display==null:
		var base=load("res://assets/fonts/Oswald.ttf") as FontFile
		var variation=FontVariation.new()
		variation.base_font=base
		variation.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):600}
		var fallback=SystemFont.new()
		fallback.font_names=PackedStringArray(["Bahnschrift","Segoe UI","Arial"])
		variation.fallbacks=[fallback]
		_display=variation
	return _display

static func spaced_font()->Font:
	if _spaced==null:
		var variation=FontVariation.new()
		variation.base_font=display_font()
		variation.spacing_glyph=5
		_spaced=variation
	return _spaced

static func surface(color:Color, radius:int=9, border:Color=Color("#315460"), width:int=1) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	style.border_color=border
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=10
	style.content_margin_bottom=10
	style.anti_aliasing=radius>0
	return style

# Botão com "degrau" inferior, como os botões em relevo do mockup.
static func raised(color:Color, border:Color, step:Color, radius:int=8, depth:int=4)->StyleBoxFlat:
	var style=surface(color,radius,border,2)
	style.border_width_bottom=depth
	style.border_color=border
	style.shadow_color=Color(step,0.35)
	style.shadow_size=0
	style.content_margin_bottom=10-depth+2
	return style

static func primary(button:Button):
	button.add_theme_stylebox_override("normal",raised(CORAL,CORAL_DARK,CORAL_DARK))
	button.add_theme_stylebox_override("hover",raised(Color("#ec6a4f"),CORAL_DARK,CORAL_DARK))
	button.add_theme_stylebox_override("pressed",raised(CORAL_DARK,Color("#8f2c1a"),CORAL_DARK,8,2))
	button.add_theme_stylebox_override("disabled",raised(Color("#d9a497"),Color("#c08a7d"),CORAL_DARK))
	for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		button.add_theme_color_override(state,Color.WHITE)
	button.add_theme_color_override("font_disabled_color",Color("#fff3ee"))
	button.add_theme_color_override("icon_normal_color",Color.WHITE)
	button.add_theme_color_override("icon_hover_color",Color.WHITE)
	button.add_theme_color_override("icon_pressed_color",Color.WHITE)
	button.add_theme_color_override("icon_focus_color",Color.WHITE)

static func make(font:Font, light:bool=false)->Theme:
	var theme=Theme.new()
	theme.default_font=font
	theme.default_font_size=20
	var text_color=INK if light else CARD
	var border=Color("#8b7f68") if light else Color("#50727a")
	for kind in ["Button","OptionButton","MenuButton","ColorPickerButton"]:
		if light:
			theme.set_stylebox("normal",kind,raised(Color("#f7f0e1"),border,border))
			theme.set_stylebox("hover",kind,raised(Color("#fffaf0"),Color("#5f5646"),border))
			theme.set_stylebox("pressed",kind,raised(Color("#e9dfca"),Color("#5f5646"),border,8,2))
			theme.set_stylebox("disabled",kind,raised(Color("#ebe4d6"),Color("#c4b9a3"),border))
		else:
			theme.set_stylebox("normal",kind,raised(PETROL,Color("#3e5f69"),NIGHT))
			theme.set_stylebox("hover",kind,raised(Color("#234652"),MINT,NIGHT))
			theme.set_stylebox("pressed",kind,raised(Color("#2b6063"),MINT,NIGHT,8,2))
			theme.set_stylebox("disabled",kind,raised(Color("#152934"),Color("#2b4652"),NIGHT))
		var focus=surface(Color.TRANSPARENT,9,CORAL if light else MINT)
		focus.set_border_width_all(3)
		theme.set_stylebox("focus",kind,focus)
		for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
			theme.set_color(state,kind,text_color)
		for state in ["icon_normal_color","icon_focus_color","icon_hover_color","icon_pressed_color"]:
			theme.set_color(state,kind,text_color)
		theme.set_color("font_disabled_color",kind,Color("#8c877b") if light else Color("#7f949b"))
	for kind in ["LineEdit","TextEdit","SpinBox"]:
		theme.set_stylebox("normal",kind,surface(CARD if light else INK,8,border,2))
		theme.set_stylebox("focus",kind,surface(CARD if light else INK,8,CORAL if light else MINT,2))
		theme.set_stylebox("read_only",kind,surface(Color("#ece5d6") if light else INK,8,LINE,2))
		theme.set_color("font_color",kind,text_color)
		theme.set_color("caret_color",kind,text_color)
		theme.set_color("font_placeholder_color",kind,Color("#7d7a70") if light else Color("#adc3c4"))
	theme.set_color("font_color","Label",text_color)
	theme.set_stylebox("panel","PopupMenu",surface(CARD if light else INK,8,border,2))
	theme.set_color("font_color","PopupMenu",text_color)
	theme.set_color("font_hover_color","PopupMenu",Color.WHITE)
	theme.set_stylebox("hover","PopupMenu",surface(CORAL,6,CORAL))
	theme.set_stylebox("panel","PopupPanel",surface(CARD if light else INK,10,border,2))
	theme.set_stylebox("panel","TooltipPanel",surface(INK,6,INK))
	theme.set_color("font_color","TooltipLabel",CARD)
	var grabber=surface(Color("#b5a789"),6,Color("#b5a789"))
	theme.set_stylebox("grabber","VScrollBar",grabber)
	theme.set_stylebox("grabber_highlight","VScrollBar",surface(CORAL,6,CORAL))
	theme.set_stylebox("scroll","VScrollBar",surface(Color("#e4d9c3"),6,Color("#e4d9c3")))
	return theme
