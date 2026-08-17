extends Node2D

var definition_id := "item"
var quantity: int = 1
const ITEM_NAMES: Dictionary = preload("res://data/item_names_ru.json").data

func setup(state: Dictionary) -> void:
	definition_id = state.definitionId
	var state_quantity = state.get("quantity")
	quantity = state_quantity if state_quantity != null else 1
	position = Vector2(state.x, state.y)
	queue_redraw()

func _draw() -> void:
	if definition_id == "baseball_bat":
		draw_line(Vector2(-14, 8), Vector2(14, -8), Color("d49852"), 7.0)
	elif definition_id == "pistol":
		draw_rect(Rect2(-12, -7, 22, 10), Color("b7bdba"), true)
		draw_rect(Rect2(2, 1, 7, 12), Color("777f7b"), true)
	elif definition_id == "pistol_ammo":
		draw_rect(Rect2(-3, -9, 6, 18), Color("e7c95b"), true)
	else:
		draw_circle(Vector2.ZERO, 10.0, Color("e7c95b"))
	var quantity_text := " x%d" % quantity if quantity > 1 else ""
	draw_string(ThemeDB.fallback_font, Vector2(-55, -18), "%s%s" % [ITEM_NAMES.get(definition_id, definition_id), quantity_text], HORIZONTAL_ALIGNMENT_CENTER, 110, 11, Color("f8e9a6"))
