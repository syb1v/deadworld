extends Node2D

## Контейнер в мире (шкаф, ящик, стеллаж).
##
## Задача отрисовки: контейнер должен читаться как объект, в который можно
## заглянуть, и сразу показывать, пуст он или нет. Подпись выводится только
## когда игрок рядом — иначе карта превращается в свалку текста.

const Palette = preload("res://scripts/data/Palette.gd")
const DepthSort = preload("res://scripts/world2d/DepthSort2D.gd")

var item_count := 0
var highlighted := false
var _time := 0.0

func _ready() -> void:
	y_sort_enabled = true

func setup(state: Dictionary) -> void:
	position = Vector2(state.x, state.y)
	item_count = state.items.size()
	DepthSort.apply(self, str(state.get("id", "container")))
	queue_redraw()

## Подсветка активной цели взаимодействия. Вызывается миром, когда этот
## контейнер выбран как ближайшая цель.
func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	queue_redraw()

func _process(delta: float) -> void:
	if highlighted:
		_time += delta
		queue_redraw()

func _draw() -> void:
	# Тень.
	draw_ellipse_shape(Vector2(3, 12), 20.0, 6.0, Palette.SHADOW)

	# Корпус с изометрическим объёмом: передняя грань и приподнятая крышка.
	var body := PackedVector2Array([
		Vector2(-17, -6), Vector2(17, -6), Vector2(17, 12), Vector2(-17, 12)
	])
	draw_colored_polygon(body, Palette.RUST)
	# Крышка сверху, смещённая назад — даёт ощущение глубины.
	var lid := PackedVector2Array([
		Vector2(-17, -6), Vector2(-11, -14), Vector2(21, -14), Vector2(17, -6)
	])
	draw_colored_polygon(lid, Palette.RUST_LIGHT)
	# Правый бок в тени.
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, -6), Vector2(21, -14), Vector2(21, 5), Vector2(17, 12)
	]), Palette.shade(Palette.RUST, 0.3))

	# Металлические стяжки.
	draw_line(Vector2(-17, -6), Vector2(17, -6), Palette.shade(Palette.METAL, 0.1), 2.0)
	draw_line(Vector2(-17, 4), Vector2(17, 4), Palette.shade(Palette.RUST, 0.35), 1.6)
	# Замок: подсказывает, что объект открывается.
	draw_rect(Rect2(-3, -5, 6, 7), Palette.METAL, true)
	draw_rect(Rect2(-3, -5, 6, 7), Palette.WALL_EDGE, false, 1.0)

	draw_rect(Rect2(-17, -14, 38, 26), Palette.WALL_EDGE, false, 1.5)

	# Пустой контейнер визуально «выключен»: не тратим внимание игрока.
	if item_count == 0:
		draw_rect(Rect2(-17, -14, 38, 26), Color(Palette.VOID, 0.35), true)

	if highlighted:
		_draw_highlight()

## Подсветка цели: пульсирующая рамка и подпись с содержимым.
func _draw_highlight() -> void:
	var pulse: float = 0.55 + absf(sin(_time * 3.4)) * 0.35
	draw_rect(Rect2(-20, -17, 44, 32), Color(Palette.UI_ACCENT, pulse), false, 2.0)
	var text := "ПУСТО" if item_count == 0 else "ПРЕДМЕТОВ: %d" % item_count
	var font := ThemeDB.fallback_font
	var width := 104.0
	draw_rect(Rect2(-width * 0.5, -36, width, 15), Color(Palette.UI_BG, 0.85), true)
	draw_rect(Rect2(-width * 0.5, -36, width, 15), Color(Palette.UI_BORDER, 0.9), false, 1.0)
	draw_string(font, Vector2(-width * 0.5, -25), text,
		HORIZONTAL_ALIGNMENT_CENTER, width, 10,
		Palette.UI_TEXT_DIM if item_count == 0 else Palette.UI_ACCENT)

func draw_ellipse_shape(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
	draw_circle(Vector2.ZERO, radius_x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
