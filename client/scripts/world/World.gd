extends Node2D

const PlayerScript = preload("res://scripts/entities/Player.gd")
const ZombieScript = preload("res://scripts/entities/Zombie.gd")
const WorldItemScript = preload("res://scripts/entities/WorldItem.gd")
const ContainerScript = preload("res://scripts/entities/Container.gd")
const CombatEffectScript = preload("res://scripts/ui/CombatEffect.gd")
const FloatingDamageScript = preload("res://scripts/ui/FloatingDamage.gd")
const ITEM_NAMES: Dictionary = preload("res://data/item_names_ru.json").data
const ERROR_NAMES := {
	"BAD_PAYLOAD": "Некорректный запрос",
	"OUT_OF_RANGE": "Слишком далеко",
	"INVENTORY_FULL": "Инвентарь заполнен",
	"ITEM_NOT_AVAILABLE": "Предмет уже недоступен",
	"ITEM_NOT_OWNED": "Предмет вам не принадлежит",
	"STALE_WORLD_VERSION": "Мир изменился, повторите действие",
	"STALE_CONTAINER_VERSION": "Содержимое контейнера изменилось",
	"WEAPON_NOT_OWNED": "В выбранном слоте нет оружия",
	"NO_AMMO": "Нет патронов",
	"ATTACK_COOLDOWN": "Оружие ещё не готово",
	"PLAYER_DEAD": "Мёртвый игрок не может действовать"
}
var players: Dictionary = {}
var zombies: Dictionary = {}
var world_items: Dictionary = {}
var containers: Dictionary = {}
var inventory: Array = []
var world_version := 0
var selected_slot := 0
var send_accumulator := 0.0
var game_started := false
var game_paused := false
var mouse_attack_requested := false

func _ready() -> void:
	Network.status_changed.connect(func(text: String): $HUD/Status.text = text)
	Network.snapshot_received.connect(_on_snapshot)
	Network.inventory_received.connect(_on_inventory)
	Network.damage_received.connect(_on_damage)
	Network.server_error.connect(func(code: String): $HUD/Status.text = ERROR_NAMES.get(code, "Действие отклонено: %s" % code))
	$Menus/MainMenu/Play.pressed.connect(_start_game)
	$Menus/MainMenu/Quit.pressed.connect(func(): get_tree().quit())
	$Menus/PauseMenu/Resume.pressed.connect(_toggle_pause)
	$Menus/PauseMenu/Quit.pressed.connect(func(): get_tree().quit())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_draw_grid()
	if OS.get_cmdline_user_args().has("--auto-start"):
		_start_game()

func _process(delta: float) -> void:
	$HUD/Crosshair.position = get_viewport().get_mouse_position()
	_update_aim_line()
	if not game_started:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
	if game_paused:
		return
	send_accumulator += delta
	if send_accumulator >= 1.0 / 20.0:
		send_accumulator = 0.0
		Network.send_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if Input.is_action_just_pressed("interact"):
		_interact()
	if Input.is_action_just_pressed("drop_item") and selected_slot < inventory.size():
		Network.drop(inventory[selected_slot].id)
	for slot in range(8):
		if Input.is_key_pressed(KEY_1 + slot) and selected_slot != slot:
			selected_slot = slot
			_update_inventory_label()
	if Input.is_action_just_pressed("attack") or mouse_attack_requested:
		mouse_attack_requested = false
		var local_player = players.get(Network.player_id)
		if local_player != null and selected_slot < inventory.size():
			var aim: Vector2 = local_player.get_global_mouse_position() - local_player.global_position
			Network.attack(selected_slot, aim)
			_show_attack(local_player.position, aim, inventory[selected_slot].definitionId == "baseball_bat")

func _on_snapshot(snapshot: Dictionary) -> void:
	var seen := {}
	for state in snapshot.players:
		var id: String = state.id
		seen[id] = true
		if not players.has(id):
			var player := Node2D.new()
			player.set_script(PlayerScript)
			$Players.add_child(player)
			player.setup(id == Network.player_id)
			players[id] = player
		players[id].set_authoritative_position(Vector2(state.x, state.y))
		players[id].set_authoritative_state(state)
	for id in players.keys():
		if not seen.has(id):
			players[id].queue_free()
			players.erase(id)
	var seen_zombies := {}
	for state in snapshot.get("zombies", []):
		var id: String = state.id
		seen_zombies[id] = true
		if not zombies.has(id):
			var zombie := Node2D.new()
			zombie.set_script(ZombieScript)
			$Zombies.add_child(zombie)
			zombies[id] = zombie
		zombies[id].apply_snapshot(state)
	for id in zombies.keys():
		if not seen_zombies.has(id):
			zombies[id].queue_free()
			zombies.erase(id)
	world_version = snapshot.get("world_version", world_version)
	_sync_world_items(snapshot.get("world_items", []))
	_sync_containers(snapshot.get("containers", []))

