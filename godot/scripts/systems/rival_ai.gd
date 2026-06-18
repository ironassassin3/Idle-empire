extends RefCounted
## Rival AI tick — port of src/rivals.py Rival._grow / tick / _take_action / _blackwater_action.

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

const ACTION_INTERVAL_MIN := 90.0
const ACTION_INTERVAL_MAX := 180.0
const GROWTH_INTERVAL := 45.0
const LOG_MAX := 10
const WEALTH_CAP := 5000000000.0
const RAID_LOOT_CAP := 500000000.0


static func _log(state, msg: String) -> void:
	state.rival_activity_log.append(msg)
	while state.rival_activity_log.size() > LOG_MAX:
		state.rival_activity_log.pop_front()


static func _other_active_rivals(state, self_rival: Dictionary) -> Array:
	var out: Array = []
	for r in state.rivals:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if r == self_rival:
			continue
		if str(r.get("status", "")) == "Eliminated":
			continue
		if int(r.get("turf", 0)) <= 0:
			continue
		out.append(r)
	return out


static func _check_weakened(r: Dictionary) -> void:
	if int(r.get("turf", 0)) == 0 and float(r.get("wealth", 0.0)) < 100000.0 and int(r.get("power", 0)) < 10:
		r["status"] = "Weakened"


static func _grow(state, r: Dictionary, rng: RandomNumberGenerator) -> void:
	var player_balance: float = float(state.balance)
	var turf: int = int(r.get("turf", 0))
	var wealth: float = float(r.get("wealth", 0.0))
	var trait_text: String = str(r.get("trait", ""))
	var base_wealth_gain: float = float(turf) * 200000.0
	var catch_up: float = maxf(1.0, player_balance / maxf(1.0, wealth * 10.0))
	var wealth_gain: float = base_wealth_gain * minf(catch_up, 5.0)
	wealth_gain *= _DragonSystem.rival_growth_mult(state)

	if trait_text in ["Wealthy", "Corrupt"]:
		wealth_gain *= 2.5
	elif trait_text == "Territorial":
		if turf < 8 and rng.randf() < 0.30:
			r["turf"] = turf + 1
			var symbol: String = str(r.get("symbol", ""))
			var rival_name: String = str(r.get("name", "?"))
			var msg: String
			if not symbol.is_empty():
				msg = "%s %s captured a new district." % [symbol, rival_name]
			else:
				msg = "%s captured a new district." % rival_name
			_log(state, msg)
	elif trait_text in ["Investigative", "Surveillance"]:
		state.heat = minf(100.0, state.heat + 2.0)
	elif trait_text == "Smuggler":
		wealth_gain *= 1.8

	r["wealth"] = minf(wealth + wealth_gain, WEALTH_CAP)
	r["power"] = mini(int(r.get("power", 0)) + 1, 300)


