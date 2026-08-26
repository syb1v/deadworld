extends SceneTree

const ItemLabel = preload("res://scripts/ui/ItemLabel.gd")

func _init() -> void:
	_assert(ItemLabel.quantity_label({"definitionId": "pistol", "quantity": 1, "magazineAmmo": 4}) == "\n4/6", "pistol label handles numeric state")
	_assert(ItemLabel.quantity_label({"definitionId": "bandage", "quantity": 3}) == "x3", "stack label handles numeric state")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Item label test failed: %s" % message)
	quit(1)
