extends RefCounted

const Meshes := preload("res://farm_mesh.gd")
const GRASS := preload("res://assets/voxel/grass.png")
const SOIL := preload("res://assets/voxel/soil.png")
const PATH := preload("res://assets/voxel/path.png")
const WATER := preload("res://assets/voxel/water.png")
const WOOD := preload("res://assets/voxel/wood.png")
const ROOF := preload("res://assets/voxel/roof.png")


## Box parts shared by the per-node builders below and the batched renderer (voxel_batch.gd).
## Each part is [offset, size, color, textured]. An empty color takes the caller's tint.
const TREE_PARTS := [
	[Vector3(0, 0.56, 0), Vector3(0.26, 1.12, 0.26), "#9c886e", true],
	[Vector3(0, 1.00, 0), Vector3(0.93, 0.38, 0.88), "#54834c", false],
	[Vector3(-0.12, 1.27, 0.02), Vector3(1.11, 0.39, 0.92), "#679351", false],
	[Vector3(0.14, 1.47, -0.10), Vector3(0.72, 0.29, 0.78), "#7ea258", false],
	[Vector3(-0.10, 1.64, -0.02), Vector3(0.46, 0.20, 0.51), "#8aaa61", false],
]
## Low ground cover. Bush leaf parts (1-3) follow the tree leaf colors through the seasons.
const BUSH_PARTS := [
	[Vector3(0, 0.05, 0), Vector3(0.18, 0.1, 0.18), "#6b5242", false],
	[Vector3(0, 0.24, 0), Vector3(0.78, 0.36, 0.66), "#54834c", false],
	[Vector3(0.12, 0.43, -0.05), Vector3(0.5, 0.22, 0.46), "#679351", false],
	[Vector3(-0.2, 0.2, 0.18), Vector3(0.36, 0.26, 0.3), "#7ea258", false],
]
const ROCK_PARTS := [
	[Vector3(0, 0.13, 0), Vector3(0.62, 0.26, 0.5), "#8d877d", false],
	[Vector3(0.08, 0.3, -0.04), Vector3(0.38, 0.16, 0.32), "#a39d91", false],
	[Vector3(-0.27, 0.07, 0.2), Vector3(0.24, 0.14, 0.22), "#7a756c", false],
]
## Grass and reed blades; the caller's tint colors all three.
const TUFT_PARTS := [
	[Vector3(-0.06, 0.13, 0), Vector3(0.04, 0.26, 0.04), "", false],
	[Vector3(0.05, 0.18, 0.03), Vector3(0.04, 0.36, 0.04), "", false],
	[Vector3(0.01, 0.1, -0.06), Vector3(0.04, 0.2, 0.04), "", false],
]
const FLOWER_PARTS := [
	[Vector3(0, 0.18, 0), Vector3(0.055, 0.36, 0.055), "#62824a", false],
	[Vector3(0.073, 0.14, 0), Vector3(0.16, 0.047, 0.085), "#7e9a58", false],
	[Vector3(0, 0.37, 0), Vector3(0.28, 0.08, 0.12), "", false],
	[Vector3(0, 0.37, 0), Vector3(0.12, 0.08, 0.28), "", false],
	[Vector3(0, 0.42, 0), Vector3(0.085, 0.05, 0.085), "#e4c880", false],
]


static func tree(parent: Node3D, at: Vector3, size: float, apple: bool) -> Node3D:
	var root := _parts(parent, at, size, TREE_PARTS, "")
	if not apple:
		return null
	var fruit_cluster := Node3D.new()
	root.add_child(fruit_cluster)
	for fruit in [Vector3(-0.38, 1.25, 0.50), Vector3(0.30, 1.09, 0.43), Vector3(0.43, 1.33, -0.31)]:
		Meshes.box(fruit_cluster, fruit, Vector3(0.18, 0.19, 0.18), "#b85c50")
	return fruit_cluster


static func flower(parent: Node3D, at: Vector3, size: float, tint: String) -> void:
	_parts(parent, at, size, FLOWER_PARTS, tint)


static func _parts(parent: Node3D, at: Vector3, size: float, parts: Array, tint: String) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	for part: Array in parts:
		var color: String = tint if part[2].is_empty() else part[2]
		if part[3]:
			Meshes.tile(root, part[0], part[1], WOOD, color)
		else:
			Meshes.box(root, part[0], part[1], color)
	return root


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
