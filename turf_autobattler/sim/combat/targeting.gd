class_name CombatTargeting
extends RefCounted

static func pick(attacker: CombatUnit, combat: CombatState) -> CombatUnit:
	var enemies := _living_enemies(attacker, combat)
	if enemies.is_empty():
		return null
	var same_row := _filter_row(enemies, attacker.grid_pos.y)
	var pool: Array[CombatUnit] = same_row if not same_row.is_empty() else enemies
	pool.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.grid_pos.x != b.grid_pos.x:
			return a.grid_pos.x < b.grid_pos.x
		return a.instance_id < b.instance_id
	)
	return pool[0]


static func _living_enemies(attacker: CombatUnit, combat: CombatState) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	for unit in combat.units:
		if unit.alive and unit.team_id != attacker.team_id:
			result.append(unit)
	return result


static func _filter_row(units: Array[CombatUnit], row: int) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	for unit in units:
		if unit.grid_pos.y == row:
			result.append(unit)
	return result
