extends Node3D
## Clover Patch game controller. farm.tscn holds the world, the player, effects, audio, and every
## menu as nodes; this script owns the farm's game state and reacts to their signals.

enum Plot { EMPTY, TILLED, PLANTED, WATERED, RIPE }
enum Tool { HANDS, HOE, WATERING_CAN, SICKLE }
enum Interaction { NONE, PLOT, SEEDS, FOOD, ENTER, EXIT, BED, REPAIR, SHIPPING, ORCHARD, FISHING, KITCHEN, RESIDENT,
	PICNIC, CLOSED_PASS, FORAGE }

const Save := preload("res://farm_save.gd")
const Orders := preload("res://farm_orders.gd")
const Weather := preload("res://valley_weather.gd")
const WorldLayout := preload("res://world_layout.gd")
const FarmAudio := preload("res://farm_audio.gd")
const Settings := preload("res://game_settings.gd")
const PauseControls := preload("res://pause_controls.gd")
const Voxels := preload("res://voxel_assets.gd")
const Scenery := preload("res://farm_scenery.gd")
const Catalog := preload("res://crop_catalog.gd")
const FarmClock := preload("res://farm_clock.gd")
const InventoryGrid := preload("res://inventory_grid.gd")
const ActionMenu := preload("res://action_menu.gd")
const MarketMenu := preload("res://market_menu.gd")
const Fishing := preload("res://pond_fishing.gd")
const Cooking := preload("res://cottage_cooking.gd")
const Skills := preload("res://valley_skills.gd")
const Village := preload("res://valley_village.gd")
const FarmHUD := preload("res://farm_hud.gd")
const UISkin := preload("res://farm_ui_theme.gd")
const Player := preload("res://player/player.gd")
const FollowCamera := preload("res://player/follow_camera.gd")
const GardenPlot := preload("res://effects/garden_plot.gd")
const GARDEN_PLOT_SCENE := preload("res://effects/garden_plot.tscn")
const BakeryMenu := preload("res://ui/bakery_menu.gd")
const ShippingMenu := preload("res://ui/shipping_menu.gd")
const InventoryMenu := preload("res://ui/inventory_menu.gd")
const JournalMenu := preload("res://ui/journal_menu.gd")
const CollectionMenu := preload("res://ui/collection_menu.gd")
const ResidentMenu := preload("res://ui/resident_menu.gd")
const VillageMenu := preload("res://ui/village_menu.gd")
const ResidentDirectory := preload("res://ui/resident_directory.gd")
const TestMenu := preload("res://ui/test_menu.gd")
const ResidentTestMenu := preload("res://ui/resident_test_menu.gd")
const TOOL_NAMES := ["Empty hands", "Hoe", "Watering Can", "Sickle"]
const TOOL_ICONS := ["", "hoe", "watering_can", "sickle"]


class GrowingCrop:
	var id: int
	var remaining: int

	func _init(crop_id: int, nights: int) -> void:
		id = crop_id
		remaining = nights


const SEASON_SKY := ["#8eb5ac", "#83acb6", "#b0a18c", "#a7b7c4"]
const FOOD_PRICE := 2
const BACKPACK_PRICES := [30, 80]
const REPAIR_PRICE := 10
const WATERING_UPGRADE_PRICE := 25
const HARVEST_MILESTONES := [Vector2i(5, 8), Vector2i(20, 18), Vector2i(50, 35)]
const WATERING_NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const ORCHARD_ROTATION_DAYS := 5
const ORCHARD_REACH := 1.05
const SPECIMENS := [Catalog.POND_PERCH, Catalog.MOONDROP, Catalog.APPLE, Catalog.LAKE_TROUT, Catalog.REED_CARP,
	Catalog.MOONFIN, Catalog.WILD_BERRIES, Catalog.CHANTERELLE, Catalog.RIVER_SHELL]
## The first three specimens are the original "valley classics" set; completing every entry pays a bonus.
const CLASSIC_COLLECTION := 0b111
const COMPLETE_COLLECTION := (1 << 9) - 1
const COLLECTION_REWARD := 18
const FULL_COLLECTION_REWARD := 40
## Pond "fish" field -> catch. Moonfin bites anywhere at dusk or in rain, and more often at secret water.
const POND_FISH := {"perch": Catalog.POND_PERCH, "trout": Catalog.LAKE_TROUT, "carp": Catalog.REED_CARP}
const MOONFIN_CHANCE := 0.18
const FORAGE_ITEMS := {"berries": Catalog.WILD_BERRIES, "mushroom": Catalog.CHANTERELLE, "shell": Catalog.RIVER_SHELL}
const FORAGE_REACH := 1.1
const PLOT_REACH := 1.0
const NO_PLOT := Vector2i(-1, -1)

var settings := Settings.new()
var layout := WorldLayout.new()
var plots: Dictionary[Vector2i, Plot] = {}
var day := 1
var harvested := 0
var claimed_milestones := 0
var watering_upgraded := false
var completed_orders := 0
var resident_actions: Array[String] = []
var resident_index := -1
var resident_reply := ""
var town_event_open := false
var donated_specimens := 0
var skills := Skills.new()
var seed_bag: Dictionary[int, int] = {Catalog.TURNIP: 5}
var produce: Dictionary[int, int] = {}
var shipments: Dictionary[int, int] = {}
var picked_apple_trees: Dictionary[Vector3, bool] = {}
var picked_forage: Dictionary[Vector3, bool] = {}
var hooked_fish := Catalog.POND_PERCH
var growing: Dictionary[Vector2i, GrowingCrop] = {}
var equipped_seed := Catalog.TURNIP
var equipped_tool := Tool.HOE
var season := Catalog.Season.SPRING
var coins := 6
var rations := 2
var clock := FarmClock.new()
var cottage_repaired := false
var visuals: Dictionary[Vector2i, GardenPlot] = {}
var bobber_target := Vector3.ZERO
var bobber_tween: Tween
var indoors := false
var bed_point: Vector3
var exit_point: Vector3
var kitchen_point: Vector3
var cursor_released := false
var active_menu: Control
var hotbar_slot := 0

var message := "Welcome to Clover Valley. Press J to see your first delivery orders."

@onready var scenery: Scenery = $Scenery
@onready var lighting: Environment = $WorldEnvironment.environment
@onready var sun: DirectionalLight3D = $Sun
@onready var camera: FollowCamera = $Camera
@onready var plot_root: Node3D = $Plots
@onready var interior: Node3D = $CottageInterior
@onready var marker: Node3D = $PlotMarker
@onready var player: Player = $Player
@onready var village: Village = $Village
@onready var weather: Weather = $Weather
@onready var work_particles: CPUParticles3D = $WorkParticles
@onready var work_particle_material: StandardMaterial3D = (work_particles.mesh as BoxMesh).material
@onready var bobber: Node3D = $Bobber
@onready var sound: FarmAudio = $Audio
@onready var pause_controls: PauseControls = $PauseControls
@onready var hud: FarmHUD = $UI/HUD
@onready var menu_backdrop: ColorRect = $UI/MenuBackdrop
@onready var market: MarketMenu = $UI/MarketMenu
@onready var food_menu: BakeryMenu = $UI/BakeryMenu
@onready var shipping_menu: ShippingMenu = $UI/ShippingMenu
@onready var fishing_menu: Fishing = $UI/FishingMenu
@onready var cooking_menu: Cooking = $UI/CookingMenu
@onready var inventory_menu: InventoryMenu = $UI/InventoryMenu
@onready var inventory_grid: InventoryGrid = inventory_menu.grid
@onready var journal: JournalMenu = $UI/Journal
@onready var resident_menu: ResidentMenu = $UI/ResidentMenu
@onready var village_menu: VillageMenu = $UI/VillageMenu
@onready var resident_directory: ResidentDirectory = $UI/ResidentDirectory
@onready var collection_menu: CollectionMenu = $UI/CollectionMenu
@onready var test_menu: TestMenu = $UI/TestMenu
@onready var resident_test_menu: ResidentTestMenu = $UI/ResidentTestMenu
@onready var fireflies: CPUParticles3D = $Fireflies


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_node_ready():
		return
	if key.physical_keycode == KEY_F7:
		_toggle_menu(resident_test_menu if active_menu == resident_test_menu else test_menu)
	elif key.physical_keycode == KEY_TAB and active_menu == null:
		_set_cursor_released(not cursor_released)
	elif key.physical_keycode == KEY_I:
		_toggle_menu(inventory_menu)
	elif key.physical_keycode == KEY_J:
		_toggle_menu(journal)
	elif key.physical_keycode == KEY_ESCAPE:
		if active_menu != null:
			_close_menu()
		else:
			_pause_game()
	elif active_menu in [market, food_menu, shipping_menu] and key.physical_keycode == KEY_E:
		_close_menu()
	elif active_menu == fishing_menu and key.physical_keycode == KEY_E:
		if fishing_menu.phase == Fishing.Phase.DONE:
			_close_menu()
		else:
			fishing_menu.reel()
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if active_menu != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.look(event.relative, settings.sensitivity, settings.invert_y)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_set_cursor_released(false)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
				_select_hotbar(posmod(hotbar_slot + direction, InventoryGrid.ROW_SIZE))
				get_viewport().set_input_as_handled()


