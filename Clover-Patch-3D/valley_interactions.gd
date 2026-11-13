extends Node
## Things in the valley the farmer can touch: signs to read, trees to shake, ducks to feed, the wishing
## well, the town bell, buried finds, bushes that rustle as you pass, and landmarks to discover.
## The farm asks `nearby()` what is in reach and calls `use()` on E; daily state resets in `new_day()`.

enum Kind { SIGN, TREE, DUCKS, WELL, BELL, DIG }

const Catalog := preload("res://crop_catalog.gd")
const FarmAudio := preload("res://farm_audio.gd")
const InventoryGrid := preload("res://inventory_grid.gd")
const Weather := preload("res://valley_weather.gd")
const Skills := preload("res://valley_skills.gd")
const Scenery := preload("res://farm_scenery.gd")

const TREE_REACH := 1.15
const SIGN_REACH := 1.2
const DIG_REACH := 1.0
const WELL_REACH := 1.75
const BELL_REACH := 1.6
const DUCK_REACH := 1.25
const DIGS_PER_DAY := 4
const HOE := 1
const DISCOVERY_COINS := 2
const EXPLORER_REWARD := 25
## Moonfin chance while the ducks or the well have blessed today's fishing.
const LUCKY_MOONFIN := 0.35

var farm: Node
var scenery: Scenery
var shaken: Dictionary[int, bool] = {}
var dug: Dictionary[Vector3, bool] = {}
var discovered: Dictionary[String, bool] = {}
var ducks_fed := false
var wished := false
var luck := false

var _tree_grid: Dictionary[Vector2i, PackedInt32Array] = {}
var _bush_grid: Dictionary[Vector2i, PackedInt32Array] = {}
var _active_digs: Dictionary[int, bool] = {}
var _wobbles: Array[Dictionary] = []
var _rustle_cooldown := 0.0
var _cached_at := Vector3.INF
var _cached_holding := Vector3i.ZERO
var _cached: Dictionary = {}


func setup(owner_farm: Node) -> void:
	farm = owner_farm
	scenery = farm.scenery
	_tree_grid = _grid(scenery.tree_spots, 3.0)
	_bush_grid = _grid(scenery.bush_spots, 2.0)
	show_day(farm.day)


## What the farmer can use from `at`, or an empty dictionary. Keys: kind, index, prompt, and
## optionally blocked (a hint shown in place of the prompt when something is missing).
func nearby(at: Vector3) -> Dictionary:
	# What is usable also depends on the tool in hand and on having a coin or bread.
	var holding := Vector3i(farm.equipped_tool, mini(farm.coins, 1), mini(farm.rations, 1))
	if at == _cached_at and holding == _cached_holding:
		return _cached
	_cached_at = at
	_cached_holding = holding
	_cached = _find(at)
	return _cached


func _find(at: Vector3) -> Dictionary:
	if scenery.well.is_finite() and at.distance_to(scenery.well) <= WELL_REACH:
		if wished:
			return {"kind": Kind.WELL, "prompt": "Wishing well · one wish a day"}
		if farm.coins < 1:
			return {"kind": Kind.WELL, "prompt": "", "blocked": "Wishing well · bring a coin to toss"}
		return {"kind": Kind.WELL, "prompt": "Toss a coin in the well · 1 coin"}
	if scenery.bell.is_finite() and at.distance_to(scenery.bell) <= BELL_REACH:
		return {"kind": Kind.BELL, "prompt": "Ring the town bell"}
	for index in _active_digs:
		var spot: Dictionary = scenery.dig_spots[index]
		if not dug.has(spot.at) and at.distance_to(farm.layout.grounded(spot.at)) <= DIG_REACH:
			return {"kind": Kind.DIG, "index": index, "prompt": "Dig up the find"}
	for index in range(scenery.signs.size()):
		var sign: Dictionary = scenery.signs[index]
		if not sign.text.is_empty() and at.distance_to(sign.at) <= SIGN_REACH:
			var board: bool = sign.text.begins_with("@")
			return {"kind": Kind.SIGN, "index": index, "prompt": "Read the petition board" if board else "Read the sign"}
	var pond := _pond_near(at)
	if pond >= 0:
		if farm.rations < 1:
			return {"kind": Kind.DUCKS, "index": pond, "prompt": "", "blocked": "Ducks  ·  bring bread to feed them"}
		return {"kind": Kind.DUCKS, "index": pond, "prompt": "Feed the ducks · 1 bread"}
	var tree := _nearest(_tree_grid, scenery.tree_spots, at, 3.0, TREE_REACH)
	if tree >= 0:
		return {"kind": Kind.TREE, "index": tree, "prompt": "Shake the tree"}
	return {}


