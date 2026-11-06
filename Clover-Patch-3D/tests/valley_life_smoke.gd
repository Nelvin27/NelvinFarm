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
	_check(farm.journal.visible and farm.forecast_label.text.contains("Tomorrow:"),
		"J opens the forecast and delivery journal.")
	_check(farm.order_buttons[0].disabled, "An order is disabled without enough stock.")
	_check(farm.milestone_button.disabled and farm.watering_upgrade_button.disabled,
		"Harvest rewards and upgrades are disabled when their requirements are unmet.")
	farm.produce[Catalog.TURNIP] = 4
	farm._refresh()
	var coins: int = farm.coins
	farm.clock.fatigue = 95.0
	farm._refresh()
	_check(farm.order_buttons[0].disabled, "Exhaustion blocks delivery.")
	farm._deliver_order(0)
	_check(farm.coins == coins, "The delivery handler also enforces exhaustion.")
	farm.clock.fatigue = 20.0
	farm._refresh()
	farm.order_buttons[0].pressed.emit()
	_check(farm.coins == coins + 20 and farm.produce[Catalog.TURNIP] == 1,
		"Delivery consumes exactly three turnips and pays the listed reward.")
	farm._deliver_order(0)
	_check(farm.coins == coins + 20 and farm.order_buttons[0].disabled,
		"A completed order cannot be collected twice.")
	farm.harvested = 5
	farm._refresh()
	farm.milestone_button.pressed.emit()
	farm._claim_harvest_milestone()
	_check(farm.coins == coins + 28 and farm.claimed_milestones == 1,
		"The five-crop milestone pays eight coins once.")
	coins = farm.coins
	farm.watering_upgrade_button.pressed.emit()
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

	farm.avatar.position = farm.scenery.repair_sign
	farm.coins += 10
	farm._repair_cottage()
	farm._set_indoors(true)
	var bedside: Vector3 = farm.bed_point + Vector3(0, 0, 0.4)
	farm.avatar.position = bedside
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
	_check(farm.indoors and farm.avatar.position.is_equal_approx(bedside) and not farm.weather.emitting,
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
	farm.avatar.position = apple_position + Vector3(0, 0, 0.5)
	_key(farm, KEY_E)
	_key(farm, KEY_E)
	_check(not apple_tree.visible and farm.produce.get(Catalog.APPLE, 0) == 1 and farm.harvested == 0,
		"Picking removes visible fruit and yields one apple without advancing crop milestones.")
	farm.avatar.position = farm.scenery.shipping_bin + Vector3(0, 0, 0.7)
	_key(farm, KEY_E)
	_check(farm.shipping_menu.visible and farm.shipping_stock.item_count == 2,
		"The cottage bin opens with both kinds of produce available for selection.")
	farm.shipping_stock.select(1)
	farm.ship_button.pressed.emit()
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
	farm.retrieve_button.pressed.emit()
	_check(farm.shipments.is_empty() and farm.produce.get(Catalog.APPLE, 0) == 1,
		"The bin can return queued produce to the bag before dawn.")
	farm.shipping_stock.select(1)
	farm.ship_button.pressed.emit()
	_key(farm, KEY_ESCAPE)
	farm._set_indoors(true)
	farm.avatar.position = farm.bed_point + Vector3(0, 0, 0.4)
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
	farm.avatar.position = farm.scenery.fishing_spots[0]
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
	farm.avatar.position = farm.scenery.shipping_bin + Vector3(0, 0, 0.7)
	_key(farm, KEY_E)
	_check(farm.shipping_menu.visible and farm.shipping_stock.get_item_id(1) == Catalog.POND_PERCH,
		"The fish can be selected for shipping.")
	_key(farm, KEY_ESCAPE)

	farm._set_indoors(true)
	farm.avatar.position = farm.kitchen_point
	_key(farm, KEY_E)
	_check(not farm.cooking_menu.visible, "The damaged cottage kitchen is locked.")
	farm._set_indoors(false)
	farm.avatar.position = farm.scenery.repair_sign
	_key(farm, KEY_E)
	farm._set_indoors(true)
	farm.avatar.position = farm.kitchen_point
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
	farm.avatar.position = Vector3(peak.x, 0.0, -15.0)
	farm.camera_yaw = 0.0
	var saw_takeoff := false
	var saw_landing := false
	for step in range(330):
		var was_hopping: bool = farm.step_elapsed < farm.step_duration
		farm._advance_walk(Vector2i.UP, 1.0 / 60.0)
		var hopping: bool = farm.step_elapsed < farm.step_duration
		if hopping and not was_hopping:
			var feet: Vector3 = farm.avatar.position
			var launch: Vector3 = farm.step_start
			var landing: Vector3 = farm.step_end
			saw_takeoff = saw_takeoff or (feet.y > launch.y and feet.y < landing.y
				and is_equal_approx(feet.z, launch.z))
		if was_hopping and not hopping:
			saw_landing = saw_landing or farm.avatar.position.is_equal_approx(farm.step_end)
		if farm.avatar.position.z < -22.0 and not hopping:
			break
	_check(saw_takeoff and saw_landing, "The farmer rises before crossing the ledge and lands on its top.")
	var at: Vector3 = farm.avatar.position
	_check(at.z < -22.0 and at.y >= 5.0 and at.y == farm.layout.elevation(Vector2(at.x, at.z)),
		"Normal walking climbs the block terraces and keeps the farmer on the surface.")
	farm._restore_position({"position": Vector3(peak.x, 0, peak.y)})
	_check(farm.avatar.position.y == 8.0, "Saved outdoor positions resolve to the current terrain height.")
	farm.walk_velocity = Vector3.ZERO
	farm.camera_yaw = 0.0
	var saw_descent := false
	var braced_for_landing := false
	var landed_below := false
	for frame in range(240):
		var was_airborne: bool = farm.step_elapsed < farm.step_duration
		var distance: float = farm._advance_walk(Vector2i.DOWN, 1.0 / 60.0)
		farm._animate_walk(distance, 1.0 / 60.0)
		var airborne: bool = farm.step_elapsed < farm.step_duration
		if airborne and farm.avatar.position.y < farm.step_start.y and farm.avatar.position.y > farm.step_end.y:
			saw_descent = true
			braced_for_landing = braced_for_landing or farm.arms[1].rotation.z > 0.1
		if was_airborne and not airborne:
			landed_below = farm.step_end.y < farm.step_start.y and farm.avatar.position.is_equal_approx(farm.step_end)
			break
	_check(saw_descent and braced_for_landing, "Walking off a block passes through an airborne fall pose.")
	_check(landed_below and is_zero_approx(farm.arms[1].rotation.z),
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
		var target: Vector2 = farm._walk_destination(start, far_side)
		_check(target.distance_to(Vector2(far_side.x, far_side.z)) > 2.0
			and farm.layout.elevation(target) >= 2.0,
			"The outer ridge blocks crossing before the map edge.")
	var pass_start := Vector3(-26, 0, 14)
	var blocked: Vector2 = farm._walk_destination(pass_start, Vector3(-30, 0, 14))
	_check(blocked.x > -28.0, "The rockslide physically blocks the old pass.")
	farm.avatar.position = pass_start
	_key(farm, KEY_E)
	_check("rockslide" in farm.message, "Inspecting the closed pass explains the rockslide.")
	farm.avatar.position = Vector3(12.5, 0, 8.35)
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
	farm.avatar.position = farm.scenery.fishing_spots[0]
	_key(farm, KEY_E)
	farm.fishing_menu._process(3.0)
	_check(is_equal_approx(farm.fishing_menu.remaining, 1.8), "Fishing practice extends the actual reel window.")
	_key(farm, KEY_ESCAPE)
	farm._set_indoors(true)
	farm.avatar.position = farm.kitchen_point
	farm.clock.fatigue = 60.0
	_key(farm, KEY_E)
	farm.cooking_menu.meal_buttons[1].pressed.emit()
	_check(is_equal_approx(farm.clock.fatigue, 11.0), "Cooking practice boosts meal recovery.")
	_key(farm, KEY_J)
	farm._open_collection()
	var coins: int = farm.coins
	for button: Button in farm.donation_buttons:
		button.pressed.emit()
	farm.donation_buttons[2].pressed.emit()
	_check(farm.donated_specimens == farm.COMPLETE_COLLECTION and farm.coins == coins + 18
		and farm.produce.get(Catalog.APPLE, -1) == 0, "Donations use one specimen each and pay once.")
	_check(farm._save_farm() == OK, "The collection and skills can be saved.")
	farm.queue_free()
	await process_frame

	farm = FARM.instantiate()
	root.add_child(farm)
	_key(farm, KEY_J)
	farm._open_collection()
	_check(farm.donation_buttons[0].disabled and farm.skills.practice == Vector3i(9, 3, 4)
		and farm.coins == coins + 18, "Reload preserves donated specimens, coins, and skill practice.")
	farm.queue_free()
	await process_frame


func _visit_resident(farm: Node, id: String) -> void:
	if farm.active_menu != null:
		_key(farm, KEY_ESCAPE)
	farm.avatar.position = farm.village.models[farm.village.resident_indices[id]].position
	_key(farm, KEY_E)
	_check(farm.active_menu == farm.resident_menu and farm.village.residents[farm.resident_index].id == id,
		"The normal interaction opens %s's dialogue." % id)


func _choose_village(farm: Node, action: String) -> void:
	var index: int = farm.resident_actions.find(action)
	_check(index >= 0, "Village dialogue offers %s." % action)
	if index >= 0:
		farm.resident_choices[index].pressed.emit()


func _test_village_story() -> void:
	_check(Save.write({"day": 3, "hour": 17.0, "produce": {Catalog.POND_PERCH: 1},
		"village": {"favor": {"mara": 18}}}) == OK, "The village fixture saves.")
	var farm := FARM.instantiate()
	root.add_child(farm)
	_check(farm.village.residents.size() == 32 and farm.village.models.size() == 32,
		"All 32 character JSON files load into the playable valley.")
	_visit_resident(farm, "mara")
	farm.gift_stock.select(1)
	farm.gift_button.pressed.emit()
	_check(farm.village.favor.mara == 15 and farm.produce[Catalog.POND_PERCH] == 0
		and farm.resident_line.text.contains("flour"), "A disliked gift consumes the item and triggers her own reply.")
	farm.gift_button.pressed.emit()
	_check(farm.rations == 2, "A second gift on the same day cannot be given.")
	_choose_village(farm, "supper-families")
	_check(farm.village.supper_table.visible, "The supper sets a table in the meadow that evening.")
	_choose_village(farm, "date")
	for witness in ["tess", "vera", "orin"]:
		_visit_resident(farm, witness)
		_choose_village(farm, "witness")
	_choose_village(farm, "supper-reaction")
	_check(farm.resident_line.text.contains("place set for us"), "Orin reacts to the chosen supper dedication.")
	_visit_resident(farm, "iona")
	_check(not farm.resident_actions.has("publish"), "The hearing opens the day after collecting the accounts.")
	_key(farm, KEY_ESCAPE)
	farm._test_advance_day()
	farm._test_set_hour(11.0)
	_visit_resident(farm, "mara")
	farm.gift_stock.select(0)
	farm.gift_button.pressed.emit()
	_check(farm.village.favor.mara == 27 and farm.rations == 1
		and farm.resident_line.text.contains("scored"), "A favorite gift raises favor and triggers her bread reply.")
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
	_check(farm.village_story.text.contains(event.title), "The journal announces the daily town event.")
	_visit_resident(farm, host)
	var before: int = farm.village.affinity(farm.resident_index)
	_choose_village(farm, "town-event")
	_check(farm.resident_line.text == event.prompt and farm.resident_choices[1].visible,
		"The host opens the scene with both choices available.")
	_choose_village(farm, "town-event-second")
	_check(farm.resident_line.text == event.choices[1].reply and farm.village.affinity(farm.resident_index) == before + 3,
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
	for item in range(farm.test_resident_picker.item_count):
		if farm.test_resident_picker.get_item_id(item) == index:
			farm.test_resident_picker.select(item)
			break
	farm._test_favor_preset(12)
	village.last_gift.mara = farm.day
	farm._test_gift_kit()
	farm._test_open_dialogue()
	_check(village.affinity(index) == 12 and farm.resident_actions.has("date") and farm.rations >= 3
		and not village.last_gift.has("mara"), "Resident Test sets exact favor, stocks gifts, and previews dialogue without visit favor.")
	farm._open_resident_tests()
	farm._test_watch_departure()
	_check(not body.visible and farm.active_menu == null and farm.avatar.position.distance_to(porch) < 4.0
		and farm.clock.hour < 6.5 and farm.clock.hour > 6.3, "Departure test waits in front of the house just before the resident leaves.")
	_check(village.location_hint("vera", 1, 15.0) == "Reedmere", "Before testimony Vera visits the new bank.")
	village.evidence = 2
	_check(village.location_hint("vera", 1, 15.0) == "west of Willow Pond", "Vera revisits the old route after giving testimony.")
	farm.clock.hour = 6.0
	farm.clock.tick(24.0, false)
	_check(is_equal_approx(farm.clock.hour, 7.0), "One game hour takes 24 seconds at the slower clock rate.")
	farm._open_resident_directory()
	_check(farm.directory_select.item_count == 32 and not farm.directory_text.text.is_empty(),
		"The journal directory offers a schedule hint for every resident.")
	for player: AudioStreamPlayer in farm.sound.players.values():
		player.stop()
	await create_timer(0.15).timeout
	farm.queue_free()
	await process_frame
