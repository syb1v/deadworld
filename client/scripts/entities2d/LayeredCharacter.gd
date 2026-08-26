extends Node2D
class_name LayeredCharacter

const DirectionalSet = preload("res://scripts/entities2d/DirectionalSpriteSet.gd")

@export var asset_id := "survivor"
@export var pixels_per_frame := Vector2i(96, 128)
@export var frame_rate := 8.0

var facing := Vector2.DOWN
var velocity := Vector2.ZERO
var character_state: StringName = &"idle"
var animation_time := 0.0
var authoritative_event_id := -1
var _layers: Dictionary = {}
var _frame_counts := {"idle": 6, "walk": 6, "attack": 4, "hit": 4, "death": 4}

func _ready() -> void:
	for layer_name in ["shadow", "backpack", "body", "clothing", "weapon"]:
		var sprite := Sprite2D.new()
		sprite.name = layer_name.capitalize()
		sprite.centered = false
		sprite.offset = Vector2(-pixels_per_frame.x * 0.5, -pixels_per_frame.y + 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = _layer_z(layer_name)
		add_child(sprite)
		_layers[layer_name] = sprite
	_refresh_textures()

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, aim: Vector2, state: StringName, event_id: int = -1) -> void:
	position = new_position
	velocity = new_velocity
	if aim.length_squared() > 0.0001:
		facing = aim.normalized()
	elif velocity.length_squared() > 0.0001:
		facing = velocity.normalized()
	character_state = state if _frame_counts.has(state) else &"idle"
	if event_id >= authoritative_event_id:
		authoritative_event_id = event_id
		animation_time = 0.0 if state in [&"attack", &"hit", &"death"] else animation_time
	_refresh_frame()

func set_equipment_layer(layer_name: StringName, definition_id: StringName) -> void:
	if not _layers.has(layer_name):
		return
	_layers[layer_name].set_meta("definition_id", definition_id)

func _process(delta: float) -> void:
	animation_time += delta
	_refresh_frame()

func _refresh_textures() -> void:
	for layer_name in _layers:
		var sprite: Sprite2D = _layers[layer_name]
		var path := "res://assets/generated/characters/%s/%s_%s.png" % [asset_id, layer_name, character_state]
		sprite.texture = load(path)
		if sprite.texture != null:
			sprite.hframes = DirectionalSet.DIRECTIONS.size()
			sprite.vframes = int(_frame_counts.get(character_state, 6))

func _refresh_frame() -> void:
	var sector := DirectionalSet.sector_for_vector(facing)
	var frame_count: int = int(_frame_counts.get(character_state, 6))
	var frame := int(floor(animation_time * frame_rate)) % frame_count
	for layer_name in _layers:
		var sprite: Sprite2D = _layers[layer_name]
		var expected_path := "res://assets/generated/characters/%s/%s_%s.png" % [asset_id, layer_name, character_state]
		if sprite.texture == null or sprite.texture.resource_path != expected_path:
			_refresh_textures()
			sprite = _layers[layer_name]
		sprite.frame = DirectionalSet.frame_index(sector, frame, frame_count)

func _layer_z(layer_name: String) -> int:
	return {"shadow": -10, "backpack": -3, "body": 0, "clothing": 1, "weapon": 2}.get(layer_name, 0)
