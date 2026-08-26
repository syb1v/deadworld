extends SceneTree

const DirectionalSet = preload("res://scripts/entities2d/DirectionalSpriteSet.gd")

func _init() -> void:
	_assert(DirectionalSet.sector_for_vector(Vector2.UP) == &"N", "up maps to north")
	_assert(DirectionalSet.sector_for_vector(Vector2.RIGHT) == &"E", "right maps to east")
	_assert(DirectionalSet.sector_for_vector(Vector2.DOWN) == &"S", "down maps to south")
	_assert(DirectionalSet.sector_for_vector(Vector2.LEFT) == &"W", "left maps to west")
	_assert(DirectionalSet.sector_for_vector(Vector2(1, -1)) == &"NE", "diagonal maps to northeast")
	_assert(DirectionalSet.sector_for_vector(Vector2.ZERO) == &"S", "zero has stable south fallback")
	_assert(DirectionalSet.frame_index(&"NW", 2, 6) == 23, "atlas frame uses row-major direction order")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Directional sprite test failed: %s" % message)
	quit(1)
