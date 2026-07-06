class_name ManagerSystem
extends RefCounted
## Manager income + active behaviors — hybrid port of src/managers.py (P1 subset).

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _HeatSystem = preload("res://scripts/systems/heat_system.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")

const COLLECTOR_SHIELD_CD := 300.0
const MECHANIC_BUILDING_IDX := 2
const MECHANIC_ORDER_INTERVAL := 8.0
const MECHANIC_BALANCE_MULT := 2.0
const ACCOUNTANT_ORDER_INTERVAL := 12.0
const CARL_RAID_THRESHOLD := 60.0
const CARL_EMERGENCY_TARGET := 55.0
const CARL_EMERGENCY_DROP := 20.0
const BROKER_RETRY_CD := 300.0
const PROMOTER_TARGETS := [40.0, 50.0, 60.0]
const COIN_LIFETIME := 8.0


static func manager_autobuy_unlocked(state) -> bool:
	if not GameConfig.MANAGER_AUTOBUY_REQUIRES_PRESTIGE:
		return true
	return state.prestige_count >= GameConfig.MANAGER_AUTOBUY_MIN_PRESTIGE_COUNT


static func heat_forecast_delta(state, horizon_sec: float = 120.0) -> float:
	return _HeatSystem.forecast_delta(state, horizon_sec)


static func is_automation_notification(message: String) -> bool:
	if message.is_empty():
		return false
	return (
		message.contains("Mechanic")
		or message.contains("Accountant")
		or message.contains("Smuggler")
		or message.contains("auto-buy")
		or message.contains("Perk auto-buy")
		or message.contains("Raid blocked")
		or message.contains("Carl dumped")
		or message.contains("Sal caught")
		or message.contains("secured a new asset")
		or message.contains("ordered another")
	)


static func hire_notification(display_name: String, state) -> String:
	match display_name:
		"Sticky Pete":
			return "Pete's on the block — check Buildings for his pick"
		"Lucky Sal":
			return "Sal's collecting — golden coins auto-grab"
		"The Collector":
			return "Collector's shield is up — first raid bounces"
		"The Mechanic":
			if manager_autobuy_unlocked(state):
				return "Mechanic's on night shift — Chop Shop orders on Buildings"
			return "Mechanic hired — purchase orders unlock after 1st prestige"
		"Clean Carl":
			return "Carl's watching heat — forecast + one emergency dump"
		"The Accountant":
			if manager_autobuy_unlocked(state):
				return "The Accountant is on payroll — best-buy orders on Buildings"
			return "Accountant hired — purchase orders unlock after 1st prestige"
		"Maxine the Dealer":
			return "Maxine boosts the family — behaviors scale with casinos"
		"The Promoter":
			return "Promoter autopilot — heat target ≤%.0f%%" % promoter_heat_target(state)
		"The Smuggler":
			return "Smuggler's queue running — ops auto-start & collect alerts"
		"The Broker":
			return "Broker intel live — best turf action highlighted"
		"The Consigliere":
			return "Consigliere sees the board — check Prestige advisory"
		"Rudy Riches":
			return "Rudy says it's time to make some real money"
		"Rob Revenue":
			return "Rob's balancing the books — see Stats dashboard"
		_:
			return "Hired %s" % display_name


