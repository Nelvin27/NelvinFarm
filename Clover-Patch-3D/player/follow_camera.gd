extends Camera3D
## Over-the-shoulder orbit camera that trails the farmer and stays above block terrain.

const WorldLayout := preload("res://world_layout.gd")

const DISTANCE := 4.3
const MIN_DISTANCE := 2.8
const MAX_DISTANCE := 8.0
const SENSITIVITY := 0.003
const MIN_PITCH := deg_to_rad(22.0)
const MAX_PITCH := deg_to_rad(65.0)

var yaw := -PI / 2.0
var pitch := deg_to_rad(35.0)
var ground_y := 0.0
var distance := DISTANCE


## Moves the camera one notch closer (-1) or farther (1).
func zoom(step: int) -> void:
	distance = clampf(distance + step * 0.6, MIN_DISTANCE, MAX_DISTANCE)


func look(relative: Vector2, sensitivity_scale: float, invert_y: bool) -> void:
	var sensitivity := SENSITIVITY * sensitivity_scale
	var vertical := -relative.y if invert_y else relative.y
	yaw = wrapf(yaw - relative.x * sensitivity, -PI, PI)
	pitch = clampf(pitch + vertical * sensitivity, MIN_PITCH, MAX_PITCH)


## Places the camera behind `target`. Pass `terrain` outdoors so the lens never clips into a hill;
## a zero delta snaps instead of easing.
func follow(target: Vector3, terrain: WorldLayout = null, delta := 0.0) -> void:
	var back := Vector3.BACK.rotated(Vector3.UP, yaw)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	ground_y = move_toward(ground_y, target.y, 12.0 * delta) if delta > 0.0 else target.y
	var shoulder := Vector3(target.x, ground_y + 0.9, target.z) + right * 0.65
	var offset := (back * cos(pitch) + Vector3.UP * sin(pitch)) * distance
	position = shoulder + offset
	if terrain != null:
		position.y = maxf(position.y, terrain.elevation(Vector2(position.x, position.z)) + 0.25)
	look_at(shoulder - back * 0.6)