func _set_cursor_released(released: bool) -> void:
	cursor_released = released
	hud.set_cursor_available(released)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if released else Input.MOUSE_MODE_CAPTURED


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if active_menu != null or key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_E:
			_use_world_action()
		KEY_F:
			_update_bag()
			inventory_grid.use_slot(hotbar_slot)
		KEY_1, KEY_2, KEY_3, KEY_4:
			_select_belt_tool(key.physical_keycode - KEY_1)


func _use_world_action() -> void:
	_interact()
	_refresh()


func _select_belt_tool(index: int) -> void:
	if _is_exhausted():
		_exhaustion_message()
	else:
		_equip_tool(index as Tool)
		for slot in range(InventoryGrid.ROW_SIZE):
			var stack := inventory_grid.stack_at(slot)
			if stack != null and stack.kind == InventoryGrid.Kind.TOOL and stack.item_id == index:
				hotbar_slot = slot
				break
	_refresh()


func _select_hotbar(index: int) -> void:
	hotbar_slot = index
	var stack := inventory_grid.stack_at(index)
	if stack != null and stack.kind in [InventoryGrid.Kind.TOOL, InventoryGrid.Kind.SEED]:
		if not stack.equipped:
			inventory_grid.use_slot(index)
	_refresh_hotbar()


func _refresh_hotbar() -> void:
	var held: String = TOOL_NAMES[equipped_tool]
	if equipped_tool == Tool.WATERING_CAN and watering_upgraded:
		held += " +"
	hud.set_hotbar(inventory_grid, hotbar_slot, held)


func _process(delta: float) -> void:
	if active_menu != null:
		return
	var horizontal := int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
	horizontal -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	vertical -= int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))

	var distance := player.walk(Vector2i(horizontal, vertical), camera.yaw, _walk_speed(), delta)
	player.animate(distance, delta)
	sound.walk(0.0 if player.is_stepping() else distance, indoors)
	_update_interaction_targets()
	_update_camera(delta)
	clock.tick(delta, distance > 0.0)
	village.update_routines(day, clock.hour, delta)
	if not indoors:
		scenery.update_wildlife(delta)
	_update_daylight()
	if weather.emitting:
		weather.position = player.position + Vector3(0, 6.5, 0)
	_update_needs()


func _walk_speed() -> float:
	if clock.hunger < 20.0 or _is_exhausted():
		return Player.WALK_SPEED * 0.70
	if clock.hunger < 45.0 or clock.fatigue >= FarmClock.SLEEP_FATIGUE:
		return Player.WALK_SPEED * 0.86
	return Player.WALK_SPEED


func _on_player_landed(at: Vector3, dropping: bool) -> void:
	sound.play_effect(FarmAudio.Effect.GRASS_STEP, 0.80 if dropping else 0.86)
	_burst(at + Vector3.UP * 0.08, Color("#ba9a6f"))


func _update_camera(delta := 0.0) -> void:
	camera.follow(player.position, null if indoors else layout, delta)


func _target_plot() -> Vector2i:
	if indoors:
		return NO_PLOT
	var cell := _tile_at(player.position)
	var offset := player.position - _world(cell)
	var forward := player.transform.basis.z
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
			sound.play_effect(FarmAudio.Effect.TILL, randf_range(0.93, 1.07))
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
			sound.play_effect(FarmAudio.Effect.WATER, randf_range(0.96, 1.06))
			message = "%s watered. %d watered night(s) until harvest." % [crop.label, plant.remaining]
			if watering_upgraded:
				var extra := _water_neighboring_crops(target)
				if extra > 0:
					message = "Watered %d crops, including %s." % [extra + 1, crop.label]
		Plot.WATERED:
			message = "Already watered. It will grow after you sleep."
			return
		Plot.RIPE:
			var plant := growing[target]
			var crop := Catalog.crops[plant.id]
			if not _bag_has_room(InventoryGrid.Kind.HARVEST, plant.id):
				return
			produce[plant.id] = produce.get(plant.id, 0) + 1
			harvested += 1
			sound.play_effect(FarmAudio.Effect.HARVEST, randf_range(0.96, 1.08))
			_animate_pickup(_world(target), plant.id)
			message = "%s harvested!" % crop.label
			if crop.regrowth > 0:
				plant.remaining = crop.regrowth
				plots[target] = Plot.PLANTED
			else:
				growing.erase(target)
				plots[target] = Plot.TILLED
	clock.do_farm_work(6.0 - 0.5 * (skills.level(Skills.Skill.FARMING) - 1))
	_train_skill(Skills.Skill.FARMING)
	_show_plot(target)
	_animate_work(action, target)


func _water_neighboring_crops(target: Vector2i) -> int:
	var watered := 0
	for offset: Vector2i in WATERING_NEIGHBORS:
		var tile := target + offset
		if plots.get(tile) != Plot.PLANTED:
			continue
		var plant := growing[tile]
		if plant.id == Catalog.GRASS or not Catalog.crops[plant.id].grows_in(season):
			continue
		plots[tile] = Plot.WATERED
		_show_plot(tile)
		watered += 1
	return watered


func _animate_work(action: Plot, target: Vector2i) -> void:
	var angles := {Plot.EMPTY: -1.65, Plot.TILLED: -0.82, Plot.PLANTED: -1.18, Plot.RIPE: -1.08}
	var colors := {Plot.EMPTY: "#ae7956", Plot.TILLED: "#e0cb87", Plot.PLANTED: "#87bfd4", Plot.RIPE: "#f6d474"}
	player.swing_tool(angles[action])
	_burst(_world(target) + Vector3.UP * 0.27, Color(colors[action]))


func _burst(at: Vector3, color: Color) -> void:
	work_particle_material.albedo_color = color
	work_particles.position = at
	work_particles.restart()


func _animate_pickup(at: Vector3, id: int) -> void:
	var pickup := Node3D.new()
	pickup.position = at
	pickup.scale = Vector3.ONE * 0.78
	add_child(pickup)
	Voxels.crop(pickup, id, Catalog.crops[id].color, 0.3, true)
	var flight := pickup.create_tween()
	flight.tween_method(func(progress: float) -> void:
		pickup.position = at.lerp(player.position + Vector3.UP * 0.62, progress)
		pickup.position.y += sin(progress * PI) * 0.85
		pickup.rotation.y = progress * TAU
		pickup.scale = Vector3.ONE * (0.78 - smoothstep(0.65, 1.0, progress) * 0.76)
	, 0.0, 1.0, 0.48)
	flight.tween_callback(pickup.queue_free)


