extends CanvasLayer

signal resume_requested
signal settings_changed
signal save_requested

const Settings := preload("res://game_settings.gd")
const ActionMenu := preload("res://action_menu.gd")
const UISkin := preload("res://farm_ui_theme.gd")
const MENU_SCENE := preload("res://action_menu.tscn")

var settings: Settings
var pause_menu: ActionMenu
var save_status: Label
var options_menu: ActionMenu
var graphics_menu: ActionMenu
var audio_menu: ActionMenu
var master_slider: HSlider
var music_slider: HSlider
var effects_slider: HSlider
var master_value := Label.new()
var music_value := Label.new()
var effects_value := Label.new()
var render_resolution: OptionButton
var antialiasing: OptionButton
var shadows: CheckButton
var vsync: CheckButton
var backdrop: ColorRect
var sensitivity: HSlider
var brightness: HSlider
var invert_y: CheckButton
var fullscreen: CheckButton
var sensitivity_value: Label
var brightness_value: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	backdrop = ColorRect.new()
	backdrop.color = Color(0.07, 0.11, 0.10, 0.66)
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.hide()

	pause_menu = _new_menu("Taking a breather")
	pause_menu.offset_top = -112
	pause_menu.offset_bottom = 112
	pause_menu.add_action("Resume farming", resume_requested.emit)
	pause_menu.add_action("Settings", _show_options)
	pause_menu.add_action("Save farm", save_requested.emit)
	save_status = Label.new()
	save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_menu.rows.add_child(save_status)

	options_menu = _new_menu("Settings")
	sensitivity_value = Label.new()
	sensitivity = _slider(options_menu, "Mouse sensitivity", Settings.MIN_SENSITIVITY,
		Settings.MAX_SENSITIVITY, sensitivity_value)
	sensitivity.value_changed.connect(_change_sensitivity)
	invert_y = _toggle(options_menu, "Invert vertical look")
	invert_y.toggled.connect(_change_invert_y)
	brightness_value = Label.new()
	brightness = _slider(options_menu, "Brightness", Settings.MIN_BRIGHTNESS,
		Settings.MAX_BRIGHTNESS, brightness_value)
	brightness.value_changed.connect(_change_brightness)
	fullscreen = _toggle(options_menu, "Fullscreen")
	fullscreen.toggled.connect(_change_fullscreen)
	options_menu.add_action("Graphics", _show_graphics)
	options_menu.add_action("Audio", _show_audio)
	options_menu.add_action("Restore defaults", _restore_defaults)
	options_menu.add_action("Back", _show_pause)
	_build_graphics_menu()
	_build_audio_menu()


func _input(event: InputEvent) -> void:
	if not backdrop.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if graphics_menu.visible or audio_menu.visible:
		_show_options()
	elif options_menu.visible:
		_show_pause()
	else:
		resume_requested.emit()


func open(current: Settings) -> void:
	settings = current
	save_status.text = ""
	backdrop.show()
	_show_pause()


func close() -> void:
	pause_menu.hide()
	options_menu.hide()
	graphics_menu.hide()
	audio_menu.hide()
	backdrop.hide()


func _new_menu(caption: String) -> ActionMenu:
	var menu := MENU_SCENE.instantiate() as ActionMenu
	add_child(menu)
	menu.theme = UISkin.menu()
	menu.title.text = caption
	return menu


func _slider(menu: ActionMenu, caption: String, minimum: float, maximum: float, value_label: Label) -> HSlider:
	var row := HBoxContainer.new()
	menu.rows.add_child(row)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	value_label.add_theme_font_size_override("font_size", 22)
	row.add_child(value_label)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 0.05
	control.custom_minimum_size.y = 28
	menu.rows.add_child(control)
	return control


func _toggle(menu: ActionMenu, caption: String) -> CheckButton:
	var control := CheckButton.new()
	control.text = caption
	control.add_theme_font_size_override("font_size", 22)
	control.custom_minimum_size.y = 44
	menu.rows.add_child(control)
	return control


func _show_pause() -> void:
	graphics_menu.hide()
	options_menu.hide()
	pause_menu.show()
	pause_menu.focus_first_action()


func _show_options() -> void:
	graphics_menu.hide()
	audio_menu.hide()
	_sync_options()
	pause_menu.hide()
	options_menu.show()
	sensitivity.grab_focus()


func _sync_options() -> void:
	sensitivity.set_value_no_signal(settings.sensitivity)
	brightness.set_value_no_signal(settings.brightness)
	invert_y.set_pressed_no_signal(settings.invert_y)
	fullscreen.set_pressed_no_signal(settings.fullscreen)
	_update_values()


