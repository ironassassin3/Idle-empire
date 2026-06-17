class_name RivalSystem
extends RefCounted
## Rival syndicates — port of src/rivals.py (mechanics only).

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _RivalAi = preload("res://scripts/systems/rival_ai.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")

const ACTION_INTERVAL_MIN := 90.0
const ACTION_INTERVAL_MAX := 180.0
const GROWTH_INTERVAL := 45.0
const LOG_MAX := 10
const NEGOTIATE_HEAT_MIN := 5.0
const ATTACK_MIN_BALANCE := 25000.0

const CARD_FLAVOR := {
	"crimson_kings": "They burn the city to take it.",
	"silver_hand": "They buy what they can't beat.",
	"iron_union": "Chop shops and rail yards.",
	"network": "They see everything you do.",
	"blackwater": "The tide is always theirs.",
}

const ELIMINATION_LINES := {
	"crimson_kings": "The Inferno is ash. The streets go quiet.",
	"silver_hand": "Old money runs dry. The courts are yours.",
	"iron_union": "The machine is scrap. The yards go still.",
	"network": "The Network goes dark. Nobody is watching.",
	"blackwater": "The tide goes out. The harbor is yours.",
}

const _FACTION_DEFS: Array = [
	["Crimson Kings", "Marco The Inferno Reyes", "The Inferno", 200, 60, 40,
		"Violent", "Raids relentlessly.", 0.75,
		"Street muscle.", "Street warfare.", "Expansionist.",
		"D", "crimson_kings", "residential,commercial", "", 2, 2000000.0, 35],
	["Silver Hand", "Marcus The Architect Kane", "The Architect", 40, 110, 175,
		"Corrupt", "Generates money faster.", 0.40,
		"Old money.", "Political corruption.", "Manipulators.",
		"S", "silver_hand", "government,commercial", "", 3, 20000000.0, 55],
	["Iron Union", "Viktor The Slab Orlov", "The Slab", 155, 118, 48,
		"Territorial", "Expands industrial turf.", 0.60,
		"Industrial.", "Industrial dominance.", "Efficient.",
		"I", "iron_union", "industrial,residential", "", 1, 1000000.0, 45],
	["The Network", "Agent Clara The Ghost Voss", "The Ghost", 155, 55, 175,
		"Surveillance", "Informants drain heat.", 0.45,
		"Shadows.", "Intelligence.", "Methodical.",
		"N", "network", "government", "", 0, 50000000.0, 70],
	["Blackwater Mob", "Captain Leon Claw Deveraux", "The Claw", 28, 105, 135,
		"Smuggler", "Controls shipping.", 0.35,
		"Harbor crime.", "Harbor crime.", "Patient.",
		"B", "blackwater", "industrial",
		"Waterfront,Rail Yards,Machine Quarter,Warehouse Row", 4, 10000000.0, 50],
]


static func clear_activity_log(state) -> void:
	if state != null:
		state.rival_activity_log.clear()


static func get_activity_log(state) -> Array:
	if state == null:
		return []
	return state.rival_activity_log.duplicate()


static func _log(state, msg: String) -> void:
	if state == null:
		return
	state.rival_activity_log.append(msg)
	while state.rival_activity_log.size() > LOG_MAX:
		state.rival_activity_log.pop_front()


static func _split_csv(text: String) -> Array:
	var out: Array = []
	for part in text.split(",", false):
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out


