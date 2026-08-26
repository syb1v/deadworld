extends SceneTree

const LayeredCharacter = preload("res://scripts/entities2d/LayeredCharacter.gd")

func _init() -> void:
	var survivor: Node2D = LayeredCharacter.new()
	survivor.asset_id = "survivor"
	root.add_child(survivor)
	survivor.apply_snapshot(Vector2(10, 20), Vector2.RIGHT, Vector2.RIGHT, &"walk")
	_assert(survivor.position == Vector2(10, 20), "snapshot sets presentation position")
	_assert(survivor.character_state == &"walk", "known state is selected")
	_assert(survivor.facing == Vector2.RIGHT, "aim direction is retained")
	var zombie: Node2D = LayeredCharacter.new()
	zombie.asset_id = "zombie"
	root.add_child(zombie)
	zombie.apply_presentation(Vector2.ZERO, Vector2.LEFT, &"attack")
	_assert(zombie.character_state == &"attack", "zombie attack state is supported")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Layered character test failed: %s" % message)
	quit(1)
