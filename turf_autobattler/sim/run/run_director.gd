class_name RunDirector
extends RefCounted

var state: RunState = RunState.new()
var skip_playback_requested: bool = false


func start_run(run_seed: int = 0, bonuses: Dictionary = {}) -> RunState:
	state = RunState.new()
	state.seed = run_seed if run_seed != 0 else 12345
	state.rng = SeededRNG.from_seed(state.seed)
	var start_xp := int(bonuses.get("start_xp", 0))
	if start_xp > 0:
		state.xp += start_xp
		state.level = EconomyRules.level_from_xp(state.xp)
	state.board.set_max_units_for_level(state.level)
	state.gold = SimConstants.BASE_GOLD_PER_ROUND + int(bonuses.get("start_gold", 0))
	_roll_shop()
	_set_phase(SimConstants.RunPhase.PLANNING)
	state.run_events.emit("ROUND_STARTED", {"round": state.round})
	return state


func submit_intent(intent: PlayerIntent) -> int:
	var reason := IntentValidator.validate(intent, state)
	if reason != SimConstants.RejectReason.OK:
		return reason
	match intent.type:
		"BUY_FROM_SHOP":
			_buy_from_shop(int(intent.params.get("index", 0)))
		"SELL":
			_sell_unit(int(intent.params.get("instance_id", -1)))
		"REROLL_SHOP":
			_reroll_shop()
		"BUY_XP":
			_buy_xp()
		"MOVE_TO_BENCH":
			_move_to_bench(int(intent.params.get("instance_id", -1)), int(intent.params.get("slot", -1)))
		"MOVE_TO_BOARD":
			_move_to_board(int(intent.params.get("instance_id", -1)), intent.params.get("grid_pos", Vector2i.ZERO))
		"SWAP_ON_BOARD":
			_swap_on_board(intent.params.get("a", Vector2i.ZERO), intent.params.get("b", Vector2i.ZERO))
		"LOCK_BOARD":
			_lock_board()
		"SKIP_PLAYBACK":
			skip_playback_requested = true
	return SimConstants.RejectReason.OK


func advance_playback_if_ready() -> bool:
	if state.phase != SimConstants.RunPhase.COMBAT_PLAYBACK:
		return false
	if skip_playback_requested:
		skip_playback_requested = false
		_finish_round()
		return true
	return false


func finish_playback() -> void:
	if state.phase == SimConstants.RunPhase.COMBAT_PLAYBACK:
		_finish_round()


func _buy_from_shop(index: int) -> void:
	var def_id = state.shop.offers[index]
	var def := UnitRegistry.get_def(String(def_id))
	state.gold -= int(def.get("cost", 0))
	state.shop_pool.buy(String(def_id))
	var unit := UnitInstance.new()
	unit.instance_id = state.next_instance_id
	state.next_instance_id += 1
	unit.def_id = String(def_id)
	unit.bench_slot = state.bench.first_empty_slot()
	state.bench.slots[unit.bench_slot] = unit.instance_id
	state.units[unit.instance_id] = unit
	state.shop.offers[index] = null
	_emit_gold(-int(def.get("cost", 0)), "buy")


func _sell_unit(instance_id: int) -> void:
	var unit: UnitInstance = state.units[instance_id]
	var def := UnitRegistry.get_def(unit.def_id)
	var refund := int(def.get("sell_value", 1))
	if unit.bench_slot >= 0:
		state.bench.slots[unit.bench_slot] = null
	if unit.grid_pos.x >= 0:
		state.board.set_unit_at(unit.grid_pos, null)
	state.shop_pool.return_unit(unit.def_id)
	state.units.erase(instance_id)
	state.gold += refund
	state.refresh_traits()
	_emit_gold(refund, "sell")


func _reroll_shop() -> void:
	state.gold -= SimConstants.REROLL_COST
	_roll_shop()
	_emit_gold(-SimConstants.REROLL_COST, "reroll")


func _buy_xp() -> void:
	state.gold -= SimConstants.XP_BUY_COST
	state.xp += SimConstants.XP_BUY_AMOUNT
	var new_level := EconomyRules.level_from_xp(state.xp)
	if new_level != state.level:
		state.level = new_level
		state.board.set_max_units_for_level(state.level)
	_emit_gold(-SimConstants.XP_BUY_COST, "buy_xp")


