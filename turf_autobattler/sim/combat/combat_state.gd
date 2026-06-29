class_name CombatState
extends RefCounted

var tick: int = 0
var units: Array[CombatUnit] = []
var event_log: EventLog = EventLog.new()
var rng: SeededRNG = SeededRNG.new()
var outcome: int = SimConstants.CombatOutcome.PENDING


func get_team_units(team_id: int) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	for unit in units:
		if unit.team_id == team_id and unit.alive:
			result.append(unit)
	return result


func find_unit(instance_id: int) -> CombatUnit:
	for unit in units:
		if unit.instance_id == instance_id:
			return unit
	return null


func duplicate_state() -> CombatState:
	var copy := CombatState.new()
	copy.tick = tick
	copy.outcome = outcome
	copy.rng = rng.duplicate_rng()
	copy.event_log = event_log.duplicate_log()
	for unit in units:
		var u := CombatUnit.new()
		u.instance_id = unit.instance_id
		u.def_id = unit.def_id
		u.team_id = unit.team_id
		u.grid_pos = unit.grid_pos
		u.stars = unit.stars
		u.max_hp = unit.max_hp
		u.current_hp = unit.current_hp
		u.attack = unit.attack
		u.attack_speed = unit.attack_speed
		u.armor = unit.armor
		u.range_cells = unit.range_cells
		u.attack_progress = unit.attack_progress
		u.alive = unit.alive
		u.tags = unit.tags.duplicate()
		copy.units.append(u)
	return copy
