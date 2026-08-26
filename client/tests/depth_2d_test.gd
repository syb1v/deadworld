extends SceneTree

const DepthSort = preload("res://scripts/world2d/DepthSort2D.gd")
const MaterialVariant = preload("res://scripts/world2d/MaterialVariant2D.gd")

func _init() -> void:
	_assert(DepthSort.sort_key(Vector2(10, 20), "a") < DepthSort.sort_key(Vector2(10, 21), "a"), "lower objects render in front")
	_assert(DepthSort.sort_key(Vector2(10, 2064), "a") <= 4096, "expanded world stays inside Godot z-index range")
	_assert(DepthSort.sort_key(Vector2(10, 2064), "a") >= -4096, "negative z-index bound is respected")
	_assert(DepthSort.sort_key(Vector2(10, 20), "a") != DepthSort.sort_key(Vector2(10, 20), "b"), "same-depth IDs are stable")
	_assert(MaterialVariant.material_for(&"clinic", 0) == &"tile_clinic", "clinic selects clinic material family")
	_assert(MaterialVariant.material_for(&"unknown", 0) == &"concrete", "unknown districts use safe fallback")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("2D depth test failed: %s" % message)
	quit(1)
