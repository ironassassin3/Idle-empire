extends Node

## Presentation façade — UI talks to sim only through intents.

signal state_changed
signal phase_changed(new_phase: int)
signal combat_event(event: Dictionary)
signal run_ended(result: Dictionary)

var run_director: RunDirector = RunDirector.new()
var metagame: MetagameState = MetagameState.create_default()
var playback_speed: float = 1.0
var use_network_authority: bool = false

var _network_server: MatchServer = null
var _network_peer_id: int = 2
var _cached_private_state: Dictionary = {}
var _cached_lobby_state: Dictionary = {}

var _playback


func _ready() -> void:
	SaveStore.load_into(self)
	var playback_script: Script = preload("res://presentation/components/combat_playback_director.gd")
	_playback = playback_script.new()
	_playback.speed_multiplier = playback_speed
	add_child(_playback)
	_playback.event_played.connect(_on_playback_event)
	_playback.playback_finished.connect(_on_playback_finished)
	phase_changed.connect(AudioDirector.on_phase_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		SaveStore.save_from(self)


func start_run(run_seed: int = 0) -> void:
	if use_network_authority:
		_start_network_loopback(run_seed)
		return
	run_director = RunDirector.new()
	run_director.start_run(run_seed, MetagameRules.starting_bonuses(metagame.unlocks))
	_emit_state()


func start_network_loopback(run_seed: int = 0) -> void:
	use_network_authority = true
	_start_network_loopback(run_seed)


func _start_network_loopback(_run_seed: int) -> void:
	if _network_server == null:
		_network_server = MatchServer.new()
		add_child(_network_server)
	_network_server.reset_match()
	_network_server.join_peer(_network_peer_id)
	_network_server.set_peer_ready(_network_peer_id, true)
	_network_server.lock_and_start_match(true)
	_apply_private_state(_network_server.get_match_result())
	_emit_state()


func submit_intent(intent: PlayerIntent) -> int:
	if use_network_authority and _network_server != null:
		var result := _network_server.submit_intent_for_peer(_network_peer_id, intent.type, intent.params)
		if result == SimConstants.RejectReason.OK:
			if intent.type == "LOCK_BOARD":
				_begin_playback()
			elif intent.type == "SKIP_PLAYBACK":
				_network_server.submit_intent_for_peer(_network_peer_id, "SKIP_PLAYBACK", {})
				_playback.skip_to_end()
				_check_run_end()
			_apply_private_state(_network_server.get_match_result())
			_emit_state()
		return result
	var result := run_director.submit_intent(intent)
	if result == SimConstants.RejectReason.OK:
		if intent.type == "LOCK_BOARD":
			_begin_playback()
		elif intent.type == "SKIP_PLAYBACK":
			run_director.advance_playback_if_ready()
			_playback.skip_to_end()
			_check_run_end()
		_emit_state()
	return result


func get_run_dto() -> Dictionary:
	if use_network_authority and _cached_private_state.has("run"):
		return _cached_private_state["run"]
	return MatchStateDto.build_run_dto(run_director)


func get_shop_dto() -> Dictionary:
	if use_network_authority and _cached_private_state.has("shop"):
		return _cached_private_state["shop"]
	return MatchStateDto.build_shop_dto(run_director)


func get_bench_dto() -> Array:
	if use_network_authority and _cached_private_state.has("bench"):
		return _cached_private_state["bench"]
	return MatchStateDto.build_bench_dto(run_director)


func get_board_dto() -> Dictionary:
	if use_network_authority and _cached_private_state.has("board"):
		return _cached_private_state["board"]
	return MatchStateDto.build_board_dto(run_director)


func get_display_dto() -> Dictionary:
	var dto := get_board_dto()
	var phase := run_director.state.phase
	if phase != SimConstants.RunPhase.COMBAT_PLAYBACK and phase != SimConstants.RunPhase.COMBAT_RESOLVE:
		return dto
	if run_director.state.last_combat == null:
		return dto
	var combat_mode := true
	var cell_map := {}
	for cell in dto["cells"]:
		cell_map[SimGrid.pos_key(cell["pos"])] = cell
	for unit in run_director.state.last_combat.units:
		var key := SimGrid.pos_key(unit.grid_pos)
		var unit_dto := {
			"instance_id": unit.instance_id,
			"def_id": unit.def_id,
			"display_name": UnitRegistry.get_def(unit.def_id).get("display_name", unit.def_id),
			"stars": unit.stars,
			"team": unit.team_id,
			"alive": unit.alive,
		}
		if cell_map.has(key):
			cell_map[key]["unit"] = unit_dto
		else:
			cell_map[key] = {
				"pos": unit.grid_pos,
				"turf": SimConstants.TurfCellType.NEUTRAL,
				"unit": unit_dto,
			}
	dto["cells"] = cell_map.values()
	dto["combat_mode"] = combat_mode
	return dto


func get_trait_dto() -> Array:
	if use_network_authority and _cached_private_state.has("traits"):
		return _cached_private_state["traits"]
	return MatchStateDto.build_trait_dto(run_director)


func get_lobby_dto() -> Dictionary:
	return _cached_lobby_state


func _apply_private_state(match_result: Dictionary) -> void:
	_cached_lobby_state = match_result.get("lobby_dto", {})
	if _network_server != null and _network_server.directors.has(_network_peer_id):
		run_director = _network_server.directors[_network_peer_id]
		_cached_private_state = MatchStateDto.build_private_state(run_director)


func skip_playback() -> void:
	submit_intent(PlayerIntent.make("SKIP_PLAYBACK"))


func _unit_dto(unit: UnitInstance) -> Dictionary:
	var def := UnitRegistry.get_def(unit.def_id)
	return {
		"instance_id": unit.instance_id,
		"def_id": unit.def_id,
		"display_name": def.get("display_name", unit.def_id),
		"cost": def.get("cost", 0),
		"stars": unit.stars,
		"tags": def.get("tags", []),
	}


func _begin_playback() -> void:
	if run_director.state.last_combat == null:
		return
	var events: Array = []
	for event in run_director.state.last_combat.event_log.events:
		events.append(event)
	_playback.speed_multiplier = playback_speed
	_playback.start(events)
	phase_changed.emit(run_director.state.phase)


func _on_playback_event(event: Dictionary) -> void:
	combat_event.emit(event)
	AudioDirector.on_combat_event(event)


func _on_playback_finished() -> void:
	if run_director.state.phase != SimConstants.RunPhase.COMBAT_PLAYBACK:
		return
	run_director.finish_playback()
	_check_run_end()
	_emit_state()


func _check_run_end() -> void:
	if run_director.state.phase == SimConstants.RunPhase.RUN_END:
		var won := run_director.state.run_won
		var result := MetagameRules.build_run_result(run_director.state, won)
		metagame.apply_run_result(result)
		SaveStore.save_from(self)
		run_ended.emit(result)


func _emit_state() -> void:
	state_changed.emit()
	phase_changed.emit(run_director.state.phase)
