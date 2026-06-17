class_name ManagerSystem
extends RefCounted
## Manager income + active behaviors — hybrid port of src/managers.py (P1 subset).

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")

const COLLECTOR_SHIELD_CD := 300.0
const MECHANIC_BUILDING_IDX := 2
const MECHANIC_AUTOBUY_INTERVAL := 3.0
const MECHANIC_BALANCE_MULT := 2.0
const AUTOBUY_INTERVAL := 3.0
const CARL_RAID_THRESHOLD := 60.0
const CARL_EMERGENCY_TARGET := 55.0
const CARL_EMERGENCY_DROP := 20.0
const BROKER_RETRY_CD := 300.0


static func manager_active(state, name: String) -> bool:
	for m in state.managers:
		if m.hired and m.display_name == name:
			return true
	return false


static func manager_covers_building(state, building_idx: int) -> bool:
	for m in state.managers:
		if m.hired and m.building_index == building_idx:
			return true
	return false


static func maxine_behavior_mult(state) -> float:
	if not manager_active(state, "Maxine the Dealer"):
		return 1.0
	if state.buildings.size() <= 6:
		return 1.0
	return 1.0 + 0.10 * float(state.buildings[6].owned)


static func behavior_interval(base: float, state) -> float:
	var mult := maxine_behavior_mult(state)
	return base / mult if mult > 0.0 else base


static func heat_gain_mult(state) -> float:
	return 0.70 if manager_active(state, "Clean Carl") else 1.0


static func raid_damage_mult(state) -> float:
	return 0.65 if manager_active(state, "The Collector") else 1.0


static func influence_gain_mult(state) -> float:
	return 1.20 if manager_active(state, "The Consigliere") else 1.0


static func operation_reward_mult(state) -> float:
	return 1.30 if manager_active(state, "The Smuggler") else 1.0


static func territory_success_bonus(state) -> float:
	return 0.15 if manager_active(state, "The Broker") else 0.0


static func tick_broker_retry_cd(state, dt: float) -> void:
	if state.broker_retry_cd > 0.0:
		state.broker_retry_cd = maxf(0.0, state.broker_retry_cd - dt)


static func broker_retry_ready(state) -> bool:
	return manager_active(state, "The Broker") and state.broker_retry_cd <= 0.0


static func manager_income_mult(state) -> float:
	return _PrestigeTree.manager_income_mult(state)


static func compute_base_income(state) -> float:
	BuildingDefs.sync_racket_multiplier(state.buildings)
	var global_mult := BuildingDefs.global_special_mult(state.buildings)
	var casino_bonus := BuildingDefs.casino_manager_bonus(state.buildings)
	var mgr_mult := manager_income_mult(state)
	var perk_blds: Array = state.perk_bld_mults
	var total := 0.0
	for i in state.buildings.size():
		var b: Building = state.buildings[i]
		var base: float = b.base_income * b.owned * b.income_multiplier
		if i < perk_blds.size():
			base *= float(perk_blds[i])
		if manager_covers_building(state, i):
			base *= mgr_mult * casino_bonus
		total += base
	return total * global_mult


static func tick_collector_shield(state, dt: float) -> void:
	if state.collector_shield_cd > 0.0:
		state.collector_shield_cd = maxf(0.0, state.collector_shield_cd - dt * maxine_behavior_mult(state))


static func collector_shield_ready(state) -> bool:
	return manager_active(state, "The Collector") and state.collector_shield_cd <= 0.0


static func collector_shield_fraction(state) -> float:
	if not manager_active(state, "The Collector"):
		return 0.0
	if state.collector_shield_cd <= 0.0:
		return 1.0
	return maxf(0.0, 1.0 - state.collector_shield_cd / COLLECTOR_SHIELD_CD)


static func apply_raid_penalty(state, penalty: float) -> Dictionary:
	## Returns { "actual": float, "absorbed": bool }
	if penalty <= 0.0:
		return {"actual": 0.0, "absorbed": false}
	var actual: float = penalty * _CrewSystem.protection_damage_mult(state.crew)
	var absorbed := false
	if manager_active(state, "The Collector"):
		if collector_shield_ready(state):
			actual = 0.0
			absorbed = true
			state.collector_shield_cd = COLLECTOR_SHIELD_CD
		else:
			actual *= raid_damage_mult(state)
	state.balance = maxf(0.0, state.balance - actual)
	return {"actual": actual, "absorbed": absorbed}


static func tick_carl_emergency(state, heat_before: float, heat_after: float) -> bool:
	if not manager_active(state, "Clean Carl"):
		return false
	if state.carl_emergency_used:
		return false
	if heat_before < CARL_RAID_THRESHOLD and heat_after >= CARL_RAID_THRESHOLD:
		state.carl_emergency_used = true
		state.heat = clampf(heat_after - CARL_EMERGENCY_DROP, 0.0, CARL_EMERGENCY_TARGET)
		return true
	return false


static func tick_manager_effects(state, dt: float) -> Array[String]:
	var messages: Array[String] = []
	tick_collector_shield(state, dt)
	tick_broker_retry_cd(state, dt)
	if manager_active(state, "The Mechanic"):
		state.mechanic_timer += dt
		if state.mechanic_timer >= behavior_interval(MECHANIC_AUTOBUY_INTERVAL, state):
			state.mechanic_timer = 0.0
			if _auto_buy_chop_shop(state):
				messages.append("Mechanic ordered another Chop Shop")
	if manager_active(state, "The Accountant"):
		state.autobuy_timer += dt
		if state.autobuy_timer >= behavior_interval(AUTOBUY_INTERVAL, state):
			state.autobuy_timer = 0.0
			if _auto_buy_best(state):
				messages.append("Accountant secured a new asset")
	return messages


static func _auto_buy_chop_shop(state) -> bool:
	if state.buildings.size() <= MECHANIC_BUILDING_IDX:
		return false
	var b: Building = state.buildings[MECHANIC_BUILDING_IDX]
	var cost: float = b.current_cost()
	if cost <= 0.0 or state.balance < cost * MECHANIC_BALANCE_MULT:
		return false
	state.balance -= cost
	b.owned += 1
	state.record_building_purchase(1)
	BuildingDefs.sync_racket_multiplier(state.buildings)
	return true


static func _auto_buy_best(state) -> bool:
	var best: Building = null
	var best_ratio := 0.0
	for b: Building in state.buildings:
		var cost: float = b.current_cost()
		if cost <= 0.0 or state.balance < cost:
			continue
		var ratio: float = (b.base_income * b.income_multiplier) / cost
		if ratio > best_ratio:
			best_ratio = ratio
			best = b
	if best == null:
		return false
	state.balance -= best.current_cost()
	best.owned += 1
	state.record_building_purchase(1)
	BuildingDefs.sync_racket_multiplier(state.buildings)
	return true


static func reset_runtime(state) -> void:
	state.collector_shield_cd = 0.0
	state.carl_emergency_used = false
	state.mechanic_timer = 0.0
	state.autobuy_timer = 0.0
	state.broker_retry_cd = 0.0
	state.smuggler_timer = 0.0
	state.smuggler_notified.clear()
