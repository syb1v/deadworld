extends RefCounted
class_name DeadworldPalette

## Единая палитра Project Deadworld.
##
## Все визуальные системы берут цвет отсюда. Хардкодить hex в отдельных
## скриптах запрещено: иначе мир, сущности и UI расходятся по тону и игра
## снова начинает выглядеть как набор несвязанных прототипов.
##
## Тон: выцветший постапокалипсис. Обесцвеченная органика, холодный бетон,
## ржавчина как единственный тёплый акцент. Насыщенный цвет — только там,
## где он несёт игровую информацию (кровь, опасность, свет).

# --- Базовые поверхности --------------------------------------------------
const VOID := Color("0a0c0b")          ## За границами мира
const ASPHALT := Color("22262a")       ## Дороги
const ASPHALT_WORN := Color("2b2f33")  ## Потёртый асфальт
const CONCRETE := Color("3a3c39")      ## Бетонные полы
const CONCRETE_DARK := Color("2e302e")
const SOIL := Color("2f2a22")          ## Земля
const GRASS_DEAD := Color("3a3a28")    ## Мёртвая трава
const GRASS_DRY := Color("46442e")
const WOOD_FLOOR := Color("3d3227")    ## Деревянные полы
const TILE_CLINIC := Color("32403f")   ## Кафель клиники

# --- Конструкции ----------------------------------------------------------
const WALL_TOP := Color("55564f")      ## Верхняя грань стены (освещена)
const WALL_FACE := Color("3c3d38")     ## Фронтальная грань (в тени)
const WALL_EDGE := Color("1c1e1c")     ## Контур
const WALL_TRIM := Color("6a6a5c")     ## Светлая кромка
const RUST := Color("6b4126")          ## Ржавчина, металл
const RUST_LIGHT := Color("8a5730")
const METAL := Color("4a4d50")

# --- Сущности -------------------------------------------------------------
const PLAYER_LOCAL := Color("6f8f6a")  ## Свой игрок: приглушённый хаки
const PLAYER_REMOTE := Color("7a6f55") ## Чужой игрок: песочный
const PLAYER_DEAD := Color("3f4340")
const SKIN := Color("9d8163")
const ZOMBIE_FLESH := Color("5c6b55")  ## Зомби: болезненная зелень
const ZOMBIE_ROT := Color("47513f")
const ZOMBIE_DEAD := Color("32372f")
const BLOOD := Color("6e1c18")         ## Кровь: тёмная, не «мультяшная»
const BLOOD_FRESH := Color("8f2420")

# --- Свет и атмосфера -----------------------------------------------------
const LIGHT_WARM := Color("ffcf8a")    ## Тёплые источники света
const LIGHT_COLD := Color("9fb8c4")    ## Холодный дневной свет
const FOG := Color("0d1113")           ## Туман/ограничение видимости
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)
const SHADOW_SOFT := Color(0.0, 0.0, 0.0, 0.28)

# --- UI -------------------------------------------------------------------
const UI_BG := Color("10130f")         ## Фон панелей
const UI_BG_SOLID := Color("161a15")
const UI_BORDER := Color("2c332a")
const UI_TEXT := Color("cdd3c4")       ## Основной текст
const UI_TEXT_DIM := Color("7d8778")   ## Второстепенный текст
const UI_ACCENT := Color("b8a05a")     ## Акцент: выцветшая латунь
const UI_DANGER := Color("a33a2c")
const UI_OK := Color("6f9455")
const UI_WARN := Color("c0873a")

# --- Индикаторы состояния -------------------------------------------------
const HEALTH := Color("8f4a42")
const HEALTH_BG := Color("2a1c1a")
const AMMO := Color("b8a05a")

## Затемнение цвета: используется для теней и граней в тени.
static func shade(color: Color, amount: float) -> Color:
	return color.darkened(amount)

## Осветление цвета: верхние грани, блики.
static func light(color: Color, amount: float) -> Color:
	return color.lightened(amount)

## Детерминированный вариант цвета для разнообразия тайлов/мусора.
## Один и тот же seed всегда даёт один и тот же результат, поэтому мир
## не «мерцает» между кадрами и одинаково выглядит у всех игроков.
static func vary(color: Color, seed_value: int, amount: float = 0.06) -> Color:
	var noise := float((seed_value * 2654435761) % 1000) / 1000.0
	return color.lightened((noise - 0.5) * 2.0 * amount)
