extends Node2D

## Атмосферный слой Project Deadworld.
##
## Реализует требование GDD §6: «динамический свет, ограниченная видимость».
## Смысл не в красоте, а в игровом напряжении — игрок не видит весь мир
## сразу и вынужден двигаться осторожно, ориентируясь на освещённые зоны.
##
## Реализация использует штатный 2D-light pipeline Godot:
##   CanvasModulate — затемняет всю сцену до «ночного» уровня;
##   PointLight2D   — возвращает свет вокруг игрока и в помещениях.
##
## Ранее здесь была самодельная схема на CanvasItemMaterial с BLEND_MODE_SUB.
## Она давала обратный эффект: SUB вычитает цвет, поэтому «свет» белым
## цветом делал сцену темнее. Штатные источники света корректны по модели
## и дешевле, так как освещение считает сам рендерер.
##
## gl_compatibility поддерживает canvas lights, поэтому решение работает
## на всех целевых платформах, включая Android и iOS.

const Palette = preload("res://scripts/data/Palette.gd")
const MAP: Dictionary = preload("res://data/world_map.json").data

## Радиус уверенной видимости вокруг игрока в мировых пикселях.
const VISION_RADIUS := 320.0
## Ночной уровень освещения. Не чёрный: силуэты и стены должны угадываться
## за пределами света, иначе игра становится неиграбельной на телефоне.
const NIGHT_LEVEL := Color(0.34, 0.36, 0.38)

var _falloff: Texture2D = null
var _player: Node2D = null
var _player_light: PointLight2D = null
var _area_lights: Array[PointLight2D] = []
var _time := 0.0

func _ready() -> void:
	_falloff = load("res://assets/generated/ui/light_falloff.png")

	var modulate_node := CanvasModulate.new()
	modulate_node.color = NIGHT_LEVEL
	add_child(modulate_node)

	_build_area_lights()
	_build_player_light()
	set_process(true)

func set_player(node: Node2D) -> void:
	_player = node
	if _player_light != null and node != null:
		_player_light.global_position = node.global_position

func _process(delta: float) -> void:
	_time += delta
	# Свет следует за игроком: зона видимости привязана к персонажу.
	if _player_light != null and _player != null and is_instance_valid(_player):
		_player_light.global_position = _player.global_position
	# Лёгкое мерцание помещений: мир ощущается живым, а не статичной картинкой.
	for index in range(_area_lights.size()):
		var light := _area_lights[index]
		var base: float = light.get_meta("base_energy", 0.7)
		var speed: float = light.get_meta("flicker_speed", 1.0)
		light.energy = base * (0.94 + sin(_time * speed) * 0.06)

## Источники света в помещениях: делают зоны ориентирами и дают цель,
## к которой можно двигаться в темноте.
func _build_area_lights() -> void:
	for area in MAP.areas:
		var rect := Rect2(area.x, area.y, area.width, area.height)
		var light := PointLight2D.new()
		light.texture = _falloff
		light.global_position = rect.get_center()
		# texture_scale переводит радиус в размер текстуры (256px исходник).
		light.texture_scale = maxf(rect.size.x, rect.size.y) / 200.0
		light.color = Palette.LIGHT_WARM
		light.energy = 0.85
		light.set_meta("base_energy", 0.85)
		light.set_meta("flicker_speed", 1.0 + float(int(area.x) % 7) * 0.3)
		add_child(light)
		_area_lights.append(light)

## Свет вокруг игрока: собственно «ограниченная видимость».
func _build_player_light() -> void:
	_player_light = PointLight2D.new()
	_player_light.texture = _falloff
	_player_light.texture_scale = VISION_RADIUS / 128.0
	_player_light.color = Palette.LIGHT_COLD
	_player_light.energy = 1.15
	add_child(_player_light)
