extends Control

signal slot_requested(index: int)
signal bag_requested
signal journal_requested
signal pause_requested
signal interact_requested

const UISkin := preload("res://farm_ui_theme.gd")

var tool_label: Label
var crop_label: Label
var hunger_meter: ProgressBar
var fatigue_meter: ProgressBar
var needs_label: Label
var stats_label: Label
var stock_label: Label
var interaction_prompt: Button
var location_label: Label

const AlmanacIcon := preload("res://almanac_icon.gd")
const Bag := preload("res://inventory_grid.gd")
const Weather := preload("res://valley_weather.gd")

var _clock: AlmanacIcon
var _weather: AlmanacIcon
var _period: Label
var _slots: Array[Button] = []
var _quantities: Array[Label] = []
var _cursor_hint: Label
var _toast: PanelContainer
var _toast_text: Label
var _toast_timer: Timer
var _current_prompt := ""


func build() -> void:
	theme = UISkin.hud()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var place := _dock(Control.PRESET_TOP_LEFT)
	_label(place, "CLOVER PATCH", 18).add_theme_color_override("font_color", UISkin.GOLD)
	location_label = _label(place, "Clover Valley", 33, true)
	_cursor_hint = _label(place, "Tab  ·  Free cursor", 18)

	var almanac := _dock(Control.PRESET_TOP_RIGHT)
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 14)
	almanac.add_child(date_row)
	_clock = AlmanacIcon.new()
	_clock.custom_minimum_size = Vector2(68, 68)
	date_row.add_child(_clock)
	var date_details := VBoxContainer.new()
	date_details.size_flags_horizontal = SIZE_EXPAND_FILL
	date_details.alignment = BoxContainer.ALIGNMENT_CENTER
	date_row.add_child(date_details)
	stats_label = _label(date_details, "", 29, true)
	_period = _label(date_details, "", 17)
	_weather = AlmanacIcon.new()
	_weather.face = AlmanacIcon.Face.WEATHER
	_weather.custom_minimum_size = Vector2(44, 44)
	_weather.size_flags_vertical = SIZE_SHRINK_CENTER
	date_row.add_child(_weather)
	stock_label = _label(almanac, "", 21)
	var rule := HSeparator.new()
	almanac.add_child(rule)
	hunger_meter = _meter(almanac, "Food", Color("#9ab977"))
	fatigue_meter = _meter(almanac, "Fatigue", Color("#d4a472"))
	needs_label = _label(almanac, "", 18)

	var belt := _dock(Control.PRESET_CENTER_BOTTOM)
	tool_label = _label(belt, "", 22, true)
	tool_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shortcuts := HBoxContainer.new()
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	shortcuts.add_theme_constant_override("separation", 8)
	belt.add_child(shortcuts)
	var hotbar := HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	belt.add_child(hotbar)
	belt.move_child(hotbar, shortcuts.get_index())
	for index in range(Bag.ROW_SIZE):
		var button := _button(hotbar, "", slot_requested.emit.bind(index))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(60, 56)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 42)
		_slots.append(button)
		var count := Label.new()
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 16)
		count.add_theme_color_override("font_color", Color.WHITE)
		count.add_theme_color_override("font_outline_color", UISkin.INK)
		count.add_theme_constant_override("outline_size", 6)
		button.add_child(count)
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -5
		count.offset_bottom = -3
		_quantities.append(count)
	_button(shortcuts, "I  Bag", bag_requested.emit)
	_button(shortcuts, "J  Journal", journal_requested.emit)
	_button(shortcuts, "Esc  Pause", pause_requested.emit)

	var action := VBoxContainer.new()
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action.alignment = BoxContainer.ALIGNMENT_END
	add_child(action)
	action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	action.offset_top = -318
	action.offset_bottom = -224
	crop_label = _label(action, "", 22)
	crop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crop_label.add_theme_color_override("font_outline_color", UISkin.INK)
	crop_label.add_theme_constant_override("outline_size", 9)
	interaction_prompt = _button(action, "", interact_requested.emit)
	interaction_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	interaction_prompt.hide()

	var notice := _dock(Control.PRESET_BOTTOM_LEFT)
	_toast = notice.get_parent() as PanelContainer
	_label(notice, "FIELD NOTES", 17).add_theme_color_override("font_color", UISkin.GOLD)
	_toast_text = _label(notice, "", 20)
	_toast_text.custom_minimum_size.x = 390
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_toast.hide)
	add_child(_toast_timer)
	_toast.hide()


