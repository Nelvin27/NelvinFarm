extends RefCounted


static func box(parent: Node3D, at: Vector3, dimensions: Vector3, color: String, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _place_mesh(parent, at, mesh, color, glow)


static func tile(parent: Node3D, at: Vector3, dimensions: Vector3, texture: Texture2D,
		tint := "#ffffff") -> MeshInstance3D:
	var instance := box(parent, at, dimensions, tint)
	var material := instance.material_override as StandardMaterial3D
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	return instance


static func _place_mesh(parent: Node3D, at: Vector3, mesh: Mesh, color: String, glow: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(color)
	surface.roughness = 0.85
	if glow:
		surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.mesh = mesh
	instance.material_override = surface
	instance.position = at
	parent.add_child(instance)
	return instance
