extends Node2D

var target_position := Vector2.ZERO
var state := "IDLE"
var hp := 30

func _ready() -> void:
	queue_redraw()

func apply_snapshot(value: Dictionary) -> void:
	target_position = Vector2(value.x, value.y)
	state = value.state
	hp = value.hp
	if position == Vector2.ZERO:
		position = target_position
	queue_redraw()

func _process(delta: float) -> void:
	position = position.lerp(target_position, 1.0 - exp(-10.0 * delta))

func _draw() -> void:
	var color := Color("592c35") if state == "DEAD" else Color("d94b52")
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.4))
	draw_circle(Vector2(0, -2), 14.0, color)
	draw_circle(Vector2(-5, -5), 2.0, Color("f0d9b5"))
	draw_circle(Vector2(5, -5), 2.0, Color("f0d9b5"))
	draw_string(ThemeDB.fallback_font, Vector2(-24, -23), "%s %d" % [state, hp], HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color("eec8c8"))
