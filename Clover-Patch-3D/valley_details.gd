extends Node3D

const Meshes := preload("res://farm_mesh.gd")
const COLORS := ["#f3c873", "#e58e82", "#8bc5b6", "#b9a2d8"]

var origin := Vector3.ZERO
var radius := Vector2.ONE
var flight := false
var elapsed := 0.0
var wings: Array[MeshInstance3D] = []
## Ducks swim to `lure` while `lure_time` runs (someone is feeding them), then drift back to their circuit.
var lure := Vector3.ZERO
var lure_time := 0.0


static func picnic(parent: Node3D, at: Vector3) -> Rect2:
	var table := Node3D.new()
	parent.add_child(table)
	table.position = at
	Meshes.box(table, Vector3(0, 0.63, 0), Vector3(1.9, 0.12, 0.86), "#bb8055")
	for x in [-0.65, 0.65]:
		Meshes.box(table, Vector3(x, 0.29, 0), Vector3(0.13, 0.58, 0.75), "#8b5e47")
	for z in [-0.69, 0.69]:
		Meshes.box(table, Vector3(0, 0.32, z), Vector3(1.9, 0.1, 0.31), "#d19a64")
		for x in [-0.65, 0.65]:
			Meshes.box(table, Vector3(x, 0.14, z), Vector3(0.12, 0.28, 0.20), "#8b5e47")
	Meshes.box(table, Vector3(0.29, 0.704, 0), Vector3(0.60, 0.024, 0.76), "#ebaa9f")
	Meshes.box(table, Vector3(0.29, 0.82, 0), Vector3(0.13, 0.22, 0.13), "#80b9ab")
	Meshes.box(table, Vector3(0.29, 1.0, 0), Vector3(0.18, 0.12, 0.18), "#efd37d")
	return Rect2(Vector2(at.x - 0.95, at.z - 0.85), Vector2(1.9, 1.7))


static func bunting(parent: Node3D, at: Vector3) -> void:
	for side in [-1, 1]:
		Meshes.box(parent, at + Vector3(side * 1.8, 1.28, 0), Vector3(0.12, 2.56, 0.12), "#946744")
	for index in range(9):
		var offset := (index - 4) * 0.39
		var sag := 2.24 + absf(offset) * 0.14
		Meshes.box(parent, at + Vector3(offset, sag, 0), Vector3(0.40, 0.037, 0.04), "#b9956f")
		var pennant := Meshes.box(parent, at + Vector3(offset, sag - 0.11, 0),
			Vector3(0.17, 0.19, 0.055), COLORS[index % COLORS.size()])
		pennant.rotation.z = 0.18 if index % 2 == 0 else -0.18


static func closed_pass(parent: Node3D, at: Vector3) -> Rect2:
	for index in range(7):
		var z := (index - 3) * 0.66
		var height := 0.9 + float(index * 7 % 5) * 0.23
		var rock := Meshes.box(parent, at + Vector3(0, height * 0.5, z),
			Vector3(1.25, height, 0.95), "#837b72" if index % 2 == 0 else "#a39a8b")
		rock.rotation.y = (index - 3) * 0.18
	for z in [-2.25, 2.25]:
		Meshes.box(parent, at + Vector3(0.85, 0.55, z), Vector3(0.15, 1.1, 0.16), "#775544")
	Meshes.box(parent, at + Vector3(0.85, 0.67, 0), Vector3(0.13, 0.12, 4.6), "#b58151")
	return Rect2(Vector2(at.x - 0.8, at.z - 2.45), Vector2(1.8, 4.9))


func attract(target: Vector3, seconds: float) -> void:
	lure = target
	lure_time = seconds


func populate(at: Vector3, roaming_radius: Vector2, is_butterfly: bool, phase: float) -> void:
	radius = roaming_radius
	flight = is_butterfly
	elapsed = phase
	origin = at
	if flight:
		Meshes.box(self, Vector3.ZERO, Vector3(0.065, 0.07, 0.21), "#574651")
		for side in [-1, 1]:
			wings.append(Meshes.box(self, Vector3(side * 0.13, 0, 0), Vector3(0.24, 0.055, 0.28),
				COLORS[int(phase) % COLORS.size()]))
	else:
		Meshes.box(self, Vector3(0, 0.1, 0), Vector3(0.30, 0.22, 0.42), "#fff1cf")
		Meshes.box(self, Vector3(0, 0.24, 0.14), Vector3(0.21, 0.23, 0.23), "#fff7de")
		Meshes.box(self, Vector3(0, 0.20, 0.28), Vector3(0.15, 0.068, 0.12), "#e7a24d")
		for side in [-1, 1]:
			Meshes.box(self, Vector3(side * 0.107, 0.27, 0.18), Vector3(0.03, 0.04, 0.04), "#44372e")
	advance(0.0)


func advance(delta: float) -> void:
	elapsed += delta
	var angle := elapsed * (0.9 if flight else 0.38)
	var circuit := origin + Vector3(cos(angle) * radius.x, sin(elapsed * 2.1) * (0.28 if flight else 0.025),
		sin(angle) * radius.y)
	if flight or delta <= 0.0:
		position = circuit
		rotation.y = atan2(-sin(angle) * radius.x, cos(angle) * radius.y)
	else:
		lure_time = maxf(0.0, lure_time - delta)
		var goal := Vector3(lure.x, circuit.y, lure.z) if lure_time > 0.0 else circuit
		var step := position.move_toward(goal, delta * (1.7 if lure_time > 0.0 else 2.4))
		var heading := (step - position) * Vector3(1, 0, 1)
		if heading.length_squared() > 0.000004:
			rotation.y = lerp_angle(rotation.y, atan2(heading.x, heading.z), minf(1.0, delta * 8.0))
		position = Vector3(step.x, circuit.y + (absf(sin(elapsed * 9.0)) * 0.05 if lure_time > 0.0 else 0.0), step.z)
	for index in range(wings.size()):
		wings[index].rotation.z = sin(elapsed * 18.0) * (0.8 if index == 0 else -0.8)
