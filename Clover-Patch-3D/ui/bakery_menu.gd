extends "res://action_menu.gd"
## Valley Bakery counter. Buttons are wired to these signals in bakery_menu.tscn.

signal buy_requested
signal close_requested

@onready var stock: Label = %Stock
@onready var buy_button: Button = %Buy
