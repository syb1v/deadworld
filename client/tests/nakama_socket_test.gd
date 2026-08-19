extends SceneTree

func _init() -> void:
	var adapter := NakamaSocketAdapter.new()
	root.add_child(adapter)
	var socket := NakamaSocket.new(adapter, "game.example.com", 443, "wss")
	var uri: String = socket.websocket_uri("token+with/value=", true)
	_assert(uri == "wss://game.example.com/ws?lang=en&status=true&token=token%2Bwith%2Fvalue%3D", "session token is URL encoded")
	quit()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Nakama socket test failed: %s" % message)
	quit(1)