func _interaction(target: Vector2i) -> Interaction:
	var at := player.position
	if indoors:
		if at.distance_to(bed_point) <= 1.25:
			return Interaction.BED
		if at.distance_to(exit_point) <= 1.05:
			return Interaction.EXIT
		if at.distance_to(kitchen_point) <= 0.95:
			return Interaction.KITCHEN
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
	if at.distance_to(scenery.shipping_bin) <= 1.45:
		return Interaction.SHIPPING
	if _nearby_apple_tree() != null:
		return Interaction.ORCHARD
	if _nearby_forage() >= 0:
		return Interaction.FORAGE
	if _nearby_fishing_spot().is_finite():
		return Interaction.FISHING
	if village.nearby(at) >= 0:
		return Interaction.RESIDENT
	for spot in scenery.picnic_spots:
		if at.distance_to(spot) <= 1.9:
			return Interaction.PICNIC
	for pass_approach in scenery.closed_passes:
		if at.distance_to(pass_approach) <= 1.8:
			return Interaction.CLOSED_PASS
	return Interaction.PLOT if target != NO_PLOT else Interaction.NONE


func _nearby_fishing_spot() -> Vector3:
	for spot in scenery.fishing_spots:
		if player.position.distance_to(spot) <= 1.05:
			return spot
	return Vector3.INF


func _nearby_apple_tree() -> Node3D:
	if season != Catalog.Season.FALL:
		return null
	var nearest: Node3D
	var closest := ORCHARD_REACH
	for at in scenery.orchard_fruit:
		var fruit := scenery.orchard_fruit[at]
		var distance := player.position.distance_to(fruit.global_position)
		if fruit.visible and distance < closest:
			nearest = fruit
			closest = distance
	return nearest


func _choose_catch(spot: int) -> int:
	var water: Dictionary = scenery.fishing_waters[spot] if spot >= 0 else {"fish": "perch", "rare": 0.0}
	var chance: float = water.rare
	if clock.hour >= 18.0 or weather.kind == Weather.Kind.RAIN:
		chance = maxf(chance, MOONFIN_CHANCE)
	if randf() < chance:
		return Catalog.MOONFIN
	return POND_FISH.get(water.fish, Catalog.POND_PERCH)


func _forage_in_season(item: String) -> bool:
	match item:
		"berries":
			return season in [Catalog.Season.SPRING, Catalog.Season.SUMMER]
		"mushroom":
			return season == Catalog.Season.FALL
	return season != Catalog.Season.WINTER


func _forage_available(index: int) -> bool:
	var spot: Dictionary = scenery.forage_spots[index]
	# Half the spots refill each morning, alternating by day.
	return _forage_in_season(spot.item) and (index + day) % 2 == 0 and not picked_forage.has(spot.at)


func _update_forage() -> void:
	for index in range(scenery.forage_spots.size()):
		scenery.set_forage_visible(index, _forage_available(index))


func _nearby_forage() -> int:
	var closest := FORAGE_REACH
	var nearest := -1
	for index in range(scenery.forage_spots.size()):
		var spot: Dictionary = scenery.forage_spots[index]
		var distance := player.position.distance_to(layout.grounded(spot.at))
		if distance < closest and _forage_available(index):
			closest = distance
			nearest = index
	return nearest


func _gather_forage() -> void:
	var index := _nearby_forage()
	if index < 0:
		return
	var spot: Dictionary = scenery.forage_spots[index]
	var id: int = FORAGE_ITEMS[spot.item]
	if not _bag_has_room(InventoryGrid.Kind.HARVEST, id):
		return
	picked_forage[spot.at] = true
	scenery.set_forage_visible(index, false)
	produce[id] = produce.get(id, 0) + 1
	clock.do_farm_work()
	sound.play_effect(FarmAudio.Effect.FRUIT_PLUCK, randf_range(0.9, 1.1))
	var at := layout.grounded(spot.at) + Vector3.UP * 0.3
	_animate_pickup(at, id)
	_burst(at, Color(Catalog.crops[id].color))
	message = "Gathered %s." % Catalog.crops[id].label


func _update_orchard() -> void:
	var index := 0
	for at in scenery.orchard_fruit:
		scenery.orchard_fruit[at].visible = season == Catalog.Season.FALL and (
			index % ORCHARD_ROTATION_DAYS == (day - 1) % ORCHARD_ROTATION_DAYS
			and not picked_apple_trees.has(at))
		index += 1


func _pick_apple() -> void:
	var fruit := _nearby_apple_tree()
	if fruit == null or not _bag_has_room(InventoryGrid.Kind.HARVEST, Catalog.APPLE):
		return
	picked_apple_trees[scenery.orchard_fruit.find_key(fruit)] = true
	fruit.hide()
	produce[Catalog.APPLE] = produce.get(Catalog.APPLE, 0) + 1
	clock.do_farm_work()
	sound.play_effect(FarmAudio.Effect.FRUIT_PLUCK, randf_range(0.95, 1.07))
	var branch := fruit.global_position + Vector3.UP * 1.05
	_animate_pickup(branch, Catalog.APPLE)
	_burst(branch, Color("#f2bc6f"))
	message = "Picked an Orchard Apple."


func _is_exhausted() -> bool:
	return clock.fatigue >= FarmClock.EXHAUSTED


func _exhaustion_message() -> void:
	message = "You're exhausted. Eat something or return to bed."


func _blocked_by_fatigue(action: Interaction) -> bool:
	return _is_exhausted() and action in [
		Interaction.PLOT, Interaction.SEEDS, Interaction.FOOD, Interaction.REPAIR,
		Interaction.ORCHARD, Interaction.FISHING, Interaction.FORAGE]


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
		Interaction.SHIPPING:
			_show_menu(shipping_menu)
			shipping_menu.focus_first_action()
		Interaction.ORCHARD:
			_pick_apple()
		Interaction.FORAGE:
			_gather_forage()
		Interaction.RESIDENT:
			_talk_to_resident(village.nearby(player.position))
		Interaction.PICNIC:
			if clock.take_picnic_break():
				message = "You took a picnic break and recovered fatigue."
			else:
				message = "A picnic break needs 30 minutes and some fatigue to recover."
		Interaction.CLOSED_PASS:
			message = "A rockslide buried the old pass. The council closed the trail while the slope is still unstable."
		Interaction.FISHING:
			hooked_fish = _choose_catch(scenery.fishing_spots.find(_nearby_fishing_spot()))
			fishing_menu.prepare_catch(Catalog.crops[hooked_fish].label,
				load("res://assets/items/crop_%02d.svg" % hooked_fish) as Texture2D)
			if not _bag_has_room(InventoryGrid.Kind.HARVEST, hooked_fish):
				return
			clock.do_farm_work()
			fishing_menu.cast(0.2 * (skills.level(Skills.Skill.FISHING) - 1))
			_show_menu(fishing_menu)
			_animate_cast(_nearby_fishing_spot())
			fishing_menu.focus_first_action()
		Interaction.KITCHEN:
			if cottage_repaired:
				_show_menu(cooking_menu)
				cooking_menu.focus_first_action()
			else:
				message = "Repair the cottage to get the kitchen working."


func _catch_fish() -> void:
	produce[hooked_fish] = produce.get(hooked_fish, 0) + 1
	message = "Caught a %s." % Catalog.crops[hooked_fish].label
	if hooked_fish == Catalog.MOONFIN:
		message += " A rare Moonfin!"
	_train_skill(Skills.Skill.FISHING)
	sound.play_effect(FarmAudio.Effect.FISHING_CATCH)
	_burst(bobber_target, Color("#d3f5ed"))
	_refresh()


func _animate_cast(spot: Vector3) -> void:
	_clear_bobber()
	var start := player.position + Vector3.UP * 0.85
	bobber_target = spot + Vector3(0, 0.12, 1.1)
	bobber.position = start
	bobber.show()
	bobber_tween = create_tween()
	bobber_tween.tween_method(func(progress: float) -> void:
		bobber.position = start.lerp(bobber_target, progress)
		bobber.position.y += sin(progress * PI) * 0.6
	, 0.0, 1.0, 0.28)
	bobber_tween.tween_callback(func() -> void:
		sound.play_effect(FarmAudio.Effect.FISHING_CAST)
		_burst(bobber_target, Color("#b8e9df")))


func _on_fishing_bite() -> void:
	if bobber_tween != null:
		bobber_tween.kill()
	bobber.position = bobber_target
	sound.play_effect(FarmAudio.Effect.FISHING_BITE)
	_burst(bobber_target, Color("#caeee6"))
	bobber_tween = create_tween().set_trans(Tween.TRANS_SINE)
	bobber_tween.tween_property(bobber, "position:y", bobber_target.y - 0.12, 0.09)
	bobber_tween.tween_property(bobber, "position:y", bobber_target.y, 0.19)


