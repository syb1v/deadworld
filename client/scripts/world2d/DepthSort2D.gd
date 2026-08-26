extends RefCounted
class_name DepthSort2D

## Stable screen-depth key for 2.5D entities.
## The ID tie-breaker prevents two objects at the same Y from flickering.
static func sort_key(world_position: Vector2, stable_id: String) -> int:
	var y_key := int(round(world_position.y * 100.0))
	var hash_key: int = absi(stable_id.hash()) % 97
	return y_key * 100 + hash_key

static func apply(node: Node2D, stable_id: String) -> void:
	node.z_index = sort_key(node.position, stable_id)
