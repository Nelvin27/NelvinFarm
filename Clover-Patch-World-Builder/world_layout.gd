extends RefCounted

const DEFAULT_PATH := "res://world/clover_valley.json"
const GRID_ORIGIN := Vector3(-5.5, 0, -3.0)
const REQUIRED := ["cottage", "seed_market", "bakery", "spawn"]
const LABELS := {
	"grass": "Grass tile", "path": "Dirt path", "pond": "Pond", "plot": "Farm plot",
	"fence": "Fence", "tree": "Tree", "apple_tree": "Apple tree",
	"purple_flower": "Purple flower", "yellow_flower": "Yellow flower", "sign": "Sign",
	"cottage": "Cottage", "seed_market": "Seed market", "bakery": "Bakery", "spawn": "Player spawn",
}

var bounds := Rect2()
var entities: Array[Dictionary] = []


func read(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("version") != 1:
		return ERR_FILE_CORRUPT
	var area: Variant = parsed.get("bounds")
	var items: Variant = parsed.get("entities")
	if not _numbers(area, 4) or not items is Array or items.size() > 5000:
		return ERR_INVALID_DATA
	var next_bounds := Rect2(area[0], area[1], area[2], area[3])
	if next_bounds.size.x < 8 or next_bounds.size.y < 8 or next_bounds.size.x > 200 or next_bounds.size.y > 200:
		return ERR_INVALID_DATA
	var loaded: Array[Dictionary] = []
	var singletons := {}
	var plots := {}
	for item: Variant in items:
		if not item is Dictionary or not LABELS.has(item.get("kind")) or not _numbers(item.get("position"), 3):
			return ERR_INVALID_DATA
		var kind: String = item["kind"]
		var at := position_of(item)
		if not next_bounds.has_point(Vector2(at.x, at.z)):
			return ERR_INVALID_DATA
		if kind in ["path", "pond"] and item.has("size"):
			if not _numbers(item["size"], 2) or item["size"][0] <= 0 or item["size"][1] <= 0 or item["size"][0] > 200 or item["size"][1] > 200:
				return ERR_INVALID_DATA
		for key in ["length", "scale", "yaw"]:
			if item.has(key) and (not (item[key] is float or item[key] is int) or not is_finite(float(item[key]))):
				return ERR_INVALID_DATA
		if float(item.get("length", 1.0)) <= 0.0 or float(item.get("length", 1.0)) > 200.0:
			return ERR_INVALID_DATA
		if float(item.get("scale", 1.0)) <= 0.0 or float(item.get("scale", 1.0)) > 10.0:
			return ERR_INVALID_DATA
		if kind in REQUIRED:
			if singletons.has(kind):
				return ERR_INVALID_DATA
			singletons[kind] = true
		if kind == "plot":
			var tile := tile_at(at)
			if plots.has(tile) or not at.is_equal_approx(world_at(tile)):
				return ERR_INVALID_DATA
			plots[tile] = true
		loaded.append(item)
	if singletons.size() != REQUIRED.size():
		return ERR_INVALID_DATA
	bounds = next_bounds
	entities = loaded
	return OK


func write(path: String) -> Error:
	var temporary := path + ".%d.tmp" % Time.get_ticks_usec()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": 1, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"entities": entities,
	}, "\t") + "\n")
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return error


func anchor(kind: String) -> Vector3:
	for item in entities:
		if item["kind"] == kind:
			return position_of(item)
	return Vector3.ZERO


static func position_of(entity: Dictionary) -> Vector3:
	var at: Array = entity["position"]
	return Vector3(at[0], at[1], at[2])


static func set_position(entity: Dictionary, at: Vector3) -> void:
	entity["position"] = [at.x, at.y, at.z]


static func tile_at(at: Vector3) -> Vector2i:
	var offset := at - GRID_ORIGIN
	return Vector2i(floori(offset.x + 0.5), floori(offset.z + 0.5))


static func world_at(tile: Vector2i) -> Vector3:
	return GRID_ORIGIN + Vector3(tile.x, 0, tile.y)


static func _numbers(value: Variant, length: int) -> bool:
	if not value is Array or value.size() != length:
		return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)):
			return false
	return true
