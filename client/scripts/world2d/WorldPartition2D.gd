extends Node2D
class_name WorldPartition2D

const CELL_SIZE := 32.0
const WorldCell = preload("res://scripts/world2d/WorldCell2D.gd")

@export var mobile_radius := 1
@export var desktop_radius := 2
var descriptor: Dictionary = {}
var cell_index: Dictionary = {}
var loaded_cells: Dictionary = {}
var proxy_cells: Dictionary = {}
var use_mobile_budget := false
var _last_relevance_cell := Vector2i(2147483647, 2147483647)

func set_descriptor(value: Dictionary) -> void:
	descriptor = value
	cell_index.clear()
	for cell in descriptor.get("cells", []):
		cell_index[str(cell.get("id", ""))] = cell
	_last_relevance_cell = Vector2i(2147483647, 2147483647)
	_clear_cells()

func configure_tier(tier: StringName) -> void:
	var settings: int = str({&"mobile": 1, &"fallback": 1, &"desktop": 2}.get(tier, 2)).to_int()
	mobile_radius = settings
	desktop_radius = settings
	use_mobile_budget = tier != &"desktop"

func update_relevance(authoritative_position: Vector2) -> void:
	if descriptor.is_empty():
		return
	var radius := mobile_radius if use_mobile_budget else desktop_radius
	var center := _cell_coords(authoritative_position)
	if center == _last_relevance_cell:
		return
	_last_relevance_cell = center
	var wanted: Dictionary = {}
	var wanted_proxies: Dictionary = {}
	for row in range(center.y - radius - 1, center.y + radius + 2):
		for column in range(center.x - radius - 1, center.x + radius + 2):
			var id := "%d:%d" % [column, row]
			if abs(column - center.x) <= radius and abs(row - center.y) <= radius:
				wanted[id] = true
			else:
				wanted_proxies[id] = true
	for id in wanted:
		_activate(id, false)
	for id in wanted_proxies:
		if not wanted.has(id):
			_activate(id, true)
	for id in loaded_cells.keys():
		if not wanted.has(id):
			loaded_cells[id].queue_free()
			loaded_cells.erase(id)
	for id in proxy_cells.keys():
		if not wanted_proxies.has(id) or wanted.has(id):
			proxy_cells[id].queue_free()
			proxy_cells.erase(id)

func is_cell_loaded(cell_id: String) -> bool:
	return loaded_cells.has(cell_id)

func _activate(cell_id: String, as_proxy: bool) -> void:
	if (as_proxy and proxy_cells.has(cell_id)) or (not as_proxy and loaded_cells.has(cell_id)):
		return
	var cell_data := _find_cell(cell_id)
	if cell_data.is_empty():
		return
	var cell: Node2D = WorldCell.new()
	cell.setup(cell_data, as_proxy)
	add_child(cell)
	if as_proxy:
		proxy_cells[cell_id] = cell
	else:
		loaded_cells[cell_id] = cell

func _find_cell(cell_id: String) -> Dictionary:
	return cell_index.get(cell_id, {})

func _cell_coords(value: Vector2) -> Vector2i:
	return Vector2i(floori(value.x / CELL_SIZE), floori(value.y / CELL_SIZE))

func _clear_cells() -> void:
	for cell in loaded_cells.values() + proxy_cells.values():
		cell.queue_free()
	loaded_cells.clear()
	proxy_cells.clear()