## Shaking and digging are physical work, so exhaustion blocks them.
func tiring(target: Dictionary) -> bool:
	return target.get("kind") in [Kind.TREE, Kind.DIG]


func use(target: Dictionary) -> void:
	if target.is_empty() or not str(target.get("blocked", "")).is_empty():
		return
	match target.kind:
		Kind.SIGN:
			var text: String = scenery.signs[target.index].text
			farm.message = rumor() if text.begins_with("@") else text
		Kind.TREE:
			_shake_tree(target.index)
		Kind.DUCKS:
			_feed_ducks(target.index)
		Kind.WELL:
			_make_wish()
		Kind.BELL:
			_ring_bell()
		Kind.DIG:
			_dig(target.index)
	_cached_at = Vector3.INF


## Per-frame: animates rustling plants, rustles bushes the farmer brushes past, and notices landmarks.
func update(delta: float, at: Vector3, moved: float) -> void:
	_rustle_cooldown = maxf(0.0, _rustle_cooldown - delta)
	if moved > 0.0:
		var bush := _nearest(_bush_grid, scenery.bush_spots, at, 2.0, 0.62)
		if bush >= 0 and not _is_wobbling(scenery._bushes, bush):
			_wobble(scenery._bushes, bush, 0.2, 0.55)
			if _rustle_cooldown == 0.0:
				farm.sound.play_effect(FarmAudio.Effect.RUSTLE, randf_range(1.25, 1.5))
				_rustle_cooldown = 0.45
	for index in range(_wobbles.size() - 1, -1, -1):
		var wobble: Dictionary = _wobbles[index]
		wobble.time += delta
		var progress: float = wobble.time / wobble.duration
		if progress >= 1.0:
			wobble.batch.tilt(wobble.instance, 0.0, 0.0)
			_wobbles.remove_at(index)
			continue
		var swing: float = sin(wobble.time * 21.0) * wobble.strength * (1.0 - progress)
		wobble.batch.tilt(wobble.instance, swing * cos(wobble.heading), swing * sin(wobble.heading))
	for landmark: Dictionary in scenery.landmarks:
		if discovered.has(landmark.name):
			continue
		var gap: Vector3 = landmark.at - at
		if Vector2(gap.x, gap.z).length() <= landmark.radius and absf(gap.y) < 2.5:
			_discover(landmark.name)


func new_day(day: int) -> void:
	shaken.clear()
	dug.clear()
	ducks_fed = false
	wished = false
	luck = false
	show_day(day)


## Picks today's buried finds and shows their sparkles. The choice depends only on the day.
func show_day(day: int) -> void:
	_cached_at = Vector3.INF
	_active_digs.clear()
	var order: Array = range(scenery.dig_spots.size())
	var random := RandomNumberGenerator.new()
	random.seed = day * 7919 + 13
	for index in range(order.size() - 1, 0, -1):
		var swap := random.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[swap]
		order[swap] = held
	for index: int in order.slice(0, DIGS_PER_DAY):
		_active_digs[index] = true
	for index in range(scenery.dig_spots.size()):
		var spot: Dictionary = scenery.dig_spots[index]
		spot.sparkle.visible = _active_digs.has(index) and not dug.has(spot.at)


func active_digs() -> Array:
	return _active_digs.keys()


func discovered_count() -> int:
	var count := 0
	for landmark: Dictionary in scenery.landmarks:
		count += int(discovered.has(landmark.name))
	return count


## The petition boards' daily notice: tomorrow's weather, a digging rumor, and a fishing tip.
func rumor() -> String:
	var lines := PackedStringArray(["Tomorrow's sky: %s." % Weather.NAMES[Weather.forecast(farm.day + 1)]])
	for index in _active_digs:
		var spot: Dictionary = scenery.dig_spots[index]
		if not dug.has(spot.at):
			lines.append("Someone saw a glint in the ground near %s." % _landmark_near(spot.at))
			break
	lines.append("Old hands say the Moonfin rises at dusk, in the rain, and for those the ducks trust.")
	return "Petition board  ·  " + " ".join(lines)


func state() -> Dictionary:
	return {"shaken": shaken.keys(), "dug": dug.keys(), "discovered": discovered.keys(),
		"fed": ducks_fed, "wished": wished, "luck": luck}


func restore(saved: Variant) -> void:
	if not saved is Dictionary:
		return
	var trees: Variant = saved.get("shaken")
	if trees is Array:
		for index: Variant in trees:
			if index is int and index >= 0 and index < scenery.tree_spots.size():
				shaken[index] = true
	var holes: Variant = saved.get("dug")
	if holes is Array:
		for at: Variant in holes:
			if at is Vector3:
				dug[at] = true
	var places: Variant = saved.get("discovered")
	if places is Array:
		for place: Variant in places:
			if place is String:
				discovered[place] = true
	ducks_fed = saved.get("fed") == true
	wished = saved.get("wished") == true
	luck = saved.get("luck") == true


