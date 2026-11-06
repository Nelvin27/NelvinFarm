extends Node3D

enum Plot { EMPTY, TILLED, PLANTED, WATERED, RIPE }
enum Tool { HANDS, HOE, WATERING_CAN, SICKLE }
enum Interaction { NONE, PLOT, SEEDS, FOOD, ENTER, EXIT, BED, REPAIR }

const EDGE_MARGIN := 0.3
const Save := preload("res://farm_save.gd")
const Orders := preload("res://farm_orders.gd")
const Weather := preload("res://valley_weather.gd")
const WorldLayout := preload("res://world_layout.gd")
const FarmAudio := preload("res://farm_audio.gd")
const Settings := preload("res://game_settings.gd")
const PauseControls := preload("res://pause_controls.gd")
const Voxels := preload("res://voxel_assets.gd")
const FarmMesh := preload("res://farm_mesh.gd")
const Scenery := preload("res://farm_scenery.gd")
const TOOL_NAMES := ["Empty hands", "Hoe", "Watering Can", "Sickle"]
const TOOL_ICONS := ["", "hoe", "watering_can", "sickle"]
const Catalog := preload("res://crop_catalog.gd")


class GrowingCrop:
	var id: int
	var remaining: int

	func _init(crop_id: int, nights: int) -> void:
		id = crop_id
		remaining = nights


const SEASON_SKY := ["#8eb5ac", "#83acb6", "#b0a18c", "#a7b7c4"]
const FarmClock := preload("res://farm_clock.gd")
const FOOD_PRICE := 2
const REPAIR_PRICE := 10
const COTTAGE_SCENE := preload("res://cottage_interior.tscn")
const InventoryGrid := preload("res://inventory_grid.gd")
const ActionMenu := preload("res://action_menu.gd")
const ACTION_MENU_SCENE := preload("res://action_menu.tscn")
const ROOM_ORIGIN := Vector3(0, 0, 160)
const ROOM_BOUNDS := Rect2(-3.05, -2.52, 6.1, 5.1)
const ROOM_OBSTACLES := [
	Rect2(-2.25, -2.33, 1.2, 1.8),
	Rect2(1.03, -1.185, 1.24, 0.85),
	Rect2(2.05, -2.42, 0.72, 0.7),
	Rect2(-0.895, -2.30, 0.53, 0.56),
]
const MarketMenu := preload("res://market_menu.gd")
const MARKET_MENU_SCENE := preload("res://market_menu.tscn")
const WALK_SPEED := 3.8
const WALK_ACCELERATION := 26.0
const WALK_BRAKING := 34.0
const PLOT_REACH := 1.0
const NO_PLOT := Vector2i(-1, -1)
const STRIDE_LENGTH := 0.85
const CAMERA_DISTANCE := 4.3
const CAMERA_SENSITIVITY := 0.003
const INK := Color("#273a31")
const CREAM := Color("#e8ddbf")

var settings := Settings.new()
var sound: FarmAudio
var layout := WorldLayout.new()
var pause_controls: PauseControls
var walk_velocity := Vector3.ZERO
var facing_angle := PI / 2.0
var plots: Dictionary[Vector2i, Plot] = {}
var day := 1
var harvested := 0
var completed_orders := 0
var weather: Weather
var journal: ActionMenu
var forecast_label: Label
var order_buttons: Array[Button] = []
var seed_bag: Dictionary[int, int] = {Catalog.TURNIP: 5}
var produce: Dictionary[int, int] = {}
var growing: Dictionary[Vector2i, GrowingCrop] = {}
var equipped_seed := Catalog.TURNIP
var equipped_tool := Tool.HOE
var tool_label: Label
var held_tools: Dictionary[Tool, Node3D] = {}
var season := Catalog.Season.SPRING
var crop_label: Label
var coins := 6
var rations := 2
var clock := FarmClock.new()
var cottage_repaired := false
var sun: DirectionalLight3D
var lighting: Environment
var hunger_meter: ProgressBar
var fatigue_meter: ProgressBar
var needs_label: Label
var visuals: Dictionary[Vector2i, Node3D] = {}
var avatar: Node3D
var farmer_model: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var walk_phase := 0.0
var walk_weight := 0.0
var work_pose := 0.0
var work_tween: Tween
var work_particles: CPUParticles3D
var work_particle_material: StandardMaterial3D
var camera: Camera3D
var camera_yaw := -PI / 2.0
var camera_pitch := deg_to_rad(35.0)
var marker: Node3D
var status_label: Label
var stats_label: Label
var stock_label: Label
var interaction_prompt: Label
var interior: Node3D
var indoors := false
var bed_point: Vector3
var exit_point: Vector3
var active_menu: Control
var food_menu: ActionMenu
var food_stock: Label
var buy_food_button: Button
var test_menu: ActionMenu
var inventory_menu: ActionMenu
var inventory_grid: InventoryGrid
var market: MarketMenu

var message := "Welcome to Clover Valley. Press J to see your first delivery orders."

@onready var scenery: Scenery = $Scenery


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or market == null:
		return
	if key.physical_keycode == KEY_F7:
		_toggle_menu(test_menu)
	elif key.physical_keycode == KEY_I:
		_toggle_menu(inventory_menu)
	elif key.physical_keycode == KEY_J:
		_toggle_menu(journal)
	elif key.physical_keycode == KEY_ESCAPE:
		if active_menu != null:
			_close_menu()
		else:
			_pause_game()
	elif active_menu in [market, food_menu] and key.physical_keycode == KEY_E:
		_close_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if active_menu != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _look(relative: Vector2) -> void:
	var sensitivity := CAMERA_SENSITIVITY * settings.sensitivity
	var vertical := -relative.y if settings.invert_y else relative.y
	camera_yaw = wrapf(camera_yaw - relative.x * sensitivity, -PI, PI)
	camera_pitch = clampf(camera_pitch + vertical * sensitivity, deg_to_rad(22.0), deg_to_rad(65.0))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if active_menu != null or key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_E:
			_interact()
		KEY_1, KEY_2, KEY_3, KEY_4:
			if _is_exhausted():
				_exhaustion_message()
			else:
				_equip_tool((key.physical_keycode - KEY_1) as Tool)
		_:
			return
	_refresh()


func _process(delta: float) -> void:
	if active_menu != null:
		return
	var horizontal := int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	horizontal -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	vertical -= int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))

	var distance := _advance_walk(Vector2i(horizontal, vertical), delta)
	_animate_walk(distance, delta)
	sound.walk(distance, indoors)
	_update_interaction_targets()
	_update_camera()
	clock.tick(delta, distance > 0.0)
	_update_daylight()
	if weather.emitting:
		weather.position = avatar.position + Vector3(0, 6.5, 0)
	_update_needs()


