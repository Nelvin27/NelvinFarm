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
	if FileAccess.file_exists(Save.path):
		DirAccess.remove_absolute(Save.path)
	await process_frame
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
	if code in [KEY_I, KEY_J, KEY_ESCAPE]:
		farm._input(event)
	else:
		farm._unhandled_key_input(event)


func _test() -> bool:
	var farm := FARM.instantiate()
	root.add_child(farm)
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
	_key(farm, KEY_J)

	_key(farm, KEY_I)
	var bag: Bag = farm.inventory_grid
	var first := bag.stacks[0]
	bag._drop_on_slot(Vector2.ZERO, {"bag": bag, "source": 0, "stack": first}, 11)
	_key(farm, KEY_I)

	farm.avatar.position = farm.scenery.repair_sign
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
