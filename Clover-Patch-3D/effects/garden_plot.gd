extends Node3D
## One garden bed. Soil and furrows are authored in garden_plot.tscn; the crop model is
## rebuilt from the crop catalog because its shape depends on the crop and growth stage.

const Voxels := preload("res://voxel_assets.gd")

const UNTILLED := Color("#ffffff")
const TILLED := Color("#ddc5b3")
const WATERED := Color("#998474")

@onready var _soil: StandardMaterial3D = $Soil.material_override
@onready var _furrows: Node3D = $Furrows
@onready var _crop: Node3D = $Crop


func show_soil(tilled: bool, watered: bool) -> void:
	_soil.albedo_color = WATERED if watered else (TILLED if tilled else UNTILLED)
	_furrows.visible = tilled


func show_crop(id: int, tint: String, size: float, ripe: bool) -> void:
	clear_crop()
	Voxels.crop(_crop, id, tint, size, ripe)


func clear_crop() -> void:
	for mesh in _crop.get_children():
		_crop.remove_child(mesh)
		mesh.queue_free()
