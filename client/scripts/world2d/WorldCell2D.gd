extends Node2D
class_name WorldCell2D

var cell_id := ""
var district_id: StringName = &"safehouse"
var proxy := false
var descriptor: Dictionary = {}

func setup(value: Dictionary, as_proxy := false) -> void:
	descriptor = value
	cell_id = str(value.get("id", ""))
	district_id = StringName(str(value.get("districtId", "safehouse")))
	proxy = as_proxy
	position = Vector2(str(value.get("x", 0)).to_float(), str(value.get("y", 0)).to_float())
	name = "Cell_%s%s" % [cell_id.replace(":", "_"), "_Proxy" if proxy else ""]
	queue_redraw()

func _draw() -> void:
	# Proxy cells are intentionally quiet: they preserve orientation without
	# competing with the fully loaded gameplay cell around the player.
	if proxy:
		draw_rect(Rect2(0, 0, 32, 32), Color(0.14, 0.2, 0.16, 0.1), true)
