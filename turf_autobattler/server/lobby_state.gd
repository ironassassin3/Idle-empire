class_name LobbyState
extends RefCounted

## Match lobby lifecycle — pure sim, snapshot-able, no transport.
## LOBBY_WAITING → LOBBY_LOCKED → MATCH_RUNNING → MATCH_ENDED → LOBBY_WAITING

enum Phase {
	LOBBY_WAITING,
	LOBBY_LOCKED,
	MATCH_RUNNING,
	MATCH_ENDED,
}

enum LobbyRejectReason {
	OK,
	WRONG_PHASE,
	LOBBY_FULL,
	UNKNOWN_PEER,
	ALREADY_JOINED,
	NOT_ENOUGH_PLAYERS,
	NOT_ALL_READY,
	INVALID_TRANSITION,
}

const MAX_PLAYERS := 8

var phase: int = Phase.LOBBY_WAITING
var match_seed: int = 0
var host_peer_id: int = 0
var round: int = 0
var run_phase: int = SimConstants.RunPhase.RUN_INIT
var prep_timer_ticks: int = 0
var pool_remaining_by_tier: Dictionary = {}
var _players_by_peer: Dictionary = {}
var _players_by_id: Dictionary = {}
var _next_player_id: int = 0


static func derive_match_seed(peer_ids: Array) -> int:
	var sorted_ids: Array = peer_ids.duplicate()
	sorted_ids.sort()
	var hash_value := 2166136261
	for peer_id in sorted_ids:
		hash_value = hash_value ^ int(peer_id)
		hash_value = int((hash_value * 16777619) & 0x7fffffff)
	return maxi(1, hash_value)


static func derive_player_rng_seed(seed_value: int, player_id: int) -> int:
	return maxi(1, int(seed_value) ^ int(player_id))


func add_player(peer_id: int) -> int:
	if phase != Phase.LOBBY_WAITING:
		return LobbyRejectReason.WRONG_PHASE
	if peer_id <= 0:
		return LobbyRejectReason.UNKNOWN_PEER
	if _players_by_peer.has(peer_id):
		return LobbyRejectReason.ALREADY_JOINED
	if _players_by_peer.size() >= MAX_PLAYERS:
		return LobbyRejectReason.LOBBY_FULL
	if host_peer_id == 0:
		host_peer_id = peer_id
	var player_id := _next_player_id
	_next_player_id += 1
	var record := {
		"peer_id": peer_id,
		"player_id": player_id,
		"ready": false,
		"hp": SimConstants.STARTING_HP,
		"alive": true,
		"disconnected": false,
	}
	_players_by_peer[peer_id] = record
	_players_by_id[player_id] = record
	return LobbyRejectReason.OK


func remove_player(peer_id: int) -> int:
	if phase != Phase.LOBBY_WAITING:
		return LobbyRejectReason.WRONG_PHASE
	if not _players_by_peer.has(peer_id):
		return LobbyRejectReason.UNKNOWN_PEER
	var record: Dictionary = _players_by_peer[peer_id]
	_players_by_peer.erase(peer_id)
	_players_by_id.erase(record["player_id"])
	if host_peer_id == peer_id:
		host_peer_id = _first_peer_id()
	return LobbyRejectReason.OK


func set_ready(peer_id: int, ready: bool) -> int:
	if phase != Phase.LOBBY_WAITING:
		return LobbyRejectReason.WRONG_PHASE
	if not _players_by_peer.has(peer_id):
		return LobbyRejectReason.UNKNOWN_PEER
	_players_by_peer[peer_id]["ready"] = ready
	return LobbyRejectReason.OK


func lock_lobby(force: bool = false) -> int:
	if phase != Phase.LOBBY_WAITING:
		return LobbyRejectReason.WRONG_PHASE
	if _players_by_peer.is_empty():
		return LobbyRejectReason.NOT_ENOUGH_PLAYERS
	if not force and _players_by_peer.size() < MAX_PLAYERS and not _all_players_ready():
		return LobbyRejectReason.NOT_ALL_READY
	_finalize_lock()
	return LobbyRejectReason.OK


func start_match() -> int:
	if phase != Phase.LOBBY_LOCKED:
		return LobbyRejectReason.WRONG_PHASE
	phase = Phase.MATCH_RUNNING
	round = 1
	run_phase = SimConstants.RunPhase.PLANNING
	prep_timer_ticks = 0
	for record in _players_by_peer.values():
		record["hp"] = SimConstants.STARTING_HP
		record["alive"] = true
		record["disconnected"] = false
	return LobbyRejectReason.OK


func mark_disconnected(peer_id: int) -> int:
	if not _players_by_peer.has(peer_id):
		return LobbyRejectReason.UNKNOWN_PEER
	_players_by_peer[peer_id]["disconnected"] = true
	return LobbyRejectReason.OK


