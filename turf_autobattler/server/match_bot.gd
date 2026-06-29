class_name MatchBot
extends Node

## Scripted ENet client — submits intents via RPC using shared bot AI.

var peer_id: int = 0
var _server_path: NodePath = NodePath()
var _connected: bool = false
var _bot_ai: Callable


func configure(server_path: NodePath, bot_ai: Callable) -> void:
	_server_path = server_path
	_bot_ai = bot_ai


func connect_to_server(port: int) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client("127.0.0.1", port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	return OK


func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_connected = false


func play_planning_round() -> void:
	if not _connected:
		return
	var server: MatchServer = get_node(_server_path)
	server.submit_intent_rpc.rpc_id(SERVER_PEER_ID, "LOCK_BOARD", {})


const SERVER_PEER_ID := 1


func _on_connected_to_server() -> void:
	peer_id = multiplayer.get_unique_id()
	_connected = true
	var server: MatchServer = get_node(_server_path)
	server.request_join.rpc_id(SERVER_PEER_ID)
	server.set_ready_rpc.rpc_id(SERVER_PEER_ID, true)
