extends Node2D

const PlayerScript = preload("res://scripts/entities/Player.gd")
const ZombieScript = preload("res://scripts/entities/Zombie.gd")
const WorldItemScript = preload("res://scripts/entities/WorldItem.gd")
const ContainerScript = preload("res://scripts/entities/Container.gd")
const CombatEffectScript = preload("res://scripts/ui/CombatEffect.gd")
const FloatingDamageScript = preload("res://scripts/ui/FloatingDamage.gd")
const WorldMapScript = preload("res://scripts/world/WorldMap.gd")
const TouchControlsScript = preload("res://scripts/ui/TouchControls.gd")
const InteractionTarget = preload("res://scripts/ui/InteractionTarget.gd")
const GameCameraScript = preload("res://scripts/world/GameCamera.gd")
const AtmosphereScript = preload("res://scripts/world/Atmosphere.gd")
const WorldPartitionScript = preload("res://scripts/world2d/WorldPartition2D.gd")
const Palette = preload("res://scripts/data/Palette.gd")
const MAP: Dictionary = preload("res://data/world_map.json").data
const BUILD_LABEL := "v0.1.0-prealpha.7"
const ITEM_NAMES: Dictionary = preload("res://data/item_names_ru.json").data
const ERROR_NAMES := {
	"BAD_PAYLOAD": "Некорректный запрос",
	"OUT_OF_RANGE": "Слишком далеко",
	"INVENTORY_FULL": "Инвентарь заполнен",
	"ITEM_NOT_AVAILABLE": "Предмет уже недоступен",
	"ITEM_NOT_OWNED": "Предмет вам не принадлежит",
	"STALE_WORLD_VERSION": "Мир изменился, повторите действие",
	"STALE_CONTAINER_VERSION": "Содержимое контейнера изменилось",
	"CONTAINER_NOT_FOUND": "Контейнер больше недоступен",
	"WEAPON_NOT_OWNED": "В выбранном слоте нет оружия",
	"NO_AMMO": "Нет патронов",
	"MAGAZINE_EMPTY": "Магазин пуст. Нажмите R для перезарядки",
	"MAGAZINE_FULL": "Магазин уже полон",
	"PISTOL_NOT_SELECTED": "Для перезарядки выберите пистолет",
	"ATTACK_COOLDOWN": "Оружие ещё не готово",
	"PLAYER_DEAD": "Мёртвый игрок не может действовать",
	"BAD_OPERATION": "Недоступное действие с контейнером",
	"PERSISTENCE_CONFLICT": "Мир изменился. Переподключитесь"
}
var players: Dictionary = {}
var zombies: Dictionary = {}
var world_items: Dictionary = {}
var containers: Dictionary = {}
var inventory: Array = []
var world_version := 0
var selected_slot := 0
var selected_item_id := ""
var send_accumulator := 0.0
var game_started := false
var game_paused := false
var mouse_attack_requested := false
var touch_controls
var touch_attack_requested := false
var current_aim := Vector2.RIGHT
var connecting := false
var interaction_target: Dictionary = {}
var open_container_id := ""
var container_mutation_pending := false
var pending_container_version := -1
var camera: Camera2D = null
var atmosphere: Node2D = null
var world_partition: Node2D = null

