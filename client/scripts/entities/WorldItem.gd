extends Node2D

## Предмет, лежащий в мире.
##
## Лут должен быть заметен, но не кричать: игрок замечает его по мягкому
## свечению и иконке. Подпись показывается только у ближайшей цели, иначе
## карта превращается в стену текста.

const Palette = preload("res://scripts/data/Palette.gd")
const ItemIcons = preload("res://scripts/data/ItemIcons.gd")
const ITEM_NAMES: Dictionary = preload("res://data/item_names_ru.json").data

const ICON_SIZE := 26.0

var definition_id := "item"
var quantity: int = 1
var highlighted := false
var _icon: Texture2D = null
var _time := 0.0

func _ready() -> void:
	y_sort_enabled = true
	_time = float(get_instance_id() % 100) * 0.06

func setup(state: Dictionary) -> void:
	definition_id = state.definitionId
	var state_quantity = state.get("quantity")
	quantity = state_quantity if state_quantity != null else 1
	position = Vector2(state.x, state.y)
	z_index = int(position.y)
	_icon = ItemIcons.get_icon(definition_id)
	queue_redraw()

func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Лёгкое покачивание: движение притягивает взгляд лучше статики.
	var hover := sin(_time * 2.0) * 1.5

	draw_ellipse_shape(Vector2(1, 9), 11.0, 4.0, Palette.SHADOW_SOFT)

	# Мягкое свечение под предметом: маркер «здесь есть лут».
	var glow: float = 0.14 + absf(sin(_time * 1.8)) * 0.08
	draw_circle(Vector2(0, 2 + hover), 15.0, Color(Palette.UI_ACCENT, glow))

	if _icon != null:
		var half := ICON_SIZE * 0.5
		draw_texture_rect(_icon,
			Rect2(Vector2(-half, -half + hover), Vector2(ICON_SIZE, ICON_SIZE)), false)
	else:
		draw_rect(Rect2(-8, -8 + hover, 16, 16), Palette.RUST, true)

	# Количество в стаке.
	if quantity > 1:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(4, 12 + hover), "x%d" % quantity,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.UI_ACCENT)

	if highlighted:
		_draw_highlight(hover)

func _draw_highlight(hover: float) -> void:
	var pulse: float = 0.55 + absf(sin(_time * 3.4)) * 0.35
	draw_arc(Vector2(0, hover), 18.0, 0.0, TAU, 24, Color(Palette.UI_ACCENT, pulse), 1.6)
	var name: String = ITEM_NAMES.get(definition_id, definition_id)
	var text := name if quantity <= 1 else "%s x%d" % [name, quantity]
	var font := ThemeDB.fallback_font
	var width := 116.0
	draw_rect(Rect2(-width * 0.5, -34, width, 15), Color(Palette.UI_BG, 0.85), true)
	draw_rect(Rect2(-width * 0.5, -34, width, 15), Color(Palette.UI_BORDER, 0.9), false, 1.0)
	draw_string(font, Vector2(-width * 0.5, -23), text,
		HORIZONTAL_ALIGNMENT_CENTER, width, 10, Palette.UI_ACCENT)

func draw_ellipse_shape(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
	draw_circle(Vector2.ZERO, radius_x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
