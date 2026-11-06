extends PanelContainer

signal buy_requested(crop_id: int)
signal sell_requested
signal close_requested

const Catalog := preload("res://crop_catalog.gd")

var balance := 0
@onready var seeds: OptionButton = $Rows/Seeds
@onready var timing: Label = $Rows/Timing
@onready var stock: Label = $Rows/Stock
@onready var buy_button: Button = $Rows/Buy
@onready var sell_button: Button = $Rows/Sell
@onready var close_button: Button = $Rows/Close


func _ready() -> void:
	seeds.item_selected.connect(_update_selection)
	buy_button.pressed.connect(_request_purchase)
	sell_button.pressed.connect(_request_sale)
	close_button.pressed.connect(close_requested.emit)


func set_season(season: Catalog.Season, equipped: int) -> void:
	seeds.clear()
	for id in range(Catalog.SEED_COUNT):
		var crop := Catalog.crops[id]
		if crop.grows_in(season):
			seeds.add_item(crop.label, id)
			if id == equipped:
				seeds.select(seeds.item_count - 1)
	if seeds.item_count > 0 and seeds.selected < 0:
		seeds.select(0)
	seeds.disabled = seeds.item_count == 0


func update_stock(caption: String, coins: int, harvest_value: int) -> void:
	stock.text = caption
	balance = coins
	sell_button.disabled = harvest_value == 0
	sell_button.text = "Sell harvest  ·  %d coins" % harvest_value
	_update_selection(seeds.selected)


func _update_selection(index: int) -> void:
	if index < 0:
		buy_button.disabled = true
		buy_button.text = "Buy seed"
		timing.text = "Winter break. New seeds arrive in Spring."
		return
	var crop := Catalog.crops[seeds.get_item_id(index)]
	buy_button.disabled = balance < crop.seed_price()
	buy_button.text = "Buy one seed  ·  %d coins" % crop.seed_price()
	timing.text = "First harvest: day %d (planting is day 1)" % crop.harvest_day
	if crop.regrowth > 0:
		timing.text += "   ·   Regrows in %d days" % crop.regrowth


func focus_first_action() -> void:
	if not buy_button.disabled:
		buy_button.grab_focus()
	elif not sell_button.disabled:
		sell_button.grab_focus()
	else:
		close_button.grab_focus()


func _request_purchase() -> void:
	if seeds.selected < 0:
		return
	buy_requested.emit(seeds.get_selected_id())
	if buy_button.disabled:
		close_button.grab_focus()


func _request_sale() -> void:
	sell_requested.emit()
	if not buy_button.disabled:
		buy_button.grab_focus()