## Compact persistent summary for the status-strip automation row.
static func automation_strip(state) -> Dictionary:
	var tags: PackedStringArray = PackedStringArray()
	if manager_active(state, "Lucky Sal"):
		tags.append("Sal: coins")
	if manager_active(state, "The Mechanic"):
		if manager_autobuy_unlocked(state):
			tags.append("Mech: order" if state.mechanic_order_ready else "Mech: watch")
		else:
			tags.append("Mech: gated")
	if manager_active(state, "The Accountant"):
		if manager_autobuy_unlocked(state):
			if state.accountant_order_idx >= 0 and state.accountant_order_idx < state.buildings.size():
				tags.append("Acct: %s" % state.buildings[state.accountant_order_idx].display_name)
			else:
				tags.append("Acct: watch")
		else:
			tags.append("Acct: gated")
	if manager_active(state, "The Smuggler"):
		var ready := _count_ready_ops(state)
		if ready > 0:
			tags.append("Smuggler: %d ready" % ready)
		else:
			tags.append("Smuggler: queue")
	if manager_active(state, "The Collector"):
		var frac: float = collector_shield_fraction(state)
		if frac >= 1.0:
			tags.append("Shield ready")
		else:
			tags.append("Shield %d%%" % int(frac * 100.0))
	if manager_active(state, "Clean Carl"):
		var delta: float = heat_forecast_delta(state, 120.0)
		var sign := "+" if delta >= 0.0 else ""
		tags.append("Carl %s%.0f%%/2m" % [sign, delta])
	if manager_active(state, "The Promoter"):
		tags.append("Heat ≤%.0f%%" % promoter_heat_target(state))
	if manager_active(state, "Sticky Pete"):
		var pick := pete_recommends_index(state)
		if pick >= 0 and pick < state.buildings.size():
			tags.append("Pete: %s" % state.buildings[pick].display_name)
	if state.perk_auto_buy and manager_autobuy_unlocked(state):
		tags.append("Perk: auto-buy")
	if state.perk_auto_upgrade:
		tags.append("Perk: auto-upg")
	if tags.is_empty():
		return {"visible": false, "summary": "", "flash": ""}
	var summary := "AUTO · " + " · ".join(tags)
	var flash := ""
	if float(state.automation_flash_timer) > 0.0 and not str(state.automation_flash).is_empty():
		flash = str(state.automation_flash)
	return {"visible": true, "summary": summary, "flash": flash}


static func _count_ready_ops(state) -> int:
	var n := 0
	for op in state.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(state, op):
			n += 1
	return n


static func purchase_autobuy_gate_text() -> String:
	return "Purchase orders unlock after 1st prestige"


static func is_manager_recommendation(message: String) -> bool:
	return message.contains("recommends")


static func pending_order_hint(state) -> String:
	var order := pending_manager_order(state)
	if order.is_empty():
		return ""
	return "%s — buy %s" % [str(order.get("source_label", "")).to_upper(), order.get("building_name", "")]


## Active manager purchase order (Mechanic Chop Shop beats Accountant best-buy).
static func pending_manager_order(state) -> Dictionary:
	_sync_manager_orders(state)
	if state.mechanic_order_ready and state.buildings.size() > MECHANIC_BUILDING_IDX:
		var chop: Building = state.buildings[MECHANIC_BUILDING_IDX]
		var chop_cost: float = chop.current_cost()
		return {
			"index": MECHANIC_BUILDING_IDX,
			"source": "mechanic",
			"source_label": "Mechanic",
			"building_name": chop.display_name,
			"qty": 1,
			"cost": chop_cost,
			"can_approve": chop_cost > 0.0 and state.balance >= chop_cost * MECHANIC_BALANCE_MULT,
		}
	if state.accountant_order_idx >= 0 and state.accountant_order_idx < state.buildings.size():
		var idx: int = state.accountant_order_idx
		var b: Building = state.buildings[idx]
		var qty: int = maxi(1, state.effective_buy_qty(idx))
		var cost: float = b.cost_for_n(qty)
		return {
			"index": idx,
			"source": "accountant",
			"source_label": "Accountant",
			"building_name": b.display_name,
			"qty": qty,
			"cost": cost,
			"can_approve": state.can_buy_building(idx, qty),
		}
	return {}


static func on_building_purchased(state, index: int) -> void:
	if not manager_autobuy_unlocked(state):
		return
	if manager_active(state, "The Mechanic") and index == MECHANIC_BUILDING_IDX:
		_refresh_mechanic_order(state)
	if manager_active(state, "The Accountant") and index == state.accountant_order_idx:
		_refresh_accountant_order(state)


static func approve_manager_order(state) -> Dictionary:
	var order := pending_manager_order(state)
	if order.is_empty() or not bool(order.get("can_approve", false)):
		return {"ok": false}
	var idx: int = int(order.get("index", -1))
	var qty: int = maxi(1, int(order.get("qty", 1)))
	if not state.buy_building(idx, qty):
		return {"ok": false, "reason": "failed"}
	if str(order.get("source", "")) == "mechanic":
		state.mechanic_order_ready = false
		_refresh_mechanic_order(state)
	else:
		_refresh_accountant_order(state)
	return {
		"ok": true,
		"index": idx,
		"qty": qty,
		"building_name": str(order.get("building_name", "")),
		"source_label": str(order.get("source_label", "")),
	}


