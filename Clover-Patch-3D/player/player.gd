extends Node3D
## The farmer: grid-aware walking, block-terrain hops, and the procedural walk/work animation.
## The body is authored in player.tscn; this script only moves and poses its pivots.

signal landed(at: Vector3, dropping: bool)

const WorldLayout := preload("res://world_layout.gd")

const EDGE_MARGIN := 0.3
const WALK_SPEED := 3.8
const WALK_ACCELERATION := 26.0
const WALK_BRAKING := 34.0
const STEP_HOP_DURATION := 0.28
const STEP_HOP_CLEARANCE := 0.24
const STEP_OFF_PHASE := 0.26
const FALL_GRAVITY := 24.0
const STRIDE_LENGTH := 0.85
## Walkable floor of the cottage interior, relative to the interior's origin.
const ROOM_BOUNDS := Rect2(-3.05, -2.52, 6.1, 5.1)
const ROOM_OBSTACLES: Array[Rect2] = [
	Rect2(-2.25, -2.33, 1.2, 1.8),
	Rect2(1.03, -1.185, 1.24, 0.85),
	Rect2(2.05, -2.42, 0.72, 0.7),
	Rect2(-0.895, -2.30, 0.53, 0.56),
]

var layout: WorldLayout
var outdoor_obstacles: Array[Rect2] = []
var room_origin := Vector3.ZERO
var indoors := false

var walk_velocity := Vector3.ZERO
var step_elapsed := STEP_HOP_DURATION
var step_duration := STEP_HOP_DURATION
var step_start := Vector3.ZERO
var step_end := Vector3.ZERO
var step_edge := Vector3.ZERO
var facing_angle := PI / 2.0
var walk_phase := 0.0
var idle_phase := 0.0
var walk_weight := 0.0
var work_pose := 0.0
var work_tween: Tween

@onready var model: Node3D = $Model
@onready var legs: Array[Node3D] = [$Model/LeftLeg, $Model/RightLeg]
@onready var arms: Array[Node3D] = [$Model/LeftArm, $Model/RightArm]
## Keyed by the farm's Tool enum value (HOE = 1, WATERING_CAN = 2, SICKLE = 3).
@onready var held_tools: Dictionary[int, Node3D] = {
	1: $Model/RightArm/Hoe, 2: $Model/RightArm/WateringCan, 3: $Model/RightArm/Sickle,
}


func setup(world: WorldLayout, obstacles: Array[Rect2], interior_origin: Vector3) -> void:
	layout = world
	outdoor_obstacles = obstacles
	room_origin = interior_origin


func is_stepping() -> bool:
	return step_elapsed < step_duration


func halt() -> void:
	walk_velocity = Vector3.ZERO


func finish_step() -> void:
	step_elapsed = step_duration


func face(angle: float) -> void:
	facing_angle = angle
	rotation.y = angle


func show_tool(tool: int) -> void:
	for id in held_tools:
		held_tools[id].visible = id == tool


## Moves one frame toward `direction` (screen-relative, rotated by the camera yaw).
## Returns the horizontal distance travelled so callers can drive footsteps and the clock.
func walk(direction: Vector2i, camera_yaw: float, speed: float, delta: float) -> float:
	if is_stepping():
		return _advance_terrain_step(delta)

	var desired := Vector3(direction.x, 0, direction.y).normalized().rotated(Vector3.UP, camera_yaw)
	var acceleration := WALK_BRAKING if direction == Vector2i.ZERO else WALK_ACCELERATION
	walk_velocity = walk_velocity.move_toward(desired * speed, acceleration * delta)
	if direction != Vector2i.ZERO:
		facing_angle = atan2(desired.x, desired.z)

	var start := position
	var destination := start + walk_velocity * delta
	var next := walk_destination(start, destination)
	var landing := Vector3(next.x, 0, next.y)
	if not indoors:
		landing = layout.grounded(landing)
		var floor_height := layout.elevation(Vector2(start.x, start.z))
		if landing.y != floor_height:
			var forward := (landing - start) * Vector3(1, 0, 1)
			var farther := walk_destination(start, landing + forward.normalized() * 0.26)
			step_edge = Vector3(landing.x, start.y, landing.z)
			if layout.elevation(farther) == landing.y:
				landing.x = farther.x
				landing.z = farther.y
			step_start = start
			step_end = landing
			var drop := floor_height - landing.y
			step_duration = STEP_HOP_DURATION
			if drop > 0.0:
				step_duration = clampf(sqrt(2.0 * drop / FALL_GRAVITY) / (1.0 - STEP_OFF_PHASE), 0.30, 0.8)
			step_elapsed = 0.0
			return _advance_terrain_step(delta)
	position = landing
	if not is_equal_approx(destination.x, landing.x):
		walk_velocity.x = 0.0
	if not is_equal_approx(destination.z, landing.z):
		walk_velocity.z = 0.0
	return Vector2(start.x, start.z).distance_to(next)


