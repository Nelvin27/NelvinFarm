extends Node3D

enum Mode { SELECT, PLACE, MOVE }

const Layout := preload("res://world_layout.gd")
const Scenery := preload("res://farm_scenery.gd")
const FarmMesh := preload("res://farm_mesh.gd")
const INTERIOR := preload("res://cottage_interior.tscn")
const GROUND := Plane(Vector3.UP, 0.0)
const INTERIOR_ORIGIN := Vector3(0, 0, 160)

var layout := Layout.new()
var mode := Mode.SELECT
var selected := -1
var saved_path := ""
var saved_items: Array[Dictionary] = []
var history: Array = []
var camera: Camera3D
var outline: Node3D
var panel: PanelContainer
var rows: VBoxContainer
var palette: OptionButton
var entity_list: ItemList
var selection_label: Label
var sign_text: LineEdit
var width: SpinBox
var depth: SpinBox
var rotation_choice: CheckButton
var status: Label
var file_dialog: FileDialog
var interior: Node3D
var previewing_interior := false
var opening_legacy := false

@onready var scenery: Scenery = $Scenery


func _ready() -> void:
	_build_view()
	_build_panel()
	var game_root := ProjectSettings.globalize_path("res://").path_join("../Clover-Patch-3D").simplify_path()
	var game_layout := game_root.path_join(Layout.DEFAULT_PATH.trim_prefix("res://"))
	if FileAccess.file_exists(game_layout):
		_open_file(game_layout)
	else:
		_status("Open the game's world/clover_valley.json to begin.")


func _build_view() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8eb5ac")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e7e5db")
	environment.ambient_light_energy = 0.48
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("#fff2dd")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400
	add_child(camera)
	camera.make_current()
	outline = Node3D.new()
	add_child(outline)
	for side in [-1.0, 1.0]:
		FarmMesh.box(outline, Vector3(side * 0.48, 0.16, 0), Vector3(0.04, 0.03, 1), "#f8de89", true)
		FarmMesh.box(outline, Vector3(0, 0.16, side * 0.48), Vector3(1, 0.03, 0.04), "#f8de89", true)
	outline.hide()
	interior = INTERIOR.instantiate() as Node3D
	interior.position = INTERIOR_ORIGIN
	add_child(interior)
	interior.hide()


func _build_panel() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	panel = PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size.x = 380
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#273a31")
	style.set_corner_radius_all(3)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 16)
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "Clover Valley World Builder"
	title.add_theme_font_size_override("font_size", 25)
	rows.add_child(title)
	var help := Label.new()
	help.text = "Click terrain to select, place, or move.\nScroll to zoom · Middle-drag to pan."
	rows.add_child(help)
	var files := _row()
	_button(files, "Open JSON", _choose_open)
	_button(files, "Save", _save)
	_button(files, "Save As", _choose_save)
	var view := _row()
	_button(view, "Frame valley", _frame_valley)
	_button(view, "Cottage preview", _toggle_interior)
	var extras := _row()
	_button(extras, "Repair preview", _toggle_repair_preview)
	_button(extras, "Import old additions", _choose_legacy)

	palette = OptionButton.new()
	for kind in Layout.LABELS:
		palette.add_item(Layout.LABELS[kind])
	palette.select(1)
	rows.add_child(palette)
	var modes := _row()
	_button(modes, "Select", _set_mode.bind(Mode.SELECT))
	_button(modes, "Place", _set_mode.bind(Mode.PLACE))
	_button(modes, "Move selected", _set_mode.bind(Mode.MOVE))

	entity_list = ItemList.new()
	entity_list.custom_minimum_size = Vector2(340, 242)
	entity_list.item_selected.connect(_select)
	rows.add_child(entity_list)
	selection_label = Label.new()
	rows.add_child(selection_label)
	sign_text = LineEdit.new()
	sign_text.placeholder_text = "Sign text"
	rows.add_child(sign_text)
	var dimensions := _row()
	width = _number(dimensions, "Width / length")
	depth = _number(dimensions, "Depth")
	rotation_choice = CheckButton.new()
	rotation_choice.text = "North–south fence"
	rows.add_child(rotation_choice)
	var actions := _row()
	_button(actions, "Apply properties", _apply_properties)
	_button(actions, "Delete", _delete_selected)
	_button(actions, "Undo", _undo)
	status = Label.new()
	status.custom_minimum_size.x = 330
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)

	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.json", "Clover Patch layouts")
	file_dialog.file_selected.connect(_file_selected)
	ui.add_child(file_dialog)


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	rows.add_child(row)
	return row


func _button(parent: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)


func _number(parent: Container, caption: String) -> SpinBox:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(group)
	var label := Label.new()
	label.text = caption
	group.add_child(label)
	var number := SpinBox.new()
	number.min_value = 0.5
	number.max_value = 50.0
	number.step = 0.1
	number.value = 1.0
	group.add_child(number)
	return number