static func building_advisor_index(state) -> int:
	_sync_manager_orders(state)
	if state.mechanic_order_ready:
		return MECHANIC_BUILDING_IDX
	if state.accountant_order_idx >= 0:
		return state.accountant_order_idx
	return pete_recommends_index(state)


static func building_advisor_prefix(state, idx: int) -> String:
	_sync_manager_orders(state)
	if state.mechanic_order_ready and idx == MECHANIC_BUILDING_IDX:
		return "▸ "
	if state.accountant_order_idx == idx:
		return "▸ "
	if pete_recommends_index(state) == idx:
		return "★ "
	return ""


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


static func pete_recommends_index(state) -> int:
	if not manager_active(state, "Sticky Pete"):
		return -1
	return _best_affordable_building_index(state)


static func _best_affordable_building_index(state) -> int:
	var best_idx := -1
	var best_ratio := 0.0
	for i in state.buildings.size():
		var b: Building = state.buildings[i]
		var cost: float = b.current_cost()
		if cost <= 0.0 or state.balance < cost:
			continue
		var ratio: float = (b.base_income * b.income_multiplier) / cost
		if ratio > best_ratio:
			best_ratio = ratio
			best_idx = i
	return best_idx


static func _building_affordable(state, idx: int) -> bool:
	if idx < 0 or idx >= state.buildings.size():
		return false
	var cost: float = state.buildings[idx].current_cost()
	return cost > 0.0 and state.balance >= cost


static func _chop_shop_order_valid(state) -> bool:
	if state.buildings.size() <= MECHANIC_BUILDING_IDX:
		return false
	var cost: float = state.buildings[MECHANIC_BUILDING_IDX].current_cost()
	return cost > 0.0 and state.balance >= cost * MECHANIC_BALANCE_MULT


static func _sync_manager_orders(state) -> void:
	if manager_active(state, "The Mechanic") and manager_autobuy_unlocked(state):
		state.mechanic_order_ready = _chop_shop_order_valid(state)
	else:
		state.mechanic_order_ready = false
	if manager_active(state, "The Accountant") and manager_autobuy_unlocked(state):
		if state.accountant_order_idx >= 0 and not _building_affordable(state, state.accountant_order_idx):
			state.accountant_order_idx = -1
	else:
		state.accountant_order_idx = -1


static func _refresh_accountant_order(state) -> void:
	if not manager_active(state, "The Accountant") or not manager_autobuy_unlocked(state):
		state.accountant_order_idx = -1
		return
	state.accountant_order_idx = _best_affordable_building_index(state)


static func _refresh_mechanic_order(state) -> void:
	if not manager_active(state, "The Mechanic") or not manager_autobuy_unlocked(state):
		state.mechanic_order_ready = false
		return
	state.mechanic_order_ready = _chop_shop_order_valid(state)


static func sal_autocollect_delay(state) -> float:
	return 0.75 / maxine_behavior_mult(state)


static func promoter_heat_target(state) -> float:
	return float(state.promoter_heat_target)


static func cycle_promoter_target(state) -> float:
	if not manager_active(state, "The Promoter"):
		return promoter_heat_target(state)
	var cur: float = promoter_heat_target(state)
	var idx: int = PROMOTER_TARGETS.find(cur)
	var nxt: float = PROMOTER_TARGETS[1] if idx < 0 else PROMOTER_TARGETS[(idx + 1) % PROMOTER_TARGETS.size()]
	state.promoter_heat_target = nxt
	return nxt


static func tick_promoter_heat(state, dt: float) -> void:
	if not manager_active(state, "The Promoter"):
		return
	var target: float = promoter_heat_target(state)
	var decay: float = 0.35 * dt
	if state.buildings.size() > 7:
		decay += 0.5 * float(state.buildings[7].owned) * dt
	if state.heat > target:
		decay += minf(state.heat - target, 20.0) * 0.06 * dt
	state.heat = maxf(HeatSystem.HEAT_MIN, state.heat - decay)