func _clear_bobber() -> void:
	if bobber_tween != null:
		bobber_tween.kill()
	bobber.hide()


func _cook_meal(recipe: Cooking.Recipe) -> void:
	if active_menu != cooking_menu or not cottage_repaired or not _can_eat():
		return
	if not recipe.has_ingredients(produce, rations):
		return
	for id in recipe.ingredients:
		if id == Cooking.BREAD:
			rations -= recipe.ingredients[id]
		else:
			produce[id] -= recipe.ingredients[id]
	clock.eat(recipe.hunger, recipe.fatigue + 3.0 * (skills.level(Skills.Skill.COOKING) - 1))
	sound.play_effect(FarmAudio.Effect.EAT)
	message = "Cooked and ate %s." % recipe.label
	_train_skill(Skills.Skill.COOKING)
	_refresh()


func _train_skill(skill: Skills.Skill) -> void:
	if skills.train(skill):
		message += " %s reached level %d!" % [Skills.NAMES[skill], skills.level(skill)]


func _set_indoors(entering: bool) -> void:
	player.finish_step()
	player.halt()
	indoors = entering
	player.indoors = entering
	interior.visible = indoors
	player.face(PI if indoors else 0.0)
	camera.yaw = 0.0 if indoors else PI
	player.position = (interior.get_node("Entry") as Marker3D).global_position if indoors else scenery.cottage_door + Vector3(0, 0, 0.38)
	message = "Home Cottage" if indoors else "Clover Valley"
	_update_weather()
	_update_daylight()
	_update_camera()


func _try_sleep() -> void:
	if not indoors or player.position.distance_to(bed_point) > 1.25:
		return
	if clock.fatigue < FarmClock.SLEEP_FATIGUE:
		message = "Too early to sleep. Fatigue must reach %d%%." % int(FarmClock.SLEEP_FATIGUE)
		return
	clock.rest()
	player.halt()
	_advance_day()
	village.update_routines(day, clock.hour, 0.0)
	_update_daylight()
	sound.play_effect(FarmAudio.Effect.SLEEP)
	if _save_farm() != OK:
		message += "  ·  Autosave failed."


func _can_eat() -> bool:
	return clock.hunger < FarmClock.FULL or clock.fatigue > 0.0


func _eat_item(kind: InventoryGrid.Kind, id: int) -> void:
	if not _can_eat():
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
	if indoors or player.position.distance_to(scenery.repair_sign) > 1.45:
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
	weather.position = player.position + Vector3(0, 6.5, 0)
	weather.apply(Weather.forecast(day), not indoors)
	scenery.set_wet(weather.kind == Weather.Kind.RAIN)


func _rain_waters(crop_id: int) -> bool:
	return weather.kind == Weather.Kind.RAIN and crop_id != Catalog.GRASS


func _advance_day() -> void:
	day += 1
	village.schedule_town_event(day)
	var next_season := Catalog.season_for(day)
	var changed := season != next_season
	season = next_season
	picked_apple_trees.clear()
	_update_orchard()
	picked_forage.clear()
	_update_forage()
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
		scenery.set_season(season)
		message = "%s has begun. New delivery orders are in your journal." % Catalog.SEASONS[season]
	if watered > 0:
		message += " Rain watered %d plot(s)." % watered
	var payout := _produce_value(shipments)
	if payout > 0:
		coins += payout
		shipments.clear()
		message += " Shipping earned %d coins." % payout


func _ready() -> void:
	var load_error := settings.read_config()
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Could not read Clover Patch settings.")
	var world_error := layout.read(WorldLayout.DEFAULT_PATH)
	if world_error != OK:
		push_error("Clover Valley layout failed to load: %s" % error_string(world_error))
		get_tree().quit(1)
		return
	if village.load_residents() != OK:
		get_tree().quit(1)
		return
	# The valley itself is data-driven: tools/world/build_world.py writes world/clover_valley.json.
	scenery.rebuild(layout)
	_build_plots()
	bed_point = (interior.get_node("Bedside") as Marker3D).global_position
	exit_point = (interior.get_node("Exit") as Marker3D).global_position
	kitchen_point = (interior.get_node("Kitchen") as Marker3D).global_position
	player.setup(layout, scenery.obstacles, interior.position)
	village.populate(layout, scenery.obstacles, scenery.resident_doors)
	_fill_resident_test_picker()
	_apply_settings()
	sound.music.play()
	player.position = layout.grounded(layout.anchor("spawn"))
	player.face(player.facing_angle)
	_update_held_tool()
	_load_farm()
	village.schedule_town_event(day)
	village.update_routines(day, clock.hour, 0.0)
	_update_orchard()
	_update_forage()
	_update_weather()
	_refresh()
	_update_daylight()
	_update_camera()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_plots() -> void:
	for entity in layout.entities:
		if entity["kind"] != "plot":
			continue
		var tile := _tile_at(WorldLayout.position_of(entity))
		var plot := GARDEN_PLOT_SCENE.instantiate() as GardenPlot
		plot.position = _world(tile)
		plot_root.add_child(plot)
		visuals[tile] = plot
		_show_plot(tile)


func _fill_resident_test_picker() -> void:
	var entries := village.residents.duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
	for resident in entries:
		resident_test_menu.picker.add_item(resident.name, village.resident_indices[resident.id])


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
		"claimed_milestones": claimed_milestones, "watering_upgraded": watering_upgraded,
		"donated_specimens": donated_specimens, "skill_practice": skills.practice,
		"village": village.state(),
		"coins": coins, "bread": rations, "seeds": seed_bag, "produce": produce,
		"shipments": shipments, "picked_apple_trees": picked_apple_trees.keys(), "picked_forage": picked_forage.keys(),
		"tool": equipped_tool, "seed": equipped_seed, "slots": inventory_grid.save_slots(),
		"backpack_rows": inventory_grid.unlocked_rows, "hotbar_slot": hotbar_slot,
		"hour": clock.hour, "hunger": clock.hunger, "fatigue": clock.fatigue,
		"repaired": cottage_repaired, "plots": beds, "indoors": indoors,
		"position": player.position, "facing": player.facing_angle,
		"camera_yaw": camera.yaw, "camera_pitch": camera.pitch,
	})


func _load_farm() -> void:
	var state := Save.read()
	if state.is_empty():
		return
	day = maxi(1, Save.count(state.get("day"), 1000000, 1))
	season = Catalog.season_for(day)
	harvested = Save.count(state.get("harvested"), 1000000)
	claimed_milestones = Save.count(state.get("claimed_milestones"), HARVEST_MILESTONES.size())
	donated_specimens = Save.count(state.get("donated_specimens"), COMPLETE_COLLECTION)
	skills.restore(state.get("skill_practice"))
	village.restore(state.get("village"))
	watering_upgraded = state.get("watering_upgraded") == true
	completed_orders = Save.count(state.get("orders"), 7)
	coins = Save.count(state.get("coins"), 1000000, coins)
	rations = Save.count(state.get("bread"), 100000, rations)
	_restore_stock(seed_bag, state.get("seeds"), Catalog.SEED_COUNT)
	_restore_stock(produce, state.get("produce"))
	_restore_stock(shipments, state.get("shipments"))
	var gathered: Variant = state.get("picked_forage")
	if gathered is Array:
		for at: Variant in gathered:
			if at is Vector3:
				picked_forage[at] = true
	var picked: Variant = state.get("picked_apple_trees")
	if picked is Array:
		for at: Variant in picked:
			if at is Vector3 and scenery.orchard_fruit.has(at):
				picked_apple_trees[at] = true
	equipped_seed = Save.count(state.get("seed"), Catalog.SEED_COUNT - 1)
	equipped_tool = Save.count(state.get("tool"), Tool.SICKLE, Tool.HOE) as Tool
	clock.hour = Save.meter(state.get("hour"), FarmClock.MORNING, FarmClock.LAST_HOUR, clock.hour)
	clock.hunger = Save.meter(state.get("hunger"), 0.0, FarmClock.FULL, clock.hunger)
	clock.fatigue = Save.meter(state.get("fatigue"), 0.0, FarmClock.FULL, clock.fatigue)
	cottage_repaired = state.get("repaired") == true
	if cottage_repaired:
		_show_cottage_repair()
	scenery.set_season(season)
	_update_forage()
	_restore_plots(state.get("plots"))
	_restore_position(state)
	inventory_grid.unlocked_rows = maxi(1, Save.count(state.get("backpack_rows"), InventoryGrid.MAX_ROWS, 1))
	hotbar_slot = Save.count(state.get("hotbar_slot"), InventoryGrid.ROW_SIZE - 1)
	inventory_grid.restore_slots(state.get("slots"))
	_update_bag()
	_update_held_tool()
	message = "Welcome back to Clover Valley."


