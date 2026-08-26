extends Node2D

## Визуальный эффект подтверждённой сервером атаки.
##
## Эффект появляется только после ATTACK_EVENT: клиент не рисует попадание
## по локальному нажатию, иначе игрок видел бы выстрелы, которых сервер не
## принял.

const Palette = preload("res://scripts/data/Palette.gd")

var from := Vector2.ZERO
var to := Vector2.ZERO
var melee := false
var lifetime := 0.16
var _total := 0.16

func setup(start: Vector2, finish: Vector2, is_melee: bool) -> void:
	from = start
	to = finish
	melee = is_melee
	_total = 0.22 if is_melee else 0.16
	lifetime = _total
	z_index = 4000
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	var t := clampf(lifetime / _total, 0.0, 1.0)
	if melee:
		_draw_melee_arc(t)
	else:
		_draw_gunshot(t)

## Дуга удара: расширяется и гаснет, читается как замах.
func _draw_melee_arc(t: float) -> void:
	var angle := (to - from).angle()
	var spread := 0.55 + (1.0 - t) * 0.35
	var radius := 34.0 + (1.0 - t) * 12.0
	draw_arc(from, radius, angle - spread, angle + spread, 20,
		Color(Palette.UI_TEXT, t * 0.75), 4.0)
	draw_arc(from, radius - 5.0, angle - spread * 0.7, angle + spread * 0.7, 16,
		Color(Palette.UI_ACCENT, t * 0.5), 2.0)

## Выстрел: трассер и вспышка у ствола.
func _draw_gunshot(t: float) -> void:
	var direction := (to - from).normalized()
	draw_line(from, to, Color(Palette.LIGHT_WARM, t * 0.85), 2.4)
	draw_line(from, from + direction * 26.0, Color(Palette.UI_TEXT, t * 0.9), 3.4)
	# Дульная вспышка: короткая и яркая.
	var flash := t * t
	draw_circle(from + direction * 6.0, 7.0 * flash, Color(Palette.LIGHT_WARM, flash * 0.9))
	draw_circle(from + direction * 6.0, 3.5 * flash, Color(Palette.UI_TEXT, flash))
	# Точка попадания.
	draw_circle(to, 4.0 * t, Color(Palette.UI_WARN, t * 0.7))
