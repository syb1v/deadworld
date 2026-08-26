extends SceneTree

const Partition = preload("res://scripts/world2d/WorldPartition2D.gd")

func _init() -> void:
	var partition: Node2D = Partition.new()
	partition.set_descriptor({"cells": [
		{"id": "0:0", "x": 0, "y": 0, "districtId": "safehouse"},
		{"id": "1:0", "x": 32, "y": 0, "districtId": "safehouse"},
		{"id": "0:1", "x": 0, "y": 32, "districtId": "park"}
	]})
	root.add_child(partition)
	partition.use_mobile_budget = true
	partition.update_relevance(Vector2(10, 10))
	_assert(partition.is_cell_loaded("0:0"), "center cell loads")
	_assert(partition.is_cell_loaded("1:0"), "adjacent cell loads")
	var loaded_count: int = partition.loaded_cells.size()
	partition.update_relevance(Vector2(11, 11))
	_assert(partition.loaded_cells.size() == loaded_count, "same cell does not rebuild streaming set")
	partition.update_relevance(Vector2(100, 100))
	_assert(not partition.is_cell_loaded("0:0"), "far cell unloads")
	partition.queue_free()
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("World streaming test failed: %s" % message)
	quit(1)
