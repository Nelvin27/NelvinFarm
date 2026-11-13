extends VBoxContainer
## Farm Bag stack grid. Layout lives in ui/inventory_grid.tscn.

signal stacks_changed
signal item_used(kind: Kind, item_id: int)

enum Kind { BREAD, SEED, HARVEST, TOOL }

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

@onready var details: Label = %Details
@onready var item_type: Label = %ItemType
@onready var preview_icon: TextureRect = %Preview
@onready var page_label: Label = %PageLabel
@onready var use_button: Button = %Use
@onready var previous: Button = %Previous
@onready var following: Button = %Next


func _ready() -> void:
	for slot in %Slots.get_children():
		var button := slot as Button
		var index := slots.size()
		button.pressed.connect(_select.bind(index))
		button.gui_input.connect(_slot_input.bind(index))
		button.set_drag_forwarding(_drag_slot.bind(index), _can_drop_on_slot.bind(index),
			_drop_on_slot.bind(index))
		slots.append(button)
		icons.append(button.get_node("Icon") as TextureRect)
		counts.append(button.get_node("Count") as Label)
	assert(slots.size() == PAGE_SIZE, "inventory_grid.tscn needs one slot per page position.")
	_draw_slots()


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
	details.text = "Select an item. Drag stacks to rearrange them.\nRight-click or double-click to use one." if selected == null else (
		"%s ×%d%s" % [selected.title, selected.quantity, "\nEquipped" if selected.equipped else ""])
	use_button.text = selected.action if selected != null and not selected.action.is_empty() else "Use item"
	use_button.disabled = selected == null or selected.action.is_empty()
	var has_reserve := _last_page() > 0
	previous.visible = has_reserve
	following.visible = has_reserve
	previous.disabled = page == 0
	following.disabled = page == _last_page()
	page_label.text = "%d / %d slots unlocked  ·  First row is the hotbar" % [
		unlocked_rows * ROW_SIZE, PAGE_SIZE] if page == 0 else "Reserve · %d / %d" % [page, _last_page()]


## Right-click or double-click uses an item straight from its slot.
func _slot_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT or (click.button_index == MOUSE_BUTTON_LEFT and click.double_click):
		var slot := page * PAGE_SIZE + index
		if stack_at(slot) != null:
			selection = slot
			use_slot(slot)
			_draw_slots()


## Tidies the bag: merges split stacks and orders them tools, seeds, provisions, then harvest.
func sort() -> void:
	var merged: Dictionary[Vector2i, Stack] = {}
	for stack in stacks:
		if stack == null:
			continue
		if merged.has(stack.key()):
			merged[stack.key()].quantity += stack.quantity
		else:
			merged[stack.key()] = _copy_stack(stack, stack.quantity)
	var order := merged.keys()
	var rank := {Kind.TOOL: 0, Kind.SEED: 1, Kind.BREAD: 2, Kind.HARVEST: 3}
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return rank[a.x] < rank[b.x] or (rank[a.x] == rank[b.x] and a.y < b.y))
	stacks.clear()
	for key: Vector2i in order:
		var total := merged[key].quantity
		while total > 0:
			var slot := _empty_slot()
			if slot >= stacks.size():
				stacks.resize(slot + 1)
			stacks[slot] = _copy_stack(merged[key], mini(total, STACK_LIMIT))
			total -= mini(total, STACK_LIMIT)
	selection = -1
	page = 0
	_draw_slots()
	stacks_changed.emit()


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
