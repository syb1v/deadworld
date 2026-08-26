extends Node2D
class_name OcclusionLayer2D

@export var fade_amount := 0.42
@export var fade_duration := 0.12
var focus_target: Node2D
var _occluders: Array[CanvasItem] = []

func register_occluder(node: CanvasItem) -> void:
	if not _occluders.has(node):
		_occluders.append(node)

func set_focus(target: Node2D) -> void:
	focus_target = target
	_refresh_occlusion()

func _process(_delta: float) -> void:
	if focus_target != null:
		_refresh_occlusion()

func _refresh_occlusion() -> void:
	for occluder in _occluders:
		if not is_instance_valid(occluder):
			continue
		var distance := occluder.global_position.distance_to(focus_target.global_position)
		var target_alpha := fade_amount if distance < 82.0 else 1.0
		occluder.modulate.a = lerpf(occluder.modulate.a, target_alpha, 0.35)
