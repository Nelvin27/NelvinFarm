extends CPUParticles3D
## Rain and snow. Base particle settings are authored on the Weather node in farm.tscn.

enum Kind { CLEAR, RAIN, SNOW }

const Catalog := preload("res://crop_catalog.gd")
const NAMES := ["Clear", "Rain", "Snow"]

var kind := Kind.CLEAR


static func forecast(day: int) -> Kind:
	# Deterministic by calendar date so forecasts survive saving and reloading.
	if posmod(day * 3 + (day - 1) / Catalog.DAYS_PER_SEASON, 7) not in [1, 2]:
		return Kind.CLEAR
	return Kind.SNOW if Catalog.season_for(day) == Catalog.Season.WINTER else Kind.RAIN


func apply(next: Kind, outdoors: bool) -> void:
	if kind != next:
		kind = next
		var rain := kind == Kind.RAIN
		var drop := mesh as BoxMesh
		drop.size = Vector3(0.012, 0.24, 0.012) if rain else Vector3(0.058, 0.058, 0.058)
		(drop.material as StandardMaterial3D).albedo_color = Color("#a4c4ce") if rain else Color("#ecf4f1")
		spread = 3.0 if rain else 18.0
		initial_velocity_min = 7.5 if rain else 2.8
		initial_velocity_max = 9.5 if rain else 3.8
		gravity = Vector3(0, -4.0, 0) if rain else Vector3(0.6, -0.3, 0.0)
		lifetime = 0.94 if rain else 2.5
		restart()
	visible = outdoors and kind != Kind.CLEAR
	emitting = visible
