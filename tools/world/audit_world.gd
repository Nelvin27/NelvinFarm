extends SceneTree
## Walks the map in 5x5-unit cells and lists visual problems in each one, using the game's own terrain.
##   godot --headless --path Clover-Patch-3D --script ../tools/world/audit_world.gd [-- --verbose]
## Exits non-zero when any cell has a problem. --verbose prints every finding, not just the per-cell summary.

const Layout := preload("res://world_layout.gd")
const CELL := 5.0
## Canopy half-width and height of a scale-1 tree (voxel_assets.gd TREE_PARTS).
const CANOPY := 0.56
const CANOPY_TOP := 1.75
const TRUNK := 0.14

var layout
var findings: Dictionary = {}   # Vector2i cell -> Array[String]
var total := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var Save = load("res://farm_save.gd")
	Save.path = OS.get_temp_dir().path_join("clover-world-audit-%d.cfg" % OS.get_process_id())
	var farm: Node = load("res://farm.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	layout = farm.layout
	var solids := _solids(farm.scenery)
	var paths := _rects("path")
	var ponds := _rects("pond")
	ponds.append_array(_rects("stream"))
	var trees: Array[Dictionary] = []
	for e: Dictionary in layout.entities:
		if e.kind in ["tree", "apple_tree"]:
			trees.append(e)

	for e: Dictionary in layout.entities:
		var at := Layout.position_of(e)
		var p := Vector2(at.x, at.z)
		match e.kind:
			"tree", "apple_tree":
				var scale := float(e.get("scale", 1.0))
				_check_ledge(e, p, TRUNK * scale, "trunk straddles a block ledge (floats or sinks)")
				_check_canopy_wall(e, p, scale)
				for r: Rect2 in solids:
					if _circle_hits(p, CANOPY * scale * 0.85, r):
						_add(p, "%s at (%.1f, %.1f) grows into a building, fence, table, or stall" % [e.kind, p.x, p.y])
						break
				for r: Rect2 in paths:
					if _circle_hits(p, TRUNK * scale + 0.1, r):
						_add(p, "%s trunk at (%.1f, %.1f) stands on a path" % [e.kind, p.x, p.y])
						break
				for r: Rect2 in ponds:
					if _circle_hits(p, CANOPY * scale * 0.6, r.grow(0.4)):
						_add(p, "%s at (%.1f, %.1f) stands in a pond" % [e.kind, p.x, p.y])
						break
			"purple_flower", "yellow_flower", "forage", "lamp", "sign", "grass", "picnic", "bunting", "dig", "bush", "rock":
				var half: float = {"picnic": 1.0, "bunting": 1.8, "grass": 0.5, "lamp": 0.18, "forage": 0.32}.get(e.kind, 0.12)
				_check_ledge(e, p, half, "sits across a block ledge")
				if e.kind in ["purple_flower", "yellow_flower", "forage", "grass"]:
					for r: Rect2 in paths:
						if r.has_point(p):
							_add(p, "%s at (%.1f, %.1f) is on a path" % [e.kind, p.x, p.y])
							break
				if e.kind in ["purple_flower", "yellow_flower", "forage", "lamp", "sign"]:
					for r: Rect2 in ponds:
						if r.grow(0.35).has_point(p):
							_add(p, "%s at (%.1f, %.1f) is in a pond" % [e.kind, p.x, p.y])
							break
					for r: Rect2 in solids:
						if r.grow(-0.02).has_point(p):
							_add(p, "%s at (%.1f, %.1f) is inside a solid object" % [e.kind, p.x, p.y])
							break
				if e.kind in ["purple_flower", "yellow_flower", "forage", "lamp", "sign"]:
					for t: Dictionary in trees:
						var tp := Vector2(t.position[0], t.position[2])
						if tp.distance_to(p) < TRUNK * float(t.get("scale", 1.0)) + 0.15:
							_add(p, "%s at (%.1f, %.1f) is inside a tree trunk" % [e.kind, p.x, p.y])
							break
			"path":
				_check_path(e, p, paths, ponds)
	_check_tree_spacing(trees)

	var cells := findings.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var verbose := "--verbose" in OS.get_cmdline_user_args()
	var kinds := {}
	for cell: Vector2i in cells:
		var items: Array = findings[cell]
		if verbose:
			print("Cell x %d..%d, z %d..%d: %d" % [cell.x * CELL, cell.x * CELL + CELL, cell.y * CELL, cell.y * CELL + CELL, items.size()])
			for item: String in items:
				print("    ", item)
		for item: String in items:
			var kind: String = item.split(" at ")[0] + " · " + item.split(") ")[-1] if " at (" in item else item
			kinds[kind] = kinds.get(kind, 0) + 1
	print("Audit: %d findings in %d of %d cells" % [total, cells.size(),
		int(ceil(layout.bounds.size.x / CELL) * ceil(layout.bounds.size.y / CELL))])
	var summary := kinds.keys()
	summary.sort_custom(func(a: String, b: String) -> bool: return kinds[a] > kinds[b])
	for kind: String in summary:
		print("  %4d  %s" % [kinds[kind], kind])
	farm.queue_free()
	await process_frame
	quit(1 if total else 0)


func _add(p: Vector2, message: String) -> void:
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if not findings.has(cell):
		findings[cell] = []
	findings[cell].append(message)
	total += 1


func _rects(kind: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for e: Dictionary in layout.entities:
		if e.kind == kind:
			var size: Array = e.get("size", [1, 1])
			out.append(Rect2(e.position[0] - size[0] * 0.5, e.position[2] - size[1] * 0.5, size[0], size[1]))
	return out


func _solids(scenery) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var ponds := _rects("pond")
	ponds.append_array(_rects("stream"))
	var barriers := _rects("ridge_barrier")
	for r: Rect2 in scenery.obstacles:
		if r in ponds or r in barriers:
			continue
		out.append(r)
	# The stalls are not obstacles in game but still occupy space.
	out.append(Rect2(scenery.market_area.position.x - 0.9, scenery.market_area.position.y + 0.8, 1.2, 1.6))
	return out


func _circle_hits(c: Vector2, radius: float, r: Rect2) -> bool:
	var nearest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return nearest.distance_to(c) < radius


func _check_ledge(e: Dictionary, p: Vector2, half: float, problem: String) -> void:
	var base: float = layout.elevation(p)
	for offset: Vector2 in [Vector2(half, 0), Vector2(-half, 0), Vector2(0, half), Vector2(0, -half)]:
		if layout.elevation(p + offset) != base:
			_add(p, "%s at (%.1f, %.1f) %s" % [e.kind, p.x, p.y, problem])
			return


func _check_canopy_wall(e: Dictionary, p: Vector2, scale: float) -> void:
	# A neighbouring column taller than the canopy's underside pushes leaves into a terrain wall.
	var base: float = layout.elevation(p)
	var reach := CANOPY * scale * 0.9
	for offset: Vector2 in [Vector2(reach, 0), Vector2(-reach, 0), Vector2(0, reach), Vector2(0, -reach)]:
		if layout.elevation(p + offset) - base >= 1.0:
			_add(p, "%s at (%.1f, %.1f) pushes its canopy into a terrain wall" % [e.kind, p.x, p.y])
			return


func _check_tree_spacing(trees: Array[Dictionary]) -> void:
	for i in range(trees.size()):
		var a: Dictionary = trees[i]
		var pa := Vector2(a.position[0], a.position[2])
		var sa := float(a.get("scale", 1.0))
		for j in range(i + 1, trees.size()):
			var b: Dictionary = trees[j]
			var pb := Vector2(b.position[0], b.position[2])
			var sb := float(b.get("scale", 1.0))
			if pa.distance_to(pb) < CANOPY * (sa + sb) * 0.62:
				_add(pa, "tree at (%.1f, %.1f) clips into another tree" % [pa.x, pa.y])


func _check_path(e: Dictionary, p: Vector2, paths: Array[Rect2], ponds: Array[Rect2]) -> void:
	var size: Array = e.get("size", [1, 1])
	var rect := Rect2(p.x - size[0] * 0.5, p.y - size[1] * 0.5, size[0], size[1])
	for r: Rect2 in ponds:
		if rect.intersects(r.grow(-0.05)):
			_add(p, "path at (%.1f, %.1f) runs into a pond" % [p.x, p.y])
	# Dead ends: both ends of a strip should meet another path, a door, a dock, or a landmark.
	var horizontal: bool = size[0] >= size[1]
	var ends: Array[Vector2] = []
	if horizontal:
		ends = [Vector2(rect.position.x - 0.3, p.y), Vector2(rect.end.x + 0.3, p.y)]
	else:
		ends = [Vector2(p.x, rect.position.y - 0.3), Vector2(p.x, rect.end.y + 0.3)]
	for end: Vector2 in ends:
		var joined := false
		for other: Rect2 in paths:
			if other != rect and other.grow(0.35).has_point(end):
				joined = true
				break
		if not joined and not _near_landmark(end):
			_add(end, "path at (%.1f, %.1f) dead-ends at (%.1f, %.1f)" % [p.x, p.y, end.x, end.y])


func _near_landmark(at: Vector2) -> bool:
	for e: Dictionary in layout.entities:
		if e.kind in ["resident_house", "cottage", "seed_market", "bakery", "closed_pass", "picnic", "pond", "lamp", "bridge", "floodgate", "ruin"]:
			var p := Vector2(e.position[0], e.position[2])
			var reach := 4.5 if e.kind in ["pond", "cottage"] else 2.6
			if p.distance_to(at) < reach:
				return true
	# Trails that end at a lookout top count as arriving somewhere.
	return layout.elevation(at) >= 4.0
