extends "res://action_menu.gd"
## Farm Bag window around the inventory grid. Re-emits the grid's signals so the farm
## can connect to this menu without reaching into its children.

signal item_used(kind: InventoryGrid.Kind, item_id: int)
signal stacks_changed
signal backpack_upgrade_requested
signal close_requested

const InventoryGrid := preload("res://inventory_grid.gd")

@onready var grid: InventoryGrid = %Grid
@onready var backpack_upgrade: Button = %BackpackUpgrade


func _ready() -> void:
	grid.item_used.connect(item_used.emit)
	grid.stacks_changed.connect(stacks_changed.emit)
