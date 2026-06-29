class_name MatchStateDto
extends RefCounted

## Server-side DTO builders — same shape as RunBridge replication payloads.


static func build_private_state(director: RunDirector) -> Dictionary:
	return {
		"run": build_run_dto(director),
		"shop": build_shop_dto(director),
		"bench": build_bench_dto(director),
		"board": build_board_dto(director),
		"traits": build_trait_dto(director),
	}


static func build_run_dto(director: RunDirector) -> Dictionary:
	var s := director.state
	return {
		"seed": s.seed,
		"round": s.round,
		"phase": s.phase,
		"player_hp": s.player_hp,
		"gold": s.gold,
		"level": s.level,
		"xp": s.xp,
		"win_streak": s.win_streak,
		"loss_streak": s.loss_streak,
		"max_units": s.board.max_units,
	}


static func build_shop_dto(director: RunDirector) -> Dictionary:
	return {
		"offers": director.state.shop.offers.duplicate(),
		"reroll_cost": SimConstants.REROLL_COST,
	}


static func build_bench_dto(director: RunDirector) -> Array:
	var result: Array = []
	for i in director.state.bench.slots.size():
		var instance_id = director.state.bench.slots[i]
		if instance_id == null:
			result.append(null)
		else:
			result.append(_unit_dto(director.state.units[instance_id]))
	return result


static func build_board_dto(director: RunDirector) -> Dictionary:
	var s := director.state
	var cells: Array = []
	for row in s.board.height:
		for col in s.board.width:
			var pos := Vector2i(col, row)
			var instance_id = s.board.get_unit_at(pos)
			var unit_dto = null
			if instance_id != null:
				unit_dto = _unit_dto(s.units[instance_id])
				unit_dto["team"] = SimConstants.TeamId.PLAYER
				unit_dto["alive"] = true
			cells.append({
				"pos": pos,
				"turf": s.board.get_turf_type(pos),
				"unit": unit_dto,
			})
	return {"width": s.board.width, "height": s.board.height, "cells": cells}


static func build_trait_dto(director: RunDirector) -> Array:
	return director.state.traits_cache.duplicate(true)


static func board_hash(director: RunDirector) -> int:
	return str(build_board_dto(director)).hash()


static func _unit_dto(unit: UnitInstance) -> Dictionary:
	var def := UnitRegistry.get_def(unit.def_id)
	return {
		"instance_id": unit.instance_id,
		"def_id": unit.def_id,
		"display_name": def.get("display_name", unit.def_id),
		"cost": def.get("cost", 0),
		"stars": unit.stars,
		"tags": def.get("tags", []),
	}
