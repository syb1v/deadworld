extends Node

signal status_changed(text: String)
signal snapshot_received(snapshot: Dictionary)
signal inventory_received(items: Array)
signal server_error(code: String)
signal damage_received(event: Dictionary)
signal attack_confirmed(event: Dictionary)
signal reload_confirmed(event: Dictionary)

const INPUT_MOVE := 1
const INPUT_ATTACK := 3
const INPUT_RELOAD := 5
const PLAYER_SNAPSHOT := 10
const DAMAGE_EVENT := 20
const ATTACK_EVENT := 23
const RELOAD_EVENT := 24
const ITEM_PICKUP := 30
const ITEM_DROP := 31
const INVENTORY_SNAPSHOT := 33
const CONTAINER_MUTATE := 41
const ERROR_EVENT := 50
const PROTOCOL_VERSION := 1
const SERVER_KEY := "CHANGE_ME_LOCAL_ONLY"

var client
var socket
var session
var match_id := ""
var player_id := ""
var sequence := 0
var attack_sequence := 0
var reload_sequence := 0
var reconnecting := false

func connect_to_world() -> void:
	status_changed.emit("Авторизация устройства...")
	client = Nakama.create_client(SERVER_KEY, "127.0.0.1", 7350, "http", 3, NakamaLogger.LOG_LEVEL.INFO)
	var auth = await client.authenticate_device_async(_device_id())
	if auth.is_exception():
		status_changed.emit("Ошибка авторизации: %s" % auth)
		return
	session = auth
	player_id = "player:%s" % session.user_id
	socket = Nakama.create_socket_from(client)
	socket.received_match_state.connect(_on_match_state)
	socket.closed.connect(_on_socket_closed.bind(socket))
	var connected = await socket.connect_async(session, true)
	if connected.is_exception():
		status_changed.emit("Ошибка подключения: %s" % connected)
		return
	var rpc = await client.rpc_async(session, "find_world", "{}")
	if rpc.is_exception():
		status_changed.emit("Мир недоступен: %s" % rpc)
		return
	var world = JSON.parse_string(rpc.payload)
	if typeof(world) != TYPE_DICTIONARY or world.get("protocol") != PROTOCOL_VERSION:
		status_changed.emit("Несовместимая версия протокола")
		return
	match_id = world.match_id
	var joined = await _join_loaded_world(socket, match_id)
	if joined.is_exception():
		status_changed.emit("Не удалось войти в мир: %s" % joined)
		return
	status_changed.emit("В сети  |  %s" % player_id)

func send_move(direction: Vector2) -> void:
	if match_id.is_empty() or socket == null:
		return
	sequence += 1
	socket.send_match_state_async(match_id, INPUT_MOVE, JSON.stringify({"x": direction.x, "y": direction.y, "sequence": sequence}))

func pickup(item_id: String, world_version: int) -> void:
	_send_intention(ITEM_PICKUP, {"item_instance_id": item_id, "expected_world_version": world_version})

func drop(item_id: String) -> void:
	_send_intention(ITEM_DROP, {"item_instance_id": item_id})

func attack(weapon_slot: int, aim: Vector2) -> void:
	attack_sequence += 1
	_send_intention(INPUT_ATTACK, {"weapon_slot": weapon_slot, "aim_x": aim.x, "aim_y": aim.y, "sequence": attack_sequence})

func reload(weapon_slot: int) -> void:
	reload_sequence += 1
	_send_intention(INPUT_RELOAD, {"weapon_slot": weapon_slot, "sequence": reload_sequence})

func take_from_container(container_id: String, item_id: String, version: int) -> void:
	_send_intention(CONTAINER_MUTATE, {"container_id": container_id, "item_instance_id": item_id, "expected_version": version, "operation": "take"})

func _send_intention(opcode: int, payload: Dictionary) -> void:
	if not match_id.is_empty():
		socket.send_match_state_async(match_id, opcode, JSON.stringify(payload))

func _on_match_state(state) -> void:
	var snapshot = JSON.parse_string(state.data)
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	if state.op_code == PLAYER_SNAPSHOT and snapshot.get("protocol") == PROTOCOL_VERSION:
		snapshot_received.emit(snapshot)
	elif state.op_code == INVENTORY_SNAPSHOT:
		inventory_received.emit(snapshot.get("items", []))
	elif state.op_code == DAMAGE_EVENT:
		damage_received.emit(snapshot)
	elif state.op_code == ATTACK_EVENT:
		attack_confirmed.emit(snapshot)
	elif state.op_code == RELOAD_EVENT:
		reload_confirmed.emit(snapshot)
	elif state.op_code == ERROR_EVENT:
		server_error.emit(snapshot.get("code", "UNKNOWN_ERROR"))

func _on_socket_closed(closed_socket) -> void:
	if closed_socket != socket:
		return
	match_id = ""
	if reconnecting or session == null:
		return
	reconnecting = true
	status_changed.emit("Соединение потеряно, переподключение...")
	for attempt in range(5):
		await get_tree().create_timer(1.0 + attempt).timeout
		var candidate = Nakama.create_socket_from(client)
		candidate.received_match_state.connect(_on_match_state)
		candidate.closed.connect(_on_socket_closed.bind(candidate))
		var connected = await candidate.connect_async(session, true)
		if connected.is_exception():
			candidate.close()
			continue
		var rpc = await client.rpc_async(session, "find_world", "{}")
		if rpc.is_exception():
			candidate.close()
			continue
		var world = JSON.parse_string(rpc.payload)
		if typeof(world) != TYPE_DICTIONARY or world.get("protocol") != PROTOCOL_VERSION:
			candidate.close()
			break
		var candidate_match_id: String = world.match_id
		var joined = await _join_loaded_world(candidate, candidate_match_id)
		if not joined.is_exception():
			socket = candidate
			match_id = candidate_match_id
			reconnecting = false
			status_changed.emit("В сети  |  %s" % player_id)
			return
		candidate.close()
	reconnecting = false
	status_changed.emit("Не удалось переподключиться")

func _join_loaded_world(target_socket, target_match_id: String):
	var result = await target_socket.join_match_async(target_match_id)
	for attempt in range(9):
		if not result.is_exception():
			return result
		await get_tree().create_timer(0.15).timeout
		result = await target_socket.join_match_async(target_match_id)
	return result

func _device_id() -> String:
	var profile := "default"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=").validate_filename()
	var path := "user://device_id_%s.txt" % profile
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path).strip_edges()
	var id := "deadworld-%s" % Crypto.new().generate_random_bytes(16).hex_encode()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(id)
	return id
