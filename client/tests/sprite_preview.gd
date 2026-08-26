extends Node2D

const LayeredCharacter = preload("res://scripts/entities2d/LayeredCharacter.gd")

func _ready() -> void:
	for index in range(8):
		var character: Node2D = LayeredCharacter.new()
		character.asset_id = "survivor"
		character.position = Vector2(120 + index * 150, 180)
		character.facing = Vector2.from_angle(float(index) * TAU / 8.0)
		character.character_state = &"idle"
		add_child(character)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 360), Color("111713"), true)
	for index in range(8):
		draw_string(ThemeDB.fallback_font, Vector2(72 + index * 150, 330), ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9e36b"))