func _advance_walk(direction: Vector2i, delta: float) -> float:
	var desired := Vector3(direction.x, 0, direction.y).normalized().rotated(Vector3.UP, camera_yaw)
	var acceleration := WALK_BRAKING if direction == Vector2i.ZERO else WALK_ACCELERATION
	var speed := _walk_speed()
	walk_velocity = walk_velocity.move_toward(desired * speed, acceleration * delta)
	if direction != Vector2i.ZERO:
		facing_angle = atan2(desired.x, desired.z)

	var start := avatar.position
	var destination := start + walk_velocity * delta
	var room_offset := Vector2(ROOM_ORIGIN.x, ROOM_ORIGIN.z) if indoors else Vector2.ZERO
	var playable := (ROOM_BOUNDS if indoors else layout.bounds).grow(-EDGE_MARGIN)
	var next := (Vector2(destination.x, destination.z) - room_offset).clamp(playable.position, playable.end)
	var origin := Vector2(start.x, start.z) - room_offset
	var obstacles := ROOM_OBSTACLES if indoors else scenery.obstacles
	for obstacle: Rect2 in obstacles:
		next = _avoid_obstacle(obstacle, origin, next)
	next += room_offset
	avatar.position = Vector3(next.x, 0, next.y)
	if not is_equal_approx(destination.x, avatar.position.x):
		walk_velocity.x = 0.0
	if not is_equal_approx(destination.z, avatar.position.z):
		walk_velocity.z = 0.0
	return start.distance_to(avatar.position)


func _walk_speed() -> float:
	if clock.hunger < 20.0 or _is_exhausted():
		return WALK_SPEED * 0.70
	if clock.hunger < 45.0 or clock.fatigue >= FarmClock.SLEEP_FATIGUE:
		return WALK_SPEED * 0.86
	return WALK_SPEED


func _avoid_obstacle(obstacle: Rect2, start: Vector2, destination: Vector2) -> Vector2:
	# Resolve each axis separately so the farmer can slide along the edge.
	var bank := obstacle.grow(EDGE_MARGIN)
	if start.y > bank.position.y and start.y < bank.end.y:
		if start.x <= bank.position.x:
			destination.x = minf(destination.x, bank.position.x)
		elif start.x >= bank.end.x:
			destination.x = maxf(destination.x, bank.end.x)
	if destination.x > bank.position.x and destination.x < bank.end.x:
		if start.y <= bank.position.y:
			destination.y = minf(destination.y, bank.position.y)
		elif start.y >= bank.end.y:
			destination.y = maxf(destination.y, bank.end.y)
	return destination


func _animate_walk(distance: float, delta: float) -> void:
	avatar.rotation.y = lerp_angle(avatar.rotation.y, facing_angle, 1.0 - exp(-20.0 * delta))

	var target_weight := clampf(distance / (WALK_SPEED * delta), 0.0, 1.0) if delta > 0.0 else 0.0
	walk_weight = move_toward(walk_weight, target_weight, delta * 10.0)
	walk_phase = fposmod(walk_phase + distance * TAU / STRIDE_LENGTH, TAU)
	if walk_weight == 0.0:
		walk_phase = 0.0

	var swing := sin(walk_phase) * walk_weight
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		legs[index].rotation.x = swing * side * 0.65
		arms[index].rotation.x = -swing * side * 0.46
	arms[1].rotation.x += work_pose
	farmer_model.position.y = absf(sin(walk_phase)) * walk_weight * 0.045


func _update_camera() -> void:
	var back := Vector3.BACK.rotated(Vector3.UP, camera_yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, camera_yaw)
	var shoulder := avatar.position + Vector3.UP * 0.9 + right * 0.65
	var offset := (back * cos(camera_pitch) + Vector3.UP * sin(camera_pitch)) * CAMERA_DISTANCE
	camera.position = shoulder + offset
	camera.look_at(shoulder - back * 0.6)


func _target_plot() -> Vector2i:
	if indoors:
		return NO_PLOT
	var cell := _tile_at(avatar.position)
	var offset := avatar.position - _world(cell)
	var forward := avatar.transform.basis.z
	var step_x := int(signf(forward.x))
	var step_z := int(signf(forward.z))
	# Find the first tile boundary in the direction the visible model faces.
	var distance_x := INF
	var distance_z := INF
	if not is_zero_approx(forward.x):
		distance_x = (step_x * 0.5 - offset.x) / forward.x
	if not is_zero_approx(forward.z):
		distance_z = (step_z * 0.5 - offset.z) / forward.z
	var distance := minf(distance_x, distance_z)
	if distance > PLOT_REACH:
		return NO_PLOT
	if is_equal_approx(distance_x, distance):
		cell.x += step_x
	if is_equal_approx(distance_z, distance):
		cell.y += step_z
	return cell if visuals.has(cell) else NO_PLOT


func _required_tool(target: Vector2i) -> Tool:
	match plots.get(target, Plot.EMPTY):
		Plot.EMPTY:
			return Tool.HOE
		Plot.PLANTED:
			if growing[target].id != Catalog.GRASS:
				return Tool.WATERING_CAN
		Plot.RIPE:
			if Catalog.crops[growing[target].id].requires_sickle:
				return Tool.SICKLE
	return Tool.HANDS


