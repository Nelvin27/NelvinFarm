extends Node3D

const ResidentHouse := preload("res://resident_house.gd")
const FarmMesh := preload("res://farm_mesh.gd")
const WorldLayout := preload("res://world_layout.gd")
const Terrain := preload("res://terrain_mesh.gd")
const Details := preload("res://valley_details.gd")
const SEASON_GROUND := ["#94b871", "#8ba965", "#b39964", "#d0d8d3"]
const Voxels := preload("res://voxel_assets.gd")
const VoxelBatch := preload("res://voxel_batch.gd")
## Leaf colors per season for the four canopy parts (the trunk keeps its color).
const SEASON_LEAVES := [
	["#54834c", "#679351", "#7ea258", "#8aaa61"],
	["#4b7a43", "#5e8a48", "#749a50", "#82a35a"],
	["#9a5a2c", "#c1702f", "#d4913f", "#e0b25a"],
	["#6f8277", "#b9c6c1", "#dde6e3", "#f3f7f5"],
]
const SNOW := "#f4f7f6"

var ground: MeshInstance3D
var damaged_roof: Node3D
var repaired_roof: Node3D
var cottage_door: Vector3
var repair_sign: Vector3
var food_counter: Vector3
var market_area: Rect2
var shipping_bin: Vector3
var orchard_fruit: Dictionary[Vector3, Node3D] = {}
var fishing_spots: Array[Vector3] = []
var obstacles: Array[Rect2] = []
var picnic_spots: Array[Vector3] = []
var closed_passes: Array[Vector3] = []
var wildlife: Array[Details] = []
var resident_doors: Dictionary = {}
## Parallel to fishing_spots: what bites there ("perch", "trout", "carp") and the rare-catch chance.
var fishing_waters: Array[Dictionary] = []
## Forage spots in map order: {"at": authored position, "item": "berries"|"mushroom"|"shell", "goods": Node3D}.
var forage_spots: Array[Dictionary] = []
## World interactables, filled while building (see valley_interactions.gd).
var signs: Array[Dictionary] = []          # {"at": Vector3, "text": String}
var tree_spots: Array[Vector3] = []        # parallel to the tree batch's instances
var bush_spots: Array[Vector3] = []        # parallel to the bush batch's instances
var ponds: Array[Dictionary] = []          # {"area": Rect2, "ducks": Array[Details]}
var dig_spots: Array[Dictionary] = []      # {"at": authored Vector3, "sparkle": Node3D}
var landmarks: Array[Dictionary] = []      # {"at": Vector3, "name": String, "radius": float}
var well := Vector3.INF
var bell := Vector3.INF
var bell_body: Node3D
var _snow_caps: Array[Node3D] = []
var _apple_leaves: Array[MeshInstance3D] = []
var _lamp_glow: StandardMaterial3D
var _lamp_pools: Array[Vector3] = []
var _puddles: MultiMeshInstance3D
## Plain trees and flowers are batched into MultiMeshes; apple trees stay nodes so fruit can toggle.
var _trees: VoxelBatch
var _flowers: VoxelBatch
var _bushes: VoxelBatch
var _rocks: VoxelBatch
var _tufts: VoxelBatch


func rebuild(layout: WorldLayout) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	obstacles.clear()
	picnic_spots.clear()
	closed_passes.clear()
	wildlife.clear()
	resident_doors.clear()
	orchard_fruit.clear()
	fishing_spots.clear()
	fishing_waters.clear()
	forage_spots.clear()
	signs.clear()
	tree_spots.clear()
	bush_spots.clear()
	ponds.clear()
	dig_spots.clear()
	landmarks.clear()
	well = Vector3.INF
	bell = Vector3.INF
	_snow_caps.clear()
	_apple_leaves.clear()
	_lamp_pools.clear()
	layout.refresh_mountains()
	_ground_patch(layout.bounds.grow(2.0), -0.31, 0.56, "#ffffff", Voxels.SOIL)
	if layout.mountains.is_empty():
		ground = _ground_patch(layout.bounds, -0.11, 0.25, SEASON_GROUND[0], Voxels.GRASS)
	else:
		ground = Terrain.surface(self, layout, layout.bounds, 0.015, Voxels.GRASS, SEASON_GROUND[0], Voxels.SOIL)
	_trees = VoxelBatch.new(Voxels.TREE_PARTS, "Trees")
	_flowers = VoxelBatch.new(Voxels.FLOWER_PARTS, "Flowers")
	_bushes = VoxelBatch.new(Voxels.BUSH_PARTS, "Bushes")
	_rocks = VoxelBatch.new(Voxels.ROCK_PARTS, "Rocks")
	_tufts = VoxelBatch.new(Voxels.TUFT_PARTS, "Tufts")
	for entity in layout.entities:
		_build_entity(layout, entity)
	for batch: VoxelBatch in [_trees, _flowers, _bushes, _rocks, _tufts]:
		batch.build(self)
	_build_lamp_pools()
	_build_puddles(layout)


