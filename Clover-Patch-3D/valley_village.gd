extends Node3D

const Layout := preload("res://world_layout.gd")
const Meshes := preload("res://farm_mesh.gd")
const Catalog := preload("res://crop_catalog.gd")
const ResidentHouse := preload("res://resident_house.gd")
const ResidentModel := preload("res://resident_model.gd")

const CHARACTERS_PATH := "res://village/characters"
const TOWN_EVENTS_PATH := "res://village/town_events.json"
const DISTRICT_NAMES := ["Market Lane", "west of Willow Pond", "orchard edge", "Clover Meadow"]
const DISTRICTS := [Vector2(2.7, 7.9), Vector2(-5.0, 13.0), Vector2(12.0, -11.0), Vector2(16.0, 14.0)]
const EVIDENCE := {"tess": 1, "vera": 2, "orin": 4}

var layout: Layout
var residents: Array[Dictionary] = []
var resident_indices: Dictionary[String, int] = {}
var district_slots: Array[int] = []
var models: Array[Node3D] = []
var figures: Array[Node3D] = []
var feet: Array[Node3D] = []
var homes: Dictionary = {}
var navigation := AStarGrid2D.new()
var routes: Array[Dictionary] = []
var blocked: Array[Rect2] = []
const WALK_SPEED := 3.8
const DOOR_OPEN_TIME := 0.30
const DOOR_STEP_TIME := 0.62
const DOOR_CLOSE_TIME := 0.32
var favor: Dictionary = {}
var last_talk: Dictionary = {}
var last_gift: Dictionary = {}
var dates: Dictionary = {}
var evidence := 0
var hearing_day := 0
var resolution := 0
var supper := 0
var supper_day := 0
var partner := ""
var supper_table: Node3D
var town_events: Dictionary = {}
var town_event_seen: Array[String] = []
var town_event_host := ""
var town_event_day := 0
var town_event_choice := -1


func load_residents() -> Error:
	var loaded: Array[Dictionary] = []
	for file in DirAccess.get_files_at(CHARACTERS_PATH):
		if file.get_extension() != "json":
			continue
		var entry: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH.path_join(file)))
		if not entry is Dictionary or not _valid_resident(entry, file.get_basename()):
			push_error("Invalid village character file: %s" % file)
			return ERR_INVALID_DATA
		loaded.append(entry)
	loaded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.order < b.order if a.order != b.order else a.id < b.id)
	var district_counts := [0, 0, 0, 0]
	for index in range(loaded.size()):
		var entry := loaded[index]
		resident_indices[entry.id] = index
		var district := int(entry.district)
		district_slots.append(district_counts[district])
		district_counts[district] += 1
	for required in ["iona", "mara", "tess", "vera", "orin"]:
		if not resident_indices.has(required):
			push_error("Missing required village resident: %s" % required)
			return ERR_INVALID_DATA
	residents = loaded
	var events: Variant = JSON.parse_string(FileAccess.get_file_as_string(TOWN_EVENTS_PATH))
	if not events is Dictionary or events.is_empty():
		push_error("Could not load village town events.")
		return ERR_INVALID_DATA
	for host in events:
		var event: Variant = events[host]
		if not resident_indices.has(host) or not event is Dictionary or not event.get("title") is String or not event.get("prompt") is String or not event.get("choices") is Array or event.choices.size() != 2:
			push_error("Invalid town event for %s." % host)
			return ERR_INVALID_DATA
		for choice in event.choices:
			if not choice is Dictionary or not choice.get("label") is String or not choice.get("reply") is String:
				push_error("Invalid town event choice for %s." % host)
				return ERR_INVALID_DATA
	town_events = events
	return OK


func schedule_town_event(day: int) -> void:
	if day < 2 or town_event_day == day:
		return
	var available: Array[String] = []
	for host in town_events:
		if not town_event_seen.has(host):
			available.append(host)
	if available.is_empty():
		town_event_seen.clear()
		available.assign(town_events.keys())
		if available.size() > 1:
			available.erase(town_event_host)
	town_event_host = available.pick_random()
	town_event_seen.append(town_event_host)
	town_event_day = day
	town_event_choice = -1


