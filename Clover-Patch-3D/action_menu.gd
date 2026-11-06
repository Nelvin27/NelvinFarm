extends PanelContainer

@onready var rows: VBoxContainer = $Rows
@onready var title: Label = $Rows/Title


func add_action(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	rows.add_child(button)
	return button


func focus_first_action() -> void:
	for child in rows.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
