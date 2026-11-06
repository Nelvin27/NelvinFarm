extends RefCounted

const Meshes := preload("res://farm_mesh.gd")
const STYLES := ["#624b47", "#365652", "#784c42", "#4d5064"]
const PORCH_OFFSET := Vector3(0, 0, 2.0)
const INSIDE_OFFSET := Vector3(0, 0, 0.78)


static func build(parent: Node3D, at: Vector3, entity: Dictionary, doors: Dictionary = {}) -> Rect2:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	var style := clampi(int(entity.get("style", 0)), 0, STYLES.size() - 1)
	var wall: String = entity.get("color", "#bc946b")
	var trim: String = entity.get("trim", "#edcc9b")
	var roof: String = STYLES[style]
	var width := 3.35 + (style % 2) * 0.34
	var depth := 2.8
	Meshes.box(root, Vector3(0, 0.12, 0), Vector3(width + 0.10, 0.24, depth + 0.12), "#827468")
	# Build a real doorway into a shallow vestibule. The back hides the unbuilt interior.
	Meshes.box(root, Vector3(0, 1.17, -0.37), Vector3(width, 1.9, 2.06), wall)
	var side := (width - 0.8) * 0.5
	for direction in [-1, 1]:
		Meshes.box(root, Vector3(direction * (0.4 + side * 0.5), 1.17, 1.03), Vector3(side, 1.9, 0.74), wall)
	Meshes.box(root, Vector3(0, 1.86, 1.03), Vector3(0.8, 0.52, 0.74), wall)
	Meshes.box(root, Vector3(0, 0.9, 0.67), Vector3(0.8, 1.45, 0.04), "#44332d")
	for direction in [-1, 1]:
		Meshes.box(root, Vector3(direction * (0.4 + side * 0.5), 0.36, 1.41), Vector3(side, 0.12, 0.06), trim)
	for level in range(4):
		Meshes.box(root, Vector3(0, 2.14 + level * 0.22, 0), Vector3(width + 0.28 - level * 0.84, 0.24, depth + 0.38), roof)
	if style != 1:
		Meshes.box(root, Vector3(0.85, 2.55, -0.55), Vector3(0.34, 0.86, 0.4), "#755548")
		Meshes.box(root, Vector3(0.85, 2.99, -0.55), Vector3(0.41, 0.10, 0.47), "#533f3a")
	Meshes.box(root, Vector3(0, 0.11, 1.69), Vector3(1.55, 0.22, 0.71), "#a78262")
	Meshes.box(root, Vector3(0, 0.06, 2.02), Vector3(1.17, 0.12, 0.38), "#b79372")
	for x in [-0.39, 0.39]:
		Meshes.box(root, Vector3(x, 0.91, 1.42), Vector3(0.10, 1.40, 0.15), trim)
	Meshes.box(root, Vector3(0, 1.61, 1.42), Vector3(0.88, 0.13, 0.15), trim)
	var hinge := Node3D.new()
	root.add_child(hinge)
	hinge.position = Vector3(-0.345, 0.0, 1.48)
	Meshes.box(hinge, Vector3(0.345, 0.90, 0), Vector3(0.69, 1.36, 0.08), "#714e3d")
	Meshes.box(hinge, Vector3(0.58, 0.86, 0.062), Vector3(0.09, 0.09, 0.055), "#f2c277")
	var resident: String = entity.get("resident", "")
	if not resident.is_empty():
		doors[resident] = hinge
	for x in [-1.04, 1.04]:
		Meshes.box(root, Vector3(x, 1.22, 1.41), Vector3(0.7, 0.68, 0.13), trim)
		Meshes.box(root, Vector3(x, 1.24, 1.48), Vector3(0.53, 0.51, 0.07), "#f4d79e")
		Meshes.box(root, Vector3(x, 1.24, 1.53), Vector3(0.054, 0.53, 0.035), "#ab795c")
		Meshes.box(root, Vector3(x, 1.22, 1.53), Vector3(0.54, 0.052, 0.035), "#ab795c")
	if style == 1 or style == 3:
		Meshes.box(root, Vector3(0, 1.71, 1.65), Vector3(1.36, 0.14, 0.78), roof)
	match entity.get("detail", "planter"):
		"crate":
			Meshes.box(root, Vector3(-1.21, 0.20, 1.83), Vector3(0.48, 0.4, 0.48), "#b58b60")
		"bench":
			Meshes.box(root, Vector3(-1.20, 0.23, 1.85), Vector3(0.82, 0.12, 0.34), "#ac7e58")
			for x in [-1.49, -0.91]:
				Meshes.box(root, Vector3(x, 0.10, 1.85), Vector3(0.10, 0.2, 0.24), "#76523f")
		"woodpile":
			for offset in [0.0, 0.21, 0.42]:
				Meshes.box(root, Vector3(-1.49 + offset, 0.14, 1.76), Vector3(0.18, 0.27, 0.51), "#966945")
		_:
			Meshes.box(root, Vector3(-1.16, 0.16, 1.80), Vector3(0.67, 0.32, 0.39), "#926745")
			Meshes.box(root, Vector3(-1.16, 0.33, 1.80), Vector3(0.53, 0.13, 0.27), "#71834d")
			for x in [-1.30, -1.04]:
				Meshes.box(root, Vector3(x, 0.42, 1.80), Vector3(0.10, 0.10, 0.10), trim)
	return Rect2(at.x - width * 0.5, at.z - depth * 0.5, width, depth)
