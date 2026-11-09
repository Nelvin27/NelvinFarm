extends RefCounted
## Draws many copies of a voxel prop (see Voxels.TREE_PARTS / FLOWER_PARTS) with one
## MultiMeshInstance3D per box part, instead of one MeshInstance3D per box.

const Voxels := preload("res://voxel_assets.gd")

var parts: Array
var name: String
var _transforms: Array[Transform3D] = []
var _nodes: Array[MultiMeshInstance3D] = []
var _tints: Array[Color] = []


func _init(prop_parts: Array, batch_name: String) -> void:
	parts = prop_parts
	name = batch_name


func add(at: Vector3, size: float, tint := Color.WHITE, yaw := 0.0) -> void:
	_transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size), at))
	_tints.append(tint)


func count() -> int:
	return _transforms.size()


func build(parent: Node3D) -> void:
	if _transforms.is_empty():
		return
	for index in range(parts.size()):
		var part: Array = parts[index]
		var box := BoxMesh.new()
		box.size = part[1]
		box.material = _material(part[3])
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = box
		batch.instance_count = _transforms.size()
		var offset := Transform3D(Basis.IDENTITY, part[0])
		for instance in range(_transforms.size()):
			batch.set_instance_transform(instance, _transforms[instance] * offset)
			batch.set_instance_color(instance, _tints[instance] if part[2].is_empty() else Color(part[2]))
		var node := MultiMeshInstance3D.new()
		node.name = "%s%d" % [name, index]
		node.multimesh = batch
		parent.add_child(node)
		_nodes.append(node)


## Recolors one part on every copy, e.g. autumn leaves. Pass force for parts that normally take each copy's tint.
func set_part_color(part_index: int, color: Color, force := false) -> void:
	if part_index >= _nodes.size() or (parts[part_index][2].is_empty() and not force):
		return
	var batch := _nodes[part_index].multimesh
	for instance in range(batch.instance_count):
		batch.set_instance_color(instance, color)


func set_visible(visible: bool) -> void:
	for node in _nodes:
		node.visible = visible


static func _material(textured: bool) -> StandardMaterial3D:
	# Instance colors are authored as sRGB hex values, like FarmMesh's albedo colors.
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.vertex_color_is_srgb = true
	surface.roughness = 0.85
	if textured:
		surface.albedo_texture = Voxels.WOOD
		surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		surface.uv1_triplanar = true
		surface.uv1_world_triplanar = true
	return surface
