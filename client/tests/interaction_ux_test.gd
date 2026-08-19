extends SceneTree

const InteractionTarget = preload("res://scripts/ui/InteractionTarget.gd")

func _init() -> void:
	var nearest := InteractionTarget.nearest([
		{"kind": "world_item", "id": "item:far", "distance": 90.0},
		{"kind": "container", "id": "container:near", "distance": 12.0}
	])
	_assert(nearest.id == "container:near", "nearest container wins over a farther item")
	nearest = InteractionTarget.nearest([
		{"kind": "world_item", "id": "item:b", "distance": 20.0},
		{"kind": "world_item", "id": "item:a", "distance": 20.0}
	])
	_assert(nearest.id == "item:a", "equal-distance selection is deterministic")
	_assert(InteractionTarget.nearest([]).is_empty(), "empty candidates have no target")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Interaction UX test failed: %s" % message)
	quit(1)
