extends Node2D

## Отрисовка игрока.
##
## Читаемость важнее детализации: на телефоне персонаж занимает мало
## пикселей, поэтому силуэт, направление взгляда и состояние здоровья
## должны угадываться мгновенно.
##
## Позиция приходит от сервера. Здесь только сглаживание отображения:
## клиент не является источником истины для координат.

const Palette = preload("res://scripts/data/Palette.gd")
const LayeredCharacterScript = preload("res://scripts/entities2d/LayeredCharacter.gd")

var target_position := Vector2.ZERO
var is_local := false
var health := 100
var player_state := "idle"
var authoritative_velocity := Vector2.ZERO
var snapshot_age := 0.0
var animation_time := 0.0
var facing := Vector2.RIGHT
var _layered_character: Node2D = null
var _use_directional_sprites := false

func setup(local: bool) -> void:
	is_local = local
	_use_directional_sprites = "--2d25d" in OS.get_cmdline_user_args() or _has_profile_argument()
	if _use_directional_sprites:
		_layered_character = LayeredCharacterScript.new()
		_layered_character.asset_id = "survivor"
		_layered_character.position = Vector2.ZERO
		add_child(_layered_character)
		_layered_character.z_index = 20
		queue_redraw()
	# Сортировка по глубине: кто ниже на экране, тот ближе к зрителю.
	y_sort_enabled = true
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
	if _layered_character != null:
		var visual_state: StringName = &"death" if player_state == "dead" else (&"walk" if authoritative_velocity.length_squared() > 16.0 else &"idle")
		_layered_character.apply_presentation(authoritative_velocity, facing, visual_state)
	queue_redraw()

func _process(delta: float) -> void:
	snapshot_age = minf(snapshot_age + delta, 0.1)
	animation_time += delta
	var presented_target := target_position + authoritative_velocity * snapshot_age
	var distance := position.distance_to(presented_target)
	var response := 18.0 if distance > 24.0 else 12.0
	position = position.lerp(presented_target, 1.0 - exp(-response * delta))
	z_index = int(position.y)
	queue_redraw()

func set_facing(value: Vector2) -> void:
	if value.length_squared() > 0.01:
		facing = value.normalized()

func _has_profile_argument() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			return true
	return false

func _draw() -> void:
	if _use_directional_sprites:
		return
	if player_state == "dead":
		_draw_corpse()
		return

	var moving := authoritative_velocity.length_squared() > 16.0
	var stride := sin(animation_time * 10.0) * 3.6 if moving else 0.0
	var bob := absf(sin(animation_time * 10.0)) * 1.8 if moving else sin(animation_time * 2.2) * 0.6
	var body_color := Palette.PLAYER_LOCAL if is_local else Palette.PLAYER_REMOTE

	# Тень: привязывает фигуру к земле, без неё персонаж «парит».
	draw_ellipse_shape(Vector2(2, 5), 13.0, 5.5, Palette.SHADOW)

	# Ноги.
	draw_line(Vector2(-4.5, 0), Vector2(-4.5 + stride, 9), Palette.shade(body_color, 0.55), 5.5)
	draw_line(Vector2(4.5, 0), Vector2(4.5 - stride, 9), Palette.shade(body_color, 0.55), 5.5)

	# Корпус: тёмный контур + заливка. Контур даёт читаемость на любом фоне.
	var torso := Vector2(0, -9 - bob)
	draw_circle(torso, 10.0, Palette.WALL_EDGE)
	draw_circle(torso, 8.6, body_color)
	# Блик сверху: подсказывает направление света в сцене.
	draw_circle(torso + Vector2(-2, -2.5), 4.2, Palette.light(body_color, 0.16))

	# Рюкзак: силуэт выживальщика, а не абстрактного кружка.
	var back := torso - facing * 6.0
	draw_circle(back, 5.6, Palette.shade(Palette.PLAYER_REMOTE, 0.35))

	# Голова.
	var head := Vector2(0, -24 - bob)
	draw_circle(head, 6.4, Palette.WALL_EDGE)
	draw_circle(head, 5.4, Palette.SKIN)

	# Оружие/направление взгляда.
	var muzzle := torso + facing * 17.0
	draw_line(torso, muzzle, Palette.METAL, 3.4)
	draw_circle(muzzle, 1.8, Palette.shade(Palette.METAL, 0.3))

	if health < 100:
		_draw_health_bar()

	# Маркер своего персонажа: в общем мире важно не терять себя из виду.
	if is_local:
		var pulse: float = 0.4 + absf(sin(animation_time * 2.0)) * 0.2
		draw_arc(Vector2(0, 2), 19.0, 0.0, TAU, 28, Color(Palette.UI_ACCENT, pulse), 1.4)

func _draw_corpse() -> void:
	draw_ellipse_shape(Vector2(3, 3), 19.0, 7.0, Palette.SHADOW_SOFT)
	# Лужа крови: смерть должна читаться однозначно.
	draw_ellipse_shape(Vector2(0, 2), 16.0, 6.0, Color(Palette.BLOOD, 0.55))
	draw_line(Vector2(-13, 0), Vector2(13, 0), Palette.PLAYER_DEAD, 11.0)
	draw_circle(Vector2(15, 0), 6.0, Palette.shade(Palette.SKIN, 0.4))

func _draw_health_bar() -> void:
	var width := 26.0
	var ratio := clampf(float(health) / 100.0, 0.0, 1.0)
	var origin := Vector2(-width * 0.5, -37)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(width + 2, 5)), Palette.WALL_EDGE, true)
	draw_rect(Rect2(origin, Vector2(width, 3)), Palette.HEALTH_BG, true)
	draw_rect(Rect2(origin, Vector2(width * ratio, 3)), Palette.HEALTH, true)

## Эллипс для теней и луж. draw_circle со сжатием по вертикали даёт
## нужную «проекцию на пол» без отдельной текстуры.
func draw_ellipse_shape(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
	draw_circle(Vector2.ZERO, radius_x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