func _work_plot() -> void:
	if _is_exhausted():
		_exhaustion_message()
		return
	var target := _target_plot()
	if target == NO_PLOT:
		message = "Face a nearby garden plot to work it."
		return

	var required := _required_tool(target)
	if required != Tool.HANDS and equipped_tool != required:
		message = "Equip the %s from your bag first." % TOOL_NAMES[required]
		return

	var action: Plot = plots.get(target, Plot.EMPTY)
	match action:
		Plot.EMPTY:
			plots[target] = Plot.TILLED
			sound.play_effect(FarmAudio.Effect.TILL)
			message = "Soil tilled. Use E again to plant the equipped seed."
		Plot.TILLED:
			var crop := Catalog.crops[equipped_seed]
			if not crop.grows_in(season):
				message = "That seed is out of season. Choose an in-season seed from your bag."
				return
			if seed_bag.get(equipped_seed, 0) == 0:
				message = "No %s seeds. Check your bag or visit the market." % crop.label
				return
			seed_bag[equipped_seed] -= 1
			growing[target] = GrowingCrop.new(equipped_seed, crop.harvest_day - 1)
			plots[target] = Plot.PLANTED
			sound.play_effect(FarmAudio.Effect.PLANT)
			if _rain_waters(equipped_seed):
				plots[target] = Plot.WATERED
				message = "%s planted and watered by rain." % crop.label
			elif equipped_seed == Catalog.GRASS:
				message = "%s planted. It grows without watering." % crop.label
			else:
				message = "%s planted. Press 3 to equip the Watering Can." % crop.label
		Plot.PLANTED:
			var plant := growing[target]
			var crop := Catalog.crops[plant.id]
			if not crop.grows_in(season):
				message = "%s is dormant until Spring." % crop.label
				return
			if plant.id == Catalog.GRASS:
				message = "Fodder Grass grows without watering."
				return
			plots[target] = Plot.WATERED
			sound.play_effect(FarmAudio.Effect.WATER)
			message = "%s watered. %d watered night(s) until harvest." % [crop.label, plant.remaining]
		Plot.WATERED:
			message = "Already watered. It will grow after you sleep."
			return
		Plot.RIPE:
			var plant := growing[target]
			var crop := Catalog.crops[plant.id]
			produce[plant.id] = produce.get(plant.id, 0) + 1
			harvested += 1
			sound.play_effect(FarmAudio.Effect.HARVEST)
			message = "%s harvested!" % crop.label
			if crop.regrowth > 0:
				plant.remaining = crop.regrowth
				plots[target] = Plot.PLANTED
			else:
				growing.erase(target)
				plots[target] = Plot.TILLED
	clock.do_farm_work()
	_show_plot(target)
	_animate_work(action, target)


func _animate_work(action: Plot, target: Vector2i) -> void:
	var angles := {Plot.EMPTY: -1.65, Plot.TILLED: -0.82, Plot.PLANTED: -1.18, Plot.RIPE: -1.08}
	var colors := {Plot.EMPTY: "#ae7956", Plot.TILLED: "#e0cb87", Plot.PLANTED: "#87bfd4", Plot.RIPE: "#f6d474"}
	if work_tween != null:
		work_tween.kill()
	work_tween = create_tween().set_trans(Tween.TRANS_SINE)
	work_tween.tween_property(self, "work_pose", angles[action], 0.12)
	work_tween.tween_property(self, "work_pose", 0.0, 0.28)
	work_particle_material.albedo_color = Color(colors[action])
	work_particles.position = _world(target) + Vector3.UP * 0.27
	work_particles.restart()


func _interaction(target: Vector2i) -> Interaction:
	var at := avatar.position
	if indoors:
		if at.distance_to(bed_point) <= 1.25:
			return Interaction.BED
		if at.distance_to(exit_point) <= 1.05:
			return Interaction.EXIT
		return Interaction.NONE

	var door_distance := at.distance_to(scenery.cottage_door)
	var repair_distance := at.distance_to(scenery.repair_sign)
	if not cottage_repaired and repair_distance <= 1.45 and repair_distance < door_distance:
		return Interaction.REPAIR
	if door_distance <= 1.4:
		return Interaction.ENTER
	if not cottage_repaired and repair_distance <= 1.45:
		return Interaction.REPAIR
	if at.distance_to(scenery.food_counter) <= 1.6:
		return Interaction.FOOD
	if scenery.market_area.has_point(Vector2(at.x, at.z)):
		return Interaction.SEEDS
	return Interaction.PLOT if target != NO_PLOT else Interaction.NONE


func _is_exhausted() -> bool:
	return clock.fatigue >= FarmClock.EXHAUSTED


func _exhaustion_message() -> void:
	message = "You're exhausted. Eat something or return to bed."


func _blocked_by_fatigue(action: Interaction) -> bool:
	return _is_exhausted() and action in [Interaction.PLOT, Interaction.SEEDS, Interaction.FOOD, Interaction.REPAIR]


func _interact() -> void:
	var action := _interaction(_target_plot())
	if _blocked_by_fatigue(action):
		_exhaustion_message()
		return
	match action:
		Interaction.PLOT:
			_work_plot()
		Interaction.SEEDS:
			_open_market()
		Interaction.FOOD:
			_show_menu(food_menu)
			food_menu.focus_first_action()
		Interaction.ENTER:
			_set_indoors(true)
		Interaction.EXIT:
			_set_indoors(false)
		Interaction.BED:
			_try_sleep()
		Interaction.REPAIR:
			_repair_cottage()


func _set_indoors(entering: bool) -> void:
	indoors = entering
	interior.visible = indoors
	walk_velocity = Vector3.ZERO
	facing_angle = PI if indoors else 0.0
	avatar.rotation.y = facing_angle
	camera_yaw = 0.0 if indoors else PI
	avatar.position = (interior.get_node("Entry") as Marker3D).global_position if indoors else scenery.cottage_door + Vector3(0, 0, 0.38)
	message = "Home Cottage" if indoors else "Clover Valley"
	_update_weather()
	_update_daylight()
	_update_camera()


func _try_sleep() -> void:
	if not indoors or avatar.position.distance_to(bed_point) > 1.25:
		return
	if clock.fatigue < FarmClock.SLEEP_FATIGUE:
		message = "Too early to sleep. Fatigue must reach %d%%." % int(FarmClock.SLEEP_FATIGUE)
		return
	clock.rest()
	walk_velocity = Vector3.ZERO
	_advance_day()
	_update_daylight()
	sound.play_effect(FarmAudio.Effect.SLEEP)
	if _save_farm() != OK:
		message += "  ·  Autosave failed."


func _eat_item(kind: InventoryGrid.Kind, id: int) -> void:
	if clock.hunger >= FarmClock.FULL and clock.fatigue <= 0.0:
		message = "You're already full and rested."
		return
	if kind == InventoryGrid.Kind.BREAD and rations > 0:
		rations -= 1
		clock.eat(35.0, 22.0)
		sound.play_effect(FarmAudio.Effect.EAT)
		message = "You ate bread and recovered 22 fatigue."
	elif kind == InventoryGrid.Kind.HARVEST and produce.get(id, 0) > 0 and Catalog.crops[id].edible:
		produce[id] -= 1
		clock.eat(25.0, 14.0)
		sound.play_effect(FarmAudio.Effect.EAT)
		message = "You ate a %s and recovered 14 fatigue." % Catalog.crops[id].label.to_lower()


func _repair_cottage() -> void:
	if indoors or avatar.position.distance_to(scenery.repair_sign) > 1.45:
		message = "Return to the cottage to make repairs."
	elif cottage_repaired:
		message = "The cottage has already been repaired."
	elif coins < REPAIR_PRICE:
		message = "Cottage repairs cost %d coins. Sell turnips at the market." % REPAIR_PRICE
	else:
		coins -= REPAIR_PRICE
		cottage_repaired = true
		_show_cottage_repair()
		message = "Cottage repaired! The roof and window are fixed."


