extends SceneTree
## Renders previews of the valley to PNG files (needs a window, so run without --headless).
##   godot --path Clover-Patch-3D --script ../tools/world/render_world.gd -- [view ...] [--out DIR]
## Views: top, overview, farm, square, bread_lane, council_row, commons, lakes, summit, glade, stones,
## hidden_pond, meadow, or "x,z,distance,pitch,yaw". Images go to tools/world/renders/ unless --out is given.
## Options: --hour 22 (time of day), --season 0-3 (spring..winter), --rain, --suffix _night (file name tag).

const VIEWS := {
	"top": "35,2,120",                 # orthographic, straight down: x, z, size
	"overview": "24,4,72,30,8",        # perspective: x, z, distance, pitch, yaw (degrees)
	"farm": "-6,4,22,30,-25",
	"square": "8,4,14,34,20",
	"bread_lane": "26,3,15,24,0",
	"council_row": "40,-6,15,30,10",
	"commons": "36,12,17,36,15",
	"lakes": "78,26,26,30,10",
	"summit": "-13.5,-24,13,38,20",
	"glade": "66,-14,13,40,15",
	"stones": "48.5,29,15,30,25",
	"hidden_pond": "-8,39,12,38,10",
	"meadow": "16,16,20,28,10",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var names: Array[String] = []
	var out := ProjectSettings.globalize_path("res://").path_join("../tools/world/renders").simplify_path()
	var args := OS.get_cmdline_user_args()
	var hour := -1.0
	var season := -1
	var rain := false
	var suffix := ""
	var index := 0
	while index < args.size():
		if args[index] == "--out" and index + 1 < args.size():
			out = args[index + 1]
			index += 1
		elif args[index] == "--hour" and index + 1 < args.size():
			hour = float(args[index + 1])
			index += 1
		elif args[index] == "--season" and index + 1 < args.size():
			season = int(args[index + 1])
			index += 1
		elif args[index] == "--suffix" and index + 1 < args.size():
			suffix = args[index + 1]
			index += 1
		elif args[index] == "--rain":
			rain = true
		else:
			names.append(args[index])
		index += 1
	if names.is_empty():
		names.assign(["top", "overview", "bread_lane", "council_row"])
	DirAccess.make_dir_recursive_absolute(out)
	var Save = load("res://farm_save.gd")
	Save.path = OS.get_temp_dir().path_join("clover-world-render-%d.cfg" % OS.get_process_id())
	var farm: Node = load("res://farm.tscn").instantiate()
	root.add_child(farm)
	for i in 5:
		await process_frame
	if season >= 0:
		farm.season = season
		farm.scenery.set_season(season)
		farm._update_forage()
	if rain:
		farm.weather.apply(farm.Weather.Kind.RAIN, true)
		farm.scenery.set_wet(true)
	if hour >= 0.0:
		farm.clock.hour = hour
	farm._update_daylight()
	farm.set_process(false)
	farm.get_node("UI").hide()
	if farm.fireflies.emitting:
		farm.fireflies.preprocess = 5.0
		farm.fireflies.restart()
	var camera: Camera3D = farm.camera
	camera.far = 400.0
	for name in names:
		var view := (VIEWS.get(name, name) as String).split(",")
		var target: Vector3 = farm.layout.grounded(Vector3(float(view[0]), 0, float(view[1])))
		if view.size() == 3:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = float(view[2])
			camera.position = target + Vector3.UP * 120.0
			camera.rotation = Vector3(-PI / 2, 0, 0)
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 50.0
			var pitch := deg_to_rad(float(view[3]))
			var yaw := deg_to_rad(float(view[4]))
			camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(view[2])
			camera.look_at(target)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var file := out.path_join(name.replace(",", "_") + suffix + ".png")
		root.get_texture().get_image().save_png(file)
		print("Rendered ", file)
	farm.queue_free()
	await process_frame
	quit()