func _move_to_bench(instance_id: int, slot: int) -> void:
	var unit: UnitInstance = state.units[instance_id]
	if unit.bench_slot >= 0:
		state.bench.slots[unit.bench_slot] = null
	if unit.grid_pos.x >= 0:
		state.board.set_unit_at(unit.grid_pos, null)
		unit.grid_pos = Vector2i(-1, -1)
	if state.bench.slots[slot] != null:
		var other_id: int = state.bench.slots[slot]
		var other: UnitInstance = state.units[other_id]
		other.bench_slot = unit.bench_slot if unit.bench_slot >= 0 else state.bench.first_empty_slot()
		if other.bench_slot >= 0:
			state.bench.slots[other.bench_slot] = other_id
	unit.bench_slot = slot
	state.bench.slots[slot] = instance_id
	state.refresh_traits()


func _move_to_board(instance_id: int, pos: Vector2i) -> void:
	var unit: UnitInstance = state.units[instance_id]
	if unit.bench_slot >= 0:
		state.bench.slots[unit.bench_slot] = null
		unit.bench_slot = -1
	if unit.grid_pos.x >= 0:
		state.board.set_unit_at(unit.grid_pos, null)
	unit.grid_pos = pos
	state.board.set_unit_at(pos, instance_id)
	state.refresh_traits()
	state.run_events.emit("TRAIT_UPDATED", {"active_traits": state.traits_cache})


func _swap_on_board(a: Vector2i, b: Vector2i) -> void:
	var id_a = state.board.get_unit_at(a)
	var id_b = state.board.get_unit_at(b)
	state.board.set_unit_at(a, id_b)
	state.board.set_unit_at(b, id_a)
	var unit_a: UnitInstance = state.units[id_a]
	var unit_b: UnitInstance = state.units[id_b]
	unit_a.grid_pos = b
	unit_b.grid_pos = a
	state.refresh_traits()


func _lock_board() -> void:
	_set_phase(SimConstants.RunPhase.COMBAT_RESOLVE)
	var player_entries := _player_board_entries()
	var enemy_data := RivalDirector.build_enemy_units(state.round, state.next_instance_id + 10000)
	var combat := CombatResolver.build_combat_state(
		player_entries,
		enemy_data["board_entries"],
		state.board,
		state.rng,
		state.round,
	)
	state.last_combat = CombatResolver.resolve(combat, state.board)
	state.last_combat_won = state.last_combat.outcome == SimConstants.CombatOutcome.PLAYER
	_set_phase(SimConstants.RunPhase.COMBAT_PLAYBACK)


func _finish_round() -> void:
	_set_phase(SimConstants.RunPhase.ROUND_RESOLVE)
	var won := state.last_combat_won
	if won:
		state.win_streak += 1
		state.loss_streak = 0
	else:
		state.loss_streak += 1
		state.win_streak = 0
		var survivors := 0
		var star_total := 0
		for unit in state.last_combat.units:
			if unit.team_id == SimConstants.TeamId.ENEMY and unit.alive:
				survivors += 1
				star_total += unit.stars
		var hp_loss := EconomyRules.hp_loss_on_defeat(survivors, star_total)
		state.player_hp -= hp_loss
		state.run_events.emit("HP_CHANGED", {"delta": -hp_loss, "reason": "combat_loss"})
	state.xp += EconomyRules.round_xp_gain(won)
	state.level = EconomyRules.level_from_xp(state.xp)
	state.board.set_max_units_for_level(state.level)
	var payout := EconomyRules.round_gold_payout(state.gold, won, state.win_streak, state.loss_streak)
	state.gold += payout
	state.run_events.emit("GOLD_CHANGED", {"delta": payout, "reason": "round_payout"})
	if state.player_hp <= 0:
		_end_run(false)
		return
	if state.round >= SimConstants.MAX_ROUNDS and won:
		_end_run(true)
		return
	state.round += 1
	_roll_shop()
	_set_phase(SimConstants.RunPhase.PLANNING)
	state.run_events.emit("ROUND_STARTED", {"round": state.round})


func _end_run(won: bool) -> void:
	state.run_won = won
	_set_phase(SimConstants.RunPhase.RUN_END)
	state.run_events.emit("RUN_ENDED", {
		"result": "win" if won else "loss",
		"rounds_survived": state.round,
	})


func _roll_shop() -> void:
	state.shop.offers = state.shop_pool.roll(state.level, state.rng)
	state.run_events.emit("SHOP_ROLLED", {"offers": state.shop.offers.duplicate()})


func _player_board_entries() -> Array:
	var entries: Array = []
	for key in state.board.slots.keys():
		var instance_id: int = state.board.slots[key]
		var unit: UnitInstance = state.units[instance_id]
		entries.append({"unit": unit, "pos": unit.grid_pos})
	return entries


func _set_phase(new_phase: int) -> void:
	var old := state.phase
	state.phase = new_phase
	state.run_events.emit("PHASE_CHANGED", {"from": old, "to": new_phase})


func _emit_gold(delta: int, reason: String) -> void:
	state.run_events.emit("GOLD_CHANGED", {"delta": delta, "reason": reason})
