extends RefCounted
class_name PerformanceTier2D

const MOBILE_MAX_LAYERS := 180
const DESKTOP_MAX_LAYERS := 360
const MOBILE_MAX_LIGHTS := 4
const DESKTOP_MAX_LIGHTS := 8
const MOBILE_MAX_CELLS := 9
const DESKTOP_MAX_CELLS := 25

static func detect() -> StringName:
	if OS.has_feature("mobile"):
		return &"mobile"
	return &"desktop"

static func settings_for(tier: StringName) -> Dictionary:
	match tier:
		&"mobile":
			return {"max_layers": MOBILE_MAX_LAYERS, "max_lights": MOBILE_MAX_LIGHTS, "cell_radius": 1, "clutter_scale": 0.55, "animation_scale": 0.85}
		&"fallback":
			return {"max_layers": 96, "max_lights": 2, "cell_radius": 1, "clutter_scale": 0.35, "animation_scale": 0.7}
		_:
			return {"max_layers": DESKTOP_MAX_LAYERS, "max_lights": DESKTOP_MAX_LIGHTS, "cell_radius": 2, "clutter_scale": 1.0, "animation_scale": 1.0}

static func apply(tier: StringName, partition: Node2D) -> void:
	var settings := settings_for(tier)
	partition.set("mobile_radius", int(settings.cell_radius))
	partition.set("desktop_radius", int(settings.cell_radius))
	partition.set("use_mobile_budget", tier != &"desktop")
