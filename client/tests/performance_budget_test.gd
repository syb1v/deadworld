extends SceneTree

const PerformanceTier = preload("res://scripts/world2d/PerformanceTier2D.gd")

func _init() -> void:
	var mobile: Dictionary = PerformanceTier.settings_for(&"mobile")
	var desktop: Dictionary = PerformanceTier.settings_for(&"desktop")
	_assert(mobile.max_layers == 180, "mobile layer budget")
	_assert(mobile.max_lights == 4, "mobile light budget")
	_assert(mobile.cell_radius == 1, "mobile cell radius")
	_assert(desktop.max_layers == 360, "desktop layer budget")
	_assert(desktop.max_lights == 8, "desktop light budget")
	_assert(PerformanceTier.detect() in [&"mobile", &"desktop"], "known runtime tier")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Performance budget test failed: %s" % message)
	quit(1)