func eliminate_player(player_id: int) -> int:
	if phase != Phase.MATCH_RUNNING:
		return LobbyRejectReason.WRONG_PHASE
	if not _players_by_id.has(player_id):
		return LobbyRejectReason.UNKNOWN_PEER
	var record: Dictionary = _players_by_id[player_id]
	record["alive"] = false
	record["hp"] = 0
	if _alive_player_count() <= 1:
		phase = Phase.MATCH_ENDED
	return LobbyRejectReason.OK


func end_match(_winner_player_id: int = -1) -> int:
	if phase != Phase.MATCH_RUNNING:
		return LobbyRejectReason.WRONG_PHASE
	phase = Phase.MATCH_ENDED
	return LobbyRejectReason.OK


func reset_to_lobby() -> int:
	if phase != Phase.MATCH_ENDED:
		return LobbyRejectReason.WRONG_PHASE
	_reset_waiting_lobby()
	return LobbyRejectReason.OK


func get_player_record(peer_id: int) -> Dictionary:
	if not _players_by_peer.has(peer_id):
		return {}
	return _duplicate_player_record(_players_by_peer[peer_id])


func get_player_record_by_id(player_id: int) -> Dictionary:
	if not _players_by_id.has(player_id):
		return {}
	return _duplicate_player_record(_players_by_id[player_id])


func get_alive_player_ids() -> Array:
	var result: Array = []
	for record in _players_by_id.values():
		if record["alive"]:
			result.append(int(record["player_id"]))
	result.sort()
	return result


func get_peer_ids() -> Array:
	var result: Array = _players_by_peer.keys()
	result.sort()
	return result


func get_player_count() -> int:
	return _players_by_peer.size()


func duplicate_state() -> LobbyState:
	var copy := LobbyState.new()
	copy.phase = phase
	copy.match_seed = match_seed
	copy.host_peer_id = host_peer_id
	copy.round = round
	copy.run_phase = run_phase
	copy.prep_timer_ticks = prep_timer_ticks
	copy.pool_remaining_by_tier = pool_remaining_by_tier.duplicate(true)
	copy._next_player_id = _next_player_id
	for peer_id in _players_by_peer.keys():
		var record: Dictionary = _players_by_peer[peer_id]
		var record_copy := _duplicate_player_record(record)
		copy._players_by_peer[peer_id] = record_copy
		copy._players_by_id[int(record_copy["player_id"])] = record_copy
	return copy


func to_dto() -> Dictionary:
	var hp_ladder := {}
	var players: Array = []
	for record in _players_by_id.values():
		var player_id := int(record["player_id"])
		hp_ladder[player_id] = int(record["hp"])
		players.append({
			"peer_id": int(record["peer_id"]),
			"player_id": player_id,
			"ready": bool(record["ready"]),
			"alive": bool(record["alive"]),
			"disconnected": bool(record["disconnected"]),
		})
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["player_id"]) < int(b["player_id"]))
	return {
		"phase": phase,
		"match_seed": match_seed,
		"host_peer_id": host_peer_id,
		"round": round,
		"run_phase": run_phase,
		"prep_timer_ticks": prep_timer_ticks,
		"hp_ladder": hp_ladder,
		"alive_ids": get_alive_player_ids(),
		"players": players,
		"pool_remaining_by_tier": pool_remaining_by_tier.duplicate(true),
	}


func dto_fingerprint() -> int:
	return str(to_dto()).hash()


func _finalize_lock() -> void:
	phase = Phase.LOBBY_LOCKED
	var peer_ids: Array = _players_by_peer.keys()
	peer_ids.sort()
	match_seed = derive_match_seed(peer_ids)
	for record in _players_by_peer.values():
		record["hp"] = SimConstants.STARTING_HP
		record["alive"] = true
		record["disconnected"] = false


func _reset_waiting_lobby() -> void:
	phase = Phase.LOBBY_WAITING
	match_seed = 0
	host_peer_id = 0
	round = 0
	run_phase = SimConstants.RunPhase.RUN_INIT
	prep_timer_ticks = 0
	pool_remaining_by_tier.clear()
	_players_by_peer.clear()
	_players_by_id.clear()
	_next_player_id = 0


func _all_players_ready() -> bool:
	if _players_by_peer.is_empty():
		return false
	for record in _players_by_peer.values():
		if not record["ready"]:
			return false
	return true


func _alive_player_count() -> int:
	var count := 0
	for record in _players_by_id.values():
		if record["alive"]:
			count += 1
	return count


func _first_peer_id() -> int:
	if _players_by_peer.is_empty():
		return 0
	var peer_ids: Array = _players_by_peer.keys()
	peer_ids.sort()
	return int(peer_ids[0])


func _duplicate_player_record(record: Dictionary) -> Dictionary:
	return {
		"peer_id": int(record["peer_id"]),
		"player_id": int(record["player_id"]),
		"ready": bool(record["ready"]),
		"hp": int(record["hp"]),
		"alive": bool(record["alive"]),
		"disconnected": bool(record["disconnected"]),
	}
