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
var stick_radius := 64.0
var aim_amount := 0.0
var aim_attack_armed := true
var safe_rect := Rect2()
var buttons: Dictionary = {}
const FIRE_THRESHOLD := 0.9
const FIRE_RESET_THRESHOLD := 0.68

func _ready() -> void:
	set_process_input(true)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
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
			if event.position.x < safe_rect.get_center().x and move_touch < 0:
				move_touch = event.index; move_origin = _clamp_stick_origin(event.position); movement = Vector2.ZERO
			elif aim_touch < 0:
				aim_touch = event.index; aim_origin = _clamp_stick_origin(event.position); aim_amount = 0.0; aim_attack_armed = true
		else:
			if event.index == move_touch: move_touch = -1; movement = Vector2.ZERO
			if event.index == aim_touch: aim_touch = -1; aim_amount = 0.0; aim_attack_armed = true
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			movement = ((event.position - move_origin) / stick_radius).limit_length(1.0)
		elif event.index == aim_touch:
			var candidate: Vector2 = event.position - aim_origin
			aim_amount = clampf(candidate.length() / stick_radius, 0.0, 1.0)
			if candidate.length_squared() > 16.0: aim = candidate.normalized()
			if aim_attack_armed and aim_amount >= FIRE_THRESHOLD:
				aim_attack_armed = false
				attack_pressed.emit()
			elif not aim_attack_armed and aim_amount <= FIRE_RESET_THRESHOLD:
				aim_attack_armed = true
		queue_redraw()

func _draw() -> void:
	var move_base := move_origin if move_touch >= 0 else _default_stick_center(false)
	var aim_base := aim_origin if aim_touch >= 0 else _default_stick_center(true)
	draw_circle(move_base, stick_radius, Color(0.1, 0.14, 0.13, 0.65))
	draw_circle(move_base + movement * stick_radius, stick_radius * 0.44, Color(0.72, 0.78, 0.68, 0.8))
	draw_circle(aim_base, stick_radius, Color(0.15, 0.12, 0.11, 0.7))
	draw_arc(aim_base, stick_radius * FIRE_THRESHOLD, 0.0, TAU, 48, Color(0.94, 0.5, 0.34, 0.9), 3.0)
	draw_circle(aim_base + aim * aim_amount * stick_radius, stick_radius * 0.44, Color(0.9, 0.67, 0.48, 0.85))
	draw_string(ThemeDB.fallback_font, aim_base + Vector2(-stick_radius, 5), "ПРИЦЕЛ / ОГОНЬ", HORIZONTAL_ALIGNMENT_CENTER, stick_radius * 2.0, maxi(12, int(stick_radius * 0.2)), Color(1, 0.88, 0.75, 0.85))
	for action in buttons:
		var rect: Rect2 = buttons[action]
		draw_rect(rect, Color(0.12, 0.15, 0.14, 0.78), true)
		draw_rect(rect, Color(0.72, 0.68, 0.52, 0.9), false, 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, rect.size.y * 0.58), _label(action), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 16, Color.WHITE)

func _button_at(position: Vector2) -> String:
	for action in buttons:
		if buttons[action].has_point(position): return action
	return ""

func _emit_action(action: String) -> void:
	match action:
		"interact": interact_pressed.emit()
		"reload": reload_pressed.emit()
		"drop": drop_pressed.emit()
		"slot": slot_pressed.emit()
		"pause": pause_pressed.emit()

func _label(action: String) -> String:
	return { "interact": "ДЕЙСТВИЕ", "reload": "R", "drop": "БРОСИТЬ", "slot": "СЛОТ", "pause": "II" }.get(action, action)

func reset_input() -> void:
	move_touch = -1
	aim_touch = -1
	movement = Vector2.ZERO
	aim_amount = 0.0
	aim_attack_armed = true
	queue_redraw()

func _update_layout() -> void:
	safe_rect = _viewport_safe_rect()
	var short_side := minf(safe_rect.size.x, safe_rect.size.y)
	stick_radius = clampf(short_side * 0.1, 52.0, 78.0)
	var button_height := clampf(short_side * 0.09, 48.0, 66.0)
	var button_width := button_height * 1.55
	var gap := maxf(8.0, button_height * 0.16)
	var right_column := safe_rect.end.x - stick_radius * 2.25 - button_width
	var bottom := safe_rect.end.y - 18.0
	buttons = {
		"interact": Rect2(right_column, bottom - button_height, button_width, button_height),
		"reload": Rect2(right_column, bottom - (button_height + gap) * 2.0, button_width, button_height),
		"drop": Rect2(right_column, bottom - (button_height + gap) * 3.0, button_width, button_height),
		"slot": Rect2(right_column, bottom - (button_height + gap) * 4.0, button_width, button_height),
		"pause": Rect2(safe_rect.end.x - button_height, safe_rect.position.y + 12.0, button_height, button_height)
	}
	queue_redraw()

func _default_stick_center(right_side: bool) -> Vector2:
	var x := safe_rect.end.x - stick_radius - 18.0 if right_side else safe_rect.position.x + stick_radius + 18.0
	return Vector2(x, safe_rect.end.y - stick_radius - 18.0)

func _clamp_stick_origin(origin: Vector2) -> Vector2:
	var margin := stick_radius + 6.0
	return origin.clamp(safe_rect.position + Vector2.ONE * margin, safe_rect.end - Vector2.ONE * margin)

func _viewport_safe_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var display_safe := DisplayServer.get_display_safe_area()
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or display_safe.size.x <= 0.0 or display_safe.size.y <= 0.0:
		return viewport_rect
	var scale := viewport_rect.size / screen_size
	var result := Rect2(Vector2(display_safe.position) * scale, Vector2(display_safe.size) * scale)
	return result.intersection(viewport_rect) if result.has_area() else viewport_rect
