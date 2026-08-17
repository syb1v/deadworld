extends Node2D

var from := Vector2.ZERO
var to := Vector2.ZERO
var melee := false
var lifetime := 0.14

func setup(start: Vector2, finish: Vector2, is_melee: bool) -> void:
	from = start
	to = finish
	melee = is_melee
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	modulate.a = clampf(lifetime / 0.14, 0.0, 1.0)
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	if melee:
		draw_arc(from, 42.0, (to - from).angle() - 0.7, (to - from).angle() + 0.7, 18, Color("f0d17b"), 5.0)
	else:
		draw_line(from, to, Color("ffe9a3"), 3.0)
		draw_circle(from, 7.0, Color("fff4c2"))
