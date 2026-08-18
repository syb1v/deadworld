extends Node2D

const MAP: Dictionary = preload("res://data/world_map.json").data

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("121a18"))
	for area in MAP.areas:
		var rect := Rect2(area.x, area.y, area.width, area.height)
		draw_rect(rect, Color(area.color), true)
		_draw_floor_detail(rect)
		draw_rect(Rect2(rect.position + Vector2(10, 8), Vector2(minf(180.0, rect.size.x - 20.0), 25)), Color(0.04, 0.06, 0.05, 0.58), true)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(17, 27), area.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e2e5dc"))
	for wall in MAP.walls:
		var rect := Rect2(wall.x, wall.y, wall.width, wall.height)
		draw_rect(Rect2(rect.position + Vector2(7, 9), rect.size), Color(0, 0, 0, 0.35), true)
		draw_rect(rect, Color("777568"), true)
		draw_rect(Rect2(rect.position - Vector2(0, 7), rect.size), Color("aaa891"), true)
		draw_line(rect.position - Vector2(0, 7), Vector2(rect.end.x, rect.position.y - 7), Color("d4cfb2"), 2.0)
		draw_line(Vector2(rect.position.x, rect.end.y - 7), rect.end, Color("46483f"), 3.0)
		draw_rect(Rect2(rect.position - Vector2(0, 7), rect.size), Color("292c28"), false, 2.0)
	var bounds: Dictionary = MAP.bounds
	draw_rect(Rect2(bounds.x, bounds.y, bounds.width, bounds.height), Color("c8bea0"), false, 4.0)

func _draw_floor_detail(rect: Rect2) -> void:
	var columns := maxi(1, int(rect.size.x / 88.0))
	var rows := maxi(1, int(rect.size.y / 72.0))
	for row in range(rows):
		for column in range(columns):
			var seed_value := int(rect.position.x * 3.0 + rect.position.y * 5.0 + column * 47 + row * 83)
			if seed_value % 3 != 0:
				continue
			var start := rect.position + Vector2(24 + column * 88 + seed_value % 19, 42 + row * 72 + seed_value % 13)
			var finish := start + Vector2(10 + seed_value % 9, -3 + seed_value % 7)
			draw_line(start, finish, Color(0.05, 0.07, 0.06, 0.24), 1.5)
