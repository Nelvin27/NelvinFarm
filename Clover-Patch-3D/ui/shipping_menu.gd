extends "res://action_menu.gd"
## Shipping bin beside the cottage. Buttons are wired to these signals in shipping_menu.tscn.

signal ship_requested
signal retrieve_requested
signal close_requested

@onready var summary: Label = %Summary
@onready var stock: OptionButton = %Stock
@onready var ship_button: Button = %Ship
@onready var retrieve_button: Button = %Retrieve