func _shake_tree(index: int) -> void:
	var at: Vector3 = scenery.tree_spots[index]
	_wobble(scenery._trees, index, 0.16, 0.9)
	farm.sound.play_effect(FarmAudio.Effect.RUSTLE, randf_range(0.85, 1.05))
	var leaves: Array = Scenery.SEASON_LEAVES[farm.season]
	farm._burst(at + Vector3.UP * 1.3, Color(leaves[1]))
	if shaken.has(index):
		farm.message = "Only a few leaves drift down. This tree has been shaken today."
		return
	shaken[index] = true
	farm.clock.do_farm_work(2.0)
	var roll := randf()
	var find := -1
	if roll < 0.22:
		match farm.season:
			Catalog.Season.SPRING, Catalog.Season.SUMMER:
				find = Catalog.WILD_BERRIES
			Catalog.Season.FALL:
				find = Catalog.CHANTERELLE
	elif roll < 0.27 and farm.season == Catalog.Season.FALL:
		find = Catalog.APPLE
	if find >= 0 and farm._bag_has_room(InventoryGrid.Kind.HARVEST, find):
		farm.produce[find] = farm.produce.get(find, 0) + 1
		farm._animate_pickup(at + Vector3.UP * 1.2, find)
		farm.message = "%s tumbled out of the branches." % Catalog.crops[find].label
	elif find < 0 and roll < 0.36:
		var coins := randi_range(1, 3)
		farm.coins += coins
		farm.sound.play_effect(FarmAudio.Effect.TRADE, 1.3)
		farm.message = "%d coin(s) fell from an old magpie nest." % coins
	elif find < 0:
		farm.message = "Leaves shower down around you."


func _feed_ducks(pond: int) -> void:
	farm.rations -= 1
	var area: Rect2 = scenery.ponds[pond].area
	var inner := area.grow(-0.55)
	var at := Vector2(farm.player.position.x, farm.player.position.z)
	var shore := Vector3(clampf(at.x, inner.position.x, inner.end.x), 0, clampf(at.y, inner.position.y, inner.end.y))
	var ducks: Array = scenery.ponds[pond].ducks
	for index in range(ducks.size()):
		ducks[index].attract(shore + Vector3(index * 0.5 - 0.25, 0, 0), 7.0)
	farm.sound.play_effect(FarmAudio.Effect.QUACK, randf_range(0.95, 1.1))
	farm.sound.play_effect(FarmAudio.Effect.SPLASH, 1.2)
	farm._burst(shore + Vector3.UP * 0.1, Color("#d9f1ec"))
	if ducks_fed:
		farm.message = "The ducks paddle over and finish every crumb."
	else:
		ducks_fed = true
		luck = true
		farm.message = "The ducks crowd in for the bread. You feel lucky about today's fishing."


func _make_wish() -> void:
	if wished:
		farm.message = "The well has already heard your wish today."
		return
	if farm.coins < 1:
		return
	farm.coins -= 1
	wished = true
	farm.sound.play_effect(FarmAudio.Effect.SPLASH, 0.9)
	farm._burst(scenery.well + Vector3.UP * 0.5, Color("#bfe6ee"))
	var hint := ""
	for index in _active_digs:
		if not dug.has(scenery.dig_spots[index].at):
			hint = _landmark_near(scenery.dig_spots[index].at)
			break
	var roll := randf()
	if roll < 0.25:
		farm.coins += 4
		farm.message = "Your coin sinks, and something glints back. You fish out 4 coins."
	elif roll < 0.5:
		luck = true
		farm.message = "The water ripples moon-silver. The fish will favor you today."
	elif roll < 0.75 and not hint.is_empty():
		farm.message = "The ripples drift toward %s. Something is buried there." % hint
	else:
		farm.clock.fatigue = maxf(0.0, farm.clock.fatigue - 18.0)
		farm.message = "A calm settles over you as the coin sinks. Your fatigue eases."


func _ring_bell() -> void:
	farm.sound.play_effect(FarmAudio.Effect.BELL)
	var swing := create_tween().set_trans(Tween.TRANS_SINE)
	for angle: float in [0.5, -0.4, 0.28, -0.16, 0.0]:
		swing.tween_property(scenery.bell_body, "rotation:z", angle, 0.22)
	farm.message = "The bell rings out across Clover Valley. It is %s." % farm.clock.clock_text()


