extends "res://action_menu.gd"
## Conversation with a villager: dialogue, up to six choices, and a daily gift.

signal choice_selected(index: int)
signal gift_requested
signal close_requested

@onready var status: Label = %Status
@onready var line: Label = %Line
@onready var choices: Array[Button] = [
	$Rows/Choice0, $Rows/Choice1, $Rows/Choice2, $Rows/Choice3, $Rows/Choice4, $Rows/Choice5,
]
@onready var gifts: OptionButton = %Gifts
@onready var gift_button: Button = %Give


func show_choices(captions: PackedStringArray) -> void:
	for index in range(choices.size()):
		var button := choices[index]
		button.visible = index < captions.size()
		if button.visible:
			button.text = captions[index]
