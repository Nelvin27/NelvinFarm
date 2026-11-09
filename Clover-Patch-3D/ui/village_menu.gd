extends "res://action_menu.gd"
## Village and story page of the journal.

signal directory_requested
signal back_requested

@onready var story: Label = %Story
