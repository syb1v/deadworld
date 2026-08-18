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
	var lift := Vector2(0, -4)
	draw_circle(Vector2(3, 4), 10.0, Color(0, 0, 0, 0.34))
	if definition_id == "baseball_bat":
		draw_line(Vector2(-14, 8) + lift, Vector2(14, -8) + lift, Color("37261b"), 9.0)
		draw_line(Vector2(-14, 8) + lift, Vector2(14, -8) + lift, Color("d49852"), 6.0)
	elif definition_id == "pistol":
		draw_rect(Rect2(-13, -10, 24, 11), Color("292e2d"), true)
		draw_rect(Rect2(-11, -8, 21, 7), Color("b7bdba"), true)
		draw_rect(Rect2(1, -1, 8, 12), Color("555e5b"), true)
	elif definition_id == "pistol_ammo":
		for offset in [-7, 0, 7]:
			draw_rect(Rect2(offset - 2, -13, 5, 16), Color("d5ad42"), true)
			draw_circle(Vector2(offset + 0.5, -13), 2.5, Color("f1da77"))
	else:
		draw_rect(Rect2(-9, -12, 18, 17), Color("765d35"), true)
		draw_rect(Rect2(-7, -10, 14, 13), Color("d1b05d"), true)
	var quantity_text := " x%d" % quantity if quantity > 1 else ""
	draw_rect(Rect2(-55, -30, 110, 16), Color(0.03, 0.04, 0.03, 0.72), true)
	draw_string(ThemeDB.fallback_font, Vector2(-55, -18), "%s%s" % [ITEM_NAMES.get(definition_id, definition_id), quantity_text], HORIZONTAL_ALIGNMENT_CENTER, 110, 11, Color("f8e9a6"))
