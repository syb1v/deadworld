extends Node2D
class_name WorldProp2D

const DepthSort = preload("res://scripts/world2d/DepthSort2D.gd")
const MaterialVariant = preload("res://scripts/world2d/MaterialVariant2D.gd")
const Palette = preload("res://scripts/data/Palette.gd")

@export var prop_id := "prop"
@export var district_id: StringName = &"residential"
@export var variant_seed := 0
@export var base_texture: Texture2D

var highlighted := false
var _time := 0.0
var _material_name: StringName = &"concrete"

func _ready() -> void:
	_material_name = MaterialVariant.material_for(district_id, variant_seed)
	DepthSort.apply(self, prop_id)
	queue_redraw()

func apply_variant(new_district: StringName, seed: int) -> void:
	district_id = new_district
	variant_seed = seed
	_material_name = MaterialVariant.material_for(district_id, variant_seed)
	queue_redraw()

func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()

func _process(delta: float) -> void:
	if highlighted:
		_time += delta
		queue_redraw()

func _draw() -> void:
	# Props are intentionally composed as a cohesive silhouette, texture detail,
	# contact shadow and feedback instead of unrelated full-frame PNGs.
	draw_ellipse_shape(Vector2(3, 10), 20.0, 6.0, Palette.SHADOW_SOFT)
	if base_texture != null:
		draw_texture_rect(base_texture, Rect2(-24, -42, 48, 48), false)
	else:
		draw_rect(Rect2(-20, -32, 40, 32), Palette.CONCRETE, true)
		draw_rect(Rect2(-20, -32, 40, 32), Palette.WALL_EDGE, false, 2.0)
	if highlighted:
		var alpha := 0.55 + absf(sin(_time * 3.2)) * 0.3
		draw_arc(Vector2(0, 0), 28.0, 0.0, TAU, 24, Color(Palette.UI_ACCENT, alpha), 2.0)

func draw_ellipse_shape(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius_y / radius_x))
	draw_circle(Vector2.ZERO, radius_x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