func _dig(index: int) -> void:
	var spot: Dictionary = scenery.dig_spots[index]
	var at: Vector3 = farm.layout.grounded(spot.at)
	farm._auto_equip(HOE)
	dug[spot.at] = true
	spot.sparkle.hide()
	farm.sound.play_effect(FarmAudio.Effect.TILL, randf_range(0.9, 1.05))
	farm._burst(at + Vector3.UP * 0.2, Color("#ae7956"))
	farm.player.swing_tool(-1.65)
	farm.clock.do_farm_work(4.0)
	var roll := randf()
	if roll < 0.25 and farm._bag_has_room(InventoryGrid.Kind.HARVEST, Catalog.RIVER_SHELL):
		farm.produce[Catalog.RIVER_SHELL] = farm.produce.get(Catalog.RIVER_SHELL, 0) + 1
		farm._animate_pickup(at, Catalog.RIVER_SHELL)
		farm.message = "You dug up an old River Shell, far from any water."
	elif roll < 0.4 and _dig_seeds(at):
		pass
	elif roll < 0.5:
		farm.coins += 15
		farm.sound.play_effect(FarmAudio.Effect.TRADE)
		farm.message = "A lost coin purse! 15 coins, from before the flood by the look of it."
	else:
		var coins := randi_range(3, 8)
		farm.coins += coins
		farm.sound.play_effect(FarmAudio.Effect.TRADE, 1.15)
		farm.message = "You dug up %d coins." % coins
	farm._train_skill(Skills.Skill.FARMING)


func _dig_seeds(at: Vector3) -> bool:
	var choices: Array[int] = []
	for id in range(Catalog.SEED_COUNT):
		if Catalog.crops[id].grows_in(farm.season) and id != Catalog.GRASS:
			choices.append(id)
	if choices.is_empty():
		return false
	var id: int = choices.pick_random()
	if not farm._bag_has_room(InventoryGrid.Kind.SEED, id):
		return false
	farm.seed_bag[id] = farm.seed_bag.get(id, 0) + 2
	farm._animate_pickup(at, id)
	farm.message = "A sealed tin of %s seeds! 2 added to your bag." % Catalog.crops[id].label
	return true


func _discover(place: String) -> void:
	discovered[place] = true
	farm.coins += DISCOVERY_COINS
	farm.sound.play_effect(FarmAudio.Effect.CHIME)
	var total := scenery.landmarks.size()
	farm.message = "Discovered %s!  ·  %d of %d places found  ·  +%d coins" % [
		place, discovered_count(), total, DISCOVERY_COINS]
	if discovered_count() == total:
		farm.coins += EXPLORER_REWARD
		farm.message += "  ·  You've walked the whole valley! +%d coins" % EXPLORER_REWARD
	farm._refresh()


func _landmark_near(at: Vector3) -> String:
	var best := "the valley floor"
	var closest := INF
	for landmark: Dictionary in scenery.landmarks:
		var distance: float = Vector2(landmark.at.x - at.x, landmark.at.z - at.z).length()
		if distance < closest:
			closest = distance
			best = landmark.name
	return best


func _pond_near(at: Vector3) -> int:
	if absf(at.y) > 0.5:
		return -1
	var point := Vector2(at.x, at.z)
	for index in range(scenery.ponds.size()):
		var area: Rect2 = scenery.ponds[index].area
		if area.grow(DUCK_REACH).has_point(point) and not area.has_point(point):
			return index
	return -1


func _wobble(batch: RefCounted, instance: int, strength: float, duration: float) -> void:
	_wobbles.append({"batch": batch, "instance": instance, "strength": strength, "duration": duration,
		"time": 0.0, "heading": randf() * TAU})


func _is_wobbling(batch: RefCounted, instance: int) -> bool:
	for wobble: Dictionary in _wobbles:
		if wobble.batch == batch and wobble.instance == instance:
			return true
	return false


static func _grid(spots: Array[Vector3], cell: float) -> Dictionary[Vector2i, PackedInt32Array]:
	var grid: Dictionary[Vector2i, PackedInt32Array] = {}
	for index in range(spots.size()):
		var key := Vector2i(floori(spots[index].x / cell), floori(spots[index].z / cell))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		grid[key].append(index)
	return grid


static func _nearest(grid: Dictionary[Vector2i, PackedInt32Array], spots: Array[Vector3], at: Vector3,
		cell: float, reach: float) -> int:
	var home := Vector2i(floori(at.x / cell), floori(at.z / cell))
	var best := -1
	var closest := reach
	for x in range(-1, 2):
		for z in range(-1, 2):
			for index: int in grid.get(home + Vector2i(x, z), PackedInt32Array()):
				var spot := spots[index]
				var distance := Vector2(spot.x - at.x, spot.z - at.z).length()
				if distance < closest and absf(spot.y - at.y) < 0.6:
					closest = distance
					best = index
	return best
