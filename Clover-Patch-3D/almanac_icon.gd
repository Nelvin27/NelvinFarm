extends Control

const UISkin := preload("res://farm_ui_theme.gd")
const Weather := preload("res://valley_weather.gd")

enum Face { CLOCK, WEATHER }

var face := Face.CLOCK
var hour := 6.0
var weather := Weather.Kind.CLEAR


func _draw() -> void:
	var center := size * 0.5
	if face == Face.WEATHER:
		_draw_weather(center)
		return
	var radius := minf(center.x, center.y) - 3.0
	draw_circle(center, radius, UISkin.PAPER, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, UISkin.GOLD, 3.0, true)
	for tick in range(12):
		var direction := Vector2.UP.rotated(tick * TAU / 12.0)
		var length := 7.0 if tick % 3 == 0 else 4.0
		draw_line(center + direction * (radius - 5.0 - length),
			center + direction * (radius - 5.0), UISkin.INK, 2.0, true)
	draw_line(center, center + Vector2.UP.rotated(hour * TAU / 12.0) * radius * 0.52,
		UISkin.INK, 4.0, true)
	draw_line(center, center + Vector2.UP.rotated(fposmod(hour, 1.0) * TAU) * radius * 0.75,
		Color("#9d643a"), 2.5, true)
	draw_circle(center, 3.5, UISkin.INK, true, -1.0, true)


func _draw_weather(center: Vector2) -> void:
	match weather:
		Weather.Kind.CLEAR:
			draw_circle(center, 9.0, UISkin.GOLD, true, -1.0, true)
			for ray in range(8):
				var direction := Vector2.UP.rotated(ray * TAU / 8.0)
				draw_line(center + direction * 13.0, center + direction * 18.0, UISkin.GOLD, 2.5, true)
		Weather.Kind.RAIN:
			var cloud := Color("#bfdbdf")
			draw_circle(center + Vector2(-9, -3), 7.0, cloud, true, -1.0, true)
			draw_circle(center + Vector2(0, -8), 10.0, cloud, true, -1.0, true)
			draw_circle(center + Vector2(10, -2), 7.0, cloud, true, -1.0, true)
			draw_rect(Rect2(center + Vector2(-9, -3), Vector2(19, 8)), cloud)
			for x in [-9, 0, 9]:
				draw_line(center + Vector2(x + 2, 9), center + Vector2(x - 2, 16), cloud, 2.5, true)
		Weather.Kind.SNOW:
			var ice := Color("#d7f0ff")
			for branch in range(6):
				var direction := Vector2.UP.rotated(branch * TAU / 6.0)
				var fork := center + direction * 10.0
				draw_line(center, center + direction * 17.0, ice, 2.5, true)
				draw_line(fork, fork + direction.rotated(-0.9) * 6.0, ice, 2.0, true)
				draw_line(fork, fork + direction.rotated(0.9) * 6.0, ice, 2.0, true)