func _build_entity(layout: WorldLayout, entity: Dictionary) -> void:
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
			fishing_waters.append({"fish": str(entity.get("fish", "perch")), "rare": float(entity.get("rare", 0.0))})
			var ducks: Array[Details] = []
			for index in range(2):
				ducks.append(_add_wildlife(at + Vector3.UP * 0.065, area.size * (0.25 + index * 0.07),
					false, 2.5 + index * 6.0))
			ponds.append({"area": area, "ducks": ducks})
		"stream":
			_build_stream(area, at.y)
		"bridge":
			_build_bridge(at, area, entity)
		"well":
			_build_well(at)
		"bell":
			_build_bell(at)
		"dig":
			_build_dig_spot(at, authored)
		"ruin":
			_build_ruin(at, float(entity.get("yaw", 0.0)))
		"floodgate":
			_build_floodgate(at)
		"landmark":
			landmarks.append({"at": at, "name": str(entity.get("name", "Landmark")), "radius": float(entity.get("radius", 4.0))})
		"ridge_barrier":
			obstacles.append(area)
		"closed_pass":
			obstacles.append(Details.closed_pass(self, at))
			closed_passes.append(at + Vector3.RIGHT * 1.3)
		"picnic":
			obstacles.append(Details.picnic(self, at))
			picnic_spots.append(at)
		"bunting":
			Details.bunting(self, at)
		"butterflies":
			for index in range(3):
				_add_wildlife(at + Vector3.UP * (1.0 + index * 0.23),
					Vector2(1.15 + index * 0.28, 0.85 + index * 0.22), true, index * 1.8 + at.x + 100.0)
		"fence":
			_build_fence(at, float(entity.get("length", 1.0)), float(entity.get("yaw", 0.0)))
		"tree":
			_trees.add(at, float(entity.get("scale", 1.0)))
			tree_spots.append(at)
		"apple_tree":
			var fruit := Voxels.tree(self, at, float(entity.get("scale", 1.0)), true)
			orchard_fruit[authored] = fruit
			for index in range(1, Voxels.TREE_PARTS.size()):
				_apple_leaves.append(fruit.get_parent().get_child(index) as MeshInstance3D)
		"forage":
			_build_forage(at, authored, str(entity.get("item", "berries")))
		"bush", "rock", "tuft":
			var batch: VoxelBatch = {"bush": _bushes, "rock": _rocks, "tuft": _tufts}[entity["kind"]]
			if entity["kind"] == "bush":
				bush_spots.append(at)
			batch.add(at, float(entity.get("scale", 1.0)), Color(entity.get("color", "#6f9a57")),
				float(entity.get("yaw", 0.0)))
		"purple_flower", "yellow_flower":
			var tint := "#a87fb9" if entity["kind"] == "purple_flower" else "#ddbd64"
			_flowers.add(at, float(entity.get("scale", 0.65)), Color(tint))
		"sign":
			_place_signpost(at)
			signs.append({"at": at, "text": str(entity.get("text", entity.get("label", "")))})
		"lamp":
			FarmMesh.box(self, at + Vector3.UP * 0.65, Vector3(0.16, 1.3, 0.16), "#665044")
			FarmMesh.box(self, at + Vector3.UP * 1.39, Vector3(0.27, 0.29, 0.27), "#ebbd6e", true)
			FarmMesh.box(self, at + Vector3.UP * 1.57, Vector3(0.35, 0.09, 0.35), "#635044")
			FarmMesh.box(self, at + Vector3.UP * 1.22, Vector3(0.34, 0.09, 0.34), "#635044")
			_lamp_pools.append(at)
		"resident_house":
			obstacles.append(ResidentHouse.build(self, at, entity, resident_doors))
			_add_house_snow(at, int(entity.get("style", 0)))
		"cottage":
			_build_cottage(at)
		"seed_market":
			_build_market_stall(at)
		"bakery":
			_build_food_stall(at)


