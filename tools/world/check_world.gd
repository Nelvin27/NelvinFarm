extends SceneTree
## In-engine checks for world/clover_valley.json, using the game's own terrain and villager navigation.
##   godot --headless --path Clover-Patch-3D --script ../tools/world/check_world.gd
## Exits non-zero when a check fails.

const Layout := preload("res://world_layout.gd")
## Flat-footprint kinds and their half extents (paths and ponds use their size).
const FLAT := {"resident_house": Vector2(2.0, 1.6), "picnic": Vector2(1.0, 0.9), "fence": Vector2(0.4, 0.4),
	"plot": Vector2(0.4, 0.4), "cottage": Vector2(0.4, 0.4), "seed_market": Vector2(0.4, 0.4),
	"bakery": Vector2(0.4, 0.4), "bunting": Vector2(0.4, 0.4), "sign": Vector2(0.4, 0.4),
	"well": Vector2(0.8, 0.8), "bell": Vector2(0.8, 0.3), "dig": Vector2(0.4, 0.4),
	"ruin": Vector2(1.6, 1.3), "floodgate": Vector2(1.5, 0.4)}
## Trails deliberately climb the north peak and the east knoll.
const TRAIL_AREAS := [Rect2(-15, -26, 10, 9), Rect2(88, 11, 9, 13), Rect2(9, -23, 5, 6)]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	failures += 1
	print("FAIL  ", message)


func _run() -> void:
	var Save = load("res://farm_save.gd")
	Save.path = OS.get_temp_dir().path_join("clover-world-check-%d.cfg" % OS.get_process_id())
	var farm: Node = load("res://farm.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	var layout = farm.layout
	_check_level_ground(layout)
	_check_reachable(farm)
	_check_routines(farm.village)
	print("World check: %d entities, %d failures" % [layout.entities.size(), failures])
	farm.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _check_level_ground(layout) -> void:
	for e: Dictionary in layout.entities:
		var at := Layout.position_of(e)
		var half: Vector2
		if e.kind in ["path", "pond", "stream", "bridge"]:
			var size: Array = e.get("size", [1, 1])
			half = Vector2(size[0], size[1]) * 0.5
		elif FLAT.has(e.kind):
			half = FLAT[e.kind]
		else:
			continue
		if e.kind == "path" and TRAIL_AREAS.any(func(area: Rect2) -> bool: return area.has_point(Vector2(at.x, at.z))):
			continue
		# Flat objects need one height across their footprint (the summit lookout sits on the peak).
		var height: float = layout.elevation(Vector2(at.x, at.z))
		var x := at.x - half.x
		while x <= at.x + half.x + 0.001:
			var z := at.z - half.y
			while z <= at.z + half.y + 0.001:
				if layout.elevation(Vector2(x, z)) != height:
					_fail("%s at (%.1f, %.1f) is not on level ground at (%.1f, %.1f)" % [e.kind, at.x, at.z, x, z])
					return
				z += 0.5
			x += 0.5


func _check_reachable(farm) -> void:
	var village = farm.village
	var spawn := Layout.tile_at(farm.layout.anchor("spawn"))
	var spots := {
		"cottage door": farm.scenery.cottage_door + Vector3(0, 0, 0.4), "seed market": Vector3(5.8, 0, 2.4),
		"bakery": Vector3(8.5, 0, 7.0), "Supper clearing": Vector3(14, 0, 18), "old pass": Vector3(-26, 0, 14),
		"Market Lane": Vector3(3.5, 0, 4),
	}
	for spot: Vector3 in farm.scenery.fishing_spots:
		spots["fishing dock (%.0f, %.0f)" % [spot.x, spot.z]] = spot
	for spot: Vector3 in farm.scenery.picnic_spots:
		if spot.y == 0.0:   # the summit table is reached by climbing, which villager paths don't model
			spots["picnic table (%.0f, %.0f)" % [spot.x, spot.z]] = spot + Vector3(0, 0, 1.4)
	for dig: Dictionary in farm.scenery.dig_spots:
		spots["dig spot (%.0f, %.0f)" % [dig.at.x, dig.at.z]] = dig.at
	for sign: Dictionary in farm.scenery.signs:
		spots["sign (%.0f, %.0f)" % [sign.at.x, sign.at.z]] = sign.at + Vector3(0, 0, 0.8)
	for landmark: Dictionary in farm.scenery.landmarks:
		if landmark.at.y == 0.0:
			spots[landmark.name] = landmark.at
	if farm.scenery.well.is_finite():
		spots["wishing well"] = farm.scenery.well + Vector3(0, 0, 1.4)
	if farm.scenery.bell.is_finite():
		spots["town bell"] = farm.scenery.bell + Vector3(0, 0, 1.0)
	for forage: Dictionary in farm.scenery.forage_spots:
		spots["%s forage (%.0f, %.0f)" % [forage.item, forage.at.x, forage.at.z]] = forage.at
	for name: String in spots:
		var to: Vector2i = village._walkable_cell(spots[name])
		if village.navigation.get_id_path(spawn, to).is_empty():
			_fail("no level route from spawn to the " + name)


func _check_routines(village) -> void:
	for index in range(village.residents.size()):
		var resident: Dictionary = village.residents[index]
		if not village.homes.has(resident.id):
			_fail("%s has no house on the map" % resident.id)
			continue
		var stops := ["home", "work", "leisure"]
		if resident.routine.has("story_stop"):
			stops.append("story")
		stops.append("home")
		for i in range(stops.size() - 1):
			var target: Vector3 = village._destination(index, stops[i + 1])
			var from: Vector2i = village._walkable_cell(village._destination(index, stops[i]))
			var to: Vector2i = village._walkable_cell(target)
			if village.navigation.get_id_path(from, to).is_empty():
				_fail("%s cannot walk from %s to %s" % [resident.id, stops[i], stops[i + 1]])
			elif Layout.world_at(to).distance_to(Vector3(target.x, 0, target.z)) > 1.2:
				_fail("%s's %s stop %s is blocked" % [resident.id, stops[i + 1], target])
