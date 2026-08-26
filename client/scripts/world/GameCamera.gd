extends Camera2D

## Игровая камера Project Deadworld.
##
## Задачи:
##  - держать игрока в кадре, но не показывать весь мир сразу;
##  - смещать взгляд в сторону прицела, чтобы игрок видел, куда стреляет;
##  - не выпускать кадр за границы мира;
##  - подбирать зум под платформу: на телефоне нужен более крупный масштаб,
##    иначе персонаж и предметы становятся нечитаемыми.
##
## Камера — чисто презентационная. Она не влияет на серверные координаты,
## коллизии и попадания: сервер по-прежнему единственный источник истины.

const WORLD_MAP: Dictionary = preload("res://data/world_map.json").data

## Насколько сильно кадр уводится в сторону прицела, в пикселях.
const AIM_LEAD := 78.0
## Скорость слежения. Достаточно быстрая, чтобы не отставать при беге,
## и достаточно мягкая, чтобы не дёргаться от сетевых поправок.
const FOLLOW_RESPONSE := 9.0
const AIM_RESPONSE := 4.0

## Зум подбирается так, чтобы по вертикали помещалось примерно
## столько игровых пикселей, сколько нужно для читаемости.
const DESKTOP_VIEW_HEIGHT := 520.0
const MOBILE_VIEW_HEIGHT := 430.0

var _aim_offset := Vector2.ZERO
var _target: Node2D = null
var _shake_strength := 0.0
var _shake_time := 0.0

func _ready() -> void:
	position_smoothing_enabled = false
	_apply_zoom()
	get_viewport().size_changed.connect(_apply_zoom)

func set_target(node: Node2D) -> void:
	_target = node
	if node != null:
		global_position = node.global_position
		_clamp_to_world()

## Короткая тряска для отдачи и получения урона.
func shake(strength: float, duration: float = 0.18) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)

func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var desired_aim := Vector2.ZERO
	var world := get_parent()
	if world != null and "current_aim" in world:
		desired_aim = world.current_aim * AIM_LEAD
	_aim_offset = _aim_offset.lerp(desired_aim, 1.0 - exp(-AIM_RESPONSE * delta))

	var goal := _target.global_position + _aim_offset
	global_position = global_position.lerp(goal, 1.0 - exp(-FOLLOW_RESPONSE * delta))

	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var falloff := _shake_time / 0.18
		global_position += Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * _shake_strength * falloff
		if _shake_time <= 0.0:
			_shake_strength = 0.0

	_clamp_to_world()

## Не даём камере показать пустоту за пределами мира.
## Если мир по какой-то оси меньше кадра — центрируем по этой оси.
func _clamp_to_world() -> void:
	var bounds: Dictionary = WORLD_MAP.bounds
	var half := get_viewport_rect().size * 0.5 / zoom
	var min_x: float = bounds.x + half.x
	var max_x: float = bounds.x + bounds.width - half.x
	var min_y: float = bounds.y + half.y
	var max_y: float = bounds.y + bounds.height - half.y

	global_position.x = (bounds.x + bounds.width * 0.5) if min_x > max_x else clampf(global_position.x, min_x, max_x)
	global_position.y = (bounds.y + bounds.height * 0.5) if min_y > max_y else clampf(global_position.y, min_y, max_y)

func _apply_zoom() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y <= 0.0:
		return
	var mobile := OS.has_feature("mobile") or OS.get_name() in ["iOS", "Android"] or OS.get_cmdline_user_args().has("--touch-controls")
	var view_height := MOBILE_VIEW_HEIGHT if mobile else DESKTOP_VIEW_HEIGHT
	var factor := viewport_size.y / view_height
	zoom = Vector2(factor, factor)
	_clamp_to_world()