func _update_values() -> void:
	sensitivity_value.text = "%d%%" % roundi(settings.sensitivity * 100)
	brightness_value.text = "%d%%" % roundi(settings.brightness * 100)


func _change_sensitivity(value: float) -> void:
	settings.sensitivity = value
	_update_values()
	settings_changed.emit()


func _change_brightness(value: float) -> void:
	settings.brightness = value
	_update_values()
	settings_changed.emit()


func _change_invert_y(value: bool) -> void:
	settings.invert_y = value
	settings_changed.emit()


func _change_fullscreen(value: bool) -> void:
	settings.fullscreen = value
	settings_changed.emit()


func _restore_defaults() -> void:
	settings.reset()
	_sync_options()
	settings_changed.emit()


func _build_graphics_menu() -> void:
	graphics_menu = _new_menu("Graphics")
	render_resolution = _graphics_choice("3D resolution")
	for height: int in Settings.RENDER_HEIGHTS:
		render_resolution.add_item("%dp" % height, height)
	render_resolution.item_selected.connect(_change_resolution)

	antialiasing = _graphics_choice("Anti-aliasing")
	antialiasing.add_item("Off", Viewport.MSAA_DISABLED)
	antialiasing.add_item("2× MSAA", Viewport.MSAA_2X)
	antialiasing.add_item("4× MSAA", Viewport.MSAA_4X)
	antialiasing.item_selected.connect(_change_antialiasing)

	shadows = _toggle(graphics_menu, "Sun shadows")
	shadows.toggled.connect(_change_shadows)
	vsync = _toggle(graphics_menu, "VSync")
	vsync.toggled.connect(_change_vsync)
	graphics_menu.add_action("Restore graphics defaults", _restore_graphics)
	graphics_menu.add_action("Back", _show_options)


func _graphics_choice(caption: String) -> OptionButton:
	var row := HBoxContainer.new()
	graphics_menu.rows.add_child(row)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var choice := OptionButton.new()
	choice.custom_minimum_size = Vector2(170, 44)
	row.add_child(choice)
	return choice


func _show_graphics() -> void:
	_sync_graphics()
	options_menu.hide()
	graphics_menu.show()
	render_resolution.grab_focus()


func _sync_graphics() -> void:
	render_resolution.select(render_resolution.get_item_index(settings.render_height))
	antialiasing.select(antialiasing.get_item_index(settings.msaa))
	shadows.set_pressed_no_signal(settings.shadows)
	vsync.set_pressed_no_signal(settings.vsync)


func _change_resolution(index: int) -> void:
	settings.render_height = render_resolution.get_item_id(index)
	settings_changed.emit()


func _change_antialiasing(index: int) -> void:
	settings.msaa = antialiasing.get_item_id(index) as Viewport.MSAA
	settings_changed.emit()


func _change_shadows(value: bool) -> void:
	settings.shadows = value
	settings_changed.emit()


func _change_vsync(value: bool) -> void:
	settings.vsync = value
	settings_changed.emit()


func _restore_graphics() -> void:
	settings.reset_graphics()
	_sync_graphics()
	settings_changed.emit()


func _build_audio_menu() -> void:
	audio_menu = _new_menu("Audio")
	master_slider = _slider(audio_menu, "Master volume", 0.0, 1.0, master_value)
	music_slider = _slider(audio_menu, "Music volume", 0.0, 1.0, music_value)
	effects_slider = _slider(audio_menu, "Sound effects", 0.0, 1.0, effects_value)
	master_slider.value_changed.connect(_change_audio)
	music_slider.value_changed.connect(_change_audio)
	effects_slider.value_changed.connect(_change_audio)
	audio_menu.add_action("Restore audio defaults", _restore_audio)
	audio_menu.add_action("Back", _show_options)


func _show_audio() -> void:
	_sync_audio()
	options_menu.hide()
	audio_menu.show()
	master_slider.grab_focus()


func _sync_audio() -> void:
	master_slider.set_value_no_signal(settings.master_volume)
	music_slider.set_value_no_signal(settings.music_volume)
	effects_slider.set_value_no_signal(settings.effects_volume)
	_update_audio_values()


func _update_audio_values() -> void:
	master_value.text = "%d%%" % roundi(settings.master_volume * 100)
	music_value.text = "%d%%" % roundi(settings.music_volume * 100)
	effects_value.text = "%d%%" % roundi(settings.effects_volume * 100)


func _change_audio(_value: float) -> void:
	settings.master_volume = master_slider.value
	settings.music_volume = music_slider.value
	settings.effects_volume = effects_slider.value
	_update_audio_values()
	settings_changed.emit()


func _restore_audio() -> void:
	settings.reset_audio()
	_sync_audio()
	settings_changed.emit()
