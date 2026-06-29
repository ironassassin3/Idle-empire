class_name MatchServer
extends Node

## Authoritative match host — owns lobby lifecycle, per-peer RunDirectors, and RPC surface.

signal match_finished(result: Dictionary)

const DEFAULT_PORT := 9123
const SERVER_PEER_ID := 1

var lobby: LobbyState = LobbyState.new()
var directors: Dictionary = {}
var shared_shop_pool: ShopPool = ShopPool.create_default()

var _port: int = DEFAULT_PORT
var _headless_mode: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func configure_headless(port: int = DEFAULT_PORT) -> void:
	_headless_mode = true
	_port = port


func start_enet_server(port: int = DEFAULT_PORT) -> int:
	_port = port
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, LobbyState.MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func stop_enet() -> void:
	if not is_inside_tree() or multiplayer.multiplayer_peer == null:
		return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func reset_match() -> void:
	directors.clear()
	shared_shop_pool = ShopPool.create_default()
	lobby = LobbyState.new()


func join_peer(peer_id: int) -> int:
	return lobby.add_player(peer_id)


func set_peer_ready(peer_id: int, ready: bool) -> int:
	return lobby.set_ready(peer_id, ready)


func lock_and_start_match(force: bool = false) -> int:
	var lock_result := lobby.lock_lobby(force)
	if lock_result != LobbyState.LobbyRejectReason.OK:
		return lock_result
	_spawn_directors_for_locked_lobby()
	var start_result := lobby.start_match()
	if start_result != LobbyState.LobbyRejectReason.OK:
		return start_result
	_sync_pool_remaining_to_lobby()
	_broadcast_lobby_state()
	return LobbyState.LobbyRejectReason.OK


func submit_intent_for_peer(peer_id: int, intent_type: String, params: Dictionary = {}) -> int:
	if lobby.phase != LobbyState.Phase.MATCH_RUNNING:
		return SimConstants.RejectReason.WRONG_PHASE
	if not directors.has(peer_id):
		return SimConstants.RejectReason.NOT_YOUR_BOARD
	var director: RunDirector = directors[peer_id]
	var intent := PlayerIntent.make(intent_type, params)
	var reason := director.submit_intent(intent)
	if reason != SimConstants.RejectReason.OK:
		return reason
	_sync_player_hp_from_director(peer_id)
	if intent.type == "LOCK_BOARD":
		director.finish_playback()
		_check_elimination(peer_id)
		_check_match_end()
	_sync_pool_remaining_to_lobby()
	_replicate_private_state(peer_id)
	_broadcast_lobby_state()
	return SimConstants.RejectReason.OK


func run_bot_round_step(bot_ai: Callable) -> void:
	if lobby.phase != LobbyState.Phase.MATCH_RUNNING:
		return
	for peer_id in directors.keys():
		var director: RunDirector = directors[peer_id]
		if director.state.phase != SimConstants.RunPhase.PLANNING:
			continue
		var record: Dictionary = lobby.get_player_record(peer_id)
		if record.is_empty() or not record["alive"]:
			continue
		bot_ai.call(director)
		submit_intent_for_peer(peer_id, "LOCK_BOARD")


func get_match_result() -> Dictionary:
	var board_hashes := {}
	for peer_id in directors.keys():
		var record: Dictionary = lobby.get_player_record(peer_id)
		if record.is_empty():
			continue
		board_hashes[int(record["player_id"])] = MatchStateDto.board_hash(directors[peer_id])
	return {
		"lobby_dto": lobby.to_dto(),
		"board_hashes": board_hashes,
		"alive_ids": lobby.get_alive_player_ids(),
	}


@rpc("any_peer", "call_remote", "reliable")
func request_join() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var result := join_peer(peer_id)
	if result == LobbyState.LobbyRejectReason.OK:
		replicate_lobby_state.rpc(lobby.to_dto())
	else:
		intent_result.rpc_id(peer_id, result, "JOIN")


@rpc("any_peer", "call_remote", "reliable")
func set_ready_rpc(ready: bool) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var result := set_peer_ready(peer_id, ready)
	if result == LobbyState.LobbyRejectReason.OK:
		replicate_lobby_state.rpc(lobby.to_dto())
	else:
		intent_result.rpc_id(peer_id, result, "SET_READY")