func _sync_world_items(states: Array) -> void:
	var seen := {}
	for state in states:
		var id: String = state.id
		seen[id] = true
		if not world_items.has(id):
			var item := Node2D.new(); item.set_script(WorldItemScript); $Items.add_child(item); world_items[id] = item
		world_items[id].setup(state)
	for id in world_items.keys():
		if not seen.has(id): world_items[id].queue_free(); world_items.erase(id)

func _sync_containers(states: Array) -> void:
	var seen := {}
	for state in states:
		var id: String = state.id
		seen[id] = true
		if not containers.has(id):
			var container := Node2D.new(); container.set_script(ContainerScript); $Containers.add_child(container); containers[id] = container
		containers[id].set_meta("state", state); containers[id].setup(state)
	for id in containers.keys():
		if not seen.has(id): containers[id].queue_free(); containers.erase(id)

func _on_inventory(items: Array) -> void:
	inventory = items
	_update_inventory_label()

func _update_inventory_label() -> void:
	var lines: Array[String] = []
	for index in range(inventory.size()):
		lines.append("%s%d. %s" % ["> " if index == selected_slot else "  ", index + 1, _item_name(inventory[index].definitionId)])
	$HUD/Inventory.text = "Инвентарь (%d/8), слот %d\n%s" % [inventory.size(), selected_slot + 1, "\n".join(lines) if not lines.is_empty() else "Пусто"]

func _interact() -> void:
	var local_player = players.get(Network.player_id)
	if local_player == null: return
	var nearest_id := ""; var nearest_distance := 97.0
	for id in world_items:
		var distance: float = local_player.position.distance_to(world_items[id].position)
		if distance < nearest_distance: nearest_distance = distance; nearest_id = id
	if not nearest_id.is_empty(): Network.pickup(nearest_id, world_version); return
	for id in containers:
		var state: Dictionary = containers[id].get_meta("state")
		if local_player.position.distance_to(containers[id].position) <= 96.0 and not state.items.is_empty():
			Network.take_from_container(id, state.items[0].id, state.version); return

func _draw_grid() -> void:
	for x in range(0, 1281, 64):
		var line := Line2D.new()
		line.add_point(Vector2(x, 0)); line.add_point(Vector2(x, 720))
		line.default_color = Color(0.12, 0.18, 0.16, 0.45)
		line.width = 1.0; $Grid.add_child(line)
	for y in range(0, 721, 64):
		var line := Line2D.new()
		line.add_point(Vector2(0, y)); line.add_point(Vector2(1280, y))
		line.default_color = Color(0.12, 0.18, 0.16, 0.45)
		line.width = 1.0; $Grid.add_child(line)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.echo:
		mouse_attack_requested = true

func _start_game() -> void:
	game_started = true
	$Menus/MainMenu.hide()
	$HUD.show()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Network.connect_to_world()

func _toggle_pause() -> void:
	game_paused = not game_paused
	$Menus/PauseMenu.visible = game_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game_paused else Input.MOUSE_MODE_HIDDEN
	if game_paused:
		Network.send_move(Vector2.ZERO)

func _update_aim_line() -> void:
	var local_player = players.get(Network.player_id)
	$AimLine.clear_points()
	if local_player == null or not game_started or game_paused:
		return
	$AimLine.add_point(local_player.position)
	$AimLine.add_point(get_global_mouse_position())

func _show_attack(origin: Vector2, aim: Vector2, melee: bool) -> void:
	var effect := Node2D.new()
	effect.set_script(CombatEffectScript)
	$Effects.add_child(effect)
	var distance := 50.0 if melee else 260.0
	effect.setup(origin, origin + aim.normalized() * distance, melee)

func _on_damage(event: Dictionary) -> void:
	var target_id: String = event.get("target_id", "")
	var target = zombies.get(target_id, players.get(target_id))
	if target == null:
		return
	var label := Label.new()
	label.set_script(FloatingDamageScript)
	$Effects.add_child(label)
	label.setup(int(event.get("damage", 0)), target.position)

func _item_name(definition_id: String) -> String:
	return ITEM_NAMES.get(definition_id, definition_id)
