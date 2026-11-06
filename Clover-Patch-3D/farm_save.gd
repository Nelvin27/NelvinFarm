extends RefCounted

const VERSION := 1
static var path := "user://farm.cfg"


static func write(state: Dictionary) -> Error:
	var config := ConfigFile.new()
	config.set_value("farm", "version", VERSION)
	config.set_value("farm", "state", state)
	var temporary := path + ".tmp"
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error


static func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var config := ConfigFile.new()
	if config.load(path) != OK or config.get_value("farm", "version", 0) != VERSION:
		push_warning("Clover Patch could not open the farm save.")
		return {}
	var state: Variant = config.get_value("farm", "state", {})
	return state if state is Dictionary else {}


static func count(value: Variant, maximum: int, fallback := 0) -> int:
	return clampi(value, 0, maximum) if value is int else fallback


static func meter(value: Variant, minimum: float, maximum: float, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return clampf(float(value), minimum, maximum)
	return fallback
