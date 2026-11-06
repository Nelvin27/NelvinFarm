extends RefCounted

const MORNING := 6.0
const LAST_HOUR := 26.0
const HOURS_PER_SECOND := 1.0 / 12.0
const SLEEP_FATIGUE := 65.0
const EXHAUSTED := 90.0
const FULL := 100.0

var hour := MORNING
var hunger := 80.0
var fatigue := 0.0


func tick(delta: float, walking: bool) -> void:
	hour = minf(hour + delta * HOURS_PER_SECOND, LAST_HOUR)
	var activity := 1.5 if walking else 1.0
	hunger = maxf(0.0, hunger - delta * 0.18 * activity)
	fatigue = minf(FULL, fatigue + delta * 0.36 * activity)


func do_farm_work() -> void:
	hunger = maxf(0.0, hunger - 1.2)
	fatigue = minf(FULL, fatigue + 6.0)


func eat(amount: float, recovery: float) -> void:
	hunger = minf(FULL, hunger + amount)
	fatigue = maxf(0.0, fatigue - recovery)


func rest() -> void:
	hour = MORNING
	fatigue = 0.0
	hunger = maxf(0.0, hunger - 12.0)


func daylight() -> float:
	return smoothstep(4.5, 8.5, hour) * (1.0 - smoothstep(17.5, 21.0, hour))


func clock_text() -> String:
	var minutes := floori(hour * 60.0)
	return "%02d:%02d" % [floori(minutes / 60.0) % 24, minutes % 60]
