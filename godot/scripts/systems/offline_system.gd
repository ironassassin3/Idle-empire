class_name OfflineSystem
extends RefCounted
## Offline return earnings — port of src/save_load.py offline block.

const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

const CAP_SECONDS := 12.0 * 3600.0
const BASE_EFFICIENCY := 0.6


static func apply_offline_return(state, raw_away_secs: float) -> void:
	if raw_away_secs < 60.0:
		return
	var elapsed: float = minf(raw_away_secs, CAP_SECONDS)
	var eff: float = minf(1.0, BASE_EFFICIENCY * _PrestigeTree.offline_earnings_mult(state))
	var ips: float = state.income_per_second()
	var gain: float = ips * elapsed * eff
	if gain <= 0.0:
		return
	state.balance += gain
	state.lifetime_earnings += gain
	state.offline_gain = gain
	state.offline_secs_away = elapsed
	state.offline_capped = raw_away_secs > CAP_SECONDS
	state.return_ops_ready = _count_ready_ops(state)
	state.return_territory_player = _TerritorySystem.player_district_count(state.territories)
	state.return_territory_total = state.territories.size()
	state.return_rival_active = _count_active_rivals(state)
	state.return_rival_at_war = _count_at_war(state)
	state.show_offline_overlay = true


static func _count_ready_ops(state) -> int:
	var n := 0
	for op in state.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(state, op):
			n += 1
	return n


static func _count_active_rivals(state) -> int:
	var n := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			n += 1
	return n


static func _count_at_war(state) -> int:
	var n := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and bool(r.get("at_war", false)) and str(r.get("status", "")) != "Eliminated":
			n += 1
	return n
