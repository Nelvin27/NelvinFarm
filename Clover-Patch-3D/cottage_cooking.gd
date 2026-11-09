extends "res://action_menu.gd"
## Cottage stove. Layout lives in ui/cooking_menu.tscn; recipes are defined here.

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

@onready var meal_buttons: Array[Button] = [$Rows/Meal0, $Rows/Meal1, $Rows/Meal2]
@onready var status: Label = %Status


func _ready() -> void:
	for index in range(recipes.size()):
		var recipe := recipes[index]
		var ingredients: PackedStringArray = []
		for id in recipe.ingredients:
			var item := "Bread" if id == BREAD else Catalog.crops[id].label
			ingredients.append("%s ×%d" % [item, recipe.ingredients[id]])
		meal_buttons[index].text = "%s  ·  %s" % [recipe.label, ", ".join(ingredients)]
		meal_buttons[index].tooltip_text = "Restores %d food and reduces fatigue by %d." % [
			recipe.hunger, recipe.fatigue]
		meal_buttons[index].pressed.connect(cook_requested.emit.bind(recipe))


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
