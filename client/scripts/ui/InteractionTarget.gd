extends RefCounted

static func nearest(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary):
		if not is_equal_approx(a.distance, b.distance): return a.distance < b.distance
		if a.kind != b.kind: return a.kind < b.kind
		return a.id < b.id)
	return ordered[0]
