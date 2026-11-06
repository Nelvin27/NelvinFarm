extends VBoxContainer

signal stacks_changed
signal item_used(kind: Kind, item_id: int)

enum Kind { BREAD, SEED, HARVEST, TOOL }

const UISkin := preload("res://farm_ui_theme.gd")
const ITEM_TYPES := ["Provisions", "Seeds", "Harvest & finds", "Tools"]
const ROW_SIZE := 12
const MAX_ROWS := 3
const PAGE_SIZE := ROW_SIZE * MAX_ROWS
const STACK_LIMIT := 64


class Stack:
	var kind: Kind
	var item_id: int
	var title: String
	var quantity: int
	var texture: Texture2D
	var action: String
	var equipped: bool

	func key() -> Vector2i:
		return Vector2i(kind, item_id)


var stacks: Array[Stack] = []
var slots: Array[Button] = []
var icons: Array[TextureRect] = []
var counts: Array[Label] = []
var unlocked_rows := 1
var page := 0
var selection := -1
var using_slot := -1
var details: Label
var item_type: Label
var preview_icon: TextureRect
var page_label: Label
var use_button: Button
var previous: Button
var following: Button


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	add_child(body)
	var grid := GridContainer.new()
	grid.columns = ROW_SIZE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for index in range(PAGE_SIZE):
		_add_slot(grid, index)

	var card := PanelContainer.new()
	card.custom_minimum_size.x = 265
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UISkin.box(
		Color("#f5dfb7"), Color("#c69b68"), 12, Vector2(16, 14)))
	body.add_child(card)
	var inspection := VBoxContainer.new()
	inspection.add_theme_constant_override("separation", 8)
	card.add_child(inspection)
	item_type = Label.new()
	item_type.add_theme_font_size_override("font_size", 17)
	inspection.add_child(item_type)
	preview_icon = TextureRect.new()
	preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.custom_minimum_size.y = 94
	inspection.add_child(preview_icon)
	details = Label.new()
	details.theme_type_variation = &"FarmHeading"
	details.add_theme_font_size_override("font_size", 24)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = SIZE_EXPAND_FILL
	inspection.add_child(details)
	use_button = _add_button(inspection, "Use item", _use_selected)

	var actions := HBoxContainer.new()
	add_child(actions)
	previous = _add_button(actions, "Previous", _move_page.bind(-1))
	page_label = Label.new()
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(page_label)
	following = _add_button(actions, "Next", _move_page.bind(1))
	_draw_slots()


func _add_slot(grid: GridContainer, index: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(54, 58)
	button.toggle_mode = true
	button.pressed.connect(_select.bind(index))
	button.set_drag_forwarding(_drag_slot.bind(index), _can_drop_on_slot.bind(index),
		_drop_on_slot.bind(index))
	grid.add_child(button)
	slots.append(button)

	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 4
	icon.offset_right = -8
	icon.offset_bottom = -7
	icons.append(icon)

	var count := Label.new()
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_font_size_override("font_size", 20)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color("#292523"))
	count.add_theme_constant_override("outline_size", 8)
	button.add_child(count)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -5
	count.offset_bottom = -3
	counts.append(count)


