extends "res://action_menu.gd"
## Valley Collection donations and skill progress. One donation button per specimen, in farm.gd's SPECIMENS order.

signal donate_requested(index: int)
signal back_requested

@onready var skills: Label = %Skills
@onready var donation_buttons: Array[Button] = []


func _ready() -> void:
	for button in %Donations.get_children():
		donation_buttons.append(button as Button)
