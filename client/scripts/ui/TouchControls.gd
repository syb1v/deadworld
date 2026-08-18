extends Control

signal attack_pressed
signal interact_pressed
signal reload_pressed
signal drop_pressed
signal pause_pressed
signal slot_pressed

var movement := Vector2.ZERO
var aim := Vector2.RIGHT
var move_touch := -1
var aim_touch := -1
var move_origin := Vector2.ZERO
var aim_origin := Vector2.ZERO
const STICK_RADIUS := 64.0
const BUTTONS := {
	"attack": Rect2(1120, 490, 120, 120),
	"interact": Rect2(985, 540, 105, 70),
	"reload": Rect2(1120, 400, 105, 65),
	"drop": Rect2(985, 450, 105, 65),
	"slot": Rect2(1120, 315, 105, 60),
	"pause": Rect2(1190, 25, 60, 52)
}

func _ready() -> void:
	set_process_input(true)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var action := _button_at(event.position)
			if not action.is_empty():
				_emit_action(action)
				get_viewport().set_input_as_handled()
				return
			if event.position.x < size.x * 0.45 and move_touch < 0:
				move_touch = event.index; move_origin = event.position; movement = Vector2.ZERO
			elif aim_touch < 0:
				aim_touch = event.index; aim_origin = event.position
		else:
			if event.index == move_touch: move_touch = -1; movement = Vector2.ZERO
			if event.index == aim_touch: aim_touch = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			movement = ((event.position - move_origin) / STICK_RADIUS).limit_length(1.0)
		elif event.index == aim_touch:
			var candidate: Vector2 = event.position - aim_origin
			if candidate.length_squared() > 16.0: aim = candidate.normalized()
		queue_redraw()

func _draw() -> void:
	var base := move_origin if move_touch >= 0 else Vector2(125, 585)
	draw_circle(base, STICK_RADIUS, Color(0.1, 0.14, 0.13, 0.65))
	draw_circle(base + movement * STICK_RADIUS, 28, Color(0.72, 0.78, 0.68, 0.8))
	for action in BUTTONS:
		var rect: Rect2 = BUTTONS[action]
		draw_rect(rect, Color(0.12, 0.15, 0.14, 0.78), true)
		draw_rect(rect, Color(0.72, 0.68, 0.52, 0.9), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, rect.size.y * 0.58), _label(action), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 16, Color.WHITE)

func _button_at(position: Vector2) -> String:
	for action in BUTTONS:
		if BUTTONS[action].has_point(position): return action
	return ""

func _emit_action(action: String) -> void:
	match action:
		"attack": attack_pressed.emit()
		"interact": interact_pressed.emit()
		"reload": reload_pressed.emit()
		"drop": drop_pressed.emit()
		"slot": slot_pressed.emit()
		"pause": pause_pressed.emit()

func _label(action: String) -> String:
	return { "attack": "ОГОНЬ", "interact": "ВЗЯТЬ", "reload": "R", "drop": "БРОСИТЬ", "slot": "СЛОТ", "pause": "II" }.get(action, action)
