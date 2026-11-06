extends RefCounted

const Meshes := preload("res://farm_mesh.gd")
const GRASS := preload("res://assets/voxel/grass.png")
const SOIL := preload("res://assets/voxel/soil.png")
const PATH := preload("res://assets/voxel/path.png")
const WATER := preload("res://assets/voxel/water.png")
const WOOD := preload("res://assets/voxel/wood.png")
const ROOF := preload("res://assets/voxel/roof.png")


static func tree(parent: Node3D, at: Vector3, size: float, apple: bool) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	Meshes.tile(root, Vector3(0, 0.56, 0), Vector3(0.26, 1.12, 0.26), WOOD, "#9c886e")
	Meshes.box(root, Vector3(0, 1.00, 0), Vector3(0.93, 0.38, 0.88), "#54834c")
	Meshes.box(root, Vector3(-0.12, 1.27, 0.02), Vector3(1.11, 0.39, 0.92), "#679351")
	Meshes.box(root, Vector3(0.14, 1.47, -0.10), Vector3(0.72, 0.29, 0.78), "#7ea258")
	Meshes.box(root, Vector3(-0.10, 1.64, -0.02), Vector3(0.46, 0.20, 0.51), "#8aaa61")
	if not apple:
		return null
	var fruit_cluster := Node3D.new()
	root.add_child(fruit_cluster)
	for fruit in [Vector3(-0.38, 1.25, 0.50), Vector3(0.30, 1.09, 0.43), Vector3(0.43, 1.33, -0.31)]:
		Meshes.box(fruit_cluster, fruit, Vector3(0.18, 0.19, 0.18), "#b85c50")
	return fruit_cluster


static func flower(parent: Node3D, at: Vector3, size: float, tint: String) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	Meshes.box(root, Vector3(0, 0.18, 0), Vector3(0.055, 0.36, 0.055), "#62824a")
	Meshes.box(root, Vector3(0.073, 0.14, 0), Vector3(0.16, 0.047, 0.085), "#7e9a58")
	Meshes.box(root, Vector3(0, 0.37, 0), Vector3(0.28, 0.08, 0.12), tint)
	Meshes.box(root, Vector3(0, 0.37, 0), Vector3(0.12, 0.08, 0.28), tint)
	Meshes.box(root, Vector3(0, 0.42, 0), Vector3(0.085, 0.05, 0.085), "#e4c880")


static func crop(parent: Node3D, id: int, tint: String, size: float, ripe: bool) -> void:
	if not ripe:
		Meshes.box(parent, Vector3(0, 0.15, 0), Vector3(size * 0.31, size, size * 0.31), "#739656")
		Meshes.box(parent, Vector3(0, 0.16 + size * 0.31, 0), Vector3(size, size * 0.25, size * 0.48), "#86a561")
		return
	if id in [5, 6, 12, 20, 21]:
		flower(parent, Vector3(0, 0.11, 0), 1.12, tint)
		return
	if id in [4, 16, 22]:
		for index in range(3):
			Meshes.box(parent, Vector3((index - 1) * 0.13, 0.22, 0),
				Vector3(0.13, 0.20 + 0.10 * (1 - absi(index - 1)), 0.32), tint)
		return
	var dimensions := Vector3(0.35, 0.27, 0.34)
	if id in [2, 8, 11, 13, 14, 19]:
		dimensions = Vector3(0.22, 0.37, 0.24)
	elif id in [1, 10, 15]:
		dimensions = Vector3(0.43, 0.25, 0.35)
	Meshes.box(parent, Vector3(0, 0.12 + dimensions.y * 0.5, 0), dimensions, tint)
	Meshes.box(parent, Vector3(0, 0.12 + dimensions.y, 0),
		Vector3(dimensions.x * 0.64, 0.06, dimensions.z * 0.64), "#" + Color(tint).lightened(0.12).to_html())
	Meshes.box(parent, Vector3(0, 0.19 + dimensions.y, 0), Vector3(0.19, 0.09, 0.09), "#779a57")
