extends Node2D

var label := "Контейнер"

func setup(state: Dictionary) -> void:
	position = Vector2(state.x, state.y)
	label = "Контейнер · %d" % state.items.size()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-14, 5, 38, 18), Color(0, 0, 0, 0.35), true)
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -8), Vector2(18, -8), Vector2(18, 13), Vector2(-18, 13)]), Color("8d6631"))
	draw_colored_polygon(PackedVector2Array([Vector2(-18, -8), Vector2(-12, -15), Vector2(22, -15), Vector2(18, -8)]), Color("d0a657"))
	draw_line(Vector2(-18, -8), Vector2(18, -8), Color("f0cd79"), 2.0)
	draw_rect(Rect2(-3, -7, 7, 10), Color("d9c17c"), true)
	draw_rect(Rect2(-48, -31, 96, 16), Color(0.03, 0.04, 0.03, 0.72), true)
	draw_string(ThemeDB.fallback_font, Vector2(-48, -19), label, HORIZONTAL_ALIGNMENT_CENTER, 96, 11, Color("f8e9a6"))
