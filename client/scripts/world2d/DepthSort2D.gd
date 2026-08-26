extends RefCounted
class_name DepthSort2D

## Stable screen-depth key for 2.5D entities.
## Keep the value inside Godot's CanvasItem z-index range even on the expanded map.
static func sort_key(world_position: Vector2, stable_id: String) -> int:
	var y_key := int(round(world_position.y))
	var tie_breaker: int = absi(stable_id.hash()) % 2
	return clampi(y_key + tie_breaker, -4096, 4096)

static func apply(node: Node2D, stable_id: String) -> void:
	node.z_index = sort_key(node.position, stable_id)
