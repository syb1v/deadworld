extends Label

var lifetime := 0.75

func setup(value: int, world_position: Vector2) -> void:
	text = "-%d" % value
	position = world_position - Vector2(24, 42)
	add_theme_color_override("font_color", Color("ff665c"))
	add_theme_color_override("font_outline_color", Color("301613"))
	add_theme_constant_override("outline_size", 4)
	add_theme_font_size_override("font_size", 22)

func _process(delta: float) -> void:
	lifetime -= delta
	position.y -= 34.0 * delta
	modulate.a = clampf(lifetime / 0.3, 0.0, 1.0)
	if lifetime <= 0.0:
		queue_free()
