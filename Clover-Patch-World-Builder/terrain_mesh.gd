extends RefCounted

const Layout := preload("res://world_layout.gd")


static func surface(parent: Node3D, layout: Layout, area: Rect2, lift: float,
		texture: Texture2D, tint: String, wall_texture: Texture2D = null) -> MeshInstance3D:
	var first := Vector2i(floori(area.position.x), floori(area.position.y + 0.5))
	var end := Vector2i(ceili(area.end.x), ceili(area.end.y + 0.5))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_walls := false
	for row in range(first.y, end.y):
		for column in range(first.x, end.x):
			var cell := Vector2(column + 0.5, row)
			var elevation := layout.elevation(cell)
			var y := elevation + lift
			var west := maxf(area.position.x, column)
			var east := minf(area.end.x, column + 1)
			var north := maxf(area.position.y, row - 0.5)
			var south := minf(area.end.y, row + 0.5)
			var nw := Vector3(west, y, north)
			var ne := Vector3(east, y, north)
			var sw := Vector3(west, y, south)
			var se := Vector3(east, y, south)
			var color := Color.WHITE
			if wall_texture != null:
				color = color.lerp(Color("#b8b6a5"), smoothstep(3.0, 7.0, elevation))
			_quad(mesh, nw, ne, sw, se, Vector3.UP, color)
			if wall_texture != null and elevation > 0.0:
				has_walls = _wall(walls, layout, area, cell, Vector2.UP, nw, ne, Vector3.FORWARD, lift) or has_walls
				has_walls = _wall(walls, layout, area, cell, Vector2.RIGHT, ne, se, Vector3.RIGHT, lift) or has_walls
				has_walls = _wall(walls, layout, area, cell, Vector2.DOWN, se, sw, Vector3.BACK, lift) or has_walls
				has_walls = _wall(walls, layout, area, cell, Vector2.LEFT, sw, nw, Vector3.LEFT, lift) or has_walls

	mesh.set_material(_material(texture, tint))
	var terrain := mesh.commit()
	if has_walls:
		walls.set_material(_material(wall_texture, "#c8beaa"))
		walls.commit(terrain)
	var instance := MeshInstance3D.new()
	instance.mesh = terrain
	parent.add_child(instance)
	return instance


static func _material(texture: Texture2D, tint: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint)
	material.albedo_texture = texture
	material.roughness = 0.85
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.vertex_color_use_as_albedo = true
	return material


static func _wall(mesh: SurfaceTool, layout: Layout, area: Rect2, cell: Vector2, offset: Vector2,
		a: Vector3, b: Vector3, normal: Vector3, lift: float) -> bool:
	var neighbor := cell + offset
	var neighbor_tile := Rect2(neighbor - Vector2(0.5, 0.5), Vector2.ONE)
	var bottom := layout.elevation(neighbor) if area.intersects(neighbor_tile) else 0.0
	bottom += lift
	if bottom >= a.y:
		return false
	_quad(mesh, b, a, Vector3(b.x, bottom, b.z), Vector3(a.x, bottom, a.z), normal, Color.WHITE)
	return true


static func _quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, color: Color) -> void:
	mesh.set_normal(normal)
	mesh.set_color(color)
	for at: Vector3 in [a, b, c, b, d, c]:
		mesh.add_vertex(at)