## Clamps a desired move to the playable area and slides it along obstacles.
func walk_destination(start: Vector3, destination: Vector3) -> Vector2:
	var room_offset := Vector2(room_origin.x, room_origin.z) if indoors else Vector2.ZERO
	var playable := (ROOM_BOUNDS if indoors else layout.bounds).grow(-EDGE_MARGIN)
	var next := (Vector2(destination.x, destination.z) - room_offset).clamp(playable.position, playable.end)
	var origin := Vector2(start.x, start.z) - room_offset
	for obstacle: Rect2 in (ROOM_OBSTACLES if indoors else outdoor_obstacles):
		next = _avoid_obstacle(obstacle, origin, next)
	return next + room_offset


## True when a saved position lies on open, walkable floor in the current area.
func can_stand_at(at: Vector3) -> bool:
	var room_offset := Vector2(room_origin.x, room_origin.z) if indoors else Vector2.ZERO
	var point := Vector2(at.x, at.z) - room_offset
	var playable := (ROOM_BOUNDS if indoors else layout.bounds).grow(-EDGE_MARGIN)
	if not playable.grow(0.001).has_point(point):
		return false
	for obstacle: Rect2 in (ROOM_OBSTACLES if indoors else outdoor_obstacles):
		if obstacle.grow(EDGE_MARGIN - 0.001).has_point(point):
			return false
	return true


func _advance_terrain_step(delta: float) -> float:
	var previous := position
	step_elapsed = minf(step_elapsed + delta, step_duration)
	var progress := step_elapsed / step_duration
	var dropping := step_end.y < step_start.y
	if dropping:
		# Step past the edge at ground height, then accelerate down to the lower tile.
		if progress <= STEP_OFF_PHASE:
			position = step_start.lerp(step_edge, progress / STEP_OFF_PHASE)
		else:
			var fall := (progress - STEP_OFF_PHASE) / (1.0 - STEP_OFF_PHASE)
			position = step_edge.lerp(step_end, fall)
			position.y = lerpf(step_edge.y, step_end.y, fall * fall)
	else:
		var peak := step_end.y + STEP_HOP_CLEARANCE
		# Clear the ledge before moving across its face.
		position = step_start.lerp(step_end, smoothstep(0.45, 1.0, progress))
		if progress < 0.45:
			var rise := progress / 0.45
			position.y = lerpf(step_start.y, peak, 1.0 - (1.0 - rise) * (1.0 - rise))
		else:
			var fall := (progress - 0.45) / 0.55
			position.y = lerpf(peak, step_end.y, fall * fall)
	if step_elapsed >= step_duration:
		landed.emit(step_end, dropping)
	return Vector2(previous.x, previous.z).distance_to(Vector2(position.x, position.z))


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


func animate(distance: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, facing_angle, 1.0 - exp(-20.0 * delta))

	var target_weight := clampf(distance / (WALK_SPEED * delta), 0.0, 1.0) if delta > 0.0 else 0.0
	walk_weight = move_toward(walk_weight, target_weight, delta * 10.0)
	walk_phase = fposmod(walk_phase + distance * TAU / STRIDE_LENGTH, TAU)
	idle_phase = fposmod(idle_phase + delta * 3.0, TAU)
	if walk_weight == 0.0:
		walk_phase = 0.0

	var swing := sin(walk_phase) * walk_weight
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		legs[index].rotation.x = swing * side * 0.65
		arms[index].rotation.x = -swing * side * 0.46
		arms[index].rotation.z = 0.0
	arms[1].rotation.x += work_pose
	model.position.y = absf(sin(walk_phase)) * walk_weight * 0.045
	model.scale.y = 1.0 + sin(idle_phase) * 0.014 * (1.0 - walk_weight)
	model.rotation.x = work_pose * 0.12
	if is_stepping():
		var progress := step_elapsed / step_duration
		if step_end.y < step_start.y:
			var brace := sin(PI * smoothstep(STEP_OFF_PHASE, 1.0, progress))
			legs[0].rotation.x = -0.28 * brace
			legs[1].rotation.x = 0.18 * brace
			arms[0].rotation.z = -0.62 * brace
			arms[1].rotation.z = 0.62 * brace
			model.rotation.x = -0.12 * brace
		else:
			var tuck := sin(PI * progress)
			legs[0].rotation.x = -0.85 * tuck
			legs[1].rotation.x = -0.55 * tuck
			arms[0].rotation.x = -0.55 * tuck
			arms[1].rotation.x = -0.55 * tuck
			model.rotation.x = 0.16 * tuck
		model.position.y = 0.0


## Swings the held tool down to `angle` and back.
func swing_tool(angle: float) -> void:
	if work_tween != null:
		work_tween.kill()
	work_tween = create_tween().set_trans(Tween.TRANS_SINE)
	work_tween.tween_property(self, "work_pose", 0.28, 0.07)
	work_tween.tween_property(self, "work_pose", angle, 0.10)
	work_tween.tween_property(self, "work_pose", 0.0, 0.28)
