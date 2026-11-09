extends RefCounted

const Layout := preload("res://world_layout.gd")
const STONE_TEXTURE := preload("res://assets/voxel/path.png")
## Wall faces whose top is at or above this height are bare rock; tops at or above SNOW_LINE are snow.
const ROCK_LINE := 7.0
const SNOW_LINE := 11.0


static func surface(parent: Node3D, layout: Layout, area: Rect2, lift: float,
		texture: Texture2D, tint: String, wall_texture: Texture2D = null) -> MeshInstance3D:
	var first := Vector2i(floori(area.position.x), floori(area.position.y + 0.5))
	var end := Vector2i(ceili(area.end.x), ceili(area.end.y + 0.5))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var snow := SurfaceTool.new()
	snow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_walls := false
	var has_rock := false
	var has_snow := false
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
				# High meadows fade to a cooler alpine green.
				color = color.lerp(Color("#c9d3b4"), smoothstep(5.0, 11.0, elevation))
			if wall_texture != null and elevation >= SNOW_LINE:
				var frost := Color.WHITE.lerp(Color("#dfe7ea"), clampf((elevation - SNOW_LINE) / 3.0, 0.0, 1.0))
				_quad(snow, nw, ne, sw, se, Vector3.UP, frost)
				has_snow = true
			else:
				_quad(mesh, nw, ne, sw, se, Vector3.UP, color)
			if wall_texture != null and elevation > 0.0:
				var faces: SurfaceTool = rock if elevation >= ROCK_LINE else walls
				var shade := _rock_shade(column, row, elevation) if elevation >= ROCK_LINE else Color.WHITE
				var built := false
				built = _wall(faces, layout, area, cell, Vector2.UP, nw, ne, Vector3.FORWARD, lift, shade) or built
				built = _wall(faces, layout, area, cell, Vector2.RIGHT, ne, se, Vector3.RIGHT, lift, shade) or built
				built = _wall(faces, layout, area, cell, Vector2.DOWN, se, sw, Vector3.BACK, lift, shade) or built
				built = _wall(faces, layout, area, cell, Vector2.LEFT, sw, nw, Vector3.LEFT, lift, shade) or built
				if elevation >= ROCK_LINE:
					has_rock = has_rock or built
				else:
					has_walls = has_walls or built

	mesh.set_material(_material(texture, tint))
	var terrain := mesh.commit()
	if has_walls:
		walls.set_material(_material(wall_texture, "#c8beaa"))
		walls.commit(terrain)
	if has_rock:
		rock.set_material(_material(STONE_TEXTURE, "#b8c0c6"))
		rock.commit(terrain)
	if has_snow:
		snow.set_material(_material(texture, "#f3f6f4"))
		snow.commit(terrain)
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


## Slight per-column variation so rock faces read as strata, not a flat sheet.
static func _rock_shade(column: int, row: int, elevation: float) -> Color:
	var noise := float(absi(hash(Vector2i(column, row))) % 100) / 100.0
	var band := 0.94 if int(elevation) % 3 == 0 else 1.0
	return Color.WHITE.darkened(noise * 0.12) * band


static func _wall(mesh: SurfaceTool, layout: Layout, area: Rect2, cell: Vector2, offset: Vector2,
		a: Vector3, b: Vector3, normal: Vector3, lift: float, shade := Color.WHITE) -> bool:
	var neighbor := cell + offset
	var neighbor_tile := Rect2(neighbor - Vector2(0.5, 0.5), Vector2.ONE)
	var bottom := layout.elevation(neighbor) if area.intersects(neighbor_tile) else 0.0
	bottom += lift
	if bottom >= a.y:
		return false
	_quad(mesh, b, a, Vector3(b.x, bottom, b.z), Vector3(a.x, bottom, a.z), normal, shade)
	return true


static func _quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, color: Color) -> void:
	mesh.set_normal(normal)
	mesh.set_color(color)
	for at: Vector3 in [a, b, c, b, d, c]:
		mesh.add_vertex(at)
