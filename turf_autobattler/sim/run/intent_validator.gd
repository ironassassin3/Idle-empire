class_name IntentValidator
extends RefCounted

static func validate(intent: PlayerIntent, state: RunState) -> int:
	match intent.type:
		"BUY_FROM_SHOP":
			return _validate_buy(intent, state)
		"SELL":
			return _validate_sell(intent, state)
		"REROLL_SHOP":
			return _validate_reroll(state)
		"BUY_XP":
			return _validate_buy_xp(state)
		"MOVE_TO_BENCH":
			return _validate_move_to_bench(intent, state)
		"MOVE_TO_BOARD":
			return _validate_move_to_board(intent, state)
		"SWAP_ON_BOARD":
			return _validate_swap(intent, state)
		"LOCK_BOARD":
			return SimConstants.RejectReason.OK if state.phase == SimConstants.RunPhase.PLANNING else SimConstants.RejectReason.WRONG_PHASE
		"SKIP_PLAYBACK":
			return SimConstants.RejectReason.OK if state.phase == SimConstants.RunPhase.COMBAT_PLAYBACK else SimConstants.RejectReason.WRONG_PHASE
		_:
			return SimConstants.RejectReason.WRONG_PHASE


static func _validate_buy(intent: PlayerIntent, state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	var index := int(intent.params.get("index", -1))
	if index < 0 or index >= state.shop.offers.size():
		return SimConstants.RejectReason.INVALID_SLOT
	var def_id = state.shop.offers[index]
	if def_id == null:
		return SimConstants.RejectReason.EMPTY_SHOP_SLOT
	var def := UnitRegistry.get_def(String(def_id))
	if state.gold < int(def.get("cost", 999)):
		return SimConstants.RejectReason.NOT_ENOUGH_GOLD
	if state.bench.first_empty_slot() < 0:
		return SimConstants.RejectReason.BENCH_FULL
	return SimConstants.RejectReason.OK


static func _validate_sell(intent: PlayerIntent, state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	var instance_id := int(intent.params.get("instance_id", -1))
	if not state.units.has(instance_id):
		return SimConstants.RejectReason.UNKNOWN_INSTANCE
	return SimConstants.RejectReason.OK


static func _validate_reroll(state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	if state.gold < SimConstants.REROLL_COST:
		return SimConstants.RejectReason.NOT_ENOUGH_GOLD
	return SimConstants.RejectReason.OK


static func _validate_buy_xp(state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	if state.level >= SimConstants.MAX_LEVEL:
		return SimConstants.RejectReason.ALREADY_MAX_LEVEL
	if state.gold < SimConstants.XP_BUY_COST:
		return SimConstants.RejectReason.NOT_ENOUGH_GOLD
	return SimConstants.RejectReason.OK


static func _validate_move_to_bench(intent: PlayerIntent, state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	var instance_id := int(intent.params.get("instance_id", -1))
	var slot := int(intent.params.get("slot", -1))
	if not state.units.has(instance_id):
		return SimConstants.RejectReason.UNKNOWN_INSTANCE
	if slot < 0 or slot >= state.bench.slots.size():
		return SimConstants.RejectReason.INVALID_SLOT
	return SimConstants.RejectReason.OK


static func _validate_move_to_board(intent: PlayerIntent, state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	var instance_id := int(intent.params.get("instance_id", -1))
	var pos: Vector2i = intent.params.get("grid_pos", Vector2i(-1, -1))
	if not state.units.has(instance_id):
		return SimConstants.RejectReason.UNKNOWN_INSTANCE
	if not SimGrid.is_in_bounds(pos, state.board.width, state.board.height):
		return SimConstants.RejectReason.INVALID_SLOT
	if state.board.get_unit_at(pos) != null:
		return SimConstants.RejectReason.INVALID_SLOT
	var unit: UnitInstance = state.units[instance_id]
	if unit.grid_pos.x < 0 and state.board.count_units() >= state.board.max_units:
		return SimConstants.RejectReason.BOARD_FULL
	return SimConstants.RejectReason.OK


static func _validate_swap(intent: PlayerIntent, state: RunState) -> int:
	if state.phase != SimConstants.RunPhase.PLANNING:
		return SimConstants.RejectReason.WRONG_PHASE
	var a: Vector2i = intent.params.get("a", Vector2i(-1, -1))
	var b: Vector2i = intent.params.get("b", Vector2i(-1, -1))
	if not SimGrid.is_in_bounds(a, state.board.width, state.board.height):
		return SimConstants.RejectReason.INVALID_SLOT
	if not SimGrid.is_in_bounds(b, state.board.width, state.board.height):
		return SimConstants.RejectReason.INVALID_SLOT
	if state.board.get_unit_at(a) == null or state.board.get_unit_at(b) == null:
		return SimConstants.RejectReason.INVALID_SLOT
	return SimConstants.RejectReason.OK
