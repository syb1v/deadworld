extends Node2D

## Отрисовка зомби.
##
## Ключевое требование — мгновенно отличать зомби от игрока и понимать
## его состояние: бредёт, заметил, атакует. Силуэт намеренно сутулый и
## асимметричный, чтобы читаться даже на краю светового пятна.
##
## Состояние приходит от сервера; клиент только отображает.

const Palette = preload("res://scripts/data/Palette.gd")
const LayeredCharacterScript = preload("res://scripts/entities2d/LayeredCharacter.gd")

var target_position := Vector2.ZERO
var state := "IDLE"
var hp := 30
var velocity := Vector2.ZERO
var snapshot_age := 0.0
var animation_time := 0.0
var facing := Vector2.LEFT
var _layered_character: Node2D = null
var _use_directional_sprites := false

func _ready() -> void:
	y_sort_enabled = true
	_use_directional_sprites = "--2d25d" in OS.get_cmdline_user_args() or _has_profile_argument()
	if _use_directional_sprites:
		_layered_character = LayeredCharacterScript.new()
		_layered_character.asset_id = "zombie"
		_layered_character.position = Vector2.ZERO
		add_child(_layered_character)
		_layered_character.z_index = 20
	# Разводим фазы анимации, иначе толпа движется синхронно как один организм.
	animation_time = float(get_instance_id() % 100) * 0.07
	queue_redraw()

func apply_snapshot(value: Dictionary) -> void:
	target_position = Vector2(value.x, value.y)
	state = value.state
	hp = value.hp
	velocity = Vector2(value.get("vx", 0.0), value.get("vy", 0.0))
	if velocity.length_squared() > 1.0: facing = velocity.normalized()
	if _layered_character != null:
		var visual_state: StringName = &"death" if state == "DEAD" else (&"attack" if state == "ATTACK" else (&"walk" if state == "CHASE" or velocity.length_squared() > 4.0 else &"idle"))
		_layered_character.apply_presentation(velocity, facing, visual_state)
	snapshot_age = 0.0
	if position == Vector2.ZERO:
		position = target_position
	queue_redraw()

func _process(delta: float) -> void:
	snapshot_age = minf(snapshot_age + delta, 0.1)
	animation_time += delta
	var presented_target := target_position + velocity * snapshot_age
	position = position.lerp(presented_target, 1.0 - exp(-11.0 * delta))
	z_index = int(position.y)
	queue_redraw()

func _draw() -> void:
	if _use_directional_sprites:
		return
	if state == "DEAD":
		_draw_corpse()
		return

	var moving := velocity.length_squared() > 4.0
	# Шаркающая походка: медленнее и рванее человеческой.
	var stride := sin(animation_time * 6.0) * 3.8 if moving else sin(animation_time * 1.6) * 1.0
	var lunge := 6.0 if state == "ATTACK" else 0.0
	var sway := sin(animation_time * 3.0) * 1.6

	draw_ellipse_shape(Vector2(3, 5), 14.0, 5.5, Palette.SHADOW)

	# Ноги.
	draw_line(Vector2(-4.5, 0), Vector2(-5.5 + stride, 9), Palette.shade(Palette.ZOMBIE_ROT, 0.45), 5.5)
	draw_line(Vector2(4.5, 0), Vector2(6.0 - stride, 9), Palette.shade(Palette.ZOMBIE_ROT, 0.45), 5.5)

	# Сутулый корпус со смещением: главное визуальное отличие от игрока.
	var torso := Vector2(sway * 0.5, -8)
	draw_circle(torso, 10.5, Palette.WALL_EDGE)
	draw_circle(torso, 9.0, Palette.ZOMBIE_FLESH)
	# Пятна разложения.
	draw_circle(torso + Vector2(3, 1), 3.2, Palette.shade(Palette.ZOMBIE_ROT, 0.2))
	draw_circle(torso + Vector2(-3.5, 2), 2.2, Palette.shade(Palette.ZOMBIE_ROT, 0.3))

	# Вытянутые руки: поза зомби, усиливается при атаке.
	var reach := facing * (10.0 + lunge)
	draw_line(torso + Vector2(-5, -3), torso + Vector2(-3, 2) + reach, Palette.ZOMBIE_ROT, 4.6)
	draw_line(torso + Vector2(5, -3), torso + Vector2(3, 4) + reach, Palette.ZOMBIE_ROT, 4.6)

	# Голова, наклонённая вперёд.
	var head := Vector2(sway + facing.x * 2.0, -23)
	draw_circle(head, 6.8, Palette.WALL_EDGE)
	draw_circle(head, 5.8, Palette.shade(Palette.ZOMBIE_FLESH, 0.12))

	# Глаза светятся только когда зомби заметил цель: это игровая
	# информация, а не украшение — игрок понимает, что его увидели.
	if state in ["CHASE", "ATTACK"]:
		var glow: float = 0.65 + absf(sin(animation_time * 5.0)) * 0.35
		var eye_offset := facing * 2.0
		draw_circle(head + Vector2(-2.2, -0.5) + eye_offset, 1.5, Color(Palette.UI_DANGER, glow))
		draw_circle(head + Vector2(2.2, -0.5) + eye_offset, 1.5, Color(Palette.UI_DANGER, glow))
	else:
		draw_circle(head + Vector2(-2.2, -0.5), 1.2, Palette.shade(Palette.ZOMBIE_DEAD, 0.2))
		draw_circle(head + Vector2(2.2, -0.5), 1.2, Palette.shade(Palette.ZOMBIE_DEAD, 0.2))

	if hp < 30:
		_draw_health_bar()

func _has_profile_argument() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			return true
	return false

func _draw_corpse() -> void:
	draw_ellipse_shape(Vector2(4, 4), 20.0, 7.5, Palette.SHADOW_SOFT)
	draw_ellipse_shape(Vector2(0, 3), 18.0, 6.5, Color(Palette.BLOOD, 0.5))
	draw_line(Vector2(-15, 0), Vector2(13, 1), Palette.ZOMBIE_DEAD, 12.0)
	draw_circle(Vector2(16, 1), 6.5, Palette.shade(Palette.ZOMBIE_FLESH, 0.4))

func _draw_health_bar() -> void:
	var width := 24.0
	var ratio := clampf(float(hp) / 30.0, 0.0, 1.0)
	var origin := Vector2(-width * 0.5, -36)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(width + 2, 5)), Palette.WALL_EDGE, true)
	draw_rect(Rect2(origin, Vector2(width, 3)), Palette.HEALTH_BG, true)
	draw_rect(Rect2(origin, Vector2(width * ratio, 3)), Palette.UI_DANGER, true)

func draw_ellipse_shape(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
	draw_circle(Vector2.ZERO, radius_x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