func _ready() -> void:
	var world_map := Node2D.new()
	world_map.set_script(WorldMapScript)
	add_child(world_map)
	move_child(world_map, $Background.get_index() + 1)
	camera = Camera2D.new()
	camera.set_script(GameCameraScript)
	add_child(camera)
	camera.make_current()
	atmosphere = Node2D.new()
	atmosphere.set_script(AtmosphereScript)
	add_child(atmosphere)
	world_partition = Node2D.new()
	world_partition.set_script(WorldPartitionScript)
	add_child(world_partition)
	world_partition.set_descriptor(MAP)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 5
	add_child(touch_layer)
	touch_controls = Control.new()
	touch_controls.set_script(TouchControlsScript)
	touch_layer.add_child(touch_controls)
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.visible = false
	touch_controls.attack_pressed.connect(func():
		if game_started and not game_paused: touch_attack_requested = true)
	touch_controls.interact_pressed.connect(func():
		if game_started and not game_paused: _interact())
	touch_controls.reload_pressed.connect(func():
		if game_started and not game_paused and _selected_slot() >= 0: Network.reload(_selected_slot()))
	touch_controls.drop_pressed.connect(func():
		if game_started and not game_paused and _selected_slot() >= 0: Network.drop(inventory[_selected_slot()].id))
	touch_controls.pause_pressed.connect(_toggle_pause)
	touch_controls.slot_pressed.connect(func():
		if game_started and not game_paused: _select_next_slot())
	$HUD/ContainerPanel/Margin/Layout/Header/Close.pressed.connect(_close_container)
	$HUD/Hotbar.slot_selected.connect(_select_slot)
	$HUD/ContainerPanel/Margin/Layout/Columns/ContainerColumn/Take.pressed.connect(_take_selected_container_item)
	$HUD/ContainerPanel/Margin/Layout/Columns/InventoryColumn/Deposit.pressed.connect(_deposit_selected_inventory_item)
	Network.status_changed.connect(_on_network_status)
	Network.snapshot_received.connect(_on_snapshot)
	Network.inventory_received.connect(_on_inventory)
	Network.damage_received.connect(_on_damage)
	Network.attack_confirmed.connect(_on_attack_confirmed)
	Network.reload_confirmed.connect(_on_reload_confirmed)
	Network.server_error.connect(_on_server_error)
	$Menus/MainMenu/Play.pressed.connect(_start_game)
	$Menus/MainMenu/ServerHost.text = Network.saved_server_url()
	$Menus/MainMenu/Quit.pressed.connect(func(): get_tree().quit())
	$Menus/PauseMenu/Resume.pressed.connect(_toggle_pause)
	$Menus/PauseMenu/Quit.pressed.connect(func(): get_tree().quit())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().size_changed.connect(_update_ui_layout)
	_update_ui_layout()
	$HUD/BuildMarker.text = "%s · %s" % [BUILD_LABEL, "TOUCH" if _touch_enabled() else "DESKTOP"]

	if OS.get_cmdline_user_args().has("--auto-start"):
		_start_game()

func _on_network_status(text: String) -> void:
	$HUD/Status.text = text
	$Menus/MainMenu/ConnectionStatus.text = text

func _process(delta: float) -> void:
	if touch_controls != null and touch_controls.visible:
		current_aim = touch_controls.aim
	else:
		var local_player = players.get(Network.player_id)
		if local_player != null:
			var aim_delta: Vector2 = local_player.get_global_mouse_position() - local_player.global_position
			if aim_delta.length_squared() > 1.0: current_aim = aim_delta.normalized()
	var facing_player = players.get(Network.player_id)
	if facing_player != null: facing_player.set_facing(current_aim)
	$HUD/Crosshair.visible = touch_controls == null or not touch_controls.visible
	$HUD/Crosshair.position = get_viewport().get_mouse_position()
	_update_aim_line()
	_update_interaction_target()
	if not game_started:
		return
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
	if game_paused:
		return
	if not open_container_id.is_empty():
		mouse_attack_requested = false
		touch_attack_requested = false
		return
	send_accumulator += delta
	if send_accumulator >= 1.0 / 20.0:
		send_accumulator = 0.0
		var move_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if touch_controls != null and touch_controls.visible: move_input = touch_controls.movement
		Network.send_move(move_input)
	if Input.is_action_just_pressed("interact"):
		_interact()
	if Input.is_action_just_pressed("drop_item") and _selected_slot() >= 0:
		Network.drop(inventory[_selected_slot()].id)
	if Input.is_action_just_pressed("reload") and _selected_slot() >= 0:
		Network.reload(_selected_slot())
	for slot in range(8):
		if Input.is_key_pressed(KEY_1 + slot) and selected_slot != slot:
			_select_slot(slot)
	if Input.is_action_just_pressed("attack") or mouse_attack_requested or touch_attack_requested:
		mouse_attack_requested = false
		touch_attack_requested = false
		var local_player = players.get(Network.player_id)
		var weapon_slot := _selected_slot()
		if local_player != null and weapon_slot >= 0:
			Network.attack(weapon_slot, current_aim)

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
			if id == Network.player_id:
				if camera != null:
					camera.set_target(player)
				if atmosphere != null:
					atmosphere.set_player(player)
		players[id].set_authoritative_position(Vector2(state.x, state.y))
		players[id].set_authoritative_state(state)
		if id == Network.player_id:
			$HUD/StatusPanel.set_health(int(state.health))
			if world_partition != null:
				world_partition.update_relevance(Vector2(state.x, state.y))
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
	var zombie_states: Array = snapshot.get("zombies", [])
	$HUD/ZombieCount.text = "Зомби: живы %d / всего %d" % [zombie_states.filter(func(zombie): return zombie.hp > 0).size(), zombie_states.size()]
	world_version = snapshot.get("world_version", world_version)
	_sync_world_items(snapshot.get("world_items", []))
	_sync_containers(snapshot.get("containers", []))
	_refresh_container_panel()

