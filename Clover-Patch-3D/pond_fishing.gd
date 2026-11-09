extends "res://action_menu.gd"
## Willow Pond fishing minigame. Layout lives in ui/fishing_menu.tscn.

signal caught
signal bite
signal line_ended
signal close_requested

enum Phase { WAITING, BITING, DONE }

const REEL_WINDOW := 1.6

var phase := Phase.DONE
var remaining := 0.0
var cue_tween: Tween
var catch_name := "Pond Perch"

@onready var instructions: Label = %Instructions
@onready var bite_meter: ProgressBar = %BiteMeter
@onready var reel_button: Button = %Reel
@onready var catch_icon: TextureRect = %CatchIcon


func prepare_catch(label: String, icon: Texture2D) -> void:
	catch_name = label
	catch_icon.texture = icon


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
			_finish("You caught a %s!" % catch_name)
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