func _add_wildlife(at: Vector3, radius: Vector2, flight: bool, phase: float) -> Details:
	var animal := Details.new()
	add_child(animal)
	animal.populate(at, radius, flight, phase)
	wildlife.append(animal)
	return animal


func update_wildlife(delta: float) -> void:
	for animal in wildlife:
		animal.advance(delta)


func _build_pond(area: Rect2, height: float) -> void:
	obstacles.append(area)
	var spot := Vector3(area.get_center().x, height, area.position.y - 0.65)
	fishing_spots.append(spot)
	FarmMesh.tile(self, spot + Vector3.UP * 0.04, Vector3(1.3, 0.13, 1.16), Voxels.WOOD)
	_place_signpost(spot + Vector3(0.85, 0, -0.22))
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


func set_season(season: int) -> void:
	var surface := ground.get_active_material(0) as StandardMaterial3D
	surface.albedo_color = Color(SEASON_GROUND[season])
	var leaves: Array = SEASON_LEAVES[season]
	for index in range(leaves.size()):
		_trees.set_part_color(index + 1, Color(leaves[index]))
		if index < 3:
			_bushes.set_part_color(index + 1, Color(leaves[index]))
	_tufts.set_visible(season != 3)
	for index in range(_apple_leaves.size()):
		(_apple_leaves[index].material_override as StandardMaterial3D).albedo_color = Color(leaves[index % leaves.size()])
	_flowers.set_visible(season != 3)
	for cap in _snow_caps:
		cap.visible = season == 3


## 0 in daylight, 1 at full night: lantern light pools fade in on the ground.
func set_night(amount: float) -> void:
	if _lamp_glow != null:
		_lamp_glow.albedo_color.a = clampf(amount, 0.0, 1.0)
		_lamp_glow.albedo_color.a *= 0.85


func set_wet(wet: bool) -> void:
	if _puddles != null:
		_puddles.visible = wet


func set_forage_visible(index: int, available: bool) -> void:
	forage_spots[index].goods.visible = available


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
	var cottage_snow := Node3D.new()
	repaired_roof.add_child(cottage_snow)
	for side in [-1.0, 1.0]:
		for step in range(5):
			FarmMesh.box(cottage_snow, Vector3(side * (3.14 - step * 0.65), 2.27 + step * 0.24, 0),
				Vector3(0.69, 0.045, 5.79), SNOW)
	FarmMesh.box(cottage_snow, Vector3(0, 3.46, 0), Vector3(0.5, 0.045, 5.79), SNOW)
	cottage_snow.hide()
	_snow_caps.append(cottage_snow)
	FarmMesh.box(repaired_roof, Vector3(0.48, 1.4, -2.73), Vector3(1.15, 0.65, 0.06), "#82adad")
	FarmMesh.box(repaired_roof, Vector3(0.48, 1.4, -2.77), Vector3(0.075, 0.68, 0.055), "#544231")
	FarmMesh.box(repaired_roof, Vector3(0, 0.16, 3.04), Vector3(1.30, 0.025, 0.24), "#758a54")
	repaired_roof.hide()
	_place_signpost(repair_sign)
	_build_shipping_bin(cottage_door + Vector3(-2.45, 0, 0.7))


func _build_shipping_bin(at: Vector3) -> void:
	shipping_bin = at
	obstacles.append(Rect2(at.x - 0.55, at.z - 0.36, 1.1, 0.72))
	FarmMesh.tile(self, at + Vector3.UP * 0.28, Vector3(1.1, 0.56, 0.72), Voxels.WOOD)
	FarmMesh.box(self, at + Vector3.UP * 0.57, Vector3(1.16, 0.10, 0.78), "#664531")
	_place_signpost(at + Vector3(0, 0, -0.38))


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


