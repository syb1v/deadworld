extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(28, 28)
	queue_redraw()

func _draw() -> void:
	var color := Color(0.82, 0.95, 0.7, 0.95)
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 24, color, 1.5)
	draw_line(Vector2(-14, 0), Vector2(-9, 0), color, 2.0)
	draw_line(Vector2(14, 0), Vector2(9, 0), color, 2.0)
	draw_line(Vector2(0, -14), Vector2(0, -9), color, 2.0)
	draw_line(Vector2(0, 14), Vector2(0, 9), color, 2.0)
