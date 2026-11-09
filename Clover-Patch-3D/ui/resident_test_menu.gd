extends "res://action_menu.gd"
## Developer tools for testing one resident's favor, romance, gifts, and routine.

signal resident_selected(item: int)
signal set_favor_requested
signal favor_preset_requested(value: int)
signal reset_romance_requested
signal gift_kit_requested
signal open_dialogue_requested
signal go_to_resident_requested
signal watch_departure_requested
signal back_requested

@onready var picker: OptionButton = %Picker
@onready var status: Label = %Status
@onready var favor: SpinBox = %Favor


func _ready() -> void:
	picker.item_selected.connect(resident_selected.emit)
