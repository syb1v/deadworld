extends Node2D

const PlayerScript = preload("res://scripts/entities/Player.gd")
var players: Dictionary = {}
var send_accumulator := 0.0

func _ready() -> void:
	Network.status_changed.connect(func(text: String): $Status.text = text)
	Network.snapshot_received.connect(_on_snapshot)
	_draw_grid()
	Network.connect_to_world()

func _process(delta: float) -> void:
	send_accumulator += delta
	if send_accumulator >= 1.0 / 20.0:
		send_accumulator = 0.0
		Network.send_move(Input.get_vector("move_left", "move_right", "move_up", "move_down"))

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