static func prestige_advice(state) -> Dictionary:
	var has_consig := manager_active(state, "The Consigliere")
	var has_rudy := manager_active(state, "Rudy Riches")
	if not has_consig and not has_rudy:
		return {}
	var ips: float = state.income_per_second()
	var le: float = state.lifetime_earnings
	var gain_now: int = Prestige.calc_influence_gain(le)
	var gain_5: int = Prestige.calc_influence_gain(le + ips * 300.0)
	var gain_10: int = Prestige.calc_influence_gain(le + ips * 600.0)
	var d5: int = gain_5 - gain_now
	var d10: int = gain_10 - gain_now
	var can_now: bool = Prestige.can_prestige(state)
	var rank_after: String = Prestige.get_rank(state.lifetime_tokens + gain_now)
	var income_pct: int = gain_now * 2
	var need: float = Prestige.prestige_earnings_required(state.prestige_count, state.next_prestige_earnings)
	var pct: int = int(minf(100.0, le / need * 100.0)) if need > 0.0 else 0
	var window: String
	var rec: String
	if can_now:
		if has_rudy:
			if d10 >= 2 and gain_10 > int(float(gain_now) * 1.20):
				window = "WAIT_10"
				rec = "wait 10m (+%d Influence)" % d10
			elif d5 >= 1 and gain_5 > int(float(gain_now) * 1.10):
				window = "WAIT_5"
				rec = "wait 5m (+%d Influence)" % d5
			else:
				window = "NOW"
				rec = "prestige now — peak window"
		elif gain_5 > int(float(gain_now) * 1.12):
			window = "WAIT_5"
			rec = "wait 5m (+Influence)"
		elif gain_10 > int(float(gain_now) * 1.20):
			window = "WAIT_10"
			rec = "wait 10m (+Influence)"
		else:
			window = "NOW"
			rec = "prestige now"
	else:
		window = "BUILD"
		rec = "%d%% to prestige gate" % pct
	var out := {
		"gain_now": gain_now,
		"recommend": rec,
		"window": window,
		"summary": "+%d Influence, +%d%% run income, rank → %s" % [gain_now, income_pct, rank_after],
		"source": "Rudy" if has_rudy else "Consigliere",
		"enhanced": has_rudy,
	}
	if has_rudy and can_now and window == "NOW":
		out["confidence"] = mini(100, 70 + d5 * 5 + (10 if d10 <= d5 else 0))
	elif has_rudy and can_now:
		out["confidence"] = mini(95, 55 + maxi(d5, d10) * 4)
	elif has_rudy:
		out["confidence"] = pct
	return out


static func _territory_income_mult(state) -> float:
	const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
	const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
	return (
		_TerritorySystem.territory_income_mult(state.territories, state)
		* (1.0 + _TerritorySystem.territory_district_count_bonus(state.territories, state))
		* _TerritorySystem.milestone_income_mult(state)
		* _PrestigeTree.district_income_mult(state)
	)


static func _estimate_click_rate(state) -> float:
	var now: float = state.play_time
	var window: Array = []
	for t in state.recent_clicks:
		if now - float(t) <= 10.0:
			window.append(t)
	var cps: float = float(window.size()) / 10.0 if not window.is_empty() else 0.0
	if cps < 0.05:
		var play: float = maxf(1.0, state.play_time)
		cps = float(state.click_count) / play
	return state.click_value() * cps


static func _estimate_operations_rate(state) -> float:
	const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
	var ips: float = state.income_per_second()
	var total := 0.0
	for op in state.operations:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		var dur: float = float(op.get("duration", 0.0))
		if dur <= 0.0:
			continue
		if bool(op.get("active", false)) and not bool(op.get("collected", false)):
			total += float(op.get("reward", 0.0)) / dur
		elif not bool(op.get("active", false)) and not bool(op.get("collected", false)):
			var gate: Dictionary = _OperationSystem.can_start(state, op)
			if gate.get("ok", false) and ips > 0.0:
				total += ips * float(op.get("reward_mult", 1.0)) / dur * 0.35
	return total


