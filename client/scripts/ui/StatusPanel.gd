extends Control

## Панель состояния игрока: здоровье и боезапас.
##
## Значения приходят от сервера. Индикатор здоровья намеренно крупный и
## меняет цвет: в критическом состоянии игрок должен замечать это, не
## отводя взгляд от происходящего в мире.

const Palette = preload("res://scripts/data/Palette.gd")

var health := 100
var magazine := 0
var reserve := 0
var has_weapon := false
var _pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(230, 58)

func set_health(value: int) -> void:
	if health == value:
		return
	health = value
	queue_redraw()

func set_ammo(magazine_value: int, reserve_value: int, weapon: bool) -> void:
	magazine = magazine_value
	reserve = reserve_value
	has_weapon = weapon
	queue_redraw()

func _process(delta: float) -> void:
	# Пульсация только в критическом состоянии: постоянная анимация
	# отвлекала бы от игры.
	if health <= 30:
		_pulse += delta
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var width := size.x

	# Фон панели.
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.UI_BG, 0.82), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.UI_BORDER, 0.9), false, 1.0)

	# --- Здоровье ---
	var ratio := clampf(float(health) / 100.0, 0.0, 1.0)
	var bar := Rect2(10, 12, width - 20, 14)
	draw_rect(bar, Palette.HEALTH_BG, true)

	var health_color := Palette.UI_OK
	if health <= 30:
		# Критическое состояние пульсирует красным.
		var beat: float = 0.6 + absf(sin(_pulse * 6.0)) * 0.4
		health_color = Color(Palette.UI_DANGER.r, Palette.UI_DANGER.g, Palette.UI_DANGER.b, beat)
	elif health <= 60:
		health_color = Palette.UI_WARN

	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), health_color, true)
	# Деления по 25%: помогают оценить состояние без чтения цифр.
	for step in range(1, 4):
		var x := bar.position.x + bar.size.x * (step / 4.0)
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y),
			Color(Palette.VOID, 0.5), 1.0)
	draw_rect(bar, Color(Palette.UI_BORDER, 0.9), false, 1.0)

	draw_string(font, Vector2(12, 10), "СОСТОЯНИЕ",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.UI_TEXT_DIM)
	draw_string(font, Vector2(width - 12, 10), str(health),
		HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, Palette.UI_TEXT)

	# --- Боезапас ---
	var ammo_y := 42.0
	if has_weapon:
		var ammo_color := Palette.UI_DANGER if magazine == 0 else Palette.AMMO
		draw_string(font, Vector2(12, ammo_y), "ПАТРОНЫ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.UI_TEXT_DIM)
		draw_string(font, Vector2(width - 12, ammo_y), "%d/6  ·  запас %d" % [magazine, reserve],
			HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, ammo_color)
		# Патроны в магазине как отдельные метки: считываются мгновенно.
		for index in range(6):
			var dot := Vector2(84 + index * 9, ammo_y - 4)
			var filled := index < magazine
			draw_rect(Rect2(dot, Vector2(5, 3)),
				Palette.AMMO if filled else Color(Palette.UI_BORDER, 0.8), true)
	else:
		draw_string(font, Vector2(12, ammo_y), "ОРУЖИЕ НЕ ВЫБРАНО",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.UI_TEXT_DIM)
