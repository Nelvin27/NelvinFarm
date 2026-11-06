extends Node3D

const ResidentHouse := preload("res://resident_house.gd")
const FarmMesh := preload("res://farm_mesh.gd")
const WorldLayout := preload("res://world_layout.gd")
const Terrain := preload("res://terrain_mesh.gd")
const Details := preload("res://valley_details.gd")
const SEASON_GROUND := ["#94b871", "#8ba965", "#b39964", "#d0d8d3"]
const Voxels := preload("res://voxel_assets.gd")

var ground: MeshInstance3D
var damaged_roof: Node3D
var repaired_roof: Node3D
var cottage_door: Vector3
var repair_sign: Vector3
var food_counter: Vector3
var market_area: Rect2
var obstacles: Array[Rect2] = []


func rebuild(layout: WorldLayout, preview := false) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	obstacles.clear()
	layout.refresh_mountains()
	_ground_patch(layout.bounds.grow(2.0), -0.31, 0.56, "#ffffff", Voxels.SOIL)
	if layout.mountains.is_empty():
		ground = _ground_patch(layout.bounds, -0.11, 0.25, SEASON_GROUND[0], Voxels.GRASS)
	else:
		ground = Terrain.surface(self, layout, layout.bounds, 0.015, Voxels.GRASS, SEASON_GROUND[0], Voxels.SOIL)
	for entity in layout.entities:
		_build_entity(layout, entity, preview)


func _build_entity(layout: WorldLayout, entity: Dictionary, preview: bool) -> void:
	var authored := WorldLayout.position_of(entity)
	var at := layout.grounded(authored)
	var size: Array = entity.get("size", [1.0, 1.0])
	var area := Rect2(Vector2(at.x, at.z) - Vector2(size[0], size[1]) * 0.5, Vector2(size[0], size[1]))
	match entity["kind"]:
		"grass":
			FarmMesh.tile(self, at, Vector3(1, 0.11, 1), Voxels.GRASS, entity.get("color", "#98b572"))
		"path":
			if layout.mountains.is_empty():
				_ground_patch(area, at.y, 0.012, "#ffffff", Voxels.PATH)
			else:
				Terrain.surface(self, layout, area, maxf(authored.y, 0.035) + 0.006, Voxels.PATH, "#ffffff")
		"pond":
			_build_pond(area, at.y)
			for index in range(2):
				_add_wildlife(at + Vector3.UP * 0.065, area.size * (0.25 + index * 0.07),
					false, 2.5 + index * 6.0)
		"ridge_barrier":
			obstacles.append(area)
		"closed_pass":
			obstacles.append(Details.closed_pass(self, at))
		"picnic":
			obstacles.append(Details.picnic(self, at))
		"bunting":
			Details.bunting(self, at)
		"butterflies":
			for index in range(3):
				_add_wildlife(at + Vector3.UP * (1.0 + index * 0.23),
					Vector2(1.15 + index * 0.28, 0.85 + index * 0.22), true, index * 1.8 + at.x + 100.0)
		"plot":
			if preview:
				FarmMesh.tile(self, at + Vector3.UP * 0.042, Vector3(0.97, 0.15, 0.97), Voxels.SOIL)
		"fence":
			_build_fence(at, float(entity.get("length", 1.0)), float(entity.get("yaw", 0.0)))
		"tree", "apple_tree":
			Voxels.tree(self, at, float(entity.get("scale", 1.0)), entity["kind"] == "apple_tree")
		"purple_flower", "yellow_flower":
			var tint := "#a87fb9" if entity["kind"] == "purple_flower" else "#ddbd64"
			Voxels.flower(self, at, float(entity.get("scale", 0.65)), tint)
		"sign":
			_place_signpost(at)
		"lamp":
			FarmMesh.box(self, at + Vector3.UP * 0.65, Vector3(0.16, 1.3, 0.16), "#665044")
			FarmMesh.box(self, at + Vector3.UP * 1.39, Vector3(0.27, 0.29, 0.27), "#ebbd6e", true)
			FarmMesh.box(self, at + Vector3.UP * 1.57, Vector3(0.35, 0.09, 0.35), "#635044")
			FarmMesh.box(self, at + Vector3.UP * 1.22, Vector3(0.34, 0.09, 0.34), "#635044")
		"resident_house":
			obstacles.append(ResidentHouse.build(self, at, entity))
		"cottage":
			_build_cottage(at)
		"seed_market":
			_build_market_stall(at)
		"bakery":
			_build_food_stall(at)
		"spawn":
			if preview:
				_place_signpost(at)