func _restore_stock(stock: Dictionary[int, int], saved: Variant, item_count: int = -1) -> void:
	if not saved is Dictionary:
		return
	stock.clear()
	for id in range(Catalog.crops.size() if item_count < 0 else item_count):
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
		elif bed.y >= 0 and bed.y < Catalog.SEED_COUNT:
			var crop := Catalog.crops[bed.y]
			plots[tile] = bed.x as Plot
			var nights := clampi(bed.z, 1, maxi(crop.harvest_day - 1, crop.regrowth))
			growing[tile] = GrowingCrop.new(bed.y, 0 if bed.x == Plot.RIPE else nights)
		_show_plot(tile)


func _restore_position(state: Dictionary) -> void:
	player.finish_step()
	if state.get("indoors") == true:
		_set_indoors(true)
	var saved: Variant = state.get("position")
	if saved is Vector3 and saved.is_finite() and player.can_stand_at(saved):
		player.position = Vector3(saved.x, 0.0, saved.z)
		if not indoors:
			player.position = layout.grounded(player.position)
	player.face(Save.meter(state.get("facing"), -PI, PI, player.facing_angle))
	camera.yaw = Save.meter(state.get("camera_yaw"), -PI, PI, camera.yaw)
	camera.pitch = Save.meter(state.get("camera_pitch"), FollowCamera.MIN_PITCH, FollowCamera.MAX_PITCH, camera.pitch)


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
	player.halt()
	hud.interaction_prompt.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_controls.open(settings)
	sound.play_effect(FarmAudio.Effect.MENU)


func _resume_game() -> void:
	pause_controls.close()
	get_tree().paused = false
	sound.play_effect(FarmAudio.Effect.MENU)
	_set_cursor_released(cursor_released)
	_update_interaction_targets()


func _world(tile: Vector2i) -> Vector3:
	return layout.grounded(WorldLayout.world_at(tile))


func _tile_at(at: Vector3) -> Vector2i:
	return WorldLayout.tile_at(at)


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
	# Lantern pools glow from dusk; fireflies come out over the meadow on summer nights.
	var night := clampf((0.7 - daylight) / 0.5, 0.0, 1.0)
	scenery.set_night(night)
	var glowing := not indoors and season == Catalog.Season.SUMMER and night > 0.6 and weather.kind == Weather.Kind.CLEAR
	if fireflies.emitting != glowing:
		fireflies.emitting = glowing
	fireflies.visible = not indoors


func _update_held_tool() -> void:
	player.show_tool(equipped_tool)


func _show_plot(tile: Vector2i) -> void:
	var plot := visuals[tile]
	var state: int = plots.get(tile, Plot.EMPTY)
	plot.show_soil(state != Plot.EMPTY, state == Plot.WATERED)
	plot.clear_crop()
	if not growing.has(tile):
		return
	var plant := growing[tile]
	var crop := Catalog.crops[plant.id]
	if not crop.grows_in(season):
		return
	var size := 0.13 + 0.24 * clampf(1.0 - float(plant.remaining) / (crop.harvest_day - 1), 0.0, 1.0)
	plot.show_crop(plant.id, crop.color, size, state == Plot.RIPE)


func _update_interaction_targets() -> void:
	var target := _target_plot()
	marker.visible = target != NO_PLOT
	if marker.visible:
		marker.position = _world(target)
	hud.crop_label.text = ""
	if growing.has(target):
		var plant := growing[target]
		var name := Catalog.crops[plant.id].label
		hud.crop_label.text = "%s  ·  %d night(s) left" % [name, plant.remaining] if plant.remaining > 0 else "%s  ·  Ready" % name
		if not Catalog.crops[plant.id].grows_in(season):
			hud.crop_label.text = "%s  ·  Dormant" % name
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
		Interaction.SHIPPING:
			prompt = "Open shipping bin"
		Interaction.ORCHARD:
			prompt = "Pick Orchard Apple"
		Interaction.FORAGE:
			var spot: Dictionary = scenery.forage_spots[_nearby_forage()]
			prompt = "Gather %s" % Catalog.crops[FORAGE_ITEMS[spot.item]].label
		Interaction.FISHING:
			prompt = "Cast a line"
		Interaction.KITCHEN:
			prompt = "Use the kitchen" if cottage_repaired else "Kitchen · repair the cottage first"
		Interaction.RESIDENT:
			prompt = "Talk to %s" % village.residents[village.nearby(player.position)].name
		Interaction.PICNIC:
			prompt = "Take a picnic break · 30 min"
		Interaction.CLOSED_PASS:
			prompt = "Inspect the closed pass"
	var required := _required_tool(target) if action == Interaction.PLOT else Tool.HANDS
	if active_menu != null or prompt.is_empty():
		hud.set_prompt("", false)
	elif _blocked_by_fatigue(action):
		hud.set_prompt("Exhausted  ·  Eat or sleep before working", false)
	elif required != Tool.HANDS and equipped_tool != required:
		hud.set_prompt("%s needed  ·  Press %d to equip" % [TOOL_NAMES[required], required + 1], false)
	else:
		hud.set_prompt("[ E ]  " + prompt, true)


func _refresh() -> void:
	_update_interaction_targets()
	_update_needs()
	hud.show_notice(message)
	hud.location_label.text = "Home Cottage" if indoors else "Clover Valley"
	_update_bag()
	hud.stock_label.text = "%d coins  ·  %s seeds ×%d" % [
		coins, Catalog.crops[equipped_seed].label, seed_bag.get(equipped_seed, 0)]
	if market.visible:
		market.update_stock(hud.stock_label.text, coins, _harvest_value())
	if food_menu.visible:
		food_menu.stock.text = "%d coins   /   %d bread in bag" % [coins, rations]
		food_menu.buy_button.disabled = coins < FOOD_PRICE
	if journal.visible:
		_update_journal()
	if collection_menu.visible:
		_update_collection()
	if shipping_menu.visible:
		_update_shipping_menu()
	if cooking_menu.visible:
		cooking_menu.update_stock(produce, rations, _can_eat())
	if resident_menu.visible:
		_update_resident()
	if village_menu.visible:
		_update_village_journal()
	if resident_test_menu.visible:
		_update_test_resident_status()


func _update_needs() -> void:
	hud.set_almanac("%s %d" % [Catalog.SEASONS[season], Catalog.day_of_season(day)], clock.hour, weather.kind)
	hud.hunger_meter.value = clock.hunger
	hud.fatigue_meter.value = clock.fatigue
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
	hud.needs_label.text = "%s   /   %s" % [appetite, rest]
	var warning := clock.hunger < 45.0 or clock.fatigue >= FarmClock.SLEEP_FATIGUE
	hud.needs_label.add_theme_color_override("font_color", Color("#e8a16e") if warning else UISkin.PAPER)


func _open_resident_tests() -> void:
	_sync_test_resident()
	_show_menu(resident_test_menu)
	resident_test_menu.picker.grab_focus()


func _sync_test_resident(_item := -1) -> void:
	resident_test_menu.favor.set_value_no_signal(village.affinity(resident_test_menu.picker.get_selected_id()))
	_update_test_resident_status()


