class_name RivalDirector
extends RefCounted

static func build_enemy_units(round_num: int, start_instance_id: int) -> Dictionary:
	var comp := RivalCompRegistry.get_comp_for_round(round_num)
	var units: Dictionary = {}
	var next_id := start_instance_id
	var board_entries: Array = []
	for entry in comp.get("units", []):
		var unit := UnitInstance.new()
		unit.instance_id = next_id
		unit.def_id = String(entry.get("def_id", ""))
		unit.stars = int(entry.get("stars", 1))
		unit.grid_pos = entry.get("grid_pos", Vector2i.ZERO)
		units[next_id] = unit
		board_entries.append({"unit": unit, "pos": unit.grid_pos})
		next_id += 1
	return {"units": units, "board_entries": board_entries, "next_instance_id": next_id}