func _add_wildlife(at: Vector3, radius: Vector2, flight: bool, phase: float) -> void:
	var animal := Details.new()
	add_child(animal)
	animal.populate(at, radius, flight, phase)


func _build_pond(area: Rect2, height: float) -> void:
	obstacles.append(area)
	_ground_patch(area.grow(0.38), height + 0.019, 0.028, "#e1d0b3", Voxels.PATH)
	_ground_patch(area, height + 0.037, 0.018, "#ffffff", Voxels.WATER)
	for index in range(7):
		var x := area.position.x + area.size.x * (0.09 + index * 0.1314)
		var ripples_z := area.position.y + area.size.y * (0.25 + sin(index * 3.0) * 0.13)
		var lilies_z := area.position.y + area.size.y * (0.70 + cos(index * 2.0) * 0.12)
		FarmMesh.box(self, Vector3(x, height + 0.05, ripples_z), Vector3(0.38, 0.012, 0.035), "#94bcb7")
		FarmMesh.box(self, Vector3(x, height + 0.065, lilies_z), Vector3(0.32, 0.035, 0.24), "#6c935b")


func _build_fence(at: Vector3, length: float, yaw: float) -> void:
	var fence := Node3D.new()
	fence.position = at
	fence.rotation_degrees.y = yaw
	add_child(fence)
	var segments := maxi(1, ceili(length))
	for post in range(segments + 1):
		var x := lerpf(-length * 0.5, length * 0.5, float(post) / segments)
		FarmMesh.box(fence, Vector3(x, 0.23, 0), Vector3(0.12, 0.48, 0.16), "#fff0cb")
	FarmMesh.box(fence, Vector3(0, 0.19, 0), Vector3(length, 0.10, 0.10), "#ebcda0")
	var size := Vector2(0.16, length) if is_equal_approx(absf(yaw), 90.0) else Vector2(length, 0.16)
	obstacles.append(Rect2(Vector2(at.x, at.z) - size * 0.5, size))


func set_ground_season(season: int) -> void:
	var surface := ground.get_active_material(0) as StandardMaterial3D
	surface.albedo_color = Color(SEASON_GROUND[season])


func show_cottage_repair() -> void:
	damaged_roof.hide()
	repaired_roof.show()


func _ground_patch(area: Rect2, y: float, height: float, color: String, texture: Texture2D) -> MeshInstance3D:
	var center := area.get_center()
	return FarmMesh.tile(self, Vector3(center.x, y, center.y), Vector3(area.size.x, height, area.size.y), texture, color)


func _place_signpost(at: Vector3) -> void:
	FarmMesh.box(self, at + Vector3.UP * 0.42, Vector3(0.12, 0.84, 0.12), "#8b6750")
	FarmMesh.box(self, at + Vector3.UP * 0.79, Vector3(0.48, 0.24, 0.09), "#ad8960")


func _build_cottage(at: Vector3) -> void:
	var house := Node3D.new()
	house.position = at
	cottage_door = at + Vector3(0, 0, 2.9)
	repair_sign = at + Vector3(3.8, 0, 2.7)
	obstacles.append(Rect2(at.x - 3.2, at.z - 2.7, 6.4, 5.4))
	add_child(house)
	FarmMesh.box(house, Vector3(0, 0.05, 0), Vector3(6.4, 0.10, 5.4), "#78543d")
	for side in [-1.0, 1.0]:
		FarmMesh.tile(house, Vector3(side * 3.12, 1.04, 0),
			Vector3(0.16, 2.08, 5.4), Voxels.WOOD)
		FarmMesh.tile(house, Vector3(0, 1.04, side * 2.62),
			Vector3(6.4, 2.08, 0.16), Voxels.WOOD)
		for end in [-1.0, 1.0]:
			FarmMesh.box(house, Vector3(side * 3.15, 1.07, end * 2.64),
				Vector3(0.20, 2.14, 0.20), "#544231")
	for row in range(1, 6):
		FarmMesh.box(house, Vector3(0, row * 0.32, 2.704),
			Vector3(6.3, 0.022, 0.018), "#876647")
	FarmMesh.box(house, Vector3(0, 0.87, 2.74), Vector3(1.24, 1.74, 0.12), "#78543d")
	FarmMesh.box(house, Vector3(0, 0.87, 2.82), Vector3(1.03, 1.59, 0.08), "#544231")
	FarmMesh.box(house, Vector3(0.32, 0.86, 2.88), Vector3(0.10, 0.10, 0.10), "#bda16a")
	FarmMesh.box(house, Vector3(0, 0.08, 2.91), Vector3(1.50, 0.14, 0.52), "#917c69")
	FarmMesh.box(house, Vector3(2.44, 2.45, -2.26), Vector3(0.36, 1.18, 0.36), "#62564b")

	damaged_roof = Node3D.new()
	house.add_child(damaged_roof)
	_build_roof(damaged_roof, true)
	var brace := FarmMesh.box(damaged_roof, Vector3(0.48, 1.37, -2.77),
		Vector3(1.32, 0.16, 0.07), "#544231")
	brace.rotation.z = 0.34
	FarmMesh.box(damaged_roof, Vector3(0.48, 1.4, -2.73), Vector3(1.15, 0.65, 0.05), "#40332b")

	repaired_roof = Node3D.new()
	house.add_child(repaired_roof)
	_build_roof(repaired_roof, false)
	FarmMesh.box(repaired_roof, Vector3(0.48, 1.4, -2.73), Vector3(1.15, 0.65, 0.06), "#82adad")
	FarmMesh.box(repaired_roof, Vector3(0.48, 1.4, -2.77), Vector3(0.075, 0.68, 0.055), "#544231")
	FarmMesh.box(repaired_roof, Vector3(0, 0.16, 3.04), Vector3(1.30, 0.025, 0.24), "#758a54")
	repaired_roof.hide()
	_place_signpost(repair_sign)