func _update_test_resident_status() -> void:
	var index := resident_test_menu.picker.get_selected_id()
	var resident: Dictionary = village.residents[index]
	var partner_name := "none" if village.partner.is_empty() else str(village.residents[village.resident_indices[village.partner]].name)
	resident_test_menu.status.text = "Favor: %d   ·   Gift today: %s   ·   Partner: %s\n%s · %s" % [
		village.affinity(index), "yes" if village.last_gift.get(resident.id, 0) == day else "no",
		partner_name, "Date completed" if village.dates.has(resident.id) else "No date completed",
		village.activity_hint(index, day, clock.hour)]


func _test_set_favor() -> void:
	var index := resident_test_menu.picker.get_selected_id()
	village.change_affinity(index, int(resident_test_menu.favor.value) - village.affinity(index))
	_sync_test_resident()


func _test_favor_preset(value: int) -> void:
	resident_test_menu.favor.value = value
	_test_set_favor()


func _test_reset_romance() -> void:
	var id: String = village.residents[resident_test_menu.picker.get_selected_id()].id
	village.dates.erase(id)
	if village.partner == id:
		village.partner = ""
	_refresh()


func _test_gift_kit() -> void:
	var resident: Dictionary = village.residents[resident_test_menu.picker.get_selected_id()]
	for preference in ["favorite", "disliked"]:
		var item := int(resident.gifts[preference])
		if item == Orders.BREAD:
			rations = maxi(rations, 3)
		else:
			produce[item] = maxi(3, produce.get(item, 0))
	village.last_gift.erase(resident.id)
	message = "Gift test supplies are ready for %s." % resident.name
	_refresh()


func _test_open_dialogue() -> void:
	_talk_to_resident(resident_test_menu.picker.get_selected_id(), false)


func _test_go_to_resident() -> void:
	var index := resident_test_menu.picker.get_selected_id()
	_test_set_hour(float(village.residents[index].routine.depart) + 0.1)
	var at := village.models[index].position
	_test_place_outside(at + Vector3(0, 0, 0.65), at)


func _test_watch_departure() -> void:
	var index := resident_test_menu.picker.get_selected_id()
	var resident: Dictionary = village.residents[index]
	if not village.homes.has(resident.id):
		message = "This resident has no assigned house."
		_refresh()
		return
	_test_set_hour(float(resident.routine.depart) - 0.12)
	var at: Vector3 = village.homes[resident.id].position
	_test_place_outside(at + Vector3(0, 0, 3), at)


func _test_place_outside(near: Vector3, look_at_point: Vector3) -> void:
	if indoors:
		_set_indoors(false)
	player.finish_step()
	player.halt()
	var cell := village._walkable_cell(near)
	var position := WorldLayout.world_at(cell)
	var point := Vector2(near.x, near.z)
	if layout.bounds.grow(-Player.EDGE_MARGIN).has_point(point) and not village._blocked(point):
		position = near
	player.position = layout.grounded(position)
	var direction := look_at_point - player.position
	if direction.length_squared() > 0.01:
		player.face(atan2(direction.x, direction.z))
		camera.yaw = wrapf(player.facing_angle + PI, -PI, PI)
	_update_camera()
	_close_menu()
	_refresh()


func _open_resident_directory() -> void:
	if resident_directory.select.item_count == 0:
		var entries := village.residents.duplicate()
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.name < b.name)
		for resident in entries:
			resident_directory.select.add_item(resident.name, village.resident_indices[resident.id])
	_update_resident_directory(resident_directory.select.selected)
	_show_menu(resident_directory)
	resident_directory.select.grab_focus()


func _update_resident_directory(item: int) -> void:
	if item < 0:
		return
	var index := resident_directory.select.get_item_id(item)
	var resident: Dictionary = village.residents[index]
	var routine: Dictionary = resident.routine
	resident_directory.text.text = "%s · %s\n%s\nHome: %s\nOut from %s · Home by %s" % [
		resident.role, village.location_hint(resident.id, day, clock.hour),
		village.activity_hint(index, day, clock.hour), village.location_hint(resident.id, day, 6.0),
		_routine_time(float(routine.depart)), _routine_time(float(routine.home))]


func _routine_time(hour: float) -> String:
	return "%02d:%02d" % [floori(hour), roundi(fposmod(hour, 1.0) * 60.0)]


func _open_village_journal() -> void:
	_show_menu(village_menu)
	village_menu.focus_first_action()


func _update_village_journal() -> void:
	var lines := PackedStringArray(["The High-Water Mark", "Find the people who remember the flood."])
	for id in ["tess", "vera", "orin"]:
		if not village.resident_indices.has(id):
			continue
		var witness: Dictionary = village.residents[village.resident_indices[id]]
		var heard := bool(village.evidence & int(Village.EVIDENCE[id]))
		lines.append("%s · %s" % [witness.name, "Account recorded" if heard else village.location_hint(id, day, clock.hour)])
	if village.resolution > 0:
		lines.append("Hearing complete. Speak to Iona for the aftermath.")
	elif village.evidence == 7:
		lines.append("Visit Iona on or after day %d · %s." % [village.hearing_day, village.location_hint("iona", day, clock.hour)])
	lines.append("Valley Supper · Ask Mara after 16:00 from day 3 · %s."
		% village.location_hint("mara", day, clock.hour) if village.supper == 0
		else "Valley Supper held. Ask residents what they remember.")
	if village.town_event_day == day:
		var host: Dictionary = village.residents[village.resident_indices[village.town_event_host]]
		var event: Dictionary = village.town_events[village.town_event_host]
		var status := "Complete" if village.town_event_choice >= 0 else "Today"
		lines.append("%s · %s · %s, %s" % [
			status, event.title, host.name, village.location_hint(host.id, day, clock.hour)])
	if not village.partner.is_empty():
		for resident in village.residents:
			if resident.id == village.partner:
				lines.append("Partner · %s" % resident.name)
	village_menu.story.text = "\n".join(lines)


func _talk_to_resident(index: int, record_visit := true) -> void:
	if index < 0:
		return
	resident_index = index
	resident_reply = ""
	town_event_open = false
	if record_visit:
		village.visit(index, day)
	_show_menu(resident_menu)
	resident_menu.focus_first_action()


func _update_resident() -> void:
	var resident: Dictionary = village.residents[resident_index]
	var id: String = resident.id
	resident_menu.title.text = resident.name
	var gifted: bool = village.last_gift.get(id, 0) == day
	resident_menu.status.text = "%s  ·  Favor %d  ·  %s\n%s" % [
		resident.role, village.affinity(resident_index), "Gift given today" if gifted else "One gift per day",
		village.activity_hint(resident_index, day, clock.hour)]
	resident_menu.line.text = village.dialogue(resident_index, day, clock.hour) if resident_reply.is_empty() else resident_reply
	resident_actions.clear()
	var captions := PackedStringArray()
	if town_event_open:
		var event: Dictionary = village.town_events[id]
		resident_menu.line.text = event.prompt
		resident_actions.assign(["town-event-first", "town-event-second"])
		captions = [event.choices[0].label, event.choices[1].label]
		resident_menu.show_choices(captions)
		_update_gifts(true)
		return
	if id == "iona" and village.evidence == 7 and day >= village.hearing_day and village.resolution == 0:
		resident_actions.assign(["publish", "trust", "fund"])
		captions = ["Post the ledger publicly", "Put the land in a shared trust", "Seal the names and fund private claims"]
	elif Village.EVIDENCE.has(id) and not (village.evidence & int(Village.EVIDENCE[id])):
		resident_actions.append("witness")
		captions.append("Stay and hear the full account")
	if id == "mara" and village.can_start_supper(day, clock.hour):
		resident_actions.append("supper-families")
		resident_actions.append("supper-clinic")
		captions.append("Set the extra place for the displaced families")
		captions.append("Set the extra place for the clinic workers")
	if resident.romance and village.partner.is_empty() and village.affinity(resident_index) >= 12:
		if not village.dates.has(id):
			resident_actions.append("date")
			captions.append("Invite %s on a date" % resident.name)
		elif village.affinity(resident_index) >= 24:
			resident_actions.append("partner")
			captions.append("Ask to make this a relationship")
	if village.supper > 0:
		resident_actions.append("supper-reaction")
		captions.append("Ask about the Valley Supper")
	if village.resolution > 0:
		resident_actions.append("hearing-reaction")
		captions.append("Ask about the hearing")
	if village.affinity(resident_index) >= 10:
		resident_actions.append("personal")
		captions.append("Make time for a personal conversation")
	if village.town_event_day == day and id == village.town_event_host and village.town_event_choice < 0:
		resident_actions.append("town-event")
		captions.append(village.town_events[id].title)
	resident_menu.show_choices(captions)
	_update_gifts(gifted)