func _sync_world_items(states: Array) -> void:
	var seen := {}
	for state in states:
		var id: String = state.id
		seen[id] = true
		if not world_items.has(id):
			var item := Node2D.new(); item.set_script(WorldItemScript); $Items.add_child(item); world_items[id] = item
		world_items[id].set_meta("state", state)
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
	if _selected_slot() < 0:
		selected_item_id = inventory[mini(selected_slot, inventory.size() - 1)].id if not inventory.is_empty() else ""
	selected_slot = maxi(0, _selected_slot())
	_update_inventory_label()
	_refresh_container_panel()

## Обновляет игровой HUD по авторитетному снимку инвентаря.
## Клиент ничего не досчитывает: показывается ровно то, что прислал сервер.
func _update_inventory_label() -> void:
	var reserve := 0
	for item in inventory:
		if item.definitionId == "pistol_ammo":
			reserve += item.get("quantity") if item.get("quantity") != null else 1

	$HUD/Hotbar.set_inventory(inventory, selected_item_id)

	var selected = inventory[_selected_slot()] if _selected_slot() >= 0 else null
	var is_firearm: bool = selected != null and selected.definitionId == "pistol"
	var selected_magazine: int = 0
	if is_firearm and selected.get("magazineAmmo") != null:
		selected_magazine = int(selected.get("magazineAmmo"))
	$HUD/StatusPanel.set_ammo(selected_magazine, reserve, is_firearm)