func _build_roof(roof: Node3D, damaged: bool) -> void:
	for side in [-1.0, 1.0]:
		for step in range(5):
			var x: float = side * (3.14 - step * 0.65)
			var y := 2.13 + step * 0.24
			if damaged:
				for strip in range(4):
					if (strip + step + int(side)) % 3 != 0:
						FarmMesh.tile(roof, Vector3(x, y, -2.15 + strip * 1.43),
							Vector3(0.67, 0.25, 1.34), Voxels.ROOF, "#c7aaa2")
			else:
				FarmMesh.tile(roof, Vector3(x, y, 0), Vector3(0.67, 0.25, 5.75), Voxels.ROOF)
	if not damaged:
		FarmMesh.tile(roof, Vector3(0, 3.32, 0), Vector3(0.48, 0.25, 5.75), Voxels.ROOF)


func _build_food_stall(at: Vector3) -> void:
	var stall := Node3D.new()
	stall.position = at
	food_counter = at
	obstacles.append(Rect2(at.x - 0.54, at.z - 0.38, 1.08, 0.76))
	add_child(stall)
	FarmMesh.tile(stall, Vector3(0, 0.38, 0), Vector3(1.25, 0.72, 0.82), Voxels.WOOD, "#dfc7ad")
	FarmMesh.box(stall, Vector3(0, 0.79, 0), Vector3(1.40, 0.12, 0.92), "#b78e64")
	for side in [-1.0, 1.0]:
		FarmMesh.box(stall, Vector3(side * 0.62, 1.10, -0.34), Vector3(0.10, 0.78, 0.10), "#765449")
	for stripe in range(5):
		var color := "#cba878" if stripe % 2 == 0 else "#799069"
		FarmMesh.box(stall, Vector3((stripe - 2) * 0.31, 1.51, 0.0),
			Vector3(0.31, 0.13, 1.08), color)
	for loaf in range(3):
		FarmMesh.box(stall, Vector3((loaf - 1) * 0.35, 0.90, 0.03),
			Vector3(0.25, 0.16, 0.31), "#c99d64")
	_place_signpost(at + Vector3(-0.92, 0, 0))


func _build_market_stall(at: Vector3) -> void:
	var stall := Node3D.new()
	stall.position = at
	market_area = Rect2(at.x + 0.32, at.z - 1.6, 2.0, 3.0)
	add_child(stall)
	FarmMesh.tile(stall, Vector3(0, 0.36, 0), Vector3(0.86, 0.70, 1.45), Voxels.WOOD)
	FarmMesh.box(stall, Vector3(0, 0.72, 0), Vector3(0.96, 0.10, 1.55), "#bb8a64")
	for side in [-1.0, 1.0]:
		FarmMesh.box(stall, Vector3(-0.31, 1.03, side * 0.64), Vector3(0.10, 0.75, 0.10), "#765549")
	for stripe in range(5):
		var color := "#d3b795" if stripe % 2 == 0 else "#a76761"
		FarmMesh.box(stall, Vector3(0, 1.43, (stripe - 2) * 0.32), Vector3(1.04, 0.13, 0.32), color)