static func _blackwater_action(state, r: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var events: Array[String] = []
	var roll: float = rng.randf()
	var name: String = str(r.get("name", "?"))
	var turf: int = int(r.get("turf", 0))
	var wealth: float = float(r.get("wealth", 0.0))
	var power: int = int(r.get("power", 0))

	if roll < 0.40 and wealth > 1000000.0:
		var claimed: String = _TerritorySystem.rival_claim_preferred(
			state.territories, name,
			r.get("preferred_district_names", []),
			r.get("preferred_district_types", []))
		r["turf"] = mini(8, turf + 1)
		r["wealth"] = maxf(0.0, wealth - 500000.0)
		r["power"] = mini(300, power + 2)
		var msg: String
		if not claimed.is_empty():
			msg = "~ %s seized %s." % [name, claimed]
		else:
			msg = "~ %s expanded along the waterfront." % name
		_log(state, msg)
		events.append(msg)
		r["last_action"] = "Secured a harbor district"

	elif roll < 0.62:
		r["wealth"] = minf(wealth + float(turf) * 300000.0, WEALTH_CAP)
		r["last_action"] = "Running smuggling routes"
		r["at_war"] = false

	elif roll < 0.80 and turf > 0:
		r["wealth"] = minf(wealth + 200000.0, WEALTH_CAP)
		var msg: String = "~ %s tightened its grip on the shipping lanes." % name
		_log(state, msg)
		events.append(msg)
		r["last_action"] = "Pressuring shipping routes"

	else:
		var others: Array = _other_active_rivals(state, r)
		if not others.is_empty():
			var victim: Dictionary = others[rng.randi_range(0, others.size() - 1)]
			victim["wealth"] = maxf(0.0, float(victim.get("wealth", 0.0)) - 500000.0)
			victim["power"] = maxi(0, int(victim.get("power", 0)) - 2)
			r["wealth"] = minf(float(r.get("wealth", 0.0)) + 300000.0, WEALTH_CAP)
			var victim_name: String = str(victim.get("name", "?"))
			_log(state, "~ %s undercut %s's trade routes." % [name, victim_name])
		r["last_action"] = "Cutting deals in the dark"

	_check_weakened(r)
	return events


static func _take_action(state, r: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	if str(r.get("faction_key", "")) == "blackwater":
		return _blackwater_action(state, r, rng)

	var events: Array[String] = []
	var roll: float = rng.randf()
	var trait_text: String = str(r.get("trait", ""))
	var symbol: String = str(r.get("symbol", ""))
	var name: String = str(r.get("name", "?"))
	var turf: int = int(r.get("turf", 0))
	var wealth: float = float(r.get("wealth", 0.0))
	var power: int = int(r.get("power", 0))
	var aggression: float = float(r.get("aggression", 0.5))
	var player_turf: int = _TerritorySystem.player_district_count(state.territories)

	# Opportunistic (legacy trait): target weakened rivals
	if trait_text == "Opportunistic":
		var targets: Array = []
		for other in state.rivals:
			if typeof(other) != TYPE_DICTIONARY or other == r:
				continue
			if str(other.get("status", "")) != "Weakened":
				continue
			if int(other.get("turf", 0)) <= 0:
				continue
			targets.append(other)
		if not targets.is_empty() and roll < 0.45:
			var victim: Dictionary = targets[rng.randi_range(0, targets.size() - 1)]
			var stolen: int = maxi(1, int(victim.get("turf", 0)) / 2)
			victim["turf"] = maxi(0, int(victim.get("turf", 0)) - stolen)
			victim["power"] = maxi(0, int(victim.get("power", 0)) - 5)
			r["turf"] = mini(8, int(r.get("turf", 0)) + stolen)
			r["wealth"] = minf(float(r.get("wealth", 0.0)) + float(victim.get("wealth", 0.0)) * 0.3, RAID_LOOT_CAP)
			var victim_name: String = str(victim.get("name", "?"))
			var msg: String = "%s seized %d district(s) from %s." % [name, stolen, victim_name]
			_log(state, msg)
			events.append(msg)
			r["last_action"] = "Exploited a weakened rival"
			return events

	var raid_threshold: float = 0.55
	if trait_text in ["Aggressive", "Violent"]:
		raid_threshold = 0.70

	var effective_aggression: float = aggression * _DragonSystem.rival_aggression_mult(state)

	if wealth > 500000.0 and roll < 0.25:
		r["turf"] = mini(8, turf + 1)
		r["wealth"] = maxf(0.0, wealth - 250000.0)
		r["power"] = mini(300, power + 2)
		r["last_action"] = "Expanded into new territory"
		var claimed: String = _TerritorySystem.rival_claim_preferred(
			state.territories, name,
			r.get("preferred_district_names", []),
			r.get("preferred_district_types", []))
		var prefix: String = "%s " % symbol if not symbol.is_empty() else ""
		var msg: String
		if not claimed.is_empty():
			msg = "%s%scaptured %s." % [prefix, name, claimed]
		else:
			msg = "%s%scaptured a new district." % [prefix, name]
		_log(state, msg)
		events.append(msg)

	elif effective_aggression > rng.randf() and player_turf > 0 and roll < raid_threshold:
		r["at_war"] = true
		var ips: float = state.income_per_second()
		var balance: float = state.balance
		var raw_penalty: float = minf(balance * 0.06, maxf(500.0, ips * 45.0))
		raw_penalty *= _DragonSystem.raid_damage_mult(state)
		var result: Dictionary = _ManagerSystem.apply_raid_penalty(state, raw_penalty)
		var actual: float = float(result.get("actual", 0.0))
		var absorbed: bool = bool(result.get("absorbed", false))
		var counter: bool = _DragonSystem.try_counterattack(state, r)
		var heat_gain: float = 10.0 if trait_text == "Aggressive" else 8.0
		state.heat = minf(100.0, state.heat + heat_gain)
		r["wealth"] = minf(float(r.get("wealth", 0.0)) + actual, RAID_LOOT_CAP)
		r["last_action"] = "Raided your operation"
		var sym_prefix: String = "%s " % symbol if not symbol.is_empty() else ""
		var event_msg: String
		if absorbed:
			event_msg = "RAID: %s%s struck — Collector handled it!" % [sym_prefix, name]
		else:
			event_msg = "RAID: %s%s hit you for %s!" % [sym_prefix, name, FormatUtil.format_money(actual)]
		if counter:
			event_msg += " Counterattack weakened %s!" % name
		_log(state, "%s raided your operations." % name)
		events.append(event_msg.strip_edges())

	elif roll < 0.12 and turf > 0:
		r["turf"] = maxi(0, turf - 1)
		r["wealth"] = maxf(0.0, wealth - 50000.0)
		r["power"] = maxi(0, power - 3)
		r["last_action"] = "Lost territory to infighting"
		var msg: String = "%s lost influence from internal conflict." % name
		_log(state, msg)
		events.append(msg)

	else:
		r["wealth"] = minf(wealth + float(turf) * 150000.0, WEALTH_CAP)
		r["last_action"] = "Consolidating power"
		r["at_war"] = false

	# Rival vs rival: occasionally fight each other
	if roll > 0.80:
		var others: Array = _other_active_rivals(state, r)
		if not others.is_empty():
			var victim: Dictionary = others[rng.randi_range(0, others.size() - 1)]
			victim["turf"] = maxi(0, int(victim.get("turf", 0)) - 1)
			victim["power"] = maxi(0, int(victim.get("power", 0)) - 4)
			victim["wealth"] = maxf(0.0, float(victim.get("wealth", 0.0)) - 200000.0)
			r["turf"] = mini(8, int(r.get("turf", 0)) + 1)
			var v_symbol: String = str(victim.get("symbol", ""))
			var v_name: String = str(victim.get("name", "?"))
			var sym_part: String = "%s " % symbol if not symbol.is_empty() else ""
			var v_sym_part: String = "%s " % v_symbol if not v_symbol.is_empty() else ""
			var msg: String = "%s%sseized turf from %s%s." % [sym_part, name, v_sym_part, v_name]
			_log(state, msg.strip_edges())

	_check_weakened(r)
	return events


static func _tick_rival(state, r: Dictionary, dt: float, rng: RandomNumberGenerator) -> Array[String]:
	if str(r.get("status", "")) == "Eliminated":
		return []

	var growth_timer: float = float(r.get("growth_timer", GROWTH_INTERVAL)) - dt
	if growth_timer <= 0.0:
		r["growth_timer"] = GROWTH_INTERVAL + rng.randf_range(-10.0, 10.0)
		_grow(state, r, rng)
	else:
		r["growth_timer"] = growth_timer

	var action_timer: float = float(r.get("action_timer", ACTION_INTERVAL_MIN)) - dt
	if action_timer > 0.0:
		r["action_timer"] = action_timer
		return []

	r["action_timer"] = rng.randf_range(ACTION_INTERVAL_MIN, ACTION_INTERVAL_MAX)
	return _take_action(state, r, rng)


static func update_rivals(state, dt: float, rng: RandomNumberGenerator) -> Array[String]:
	var events: Array[String] = []
	for r in state.rivals:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		events.append_array(_tick_rival(state, r, dt, rng))
	events.append_array(_DragonSystem.try_jade_de_escalate(state, rng))
	return events
