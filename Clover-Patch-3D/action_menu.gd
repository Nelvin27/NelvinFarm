extends PanelContainer

@onready var rows: VBoxContainer = $Rows
@onready var title: Label = $Rows/Title


func add_action(caption: String, action: Callable, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	var target := parent if parent != null else rows
	target.add_child(button)
	return button


func focus_first_action() -> void:
	for child in rows.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return
