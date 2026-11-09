extends Control
## On-screen HUD. Layout lives in ui/hud.tscn; this script only fills it in.

signal slot_requested(index: int)
signal bag_requested
signal journal_requested
signal pause_requested
signal interact_requested

const AlmanacIcon := preload("res://almanac_icon.gd")
const Bag := preload("res://inventory_grid.gd")
const Weather := preload("res://valley_weather.gd")

var _slots: Array[Button] = []
var _current_prompt := ""

@onready var location_label: Label = %Location
@onready var stats_label: Label = %Date
@onready var stock_label: Label = %Stock
@onready var hunger_meter: ProgressBar = %HungerMeter
@onready var fatigue_meter: ProgressBar = %FatigueMeter
@onready var needs_label: Label = %Needs
@onready var tool_label: Label = %Tool
@onready var crop_label: Label = %Crop
@onready var interaction_prompt: Button = %Prompt
@onready var _clock: AlmanacIcon = %Clock
@onready var _weather: AlmanacIcon = %WeatherIcon
@onready var _period: Label = %Period
@onready var _cursor_hint: Label = %CursorHint
@onready var _notice: PanelContainer = %Notice
@onready var _notice_text: Label = %NoticeText
@onready var _notice_timer: Timer = %NoticeTimer


func _ready() -> void:
	for slot in %Hotbar.get_children():
		var index := _slots.size()
		_slots.append(slot as Button)
		slot.pressed.connect(slot_requested.emit.bind(index))


func show_notice(message: String) -> void:
	if _notice_text.text == message:
		return
	_notice_text.text = message
	_notice.show()
	_notice_timer.start(6.0)


func set_almanac(date: String, hour: float, weather: Weather.Kind) -> void:
	stats_label.text = date
	_period.text = "AM" if fposmod(hour, 24.0) < 12.0 else "PM"
	if _clock.hour != hour:
		_clock.hour = hour
		_clock.queue_redraw()
	if _weather.weather != weather or _weather.tooltip_text.is_empty():
		_weather.weather = weather
		_weather.tooltip_text = Weather.NAMES[weather]
		_weather.queue_redraw()


func set_hotbar(bag: Bag, selected: int, held_tool: String) -> void:
	var stack := bag.stack_at(selected)
	var item := stack.title if stack != null else "Empty slot"
	if stack != null and stack.kind == Bag.Kind.TOOL and stack.equipped:
		item = held_tool
	else:
		item += "  ·  Holding " + held_tool
	tool_label.text = "%s  ·  Wheel to select  ·  F to use" % item
	for index in range(_slots.size()):
		stack = bag.stack_at(index)
		_slots[index].icon = stack.texture if stack != null else null
		_slots[index].tooltip_text = stack.title if stack != null else "Empty slot"
		_slots[index].set_pressed_no_signal(index == selected)
		(_slots[index].get_node("Count") as Label).text = (
			str(stack.quantity) if stack != null and stack.quantity > 1 else "")


func set_cursor_available(available: bool) -> void:
	_cursor_hint.text = "Tab  ·  Return to camera" if available else "Tab  ·  Free cursor"


func set_prompt(caption: String, can_interact: bool) -> void:
	crop_label.visible = not crop_label.text.is_empty()
	if _current_prompt == caption and interaction_prompt.visible == (not caption.is_empty()):
		return
	_current_prompt = caption
	interaction_prompt.text = caption
	interaction_prompt.disabled = not can_interact
	interaction_prompt.visible = not caption.is_empty()
