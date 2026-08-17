extends Node2D

var definition_id := "item"

func setup(state: Dictionary) -> void:
	definition_id = state.definitionId
	position = Vector2(state.x, state.y)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color("e7c95b"))
	draw_string(ThemeDB.fallback_font, Vector2(-35, -16), definition_id, HORIZONTAL_ALIGNMENT_CENTER, 70, 11, Color("f8e9a6"))