func _set_mode(next: Mode) -> void:
	if next == Mode.MOVE and selected < 0:
		_status("Select an entity first.")
		return
	mode = next
	_status(["Select mode", "Place mode", "Click the new position"][mode])


func _unhandled_input(event: InputEvent) -> void:
	if previewing_interior or layout.entities.is_empty():
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		var from: Variant = _ground(event.position - event.relative)
		var to: Variant = _ground(event.position)
		if from != null and to != null:
			camera.position += from - to
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var point: Variant = _ground(event.position)
	if point == null:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			match mode:
				Mode.SELECT:
					_pick(point)
				Mode.PLACE:
					_place(point)
				Mode.MOVE:
					_move(point)
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size * (0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.17), 6.0, 200.0)
			var after: Variant = _ground(event.position)
			if after != null:
				camera.position += point - after


func _ground(pixel: Vector2) -> Variant:
	return GROUND.intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))


func _frame_valley() -> void:
	if layout.entities.is_empty():
		return
	previewing_interior = false
	interior.hide()
	scenery.show()
	var at := layout.bounds.get_center()
	var target := Vector3(at.x, 0, at.y)
	camera.size = maxf(layout.bounds.size.y, layout.bounds.size.x * 0.76) + 2.0
	camera.position = target + Vector3(0, 60, 39)
	camera.look_at(target)
	_update_outline()


func _toggle_interior() -> void:
	if previewing_interior:
		_frame_valley()
		_status("Valley view")
		return
	previewing_interior = true
	scenery.hide()
	outline.hide()
	interior.show()
	camera.size = 7.3
	camera.position = INTERIOR_ORIGIN + Vector3(0, 9, 8)
	camera.look_at(INTERIOR_ORIGIN)
	_status("Cottage interior preview. Editing applies to the valley.")


func _toggle_repair_preview() -> void:
	if not previewing_interior:
		_toggle_interior()
	var repaired := interior.get_node("Repaired") as Node3D
	repaired.visible = not repaired.visible
	(interior.get_node("Damaged") as Node3D).visible = not repaired.visible
	_status("Repaired cottage preview." if repaired.visible else "Damaged cottage preview.")


func _pick(at: Vector3) -> void:
	var nearest := -1
	var distance := 1.65
	for index in range(layout.entities.size() - 1, -1, -1):
		var center := Layout.position_of(layout.entities[index])
		var gap := Vector2(at.x - center.x, at.z - center.z).length()
		if gap < distance:
			distance = gap
			nearest = index
	_select(nearest)


func _select(index: int) -> void:
	selected = index
	if index < 0:
		entity_list.deselect_all()
		selection_label.text = "No entity selected"
	else:
		var entity := layout.entities[index]
		var kind: String = entity["kind"]
		entity_list.select(index)
		entity_list.ensure_current_is_visible()
		selection_label.text = Layout.LABELS[kind]
		sign_text.text = str(entity.get("label", ""))
		var size: Array = entity.get("size", [1, 1])
		width.value = float(entity.get("length", size[0]))
		depth.value = float(size[1])
		rotation_choice.set_pressed_no_signal(absf(float(entity.get("yaw", 0))) == 90.0)
	_update_outline()


func _update_outline() -> void:
	outline.visible = selected >= 0 and not previewing_interior
	if outline.visible:
		outline.position = Layout.position_of(layout.entities[selected])


func _valid_position(at: Vector3, kind: String, except := -1) -> bool:
	if not layout.bounds.has_point(Vector2(at.x, at.z)):
		_status("Place the entity inside the valley bounds.")
		return false
	if kind == "plot":
		for index in range(layout.entities.size()):
			if index != except and layout.entities[index]["kind"] == "plot" and Layout.position_of(layout.entities[index]).is_equal_approx(at):
				_status("There is already a plot on that tile.")
				return false
	return true


func _place(at: Vector3) -> void:
	var kind: String = Layout.LABELS.keys()[palette.selected]
	var position := Layout.world_at(Layout.tile_at(at))
	if kind in Layout.REQUIRED:
		for index in range(layout.entities.size()):
			if layout.entities[index]["kind"] == kind:
				selected = index
				_move(at)
				return
	if not _valid_position(position, kind):
		return
	_remember()
	var entity := {"kind": kind}
	position.y = 0.065 if kind == "path" else 0.0
	Layout.set_position(entity, position)
	if kind == "pond":
		entity["size"] = [4, 3]
	elif kind == "sign":
		entity["label"] = "Clover Valley"
	layout.entities.append(entity)
	_rebuild(layout.entities.size() - 1)
	_status("Placed %s." % Layout.LABELS[kind])


func _move(at: Vector3) -> void:
	if selected < 0:
		return
	var entity := layout.entities[selected]
	var position := Layout.world_at(Layout.tile_at(at))
	position.y = Layout.position_of(entity).y
	if not _valid_position(position, entity["kind"], selected):
		return
	_remember()
	Layout.set_position(entity, position)
	_rebuild(selected)
	mode = Mode.SELECT
	_status("Moved %s." % Layout.LABELS[entity["kind"]])


