extends RefCounted
class_name DirectionalSpriteSet

const DIRECTIONS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]

static func sector_for_vector(direction: Vector2) -> StringName:
	if direction.length_squared() < 0.0001:
		return &"S"
	var angle := atan2(direction.x, -direction.y)
	var sector := int(floor((angle + PI / 8.0) / (PI / 4.0)))
	sector = posmod(sector, DIRECTIONS.size())
	return DIRECTIONS[sector]

static func index_for_sector(sector: StringName) -> int:
	var index := DIRECTIONS.find(sector)
	return index if index >= 0 else 4

static func frame_index(sector: StringName, frame: int, frame_count: int) -> int:
	return clampi(frame, 0, max(0, frame_count - 1)) * DIRECTIONS.size() + index_for_sector(sector)
