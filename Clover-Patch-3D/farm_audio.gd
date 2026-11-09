extends Node
## Music and sound effects. Players are authored as child nodes in effects/farm_audio.tscn.

enum Effect {
	GRASS_STEP, WOOD_STEP, TILL, PLANT, WATER, HARVEST, MENU, SLEEP, EAT, TRADE,
	FISHING_CAST, FISHING_BITE, FISHING_CATCH, FRUIT_PLUCK,
}

const METERS_PER_STEP := 0.88

var distance_to_next_step := METERS_PER_STEP

@onready var music: AudioStreamPlayer = $Music
@onready var players: Dictionary[Effect, AudioStreamPlayer] = {
	Effect.GRASS_STEP: $GrassStep, Effect.WOOD_STEP: $WoodStep, Effect.TILL: $Till,
	Effect.PLANT: $Plant, Effect.WATER: $Water, Effect.HARVEST: $Harvest, Effect.MENU: $Menu,
	Effect.SLEEP: $Sleep, Effect.EAT: $Eat, Effect.TRADE: $Trade, Effect.FISHING_CAST: $FishingCast,
	Effect.FISHING_BITE: $FishingBite, Effect.FISHING_CATCH: $FishingCatch, Effect.FRUIT_PLUCK: $FruitPluck,
}


func _exit_tree() -> void:
	music.stop()
	for player in players.values():
		player.stop()


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
