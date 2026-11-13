extends Node
## Music and sound effects. Players are authored as child nodes in effects/farm_audio.tscn.

enum Effect {
	GRASS_STEP, WOOD_STEP, TILL, PLANT, WATER, HARVEST, MENU, SLEEP, EAT, TRADE,
	FISHING_CAST, FISHING_BITE, FISHING_CATCH, FRUIT_PLUCK, RUSTLE, BELL, SPLASH, QUACK, CHIME,
}

const METERS_PER_STEP := 0.88
## One theme per season, in Catalog.Season order. Composed in tools/audio/make_music.py.
const SEASON_MUSIC: Array[AudioStream] = [
	preload("res://assets/audio/spring.ogg"), preload("res://assets/audio/summer.ogg"),
	preload("res://assets/audio/fall.ogg"), preload("res://assets/audio/winter.ogg"),
]
const MUSIC_FADE := 1.2

var distance_to_next_step := METERS_PER_STEP
var _fade: Tween

@onready var music: AudioStreamPlayer = $Music
@onready var players: Dictionary[Effect, AudioStreamPlayer] = {
	Effect.GRASS_STEP: $GrassStep, Effect.WOOD_STEP: $WoodStep, Effect.TILL: $Till,
	Effect.PLANT: $Plant, Effect.WATER: $Water, Effect.HARVEST: $Harvest, Effect.MENU: $Menu,
	Effect.SLEEP: $Sleep, Effect.EAT: $Eat, Effect.TRADE: $Trade, Effect.FISHING_CAST: $FishingCast,
	Effect.FISHING_BITE: $FishingBite, Effect.FISHING_CATCH: $FishingCatch, Effect.FRUIT_PLUCK: $FruitPluck,
	Effect.RUSTLE: $Rustle, Effect.BELL: $Bell, Effect.SPLASH: $Splash, Effect.QUACK: $Quack, Effect.CHIME: $Chime,
}


func _exit_tree() -> void:
	music.stop()
	for player in players.values():
		player.stop()


## Plays the season's theme. A change of season fades the old theme out and the new one in.
func play_season(season: int, instant := false) -> void:
	var track := SEASON_MUSIC[clampi(season, 0, SEASON_MUSIC.size() - 1)]
	(track as AudioStreamOggVorbis).loop = true
	if music.stream == track and music.playing:
		return
	if _fade != null:
		_fade.kill()
	if instant or not music.playing:
		music.stream = track
		music.volume_db = 0.0
		music.play()
		return
	_fade = create_tween()
	_fade.tween_property(music, "volume_db", -40.0, MUSIC_FADE)
	_fade.tween_callback(func() -> void:
		music.stream = track
		music.play())
	_fade.tween_property(music, "volume_db", 0.0, MUSIC_FADE)


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
