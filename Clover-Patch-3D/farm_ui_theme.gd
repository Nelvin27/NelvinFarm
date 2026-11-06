extends RefCounted

const PAPER := Color("#fff0cf")
const INK := Color("#33271f")
const MOSS := Color("#334c38")
const GOLD := Color("#e6b665")

static var _menu_theme: Theme
static var _hud_theme: Theme


static func box(fill: Color, rim: Color, radius: int, padding: Vector2, depth := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = rim
	style.set_border_width_all(2)
	style.border_width_bottom += depth
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	return style


static func menu() -> Theme:
	if _menu_theme == null:
		_menu_theme = _build_theme(false)
	return _menu_theme


static func hud() -> Theme:
	if _hud_theme == null:
		_hud_theme = _build_theme(true)
	return _hud_theme


static func _build_theme(dark: bool) -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	var heading := SystemFont.new()
	heading.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	heading.font_weight = 700
	theme.set_type_variation("FarmHeading", "Label")
	theme.set_font("font", "FarmHeading", heading)
	theme.set_color("font_color", "Label", PAPER if dark else INK)
	var panel := box(Color("#263c2d") if dark else PAPER,
		Color("#738353") if dark else Color("#b5804c"), 18, Vector2(23, 16) if dark else Vector2(32, 26), 4)
	panel.shadow_color = Color("#160e0966")
	panel.shadow_size = 8
	panel.shadow_offset = Vector2(0, 5)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var normal := box(MOSS if dark else Color("#f4dcb1"),
		Color("#627959") if dark else Color("#c69b68"), 10, Vector2(13, 5), 2)
	var hover := box(Color("#4d6646") if dark else Color("#ffe6ac"),
		GOLD if dark else Color("#a66e33"), 10, Vector2(13, 5), 2)
	var pressed := box(GOLD, Color("#9c682d"), 10, Vector2(13, 5), 2)
	var disabled := box(Color("#ded0ae"), Color("#c8b798"), 10, Vector2(13, 5))
	var focus := box(Color.TRANSPARENT, Color("#fff0b3") if dark else Color("#3b6947"), 10, Vector2.ZERO)
	focus.draw_center = false
	focus.set_border_width_all(3)
	for type in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			theme.set_color(state, type, PAPER if dark else INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_disabled_color", type, Color("#675c49"))

	theme.set_stylebox("panel", "PopupMenu", box(PAPER, Color("#b5804c"), 10, Vector2(7, 7)))
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("slider", "HSlider", box(Color("#d4ba94"), Color("#a88056"), 5, Vector2(0, 5)))
	var level := box(Color("#668650"), MOSS, 5, Vector2(0, 5))
	theme.set_stylebox("grabber_area", "HSlider", level)
	theme.set_stylebox("grabber_area_highlight", "HSlider", level)
	return theme