static func empire_efficiency_report(state) -> Dictionary:
	if not manager_active(state, "Rob Revenue"):
		return {}
	var ips: float = state.income_per_second()
	var terr_mult: float = maxf(1.0, _territory_income_mult(state))
	var building_rate: float = ips / terr_mult if ips > 0.0 else 0.0
	var territory_rate: float = maxf(0.0, ips - building_rate)
	var ops_rate: float = _estimate_operations_rate(state)
	var click_rate: float = _estimate_click_rate(state)
	var total: float = building_rate + territory_rate + ops_rate + click_rate
	if total <= 0.0:
		total = 1.0
	var shares := {
		"buildings": building_rate / total * 100.0,
		"territory": territory_rate / total * 100.0,
		"operations": ops_rate / total * 100.0,
		"clicks": click_rate / total * 100.0,
	}
	var labels := {
		"buildings": "Buildings",
		"territory": "Territories",
		"operations": "Operations",
		"clicks": "Clicks",
	}
	var ranked: Array = shares.keys()
	ranked.sort_custom(func(a, b): return shares[a] > shares[b])
	var strongest_key: String = ranked[0]
	var weakest_key: String = ranked[ranked.size() - 1]
	var recs: Array[String] = []
	const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
	var can_op := false
	for op in state.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.can_start(state, op).get("ok", false):
			can_op = true
			break
	if shares["operations"] < 8.0 and can_op:
		recs.append("Operations are underperforming.")
	if shares["territory"] >= 20.0 and shares["territory"] >= shares["buildings"] * 0.85:
		recs.append("Territories now generate most revenue.")
	if shares["clicks"] < 8.0:
		recs.append("Clicks are only %.0f%% of income." % shares["clicks"])
	var adv := prestige_advice(state)
	if not adv.is_empty():
		if adv.get("window") == "NOW":
			recs.append("Consider another prestige.")
		elif adv.get("window") in ["WAIT_5", "WAIT_10"]:
			recs.append("Hold prestige — income still climbing.")
	if recs.is_empty():
		var low_key: String = weakest_key
		recs.append("%s need attention." % labels.get(low_key, low_key))
	return {
		"shares": shares,
		"labels": labels,
		"strongest": [labels[strongest_key], shares[strongest_key]],
		"weakest": [labels[weakest_key], shares[weakest_key]],
		"recommendations": recs.slice(0, 4),
		"headline": recs[0],
	}


static func tick_manager_effects(state, dt: float) -> Array[String]:
	var messages: Array[String] = []
	tick_collector_shield(state, dt)
	tick_broker_retry_cd(state, dt)
	tick_promoter_heat(state, dt)
	if manager_active(state, "The Mechanic") and manager_autobuy_unlocked(state):
		state.mechanic_timer += dt
		if state.mechanic_timer >= behavior_interval(MECHANIC_ORDER_INTERVAL, state):
			state.mechanic_timer = 0.0
			var was_ready: bool = state.mechanic_order_ready
			_refresh_mechanic_order(state)
			if state.mechanic_order_ready and not was_ready:
				messages.append("Mechanic recommends Chop Shop — Approve on Buildings")
	if manager_active(state, "The Accountant") and manager_autobuy_unlocked(state):
		state.autobuy_timer += dt
		if state.autobuy_timer >= behavior_interval(ACCOUNTANT_ORDER_INTERVAL, state):
			state.autobuy_timer = 0.0
			var prev_idx: int = state.accountant_order_idx
			_refresh_accountant_order(state)
			if state.accountant_order_idx >= 0 and state.accountant_order_idx != prev_idx:
				var name: String = state.buildings[state.accountant_order_idx].display_name
				messages.append("Accountant recommends %s — Approve on Buildings" % name)
	return messages


static func _auto_buy_chop_shop(state) -> String:
	if state.buildings.size() <= MECHANIC_BUILDING_IDX:
		return ""
	var b: Building = state.buildings[MECHANIC_BUILDING_IDX]
	var cost: float = b.current_cost()
	if cost <= 0.0 or state.balance < cost * MECHANIC_BALANCE_MULT:
		return ""
	state.balance -= cost
	b.owned += 1
	state.record_building_purchase(1)
	BuildingDefs.sync_racket_multiplier(state.buildings)
	return b.display_name


static func _auto_buy_best(state) -> String:
	var idx: int = _best_affordable_building_index(state)
	if idx < 0:
		return ""
	var best: Building = state.buildings[idx]
	state.balance -= best.current_cost()
	best.owned += 1
	state.record_building_purchase(1)
	BuildingDefs.sync_racket_multiplier(state.buildings)
	return best.display_name