func _build_forage(at: Vector3, authored: Vector3, item: String) -> void:
	var spot := Node3D.new()
	spot.position = at
	add_child(spot)
	var goods := Node3D.new()
	spot.add_child(goods)
	match item:
		"berries":
			FarmMesh.box(spot, Vector3(0, 0.2, 0), Vector3(0.62, 0.4, 0.55), "#4f7a3c")
			FarmMesh.box(spot, Vector3(0.05, 0.43, -0.02), Vector3(0.44, 0.16, 0.4), "#6b9450")
			for berry in [Vector3(-0.22, 0.32, 0.26), Vector3(0.12, 0.42, 0.22), Vector3(0.26, 0.24, 0.12),
					Vector3(-0.05, 0.5, -0.12), Vector3(-0.26, 0.2, -0.16)]:
				FarmMesh.box(goods, berry, Vector3(0.09, 0.09, 0.09), "#5b4fa8")
		"mushroom":
			for cap in [Vector3(0, 0, 0), Vector3(0.22, 0, 0.12), Vector3(-0.17, 0, 0.16)]:
				var height := 0.14 if cap.x == 0 else 0.1
				FarmMesh.box(goods, cap + Vector3(0, height * 0.5, 0), Vector3(0.06, height, 0.06), "#f1d9a2")
				FarmMesh.box(goods, cap + Vector3(0, height + 0.02, 0), Vector3(0.17, 0.05, 0.17), "#e08a2c")
		_:
			FarmMesh.box(goods, Vector3(0, 0.03, 0), Vector3(0.22, 0.05, 0.2), "#f2dcc3")
			FarmMesh.box(goods, Vector3(0, 0.06, 0), Vector3(0.04, 0.02, 0.2), "#e7a99a")
			FarmMesh.box(goods, Vector3(0.07, 0.06, 0), Vector3(0.03, 0.02, 0.18), "#e7a99a")
	forage_spots.append({"at": authored, "item": item, "goods": goods})


func _add_house_snow(at: Vector3, style: int) -> void:
	# Mirrors the stepped roof in resident_house.gd: a thin snow slab on every roof layer.
	var width := 3.35 + (style % 2) * 0.34
	var cap := Node3D.new()
	cap.position = at
	add_child(cap)
	for level in range(4):
		FarmMesh.box(cap, Vector3(0, 2.275 + level * 0.22, 0),
			Vector3(width + 0.3 - level * 0.84, 0.04, 2.8 + 0.4), SNOW)
	cap.hide()
	_snow_caps.append(cap)


func _build_lamp_pools() -> void:
	if _lamp_pools.is_empty():
		return
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.82, 0.48, 0.75))
	gradient.set_color(1, Color(1.0, 0.7, 0.35, 0.0))
	var falloff := GradientTexture2D.new()
	falloff.gradient = gradient
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(1.0, 0.5)
	_lamp_glow = StandardMaterial3D.new()
	_lamp_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lamp_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lamp_glow.albedo_texture = falloff
	_lamp_glow.albedo_color = Color(1, 1, 1, 0)
	var pool := PlaneMesh.new()
	pool.size = Vector2(4.6, 4.6)
	pool.material = _lamp_glow
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = pool
	batch.instance_count = _lamp_pools.size()
	for index in range(_lamp_pools.size()):
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, _lamp_pools[index] + Vector3.UP * 0.07))
	var node := MultiMeshInstance3D.new()
	node.name = "LampGlow"
	node.multimesh = batch
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_puddles(layout: WorldLayout) -> void:
	# Rain puddles on level road strips, placed by a fixed hash so they never move between runs.
	var spots: Array[Transform3D] = []
	for entity in layout.entities:
		if entity["kind"] != "path":
			continue
		var center := WorldLayout.position_of(entity)
		var size: Array = entity.get("size", [1.0, 1.0])
		var count := int(float(size[0]) * float(size[1]) / 14.0)
		for index in range(count):
			var key := absi(hash([center.x, center.z, index]))
			var x: float = center.x + (float(key % 1000) / 1000.0 - 0.5) * (float(size[0]) - 0.9)
			var z: float = center.z + (float(key / 1000 % 1000) / 1000.0 - 0.5) * (float(size[1]) - 0.7)
			if layout.elevation(Vector2(x, z)) != 0.0:
				continue
			var scale := Vector3(0.45 + float(key % 7) * 0.07, 1.0, 0.45 + float(key % 5) * 0.07)
			spots.append(Transform3D(Basis.from_scale(scale), Vector3(x, 0.052, z)))
	if spots.is_empty():
		return
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.45, 0.5, 0.55)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 1.0
	_puddles = MultiMeshInstance3D.new()
	_puddles.name = "Puddles"
	_puddles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puddles.hide()
	add_child(_puddles)
	# Two overlapping slabs per puddle round off the corners.
	for footprint in [Vector3(1.0, 0.012, 0.6), Vector3(0.66, 0.014, 0.94)]:
		var slab := BoxMesh.new()
		slab.size = footprint
		slab.material = water
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = slab
		batch.instance_count = spots.size()
		for index in range(spots.size()):
			batch.set_instance_transform(index, spots[index])
		var layer := MultiMeshInstance3D.new()
		layer.multimesh = batch
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_puddles.add_child(layer)


