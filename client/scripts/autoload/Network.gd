extends Node

signal status_changed(text: String)
signal snapshot_received(snapshot: Dictionary)
signal inventory_received(items: Array)
signal server_error(code: String)

const INPUT_MOVE := 1
const PLAYER_SNAPSHOT := 10
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

func connect_to_world() -> void:
	status_changed.emit("Authenticating device...")
	client = Nakama.create_client(SERVER_KEY, "127.0.0.1", 7350, "http", 3, NakamaLogger.LOG_LEVEL.INFO)
	var auth = await client.authenticate_device_async(_device_id())
	if auth.is_exception():
		status_changed.emit("Authentication failed: %s" % auth)
		return
	session = auth
	player_id = "player:%s" % session.user_id
	socket = Nakama.create_socket_from(client)
	socket.received_match_state.connect(_on_match_state)
	socket.closed.connect(_on_socket_closed)
	var connected = await socket.connect_async(session, true)
	if connected.is_exception():
		status_changed.emit("Socket failed: %s" % connected)
		return
	var rpc = await client.rpc_async(session, "find_world", "{}")
	if rpc.is_exception():
		status_changed.emit("World lookup failed: %s" % rpc)
		return
	var world = JSON.parse_string(rpc.payload)
	if typeof(world) != TYPE_DICTIONARY or world.get("protocol") != PROTOCOL_VERSION:
		status_changed.emit("Protocol mismatch")
		return
	match_id = world.match_id
	var joined = await socket.join_match_async(match_id)
	if joined.is_exception():
		status_changed.emit("Join failed: %s" % joined)
		return
	status_changed.emit("Online  |  %s" % player_id)

func send_move(direction: Vector2) -> void:
	if match_id.is_empty() or socket == null:
		return
	sequence += 1
	socket.send_match_state_async(match_id, INPUT_MOVE, JSON.stringify({"x": direction.x, "y": direction.y, "sequence": sequence}))

func pickup(item_id: String, world_version: int) -> void:
	_send_intention(ITEM_PICKUP, {"item_instance_id": item_id, "expected_world_version": world_version})

func drop(item_id: String) -> void:
	_send_intention(ITEM_DROP, {"item_instance_id": item_id})

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
	elif state.op_code == ERROR_EVENT:
		server_error.emit(snapshot.get("code", "UNKNOWN_ERROR"))

func _on_socket_closed() -> void:
	match_id = ""
	status_changed.emit("Disconnected")

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
