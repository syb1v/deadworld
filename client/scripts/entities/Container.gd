extends Node2D

var label := "Container"

func setup(state: Dictionary) -> void:
	position = Vector2(state.x, state.y)
	label = "Container v%d (%d)" % [state.version, state.items.size()]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-18, -14, 36, 28), Color("b88a3b"), true)
	draw_rect(Rect2(-18, -14, 36, 28), Color("f2cf75"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-48, -22), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 11, Color("f8e9a6"))