func _show_cottage_repair() -> void:
	scenery.show_cottage_repair()
	(interior.get_node("Damaged") as Node3D).hide()
	(interior.get_node("Repaired") as Node3D).show()


func _update_weather() -> void:
	weather.position = avatar.position + Vector3(0, 6.5, 0)
	weather.apply(Weather.forecast(day), not indoors)


func _rain_waters(crop_id: int) -> bool:
	return weather.kind == Weather.Kind.RAIN and crop_id != Catalog.GRASS


func _advance_day() -> void:
	day += 1
	var next_season := Catalog.season_for(day)
	var changed := season != next_season
	season = next_season
	if changed:
		completed_orders = 0
	_update_weather()
	var ripe := 0
	var watered := 0
	for tile in growing.keys():
		var plant := growing[tile]
		var crop := Catalog.crops[plant.id]
		var previous: Plot = plots[tile]
		if not crop.grows_in(season):
			plots[tile] = Plot.TILLED
			if plant.id == Catalog.GRASS:
				plots[tile] = Plot.PLANTED
			else:
				growing.erase(tile)
		elif plots[tile] == Plot.WATERED or (plant.id == Catalog.GRASS and plots[tile] == Plot.PLANTED):
			plant.remaining = maxi(0, plant.remaining - 1)
			plots[tile] = Plot.RIPE if plant.remaining == 0 else Plot.PLANTED
			ripe += int(plots[tile] == Plot.RIPE)
		if plots[tile] == Plot.PLANTED and _rain_waters(plant.id) and crop.grows_in(season):
			plots[tile] = Plot.WATERED
			watered += 1
		if previous != plots[tile] or previous == Plot.WATERED or changed:
			_show_plot(tile)

	message = "Good morning! Remember to water your crops."
	if ripe > 0:
		message = "Good morning! %d plot(s) are ready to harvest." % ripe
	if changed:
		scenery.set_ground_season(season)
		message = "%s has begun. New delivery orders are in your journal." % Catalog.SEASONS[season]
	if watered > 0:
		message += " Rain watered %d plot(s)." % watered


func _ready() -> void:
	var load_error := settings.read_config()
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Could not read Clover Patch settings.")
	var world_error := layout.read(WorldLayout.DEFAULT_PATH)
	if world_error != OK:
		push_error("Clover Valley layout failed to load: %s" % error_string(world_error))
		get_tree().quit(1)
		return
	scenery.rebuild(layout)
	_build_world()
	_build_hud()
	sound = FarmAudio.new()
	add_child(sound)
	pause_controls = PauseControls.new()
	add_child(pause_controls)
	pause_controls.resume_requested.connect(_resume_game)
	pause_controls.settings_changed.connect(_save_settings)
	pause_controls.save_requested.connect(_manual_save)
	_apply_settings()
	sound.music.play()
	avatar.position = layout.anchor("spawn")
	avatar.rotation.y = facing_angle
	_load_farm()
	_update_weather()
	_refresh()
	_update_daylight()
	_update_camera()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _manual_save() -> void:
	var error := _save_farm()
	pause_controls.save_status.text = "Farm saved." if error == OK else "Could not save the farm."


func _save_farm() -> Error:
	# Reconcile stacks before saving so sales and deliveries cannot leave stale quantities.
	_update_bag()
	var beds := {}
	for tile in plots:
		var plant: GrowingCrop = growing.get(tile)
		beds[tile] = Vector3i(plots[tile], plant.id if plant else -1, plant.remaining if plant else 0)
	return Save.write({
		"day": day, "harvested": harvested, "orders": completed_orders,
		"coins": coins, "bread": rations, "seeds": seed_bag, "produce": produce,
		"tool": equipped_tool, "seed": equipped_seed, "slots": inventory_grid.save_slots(),
		"hour": clock.hour, "hunger": clock.hunger, "fatigue": clock.fatigue,
		"repaired": cottage_repaired, "plots": beds, "indoors": indoors,
		"position": avatar.position, "facing": facing_angle,
		"camera_yaw": camera_yaw, "camera_pitch": camera_pitch,
	})


func _load_farm() -> void:
	var state := Save.read()
	if state.is_empty():
		return
	day = maxi(1, Save.count(state.get("day"), 1000000, 1))
	season = Catalog.season_for(day)
	harvested = Save.count(state.get("harvested"), 1000000)
	completed_orders = Save.count(state.get("orders"), 7)
	coins = Save.count(state.get("coins"), 1000000, coins)
	rations = Save.count(state.get("bread"), 100000, rations)
	_restore_stock(seed_bag, state.get("seeds"))
	_restore_stock(produce, state.get("produce"))
	equipped_seed = Save.count(state.get("seed"), Catalog.crops.size() - 1)
	equipped_tool = Save.count(state.get("tool"), Tool.SICKLE, Tool.HOE) as Tool
	clock.hour = Save.meter(state.get("hour"), FarmClock.MORNING, FarmClock.LAST_HOUR, clock.hour)
	clock.hunger = Save.meter(state.get("hunger"), 0.0, FarmClock.FULL, clock.hunger)
	clock.fatigue = Save.meter(state.get("fatigue"), 0.0, FarmClock.FULL, clock.fatigue)
	cottage_repaired = state.get("repaired") == true
	if cottage_repaired:
		_show_cottage_repair()
	scenery.set_ground_season(season)
	_restore_plots(state.get("plots"))
	_restore_position(state)
	inventory_grid.restore_slots(state.get("slots"))
	_update_bag()
	_update_held_tool()
	message = "Welcome back to Clover Valley."


func _restore_stock(stock: Dictionary[int, int], saved: Variant) -> void:
	if not saved is Dictionary:
		return
	stock.clear()
	for id in range(Catalog.crops.size()):
		var quantity := Save.count(saved.get(id), 100000)
		if quantity > 0:
			stock[id] = quantity


func _restore_plots(saved: Variant) -> void:
	if not saved is Dictionary:
		return
	for tile in visuals:
		var bed: Variant = saved.get(tile)
		if not bed is Vector3i or bed.x < Plot.TILLED or bed.x > Plot.RIPE:
			continue
		if bed.x == Plot.TILLED:
			plots[tile] = Plot.TILLED
		elif bed.y >= 0 and bed.y < Catalog.crops.size():
			var crop := Catalog.crops[bed.y]
			plots[tile] = bed.x as Plot
			var nights := clampi(bed.z, 1, maxi(crop.harvest_day - 1, crop.regrowth))
			growing[tile] = GrowingCrop.new(bed.y, 0 if bed.x == Plot.RIPE else nights)
		_show_plot(tile)