func _valid_resident(entry: Dictionary, id: String) -> bool:
	if entry.get("id") != id or not entry.get("name") is String or not entry.get("role") is String:
		return false
	var district: Variant = entry.get("district")
	if not _is_whole_number(district) or district < 0 or district >= DISTRICTS.size():
		return false
	if not _is_whole_number(entry.get("order")) or not entry.get("romance") is bool:
		return false
	var gifts: Variant = entry.get("gifts")
	var lines: Variant = entry.get("dialogue")
	if not gifts is Dictionary or not lines is Dictionary:
		return false
	for preference in ["favorite", "disliked"]:
		var item: Variant = gifts.get(preference)
		if not _is_whole_number(item) or item < -1 or item >= Catalog.crops.size():
			return false
	var required_lines := ["introduction", "friendship", "supper", "hearing", "favorite_gift", "disliked_gift"]
	if EVIDENCE.has(id):
		required_lines.append_array(["witness", "after_testimony"])
	if entry.romance:
		required_lines.append_array(["date", "partner"])
	if id == "iona":
		required_lines.append_array(["opening", "waiting_hearing", "open_hearing"])
	if id == "mara":
		required_lines.append_array(["supper_invitation", "supper_open"])
	for key in required_lines:
		if not lines.get(key) is String or lines[key].strip_edges().is_empty():
			return false
	if id == "iona" and not lines.has("hearings"):
		return false
	for key in ["hearings", "supper_choices"]:
		if lines.has(key):
			var count := 3 if key == "hearings" else 2
			if not lines[key] is Array or lines[key].size() != count:
				return false
			for line in lines[key]:
				if not line is String or line.strip_edges().is_empty():
					return false
	var routine: Variant = entry.get("routine")
	if not routine is Dictionary:
		return false
	var last := 6.0
	for key in ["depart", "break_at", "home"]:
		var hour: Variant = routine.get(key)
		if not (hour is int or hour is float) or not is_finite(float(hour)) or hour <= last or hour > 24:
			return false
		last = float(hour)
	for key in ["work", "leisure"]:
		if not _valid_stop(routine.get(key)):
			return false
	if routine.has("story_stop"):
		var story: Variant = routine.story_stop
		if not story is Dictionary or story.get("after") not in ["hearing", "testimony"] or not _valid_stop(story.get("at")):
			return false
		if not story.get("area") is String or not story.get("activity") is String:
			return false
	for key in ["job", "hobby", "leisure_area", "home_context"]:
		if not routine.get(key) is String or routine[key].is_empty():
			return false
	return true


func _valid_stop(point: Variant) -> bool:
	if not point is Array or point.size() != 2:
		return false
	for value in point:
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	return true


func _is_whole_number(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floorf(float(value))


func populate(world: Layout, obstacles: Array[Rect2], doors: Dictionary) -> void:
	layout = world
	for entity in layout.entities:
		if entity.kind == "resident_house" and resident_indices.has(entity.get("resident", "")):
			var porch := Layout.position_of(entity) + ResidentHouse.PORCH_OFFSET
			homes[entity.resident] = {"position": porch, "street": entity.get("street", ""),
				"inside": Layout.position_of(entity) + ResidentHouse.INSIDE_OFFSET,
				"door": doors.get(entity.resident)}
	_build_navigation(obstacles)
	for index in range(residents.size()):
		var body := Node3D.new()
		add_child(body)
		models.append(body)
		routes.append({"stage": "", "path": [], "cursor": 0, "phase": float(index), "crossing": "", "door_time": 0.0})
		var figure := Node3D.new()
		body.add_child(figure)
		figures.append(figure)
		feet.append_array(ResidentModel.build(figure, residents[index].get("appearance", {})))
	supper_table = Node3D.new()
	supper_table.position = layout.grounded(Vector3(14.0, 0, 16.5))
	add_child(supper_table)
	Meshes.box(supper_table, Vector3(0, 0.65, 0), Vector3(4.0, 0.16, 0.9), "#8b5e43")
	for x in [-1.75, 1.75]:
		Meshes.box(supper_table, Vector3(x, 0.3, 0), Vector3(0.16, 0.60, 0.7), "#6c4938")
	for index in range(7):
		Meshes.box(supper_table, Vector3((index - 3) * 0.5, 0.75, 0), Vector3(0.23, 0.04, 0.21), "#e2c28b")
	update_routines(1, 6.0, 0.0)


func _build_navigation(obstacles: Array[Rect2]) -> void:
	blocked.clear()
	for obstacle in obstacles:
		blocked.append(obstacle.grow(0.53))
	var first := Layout.tile_at(Vector3(layout.bounds.position.x, 0, layout.bounds.position.y))
	var last := Layout.tile_at(Vector3(layout.bounds.end.x, 0, layout.bounds.end.y))
	navigation.region = Rect2i(first, last - first + Vector2i.ONE)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, z)
			var point := Layout.world_at(cell)
			var at := Vector2(point.x, point.z)
			if not layout.bounds.grow(-0.35).has_point(at) or layout.elevation(at) > 0.0 or _blocked(at):
				navigation.set_point_solid(cell)


