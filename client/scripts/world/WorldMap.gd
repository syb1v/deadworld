extends Node2D

## Отрисовка мира Project Deadworld.
##
## Мир строится из тайловых поверхностей и объёмных стен с изометрическим
## скосом. Задача — читаемость: игрок должен с одного взгляда понимать,
## где пол, где стена, где проход и где заканчивается безопасная зона.
##
## Геометрия берётся из client/data/world_map.json — того же файла, который
## использует сервер для коллизий. Здесь мы только отображаем её; никакие
## визуальные правки не меняют игровые границы.

const Palette = preload("res://scripts/data/Palette.gd")
const MAP: Dictionary = preload("res://data/world_map.json").data

const TILE := 64.0
## Высота фальш-объёма стены. Даёт изометрическое ощущение без смены
## системы координат: сервер по-прежнему работает в плоских координатах.
const WALL_HEIGHT := 22.0

var _surfaces: Dictionary = {}
var _ground: Texture2D = null

func _ready() -> void:
	z_index = -100
	_surfaces = {
		"asphalt": load("res://assets/generated/surfaces/asphalt.png"),
		"concrete": load("res://assets/generated/surfaces/concrete.png"),
		"soil": load("res://assets/generated/surfaces/soil.png"),
		"grass": load("res://assets/generated/surfaces/grass.png"),
		"wood": load("res://assets/generated/surfaces/wood.png"),
		"tile_clinic": load("res://assets/generated/surfaces/tile_clinic.png")
	}
	_ground = _surfaces["soil"]
	queue_redraw()

func _draw() -> void:
	var bounds: Dictionary = MAP.bounds
	var world_rect := Rect2(bounds.x, bounds.y, bounds.width, bounds.height)

	_draw_void(world_rect)
	_draw_ground(world_rect)
	_draw_roads(world_rect)
	for area in MAP.areas:
		_draw_area(area)
	_draw_debris(world_rect)
	_draw_district_landmarks(world_rect)
	for wall in MAP.walls:
		_draw_wall(Rect2(wall.x, wall.y, wall.width, wall.height))
	_draw_boundary(world_rect)

## Пустота за границами мира: камера может подойти к краю вплотную.
func _draw_void(world_rect: Rect2) -> void:
	var margin := 400.0
	draw_rect(Rect2(world_rect.position - Vector2(margin, margin),
		world_rect.size + Vector2(margin, margin) * 2.0), Palette.VOID, true)

## Базовый грунт: тайл земли по всей карте.
func _draw_ground(world_rect: Rect2) -> void:
	_draw_tiled(world_rect, _ground, Palette.SOIL)
	# Пятна сухой травы разбивают однородность.
	var seed_base := 7717
	for index in range(48):
		var px := world_rect.position.x + noise(seed_base + index * 13) * world_rect.size.x
		var py := world_rect.position.y + noise(seed_base + index * 29) * world_rect.size.y
		var radius := 26.0 + noise(seed_base + index * 41) * 46.0
		draw_circle(Vector2(px, py), radius, Color(Palette.GRASS_DEAD, 0.30))

## Дороги: связывают зоны и задают направление движения по карте.
func _draw_roads(world_rect: Rect2) -> void:
	var roads: Array[Rect2] = []
	for fraction: float in [1.0 / 3.0, 2.0 / 3.0]:
		var road_y: float = world_rect.position.y + world_rect.size.y * fraction
		var road_x: float = world_rect.position.x + world_rect.size.x * fraction
		roads.append(Rect2(world_rect.position.x, road_y - 46.0, world_rect.size.x, 92.0))
		roads.append(Rect2(road_x - 44.0, world_rect.position.y, 88.0, world_rect.size.y))
	for road in roads:
		_draw_tiled(road, _surfaces["asphalt"], Palette.ASPHALT)
		draw_rect(road, Color(Palette.VOID, 0.18), false, 2.0)

## Зона: пол помещения со своей поверхностью и мягкой границей.
func _draw_area(area: Dictionary) -> void:
	var rect := Rect2(area.x, area.y, area.width, area.height)
	var surface_name: String = area.get("surface", "concrete")
	var texture: Texture2D = _surfaces.get(surface_name, _surfaces["concrete"])
	var tint: Color = Color(area.get("color", "3a3c39"))

	_draw_tiled(rect, texture, Palette.CONCRETE)
	# Лёгкий оттенок зоны поверх тайла: помещения различимы, но не пёстрые.
	draw_rect(rect, Color(tint, 0.14), true)
	# Внутренняя тень по периметру: пол «проседает» внутрь стен.
	draw_rect(rect, Color(Palette.VOID, 0.30), false, 6.0)
	draw_rect(rect.grow(-3.0), Color(Palette.VOID, 0.14), false, 3.0)

## Мусор и следы: мир должен выглядеть обжитым и заброшенным.
func _draw_debris(world_rect: Rect2) -> void:
	for index in range(420):
		var seed_value := 5100 + index * 7
		var px := world_rect.position.x + noise(seed_value) * world_rect.size.x
		var py := world_rect.position.y + noise(seed_value + 3) * world_rect.size.y
		var kind := int(noise(seed_value + 11) * 3.0)
		var point := Vector2(px, py)
		match kind:
			0:
				var length := 5.0 + noise(seed_value + 17) * 9.0
				var angle := noise(seed_value + 23) * TAU
				draw_line(point, point + Vector2(cos(angle), sin(angle)) * length,
					Color(Palette.WALL_EDGE, 0.34), 1.6)
			1:
				draw_circle(point, 1.6 + noise(seed_value + 31) * 2.4,
					Color(Palette.CONCRETE_DARK, 0.5))
			_:
				draw_rect(Rect2(point, Vector2(3.0, 2.0) * (1.0 + noise(seed_value + 37))),
					Color(Palette.RUST, 0.26), true)