func _restore_position(state: Dictionary) -> void:
	if state.get("indoors") == true:
		_set_indoors(true)
	var saved: Variant = state.get("position")
	if saved is Vector3 and saved.is_finite():
		var room_offset := Vector2(ROOM_ORIGIN.x, ROOM_ORIGIN.z) if indoors else Vector2.ZERO
		var point := Vector2(saved.x, saved.z) - room_offset
		var playable := (ROOM_BOUNDS if indoors else layout.bounds).grow(-EDGE_MARGIN)
		var obstacles := ROOM_OBSTACLES if indoors else scenery.obstacles
		if playable.grow(0.001).has_point(point):
			var obstructed := false
			for obstacle: Rect2 in obstacles:
				if obstacle.grow(EDGE_MARGIN - 0.001).has_point(point):
					obstructed = true
					break
			if not obstructed:
				avatar.position = Vector3(saved.x, 0.0, saved.z)
	facing_angle = Save.meter(state.get("facing"), -PI, PI, facing_angle)
	avatar.rotation.y = facing_angle
	camera_yaw = Save.meter(state.get("camera_yaw"), -PI, PI, camera_yaw)
	camera_pitch = Save.meter(state.get("camera_pitch"), deg_to_rad(22), deg_to_rad(65), camera_pitch)


func _apply_settings() -> void:
	sound.apply_mix(settings.master_volume, settings.music_volume, settings.effects_volume)
	lighting.adjustment_enabled = not is_equal_approx(settings.brightness, 1.0)
	lighting.adjustment_brightness = settings.brightness
	var viewport := get_viewport()
	viewport.scaling_3d_scale = settings.render_height / 1080.0
	viewport.msaa_3d = settings.msaa
	sun.shadow_enabled = settings.shadows
	if DisplayServer.get_name() != "headless":
		var mode := Window.MODE_FULLSCREEN if settings.fullscreen else Window.MODE_WINDOWED
		if get_window().mode != mode:
			get_window().mode = mode
		var vsync := DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED
		var window_id := get_window().get_window_id()
		if DisplayServer.window_get_vsync_mode(window_id) != vsync:
			DisplayServer.window_set_vsync_mode(vsync, window_id)


func _save_settings() -> void:
	_apply_settings()
	if settings.write_config() != OK:
		push_warning("Could not save Clover Patch settings.")


func _pause_game() -> void:
	get_tree().paused = true
	walk_velocity = Vector3.ZERO
	interaction_prompt.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_controls.open(settings)
	sound.play_effect(FarmAudio.Effect.MENU)


func _resume_game() -> void:
	pause_controls.close()
	get_tree().paused = false
	sound.play_effect(FarmAudio.Effect.MENU)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_interaction_targets()


func _world(tile: Vector2i) -> Vector3:
	return WorldLayout.world_at(tile)


func _tile_at(at: Vector3) -> Vector2i:
	return WorldLayout.tile_at(at)


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	lighting = Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color("#8eb5ac")
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("#e7e5db")
	lighting.ambient_light_energy = 0.48
	environment.environment = lighting
	add_child(environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_color = Color("#fff2dd")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 56.0
	camera.far = 80.0
	add_child(camera)
	camera.make_current()

	for entity in layout.entities:
		if entity["kind"] == "plot":
			_add_plot(_tile_at(WorldLayout.position_of(entity)))
	interior = COTTAGE_SCENE.instantiate() as Node3D
	interior.position = ROOM_ORIGIN
	add_child(interior)
	interior.hide()
	bed_point = (interior.get_node("Bedside") as Marker3D).global_position
	exit_point = (interior.get_node("Exit") as Marker3D).global_position

	marker = Node3D.new()
	add_child(marker)
	for side in [-1.0, 1.0]:
		FarmMesh.box(marker, Vector3(0, 0.15, side * 0.46), Vector3(0.95, 0.035, 0.035), "#dfcb87", true)
		FarmMesh.box(marker, Vector3(side * 0.46, 0.15, 0), Vector3(0.035, 0.035, 0.95), "#dfcb87", true)

	avatar = Node3D.new()
	add_child(avatar)
	_build_farmer()
	weather = Weather.new()
	add_child(weather)

	work_particles = CPUParticles3D.new()
	work_particles.emitting = false
	work_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	work_particles.one_shot = true
	work_particles.amount = 12
	work_particles.lifetime = 0.5
	work_particles.explosiveness = 1.0
	work_particles.direction = Vector3.UP
	work_particles.spread = 58.0
	work_particles.initial_velocity_min = 0.85
	work_particles.initial_velocity_max = 1.8
	work_particles.gravity = Vector3(0, -5.5, 0)
	work_particles.scale_amount_min = 0.55
	work_particles.scale_amount_max = 1.2
	work_particle_material = StandardMaterial3D.new()
	work_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var chip := BoxMesh.new()
	chip.size = Vector3(0.045, 0.045, 0.045)
	chip.material = work_particle_material
	work_particles.mesh = chip
	add_child(work_particles)


func _add_plot(tile: Vector2i) -> void:
	var plot := Node3D.new()
	plot.position = _world(tile)
	add_child(plot)
	visuals[tile] = plot
	_show_plot(tile)


func _update_daylight() -> void:
	var daylight := clock.daylight()
	lighting.background_color = Color("#332c29") if indoors else Color("#25364d").lerp(Color(SEASON_SKY[season]), daylight)
	lighting.ambient_light_color = Color("#9ab0df").lerp(Color("#e7e5db"), daylight)
	lighting.ambient_light_energy = lerpf(0.27, 0.48, daylight)
	sun.light_color = Color("#9bb4ec").lerp(Color("#fff2dd"), daylight)
	sun.light_energy = lerpf(0.08, 0.72, daylight)
	sun.rotation_degrees.x = lerpf(-25.0, -55.0, daylight)
	if not indoors and weather.kind != Weather.Kind.CLEAR:
		lighting.background_color = lighting.background_color.lerp(Color("#687e89"), daylight * 0.52)
		sun.light_energy *= 0.60
		lighting.ambient_light_color = lighting.ambient_light_color.lerp(Color("#bdd3df"), 0.38)


func _build_farmer() -> void:
	farmer_model = Node3D.new()
	avatar.add_child(farmer_model)
	FarmMesh.box(farmer_model, Vector3(0, 0.40, 0), Vector3(0.43, 0.48, 0.32), "#438880")
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.11, 0.31, 0)
		farmer_model.add_child(leg)
		legs.append(leg)
		FarmMesh.box(leg, Vector3(0, -0.065, 0), Vector3(0.15, 0.21, 0.16), "#376d6b")
		FarmMesh.box(leg, Vector3(0, -0.17, 0.04), Vector3(0.17, 0.22, 0.25), "#745449")

		var arm := Node3D.new()
		arm.position = Vector3(side * 0.21, 0.52, 0)
		farmer_model.add_child(arm)
		arms.append(arm)
		FarmMesh.box(arm, Vector3(side * 0.01, -0.12, 0), Vector3(0.15, 0.23, 0.17), "#f2b98d")
	FarmMesh.box(farmer_model, Vector3(0, 0.76, -0.075), Vector3(0.61, 0.49, 0.42), "#784f40")
	FarmMesh.box(farmer_model, Vector3(0, 0.74, 0.065), Vector3(0.55, 0.41, 0.43), "#f7c9a0")
	for side in [-1.0, 1.0]:
		FarmMesh.box(farmer_model, Vector3(side * 0.115, 0.77, 0.283), Vector3(0.048, 0.065, 0.017), "#413431")
		FarmMesh.box(farmer_model, Vector3(side * 0.169, 0.69, 0.283), Vector3(0.070, 0.032, 0.016), "#eaa2a3")
	FarmMesh.box(farmer_model, Vector3(0, 0.975, 0), Vector3(0.87, 0.10, 0.72), "#f3cd79")
	FarmMesh.box(farmer_model, Vector3(0, 1.10, -0.015), Vector3(0.60, 0.19, 0.55), "#ebba61")

	_build_held_tools()


