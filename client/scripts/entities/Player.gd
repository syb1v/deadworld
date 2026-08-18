extends Node2D

var target_position := Vector2.ZERO
var is_local := false
var health := 100
var player_state := "idle"
var authoritative_velocity := Vector2.ZERO
var snapshot_age := 0.0
var animation_time := 0.0
var facing := Vector2.RIGHT

func setup(local: bool) -> void:
	is_local = local
	queue_redraw()

func set_authoritative_position(value: Vector2) -> void:
	if position != Vector2.ZERO and position.distance_to(value) > 180.0:
		position = value
	target_position = value
	snapshot_age = 0.0
	if position == Vector2.ZERO:
		position = value

func set_authoritative_state(value: Dictionary) -> void:
	health = value.get("health", health)
	player_state = value.get("state", player_state)
	authoritative_velocity = Vector2(value.get("vx", 0.0), value.get("vy", 0.0))
	if authoritative_velocity.length_squared() > 4.0:
		facing = authoritative_velocity.normalized()
	queue_redraw()

func _process(delta: float) -> void:
	snapshot_age = minf(snapshot_age + delta, 0.1)
	animation_time += delta
	var presented_target := target_position + authoritative_velocity * snapshot_age
	var distance := position.distance_to(presented_target)
	var response := 18.0 if distance > 24.0 else 12.0
	position = position.lerp(presented_target, 1.0 - exp(-response * delta))
	queue_redraw()

func set_facing(value: Vector2) -> void:
	if value.length_squared() > 0.01:
		facing = value.normalized()

func _draw() -> void:
	var color := Color("565a57") if player_state == "dead" else Color("4bb5d8") if is_local else Color("d5a452")
	if player_state == "dead":
		draw_set_transform(Vector2.ZERO, 0.7)
		draw_ellipse(Vector2(3, 3), 20.0, 8.0, Color(0, 0, 0, 0.38))
		draw_line(Vector2(-14, 0), Vector2(14, 0), Color("222825"), 12.0)
		draw_circle(Vector2(17, 0), 7.0, color)
		return
	var moving := authoritative_velocity.length_squared() > 16.0
	var stride := sin(animation_time * 11.0) * 4.0 if moving else 0.0
	var bob := absf(sin(animation_time * 11.0)) * 2.0 if moving else sin(animation_time * 2.5) * 0.7
	draw_ellipse(Vector2(4, 3), 15.0, 7.0, Color(0, 0, 0, 0.42))
	draw_line(Vector2(-5, -1), Vector2(-5 + stride, 8), Color("1b2522"), 6.0)
	draw_line(Vector2(5, -1), Vector2(5 - stride, 8), Color("1b2522"), 6.0)
	draw_circle(Vector2(0, -10 - bob), 10.5, Color("17201d"))
	draw_circle(Vector2(0, -11 - bob), 9.0, color)
	draw_circle(Vector2(0, -27 - bob), 6.5, Color("c7a983"))
	draw_line(Vector2(0, -12 - bob), facing * 18.0 + Vector2(0, -12 - bob), Color("d9ded8"), 3.0)
	if health < 100:
		draw_rect(Rect2(-14, -39, 28, 4), Color("321919"), true)
		draw_rect(Rect2(-14, -39, 28.0 * health / 100.0, 4), Color("7fd36c"), true)
