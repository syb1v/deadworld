extends RefCounted
class_name ItemIcons

## Реестр иконок предметов.
##
## Один источник для мира, инвентаря и панели контейнера: иначе один и тот
## же предмет выглядит по-разному в разных экранах, и игрок перестаёт
## узнавать его с первого взгляда.
##
## Иконки создаёт scripts/generate_assets.py. Для неизвестного предмета
## возвращается generic — новый предмет на сервере не должен ломать клиент.

const BASE_PATH := "res://assets/generated/items/"

const KNOWN := [
	"pistol",
	"pistol_ammo",
	"baseball_bat",
	"bandage",
	"canned_food",
	"water_bottle",
	"scrap_metal"
]

static var _cache: Dictionary = {}

static func get_icon(definition_id: String) -> Texture2D:
	var key := definition_id if definition_id in KNOWN else "generic"
	if not _cache.has(key):
		_cache[key] = load(BASE_PATH + key + ".png")
	return _cache[key]
