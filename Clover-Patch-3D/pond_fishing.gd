extends "res://action_menu.gd"

signal caught
signal bite
signal line_ended
signal close_requested

enum Phase { WAITING, BITING, DONE }

const REEL_WINDOW := 1.6

var phase := Phase.DONE
var remaining := 0.0
var instructions: Label
var bite_meter: ProgressBar
var reel_button: Button
var catch_icon: TextureRect
var cue_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -495
	offset_right = -32
	offset_top = -190
	offset_bottom = 190
	instructions = Label.new()
	instructions.add_theme_font_size_override("font_size", 22)
	rows.add_child(instructions)
	bite_meter = ProgressBar.new()
	bite_meter.max_value = REEL_WINDOW
	bite_meter.show_percentage = false
	bite_meter.custom_minimum_size.y = 12
	rows.add_child(bite_meter)
	catch_icon = TextureRect.new()
	catch_icon.texture = preload("res://assets/items/crop_24.svg")
	catch_icon.custom_minimum_size = Vector2(64, 64)
	catch_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	catch_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	catch_icon.hide()
	rows.add_child(catch_icon)
	reel_button = add_action("Reel in (E)", reel)
	add_action("Leave", close_requested.emit)


func cast(reel_bonus := 0.0) -> void:
	_clear_cue()
	catch_icon.hide()
	phase = Phase.WAITING
	remaining = randf_range(1.0, 2.6)
	bite_meter.max_value = REEL_WINDOW + reel_bonus
	instructions.text = "Line cast. Wait for a bite."
	bite_meter.value = 0.0
	reel_button.disabled = false


func _process(delta: float) -> void:
	if not visible or phase == Phase.DONE:
		return
	remaining -= delta
	if phase == Phase.WAITING and remaining <= 0.0:
		phase = Phase.BITING
		remaining = bite_meter.max_value
		instructions.text = "A fish bites! Reel in now."
		instructions.modulate = Color("#ffe39d")
		reel_button.modulate = Color("#ffe39d")
		cue_tween = create_tween()
		cue_tween.tween_property(reel_button, "modulate", Color.WHITE, 0.35)
		bite.emit()
	if phase == Phase.BITING:
		bite_meter.value = maxf(0.0, remaining)
		if remaining <= 0.0:
			_finish("The fish got away.")


func reel() -> void:
	match phase:
		Phase.WAITING:
			_finish("Too soon. The line came back empty.")
		Phase.BITING:
			_finish("You caught a Pond Perch!")
			catch_icon.show()
			catch_icon.pivot_offset = catch_icon.custom_minimum_size * 0.5
			catch_icon.scale = Vector2.ONE * 0.55
			cue_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			cue_tween.tween_property(catch_icon, "scale", Vector2.ONE, 0.28)
			caught.emit()


func _finish(caption: String) -> void:
	_clear_cue()
	phase = Phase.DONE
	instructions.text = caption
	bite_meter.value = 0.0
	reel_button.disabled = true
	focus_first_action()
	line_ended.emit()


func _clear_cue() -> void:
	if cue_tween != null:
		cue_tween.kill()
	instructions.modulate = Color.WHITE
	reel_button.modulate = Color.WHITE