func _add_button(parent: Container, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func add_stacks(items: Array[Stack], kind: Kind, id: int, title: String, quantity: int,
		icon_path: String, action: String, equipped := false) -> void:
	if quantity <= 0:
		return
	var texture := load("res://assets/items/" + icon_path + ".svg") as Texture2D
	while quantity > 0:
		var stack := Stack.new()
		stack.kind = kind
		stack.item_id = id
		stack.title = title
		stack.quantity = mini(quantity, STACK_LIMIT)
		stack.texture = texture
		stack.action = action
		stack.equipped = equipped
		items.append(stack)
		quantity -= stack.quantity


func show_stacks(items: Array[Stack]) -> void:
	var remaining: Dictionary[Vector2i, int] = {}
	var templates: Dictionary[Vector2i, Stack] = {}
	for stack in items:
		var key := stack.key()
		remaining[key] = remaining.get(key, 0) + stack.quantity
		templates[key] = stack

	# Consume from the slot the player used before reconciling the other stacks.
	if using_slot >= 0:
		var used := stacks[using_slot]
		var total := 0
		for stack in stacks:
			if stack != null and stack.key() == used.key():
				total += stack.quantity
		used.quantity -= clampi(total - remaining.get(used.key(), 0), 0, used.quantity)

	# Keep positions and partial stacks when inventory totals refresh.
	for index in range(stacks.size()):
		var stack := stacks[index]
		if stack == null:
			continue
		var key := stack.key()
		var quantity := mini(stack.quantity, remaining.get(key, 0))
		if quantity == 0:
			stacks[index] = null
			continue
		stacks[index] = _copy_stack(templates[key], quantity)
		remaining[key] -= quantity

	for key in remaining:
		var quantity := remaining[key]
		if quantity == 0:
			continue
		for index in range(unlocked_rows * ROW_SIZE):
			var stack := stack_at(index)
			if stack != null and stack.key() == key:
				var added := mini(quantity, STACK_LIMIT - stack.quantity)
				stack.quantity += added
				quantity -= added
				if quantity == 0:
					break
		while quantity > 0:
			var stack := _copy_stack(templates[key], mini(quantity, STACK_LIMIT))
			var empty := _empty_slot()
			if empty >= stacks.size():
				stacks.resize(empty + 1)
			stacks[empty] = stack
			quantity -= stack.quantity

	while not stacks.is_empty() and stacks.back() == null:
		stacks.pop_back()
	if selection >= stacks.size() or (selection >= 0 and stacks[selection] == null):
		selection = -1
	page = mini(page, _last_page())
	_draw_slots()
	stacks_changed.emit()


func _empty_slot() -> int:
	for index in range(unlocked_rows * ROW_SIZE):
		if stack_at(index) == null:
			return index
	for index in range(PAGE_SIZE, stacks.size()):
		if stacks[index] == null:
			return index
	return maxi(PAGE_SIZE, stacks.size())


func can_add(kind: Kind, id: int, quantity := 1) -> bool:
	return can_add_stacks(kind, {id: quantity})


func can_add_stacks(kind: Kind, quantities: Dictionary) -> bool:
	var remaining := quantities.duplicate()
	var empty := 0
	for index in range(unlocked_rows * ROW_SIZE):
		var stack := stack_at(index)
		if stack == null:
			empty += 1
		elif stack.kind == kind and remaining.has(stack.item_id):
			remaining[stack.item_id] = maxi(0, remaining[stack.item_id] - (STACK_LIMIT - stack.quantity))
	for quantity: int in remaining.values():
		empty -= ceili(float(quantity) / STACK_LIMIT)
	return empty >= 0


func save_slots() -> Array[Vector3i]:
	var saved: Array[Vector3i] = []
	for stack in stacks:
		saved.append(Vector3i(stack.kind, stack.item_id, stack.quantity) if stack != null else Vector3i.ZERO)
	return saved


func restore_slots(saved: Variant) -> void:
	if not saved is Array:
		return
	stacks.clear()
	for entry: Variant in saved:
		var stack: Stack
		if entry is Vector3i and entry.x >= Kind.BREAD and entry.x <= Kind.TOOL and entry.z > 0:
			stack = Stack.new()
			stack.kind = entry.x as Kind
			stack.item_id = entry.y
			stack.quantity = mini(entry.z, STACK_LIMIT)
		stacks.append(stack)
	var reserve: Array[Stack] = []
	for index in range(unlocked_rows * ROW_SIZE, mini(PAGE_SIZE, stacks.size())):
		if stacks[index] != null:
			reserve.append(stacks[index])
			stacks[index] = null
	if not reserve.is_empty():
		stacks.resize(maxi(PAGE_SIZE, stacks.size()))
		stacks.append_array(reserve)
	# show_stacks reconciles these positions with the authoritative inventory and restores icons.


func _copy_stack(source: Stack, quantity: int) -> Stack:
	var stack := Stack.new()
	stack.kind = source.kind
	stack.item_id = source.item_id
	stack.title = source.title
	stack.quantity = quantity
	stack.texture = source.texture
	stack.action = source.action
	stack.equipped = source.equipped
	return stack


func stack_at(slot: int) -> Stack:
	return stacks[slot] if slot >= 0 and slot < stacks.size() else null


func _drag_slot(_at: Vector2, index: int) -> Variant:
	var source := page * PAGE_SIZE + index
	var stack := stack_at(source)
	if stack == null:
		return null
	var preview := TextureRect.new()
	preview.texture = stack.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(52, 52)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots[index].set_drag_preview(preview)
	return {"bag": self, "source": source, "stack": stack}


func _can_drop_on_slot(_at: Vector2, data: Variant, index: int) -> bool:
	if not data is Dictionary or data.get("bag") != self:
		return false
	var source: int = data.get("source", -1)
	var target := page * PAGE_SIZE + index
	var stack := stack_at(source)
	if _is_locked(target) or stack == null or stack != data.get("stack") or source == target:
		return false
	var destination := stack_at(target)
	return destination == null or destination.key() != stack.key() or destination.quantity < STACK_LIMIT


func _drop_on_slot(at: Vector2, data: Variant, index: int) -> void:
	if not _can_drop_on_slot(at, data, index):
		return
	var source: int = data["source"]
	var target := page * PAGE_SIZE + index
	var stack := stacks[source]
	var destination := stack_at(target)
	if target >= stacks.size():
		stacks.resize(target + 1)
	if destination != null and destination.key() == stack.key():
		var moved := mini(stack.quantity, STACK_LIMIT - destination.quantity)
		destination.quantity += moved
		stack.quantity -= moved
		if stack.quantity == 0:
			stacks[source] = null
	else:
		stacks[target] = stack
		stacks[source] = destination
	selection = target
	_draw_slots()
	stacks_changed.emit()


func _last_page() -> int:
	return maxi(0, ceili(float(stacks.size()) / PAGE_SIZE) - 1)


func _is_locked(slot: int) -> bool:
	return slot < PAGE_SIZE and slot >= unlocked_rows * ROW_SIZE


func _draw_slots() -> void:
	for index in range(PAGE_SIZE):
		var slot := page * PAGE_SIZE + index
		var stack := stack_at(slot)
		var locked := _is_locked(slot)
		slots[index].disabled = locked
		slots[index].text = "×" if locked else ""
		slots[index].focus_mode = Control.FOCUS_ALL if stack != null else Control.FOCUS_NONE
		slots[index].set_pressed_no_signal(slot == selection)
		slots[index].tooltip_text = "Locked · Upgrade your backpack" if locked else (stack.title if stack != null else "")
		icons[index].texture = stack.texture if stack != null else null
		counts[index].text = str(stack.quantity) if stack != null else ""
	var selected := stack_at(selection)
	item_type.text = "IN YOUR BAG" if selected == null else ITEM_TYPES[selected.kind].to_upper()
	preview_icon.texture = selected.texture if selected != null else null
	details.text = "Select an item. Drag stacks to rearrange them." if selected == null else (
		"%s ×%d%s" % [selected.title, selected.quantity, "\nEquipped" if selected.equipped else ""])
	use_button.text = selected.action if selected != null and not selected.action.is_empty() else "Use item"
	use_button.disabled = selected == null or selected.action.is_empty()
	previous.disabled = page == 0
	following.disabled = page == _last_page()
	page_label.text = "%d / %d slots unlocked  ·  First row is the hotbar" % [
		unlocked_rows * ROW_SIZE, PAGE_SIZE] if page == 0 else "Reserve · %d / %d" % [page, _last_page()]


func _select(index: int) -> void:
	var slot := page * PAGE_SIZE + index
	if stack_at(slot) == null:
		slots[index].set_pressed_no_signal(false)
		return
	selection = slot
	_draw_slots()


func focus_first_item() -> bool:
	for button in slots:
		if button.focus_mode == Control.FOCUS_ALL:
			button.grab_focus()
			return true
	return false


func _move_page(direction: int) -> void:
	page += direction
	selection = -1
	_draw_slots()
	focus_first_item()


func _use_selected() -> void:
	if use_button.disabled:
		return
	use_slot(selection)
	if use_button.disabled:
		focus_first_item()


func use_slot(index: int) -> void:
	var stack := stack_at(index)
	if stack == null or stack.action.is_empty():
		return
	using_slot = index
	item_used.emit(stack.kind, stack.item_id)
	using_slot = -1