func _blocked(at: Vector2) -> bool:
	for obstacle in blocked:
		if obstacle.has_point(at):
			return true
	return false


func _walkable_cell(at: Vector3) -> Vector2i:
	var cell := Layout.tile_at(at)
	var region := navigation.region
	cell = cell.clamp(region.position, region.end - Vector2i.ONE)
	if not navigation.is_point_solid(cell):
		return cell
	var best := cell
	var distance := INF
	for z in range(-5, 6):
		for x in range(-5, 6):
			var candidate := cell + Vector2i(x, z)
			if not region.has_point(candidate) or navigation.is_point_solid(candidate):
				continue
			var gap := Layout.world_at(candidate).distance_squared_to(at)
			if gap < distance:
				best = candidate
				distance = gap
	return best


func _stage(index: int, day: int, hour: float) -> String:
	var resident := residents[index]
	if supper_day == day and hour >= 16.0:
		if resident.id == "mara" or (int(resident.district) == 3 and district_slots[index] < 8):
			return "supper"
	var routine: Dictionary = resident.routine
	if hour < float(routine.depart) or hour >= float(routine.home):
		return "home"
	if hour < float(routine.break_at):
		return "work"
	var story: Dictionary = routine.get("story_stop", {})
	if story.get("after") == "testimony" and bool(evidence & int(EVIDENCE.get(resident.id, 0))):
		return "story"
	if story.get("after") == "hearing" and resolution > 0:
		return "story"
	return "leisure"


func _destination(index: int, stage: String) -> Vector3:
	var resident := residents[index]
	if stage == "supper":
		if resident.id == "mara":
			return Vector3(14.5, 0, 18)
		var slot := district_slots[index]
		return Vector3(12.5 + slot % 4, 0, 15 if slot < 4 else 17)
	if stage == "home" and homes.has(resident.id):
		return homes[resident.id].position
	var point: Array = resident.routine.story_stop.at if stage == "story" else resident.routine.leisure if stage == "leisure" else resident.routine.work
	return Vector3(point[0], 0, point[1])


func location_hint(id: String, day: int, hour: float) -> String:
	var index := resident_indices[id]
	var resident := residents[index]
	match _stage(index, day, hour):
		"supper":
			return "at the meadow supper"
		"home":
			if homes.has(id) and not str(homes[id].street).is_empty():
				var porch: Vector3 = homes[id].position
				return "%s, %s end" % [homes[id].street, "west" if porch.x < 51 else "east"]
			if homes.has(id):
				var porch: Vector3 = homes[id].position
				return "at home near %.0f, %.0f" % [porch.x, porch.z]
		"story":
			return resident.routine.story_stop.area
		"leisure":
			return resident.routine.leisure_area
	return resident.routine.get("work_area", DISTRICT_NAMES[int(resident.district)])


func activity_hint(index: int, day: int, hour: float) -> String:
	match _stage(index, day, hour):
		"supper":
			return "Joins the valley supper"
		"home":
			return "Inside their home" if homes.has(residents[index].id) else "Takes a break"
		"work":
			return residents[index].routine.job
		"story":
			return residents[index].routine.story_stop.activity
		_:
			return residents[index].routine.hobby


