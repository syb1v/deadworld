extends Node2D

var target_position := Vector2.ZERO
var state := "IDLE"
var hp := 30
var velocity := Vector2.ZERO
var snapshot_age := 0.0
var animation_time := 0.0
var facing := Vector2.LEFT

func _ready() -> void:
	queue_redraw()

func apply_snapshot(value: Dictionary) -> void:
	target_position = Vector2(value.x, value.y)
	state = value.state
	hp = value.hp
	velocity = Vector2(value.get("vx", 0.0), value.get("vy", 0.0))
	if velocity.length_squared() > 1.0: facing = velocity.normalized()
	snapshot_age = 0.0
	if position == Vector2.ZERO:
		position = target_position
	queue_redraw()

func _process(delta: float) -> void:
	snapshot_age = minf(snapshot_age + delta, 0.1)
	animation_time += delta
	var presented_target := target_position + velocity * snapshot_age
	position = position.lerp(presented_target, 1.0 - exp(-11.0 * delta))
	queue_redraw()

func _draw() -> void:
	if state == "DEAD":
		draw_ellipse(Vector2(4, 4), 20.0, 8.0, Color(0, 0, 0, 0.42))
		draw_line(Vector2(-15, 0), Vector2(13, 1), Color("552f32"), 13.0)
		draw_circle(Vector2(17, 1), 7.0, Color("704047"))
		return
	var moving := velocity.length_squared() > 4.0
	var stride := sin(animation_time * 7.0) * 4.0 if moving else sin(animation_time * 2.0) * 1.2
	var lunge := 5.0 if state == "ATTACK" else 0.0
	draw_ellipse(Vector2(5, 4), 16.0, 7.0, Color(0, 0, 0, 0.45))
	draw_line(Vector2(-5, 0), Vector2(-6 + stride, 8), Color("261b1d"), 6.0)
	draw_line(Vector2(5, 0), Vector2(7 - stride, 8), Color("261b1d"), 6.0)
	draw_circle(Vector2(0, -10), 11.0, Color("321f24"))
	draw_circle(Vector2(0, -12), 9.5, Color("8d3f49"))
	draw_circle(Vector2(0, -27), 7.0, Color("8da079"))
	draw_line(Vector2(-5, -13), Vector2(-13, -4) + facing * lunge, Color("78515a"), 5.0)
	draw_line(Vector2(5, -13), Vector2(14, -5) + facing * lunge, Color("78515a"), 5.0)
	draw_circle(Vector2(-2, -29), 1.4, Color("d9df9a"))
	draw_circle(Vector2(3, -29), 1.4, Color("d9df9a"))
	if hp < 30:
		draw_rect(Rect2(-13, -40, 26, 4), Color("321919"), true)
		draw_rect(Rect2(-13, -40, 26.0 * hp / 30.0, 4), Color("ce5656"), true)