func _update_gifts(gifted: bool) -> void:
	var previous := resident_menu.gifts.get_selected_id() if resident_menu.gifts.selected >= 0 else -2
	resident_menu.gifts.clear()
	if rations > 0:
		resident_menu.gifts.add_item("Bread ×%d" % rations, Catalog.crops.size())
	for id in range(Catalog.crops.size()):
		var quantity: int = produce.get(id, 0)
		if quantity > 0:
			resident_menu.gifts.add_item("%s ×%d" % [Catalog.crops[id].label, quantity], id)
	var available := resident_menu.gifts.item_count > 0
	for index in range(resident_menu.gifts.item_count):
		if resident_menu.gifts.get_item_id(index) == previous:
			resident_menu.gifts.select(index)
			break
	resident_menu.gifts.disabled = gifted or not available
	resident_menu.gift_button.disabled = resident_menu.gifts.disabled
	if not available:
		resident_menu.gifts.add_item("No gifts in your bag")


func _give_resident_gift() -> void:
	if active_menu != resident_menu or resident_menu.gift_button.disabled:
		return
	var id := resident_menu.gifts.get_selected_id()
	var bread := id == Catalog.crops.size()
	if (rations if bread else produce.get(id, 0)) <= 0:
		return
	var reply := village.gift(resident_index, Orders.BREAD if bread else id, day)
	if reply.is_empty():
		return
	if bread:
		rations -= 1
	else:
		produce[id] -= 1
	resident_reply = reply
	sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()
	resident_menu.focus_first_action()


func _choose_resident_action(index: int) -> void:
	if active_menu != resident_menu or index >= resident_actions.size():
		return
	var id: String = village.residents[resident_index].id
	match resident_actions[index]:
		"town-event":
			town_event_open = true
		"town-event-first", "town-event-second":
			var choice := 0 if resident_actions[index] == "town-event-first" else 1
			village.town_event_choice = choice
			village.change_affinity(resident_index, 3)
			resident_reply = village.town_events[id].choices[choice].reply
			town_event_open = false
		"witness":
			village.evidence |= Village.EVIDENCE[id]
			village.change_affinity(resident_index, 3)
			resident_reply = village.residents[resident_index].dialogue.witness
			if village.evidence == 7:
				village.hearing_day = day + 1
		"date":
			village.dates[id] = true
			village.change_affinity(resident_index, 2)
			resident_reply = village.residents[resident_index].dialogue.date
		"partner":
			village.partner = id
			resident_reply = village.residents[resident_index].dialogue.partner
		"supper-families", "supper-clinic":
			village.supper = 1 if resident_actions[index] == "supper-families" else 2
			village.supper_day = day
			village.supper_table.show()
			resident_reply = village.residents[resident_index].dialogue.supper_open
		"supper-reaction":
			resident_reply = village.event_reaction(resident_index, false)
		"hearing-reaction":
			resident_reply = village.event_reaction(resident_index, true)
		"personal":
			resident_reply = village.residents[resident_index].dialogue.friendship
		"publish":
			village.resolution = 1
			for witness_id in Village.EVIDENCE:
				if village.resident_indices.has(witness_id):
					village.change_affinity(village.resident_indices[witness_id], 5)
			resident_reply = village.event_reaction(resident_index, true)
		"trust":
			village.resolution = 2
			seed_bag[Catalog.TURNIP] = seed_bag.get(Catalog.TURNIP, 0) + 8
			resident_reply = village.event_reaction(resident_index, true) + " The first seed share is yours."
		"fund":
			village.resolution = 3
			coins += 16
			resident_reply = village.event_reaction(resident_index, true) + " Here's the 16-coin fee for returning the records."
	_refresh()
	resident_menu.focus_first_action()


func _update_journal() -> void:
	journal.forecast.text = "Today: %s  ·  Tomorrow: %s  ·  Crops harvested: %d\n%s deliveries · fulfilled from your bag" % [
		Weather.NAMES[weather.kind], Weather.NAMES[Weather.forecast(day + 1)], harvested, Catalog.SEASONS[season]]
	for index in range(journal.order_buttons.size()):
		var order: Vector3i = Orders.BOARDS[season][index]
		var delivered := bool(completed_orders & (1 << index))
		var stock := _delivery_stock(order.x)
		var button := journal.order_buttons[index]
		var icon := "bread" if order.x == Orders.BREAD else "crop_%02d" % order.x
		button.icon = load("res://assets/items/%s.svg" % icon) as Texture2D
		button.add_theme_color_override("font_disabled_color", Color("#375a37") if delivered else Color("#675c49"))
		button.text = "%s ×%d  ·  %d coins  ·  %s" % [
			Orders.item_name(order.x), order.y, order.z,
			"Delivered" if delivered else "%d/%d in bag" % [mini(stock, order.y), order.y]]
		button.disabled = delivered or stock < order.y or _is_exhausted()
		button.tooltip_text = "Eat or sleep before making a delivery." if _is_exhausted() else ""

	journal.milestone_button.disabled = true
	journal.milestone_button.text = "All harvest milestones claimed"
	if claimed_milestones < HARVEST_MILESTONES.size():
		var milestone: Vector2i = HARVEST_MILESTONES[claimed_milestones]
		journal.milestone_button.disabled = harvested < milestone.x
		journal.milestone_button.text = "Harvest milestone · %d/%d crops · Claim %d coins" % [
			mini(harvested, milestone.x), milestone.x, milestone.y]

	journal.watering_upgrade_button.text = "Watering Can + · Waters neighboring crops" if watering_upgraded else (
		"Upgrade Watering Can · %d coins (%d in bag)" % [WATERING_UPGRADE_PRICE, coins])
	journal.watering_upgrade_button.disabled = watering_upgraded or coins < WATERING_UPGRADE_PRICE or _is_exhausted()
	journal.watering_upgrade_button.tooltip_text = "Water a dry crop to also water its four side neighbors."


func _open_collection() -> void:
	_show_menu(collection_menu)
	collection_menu.focus_first_action()


func _update_collection() -> void:
	var lines := PackedStringArray([
		"%s · Less fatigue from plot work" % skills.progress_text(Skills.Skill.FARMING),
		"%s · More time to reel in" % skills.progress_text(Skills.Skill.FISHING),
		"%s · Meals relieve more fatigue" % skills.progress_text(Skills.Skill.COOKING),
		"Collection complete" if donated_specimens == COMPLETE_COLLECTION else (
			"Valley classics on display · %d/%d specimens · Complete it for %d coins." % [
				_donated_count(), SPECIMENS.size(), FULL_COLLECTION_REWARD]
			if donated_specimens & CLASSIC_COLLECTION == CLASSIC_COLLECTION
			else "Donate the perch, Moondrop, and apple for %d coins." % COLLECTION_REWARD),
	])
	collection_menu.skills.text = "\n".join(lines)
	for index in range(SPECIMENS.size()):
		var id: int = SPECIMENS[index]
		var donated := bool(donated_specimens & (1 << index))
		var available: bool = produce.get(id, 0) > 0
		var state := "On display" if donated else ("Donate one" if available else "Find one to donate")
		collection_menu.donation_buttons[index].text = "%s · %s" % [Catalog.crops[id].label, state]
		collection_menu.donation_buttons[index].disabled = donated or not available