func _draw_district_landmarks(world_rect: Rect2) -> void:
	var district_width := world_rect.size.x / 3.0
	var district_height := world_rect.size.y / 3.0
	for index in range(9):
		var column := index % 3
		var row := index / 3
		var origin := world_rect.position + Vector2(column * district_width, row * district_height)
		var center := origin + Vector2(district_width * 0.5, district_height * 0.5)
		var accent: Color = [Palette.UI_OK, Palette.WALL_TRIM, Palette.METAL, Palette.RUST, Palette.UI_ACCENT][index % 5]
		# Each district gets a landmark silhouette. These remain part of the
		# static map draw, avoiding hundreds of independent decorative nodes.
		draw_rect(Rect2(center - Vector2(34, 25), Vector2(68, 50)), Color(Palette.VOID, 0.22), true)
		draw_rect(Rect2(center - Vector2(28, 19), Vector2(56, 38)), Color(accent, 0.22), true)
		draw_line(center + Vector2(-26, 12), center + Vector2(26, 12), Color(accent, 0.62), 3.0)
		draw_circle(center + Vector2(0, -4), 5.0 + noise(index * 101) * 4.0, Color(accent, 0.62))

## Стена с фальш-объёмом: тень, боковая грань, освещённый верх.
## Порядок отрисовки важен — он и создаёт ощущение высоты.
func _draw_wall(rect: Rect2) -> void:
	# 1. Тень на полу, смещённая по направлению света.
	draw_rect(Rect2(rect.position + Vector2(6.0, 9.0), rect.size), Palette.SHADOW, true)
	# 2. Фронтальная грань — то, что видно «сбоку».
	draw_rect(rect, Palette.WALL_FACE, true)
	# 3. Верхняя грань, приподнятая вверх.
	var top := Rect2(rect.position - Vector2(0.0, WALL_HEIGHT), rect.size)
	draw_rect(top, Palette.WALL_TOP, true)
	# 4. Кромка сверху ловит свет.
	draw_line(top.position, Vector2(top.end.x, top.position.y), Palette.WALL_TRIM, 2.0)
	# 5. Стык верха и фронта — самая тёмная линия, читается как ребро.
	draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y),
		Palette.WALL_EDGE, 2.0)
	# 6. Общий контур.
	draw_rect(Rect2(top.position, Vector2(rect.size.x, rect.size.y + WALL_HEIGHT)),
		Palette.WALL_EDGE, false, 1.5)
	_draw_wall_wear(top)

## Потёртости на верхней грани: стены не выглядят пластиковыми.
func _draw_wall_wear(top: Rect2) -> void:
	var steps := int(top.size.x / 24.0)
	for index in range(steps):
		var seed_value := int(top.position.x * 3.0 + top.position.y * 7.0) + index * 31
		if noise(seed_value) < 0.55:
			continue
		var px := top.position.x + index * 24.0 + noise(seed_value + 5) * 12.0
		draw_line(Vector2(px, top.position.y + 2.0), Vector2(px, top.end.y - 2.0),
			Color(Palette.WALL_EDGE, 0.22), 1.0)

## Граница мира: жёлтая аварийная лента.
func _draw_boundary(world_rect: Rect2) -> void:
	draw_rect(world_rect, Color(Palette.UI_ACCENT, 0.34), false, 3.0)
	var step := 34.0
	var x := world_rect.position.x
	while x < world_rect.end.x:
		draw_line(Vector2(x, world_rect.position.y), Vector2(x + 16.0, world_rect.position.y),
			Color(Palette.UI_WARN, 0.42), 3.0)
		draw_line(Vector2(x, world_rect.end.y), Vector2(x + 16.0, world_rect.end.y),
			Color(Palette.UI_WARN, 0.42), 3.0)
		x += step

## Замощение прямоугольника текстурой с обрезкой по краям.
func _draw_tiled(rect: Rect2, texture: Texture2D, fallback: Color) -> void:
	if texture == null:
		draw_rect(rect, fallback, true)
		return
	var columns := int(ceil(rect.size.x / TILE))
	var rows := int(ceil(rect.size.y / TILE))
	for row in range(rows):
		for column in range(columns):
			var origin := rect.position + Vector2(column * TILE, row * TILE)
			var size := Vector2(
				minf(TILE, rect.end.x - origin.x),
				minf(TILE, rect.end.y - origin.y)
			)
			if size.x <= 0.0 or size.y <= 0.0:
				continue
			draw_texture_rect_region(texture, Rect2(origin, size), Rect2(Vector2.ZERO, size))

## Детерминированный шум: одинаковая карта у всех игроков и между кадрами.
static func noise(seed_value: int) -> float:
	var value := (seed_value * 2654435761) % 4294967296
	value = (value ^ (value >> 13)) * 1274126177
	return float(absi(value) % 10000) / 10000.0