@rpc("any_peer", "call_remote", "reliable")
func lock_lobby_rpc(force: bool = false) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id != lobby.host_peer_id:
		intent_result.rpc_id(peer_id, SimConstants.RejectReason.NOT_YOUR_BOARD, "LOCK_LOBBY")
		return
	var result := lock_and_start_match(force)
	if result != LobbyState.LobbyRejectReason.OK:
		intent_result.rpc_id(peer_id, result, "LOCK_LOBBY")
		return
	replicate_lobby_state.rpc(lobby.to_dto())
	for connected_peer in directors.keys():
		_replicate_private_state(connected_peer)


@rpc("any_peer", "call_remote", "reliable")
func submit_intent_rpc(intent_type: String, params: Dictionary) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	var reason := submit_intent_for_peer(peer_id, intent_type, params)
	intent_result.rpc_id(peer_id, reason, intent_type)
	if reason == SimConstants.RejectReason.OK:
		_replicate_private_state(peer_id)


@rpc("authority", "call_remote", "reliable")
func replicate_lobby_state(dto: Dictionary) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func replicate_private_state(dto: Dictionary) -> void:
	pass


@rpc("authority", "call_remote", "reliable")
func intent_result(reason: int, intent_type: String) -> void:
	pass


func _spawn_directors_for_locked_lobby() -> void:
	directors.clear()
	for peer_id in lobby.get_peer_ids():
		var record: Dictionary = lobby.get_player_record(peer_id)
		var player_id := int(record["player_id"])
		var run_seed := LobbyState.derive_player_rng_seed(lobby.match_seed, player_id)
		var director := RunDirector.new()
		director.start_run(run_seed)
		directors[peer_id] = director


func _sync_player_hp_from_director(peer_id: int) -> void:
	var record: Dictionary = lobby.get_player_record(peer_id)
	if record.is_empty():
		return
	var director: RunDirector = directors[peer_id]
	record["hp"] = director.state.player_hp


func _check_elimination(peer_id: int) -> void:
	var record: Dictionary = lobby.get_player_record(peer_id)
	if record.is_empty():
		return
	var director: RunDirector = directors[peer_id]
	if director.state.player_hp <= 0 and record["alive"]:
		lobby.eliminate_player(int(record["player_id"]))


func _check_match_end() -> void:
	if lobby.get_alive_player_ids().size() <= 1 and lobby.phase == LobbyState.Phase.MATCH_RUNNING:
		lobby.end_match()
		match_finished.emit(get_match_result())
		_broadcast_lobby_state()


func _sync_pool_remaining_to_lobby() -> void:
	lobby.pool_remaining_by_tier.clear()
	for def_id in shared_shop_pool.remaining.keys():
		var def := UnitRegistry.get_def(String(def_id))
		var tier := int(def.get("tier", 1))
		var tier_key := str(tier)
		lobby.pool_remaining_by_tier[tier_key] = int(lobby.pool_remaining_by_tier.get(tier_key, 0)) + int(shared_shop_pool.remaining[def_id])


func _broadcast_lobby_state() -> void:
	if not _can_replicate():
		return
	replicate_lobby_state.rpc(lobby.to_dto())


func _replicate_private_state(peer_id: int) -> void:
	if not directors.has(peer_id):
		return
	if not _can_replicate():
		return
	var dto := MatchStateDto.build_private_state(directors[peer_id])
	replicate_private_state.rpc_id(peer_id, dto)


func _can_replicate() -> bool:
	return is_inside_tree() and multiplayer.multiplayer_peer != null


func _on_peer_connected(peer_id: int) -> void:
	if _headless_mode or not _can_replicate():
		return
	join_peer(peer_id)
	replicate_lobby_state.rpc_id(peer_id, lobby.to_dto())


func _on_peer_disconnected(peer_id: int) -> void:
	lobby.mark_disconnected(peer_id)
	if lobby.phase == LobbyState.Phase.LOBBY_WAITING:
		lobby.remove_player(peer_id)
	elif directors.has(peer_id):
		var record: Dictionary = lobby.get_player_record(peer_id)
		if not record.is_empty() and record["alive"]:
			lobby.eliminate_player(int(record["player_id"]))
	_broadcast_lobby_state()
