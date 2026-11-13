extends RefCounted
## Reads and validates world/clover_valley.json (written by tools/world/build_world.py).

const DEFAULT_PATH := "res://world/clover_valley.json"
const GRID_ORIGIN := Vector3(-5.5, 0, -3.0)
const MOUNTAIN_SIZE := [16.0, 16.0]
const MOUNTAIN_HEIGHT := 5.0
const MAX_MOUNTAIN_HEIGHT := 16.0
const REQUIRED := ["cottage", "seed_market", "bakery", "spawn"]
const LABELS := {
	"grass": "Grass tile", "path": "Dirt path", "pond": "Pond", "plot": "Farm plot",
	"fence": "Fence", "tree": "Tree", "apple_tree": "Apple tree",
	"purple_flower": "Purple flower", "yellow_flower": "Yellow flower", "sign": "Sign",
	"cottage": "Cottage", "seed_market": "Seed market", "bakery": "Bakery", "spawn": "Player spawn",
	"mountain": "Mountain", "resident_house": "Resident house", "lamp": "Lantern post",
	"ridge_barrier": "Ridge barrier", "closed_pass": "Closed pass", "picnic": "Picnic table",
	"bunting": "Bunting", "butterflies": "Butterflies", "forage": "Forage spot", "bush": "Bush", "rock": "Rock", "tuft": "Grass tuft",
	"stream": "Stream", "bridge": "Bridge", "well": "Wishing well", "bell": "Town bell", "dig": "Dig spot",
	"landmark": "Landmark",
	"ruin": "Flooded ruin", "floodgate": "Floodgate",
}

var bounds := Rect2()
var entities: Array[Dictionary] = []
var mountains: Array[Dictionary] = []


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
	var homeowners := {}
	for item: Variant in items:
		if not item is Dictionary or not LABELS.has(item.get("kind")) or not _numbers(item.get("position"), 3):
			return ERR_INVALID_DATA
		var kind: String = item["kind"]
		var at := position_of(item)
		if not next_bounds.has_point(Vector2(at.x, at.z)):
			return ERR_INVALID_DATA
		if kind in ["path", "pond", "mountain", "ridge_barrier", "stream", "bridge"] and item.has("size"):
			if not _numbers(item["size"], 2) or item["size"][0] <= 0 or item["size"][1] <= 0 or item["size"][0] > 200 or item["size"][1] > 200:
				return ERR_INVALID_DATA
		if kind == "mountain":
			var height: Variant = item.get("height", MOUNTAIN_HEIGHT)
			if not (height is float or height is int) or not is_finite(float(height)) or height <= 0 or height > MAX_MOUNTAIN_HEIGHT:
				return ERR_INVALID_DATA
			# Optional profile exponent: 2 is the classic dome, lower values give broad shoulders.
			var falloff: Variant = item.get("falloff", 2.0)
			if not (falloff is float or falloff is int) or falloff < 0.5 or falloff > 4.0:
				return ERR_INVALID_DATA
		for key in ["length", "scale", "yaw"]:
			if item.has(key) and (not (item[key] is float or item[key] is int) or not is_finite(float(item[key]))):
				return ERR_INVALID_DATA
		if float(item.get("length", 1.0)) <= 0.0 or float(item.get("length", 1.0)) > 200.0:
			return ERR_INVALID_DATA
		if float(item.get("scale", 1.0)) <= 0.0 or float(item.get("scale", 1.0)) > 10.0:
			return ERR_INVALID_DATA
		if kind == "resident_house":
			var resident: Variant = item.get("resident", "")
			if not resident is String or (not resident.is_empty() and (not resident.is_valid_identifier() or homeowners.has(resident))):
				return ERR_INVALID_DATA
			if not resident.is_empty():
				homeowners[resident] = true
			for field in ["street", "color", "trim", "detail"]:
				if not item.get(field, "") is String:
					return ERR_INVALID_DATA
			var style: Variant = item.get("style", 0)
			if not (style is int or style is float) or style != int(style) or style < 0 or style > 3:
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
	refresh_mountains()
	return OK


func anchor(kind: String) -> Vector3:
	for item in entities:
		if item["kind"] == kind:
			return position_of(item)
	return Vector3.ZERO


func refresh_mountains() -> void:
	mountains.clear()
	for entity in entities:
		if entity["kind"] != "mountain":
			continue
		var at := position_of(entity)
		var size: Array = entity.get("size", MOUNTAIN_SIZE)
		mountains.append({
			"center": Vector2(at.x, at.z),
			"radius": Vector2(size[0], size[1]) * 0.5,
			"height": float(entity.get("height", MOUNTAIN_HEIGHT)),
			"falloff": float(entity.get("falloff", 2.0)),
		})


func elevation(at: Vector2) -> float:
	# Sample the same one-unit column for movement, props, and the terrain mesh.
	var cell := Vector2(floorf(at.x) + 0.5, floorf(at.y + 0.5))
	var highest := 0.0
	for mountain in mountains:
		var offset: Vector2 = (cell - mountain["center"]) / mountain["radius"]
		var falloff := maxf(0.0, 1.0 - offset.length_squared())
		highest = maxf(highest, mountain["height"] * pow(falloff, mountain["falloff"]))
	return roundf(highest)


func grounded(at: Vector3) -> Vector3:
	return at + Vector3.UP * elevation(Vector2(at.x, at.z))


static func position_of(entity: Dictionary) -> Vector3:
	var at: Array = entity["position"]
	return Vector3(at[0], at[1], at[2])


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
