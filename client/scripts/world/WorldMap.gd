extends Node2D

const MAP: Dictionary = preload("res://data/world_map.json").data

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("17211f"))
	for area in MAP.areas:
		var rect := Rect2(area.x, area.y, area.width, area.height)
		draw_rect(rect, Color(area.color), true)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 26), area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d7ded5"))
	for wall in MAP.walls:
		draw_rect(Rect2(wall.x, wall.y, wall.width, wall.height), Color("b3aa92"), true)
		draw_rect(Rect2(wall.x, wall.y, wall.width, wall.height), Color("302f2c"), false, 2.0)
	var bounds: Dictionary = MAP.bounds
	draw_rect(Rect2(bounds.x, bounds.y, bounds.width, bounds.height), Color("c6b98d"), false, 4.0)
