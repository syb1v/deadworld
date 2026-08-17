extends Node2D

const PlayerScript = preload("res://scripts/entities/Player.gd")
const ZombieScript = preload("res://scripts/entities/Zombie.gd")
const WorldItemScript = preload("res://scripts/entities/WorldItem.gd")
const ContainerScript = preload("res://scripts/entities/Container.gd")
var players: Dictionary = {}
var zombies: Dictionary = {}
var world_items: Dictionary = {}
var containers: Dictionary = {}
var inventory: Array = []
var world_version := 0
var send_accumulator := 0.0

func _ready() -> void:
	Network.status_changed.connect(func(text: String): $Status.text = text)
	Network.snapshot_received.connect(_on_snapshot)
	Network.inventory_received.connect(_on_inventory)
	Network.server_error.connect(func(code: String): $Status.text = "Rejected: %s" % code)
	_draw_grid()
	Network.connect_to_world()

func _process(delta: float) -> void:
	send_accumulator += delta
	if send_accumulator >= 1.0 / 20.0:
		send_accumulator = 0.0
		Network.send_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if Input.is_action_just_pressed("interact"):
		_interact()
	if Input.is_action_just_pressed("drop_item") and not inventory.is_empty():
		Network.drop(inventory[0].id)

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
	$Inventory.text = "Inventory (%d/8)\n%s" % [items.size(), "\n".join(items.map(func(item): return item.definitionId))]

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
