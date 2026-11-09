extends CanvasLayer
## Pause, settings, graphics, and audio screens. Layout and signal wiring live in ui/pause_menu.tscn.

signal resume_requested
signal settings_changed
signal save_requested

const Settings := preload("res://game_settings.gd")
const ActionMenu := preload("res://action_menu.gd")

var settings: Settings

@onready var backdrop: ColorRect = %Backdrop
@onready var pause_menu: ActionMenu = %PauseMenu
@onready var options_menu: ActionMenu = %OptionsMenu
@onready var graphics_menu: ActionMenu = %GraphicsMenu
@onready var audio_menu: ActionMenu = %AudioMenu
@onready var save_status: Label = %SaveStatus
@onready var sensitivity: HSlider = %Sensitivity
@onready var sensitivity_value: Label = %SensitivityValue
@onready var brightness: HSlider = %Brightness
@onready var brightness_value: Label = %BrightnessValue
@onready var invert_y: CheckButton = %InvertY
@onready var fullscreen: CheckButton = %Fullscreen
@onready var render_resolution: OptionButton = %RenderResolution
@onready var antialiasing: OptionButton = %Antialiasing
@onready var shadows: CheckButton = %Shadows
@onready var vsync: CheckButton = %VSync
@onready var master_slider: HSlider = %MasterVolume
@onready var music_slider: HSlider = %MusicVolume
@onready var effects_slider: HSlider = %EffectsVolume
@onready var master_value: Label = %MasterVolumeValue
@onready var music_value: Label = %MusicVolumeValue
@onready var effects_value: Label = %EffectsVolumeValue


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
