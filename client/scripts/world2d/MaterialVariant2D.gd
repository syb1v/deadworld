extends RefCounted
class_name MaterialVariant2D

const VARIANTS := {
	&"safehouse": [&"concrete", &"wood"],
	&"residential": [&"concrete", &"wood", &"soil"],
	&"clinic": [&"tile_clinic", &"concrete"],
	&"industrial": [&"asphalt", &"concrete", &"metal"],
	&"fuel": [&"asphalt", &"concrete"],
	&"park": [&"grass", &"soil", &"wood"],
	&"warehouse": [&"concrete", &"asphalt"],
	&"commercial": [&"concrete", &"asphalt", &"wood"],
	&"perimeter": [&"soil", &"grass", &"asphalt"]
}

static func material_for(district_id: StringName, seed: int) -> StringName:
	var family: Array = VARIANTS.get(district_id, [&"concrete"])
	return family[absi(seed) % family.size()]
