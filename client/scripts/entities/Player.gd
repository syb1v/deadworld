extends Node2D

var target_position := Vector2.ZERO
var is_local := false
var health := 100
var player_state := "idle"

func setup(local: bool) -> void:
	is_local = local
	queue_redraw()

func set_authoritative_position(value: Vector2) -> void:
	target_position = value
	if position == Vector2.ZERO:
		position = value

func set_authoritative_state(value: Dictionary) -> void:
	health = value.get("health", health)
	player_state = value.get("state", player_state)
	queue_redraw()

func _process(delta: float) -> void:
	position = position.lerp(target_position, 1.0 - exp(-12.0 * delta))

func _draw() -> void:
	var color := Color("555555") if player_state == "dead" else Color("45a8ff") if is_local else Color("e6a84d")
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(0, -2), 13.0, color)
	draw_line(Vector2.ZERO, Vector2(18, 0), Color.WHITE, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-22, -22), "%d HP" % health, HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color.WHITE)