func _donate_specimen(index: int) -> void:
	if active_menu != collection_menu:
		return
	var id: int = SPECIMENS[index]
	var flag := 1 << index
	if donated_specimens & flag or produce.get(id, 0) <= 0:
		return
	var before := donated_specimens
	produce[id] -= 1
	donated_specimens |= flag
	message = "Donated %s to the Valley Collection." % Catalog.crops[id].label
	if before & CLASSIC_COLLECTION != CLASSIC_COLLECTION and donated_specimens & CLASSIC_COLLECTION == CLASSIC_COLLECTION:
		coins += COLLECTION_REWARD
		message += " Valley classics complete! Earned %d coins." % COLLECTION_REWARD
	if donated_specimens == COMPLETE_COLLECTION:
		coins += FULL_COLLECTION_REWARD
		message += " Collection complete! Earned %d coins." % FULL_COLLECTION_REWARD
	sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()
	collection_menu.focus_first_action()


func _donated_count() -> int:
	var count := 0
	for index in range(SPECIMENS.size()):
		count += int(bool(donated_specimens & (1 << index)))
	return count


func _claim_harvest_milestone() -> void:
	if claimed_milestones >= HARVEST_MILESTONES.size():
		return
	var milestone: Vector2i = HARVEST_MILESTONES[claimed_milestones]
	if harvested < milestone.x:
		return
	claimed_milestones += 1
	coins += milestone.y
	sound.play_effect(FarmAudio.Effect.TRADE)
	message = "Harvest milestone reached! Earned %d coins." % milestone.y
	_refresh()
	if journal.milestone_button.disabled:
		journal.focus_first_action()


func _upgrade_watering_can() -> void:
	if watering_upgraded or coins < WATERING_UPGRADE_PRICE or _is_exhausted():
		return
	coins -= WATERING_UPGRADE_PRICE
	watering_upgraded = true
	sound.play_effect(FarmAudio.Effect.TRADE)
	message = "Watering Can upgraded. Water a dry crop to also water its side neighbors."
	_refresh()
	journal.focus_first_action()


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
	for id in range(Catalog.SEED_COUNT):
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
	inventory_menu.backpack_upgrade.visible = inventory_grid.unlocked_rows < InventoryGrid.MAX_ROWS
	if inventory_menu.backpack_upgrade.visible:
		var price: int = BACKPACK_PRICES[inventory_grid.unlocked_rows - 1]
		inventory_menu.backpack_upgrade.text = "Expand backpack to %d slots  ·  %d coins" % [
			(inventory_grid.unlocked_rows + 1) * InventoryGrid.ROW_SIZE, price]
		inventory_menu.backpack_upgrade.disabled = coins < price


func _upgrade_backpack() -> void:
	var rows := inventory_grid.unlocked_rows
	if rows >= InventoryGrid.MAX_ROWS or coins < BACKPACK_PRICES[rows - 1]:
		return
	coins -= BACKPACK_PRICES[rows - 1]
	inventory_grid.unlocked_rows += 1
	message = "Backpack expanded to %d slots." % (inventory_grid.unlocked_rows * InventoryGrid.ROW_SIZE)
	sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()
	if not inventory_menu.backpack_upgrade.visible or inventory_menu.backpack_upgrade.disabled:
		inventory_menu.focus_first_action()


func _bag_has_room(kind: InventoryGrid.Kind, id: int) -> bool:
	if inventory_grid.can_add(kind, id):
		return true
	message = "Backpack full. Free a slot or expand it in the Farm Bag."
	return false


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
	if not _bag_has_room(InventoryGrid.Kind.BREAD, 0):
		_refresh()
		return
	coins -= FOOD_PRICE
	rations += 1
	sound.play_effect(FarmAudio.Effect.TRADE)
	message = "Bread added to your bag."
	_refresh()
	if food_menu.buy_button.disabled:
		food_menu.focus_first_action()


func _test_add_coins() -> void:
	coins += 100
	_refresh()


func _test_restore() -> void:
	clock.hunger = FarmClock.FULL
	clock.fatigue = 0.0
	_refresh()


func _test_needs() -> void:
	clock.hunger = 10.0
	clock.fatigue = 95.0
	_refresh()


func _test_night() -> void:
	_test_set_hour(22.0)


func _test_set_hour(hour: float) -> void:
	clock.hour = hour
	village.update_routines(day, hour, 0.0)
	_update_daylight()
	_refresh()


func _test_advance_day() -> void:
	clock.rest()
	_advance_day()
	village.update_routines(day, clock.hour, 0.0)
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


func _toggle_inventory() -> void:
	_toggle_menu(inventory_menu)


func _toggle_journal() -> void:
	_toggle_menu(journal)


func _open_journal() -> void:
	_show_menu(journal)
	journal.focus_first_action()


func _open_test_menu() -> void:
	_toggle_menu(test_menu)


func _toggle_menu(menu: ActionMenu) -> void:
	if active_menu == menu:
		_close_menu()
	else:
		_show_menu(menu)
		if menu != inventory_menu or not inventory_grid.focus_first_item():
			menu.focus_first_action()


func _show_menu(menu: Control) -> void:
	if active_menu != null:
		if active_menu == fishing_menu:
			_clear_bobber()
		active_menu.hide()
	active_menu = menu
	player.halt()
	player.animate(0.0, 0.1)
	menu_backdrop.show()
	menu.show()
	sound.play_effect(FarmAudio.Effect.MENU)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func _close_menu() -> void:
	if active_menu == null:
		return
	if active_menu == fishing_menu:
		_clear_bobber()
	active_menu.hide()
	active_menu = null
	menu_backdrop.hide()
	sound.play_effect(FarmAudio.Effect.MENU)
	_set_cursor_released(cursor_released)
	_update_interaction_targets()


func _buy_seed(id: int) -> void:
	if id < 0 or id >= Catalog.SEED_COUNT:
		return
	var crop := Catalog.crops[id]
	if not crop.grows_in(season) or coins < crop.seed_price():
		return
	if not _bag_has_room(InventoryGrid.Kind.SEED, id):
		_refresh()
		return
	coins -= crop.seed_price()
	seed_bag[id] = seed_bag.get(id, 0) + 1
	equipped_seed = id
	sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()


func _produce_value(stock: Dictionary[int, int]) -> int:
	var value := 0
	for id in stock:
		value += stock[id] * Catalog.crops[id].sale_price()
	return value


func _harvest_value() -> int:
	return _produce_value(produce)


func _update_shipping_menu() -> void:
	var selected_id := shipping_menu.stock.get_selected_id()
	shipping_menu.stock.clear()
	for id in range(Catalog.crops.size()):
		var quantity := produce.get(id, 0) as int
		if quantity > 0:
			shipping_menu.stock.add_item("%s ×%d" % [Catalog.crops[id].label, quantity], id)
			if id == selected_id:
				shipping_menu.stock.select(shipping_menu.stock.item_count - 1)
	shipping_menu.stock.disabled = shipping_menu.stock.item_count == 0
	if shipping_menu.stock.disabled:
		shipping_menu.stock.add_item("No produce in your bag")
	if shipping_menu.stock.selected < 0:
		shipping_menu.stock.select(0)
	shipping_menu.ship_button.disabled = shipping_menu.stock.disabled
	shipping_menu.retrieve_button.disabled = shipments.is_empty()
	shipping_menu.summary.text = "Dawn payout: %d coins" % _produce_value(shipments)


func _ship_selected_produce() -> void:
	if shipping_menu.stock.disabled:
		return
	var id := shipping_menu.stock.get_selected_id()
	var quantity := produce.get(id, 0) as int
	if quantity <= 0:
		return
	shipments[id] = shipments.get(id, 0) + quantity
	produce.erase(id)
	_refresh()
	if shipping_menu.ship_button.disabled:
		shipping_menu.focus_first_action()


func _retrieve_shipments() -> void:
	if not inventory_grid.can_add_stacks(InventoryGrid.Kind.HARVEST, shipments):
		message = "Free room in your backpack to return the shipment."
		_refresh()
		return
	for id in shipments:
		produce[id] = produce.get(id, 0) + shipments[id]
	shipments.clear()
	_refresh()
	shipping_menu.focus_first_action()


func _sell_harvest() -> void:
	var value := _harvest_value()
	coins += value
	produce.clear()
	if value > 0:
		sound.play_effect(FarmAudio.Effect.TRADE)
	_refresh()