func _build_held_tools() -> void:
	for id: Tool in [Tool.HOE, Tool.WATERING_CAN, Tool.SICKLE]:
		var model := Node3D.new()
		model.position = Vector3(0.04, -0.16, 0.035)
		arms[1].add_child(model)
		held_tools[id] = model
	var hoe := held_tools[Tool.HOE]
	FarmMesh.box(hoe, Vector3(0, 0.07, 0), Vector3(0.045, 0.53, 0.045), "#a97d55")
	FarmMesh.box(hoe, Vector3(0, -0.19, 0.075), Vector3(0.20, 0.045, 0.15), "#9eada6")
	var can := held_tools[Tool.WATERING_CAN]
	FarmMesh.box(can, Vector3(0.02, -0.08, 0.06), Vector3(0.19, 0.20, 0.23), "#789d8c")
	var spout := FarmMesh.box(can, Vector3(0.02, -0.045, 0.23),
		Vector3(0.05, 0.055, 0.22), "#789d8c")
	spout.rotation.x = -0.38
	FarmMesh.box(can, Vector3(0.02, 0.025, 0.045), Vector3(0.11, 0.04, 0.16), "#405e55")
	var sickle := held_tools[Tool.SICKLE]
	FarmMesh.box(sickle, Vector3(0, 0, 0), Vector3(0.05, 0.22, 0.05), "#a97d55")
	var blade := FarmMesh.box(sickle, Vector3(0, 0.14, 0.075),
		Vector3(0.035, 0.075, 0.18), "#adbdb6")
	blade.rotation.x = 0.48
	FarmMesh.box(sickle, Vector3(0, 0.12, 0.16), Vector3(0.032, 0.10, 0.045), "#adbdb6")
	_update_held_tool()


func _update_held_tool() -> void:
	for id in held_tools:
		held_tools[id].visible = id == equipped_tool


func _show_plot(tile: Vector2i) -> void:
	var plot: Node3D = visuals[tile]
	for mesh in plot.get_children():
		plot.remove_child(mesh)
		mesh.queue_free()

	var state: int = plots.get(tile, Plot.EMPTY)
	var soil := "#ffffff"
	if state != Plot.EMPTY:
		soil = "#ddc5b3"
	if state == Plot.WATERED:
		soil = "#998474"
	FarmMesh.tile(plot, Vector3(0, 0.042, 0), Vector3(0.97, 0.15, 0.97), Voxels.SOIL, soil)
	if state != Plot.EMPTY:
		for offset in [-0.26, 0.0, 0.26]:
			FarmMesh.tile(plot, Vector3(0, 0.12, offset), Vector3(0.75, 0.045, 0.09), Voxels.SOIL, soil)
	if not growing.has(tile):
		return
	var plant := growing[tile]
	var crop := Catalog.crops[plant.id]
	if not crop.grows_in(season):
		return
	var size := 0.13 + 0.24 * clampf(1.0 - float(plant.remaining) / (crop.harvest_day - 1), 0.0, 1.0)
	Voxels.crop(plot, plant.id, crop.color, size, state == Plot.RIPE)

func _update_interaction_targets() -> void:
	var target := _target_plot()
	marker.visible = target != NO_PLOT
	if marker.visible:
		marker.position = _world(target)
	crop_label.text = ""
	if growing.has(target):
		var plant := growing[target]
		var name := Catalog.crops[plant.id].label
		crop_label.text = "%s  ·  %d night(s) left" % [name, plant.remaining] if plant.remaining > 0 else "%s  ·  Ready" % name
		if not Catalog.crops[plant.id].grows_in(season):
			crop_label.text = "%s  ·  Dormant" % name
	var prompt := ""
	var action := _interaction(target)
	match action:
		Interaction.PLOT:
			var plot_actions := ["Till soil", "Plant seed", "Water crop", "Check crop", "Harvest"]
			prompt = plot_actions[plots.get(target, Plot.EMPTY)]
		Interaction.SEEDS:
			prompt = "Seed market"
		Interaction.FOOD:
			prompt = "Valley Bakery"
		Interaction.ENTER:
			prompt = "Enter cottage"
		Interaction.EXIT:
			prompt = "Leave cottage"
		Interaction.BED:
			prompt = "Sleep" if clock.fatigue >= FarmClock.SLEEP_FATIGUE else "Bed · requires 65% fatigue"
		Interaction.REPAIR:
			prompt = "Repair cottage · %d coins" % REPAIR_PRICE
	var required := _required_tool(target) if action == Interaction.PLOT else Tool.HANDS
	if _blocked_by_fatigue(action):
		interaction_prompt.text = "Exhausted  ·  Eat or sleep before working"
	elif required != Tool.HANDS and equipped_tool != required:
		interaction_prompt.text = "%s needed  ·  Press %d to equip" % [TOOL_NAMES[required], required + 1]
	else:
		interaction_prompt.text = "E   " + prompt
	interaction_prompt.visible = active_menu == null and not prompt.is_empty()