func _interact() -> void:
	if interaction_target.is_empty():
		return
	if interaction_target.kind == "world_item":
		Network.pickup(interaction_target.id, world_version)
	else:
		_open_container(interaction_target.id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_attack_requested = true

func _start_game() -> void:
	if connecting:
		return
	connecting = true
	$Menus/MainMenu/Play.disabled = true
	$Menus/MainMenu/Play.text = "ПОДКЛЮЧЕНИЕ..."
	Network.set_server_url($Menus/MainMenu/ServerHost.text)
	var connected := await Network.connect_to_world()
	connecting = false
	$Menus/MainMenu/Play.disabled = false
	$Menus/MainMenu/Play.text = "ИГРАТЬ"
	if not connected:
		return
	game_started = true
	touch_controls.visible = _touch_enabled()
	_update_ui_layout()
	$Menus/MainMenu.hide()
	$HUD.show()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _toggle_pause() -> void:
	game_paused = not game_paused
	$Menus/PauseMenu.visible = game_paused
	if touch_controls != null: touch_controls.visible = _touch_enabled() and not game_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if game_paused else Input.MOUSE_MODE_HIDDEN
	if game_paused:
		touch_controls.reset_input()
		Network.send_move(Vector2.ZERO)
		_close_container()

func _update_ui_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 1050.0 or viewport_size.y < 620.0
	var mobile_layout := _touch_enabled()
	var safe: Rect2 = touch_controls.safe_rect if touch_controls != null and touch_controls.safe_rect.has_area() else get_viewport_rect()
	$HUD/Hint.visible = not compact and not mobile_layout
	$HUD/Status.position = safe.position + Vector2(16, 12)
	$HUD/ZombieCount.position = safe.position + Vector2(16, 48)
	var panel_size := Vector2(minf(860.0, viewport_size.x - 32.0), minf(490.0, viewport_size.y - 32.0))
	$HUD/ContainerPanel.offset_left = -panel_size.x * 0.5
	$HUD/ContainerPanel.offset_top = -panel_size.y * 0.5
	$HUD/ContainerPanel.offset_right = panel_size.x * 0.5
	$HUD/ContainerPanel.offset_bottom = panel_size.y * 0.5

	# Хотбар: слот должен оставаться пригодным для пальца на телефоне,
	# но не занимать пол-экрана на десктопе.
	var slot_size := 46.0 if compact else 54.0
	if mobile_layout:
		slot_size = clampf(safe.size.x / 13.0, 40.0, 58.0)
	var gap := slot_size * 0.12
	var hotbar: Control = $HUD/Hotbar
	hotbar.configure(slot_size, gap)
	var hotbar_width := slot_size * 8.0 + gap * 7.0
	# На мобильных хотбар поднимается выше: снизу находятся стики.
	var hotbar_bottom := safe.end.y - (150.0 if mobile_layout else 24.0)
	hotbar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hotbar.position = Vector2(safe.position.x + (safe.size.x - hotbar_width) * 0.5,
		hotbar_bottom - slot_size)

	# Панель состояния: слева внизу на десктопе, слева сверху на телефоне,
	# где низ экрана занят органами управления.
	var status: Control = $HUD/StatusPanel
	status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status.size = Vector2(minf(240.0, safe.size.x * 0.42), 58.0)
	if mobile_layout:
		status.position = safe.position + Vector2(16, 78)
	else:
		status.position = Vector2(safe.position.x + 16.0, hotbar_bottom - slot_size - 70.0)

func _update_aim_line() -> void:
	var local_player = players.get(Network.player_id)
	$AimLine.clear_points()
	if local_player == null or not game_started or game_paused:
		return
	$AimLine.add_point(local_player.position)
	$AimLine.add_point(local_player.position + current_aim.normalized() * 180.0)

func _show_attack(origin: Vector2, aim: Vector2, melee: bool) -> void:
	var effect := Node2D.new()
	effect.set_script(CombatEffectScript)
	$Effects.add_child(effect)
	var distance := 50.0 if melee else 260.0
	effect.setup(origin, origin + aim.normalized() * distance, melee)

func _on_attack_confirmed(event: Dictionary) -> void:
	var player = players.get(event.get("player_id", ""))
	if player == null:
		return
	var melee: bool = event.get("weapon", "") == "baseball_bat"
	_show_attack(player.position, Vector2(event.get("aim_x", 0.0), event.get("aim_y", 0.0)), melee)
	# Отдача чувствуется только для своего выстрела: чужая стрельба не
	# должна трясти камеру игрока.
	if camera != null and event.get("player_id", "") == Network.player_id:
		camera.shake(3.0 if melee else 5.0)

func _on_reload_confirmed(event: Dictionary) -> void:
	if event.get("player_id", "") == Network.player_id:
		$HUD/Status.text = "Перезаряжено: %d, в магазине: %d/6" % [event.get("loaded", 0), event.get("magazine_ammo", 0)]

func _on_damage(event: Dictionary) -> void:
	var target_id: String = event.get("target_id", "")
	var target = zombies.get(target_id, players.get(target_id))
	if target == null:
		return
	var label := Label.new()
	label.set_script(FloatingDamageScript)
	$Effects.add_child(label)
	label.setup(int(event.get("damage", 0)), target.position)
	# Получение урона игроком ощущается физически.
	if camera != null and target_id == Network.player_id:
		camera.shake(7.0, 0.22)

func _item_name(definition_id: String) -> String:
	return ITEM_NAMES.get(definition_id, definition_id)

func _selected_slot() -> int:
	for index in range(inventory.size()):
		if inventory[index].id == selected_item_id:
			return index
	return -1

func _select_next_slot() -> void:
	if inventory.is_empty(): return
	var current := _selected_slot()
	var next := (current + 1) % inventory.size()
	_select_slot(next)

## Выбор конкретного слота: клавишами 1-8 или тапом по хотбару.
func _select_slot(index: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	selected_slot = index
	selected_item_id = inventory[index].id
	_update_inventory_label()

func _update_interaction_target() -> void:
	var local_player = players.get(Network.player_id)
	interaction_target = {}
	if local_player == null or not game_started or game_paused or not open_container_id.is_empty():
		$HUD/InteractionPrompt.text = ""
		_apply_highlight("")
		return
	var candidates: Array[Dictionary] = []
	for id in world_items:
		var distance: float = local_player.position.distance_to(world_items[id].position)
		if distance <= 96.0:
			var state: Dictionary = world_items[id].get_meta("state", {})
			candidates.append({"kind": "world_item", "id": id, "distance": distance, "label": _item_name(state.get("definitionId", "предмет"))})
	for id in containers:
		var distance: float = local_player.position.distance_to(containers[id].position)
		if distance <= 96.0:
			var state: Dictionary = containers[id].get_meta("state", {})
			candidates.append({"kind": "container", "id": id, "distance": distance, "label": "Контейнер · %d" % state.get("items", []).size()})
	if candidates.is_empty():
		$HUD/InteractionPrompt.text = ""
		_apply_highlight("")
		return
	interaction_target = InteractionTarget.nearest(candidates)
	_apply_highlight(interaction_target.id)
	var action := "взять" if interaction_target.kind == "world_item" else "открыть"
	$HUD/InteractionPrompt.text = "%s — %s %s" % ["ДЕЙСТВИЕ" if touch_controls.visible else "E", action, interaction_target.label]

## Подсветка выбранной цели прямо в мире. Текстовой подсказки мало:
## при нескольких объектах рядом игрок должен видеть, что именно сработает.
func _apply_highlight(target_id: String) -> void:
	for id in world_items:
		world_items[id].set_highlighted(id == target_id)
	for id in containers:
		containers[id].set_highlighted(id == target_id)

func _open_container(container_id: String) -> void:
	if not containers.has(container_id):
		return
	open_container_id = container_id
	container_mutation_pending = false
	pending_container_version = -1
	$HUD/ContainerPanel.show()
	$HUD/InteractionPrompt.text = ""
	if touch_controls.visible:
		touch_controls.reset_input()
		touch_controls.hide()
	Network.send_move(Vector2.ZERO)
	_refresh_container_panel()

func _close_container() -> void:
	open_container_id = ""
	container_mutation_pending = false
	pending_container_version = -1
	$HUD/ContainerPanel.hide()
	if game_started and not game_paused and _touch_enabled():
		touch_controls.show()

func _refresh_container_panel() -> void:
	if open_container_id.is_empty():
		return
	if not containers.has(open_container_id):
		_close_container()
		return
	var local_player = players.get(Network.player_id)
	if local_player == null or local_player.position.distance_to(containers[open_container_id].position) > 96.0:
		_close_container()
		return
	var state: Dictionary = containers[open_container_id].get_meta("state", {})
	var version := int(state.get("version", -1))
	if container_mutation_pending and version != pending_container_version:
		container_mutation_pending = false
		pending_container_version = -1
		$HUD/ContainerPanel/Margin/Layout/Feedback.text = "Перенос подтверждён сервером"
	var container_list: ItemList = $HUD/ContainerPanel/Margin/Layout/Columns/ContainerColumn/Items
	var inventory_list: ItemList = $HUD/ContainerPanel/Margin/Layout/Columns/InventoryColumn/Items
	var selected_container_id := _selected_list_item_id(container_list)
	var selected_inventory_id := _selected_list_item_id(inventory_list)
	container_list.clear()
	inventory_list.clear()
	for item in state.get("items", []):
		var index := container_list.add_item(_item_quantity_label(item), ItemIcons.get_icon(str(item.get("definitionId", ""))))
		container_list.set_item_metadata(index, item.get("id", ""))
		if item.get("id", "") == selected_container_id: container_list.select(index)
	for item in inventory:
		var index := inventory_list.add_item(_item_quantity_label(item), ItemIcons.get_icon(str(item.get("definitionId", ""))))
		inventory_list.set_item_metadata(index, item.get("id", ""))
		if item.get("id", "") == selected_inventory_id: inventory_list.select(index)
	$HUD/ContainerPanel/Margin/Layout/Title.text = "КОНТЕЙНЕР · %d ПРЕДМ. · V%d" % [state.get("items", []).size(), version]
	$HUD/ContainerPanel/Margin/Layout/Columns/ContainerColumn/Take.disabled = container_mutation_pending or container_list.item_count == 0
	$HUD/ContainerPanel/Margin/Layout/Columns/InventoryColumn/Deposit.disabled = container_mutation_pending or inventory_list.item_count == 0

func _take_selected_container_item() -> void:
	if container_mutation_pending or not containers.has(open_container_id):
		return
	var list: ItemList = $HUD/ContainerPanel/Margin/Layout/Columns/ContainerColumn/Items
	var item_id := _selected_list_item_id(list)
	if item_id.is_empty():
		$HUD/ContainerPanel/Margin/Layout/Feedback.text = "Выберите предмет в контейнере"
		return
	var state: Dictionary = containers[open_container_id].get_meta("state", {})
	_begin_container_mutation(int(state.get("version", -1)))
	Network.take_from_container(open_container_id, item_id, pending_container_version)

func _deposit_selected_inventory_item() -> void:
	if container_mutation_pending or not containers.has(open_container_id):
		return
	var list: ItemList = $HUD/ContainerPanel/Margin/Layout/Columns/InventoryColumn/Items
	var item_id := _selected_list_item_id(list)
	if item_id.is_empty():
		$HUD/ContainerPanel/Margin/Layout/Feedback.text = "Выберите предмет в рюкзаке"
		return
	var state: Dictionary = containers[open_container_id].get_meta("state", {})
	_begin_container_mutation(int(state.get("version", -1)))
	Network.deposit_to_container(open_container_id, item_id, pending_container_version)

func _begin_container_mutation(version: int) -> void:
	container_mutation_pending = true
	pending_container_version = version
	$HUD/ContainerPanel/Margin/Layout/Feedback.text = "Ожидание подтверждения сервера..."
	_refresh_container_panel()

func _selected_list_item_id(list: ItemList) -> String:
	var selected := list.get_selected_items()
	return str(list.get_item_metadata(selected[0])) if not selected.is_empty() else ""

func _item_quantity_label(item: Dictionary) -> String:
	var quantity := int(item.get("quantity", 1))
	var suffix := "x%d" % quantity if quantity > 1 else ""
	if item.get("definitionId", "") == "pistol":
		return "%s\n%d/6" % [suffix, int(item.get("magazineAmmo", 0))] if not suffix.is_empty() else "\n%d/6" % int(item.get("magazineAmmo", 0))
	return suffix

func _on_server_error(code: String) -> void:
	var message: String = ERROR_NAMES.get(code, "Действие отклонено: %s" % code)
	$HUD/Status.text = message
	if not open_container_id.is_empty():
		container_mutation_pending = false
		pending_container_version = -1
		$HUD/ContainerPanel/Margin/Layout/Feedback.text = message
		_refresh_container_panel()

func _touch_enabled() -> bool:
	return OS.has_feature("mobile") or OS.get_name() in ["iOS", "Android"] or OS.get_cmdline_user_args().has("--touch-controls")
