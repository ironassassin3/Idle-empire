class_name MatchBotAi
extends RefCounted

const MAX_REROLLS_PER_ROUND := 4
const REROLL_GOLD_RESERVE := 1


static func auto_buy_and_place(director: RunDirector) -> void:
	var state := director.state
	var target_size := _enemy_size_for_round(state.round)
	while state.board.max_units < target_size \
			and state.level < SimConstants.MAX_LEVEL \
			and state.gold >= SimConstants.XP_BUY_COST:
		if director.submit_intent(PlayerIntent.make("BUY_XP")) != SimConstants.RejectReason.OK:
			break
	_buy_affordable(director)
	var rerolls := 0
	while rerolls < MAX_REROLLS_PER_ROUND \
			and state.bench.first_empty_slot() >= 0 \
			and state.gold >= SimConstants.REROLL_COST + REROLL_GOLD_RESERVE:
		if director.submit_intent(PlayerIntent.make("REROLL_SHOP")) != SimConstants.RejectReason.OK:
			break
		_buy_affordable(director)
		rerolls += 1
	_field_strongest(director)


static func _buy_affordable(director: RunDirector) -> void:
	var state := director.state
	var order: Array = []
	for i in state.shop.offers.size():
		if state.shop.offers[i] != null:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _def_strength(String(state.shop.offers[a])) > _def_strength(String(state.shop.offers[b])))
	for i in order:
		if state.shop.offers[i] == null or state.bench.first_empty_slot() < 0:
			continue
		var def := UnitRegistry.get_def(String(state.shop.offers[i]))
		if state.gold >= int(def.get("cost", 0)):
			director.submit_intent(PlayerIntent.make("BUY_FROM_SHOP", {"index": i}))


static func _field_strongest(director: RunDirector) -> void:
	var state := director.state
	var cap: int = state.board.max_units
	var owned: Array = state.units.keys()
	owned.sort_custom(func(a: int, b: int) -> bool:
		return _def_strength(state.units[a].def_id) > _def_strength(state.units[b].def_id))
	var keepers: Dictionary = {}
	for idx in range(mini(cap, owned.size())):
		keepers[owned[idx]] = true
	for iid in owned:
		if not keepers.has(iid):
			director.submit_intent(PlayerIntent.make("SELL", {"instance_id": iid}))
	for iid in keepers.keys():
		var unit: UnitInstance = state.units[iid]
		if unit.grid_pos.x >= 0:
			continue
		var cell := _first_empty_spread_cell(state.board)
		if cell.x < 0:
			break
		director.submit_intent(PlayerIntent.make("MOVE_TO_BOARD", {"instance_id": iid, "grid_pos": cell}))


static func _first_empty_spread_cell(board: BoardState) -> Vector2i:
	for col in range(SimConstants.BOARD_WIDTH):
		for row in range(SimConstants.BOARD_HEIGHT):
			var cell := Vector2i(col, row)
			if board.get_unit_at(cell) == null:
				return cell
	return Vector2i(-1, -1)


static func _def_strength(def_id: String) -> int:
	var def := UnitRegistry.get_def(def_id)
	var stats: Dictionary = def.get("base_stats", {})
	return int(def.get("tier", 0)) * 100000 + int(def.get("cost", 0)) * 10000 + int(stats.get("max_hp", 0))


static func _enemy_size_for_round(round_num: int) -> int:
	return RivalCompRegistry.get_comp_for_round(round_num).get("units", []).size()