func _refresh() -> void:
	_update_interaction_targets()
	_update_needs()
	status_label.text = message
	tool_label.text = "Tool  /  " + TOOL_NAMES[equipped_tool]
	stock_label.text = "%s seeds ×%d   /   %d coins" % [
		Catalog.crops[equipped_seed].label, seed_bag.get(equipped_seed, 0), coins]
	if market.visible:
		market.update_stock(stock_label.text, coins, _harvest_value())
	if food_menu.visible:
		food_stock.text = "%d coins   /   %d bread in bag" % [coins, rations]
		buy_food_button.disabled = coins < FOOD_PRICE
	if inventory_menu.visible:
		_update_bag()
	if journal.visible:
		_update_journal()


func _update_needs() -> void:
	stats_label.text = "%s %d  ·  %s  ·  %s" % [
		Catalog.SEASONS[season], Catalog.day_of_season(day), clock.clock_text(), Weather.NAMES[weather.kind]]
	hunger_meter.value = clock.hunger
	fatigue_meter.value = clock.fatigue
	var appetite := "Fed"
	if clock.hunger < 20.0:
		appetite = "Very hungry"
	elif clock.hunger < 45.0:
		appetite = "Hungry"
	var rest := "Rested"
	if _is_exhausted():
		rest = "Exhausted"
	elif clock.fatigue >= FarmClock.SLEEP_FATIGUE:
		rest = "Tired"
	elif clock.fatigue >= 30.0:
		rest = "Getting tired"
	needs_label.text = "%s   /   %s" % [appetite, rest]
	var warning := clock.hunger < 45.0 or clock.fatigue >= FarmClock.SLEEP_FATIGUE
	needs_label.add_theme_color_override("font_color", Color("#e8a16e") if warning else CREAM)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_panel(layer, Vector2(32, 28), Vector2(356, 166))
	_hud_panel(layer, Vector2(1408, 28), Vector2(480, 100))
	_hud_panel(layer, Vector2(1408, 143), Vector2(480, 134))
	_hud_panel(layer, Vector2(32, 932), Vector2(1180, 67))
	_hud_text(layer, Vector2(56, 40), "CLOVER PATCH", 38)
	_hud_text(layer, Vector2(58, 87), "Clover Valley", 22)
	tool_label = _hud_text(layer, Vector2(58, 117), "", 20)
	_hud_text(layer, Vector2(58, 151), "1–4 Tools   ·   I Bag   ·   J Journal", 18)
	stats_label = _hud_text(layer, Vector2(1432, 43), "", 23)
	_hud_text(layer, Vector2(1432, 151), "FOOD", 19)
	_hud_text(layer, Vector2(1432, 187), "FATIGUE", 19)
	hunger_meter = _make_meter(layer, Vector2(1540, 156), Color("#80a668"))
	fatigue_meter = _make_meter(layer, Vector2(1540, 192), Color("#b78c66"))
	needs_label = _hud_text(layer, Vector2(1432, 230), "", 19)
	stock_label = _hud_text(layer, Vector2(1432, 80), "", 22)
	interaction_prompt = _hud_text(layer, Vector2(56, 877), "", 27)
	interaction_prompt.add_theme_color_override("font_outline_color", INK)
	interaction_prompt.add_theme_constant_override("outline_size", 10)
	crop_label = _hud_text(layer, Vector2(56, 840), "", 25)
	crop_label.add_theme_color_override("font_outline_color", INK)
	crop_label.add_theme_constant_override("outline_size", 10)
	status_label = _hud_text(layer, Vector2(56, 943), "", 22)
	status_label.custom_minimum_size.x = 1128
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market = MARKET_MENU_SCENE.instantiate() as MarketMenu
	layer.add_child(market)
	market.buy_requested.connect(_buy_seed)
	market.sell_requested.connect(_sell_harvest)
	market.close_requested.connect(_close_menu)
	_build_action_menus(layer)


