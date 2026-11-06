extends RefCounted

const Catalog := preload("res://crop_catalog.gd")
const BREAD := -1

# Crop ID (or bread), quantity, and coin reward. Each board resets next season.
const BOARDS := [
	[Vector3i(0, 3, 20), Vector3i(1, 3, 24), Vector3i(3, 4, 36)],
	[Vector3i(9, 3, 24), Vector3i(7, 4, 36), Vector3i(8, 4, 44)],
	[Vector3i(16, 3, 24), Vector3i(14, 4, 32), Vector3i(15, 4, 36)],
	[Vector3i(BREAD, 5, 16), Vector3i(0, 4, 28), Vector3i(8, 4, 44)],
]


static func item_name(id: int) -> String:
	return "Bread" if id == BREAD else Catalog.crops[id].label
