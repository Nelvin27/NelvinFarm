extends RefCounted

const FILE_PATH := "user://clover_settings.cfg"
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 2.5
const MIN_BRIGHTNESS := 0.65
const MAX_BRIGHTNESS := 1.35
const RENDER_HEIGHTS := [720, 900, 1080]
const MSAA_MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

var sensitivity := 1.0
var invert_y := false
var brightness := 1.0
var fullscreen := false
var render_height := 1080
var shadows := true
var msaa := Viewport.MSAA_DISABLED
var vsync := true
var master_volume := 0.85
var music_volume := 0.45
var effects_volume := 0.75


func reset() -> void:
	sensitivity = 1.0
	invert_y = false
	brightness = 1.0
	fullscreen = false
	reset_graphics()
	reset_audio()


func reset_graphics() -> void:
	render_height = 1080
	shadows = true
	msaa = Viewport.MSAA_DISABLED
	vsync = true


func reset_audio() -> void:
	master_volume = 0.85
	music_volume = 0.45
	effects_volume = 0.75


func read_config(path := FILE_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return error
	sensitivity = clampf(float(config.get_value("camera", "sensitivity", 1.0)),
		MIN_SENSITIVITY, MAX_SENSITIVITY)
	invert_y = bool(config.get_value("camera", "invert_y", false))
	brightness = clampf(float(config.get_value("display", "brightness", 1.0)),
		MIN_BRIGHTNESS, MAX_BRIGHTNESS)
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	var stored_height := int(config.get_value("graphics", "render_height", 1080))
	render_height = stored_height if stored_height in RENDER_HEIGHTS else 1080
	var stored_msaa := int(config.get_value("graphics", "msaa", Viewport.MSAA_DISABLED))
	msaa = stored_msaa as Viewport.MSAA if stored_msaa in MSAA_MODES else Viewport.MSAA_DISABLED
	shadows = bool(config.get_value("graphics", "shadows", true))
	vsync = bool(config.get_value("graphics", "vsync", true))
	master_volume = clampf(float(config.get_value("audio", "master", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music", 0.45)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value("audio", "effects", 0.75)), 0.0, 1.0)
	return OK


func write_config(path := FILE_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("camera", "sensitivity", sensitivity)
	config.set_value("camera", "invert_y", invert_y)
	config.set_value("display", "brightness", brightness)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("graphics", "render_height", render_height)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "msaa", msaa)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "effects", effects_volume)
	return config.save(path)
