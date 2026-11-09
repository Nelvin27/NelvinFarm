extends PanelContainer
## Shared menu panel (action_menu.tscn). Menus inherit the scene and add their own rows.

@onready var rows: VBoxContainer = $Rows
@onready var title: Label = $Rows/Title


func focus_first_action() -> void:
	for child in rows.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return
