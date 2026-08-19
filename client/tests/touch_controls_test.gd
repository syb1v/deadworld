extends SceneTree

const TouchControlsScript = preload("res://scripts/ui/TouchControls.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controls := Control.new()
	controls.set_script(TouchControlsScript)
	root.add_child(controls)
	controls.size = Vector2(1280, 720)
	controls._update_layout()
	var attacks := [0]
	controls.attack_pressed.connect(func(): attacks[0] += 1)

	controls.aim_touch = 7
	controls.aim_origin = Vector2(1050, 580)
	controls._input(_drag(7, controls.aim_origin + Vector2(controls.stick_radius, 0)))
	_assert(attacks[0] == 1, "outer ring emits one attack")
	controls._input(_drag(7, controls.aim_origin + Vector2(controls.stick_radius, 0)))
	_assert(attacks[0] == 1, "holding the outer ring does not repeat")
	controls._input(_drag(7, controls.aim_origin + Vector2(controls.stick_radius * 0.5, 0)))
	controls._input(_drag(7, controls.aim_origin + Vector2(controls.stick_radius, 0)))
	_assert(attacks[0] == 2, "returning inward rearms the next attack")
	quit()

func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("TouchControls test failed: %s" % message)
	quit(1)