func show_notice(message: String) -> void:
	if _toast_text.text == message:
		return
	_toast_text.text = message
	_toast.show()
	_toast_timer.start(6.0)


func set_almanac(date: String, hour: float, weather: Weather.Kind) -> void:
	stats_label.text = date
	_period.text = "AM" if fposmod(hour, 24.0) < 12.0 else "PM"
	if _clock.hour != hour:
		_clock.hour = hour
		_clock.queue_redraw()
	if _weather.weather != weather or _weather.tooltip_text.is_empty():
		_weather.weather = weather
		_weather.tooltip_text = Weather.NAMES[weather]
		_weather.queue_redraw()


func set_hotbar(bag: Bag, selected: int, held_tool: String) -> void:
	var stack := bag.stack_at(selected)
	var item := stack.title if stack != null else "Empty slot"
	if stack != null and stack.kind == Bag.Kind.TOOL and stack.equipped:
		item = held_tool
	else:
		item += "  ·  Holding " + held_tool
	tool_label.text = "%s  ·  Wheel to select  ·  F to use" % item
	for index in range(_slots.size()):
		stack = bag.stack_at(index)
		_slots[index].icon = stack.texture if stack != null else null
		_slots[index].tooltip_text = stack.title if stack != null else "Empty slot"
		_slots[index].set_pressed_no_signal(index == selected)
		_quantities[index].text = str(stack.quantity) if stack != null and stack.quantity > 1 else ""


func set_cursor_available(available: bool) -> void:
	_cursor_hint.text = "Tab  ·  Return to camera" if available else "Tab  ·  Free cursor"


func set_prompt(caption: String, can_interact: bool) -> void:
	crop_label.visible = not crop_label.text.is_empty()
	if _current_prompt == caption and interaction_prompt.visible == (not caption.is_empty()):
		return
	_current_prompt = caption
	interaction_prompt.text = caption
	interaction_prompt.disabled = not can_interact
	interaction_prompt.visible = not caption.is_empty()


func _dock(preset: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var inset := Vector2(0, -30)
	match preset:
		Control.PRESET_TOP_LEFT: inset = Vector2(30, 28)
		Control.PRESET_TOP_RIGHT: inset = Vector2(-30, 28)
		Control.PRESET_BOTTOM_LEFT: inset = Vector2(30, -30)
	_pin(panel, preset, inset)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 5)
	panel.add_child(rows)
	return rows


func _pin(control: Control, preset: int, inset: Vector2) -> void:
	control.set_anchors_and_offsets_preset(preset)
	match preset:
		Control.PRESET_TOP_RIGHT:
			control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_BOTTOM_LEFT:
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			control.grow_horizontal = Control.GROW_DIRECTION_BOTH
			control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control.offset_left += inset.x
	control.offset_right += inset.x
	control.offset_top += inset.y
	control.offset_bottom += inset.y


func _label(parent: Container, caption: String, size: int, heading := false) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", size)
	if heading:
		label.theme_type_variation = &"FarmHeading"
	parent.add_child(label)
	return label


func _button(parent: Container, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 52
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _meter(parent: VBoxContainer, caption: String, fill: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label(row, caption, 19)
	label.custom_minimum_size.x = 78
	var meter := ProgressBar.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.custom_minimum_size = Vector2(218, 24)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.add_theme_stylebox_override("background", UISkin.box(Color("#17281d"), Color("#58694c"), 7, Vector2.ZERO))
	meter.add_theme_stylebox_override("fill", UISkin.box(fill, fill.darkened(0.25), 7, Vector2.ZERO))
	meter.add_theme_color_override("font_color", Color.WHITE)
	meter.add_theme_color_override("font_outline_color", UISkin.INK)
	meter.add_theme_constant_override("outline_size", 5)
	meter.add_theme_font_size_override("font_size", 16)
	row.add_child(meter)
	return meter