func update_routines(day: int, hour: float, delta: float) -> void:
	supper_table.visible = supper_day == day and hour >= 16.0
	for index in range(models.size()):
		var body := models[index]
		var route := routes[index]
		var stage := _stage(index, day, hour)
		var home: Dictionary = homes.get(residents[index].id, {})
		if delta <= 0.0:
			_snap_routine(index, stage, home)
			continue
		if not route.crossing.is_empty():
			_advance_door(index, home, delta)
			continue
		if stage != route.stage:
			if not body.visible and not home.is_empty():
				_start_door(index, "exit")
				_advance_door(index, home, delta)
				continue
			_plan_route(index, stage)
		var before := body.position
		var remaining := delta * WALK_SPEED
		while remaining > 0.0 and route.cursor < route.path.size():
			var target := layout.grounded(Layout.world_at(route.path[route.cursor]))
			var gap := body.position.distance_to(target)
			if gap > 0.001:
				body.rotation.y = lerp_angle(body.rotation.y, atan2(target.x - body.position.x, target.z - body.position.z), minf(delta * 16.0, 1.0))
			body.position = body.position.move_toward(target, remaining)
			if gap > remaining:
				break
			remaining -= gap
			route.cursor += 1
		if stage == "home" and not home.is_empty() and route.cursor >= route.path.size():
			var porch := layout.grounded(home.position)
			var entry_cell := _walkable_cell(home.position)
			if body.position.is_equal_approx(layout.grounded(Layout.world_at(entry_cell))):
				if body.position.distance_to(porch) <= 0.5:
					body.position = porch
					_start_door(index, "enter")
		_animate_resident(index, delta, before.distance_squared_to(body.position) > 0.00001)


func _snap_routine(index: int, stage: String, home: Dictionary) -> void:
	var route := routes[index]
	var body := models[index]
	route.stage = stage
	route.path = []
	route.cursor = 0
	route.crossing = ""
	var cell := _walkable_cell(_destination(index, stage))
	body.visible = stage != "home" or home.is_empty()
	if not body.visible:
		body.position = layout.grounded(home.inside)
	elif not navigation.is_point_solid(cell):
		body.position = layout.grounded(Layout.world_at(cell))
	if home.get("door") != null:
		home.door.rotation.y = 0.0
	for foot in [feet[index * 2], feet[index * 2 + 1]]:
		foot.rotation.x = 0.0
	figures[index].position.y = 0.0
	figures[index].rotation.z = 0.0


func _plan_route(index: int, stage: String) -> void:
	var route := routes[index]
	var destination := _walkable_cell(_destination(index, stage))
	var origin := _walkable_cell(models[index].position)
	route.stage = stage
	route.cursor = 0
	route.path = []
	if not navigation.is_point_solid(origin) and not navigation.is_point_solid(destination):
		route.path = navigation.get_id_path(origin, destination)


func _start_door(index: int, direction: String) -> void:
	routes[index].crossing = direction
	routes[index].door_time = 0.0
	models[index].rotation.y = 0.0 if direction == "exit" else PI


func _advance_door(index: int, home: Dictionary, delta: float) -> void:
	var route := routes[index]
	var body := models[index]
	var exiting: bool = route.crossing == "exit"
	var elapsed: float = route.door_time + delta
	route.door_time = elapsed
	var walk_end := DOOR_OPEN_TIME + DOOR_STEP_TIME
	var progress := clampf((elapsed - DOOR_OPEN_TIME) / DOOR_STEP_TIME, 0.0, 1.0)
	var open := smoothstep(0.0, DOOR_OPEN_TIME, elapsed) * (1.0 - smoothstep(walk_end, walk_end + DOOR_CLOSE_TIME, elapsed))
	if home.get("door") != null:
		home.door.rotation.y = -open * 1.65
	var inside := layout.grounded(home.inside)
	var porch := layout.grounded(home.position)
	body.position = inside.lerp(porch, progress if exiting else 1.0 - progress)
	body.visible = elapsed >= DOOR_OPEN_TIME if exiting else elapsed < walk_end
	_animate_resident(index, delta, elapsed >= DOOR_OPEN_TIME and elapsed < walk_end)
	if elapsed >= walk_end + DOOR_CLOSE_TIME:
		route.crossing = ""
		if exiting:
			route.stage = ""  # Reevaluate the destination after crossing the threshold.


func _animate_resident(index: int, delta: float, walking: bool) -> void:
	var route := routes[index]
	route.phase += delta * (13.0 if walking else 2.0)
	var swing := sin(float(route.phase)) * (0.52 if walking else 0.0)
	feet[index * 2].rotation.x = lerpf(feet[index * 2].rotation.x, swing, minf(delta * 18.0, 1.0))
	feet[index * 2 + 1].rotation.x = -feet[index * 2].rotation.x
	var idle_sway := sin(float(route.phase) * 0.75)
	figures[index].position.y = absf(swing) * 0.045 if walking else maxf(0.0, idle_sway) * 0.016
	figures[index].rotation.z = 0.0 if walking else idle_sway * 0.025


func nearby(at: Vector3) -> int:
	var nearest := -1
	var reach := 1.0
	for index in range(models.size()):
		if not models[index].visible or not routes[index].crossing.is_empty():
			continue
		var distance := at.distance_to(models[index].position)
		if distance < reach:
			nearest = index
			reach = distance
	return nearest