static func reset_runtime(state) -> void:
	state.collector_shield_cd = 0.0
	state.carl_emergency_used = false
	state.mechanic_timer = 0.0
	state.autobuy_timer = 0.0
	state.mechanic_autobuys = 0
	state.accountant_autobuys = 0
	state.accountant_order_idx = -1
	state.mechanic_order_ready = false
	state.broker_retry_cd = 0.0
	state.smuggler_timer = 0.0
	state.smuggler_notified.clear()
	state.promoter_heat_target = 50.0
	state.automation_flash = ""
	state.automation_flash_timer = 0.0


## Phase 123 roster status — (text, color, badge_kind) for manager_row.gd.
static func employee_status(state, idx: int) -> Dictionary:
	if idx < 0 or idx >= state.managers.size():
		return {"text": "", "color": GameTheme.TEXT_MUTED, "badge_kind": ""}
	var mgr: Manager = state.managers[idx]
	if mgr.hired:
		match mgr.display_name:
			"Lucky Sal":
				return {"text": "Collecting coins", "color": GameTheme.GOLD_BRIGHT, "badge_kind": "auto"}
			"The Mechanic":
				if not manager_autobuy_unlocked(state):
					return {"text": purchase_autobuy_gate_text(), "color": GameTheme.TEXT_MUTED, "badge_kind": "gated"}
				if state.mechanic_order_ready:
					return {"text": "Chop Shop order ready — Approve on Buildings", "color": GameTheme.GOLD_BRIGHT, "badge_kind": "ready"}
				return {"text": "Watching Chop Shop — order when affordable", "color": GameTheme.GOLD, "badge_kind": "working"}
			"The Collector":
				var shield: float = collector_shield_fraction(state)
				if shield >= 1.0:
					return {"text": "Shield ready", "color": GameTheme.BLUE_BRIGHT, "badge_kind": "ready"}
				return {"text": "Shield charging (%d%%)" % int(shield * 100.0), "color": GameTheme.BLUE_BRIGHT, "badge_kind": "working"}
			"Clean Carl":
				var delta: float = heat_forecast_delta(state, 120.0)
				var sign := "+" if delta >= 0.0 else ""
				var emergency := "" if state.carl_emergency_used else " · rescue ready"
				return {
					"text": "Forecast %s%.0f%% / 2m%s" % [sign, delta, emergency],
					"color": GameTheme.GOLD,
					"badge_kind": "working",
				}
			"The Accountant":
				if not manager_autobuy_unlocked(state):
					return {"text": purchase_autobuy_gate_text(), "color": GameTheme.TEXT_MUTED, "badge_kind": "gated"}
				if state.accountant_order_idx >= 0 and state.accountant_order_idx < state.buildings.size():
					var b: Building = state.buildings[state.accountant_order_idx]
					return {
						"text": "Order ready: %s — Approve on Buildings" % b.display_name,
						"color": GameTheme.GOLD_BRIGHT,
						"badge_kind": "ready",
					}
				return {"text": "Scanning for best buy", "color": GameTheme.GOLD, "badge_kind": "working"}
			"The Promoter":
				var tgt: int = int(promoter_heat_target(state))
				return {"text": "Maintaining heat ≤ %d%%" % tgt, "color": GameTheme.RED, "badge_kind": "auto"}
			"The Smuggler":
				var ready := _count_ready_ops(state)
				if ready > 0:
					return {
						"text": "%d op%s ready to collect" % [ready, "" if ready == 1 else "s"],
						"color": GameTheme.GOLD_BRIGHT,
						"badge_kind": "ready",
					}
				return {"text": "Ops queue running", "color": GameTheme.GREEN, "badge_kind": "auto"}
			"The Broker":
				return {"text": "Turf intel active", "color": GameTheme.BLUE_BRIGHT, "badge_kind": "working"}
			"Sticky Pete":
				return {"text": "Marking best building buy", "color": GameTheme.GOLD, "badge_kind": "working"}
			_:
				return {"text": "On payroll", "color": GameTheme.GREEN, "badge_kind": "working"}
	if not ManagerDefs.is_unlocked(state, idx):
		return {"text": "Locked: %s" % ManagerDefs.unlock_text(idx), "color": GameTheme.TEXT_MUTED, "badge_kind": ""}
	return {"text": "Payroll open — ready to hire", "color": GameTheme.GOLD_BRIGHT, "badge_kind": "ready"}
