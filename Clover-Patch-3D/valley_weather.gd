extends CPUParticles3D

enum Kind { CLEAR, RAIN, SNOW }

const Catalog := preload("res://crop_catalog.gd")
const NAMES := ["Clear", "Rain", "Snow"]

var kind := Kind.CLEAR


static func forecast(day: int) -> Kind:
	# Deterministic by calendar date so forecasts survive saving and reloading.
	if posmod(day * 3 + (day - 1) / Catalog.DAYS_PER_SEASON, 7) not in [1, 2]:
		return Kind.CLEAR
	return Kind.SNOW if Catalog.season_for(day) == Catalog.Season.WINTER else Kind.RAIN


func _ready() -> void:
	emitting = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	amount = 230
	lifetime = 1.15
	emission_shape = EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(7.0, 0.6, 7.0)
	direction = Vector3(0.14, -1.0, 0.04)
	local_coords = false
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var drop := BoxMesh.new()
	drop.material = material
	mesh = drop


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