func affinity(index: int) -> int:
	return favor.get(residents[index].id, 0)


func change_affinity(index: int, amount: int) -> void:
	favor[residents[index].id] = clampi(affinity(index) + amount, -20, 100)


func visit(index: int, day: int) -> void:
	var id: String = residents[index].id
	if last_talk.get(id, 0) != day:
		last_talk[id] = day
		change_affinity(index, 2)


func gift(index: int, item: int, day: int) -> String:
	var resident := residents[index]
	if last_gift.get(resident.id, 0) == day:
		return ""
	last_gift[resident.id] = day
	if item == resident.gifts.favorite:
		change_affinity(index, 8)
		return resident.dialogue.favorite_gift
	if item == resident.gifts.disliked:
		change_affinity(index, -5)
		return resident.dialogue.disliked_gift
	change_affinity(index, 3)
	return "I'll find a use for this. Thank you."


func dialogue(index: int, day: int, hour: float) -> String:
	var resident := residents[index]
	var id: String = resident.id
	var lines: Dictionary = resident.dialogue
	if id == "iona" and resolution > 0:
		return event_reaction(index, true)
	if id == "iona" and evidence == 7:
		if day < hearing_day:
			return lines.waiting_hearing
		return lines.open_hearing
	if id == "iona":
		return lines.opening
	if EVIDENCE.has(id) and evidence & int(EVIDENCE[id]):
		return resident.dialogue.after_testimony
	if id == "mara" and can_start_supper(day, hour):
		return lines.supper_invitation
	if id == partner:
		return lines.partner
	if affinity(index) >= 10:
		return resident.dialogue.friendship
	return resident.dialogue.introduction


func can_start_supper(day: int, hour: float) -> bool:
	return supper == 0 and day >= 3 and hour >= 16.0


func event_reaction(index: int, hearing: bool) -> String:
	var lines: Dictionary = residents[index].dialogue
	if hearing and resolution > 0 and lines.has("hearings"):
		return lines.hearings[resolution - 1]
	if not hearing and supper > 0 and lines.has("supper_choices"):
		return lines.supper_choices[supper - 1]
	return lines.hearing if hearing else lines.supper


func state() -> Dictionary:
	return {"favor": favor, "talk": last_talk, "gifts": last_gift, "dates": dates,
		"evidence": evidence, "hearing_day": hearing_day, "resolution": resolution,
		"supper": supper, "supper_day": supper_day, "partner": partner,
		"town_event_host": town_event_host, "town_event_day": town_event_day,
		"town_event_seen": town_event_seen, "town_event_choice": town_event_choice}


func restore(data: Variant) -> void:
	if not data is Dictionary:
		return
	evidence = clampi(int(data.get("evidence", 0)), 0, 7)
	hearing_day = clampi(int(data.get("hearing_day", 0)), 0, 1000001)
	resolution = clampi(int(data.get("resolution", 0)), 0, 3)
	supper = clampi(int(data.get("supper", 0)), 0, 2)
	supper_day = clampi(int(data.get("supper_day", 0)), 0, 1000000)
	var saved_seen: Variant = data.get("town_event_seen")
	if saved_seen is Array:
		for host in saved_seen:
			if host is String and town_events.has(host) and not town_event_seen.has(host):
				town_event_seen.append(host)
	var saved_host: Variant = data.get("town_event_host")
	if saved_host is String and town_events.has(saved_host):
		town_event_host = saved_host
		town_event_day = clampi(int(data.get("town_event_day", 0)), 0, 1000000)
		town_event_choice = clampi(int(data.get("town_event_choice", -1)), -1, 1)
	var saved_partner: String = str(data.get("partner", ""))
	if resident_indices.has(saved_partner) and residents[resident_indices[saved_partner]].romance:
		partner = saved_partner
	for resident in residents:
		var id: String = resident.id
		var saved_dates: Variant = data.get("dates")
		if resident.romance and saved_dates is Dictionary and saved_dates.get(id) == true:
			dates[id] = true
		for pair in [[favor, "favor", -20, 100], [last_talk, "talk", 0, 1000000], [last_gift, "gifts", 0, 1000000]]:
			var values: Variant = data.get(pair[1])
			if values is Dictionary and values.get(id) is int:
				pair[0][id] = clampi(values[id], pair[2], pair[3])
