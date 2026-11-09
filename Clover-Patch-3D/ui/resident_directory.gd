extends "res://action_menu.gd"
## Resident directory: pick a villager to see where they are and their routine.

signal resident_selected(item: int)
signal back_requested

@onready var select: OptionButton = %Select
@onready var text: Label = %Text


func _ready() -> void:
	select.item_selected.connect(resident_selected.emit)
