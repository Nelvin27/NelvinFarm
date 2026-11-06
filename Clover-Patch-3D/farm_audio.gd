extends Node

enum Effect {
	GRASS_STEP, WOOD_STEP, TILL, PLANT, WATER, HARVEST, MENU, SLEEP, EAT, TRADE,
	FISHING_CAST, FISHING_BITE, FISHING_CATCH, FRUIT_PLUCK,
}

const THEME := preload("res://assets/audio/clover_theme.ogg")
const EFFECTS: Dictionary[Effect, AudioStream] = {
	Effect.GRASS_STEP: preload("res://assets/audio/step_grass.wav"),
	Effect.WOOD_STEP: preload("res://assets/audio/step_wood.wav"),
	Effect.TILL: preload("res://assets/audio/till.wav"),
	Effect.PLANT: preload("res://assets/audio/plant.wav"),
	Effect.WATER: preload("res://assets/audio/water.wav"),
	Effect.HARVEST: preload("res://assets/audio/harvest.wav"),
	Effect.MENU: preload("res://assets/audio/menu.wav"),
	Effect.SLEEP: preload("res://assets/audio/sleep.wav"),
	Effect.EAT: preload("res://assets/audio/eat.wav"),
	Effect.TRADE: preload("res://assets/audio/trade.wav"),
	Effect.FISHING_CAST: preload("res://assets/audio/fishing_cast.wav"),
	Effect.FISHING_BITE: preload("res://assets/audio/fishing_bite.wav"),
	Effect.FISHING_CATCH: preload("res://assets/audio/fishing_catch.wav"),
	Effect.FRUIT_PLUCK: preload("res://assets/audio/fruit_pluck.wav"),
}
const METERS_PER_STEP := 0.88

var music: AudioStreamPlayer
var players: Dictionary[Effect, AudioStreamPlayer] = {}
var distance_to_next_step := METERS_PER_STEP


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var loop := THEME.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	music = _make_player(loop, &"Music")
	for effect in EFFECTS:
		players[effect] = _make_player(EFFECTS[effect], &"SFX")
		players[effect].max_polyphony = 2


func _exit_tree() -> void:
	music.stop()
	for player in players.values():
		player.stop()


func _make_player(stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player


func play_effect(effect: Effect, pitch := 1.0) -> void:
	var player := players[effect]
	player.pitch_scale = pitch
	player.play()


func walk(distance: float, indoors: bool) -> void:
	if distance <= 0.0:
		distance_to_next_step = METERS_PER_STEP
		return
	distance_to_next_step -= distance
	if distance_to_next_step <= 0.0:
		play_effect(Effect.WOOD_STEP if indoors else Effect.GRASS_STEP, randf_range(0.94, 1.06))
		distance_to_next_step = METERS_PER_STEP + fmod(distance_to_next_step, METERS_PER_STEP)


func apply_mix(master: float, music_volume: float, effects_volume: float) -> void:
	_set_bus(&"Master", master)
	_set_bus(&"Music", music_volume)
	_set_bus(&"SFX", effects_volume)


func _set_bus(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