func _apply_properties() -> void:
	if selected < 0:
		return
	var entity := layout.entities[selected]
	match entity["kind"]:
		"sign":
			_remember()
			entity["label"] = sign_text.text.left(90)
		"path", "pond":
			_remember()
			entity["size"] = [width.value, depth.value]
		"fence":
			_remember()
			entity["length"] = width.value
			entity["yaw"] = 90.0 if rotation_choice.button_pressed else 0.0
		_:
			_status("Properties apply to signs, paths, ponds, and fences.")
			return
	_rebuild(selected)
	_status("Updated entity properties.")


func _delete_selected() -> void:
	if selected < 0:
		return
	if layout.entities[selected]["kind"] in Layout.REQUIRED:
		_status("The cottage, shops, and spawn can be moved. The game needs one of each.")
		return
	_remember()
	layout.entities.remove_at(selected)
	_rebuild(-1)
	_status("Deleted entity.")


func _remember() -> void:
	history.append(layout.entities.duplicate(true))
	if history.size() > 40:
		history.pop_front()


func _undo() -> void:
	if history.is_empty():
		return
	layout.entities.assign(history.pop_back())
	_rebuild(-1)
	_status("Undid the last change.")


func _rebuild(index: int) -> void:
	scenery.rebuild(layout, true)
	entity_list.clear()
	for item in layout.entities:
		var at := Layout.position_of(item)
		var label: String = item.get("label", Layout.LABELS[item["kind"]])
		entity_list.add_item("%s  ·  %.1f, %.1f" % [label, at.x, at.z])
	_select(index)


func _status(text: String) -> void:
	status.text = text + ("\nUnsaved edits." if layout.entities != saved_items else "")


func _choose_open() -> void:
	if layout.entities != saved_items:
		_status("Save or use Undo before opening another layout.")
		return
	opening_legacy = false
	file_dialog.filters = PackedStringArray(["*.json ; Clover Patch layouts"])
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered_ratio(0.70)


func _choose_save() -> void:
	opening_legacy = false
	file_dialog.filters = PackedStringArray(["*.json ; Clover Patch layouts"])
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.current_file = "clover_valley.json"
	file_dialog.popup_centered_ratio(0.70)


func _file_selected(path: String) -> void:
	if opening_legacy:
		_import_legacy(path)
	elif file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		_save_file(path)
	else:
		_open_file(path)


func _open_file(path: String) -> void:
	var error := layout.read(path)
	if error != OK:
		_status("Could not open the layout: " + error_string(error))
		return
	saved_path = path
	saved_items = layout.entities.duplicate(true)
	history.clear()
	mode = Mode.SELECT
	_rebuild(-1)
	_frame_valley()
	_status("Editing " + path.get_file())
	status.tooltip_text = ProjectSettings.globalize_path(path)


func _save() -> void:
	if saved_path.is_empty():
		_choose_save()
	else:
		_save_file(saved_path)


func _save_file(path: String) -> void:
	var error := layout.write(path)
	if error != OK:
		_status("Could not save the layout: " + error_string(error))
		return
	saved_path = path
	saved_items = layout.entities.duplicate(true)
	_status("Saved " + path.get_file())


func _choose_legacy() -> void:
	opening_legacy = true
	file_dialog.filters = PackedStringArray(["*.cfg ; Old World Builder layouts"])
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered_ratio(0.70)


func _import_legacy(path: String) -> void:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		_status("Could not import old additions: " + error_string(error))
		return
	var old: Variant = config.get_value("world", "pieces", {})
	if not old is Dictionary:
		_status("The file does not contain old World Builder additions.")
		return
	var kinds := ["", "path", "tree", "purple_flower", "fence", "fence", "plot"]
	var additions: Array[Dictionary] = []
	for cell: Variant in old:
		var piece: Variant = old[cell]
		if not cell is Vector2i or not piece is int or piece < 1 or piece >= kinds.size():
			continue
		var at := Layout.world_at(cell)
		var kind: String = kinds[piece]
		if not _valid_position(at, kind):
			continue
		var already_present := false
		for entity in layout.entities:
			var old_at := Layout.position_of(entity)
			if entity["kind"] == kind and Vector2(old_at.x, old_at.z).is_equal_approx(Vector2(at.x, at.z)):
				already_present = true
				break
		if already_present:
			continue
		var addition := {"kind": kind}
		at.y = 0.065 if kind == "path" else 0.0
		Layout.set_position(addition, at)
		if piece == 5:
			addition["yaw"] = 90.0
		additions.append(addition)
	if not additions.is_empty():
		_remember()
		layout.entities.append_array(additions)
		_rebuild(-1)
	_status("Imported %d old additions." % additions.size())
