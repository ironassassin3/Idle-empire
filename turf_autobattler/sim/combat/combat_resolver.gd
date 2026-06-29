class_name CombatResolver
extends RefCounted

# Enemy stats ramp +5%/round, but the ramp is capped so a strong, well-leveled
# end-game board can still win the final rounds (the run stays winnable).
# Uncapped, round 15 reached x1.70 and even an over-leveled board lost 100%.
const MAX_ENEMY_SCALE := 1.45

# Stall-breaker: a grindy fight that hasn't ended by this tick is decided by the
# survivors/HP tiebreak in _determine_outcome rather than dragging to the hard
# MAX_COMBAT_TICKS cap. Keeps late-round playback snappy without coin-flips.
# Short/mid fights end well before this, so they are unaffected.
const STALL_RESOLVE_TICK := 300


static func build_combat_state(
	player_units: Array,
	enemy_units: Array,
	player_board: BoardState,
	rng: SeededRNG,
	round_num: int,
) -> CombatState:
	var combat := CombatState.new()
	combat.rng = rng.duplicate_rng()
	var scale := minf(1.0 + float(round_num - 1) * 0.05, MAX_ENEMY_SCALE)
	for entry in player_units:
		var unit: UnitInstance = entry["unit"]
		var pos: Vector2i = entry["pos"]
		combat.units.append(CombatUnit.from_unit_instance(unit, SimConstants.TeamId.PLAYER, pos, 1.0))
	for entry in enemy_units:
		var unit: UnitInstance = entry["unit"]
		var pos: Vector2i = entry["pos"]
		combat.units.append(CombatUnit.from_unit_instance(unit, SimConstants.TeamId.ENEMY, pos, scale))
	TraitCalculator.apply_combat_start_traits(combat.units, SimConstants.TeamId.PLAYER, combat.event_log)
	TraitCalculator.apply_combat_start_traits(combat.units, SimConstants.TeamId.ENEMY, combat.event_log)
	return combat


static func resolve(combat: CombatState, player_board: BoardState) -> CombatState:
	combat.event_log.emit("COMBAT_START", {
		"player_units": _summaries(combat, SimConstants.TeamId.PLAYER),
		"enemy_units": _summaries(combat, SimConstants.TeamId.ENEMY),
	})
	while combat.tick < mini(STALL_RESOLVE_TICK, SimConstants.MAX_COMBAT_TICKS) and not _is_terminal(combat):
		for unit in _get_act_order(combat):
			if not unit.can_act():
				continue
			unit.attack_progress += unit.attack_speed / float(SimConstants.TICKS_PER_SECOND)
			while unit.attack_progress >= 1.0 and unit.can_act():
				unit.attack_progress -= 1.0
				var target := CombatTargeting.pick(unit, combat)
				if target == null:
					break
				combat.event_log.emit("ATTACK_START", {
					"attacker_id": unit.instance_id,
					"target_id": target.instance_id,
				})
				var turf_type := player_board.get_turf_type(unit.grid_pos) if unit.team_id == SimConstants.TeamId.PLAYER else SimConstants.TurfCellType.NEUTRAL
				var result := DamagePipeline.apply(unit, target, turf_type)
				combat.event_log.emit("DAMAGE", result)
				if not target.alive:
					combat.event_log.emit("UNIT_DIED", {
						"instance_id": target.instance_id,
						"team": target.team_id,
					})
		combat.tick += 1
	combat.outcome = _determine_outcome(combat)
	combat.event_log.emit("COMBAT_END", {"outcome": combat.outcome, "tick": combat.tick})
	return combat


static func _get_act_order(combat: CombatState) -> Array[CombatUnit]:
	var living: Array[CombatUnit] = []
	for unit in combat.units:
		if unit.alive:
			living.append(unit)
	living.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.attack_speed != b.attack_speed:
			return a.attack_speed > b.attack_speed
		return a.instance_id < b.instance_id
	)
	return living


static func _is_terminal(combat: CombatState) -> bool:
	return combat.get_team_units(SimConstants.TeamId.PLAYER).is_empty() or combat.get_team_units(SimConstants.TeamId.ENEMY).is_empty()


static func _determine_outcome(combat: CombatState) -> int:
	var player_units := combat.get_team_units(SimConstants.TeamId.PLAYER)
	var enemy_units := combat.get_team_units(SimConstants.TeamId.ENEMY)
	var player_alive := not player_units.is_empty()
	var enemy_alive := not enemy_units.is_empty()
	if player_alive and not enemy_alive:
		return SimConstants.CombatOutcome.PLAYER
	if enemy_alive and not player_alive:
		return SimConstants.CombatOutcome.ENEMY
	if not player_alive and not enemy_alive:
		return SimConstants.CombatOutcome.DRAW
	# Both teams still standing — combat hit the tick cap. Resolve the
	# stalemate the way most autobattlers do: more survivors wins, then more
	# total remaining HP. Avoids timeouts being an arbitrary loss for the
	# side that was actually ahead.
	if player_units.size() != enemy_units.size():
		return SimConstants.CombatOutcome.PLAYER if player_units.size() > enemy_units.size() \
			else SimConstants.CombatOutcome.ENEMY
	var player_hp := 0
	for unit in player_units:
		player_hp += unit.current_hp
	var enemy_hp := 0
	for unit in enemy_units:
		enemy_hp += unit.current_hp
	if player_hp > enemy_hp:
		return SimConstants.CombatOutcome.PLAYER
	if enemy_hp > player_hp:
		return SimConstants.CombatOutcome.ENEMY
	return SimConstants.CombatOutcome.DRAW


static func _summaries(combat: CombatState, team_id: int) -> Array:
	var result: Array = []
	for unit in combat.units:
		if unit.team_id != team_id:
			continue
		result.append({
			"instance_id": unit.instance_id,
			"def_id": unit.def_id,
			"grid_pos": {"x": unit.grid_pos.x, "y": unit.grid_pos.y},
			"hp": unit.current_hp,
		})
	return result