static func make_rivals(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for d in _FACTION_DEFS:
		var r: Dictionary = {
			"name": d[0],
			"leader_name": d[1],
			"leader_title": d[2],
			"color": Color(float(d[3]) / 255.0, float(d[4]) / 255.0, float(d[5]) / 255.0),
			"trait": d[6],
			"trait_desc": d[7],
			"aggression": float(d[8]),
			"flavor": d[9],
			"theme": d[10],
			"personality": d[11],
			"symbol": d[12],
			"faction_key": d[13],
			"preferred_district_types": _split_csv(str(d[14])),
			"preferred_district_names": _split_csv(str(d[15])),
			"turf": int(d[16]),
			"wealth": float(d[17]),
			"power": int(d[18]),
			"at_war": false,
			"status": "Active",
			"last_action": "Watching...",
			"action_timer": rng.randf_range(30.0, ACTION_INTERVAL_MIN),
			"growth_timer": rng.randf_range(10.0, GROWTH_INTERVAL),
		}
		out.append(r)
	return out


static func merge_save_rivals(rivals: Array, saved: Array) -> void:
	for i in mini(saved.size(), rivals.size()):
		var rd = saved[i]
		if typeof(rd) != TYPE_DICTIONARY:
			continue
		rivals[i]["turf"] = int(rd.get("turf", rd.get("territory", rivals[i].get("turf", 0))))
		rivals[i]["wealth"] = float(rd.get("wealth", rivals[i].get("wealth", 0.0)))
		rivals[i]["power"] = int(rd.get("power", rivals[i].get("power", 0)))
		rivals[i]["aggression"] = float(rd.get("aggression", rivals[i].get("aggression", 0.5)))
		rivals[i]["at_war"] = bool(rd.get("at_war", false))
		rivals[i]["status"] = str(rd.get("status", "Active"))
		rivals[i]["last_action"] = str(rd.get("last_action", "Watching..."))


static func rivals_to_save(rivals: Array) -> Array:
	var out: Array = []
	for r in rivals:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		out.append({
			"turf": int(r.get("turf", 0)),
			"wealth": float(r.get("wealth", 0.0)),
			"power": int(r.get("power", 0)),
			"aggression": float(r.get("aggression", 0.5)),
			"at_war": bool(r.get("at_war", false)),
			"status": str(r.get("status", "Active")),
			"last_action": str(r.get("last_action", "Watching...")),
		})
	return out


static func reconstitute_eliminated_rivals(rivals: Array, rng: RandomNumberGenerator, restore_fraction: float = 0.30) -> int:
	var count: int = 0
	for rival in rivals:
		if typeof(rival) != TYPE_DICTIONARY or str(rival.get("status", "")) != "Eliminated":
			continue
		var defaults: Array = []
		for d in _FACTION_DEFS:
			if str(d[13]) == str(rival.get("faction_key", "")):
				defaults = d
				break
		var turf: int = 1
		var wealth: float = 500000.0
		var power: int = 10
		if not defaults.is_empty():
			turf = int(float(defaults[16]) * restore_fraction)
			wealth = float(defaults[17]) * restore_fraction
			power = int(float(defaults[18]) * restore_fraction)
		rival["status"] = "Active"
		rival["turf"] = maxi(1, turf)
		rival["wealth"] = maxf(100000.0, wealth)
		rival["power"] = maxi(5, power)
		rival["at_war"] = false
		rival["action_timer"] = rng.randf_range(120.0, 180.0)
		rival["last_action"] = "Regrouping..."
		count += 1
	return count


static func get_empire_impact(state) -> Dictionary:
	var total_power: int = 0
	var total_wealth: float = 0.0
	var high_agg: float = 0.0
	var investig_active: bool = false
	for r in state.rivals:
		if typeof(r) != TYPE_DICTIONARY or str(r.get("status", "")) == "Eliminated":
			continue
		total_power += int(r.get("power", 0))
		total_wealth += float(r.get("wealth", 0.0))
		var agg: float = float(r.get("aggression", 0.0))
		if agg > high_agg:
			high_agg = agg
		if str(r.get("trait", "")) in ["Investigative", "Surveillance"]:
			investig_active = true
	return {
		"territory_penalty": minf(0.30, float(total_power) / 1000.0),
		"raid_mult": 1.0 + high_agg * 0.4,
		"heat_drain_rate": 1.5 if investig_active else 0.0,
		"total_power": total_power,
		"total_wealth": total_wealth,
	}


static func update_rivals(state, dt: float, rng: RandomNumberGenerator) -> Array[String]:
	return _RivalAi.update_rivals(state, dt, rng)


static func preview_success_chance(rival: Dictionary, action: String, state = null) -> float:
	var bonus: float = 0.0
	if state != null:
		bonus = _PrestigeTree.combat_success_bonus(state)
	return minf(0.95, _base_success(rival, action) + bonus)


static func action_cost(state, action: String) -> float:
	var ips: float = state.income_per_second()
	match action:
		"attack":
			return maxf(ATTACK_MIN_BALANCE, ips * 20.0)
		"bribe":
			return maxf(1000000.0, ips * 120.0)
		"sabotage":
			return maxf(500000.0, ips * 60.0)
	return 0.0


static func can_afford_action(state, action: String) -> bool:
	var cost: float = action_cost(state, action)
	if cost <= 0.0:
		return true
	return state.balance >= cost


static func action_block_reason(state, rival: Dictionary, action: String) -> String:
	if str(rival.get("status", "")) == "Eliminated":
		return "%s is already eliminated." % rival.get("name", "?")
	match action:
		"attack":
			var attack_min: float = action_cost(state, "attack")
			if state.balance < attack_min:
				return "Need %s to mount an attack." % FormatUtil.format_money(attack_min)
		"bribe":
			var bribe_cost: float = action_cost(state, "bribe")
			if state.balance < bribe_cost:
				return "Need %s to bribe." % FormatUtil.format_money(bribe_cost)
		"sabotage":
			var sabotage_cost: float = action_cost(state, "sabotage")
			if state.balance < sabotage_cost:
				return "Need %s for a sabotage op." % FormatUtil.format_money(sabotage_cost)
		"negotiate":
			if state.heat < NEGOTIATE_HEAT_MIN:
				return "Not enough heat leverage to negotiate."
	return ""


static func perform_action(state, rival_idx: int, action: String, rng: RandomNumberGenerator) -> String:
	if rival_idx < 0 or rival_idx >= state.rivals.size():
		return "Action unavailable"
	var rival: Dictionary = state.rivals[rival_idx]
	if typeof(rival) != TYPE_DICTIONARY:
		return "Action unavailable"
	if str(rival.get("status", "")) == "Eliminated":
		return "%s is already eliminated." % rival.get("name", "?")
	var r_turf: int = int(rival.get("turf", 0))
	var r_wealth: float = float(rival.get("wealth", 0.0))
	var r_power: int = int(rival.get("power", 0))
	var r_aggression: float = float(rival.get("aggression", 0.5))
	var blocked := action_block_reason(state, rival, action)
	if not blocked.is_empty():
		return blocked
	var success: bool = rng.randf() < preview_success_chance(rival, action, state)
	var balance: float = state.balance
	var heat: float = state.heat
	var tokens: int = state.prestige_tokens
	var respect: int = state.influence
	if action == "attack":
		if success:
			var cash_reward: float = maxf(25000.0, r_wealth * 0.12) * _PrestigeTree.combat_reward_mult(state)
			rival["turf"] = maxi(0, r_turf - 1)
			rival["wealth"] = maxf(0.0, r_wealth - cash_reward)
			rival["power"] = maxi(0, r_power - 8)
			if int(rival["turf"]) == 0 and float(rival["wealth"]) < 100000.0 and int(rival["power"]) < 5:
				rival["status"] = "Eliminated"
				return _defeat_rival(state, rival, r_wealth, balance, tokens, respect)
			state.balance = balance + cash_reward
			state.prestige_tokens = tokens + 1
			state.influence = respect + 10
			if int(rival["turf"]) == 0:
				rival["status"] = "Weakened"
			else:
				rival["status"] = "Active"
			_log(state, "%s lost a district to your forces." % rival.get("name", "?"))
			return "Victory! Seized %s cash  +1 Influence  +10 Respect" % FormatUtil.format_money(cash_reward)
		var balance_penalty: float = balance * 0.05
		state.heat = minf(100.0, heat + 14.0)
		state.balance = maxf(0.0, balance - balance_penalty)
		rival["wealth"] = minf(float(rival["wealth"]) + balance_penalty, 500000000.0)
		_log(state, "%s repelled your attack." % rival.get("name", "?"))
		return "Repelled! +14 heat, lost %s" % FormatUtil.format_money(balance_penalty)
	if action == "bribe":
		var cost: float = action_cost(state, "bribe")
		state.balance = maxf(0.0, balance - cost)
		if success:
			rival["power"] = maxi(0, r_power - 10)
			rival["wealth"] = maxf(0.0, r_wealth * 0.75)
			state.heat = maxf(0.0, heat - 10.0)
			state.prestige_tokens = tokens + 1
			state.influence = respect + 8
			_log(state, "%s was bribed into inaction." % rival.get("name", "?"))
			return "Bribed! -10 heat, +1 Influence, +8 Respect"
		state.heat = minf(100.0, heat + 8.0)
		return "Bribe rejected! +8 heat, lost %s" % FormatUtil.format_money(cost)
	if action == "negotiate":
		if success:
			rival["at_war"] = false
			rival["aggression"] = maxf(0.10, r_aggression - 0.12)
			state.heat = maxf(0.0, heat - 15.0)
			state.prestige_tokens = tokens + 1
			state.influence = respect + 6
			_log(state, "Peace deal struck with %s." % rival.get("name", "?"))
			return "Peace deal with %s. -15 heat, +1 Influence, +6 Respect" % rival.get("name", "?")
		state.heat = minf(100.0, heat + 5.0)
		_log(state, "%s rejected negotiations." % rival.get("name", "?"))
		return "Negotiations collapsed. +5 heat"
	if action == "sabotage":
		var sabotage_cost: float = action_cost(state, "sabotage")
		state.balance = maxf(0.0, balance - sabotage_cost)
		if success:
			rival["wealth"] = maxf(0.0, r_wealth * 0.55)
			rival["power"] = maxi(0, r_power - 12)
			if int(rival.get("turf", 0)) == 0 and float(rival["wealth"]) < 100000.0 and int(rival["power"]) < 5:
				rival["status"] = "Eliminated"
				return _defeat_rival(state, rival, r_wealth, balance, tokens, respect)
			state.prestige_tokens = tokens + 1
			state.influence = respect + 10
			var rival_name: String = str(rival.get("name", "?"))
			_log(state, "%s operations were sabotaged." % rival_name)
			return "Sabotage succeeded! %s lost half their wealth. +1 Influence, +10 Respect" % rival_name
		state.heat = minf(100.0, heat + 10.0)
		return "Sabotage blown! +10 heat, lost %s" % FormatUtil.format_money(sabotage_cost)
	return "Action unavailable"


static func _base_success(rival: Dictionary, action: String) -> float:
	var aggression: float = float(rival.get("aggression", 0.5))
	var power: int = int(rival.get("power", 0))
	var wealth: float = float(rival.get("wealth", 0.0))
	var power_penalty: float = minf(0.25, float(power) / 800.0)
	var wealth_penalty: float = minf(0.15, wealth / 100000000.0)
	var base: float = 0.5
	match action:
		"attack":
			base = 0.60 - aggression * 0.2 - power_penalty
		"bribe":
			base = 0.65 - wealth_penalty * 2.0
		"negotiate":
			base = 0.70 - aggression * 0.3
		"sabotage":
			base = 0.55 - power_penalty
	return clampf(base, 0.10, 0.90)


static func _defeat_rival(
	state,
	rival: Dictionary,
	pre_wealth: float,
	pre_balance: float,
	pre_tokens: int,
	pre_respect: int,
) -> String:
	var cash_bonus: float = maxf(500000.0, pre_wealth * 0.35)
	state.balance = pre_balance + cash_bonus
	state.prestige_tokens = pre_tokens + 3
	state.influence = pre_respect + 30
	var heat_bonus: String = ""
	if str(rival.get("trait", "")) == "Investigative":
		state.heat = maxf(0.0, state.heat - 30.0)
		heat_bonus = "-30 heat!"
	var freed: int = _TerritorySystem.release_rival_territories(state.territories, str(rival.get("name", "")))
	state.total_rivals_defeated += 1
	_log(state, "%s has been eliminated." % rival.get("name", "?"))
	var reward_str: String = "+%s  +3 Influence  +30 Respect" % FormatUtil.format_money(cash_bonus)
	if freed > 0:
		var suffix: String = "s" if freed != 1 else ""
		reward_str += "  %d district%s freed" % [freed, suffix]
	if not heat_bonus.is_empty():
		reward_str += "  %s" % heat_bonus
	var flavor: String = str(ELIMINATION_LINES.get(str(rival.get("faction_key", "")), "has collapsed."))
	var rival_name: String = str(rival.get("name", "?"))
	state.show_elimination_overlay(rival_name, flavor, reward_str)
	return ""