func _build_stream(area: Rect2, height: float) -> void:
	obstacles.append(area)
	_ground_patch(area.grow(0.22), height + 0.019, 0.028, "#d9c9ab", Voxels.PATH)
	_ground_patch(area, height + 0.037, 0.018, "#e8f4ff", Voxels.WATER)
	# Light streaks drifting along the current.
	var along_x := area.size.x > area.size.y
	var length := maxf(area.size.x, area.size.y)
	for index in range(int(length / 1.7)):
		var t := (index + 0.5) / maxf(1.0, floorf(length / 1.7))
		var side := 0.25 + 0.5 * fposmod(index * 0.618, 1.0)
		var at := Vector3(area.position.x + area.size.x * (t if along_x else side), height + 0.05,
			area.position.y + area.size.y * (side if along_x else t))
		FarmMesh.box(self, at, Vector3(0.42, 0.012, 0.05) if along_x else Vector3(0.05, 0.012, 0.42), "#a9cfd0")


func _build_bridge(at: Vector3, deck: Rect2, entity: Dictionary) -> void:
	# The deck spans a gap left between two stream segments; water is drawn beneath it.
	var along_x := str(entity.get("axis", "x")) == "x"
	var water: Array = entity.get("water", [1.6, 1.6])
	_ground_patch(Rect2(at.x - float(water[0]) * 0.5, at.z - float(water[1]) * 0.5, float(water[0]), float(water[1])),
		at.y + 0.037, 0.018, "#e8f4ff", Voxels.WATER)
	var bridge := Node3D.new()
	bridge.position = at
	add_child(bridge)
	var length := deck.size.x if along_x else deck.size.y
	var width := deck.size.y if along_x else deck.size.x
	var planks := maxi(2, int(length / 0.42))
	for index in range(planks):
		var offset := lerpf(-length * 0.5, length * 0.5, (index + 0.5) / planks)
		var tone := "#b98a5e" if index % 2 == 0 else "#a97c53"
		var size := Vector3(length / planks - 0.03, 0.1, width) if along_x else Vector3(width, 0.1, length / planks - 0.03)
		FarmMesh.box(bridge, Vector3(offset, 0.14, 0) if along_x else Vector3(0, 0.14, offset), size, tone)
	for side: float in [-1.0, 1.0]:
		var edge: float = side * (width * 0.5 - 0.06)
		for end: float in [-1.0, 0.0, 1.0]:
			var along: float = end * (length * 0.5 - 0.1)
			FarmMesh.box(bridge, Vector3(along, 0.5, edge) if along_x else Vector3(edge, 0.5, along),
				Vector3(0.12, 0.72, 0.12), "#7a5a43")
		FarmMesh.box(bridge, Vector3(0, 0.78, edge) if along_x else Vector3(edge, 0.78, 0),
			Vector3(length, 0.09, 0.09) if along_x else Vector3(0.09, 0.09, length), "#c79a6b")


