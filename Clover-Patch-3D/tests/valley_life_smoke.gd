extends SceneTree

const FARM := preload("res://farm.tscn")
const Save := preload("res://farm_save.gd")
const Weather := preload("res://valley_weather.gd")
const Catalog := preload("res://crop_catalog.gd")
const Bag := preload("res://inventory_grid.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Save.path = OS.get_temp_dir().path_join("clover-farm-test-%d.cfg" % OS.get_process_id())
	if not await _test():
		failures += 1
	await _test_orchard_shipping()
	await _test_fishing_and_cooking()
	await _test_block_terrain()
	await _test_valley_edges_and_picnics()
	await _test_collection_and_skills()
	await _test_valley_extras()
	await _test_world_interactions()
	await _test_controls_and_bag()
	await _test_village_story()
	await _test_town_events()
	await _test_resident_routines()
	if FileAccess.file_exists(Save.path):
		DirAccess.remove_absolute(Save.path)
	await create_timer(0.15).timeout
	print("Valley Life: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _key(farm: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	if code in [KEY_I, KEY_J, KEY_ESCAPE] or (code == KEY_E and farm.active_menu == farm.fishing_menu):
		farm._input(event)
	else:
		farm._unhandled_key_input(event)


func _test() -> bool:
	_check(Save.write({"harvested": 4}) == OK, "A legacy save fixture can be written.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	_check(farm.harvested == 4 and farm.claimed_milestones == 0 and not farm.watering_upgraded,
		"Older saves keep their harvest count and default to unclaimed milestones and the basic can.")
	_check(farm.find_children("*", "Label3D", true, false).is_empty(), "The world has no floating labels.")
	var tile: Vector2i = farm._target_plot()
	_check(tile != farm.NO_PLOT, "The new farm starts in reach of its first plot.")
	_check(farm.weather.kind == Weather.Kind.CLEAR, "The first morning is clear.")
	_key(farm, KEY_E)
	_key(farm, KEY_E)
	_key(farm, KEY_3)
	_check(farm.equipped_tool == farm.Tool.WATERING_CAN, "The shortcut equips the watering can.")
	_key(farm, KEY_E)
	_check(farm.plots[tile] == farm.Plot.WATERED, "E waters with the equipped can.")
	_check(farm.work_particles.emitting, "Working a plot triggers the voxel effect.")

	farm._test_advance_day()
	_check(farm.growing[tile].remaining == 3 and farm.plots[tile] == farm.Plot.PLANTED,
		"A watered crop advances one night, then dries on a clear morning.")
	farm._test_advance_day()
	_check(farm.weather.kind == Weather.Kind.RAIN and farm.weather.emitting,
		"The third morning has visible rain.")
	_check(farm.growing[tile].remaining == 3 and farm.plots[tile] == farm.Plot.WATERED,
		"Rain waters the plot for the coming night without retroactive growth.")
	farm._test_advance_day()
	_check(farm.growing[tile].remaining == 2, "Rain counts as watering overnight.")

	_key(farm, KEY_J)
	_check(farm.journal.visible and farm.journal.forecast.text.contains("Tomorrow:"),
		"J opens the forecast and delivery journal.")
	_check(farm.journal.order_buttons[0].disabled, "An order is disabled without enough stock.")
	_check(farm.journal.milestone_button.disabled and farm.journal.watering_upgrade_button.disabled,
		"Harvest rewards and upgrades are disabled when their requirements are unmet.")
	farm.produce[Catalog.TURNIP] = 4
	farm._refresh()
	var coins: int = farm.coins
	farm.clock.fatigue = 95.0
	farm._refresh()
	_check(farm.journal.order_buttons[0].disabled, "Exhaustion blocks delivery.")
	farm._deliver_order(0)
	_check(farm.coins == coins, "The delivery handler also enforces exhaustion.")
	farm.clock.fatigue = 20.0
	farm._refresh()
	farm.journal.order_buttons[0].pressed.emit()
	_check(farm.coins == coins + 20 and farm.produce[Catalog.TURNIP] == 1,
		"Delivery consumes exactly three turnips and pays the listed reward.")
	farm._deliver_order(0)
	_check(farm.coins == coins + 20 and farm.journal.order_buttons[0].disabled,
		"A completed order cannot be collected twice.")
	farm.harvested = 5
	farm._refresh()
	farm.journal.milestone_button.pressed.emit()
	farm._claim_harvest_milestone()
	_check(farm.coins == coins + 28 and farm.claimed_milestones == 1,
		"The five-crop milestone pays eight coins once.")
	coins = farm.coins
	farm.journal.watering_upgrade_button.pressed.emit()
	farm._upgrade_watering_can()
	_check(farm.coins == coins - 25 and farm.watering_upgraded,
		"The permanent watering upgrade costs 25 coins once.")
	_key(farm, KEY_J)

	var neighbor := Vector2i.ZERO
	for offset: Vector2i in farm.WATERING_NEIGHBORS:
		if farm.visuals.has(tile + offset):
			neighbor = tile + offset
			break
	_check(neighbor != Vector2i.ZERO, "The starting plot has a side neighbor.")
	farm.growing[neighbor] = farm.GrowingCrop.new(Catalog.TURNIP, 3)
	farm.plots[neighbor] = farm.Plot.PLANTED
	farm.plots[tile] = farm.Plot.PLANTED
	_key(farm, KEY_E)
	_check(farm.plots[tile] == farm.Plot.WATERED and farm.plots[neighbor] == farm.Plot.WATERED,
		"One use of the upgraded can waters the target and a planted side neighbor.")

	_key(farm, KEY_I)
	var bag: Bag = farm.inventory_grid
	var first := bag.stacks[0]
	bag._drop_on_slot(Vector2.ZERO, {"bag": bag, "source": 0, "stack": first}, 11)
	_key(farm, KEY_I)

	farm.player.position = farm.scenery.repair_sign
	farm.coins += 10
	farm._repair_cottage()
	farm._set_indoors(true)
	var bedside: Vector3 = farm.bed_point + Vector3(0, 0, 0.4)
	farm.player.position = bedside
	farm.clock.fatigue = 70.0
	farm._try_sleep()
	_check(FileAccess.file_exists(Save.path), "Sleeping writes an autosave.")
	var sleep_day: int = farm.day
	farm._test_night()
	_key(farm, KEY_ESCAPE)
	farm.pause_controls.save_requested.emit()
	_check(farm.pause_controls.save_status.text == "Farm saved.", "The pause menu saves on demand.")
	farm._resume_game()
	var expected_coins: int = farm.coins
	var expected_plant: int = farm.growing[tile].remaining
	farm.queue_free()
	await create_timer(0.15).timeout

	farm = FARM.instantiate()
	root.add_child(farm)
	_check(farm.day == sleep_day and is_equal_approx(farm.clock.hour, 22.0),
		"Reload restores the manual save after the sleep autosave.")
	_check(farm.indoors and farm.player.position.is_equal_approx(bedside) and not farm.weather.emitting,
		"Reload restores the indoor position with no indoor precipitation.")
	_check(farm.cottage_repaired and farm.interior.get_node("Repaired").visible,
		"Reload restores cottage repairs.")
	_check(farm.coins == expected_coins and farm.completed_orders == 1 and farm.produce[Catalog.TURNIP] == 1,
		"Reload restores inventory, money, and completed deliveries.")
	_check(farm.claimed_milestones == 1 and farm.watering_upgraded,
		"Reload preserves claimed harvest milestones and the permanent watering upgrade.")
	_check(farm.growing[tile].remaining == expected_plant and farm.equipped_tool == farm.Tool.WATERING_CAN,
		"Reload restores crop growth and equipped tools.")
	bag = farm.inventory_grid
	_check(bag.stacks[11].kind == Bag.Kind.TOOL and bag.stacks[11].item_id == farm.Tool.HOE
		and bag.stacks[0] == null and bag.stacks[11].texture != null,
		"Reload preserves dragged inventory slots and rebuilds their icons.")

	farm.day = 30
	farm._test_advance_day()
	_check(farm.season == Catalog.Season.SUMMER and farm.completed_orders == 0 and not farm.growing.has(tile),
		"A season change resets the order board and removes out-of-season crops.")
	for winter_day in range(91, 121):
		if Weather.forecast(winter_day) == Weather.Kind.SNOW:
			farm.day = winter_day
			farm._set_indoors(false)
			_check(farm.weather.kind == Weather.Kind.SNOW and farm.weather.emitting
				and not farm._rain_waters(Catalog.TURNIP), "Winter snow renders without watering.")
			break
	farm.queue_free()
	await create_timer(0.15).timeout
	return true


func _test_orchard_shipping() -> void:
	_check(Save.write({"day": 61, "coins": 10, "produce": {Catalog.TURNIP: 2}}) == OK,
		"The fall test fixture can be written.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	var apple_tree: Node3D
	for fruit: Node3D in farm.scenery.orchard_fruit.values():
		if fruit.visible:
			apple_tree = fruit
			break
	_check(apple_tree != null, "Some orchard trees bear visible fruit on the first day of fall.")
	if apple_tree == null:
		farm.queue_free()
		return
	var apple_position := apple_tree.global_position
	farm.player.position = apple_position + Vector3(0, 0, 0.5)
	_key(farm, KEY_E)
	_key(farm, KEY_E)
	_check(not apple_tree.visible and farm.produce.get(Catalog.APPLE, 0) == 1 and farm.harvested == 0,
		"Picking removes visible fruit and yields one apple without advancing crop milestones.")
	farm.player.position = farm.scenery.shipping_bin + Vector3(0, 0, 0.7)
	_key(farm, KEY_E)
	_check(farm.shipping_menu.visible and farm.shipping_menu.stock.item_count == 2,
		"The cottage bin opens with both kinds of produce available for selection.")
	farm.shipping_menu.stock.select(1)
	farm.shipping_menu.ship_button.pressed.emit()
	_check(farm.shipments.get(Catalog.APPLE, 0) == 1 and not farm.produce.has(Catalog.APPLE)
		and farm.produce.get(Catalog.TURNIP, 0) == 2 and farm.coins == 10,
		"The selected apple is queued separately, with no payment before dawn.")
	_check(farm._save_farm() == OK, "A pending shipment and picked tree can be saved.")
	farm.queue_free()
	await process_frame


	farm = FARM.instantiate()
	root.add_child(farm)
	_check(not farm.scenery.orchard_fruit[apple_position].visible and farm.shipments.get(Catalog.APPLE, 0) == 1,
		"Reload restores the pending shipment and keeps the picked tree bare.")
	_key(farm, KEY_E)
	farm.shipping_menu.retrieve_button.pressed.emit()
	_check(farm.shipments.is_empty() and farm.produce.get(Catalog.APPLE, 0) == 1,
		"The bin can return queued produce to the bag before dawn.")
	farm.shipping_menu.stock.select(1)
	farm.shipping_menu.ship_button.pressed.emit()
	_key(farm, KEY_ESCAPE)
	farm._set_indoors(true)
	farm.player.position = farm.bed_point + Vector3(0, 0, 0.4)
	farm.clock.fatigue = 70.0
	farm._try_sleep()
	var expected_coins := 10 + Catalog.crops[Catalog.APPLE].sale_price()
	_check(farm.day == 62 and farm.coins == expected_coins and farm.shipments.is_empty()
		and farm.message.contains("Shipping earned"), "Sleeping pays out once and clears the bin.")
	_check(farm.picked_apple_trees.is_empty(), "A new day resets the picked-tree record.")
	farm.queue_free()
	await process_frame

	farm = FARM.instantiate()
	root.add_child(farm)
	farm._test_advance_day()
	_check(farm.coins == expected_coins and farm.shipments.is_empty(),
		"Reloading the dawn autosave and advancing again cannot repeat the payout.")
	farm.queue_free()
	await process_frame

func _test_fishing_and_cooking() -> void:
	_check(Save.write({"day": 1, "coins": 10, "produce": {Catalog.TURNIP: 1}}) == OK,
		"The pond and kitchen test fixture can be written.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	_check(not farm.scenery.fishing_spots.is_empty(), "Willow Pond has a fishing spot on its bank.")
	farm.player.position = farm.scenery.fishing_spots[0]
	_key(farm, KEY_E)
	_check(farm.fishing_menu.visible and farm.fishing_menu.phase == farm.Fishing.Phase.WAITING,
		"E at the pond casts a line.")
	_check(farm.bobber.visible and not farm.fishing_menu.catch_icon.visible,
		"Casting shows the bobber and clears the previous catch icon.")
	farm.bobber_tween.custom_step(0.3)
	_check(farm.bobber.position.is_equal_approx(farm.bobber_target) and farm.work_particles.emitting,
		"The cast lands in the water and emits a splash.")
	_key(farm, KEY_E)
	_check(farm.fishing_menu.phase == farm.Fishing.Phase.DONE and not farm.produce.has(Catalog.POND_PERCH),
		"Reeling before the bite yields no fish.")
	_check(not farm.bobber.visible, "A missed cast clears the bobber.")
	_key(farm, KEY_E)
	_key(farm, KEY_E)
	farm.fishing_menu._process(3.0)
	_check(farm.fishing_menu.phase == farm.Fishing.Phase.BITING, "The cast enters its reel window.")
	_check(farm.fishing_menu.instructions.modulate != Color.WHITE,
		"The bite changes the cue color during the reel window.")
	farm.fishing_menu._process(2.0)
	_check(farm.fishing_menu.phase == farm.Fishing.Phase.DONE and not farm.produce.has(Catalog.POND_PERCH),
		"Missing the reel window lets the fish escape.")
	_key(farm, KEY_E)
	_key(farm, KEY_E)
	farm.fishing_menu._process(3.0)
	_key(farm, KEY_E)
	_check(farm.produce.get(Catalog.POND_PERCH, 0) == 1 and farm.harvested == 0,
		"Reeling during a bite adds one fish without counting it as a crop.")
	_check(farm.fishing_menu.catch_icon.visible and not farm.bobber.visible,
		"A catch shows the fish icon and clears the bobber.")
	_key(farm, KEY_E)
	farm.player.position = farm.scenery.shipping_bin + Vector3(0, 0, 0.7)
	_key(farm, KEY_E)
	_check(farm.shipping_menu.visible and farm.shipping_menu.stock.get_item_id(1) == Catalog.POND_PERCH,
		"The fish can be selected for shipping.")
	_key(farm, KEY_ESCAPE)

	farm._set_indoors(true)
	farm.player.position = farm.kitchen_point
	_key(farm, KEY_E)
	_check(not farm.cooking_menu.visible, "The damaged cottage kitchen is locked.")
	farm._set_indoors(false)
	farm.player.position = farm.scenery.repair_sign
	_key(farm, KEY_E)
	farm._set_indoors(true)
	farm.player.position = farm.kitchen_point
	farm.clock.hunger = 30.0
	farm.clock.fatigue = 95.0
	_key(farm, KEY_E)
	_check(farm.cooking_menu.visible and not farm.cooking_menu.meal_buttons[2].disabled,
		"The repaired kitchen can cook an available fish even when exhausted.")
	_check(farm.cooking_menu.meal_buttons[1].disabled, "A recipe with missing ingredients is disabled.")
	farm.cooking_menu.meal_buttons[2].pressed.emit()
	farm.cooking_menu.meal_buttons[2].pressed.emit()
	_check(farm.produce.get(Catalog.POND_PERCH, 0) == 0 and farm.clock.hunger == 70.0
		and farm.clock.fatigue == 65.0, "Cooking consumes the fish once and restores food and fatigue.")
	farm.cooking_menu.meal_buttons[0].pressed.emit()
	_check(farm.rations == 1 and farm.produce.get(Catalog.TURNIP, 0) == 0
		and farm.clock.hunger == 100.0 and farm.clock.fatigue == 23.0,
		"A mixed recipe consumes bread and produce and caps food at full.")
	farm.queue_free()
	await process_frame


func _test_block_terrain() -> void:
	var farm := FARM.instantiate()
	root.add_child(farm)
	var peak := Vector2(-13.5, -26)
	_check(farm.layout.elevation(peak) == 8.0 and farm.layout.elevation(Vector2(-5.5, 0)) == 0.0,
		"The north peak rises eight blocks and the farmer starts on level ground.")
	var cottage_exit: Vector3 = farm.scenery.cottage_door + Vector3(0, 0, 0.38)
	_check(cottage_exit.y == 0.0 and farm.layout.grounded(cottage_exit) == cottage_exit,
		"The cottage door opens onto level ground.")
	var terrace := Vector2(-13.5, -20)
	var elevation: float = farm.layout.elevation(terrace)
	_check(elevation > 0.0 and elevation == roundf(elevation)
		and elevation == farm.layout.elevation(terrace + Vector2(0.4, 0.4)),
		"An elevated column has a level top at a whole-block height.")
	var ground_mesh: Mesh = farm.scenery.ground.mesh
	var normals: PackedVector3Array = ground_mesh.surface_get_arrays(1)[Mesh.ARRAY_NORMAL]
	_check(is_equal_approx(ground_mesh.get_aabb().size.y, 16.0)
		and not normals.is_empty() and is_zero_approx(normals[0].y),
		"The rendered terrain contains vertical block faces.")
	farm.player.position = Vector3(peak.x, 0.0, -15.0)
	farm.camera.yaw = 0.0
	var saw_takeoff := false
	var saw_landing := false
	for step in range(330):
		var was_hopping: bool = farm.player.step_elapsed < farm.player.step_duration
		farm.player.walk(Vector2i.UP, farm.camera.yaw, farm._walk_speed(), 1.0 / 60.0)
		var hopping: bool = farm.player.step_elapsed < farm.player.step_duration
		if hopping and not was_hopping:
			var feet: Vector3 = farm.player.position
			var launch: Vector3 = farm.player.step_start
			var landing: Vector3 = farm.player.step_end
			saw_takeoff = saw_takeoff or (feet.y > launch.y and feet.y < landing.y
				and is_equal_approx(feet.z, launch.z))
		if was_hopping and not hopping:
			saw_landing = saw_landing or farm.player.position.is_equal_approx(farm.player.step_end)
		if farm.player.position.z < -22.0 and not hopping:
			break
	_check(saw_takeoff and saw_landing, "The farmer rises before crossing the ledge and lands on its top.")
	var at: Vector3 = farm.player.position
	_check(at.z < -22.0 and at.y >= 5.0 and at.y == farm.layout.elevation(Vector2(at.x, at.z)),
		"Normal walking climbs the block terraces and keeps the farmer on the surface.")
	farm._restore_position({"position": Vector3(peak.x, 0, peak.y)})
	_check(farm.player.position.y == 8.0, "Saved outdoor positions resolve to the current terrain height.")
	farm.player.walk_velocity = Vector3.ZERO
	farm.camera.yaw = 0.0
	var saw_descent := false
	var braced_for_landing := false
	var landed_below := false
	for frame in range(240):
		var was_airborne: bool = farm.player.step_elapsed < farm.player.step_duration
		var distance: float = farm.player.walk(Vector2i.DOWN, farm.camera.yaw, farm._walk_speed(), 1.0 / 60.0)
		farm.player.animate(distance, 1.0 / 60.0)
		var airborne: bool = farm.player.step_elapsed < farm.player.step_duration
		if airborne and farm.player.position.y < farm.player.step_start.y and farm.player.position.y > farm.player.step_end.y:
			saw_descent = true
			braced_for_landing = braced_for_landing or farm.player.arms[1].rotation.z > 0.1
		if was_airborne and not airborne:
			landed_below = farm.player.step_end.y < farm.player.step_start.y and farm.player.position.is_equal_approx(farm.player.step_end)
			break
	_check(saw_descent and braced_for_landing, "Walking off a block passes through an airborne fall pose.")
	_check(landed_below and is_zero_approx(farm.player.arms[1].rotation.z),
		"The fall lands on the lower terrace and releases the airborne pose.")
	farm.queue_free()
	await process_frame


func _test_valley_edges_and_picnics() -> void:
	var farm := FARM.instantiate()
	root.add_child(farm)
	var crossings := [
		[Vector3(0, 0, -47), Vector3(0, 0, -58)],
		[Vector3(60, 0, 54), Vector3(60, 0, 67)],
		[Vector3(-31, 0, 0), Vector3(-40, 0, 0)],
		[Vector3(110, 0, 27), Vector3(122, 0, 27)],
	]
	for crossing: Array in crossings:
		var start: Vector3 = farm.layout.grounded(crossing[0])
		var far_side: Vector3 = crossing[1]
		var target: Vector2 = farm.player.walk_destination(start, far_side)
		_check(target.distance_to(Vector2(far_side.x, far_side.z)) > 2.0
			and farm.layout.elevation(target) >= 2.0,
			"The outer ridge blocks crossing before the map edge.")
	var pass_start := Vector3(-26, 0, 14)
	var blocked: Vector2 = farm.player.walk_destination(pass_start, Vector3(-30, 0, 14))
	_check(blocked.x > -28.0, "The rockslide physically blocks the old pass.")
	farm.player.position = pass_start
	_key(farm, KEY_E)
	_check("rockslide" in farm.message, "Inspecting the closed pass explains the rockslide.")
	farm.player.position = Vector3(12.5, 0, 8.35)
	farm.clock.hour = 10.0
	farm.clock.fatigue = 25.0
	_key(farm, KEY_E)
	_check(is_equal_approx(farm.clock.hour, 10.5) and is_equal_approx(farm.clock.fatigue, 13.0),
		"A picnic break trades half an hour for fatigue recovery.")
	farm.queue_free()
	await process_frame


func _test_collection_and_skills() -> void:
	_check(Save.write({"produce": {Catalog.POND_PERCH: 1, Catalog.MOONDROP: 1, Catalog.APPLE: 2},
		"skill_practice": Vector3i(7, 3, 3), "repaired": true}) == OK, "The progress fixture saves.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	_key(farm, KEY_E)
	var after_tilling: float = farm.clock.fatigue
	_key(farm, KEY_E)
	_check(is_equal_approx(farm.clock.fatigue - after_tilling, 5.5),
		"Successful plot work improves farming and lowers the next action's fatigue.")
	farm.player.position = farm.scenery.fishing_spots[0]
	_key(farm, KEY_E)
	farm.fishing_menu._process(3.0)
	_check(is_equal_approx(farm.fishing_menu.remaining, 1.8), "Fishing practice extends the actual reel window.")
	_key(farm, KEY_ESCAPE)
	farm._set_indoors(true)
	farm.player.position = farm.kitchen_point
	farm.clock.fatigue = 60.0
	_key(farm, KEY_E)
	farm.cooking_menu.meal_buttons[1].pressed.emit()
	_check(is_equal_approx(farm.clock.fatigue, 11.0), "Cooking practice boosts meal recovery.")
	_key(farm, KEY_J)
	farm._open_collection()
	var coins: int = farm.coins
	for button: Button in farm.collection_menu.donation_buttons:
		button.pressed.emit()
	farm.collection_menu.donation_buttons[2].pressed.emit()
	_check(farm.donated_specimens == farm.CLASSIC_COLLECTION and farm.coins == coins + 18
		and farm.produce.get(Catalog.APPLE, -1) == 0, "Donations use one specimen each and pay once.")
	_check(farm._save_farm() == OK, "The collection and skills can be saved.")
	farm.queue_free()
	await process_frame

	farm = FARM.instantiate()
	root.add_child(farm)
	_key(farm, KEY_J)
	farm._open_collection()
	_check(farm.collection_menu.donation_buttons[0].disabled and farm.skills.practice == Vector3i(9, 3, 4)
		and farm.coins == coins + 18, "Reload preserves donated specimens, coins, and skill practice.")
	farm.queue_free()
	await process_frame


func _test_valley_extras() -> void:
	_check(Save.write({"day": 1, "coins": 5}) == OK, "The valley extras fixture saves.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	var waters: Array = farm.scenery.fishing_waters
	_check(waters.size() == farm.scenery.fishing_spots.size() and waters[1].fish == "trout" and waters[2].fish == "carp",
		"Each pond records what bites there.")
	farm.player.position = farm.scenery.fishing_spots[1]
	_key(farm, KEY_E)
	_check(farm.fishing_menu.visible and farm.hooked_fish == Catalog.LAKE_TROUT,
		"Clover Lake hooks Lake Trout on a clear morning.")
	_key(farm, KEY_ESCAPE)
	farm.clock.hour = 19.0
	seed(3)
	var moonfin := false
	for attempt in range(60):
		moonfin = moonfin or farm._choose_catch(0) == Catalog.MOONFIN
	_check(moonfin, "Moonfin can bite at dusk.")
	farm.clock.hour = 9.0

	var berries := -1
	var mushroom := -1
	for index in range(farm.scenery.forage_spots.size()):
		var item: String = farm.scenery.forage_spots[index].item
		if item == "berries" and berries < 0 and farm._forage_available(index):
			berries = index
		if item == "mushroom" and mushroom < 0:
			mushroom = index
	_check(berries >= 0 and not farm._forage_available(mushroom), "Spring has berries but no chanterelles.")
	var spot: Vector3 = farm.layout.grounded(farm.scenery.forage_spots[berries].at)
	farm.player.position = spot + Vector3(0, 0, 0.5)
	_key(farm, KEY_E)
	_check(farm.produce.get(Catalog.WILD_BERRIES, 0) == 1 and not farm.scenery.forage_spots[berries].goods.visible,
		"Gathering takes the berries and empties the bush.")
	_key(farm, KEY_E)
	_check(farm.produce.get(Catalog.WILD_BERRIES, 0) == 1, "A spot gives one find per day.")
	_check(farm._save_farm() == OK, "Gathered spots save.")
	farm.queue_free()
	await process_frame

	farm = FARM.instantiate()
	root.add_child(farm)
	_check(not farm._forage_available(berries), "Reloading keeps today's gathered spot empty.")
	farm._test_advance_day()
	farm._test_advance_day()
	_check(farm._forage_available(berries), "Forage spots refill on their next turn.")
	for id in farm.SPECIMENS:
		farm.produce[id] = 1
	var coins: int = farm.coins
	_key(farm, KEY_J)
	farm._open_collection()
	for button: Button in farm.collection_menu.donation_buttons:
		button.pressed.emit()
	_check(farm.donated_specimens == farm.COMPLETE_COLLECTION and farm.coins == coins + 18 + 40,
		"Finishing all nine specimens pays the classics reward and the full-collection bonus.")
	_key(farm, KEY_ESCAPE)

	farm._test_set_hour(22.0)
	_check(farm.scenery._lamp_glow.albedo_color.a > 0.5, "Lantern light pools glow at night.")
	farm._test_set_hour(12.0)
	_check(is_zero_approx(farm.scenery._lamp_glow.albedo_color.a), "Lantern light pools fade out by day.")
	farm.scenery.set_wet(true)
	_check(farm.scenery._puddles.visible, "Rain leaves puddles on the paths.")
	farm.scenery.set_season(Catalog.Season.WINTER)
	_check(farm.scenery._snow_caps.all(func(cap: Node3D) -> bool: return cap.visible)
		and not farm.scenery._flowers._nodes[0].visible, "Winter adds snow to the roofs and hides the flowers.")
	farm.scenery.set_season(Catalog.Season.SPRING)
	_check(not farm.scenery._snow_caps[1].visible, "Snow melts in spring.")
	farm.queue_free()
	await process_frame


## Stands the farmer within `radius` of `center` where E would use a world interaction of `kind`.
func _reach(farm: Node, center: Vector3, radius: float, kind: int) -> bool:
	for step in range(8):
		var angle := step * TAU / 8.0
		farm.player.position = farm.layout.grounded(
			Vector3(center.x + cos(angle) * radius, 0, center.z + sin(angle) * radius))
		if (farm._interaction(farm._target_plot()) == farm.Interaction.WORLD
				and farm.world.nearby(farm.player.position).get("kind") == kind):
			return true
	return false


func _carried(farm: Node) -> int:
	var total: int = farm.coins
	for count: int in farm.produce.values():
		total += count
	for count: int in farm.seed_bag.values():
		total += count
	return total


func _test_world_interactions() -> void:
	_check(Save.write({"day": 1, "coins": 5, "bread": 2}) == OK, "The world interactions fixture saves.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	var world: Node = farm.world
	var scenery: Node = farm.scenery
	var Kind: Dictionary = world.Kind
	seed(11)

	_check(farm.sound.music.playing and farm.sound.music.stream == farm.sound.SEASON_MUSIC[farm.season],
		"The season's theme plays.")
	farm.sound.play_season(Catalog.Season.WINTER, true)
	_check(farm.sound.music.stream == farm.sound.SEASON_MUSIC[Catalog.Season.WINTER], "Each season has its own theme.")
	farm.sound.play_season(farm.season, true)

	# Signs and petition boards.
	var plain := -1
	var board := -1
	for index in range(scenery.signs.size()):
		var text: String = scenery.signs[index].text
		if text.is_empty() or (plain >= 0 and not text.begins_with("@")) or (board >= 0 and text.begins_with("@")):
			continue
		if _reach(farm, scenery.signs[index].at, 0.7, Kind.SIGN) and world.nearby(farm.player.position).index == index:
			_key(farm, KEY_E)
			if text.begins_with("@"):
				board = index
				_check(farm.message.begins_with("Petition board") and "Tomorrow's sky" in farm.message,
					"A petition board shows the daily notice with tomorrow's weather.")
			else:
				plain = index
				_check(farm.message == text, "Reading a sign shows its text.")
	_check(plain >= 0 and board >= 0, "A sign and a petition board can each be reached and read.")

	# Tree shaking.
	var tree := -1
	for index in range(scenery.tree_spots.size()):
		if _reach(farm, scenery.tree_spots[index], 0.7, Kind.TREE):
			tree = world.nearby(farm.player.position).index
			break
	_check(tree >= 0, "A tree is in reach to shake.")
	if tree >= 0:
		var fatigue: float = farm.clock.fatigue
		var before := _carried(farm)
		_key(farm, KEY_E)
		_check(world.shaken.has(tree) and farm.clock.fatigue > fatigue and _carried(farm) >= before,
			"Shaking a tree tires the farmer, marks the tree, and never costs anything.")
		_check(world._is_wobbling(scenery._trees, tree), "A shaken tree wobbles.")
		world.update(1.0, farm.player.position, 0.0)
		_check(not world._is_wobbling(scenery._trees, tree), "The wobble settles within a second.")
		before = _carried(farm)
		_key(farm, KEY_E)
		_check(_carried(farm) == before and "shaken today" in farm.message, "A tree drops things once per day.")

	# Feeding the ducks.
	var pond := -1
	for index in range(scenery.ponds.size()):
		var area: Rect2 = scenery.ponds[index].area
		var middle := area.get_center()
		if scenery.ponds[index].ducks.is_empty():
			continue
		for bank: Vector2 in [Vector2(area.position.x - 0.6, middle.y), Vector2(area.end.x + 0.6, middle.y),
				Vector2(middle.x, area.end.y + 0.6)]:
			farm.player.position = farm.layout.grounded(Vector3(bank.x, 0, bank.y))
			if (farm._interaction(farm._target_plot()) == farm.Interaction.WORLD
					and world.nearby(farm.player.position).get("kind") == Kind.DUCKS):
				pond = index
				break
		if pond >= 0:
			break
	_check(pond >= 0, "A pond with ducks has a bank to feed them from.")
	if pond >= 0:
		var unlucky := false
		for attempt in range(60):
			unlucky = unlucky or farm._choose_catch(-1) == Catalog.MOONFIN
		_check(not unlucky, "Moonfin stays away from plain water on a clear morning.")
		_key(farm, KEY_E)
		_check(farm.rations == 1 and world.ducks_fed and world.luck, "Feeding the ducks costs a bread and brings luck.")
		_check(scenery.ponds[pond].ducks[0].lure_time > 0.0, "Fed ducks swim toward the farmer.")
		var lucky := false
		for attempt in range(60):
			lucky = lucky or farm._choose_catch(-1) == Catalog.MOONFIN
		_check(lucky, "Duck luck lets Moonfin bite anywhere.")
		_key(farm, KEY_E)
		_check(farm.rations == 0 and not str(world.nearby(farm.player.position).get("blocked", "")).is_empty(),
			"Without bread the ducks only show a hint.")
		_key(farm, KEY_E)
		_check(farm.rations == 0, "Feeding with no bread does nothing.")

	# Wishing well.
	_check(_reach(farm, scenery.well, 1.3, Kind.WELL), "The wishing well can be used from Market Square.")
	var coins: int = farm.coins
	_key(farm, KEY_E)
	_check(world.wished and farm.coins in [coins - 1, coins + 3], "A wish costs one coin, and may pay four back.")
	coins = farm.coins
	_key(farm, KEY_E)
	_check(farm.coins == coins and "already heard" in farm.message, "The well grants one wish a day.")

	# Town bell.
	_check(_reach(farm, scenery.bell, 1.2, Kind.BELL), "The town bell can be reached.")
	_key(farm, KEY_E)
	_check("bell rings" in farm.message and farm.clock.clock_text() in farm.message, "Ringing the bell tells the time.")

	# Buried finds.
	var digs: Array = world.active_digs()
	_check(digs.size() == world.DIGS_PER_DAY, "Four buried finds sparkle each day.")
	var spot: Dictionary = scenery.dig_spots[digs[0]]
	_check(spot.sparkle.visible and _reach(farm, spot.at, 0.5, Kind.DIG), "Today's find sparkles and can be reached.")
	_key(farm, KEY_3)
	var held := _carried(farm)
	_key(farm, KEY_E)
	_check(farm.equipped_tool == farm.Tool.HOE, "Digging picks up the Hoe by itself.")
	_check(world.dug.has(spot.at) and not spot.sparkle.visible and _carried(farm) > held,
		"Digging gives a find and removes the sparkle.")
	_check(world.nearby(farm.player.position).get("kind") != Kind.DIG, "A dug spot cannot be dug again.")

	# Landmarks.
	var total: int = scenery.landmarks.size()
	var first: Dictionary = {}
	for landmark: Dictionary in scenery.landmarks:
		if not world.discovered.has(landmark.name):
			first = landmark
			break
	_check(total > 0 and not first.is_empty(), "The valley has places left to discover.")
	if not first.is_empty():
		coins = farm.coins
		world.update(0.0, first.at, 0.0)
		_check(world.discovered.has(first.name) and farm.coins == coins + world.DISCOVERY_COINS
			and farm.message.begins_with("Discovered " + first.name), "Walking into a landmark discovers it and pays 2 coins.")
		coins = farm.coins
		world.update(0.0, first.at, 0.0)
		_check(farm.coins == coins, "A landmark pays once.")
		var remaining: int = total - world.discovered_count()
		for landmark: Dictionary in scenery.landmarks:
			world.update(0.0, landmark.at, 0.0)
		_check(world.discovered_count() == total
			and farm.coins == coins + remaining * world.DISCOVERY_COINS + world.EXPLORER_REWARD,
			"Finding every landmark pays the explorer reward.")
		farm._open_collection()
		_check(farm.find_children("*", "Label", true, false).any(func(label: Label) -> bool:
			return "Places discovered · %d of %d" % [total, total] in label.text), "The Collection page shows the places found.")
		_key(farm, KEY_ESCAPE)

	# Save, reload, and the next morning.
	_check(farm._save_farm() == OK, "World interaction state saves.")
	farm.queue_free()
	await process_frame
	farm = FARM.instantiate()
	root.add_child(farm)
	world = farm.world
	_check(world.shaken.has(tree) and world.dug.has(spot.at) and world.wished and world.ducks_fed and world.luck,
		"Reloading keeps today's shaken tree, dug spot, wish, and duck luck.")
	_check(world.discovered_count() == total, "Reloading keeps discovered landmarks.")
	_check(world.active_digs() == digs and not farm.scenery.dig_spots[digs[0]].sparkle.visible,
		"Reloading keeps today's finds, with the dug one still gone.")
	farm._test_advance_day()
	_check(world.shaken.is_empty() and world.dug.is_empty() and not world.wished and not world.ducks_fed and not world.luck,
		"A new day resets trees, digs, the wish, and duck luck.")
	_check(world.discovered_count() == total and world.active_digs().size() == world.DIGS_PER_DAY,
		"A new day keeps discoveries and buries four new finds.")
	farm.queue_free()
	await process_frame


func _test_controls_and_bag() -> void:
	_check(Save.write({"day": 1, "coins": 5}) == OK, "The controls fixture saves.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	var tile: Vector2i = farm._target_plot()
	_key(farm, KEY_4)
	_key(farm, KEY_E)
	_check(farm.plots[tile] == farm.Plot.TILLED and farm.equipped_tool == farm.Tool.HOE,
		"E on bare soil picks up the Hoe and tills, whatever tool was held.")
	_key(farm, KEY_E)
	_key(farm, KEY_E)
	_check(farm.plots[tile] == farm.Plot.WATERED and farm.equipped_tool == farm.Tool.WATERING_CAN,
		"E plants, then picks up the Watering Can and waters.")
	_check(farm.last_worked_plot == tile, "The farm remembers the last plot worked, so holding E moves on.")

	var other := -1
	for id in range(Catalog.SEED_COUNT):
		if id != farm.equipped_seed and id != Catalog.GRASS and Catalog.crops[id].grows_in(farm.season):
			other = id
			break
	farm.seed_bag.clear()
	farm.seed_bag[farm.equipped_seed] = 1
	farm.seed_bag[other] = 3
	farm.plots[tile] = farm.Plot.TILLED
	farm.growing.erase(tile)
	_key(farm, KEY_E)
	_check(farm.equipped_seed == other and farm.seed_bag[other] == 3,
		"Planting the last seed switches to another in-season seed in the bag.")

	var grid: Control = farm.inventory_grid
	farm.rations = 2
	farm.produce[Catalog.WILD_BERRIES] = 3
	farm._update_bag()
	var before := 0
	for stack in grid.stacks:
		before += stack.quantity if stack != null else 0
	grid.stacks.reverse()
	grid.stacks.insert(1, null)
	grid.sort()
	var after := 0
	var ordered := true
	var rank := {Bag.Kind.TOOL: 0, Bag.Kind.SEED: 1, Bag.Kind.BREAD: 2, Bag.Kind.HARVEST: 3}
	for index in range(grid.stacks.size()):
		ordered = ordered and grid.stacks[index] != null
		if ordered:
			after += grid.stacks[index].quantity
			if index > 0:
				ordered = rank[grid.stacks[index - 1].kind] <= rank[grid.stacks[index].kind]
	_check(ordered and after == before and grid.stacks[0].kind == Bag.Kind.TOOL,
		"Sorting the bag closes gaps, keeps every item, and puts tools first.")

	farm.clock.hunger = 40.0
	farm._update_bag()
	var bread := -1
	for index in range(grid.stacks.size()):
		if grid.stacks[index] != null and grid.stacks[index].kind == Bag.Kind.BREAD:
			bread = index
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	grid._slot_input(click, bread)
	_check(farm.rations == 1, "Right-clicking a bag slot uses the item.")

	var reach: float = farm.camera.distance
	farm.camera.zoom(1)
	_check(farm.camera.distance > reach, "The camera zooms out.")
	for step in range(30):
		farm.camera.zoom(-1)
	_check(is_equal_approx(farm.camera.distance, farm.camera.MIN_DISTANCE), "The camera stops at its closest zoom.")

	farm._set_indoors(true)
	farm.player.position = farm.bed_point
	farm.clock.fatigue = 0.0
	farm.clock.hour = 10.0
	farm._try_sleep()
	_check(farm.day == 1, "A rested farmer cannot sleep in the morning.")
	farm.clock.hour = 19.0
	farm._try_sleep()
	_check(farm.day == 2, "From 18:00 the farmer can go to bed without being tired.")
	farm.queue_free()
	await process_frame


func _visit_resident(farm: Node, id: String) -> void:
	if farm.active_menu != null:
		_key(farm, KEY_ESCAPE)
	farm.player.position = farm.village.models[farm.village.resident_indices[id]].position
	_key(farm, KEY_E)
	_check(farm.active_menu == farm.resident_menu and farm.village.residents[farm.resident_index].id == id,
		"The normal interaction opens %s's dialogue." % id)


func _choose_village(farm: Node, action: String) -> void:
	var index: int = farm.resident_actions.find(action)
	_check(index >= 0, "Village dialogue offers %s." % action)
	if index >= 0:
		farm.resident_menu.choices[index].pressed.emit()


func _test_village_story() -> void:
	_check(Save.write({"day": 3, "hour": 17.0, "produce": {Catalog.POND_PERCH: 1},
		"village": {"favor": {"mara": 18}}}) == OK, "The village fixture saves.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	_check(farm.village.residents.size() == 32 and farm.village.models.size() == 32,
		"All 32 character JSON files load into the playable valley.")
	_visit_resident(farm, "mara")
	farm.resident_menu.gifts.select(1)
	farm.resident_menu.gift_button.pressed.emit()
	_check(farm.village.favor.mara == 15 and farm.produce[Catalog.POND_PERCH] == 0
		and farm.resident_menu.line.text.contains("flour"), "A disliked gift consumes the item and triggers her own reply.")
	farm.resident_menu.gift_button.pressed.emit()
	_check(farm.rations == 2, "A second gift on the same day cannot be given.")
	_choose_village(farm, "supper-families")
	_check(farm.village.supper_table.visible, "The supper sets a table in the meadow that evening.")
	_choose_village(farm, "date")
	for witness in ["tess", "vera", "orin"]:
		_visit_resident(farm, witness)
		_choose_village(farm, "witness")
	_choose_village(farm, "supper-reaction")
	_check(farm.resident_menu.line.text.contains("place set for us"), "Orin reacts to the chosen supper dedication.")
	_visit_resident(farm, "iona")
	_check(not farm.resident_actions.has("publish"), "The hearing opens the day after collecting the accounts.")
	_key(farm, KEY_ESCAPE)
	farm._test_advance_day()
	farm._test_set_hour(11.0)
	_visit_resident(farm, "mara")
	farm.resident_menu.gifts.select(0)
	farm.resident_menu.gift_button.pressed.emit()
	_check(farm.village.favor.mara == 27 and farm.rations == 1
		and farm.resident_menu.line.text.contains("scored"), "A favorite gift raises favor and triggers her bread reply.")
	_choose_village(farm, "partner")
	_visit_resident(farm, "iona")
	var seeds: int = farm.seed_bag[Catalog.TURNIP]
	_choose_village(farm, "trust")
	_check(farm.village.resolution == 2 and farm.seed_bag[Catalog.TURNIP] == seeds + 8,
		"The hearing choice persists in state and grants the matching reward.")
	_check(farm._save_farm() == OK, "The village can be saved after a story choice.")
	farm.queue_free()
	await process_frame
	farm = FARM.instantiate()
	root.add_child(farm)
	_check(farm.village.supper == 1 and farm.village.resolution == 2 and farm.village.partner == "mara"
		and farm.village.favor.mara == 27, "Reload preserves the events, romance, and favor.")
	farm.queue_free()
	await process_frame


func _test_town_events() -> void:
	_check(Save.write({"day": 2, "hour": 11.0}) == OK, "A legacy save can start the town event rotation.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	var host: String = farm.village.town_event_host
	var event: Dictionary = farm.village.town_events[host]
	_key(farm, KEY_J)
	farm._open_village_journal()
	_check(farm.village_menu.story.text.contains(event.title), "The journal announces the daily town event.")
	_visit_resident(farm, host)
	var before: int = farm.village.affinity(farm.resident_index)
	_choose_village(farm, "town-event")
	_check(farm.resident_menu.line.text == event.prompt and farm.resident_menu.choices[1].visible,
		"The host opens the scene with both choices available.")
	_choose_village(farm, "town-event-second")
	_check(farm.resident_menu.line.text == event.choices[1].reply and farm.village.affinity(farm.resident_index) == before + 3,
		"The chosen reply appears and favor increases once.")
	_check(farm._save_farm() == OK, "The selected town event can be saved.")
	farm.queue_free()
	await process_frame
	farm = FARM.instantiate()
	root.add_child(farm)
	_visit_resident(farm, host)
	_check(farm.village.town_event_host == host and farm.village.town_event_choice == 1
		and not farm.resident_actions.has("town-event"), "Reload keeps the event and its completed choice.")
	var drawn := {host: true}
	for next_day in range(3, 34):
		farm.village.schedule_town_event(next_day)
		drawn[farm.village.town_event_host] = true
	_check(drawn.size() == 32, "Every resident hosts once before the rotation repeats.")
	farm.queue_free()
	await process_frame

func _test_resident_routines() -> void:
	var farm := FARM.instantiate()
	root.add_child(farm)
	farm.sound.music.stop()
	var village = farm.village
	_check(village.homes.size() == village.residents.size()
		and village.homes.size() == 32, "The expanded map assigns one home to each of the 32 villagers.")
	_check(village.homes.mara.position.distance_to(village.homes.ada.position) < 8.0
		and village.homes.niko.position.distance_to(village.homes.sol.position) == 6.0
		and village.homes.iona.position.distance_to(village.homes.tess.position) < 8.0
		and village.homes.hollis.position.distance_to(village.homes.ren.position) < 8.0
		and village.homes.ren.street == "Reedmere Walk", "Home placements preserve lore-based neighbors.")
	var layout_type := preload("res://world_layout.gd")
	var market_lane_cell := layout_type.tile_at(Vector3(3.5, 0, 4))
	var pond_cell := layout_type.tile_at(Vector3(93, 0, 32))
	_check(not village.navigation.get_id_path(market_lane_cell, pond_cell).is_empty(),
		"The woodland pond has a walkable approach from Market Lane.")
	var reachable := true
	var clear := true
	for index in range(village.residents.size()):
		var porch_cell := layout_type.tile_at(village._destination(index, "home"))
		reachable = reachable and not village.navigation.is_point_solid(porch_cell)
		var from := porch_cell
		for stage in ["work", "leisure", "home"]:
			var to: Vector2i = village._walkable_cell(village._destination(index, stage))
			var path: Array[Vector2i] = village.navigation.get_id_path(from, to)
			reachable = reachable and not path.is_empty() and path[-1] == to and from != to
			for cell in path:
				var point := preload("res://world_layout.gd").world_at(cell)
				clear = clear and not village._blocked(Vector2(point.x, point.z))
			from = to
	_check(reachable and clear, "Every resident can leave their porch, reach work and leisure, and return home.")
	village.update_routines(1, 6.0, 0.0)
	var index: int = village.resident_indices.mara
	var body: Node3D = village.models[index]
	var home: Dictionary = village.homes.mara
	var porch: Vector3 = farm.layout.grounded(home.position)
	var door: Node3D = home.door
	_check(not body.visible and village.nearby(body.position) == -1 and is_zero_approx(door.rotation.y),
		"A resident at home is hidden and cannot be talked to through their closed door.")
	village.update_routines(1, 6.55, 0.15)
	_check(not body.visible and absf(door.rotation.y) > 0.2, "Mara opens the door before stepping out.")
	village.update_routines(1, 6.55, 0.45)
	_check(body.visible and body.position.z < porch.z and body.position.z > porch.z - 1.22,
		"Mara walks through the doorway before reaching the porch.")
	for frame in range(140):
		village.update_routines(1, 7.0, 0.25)
	var work: Vector3 = farm.layout.grounded(preload("res://world_layout.gd").world_at(
		village._walkable_cell(village._destination(index, "work"))))
	_check(body.position.is_equal_approx(work) and is_zero_approx(door.rotation.y) and village.nearby(work) == index,
		"After closing the door, Mara walks to work and becomes available to talk.")
	var saw_return := false
	for frame in range(160):
		village.update_routines(1, 20.0, 0.25)
		saw_return = saw_return or village.routes[index].crossing == "enter"
	_check(saw_return and not body.visible and is_zero_approx(door.rotation.y),
		"At the end of the day Mara walks home, enters, and shuts the door.")
	farm._open_resident_tests()
	for item in range(farm.resident_test_menu.picker.item_count):
		if farm.resident_test_menu.picker.get_item_id(item) == index:
			farm.resident_test_menu.picker.select(item)
			break
	farm._test_favor_preset(12)
	village.last_gift.mara = farm.day
	farm._test_gift_kit()
	farm._test_open_dialogue()
	_check(village.affinity(index) == 12 and farm.resident_actions.has("date") and farm.rations >= 3
		and not village.last_gift.has("mara"), "Resident Test sets exact favor, stocks gifts, and previews dialogue without visit favor.")
	farm._open_resident_tests()
	farm._test_watch_departure()
	_check(not body.visible and farm.active_menu == null and farm.player.position.distance_to(porch) < 4.0
		and farm.clock.hour < 6.5 and farm.clock.hour > 6.3, "Departure test waits in front of the house just before the resident leaves.")
	_check(village.location_hint("vera", 1, 15.0) == "Reedmere", "Before testimony Vera visits the new bank.")
	village.evidence = 2
	_check(village.location_hint("vera", 1, 15.0) == "west of Willow Pond", "Vera revisits the old route after giving testimony.")
	farm.clock.hour = 6.0
	farm.clock.tick(24.0, false)
	_check(is_equal_approx(farm.clock.hour, 7.0), "One game hour takes 24 seconds at the slower clock rate.")
	farm._open_resident_directory()
	_check(farm.resident_directory.select.item_count == 32 and not farm.resident_directory.text.text.is_empty(),
		"The journal directory offers a schedule hint for every resident.")
	for player: AudioStreamPlayer in farm.sound.players.values():
		player.stop()
	await create_timer(0.15).timeout
	farm.queue_free()
	await process_frame