func _make_meter(layer: CanvasLayer, at: Vector2, color: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.position = at
	meter.size = Vector2(318, 22)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#1c2a25")
	track.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	meter.add_theme_stylebox_override("background", track)
	meter.add_theme_stylebox_override("fill", fill)
	layer.add_child(meter)
	return meter


func _build_action_menus(layer: CanvasLayer) -> void:
	food_menu = _new_menu(layer, "Valley Bakery")
	food_stock = Label.new()
	food_stock.add_theme_font_size_override("font_size", 22)
	food_menu.rows.add_child(food_stock)
	buy_food_button = food_menu.add_action("Buy bread · %d coins" % FOOD_PRICE, _buy_food)
	food_menu.add_action("Close", _close_menu)

	inventory_menu = _new_menu(layer, "Farm Bag")
	inventory_menu.offset_left = -385
	inventory_menu.offset_right = 385
	inventory_menu.offset_top = -280
	inventory_menu.offset_bottom = 280
	inventory_grid = InventoryGrid.new()
	inventory_menu.rows.add_child(inventory_grid)
	inventory_grid.item_used.connect(_use_bag_item)
	inventory_menu.add_action("Close", _close_menu)

	journal = _new_menu(layer, "Valley Journal")
	journal.offset_left = -395
	journal.offset_right = 395
	journal.offset_top = -215
	journal.offset_bottom = 215
	forecast_label = Label.new()
	forecast_label.add_theme_font_size_override("font_size", 22)
	journal.rows.add_child(forecast_label)
	for index in range(3):
		var delivery := journal.add_action("", _deliver_order.bind(index))
		delivery.expand_icon = true
		delivery.add_theme_constant_override("icon_max_width", 34)
		delivery.add_theme_constant_override("h_separation", 12)
		order_buttons.append(delivery)
	journal.add_action("Close", _close_menu)

	test_menu = _new_menu(layer, "Farm Test Menu")
	test_menu.add_action("Add 100 coins", func() -> void:
		coins += 100
		_refresh())
	test_menu.add_action("Refill food meter and clear fatigue", _test_restore)
	test_menu.add_action("Set very hungry and exhausted", _test_needs)
	test_menu.add_action("Set time to 22:00", _test_night)
	test_menu.add_action("Advance one day", _test_advance_day)
	test_menu.add_action("Go to cottage interior", _test_go_home)
	test_menu.add_action("Close", _close_menu)


func _new_menu(layer: CanvasLayer, title: String) -> ActionMenu:
	var menu := ACTION_MENU_SCENE.instantiate() as ActionMenu
	layer.add_child(menu)
	menu.title.text = title
	return menu


func _update_journal() -> void:
	forecast_label.text = "Today: %s  ·  Tomorrow: %s  ·  Crops harvested: %d\n%s deliveries · fulfilled from your bag" % [
		Weather.NAMES[weather.kind], Weather.NAMES[Weather.forecast(day + 1)], harvested, Catalog.SEASONS[season]]
	for index in range(order_buttons.size()):
		var order: Vector3i = Orders.BOARDS[season][index]
		var delivered := bool(completed_orders & (1 << index))
		var stock := _delivery_stock(order.x)
		var button := order_buttons[index]
		var icon := "bread" if order.x == Orders.BREAD else "crop_%02d" % order.x
		button.icon = load("res://assets/items/%s.svg" % icon) as Texture2D
		button.add_theme_color_override("font_disabled_color", Color("#9ec997") if delivered else Color("#b7c4b6"))
		button.text = "%s ×%d  ·  %d coins  ·  %s" % [
			Orders.item_name(order.x), order.y, order.z,
			"Delivered" if delivered else "%d/%d in bag" % [mini(stock, order.y), order.y]]
		button.disabled = delivered or stock < order.y or _is_exhausted()
		button.tooltip_text = "Eat or sleep before making a delivery." if _is_exhausted() else ""


func _delivery_stock(id: int) -> int:
	return rations if id == Orders.BREAD else produce.get(id, 0)


func _deliver_order(index: int) -> void:
	var flag := 1 << index
	var order: Vector3i = Orders.BOARDS[season][index]
	if _is_exhausted() or completed_orders & flag or _delivery_stock(order.x) < order.y:
		return
	if order.x == Orders.BREAD:
		rations -= order.y
	else:
		produce[order.x] -= order.y
	coins += order.z
	completed_orders |= flag
	sound.play_effect(FarmAudio.Effect.TRADE)
	message = "Delivered %s ×%d and earned %d coins." % [Orders.item_name(order.x), order.y, order.z]
	_refresh()
	journal.focus_first_action()


func _equip_tool(tool: Tool) -> void:
	equipped_tool = tool
	_update_held_tool()
	message = "Tool: %s." % TOOL_NAMES[tool]


func _update_bag() -> void:
	var items: Array[InventoryGrid.Stack] = []
	for id in range(Tool.HOE, Tool.SICKLE + 1):
		var equipped := id == equipped_tool
		var action := "Unequip tool" if equipped else "Equip tool"
		inventory_grid.add_stacks(items, InventoryGrid.Kind.TOOL, id, TOOL_NAMES[id], 1,
			TOOL_ICONS[id], "" if _is_exhausted() else action, equipped)
	var can_eat := clock.hunger < FarmClock.FULL or clock.fatigue > 0.0
	inventory_grid.add_stacks(items, InventoryGrid.Kind.BREAD, 0, "Bread", rations,
		"bread", "Eat bread" if can_eat else "")
	for id in range(Catalog.crops.size()):
		var crop := Catalog.crops[id]
		var action := "Equip seed" if crop.grows_in(season) and not _is_exhausted() else ""
		inventory_grid.add_stacks(items, InventoryGrid.Kind.SEED, id, crop.label + " seeds",
			seed_bag.get(id, 0), "seed_%02d" % id, action, id == equipped_seed)
	for id in range(Catalog.crops.size()):
		var crop := Catalog.crops[id]
		var action := "Eat " + crop.label.to_lower() if can_eat and crop.edible else ""
		inventory_grid.add_stacks(items, InventoryGrid.Kind.HARVEST, id, crop.label,
			produce.get(id, 0), "crop_%02d" % id, action)
	inventory_grid.show_stacks(items)


func _use_bag_item(kind: InventoryGrid.Kind, id: int) -> void:
	if kind == InventoryGrid.Kind.TOOL:
		if not _is_exhausted() and id >= Tool.HOE and id <= Tool.SICKLE:
			_equip_tool(Tool.HANDS if id == equipped_tool else id as Tool)
	elif kind == InventoryGrid.Kind.SEED:
		if not _is_exhausted() and seed_bag.get(id, 0) > 0 and Catalog.crops[id].grows_in(season):
			equipped_seed = id
			message = "Equipped %s seeds." % Catalog.crops[id].label
	else:
		_eat_item(kind, id)
	_refresh()


func _buy_food() -> void:
	if coins < FOOD_PRICE:
		return
	coins -= FOOD_PRICE
	rations += 1
	sound.play_effect(FarmAudio.Effect.TRADE)
	message = "Bread added to your bag."
	_refresh()
	if buy_food_button.disabled:
		food_menu.focus_first_action()


func _test_restore() -> void:
	clock.hunger = FarmClock.FULL
	clock.fatigue = 0.0
	_refresh()


func _test_needs() -> void:
	clock.hunger = 10.0
	clock.fatigue = 95.0
	_refresh()


func _test_night() -> void:
	clock.hour = 22.0
	_update_daylight()
	_refresh()


func _test_advance_day() -> void:
	clock.rest()
	_advance_day()
	_update_daylight()
	_refresh()


func _test_go_home() -> void:
	_set_indoors(true)
	_close_menu()
	_refresh()


func _open_market() -> void:
	market.set_season(season, equipped_seed)
	_show_menu(market)
	market.focus_first_action()


func _toggle_menu(menu: ActionMenu) -> void:
	if active_menu == menu:
		_close_menu()
	else:
		_show_menu(menu)
		menu.focus_first_action()


func _show_menu(menu: Control) -> void:
	if active_menu != null:
		active_menu.hide()
	active_menu = menu
	walk_velocity = Vector3.ZERO
	_animate_walk(0.0, 0.1)
	menu.show()
	sound.play_effect(FarmAudio.Effect.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _close_menu() -> void:
	if active_menu == null:
		return
	active_menu.hide()
	active_menu = null
	sound.play_effect(FarmAudio.Effect.MENU)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_interaction_targets()


func _buy_seed(id: int) -> void:
	var crop := Catalog.crops[id]
	if not crop.grows_in(season) or coins < crop.seed_price():
		return
	coins -= crop.seed_price()
	seed_bag[id] = seed_bag.get(id, 0) + 1
	equipped_seed = id
	sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()


func _harvest_value() -> int:
	var value := 0
	for id in produce:
		value += produce[id] * Catalog.crops[id].sale_price()
	return value


func _sell_harvest() -> void:
	var value := _harvest_value()
	coins += value
	produce.clear()
	if value > 0:
		sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()


func _hud_panel(layer: CanvasLayer, at: Vector2, dimensions: Vector2) -> void:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)


func _hud_text(layer: CanvasLayer, at: Vector2, caption: String, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.text = caption
	label.add_theme_color_override("font_color", CREAM)
	label.add_theme_font_size_override("font_size", size)
	layer.add_child(label)
	return label
