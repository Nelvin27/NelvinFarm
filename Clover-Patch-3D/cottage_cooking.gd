extends "res://action_menu.gd"

signal cook_requested(recipe: Recipe)
signal close_requested

const Catalog := preload("res://crop_catalog.gd")
const BREAD := -1


class Recipe:
	var label: String
	var ingredients: Dictionary[int, int]
	var hunger: float
	var fatigue: float

	func _init(meal: String, items: Dictionary[int, int], food: float, recovery: float) -> void:
		label = meal
		ingredients = items
		hunger = food
		fatigue = recovery

	func has_ingredients(produce: Dictionary[int, int], rations: int) -> bool:
		for id in ingredients:
			var available: int = rations if id == BREAD else produce.get(id, 0)
			if available < ingredients[id]:
				return false
		return true


var recipes: Array[Recipe] = [
	Recipe.new("Garden Stew", {Catalog.TURNIP: 1, BREAD: 1}, 70.0, 42.0),
	Recipe.new("Orchard Toast", {Catalog.APPLE: 1, BREAD: 1}, 65.0, 46.0),
	Recipe.new("Pan-Seared Perch", {Catalog.POND_PERCH: 1}, 40.0, 30.0),
]

var meal_buttons: Array[Button] = []
var status: Label


func _ready() -> void:
	title.text = "Cottage Kitchen"
	offset_left = -380
	offset_right = 380
	status = Label.new()
	status.add_theme_font_size_override("font_size", 22)
	rows.add_child(status)
	for recipe in recipes:
		var ingredients: PackedStringArray = []
		for id in recipe.ingredients:
			var item := "Bread" if id == BREAD else Catalog.crops[id].label
			ingredients.append("%s ×%d" % [item, recipe.ingredients[id]])
		var caption := "%s  ·  %s" % [recipe.label, ", ".join(ingredients)]
		var button := add_action(caption, cook_requested.emit.bind(recipe))
		button.tooltip_text = "Restores %d food and reduces fatigue by %d." % [recipe.hunger, recipe.fatigue]
		meal_buttons.append(button)
	add_action("Close", close_requested.emit)


func update_stock(produce: Dictionary[int, int], rations: int, can_cook: bool) -> void:
	status.text = "Cook and eat here to recover." if can_cook else "You are already full and rested."
	var needs_focus := false
	for index in range(recipes.size()):
		var button := meal_buttons[index]
		var had_focus := button.has_focus()
		button.disabled = not can_cook or not recipes[index].has_ingredients(produce, rations)
		needs_focus = needs_focus or (button.disabled and had_focus)
	if needs_focus:
		focus_first_action()
