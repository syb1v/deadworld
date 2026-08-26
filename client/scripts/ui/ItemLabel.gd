extends RefCounted
class_name ItemLabel

static func quantity_label(item: Dictionary) -> String:
	var quantity: int = str(item.get("quantity", 1)).to_int()
	var suffix := "x%d" % quantity if quantity > 1 else ""
	if item.get("definitionId", "") == "pistol":
		var magazine: int = str(item.get("magazineAmmo", 0)).to_int()
		return "%s\n%d/6" % [suffix, magazine] if not suffix.is_empty() else "\n%d/6" % magazine
	return suffix