func _build_well(at: Vector3) -> void:
	well = at
	obstacles.append(Rect2(at.x - 0.75, at.z - 0.75, 1.5, 1.5))
	var root := Node3D.new()
	root.position = at
	add_child(root)
	for side in [-1.0, 1.0]:
		FarmMesh.box(root, Vector3(side * 0.6, 0.3, 0), Vector3(0.3, 0.6, 1.5), "#9a958b")
		FarmMesh.box(root, Vector3(0, 0.3, side * 0.6), Vector3(0.9, 0.6, 0.3), "#a8a297")
		FarmMesh.box(root, Vector3(side * 0.6, 1.2, 0), Vector3(0.14, 1.3, 0.14), "#7a5a43")
	FarmMesh.box(root, Vector3(0, 0.34, 0), Vector3(0.9, 0.05, 0.9), "#3f6f86")
	FarmMesh.box(root, Vector3(0, 1.62, 0), Vector3(1.36, 0.1, 0.12), "#7a5a43")
	for step in range(3):
		FarmMesh.tile(root, Vector3(0, 1.9 + step * 0.16, 0), Vector3(1.7 - step * 0.5, 0.16, 1.5 - step * 0.36), Voxels.ROOF)
	FarmMesh.box(root, Vector3(0.12, 1.28, 0), Vector3(0.04, 0.6, 0.04), "#d9c9a8")
	FarmMesh.box(root, Vector3(0.12, 0.92, 0), Vector3(0.26, 0.24, 0.26), "#8b6750")


func _build_bell(at: Vector3) -> void:
	bell = at
	obstacles.append(Rect2(at.x - 0.75, at.z - 0.2, 1.5, 0.4))
	var root := Node3D.new()
	root.position = at
	add_child(root)
	for side in [-1.0, 1.0]:
		FarmMesh.box(root, Vector3(side * 0.62, 1.15, 0), Vector3(0.16, 2.3, 0.16), "#6c4f3e")
	FarmMesh.box(root, Vector3(0, 2.3, 0), Vector3(1.6, 0.16, 0.22), "#6c4f3e")
	FarmMesh.box(root, Vector3(0, 0.06, 0), Vector3(1.6, 0.12, 0.5), "#8b8378")
	bell_body = Node3D.new()
	bell_body.position = Vector3(0, 2.22, 0)
	root.add_child(bell_body)
	FarmMesh.box(bell_body, Vector3(0, -0.14, 0), Vector3(0.1, 0.2, 0.1), "#6c4f3e")
	FarmMesh.box(bell_body, Vector3(0, -0.38, 0), Vector3(0.36, 0.3, 0.36), "#d8a94a")
	FarmMesh.box(bell_body, Vector3(0, -0.6, 0), Vector3(0.52, 0.18, 0.52), "#e3b85a")
	FarmMesh.box(bell_body, Vector3(0, -0.76, 0), Vector3(0.1, 0.14, 0.1), "#5b4636")


## The foundation of a home the flood took: broken stone walls, a chimney stump, and moss on the floor.
func _build_ruin(at: Vector3, yaw: float) -> void:
	obstacles.append(Rect2(at.x - 1.6, at.z - 1.3, 3.2, 2.6))
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw
	add_child(root)
	FarmMesh.box(root, Vector3(0, 0.04, 0), Vector3(3.2, 0.08, 2.6), "#8f8c80")
	for patch: Vector3 in [Vector3(-0.8, 0.09, 0.3), Vector3(0.7, 0.09, -0.4), Vector3(0.2, 0.09, 0.7)]:
		FarmMesh.box(root, patch, Vector3(0.8, 0.03, 0.6), "#7f9a62")
	# Back wall, tallest by the chimney and crumbling toward the far corner.
	var heights := [1.5, 1.2, 1.3, 0.8, 0.5, 0.3]
	for index in range(heights.size()):
		var tall: float = heights[index]
		FarmMesh.box(root, Vector3(-1.35 + index * 0.52, tall * 0.5, -1.18), Vector3(0.52, tall, 0.24),
			"#a8a297" if index % 2 == 0 else "#9a958b")
	# Side walls step down toward the front.
	for index in range(4):
		var left: float = 1.1 - index * 0.25
		var right: float = 0.45 - index * 0.1
		FarmMesh.box(root, Vector3(-1.48, left * 0.5, -0.8 + index * 0.55), Vector3(0.24, left, 0.55),
			"#9a958b" if index % 2 == 0 else "#a8a297")
		FarmMesh.box(root, Vector3(1.48, right * 0.5, -0.8 + index * 0.55), Vector3(0.24, right, 0.55), "#a39e93")
	# Front wall with the doorway still open, and one doorpost standing.
	FarmMesh.box(root, Vector3(-1.0, 0.2, 1.18), Vector3(1.0, 0.4, 0.24), "#a8a297")
	FarmMesh.box(root, Vector3(1.05, 0.14, 1.18), Vector3(0.9, 0.28, 0.24), "#9a958b")
	FarmMesh.box(root, Vector3(-0.42, 0.6, 1.18), Vector3(0.16, 1.2, 0.16), "#6c5546")
	# Chimney stump in the back corner, a fallen roof beam, and loose stones.
	FarmMesh.box(root, Vector3(-1.1, 1.1, -0.85), Vector3(0.62, 2.2, 0.56), "#8d8a80")
	FarmMesh.box(root, Vector3(-1.1, 2.26, -0.85), Vector3(0.74, 0.14, 0.68), "#7d7a71")
	var beam := FarmMesh.box(root, Vector3(0.45, 0.22, 0.1), Vector3(2.0, 0.14, 0.16), "#6c5546")
	beam.rotation_degrees = Vector3(0, 28, 8)
	for stone: Vector3 in [Vector3(1.0, 0.16, 0.55), Vector3(0.75, 0.13, -0.75), Vector3(-0.3, 0.12, -0.5)]:
		FarmMesh.box(root, stone, Vector3(0.3, 0.18, 0.26), "#b3ada1")
	# A high-water line stained across what is left of the walls.
	FarmMesh.box(root, Vector3(-1.1, 0.95, -0.56), Vector3(0.64, 0.05, 0.02), "#5f7f8a")


