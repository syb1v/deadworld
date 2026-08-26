extends Control

## Хотбар: восемь слотов инвентаря с иконками.
##
## Заменяет прежний текстовый список. Игрок должен понимать своё
## снаряжение боковым зрением во время боя, а чтение строк этого не даёт.
##
## Отображает только то, что прислал сервер в INVENTORY_SNAPSHOT.
## Никакой локальной модели инвентаря здесь нет.

const Palette = preload("res://scripts/data/Palette.gd")
const ItemIcons = preload("res://scripts/data/ItemIcons.gd")

const SLOTS := 8

signal slot_selected(index: int)

var _items: Array = []
var _selected_id := ""
var _slot_texture: Texture2D = null
var _slot_active_texture: Texture2D = null
var _slot_size := 54.0
var _gap := 6.0

func _ready() -> void:
	_slot_texture = load("res://assets/generated/ui/slot.png")
	_slot_active_texture = load("res://assets/generated/ui/slot_active.png")
	mouse_filter = Control.MOUSE_FILTER_PASS

## Размер слота подстраивается под экран: на телефоне слот должен
## оставаться пригодным для пальца.
func configure(slot_size: float, gap: float) -> void:
	_slot_size = slot_size
	_gap = gap
	custom_minimum_size = Vector2(SLOTS * slot_size + (SLOTS - 1) * gap, slot_size)
	size = custom_minimum_size
	queue_redraw()

func set_inventory(items: Array, selected_id: String) -> void:
	_items = items
	_selected_id = selected_id
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	# Тап по слоту выбирает его: на телефоне это основной способ смены оружия.
	if event is InputEventScreenTouch and event.pressed:
		_select_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_at(event.position)

func _select_at(local_position: Vector2) -> void:
	var step := _slot_size + _gap
	var index := int(local_position.x / step)
	if index >= 0 and index < SLOTS and index < _items.size():
		slot_selected.emit(index)
		accept_event()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for index in range(SLOTS):
		var origin := Vector2(index * (_slot_size + _gap), 0.0)
		var rect := Rect2(origin, Vector2(_slot_size, _slot_size))
		var item: Dictionary = _items[index] if index < _items.size() else {}
		var is_selected: bool = not item.is_empty() and item.get("id", "") == _selected_id

		var texture := _slot_active_texture if is_selected else _slot_texture
		if texture != null:
			draw_texture_rect(texture, rect, false)
		else:
			draw_rect(rect, Palette.UI_BG, true)
			draw_rect(rect, Palette.UI_ACCENT if is_selected else Palette.UI_BORDER, false, 1.5)

		# Номер слота: соответствие клавишам 1-8 на десктопе.
		draw_string(font, origin + Vector2(4, 13), str(index + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Palette.UI_ACCENT if is_selected else Palette.UI_TEXT_DIM)

		if item.is_empty():
			continue

		var icon := ItemIcons.get_icon(item.get("definitionId", ""))
		if icon != null:
			var padding := _slot_size * 0.16
			draw_texture_rect(icon,
				Rect2(origin + Vector2(padding, padding),
					Vector2(_slot_size - padding * 2.0, _slot_size - padding * 2.0)), false)

		# Количество в стаке.
		var quantity := int(item.get("quantity", 1))
		if quantity > 1:
			var text := str(quantity)
			draw_string(font, origin + Vector2(_slot_size - 4, _slot_size - 5), text,
				HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Palette.UI_TEXT)

		# Патроны в магазине оружия: критичная боевая информация.
		if item.get("definitionId", "") == "pistol":
			var magazine := int(item.get("magazineAmmo", 0))
			var color := Palette.UI_DANGER if magazine == 0 else Palette.AMMO
			draw_string(font, origin + Vector2(_slot_size - 4, 13), "%d/6" % magazine,
				HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, color)