## The old floodgate across the brook: stone piers on both banks, a raised plank gate, and its wheel.
func _build_floodgate(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	for side: float in [-1.0, 1.0]:
		obstacles.append(Rect2(at.x + side * 1.2 - 0.35, at.z - 0.4, 0.7, 0.8))
		FarmMesh.box(root, Vector3(side * 1.2, 0.8, 0), Vector3(0.6, 1.6, 0.8), "#9a958b")
		FarmMesh.box(root, Vector3(side * 1.2, 1.66, 0), Vector3(0.72, 0.12, 0.92), "#8d8a80")
		FarmMesh.box(root, Vector3(side * 0.82, 1.5, 0), Vector3(0.12, 3.0, 0.14), "#6c4f3e")
	FarmMesh.box(root, Vector3(0, 3.0, 0), Vector3(1.9, 0.16, 0.2), "#6c4f3e")
	FarmMesh.box(root, Vector3(0, 0.1, 0), Vector3(1.8, 0.2, 0.5), "#8d8a80")
	for plank in range(4):
		FarmMesh.box(root, Vector3(-0.57 + plank * 0.38, 1.7, 0), Vector3(0.36, 1.5, 0.1),
			"#8b6750" if plank % 2 == 0 else "#7a5a43")
	FarmMesh.box(root, Vector3(0, 1.3, 0.06), Vector3(1.56, 0.1, 0.04), "#4f4a44")
	FarmMesh.box(root, Vector3(0, 2.1, 0.06), Vector3(1.56, 0.1, 0.04), "#4f4a44")
	# The wheel on the east pier that raised the gate, rusted in place.
	var wheel := Node3D.new()
	wheel.position = Vector3(1.2, 2.05, 0.3)
	root.add_child(wheel)
	FarmMesh.box(wheel, Vector3(0, -0.2, -0.3), Vector3(0.12, 0.5, 0.12), "#4f4a44")
	for spoke in range(4):
		var arm := FarmMesh.box(wheel, Vector3.ZERO, Vector3(0.7, 0.08, 0.06), "#8a5a3c")
		arm.rotation_degrees.z = spoke * 45.0


func _build_dig_spot(at: Vector3, authored: Vector3) -> void:
	var sparkle := Node3D.new()
	sparkle.position = at
	add_child(sparkle)
	FarmMesh.tile(sparkle, Vector3(0, 0.04, 0), Vector3(0.62, 0.07, 0.56), Voxels.SOIL, "#cdb49d")
	FarmMesh.tile(sparkle, Vector3(0.06, 0.09, -0.03), Vector3(0.36, 0.06, 0.32), Voxels.SOIL, "#bfa58d")
	for glint in [Vector3(-0.12, 0.2, 0.08), Vector3(0.14, 0.3, -0.06), Vector3(0.02, 0.42, 0.1)]:
		FarmMesh.box(sparkle, glint, Vector3(0.05, 0.05, 0.05), "#ffe9a3", true)
	sparkle.hide()
	dig_spots.append({"at": authored, "sparkle": sparkle})
