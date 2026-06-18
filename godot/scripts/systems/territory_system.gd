class_name TerritorySystem
extends RefCounted
## Territory warfare — port of src/territory.py (mechanics only, no pygame draw).

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _Prestige = preload("res://scripts/systems/prestige.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

const TOTAL_DISTRICTS := 20

const STRATEGIC_NAMES := [
	"South Side", "Downtown", "Industrial District", "Waterfront", "City Hall",
]

const MILESTONE_DEFS := [
	["25", 0.25, "+10% Influence Gain"],
	["50", 0.50, "+25% Respect Gain"],
	["75", 0.75, "-15% Heat Generation"],
	["100", 1.00, "+50% Global Income"],
]

const ACTIONS := [
	["attack", "Attack"],
	["bribe", "Bribe"],
	["negotiate", "Negotiate"],
	["sabotage", "Sabotage"],
]

# name, desc, unlock_cost, income_bonus, click_bonus, heat_resistance, news_tag,
# color (r,g,b 0-255), perk, perk_key, district_type
const _TERRITORY_DEFS: Array = [
	["South Side", "Your home turf. Cheap and loyal.", 0, 0.0, 0.0, 0.0, "south_side",
		[80, 120, 80], "Home Turf", "", ""],
	["Downtown", "The money district. Biggest straight income boost.", 0, 0.20, 0.06, 0.0, "downtown",
		[80, 120, 180], "CASH: +20% income, +6% clicks", "cash", ""],
	["Industrial District", "Warehouses and chop shops — your operations hub.", 5, 0.10, 0.0, 0.12, "industrial",
		[160, 120, 60], "OPERATIONS: +25% op rewards, -12% heat", "operations", ""],
	["Waterfront", "Open smuggling routes. Risky work pays the most.", 15, 0.15, 0.05, 0.04, "waterfront",
		[60, 140, 180], "SMUGGLING: +15% op success & rewards", "smuggling", ""],
	["City Hall", "You own the politicians. Heat can't touch you here.", 40, 0.30, 0.12, 0.25, "city_hall",
		[200, 160, 60], "POLITICS: heat shield + prestige boost", "politics", ""],
	["Eastside Heights", "Working neighborhoods. Steady, reliable revenue.", 2, 0.01, 0.0, 0.0, "eastside",
		[100, 150, 100], "RESIDENTIAL: +1% income", "", "residential"],
	["Sunset Gardens", "Quiet streets. Consistent flow, low exposure.", 8, 0.01, 0.0, 0.0, "sunset",
		[120, 160, 90], "RESIDENTIAL: +1% income", "", "residential"],
	["Millbrook Park", "Upscale housing. High rent keeps you funded.", 20, 0.015, 0.0, 0.0, "millbrook",
		[130, 170, 80], "RESIDENTIAL: +1.5% income", "", "residential"],
	["Harbor View", "Old money neighborhood. Premium returns.", 35, 0.015, 0.0, 0.0, "harborview",
		[70, 160, 140], "RESIDENTIAL: +1.5% income", "", "residential"],
	["Rail Yards", "Freight hub. Product moves undetected through here.", 10, 0.0, 0.0, 0.03, "railyards",
		[150, 110, 60], "INDUSTRIAL: +2% op rewards, -3% heat", "", "industrial"],
	["Machine Quarter", "Chop shops and auto yards. Lucrative rackets.", 25, 0.0, 0.0, 0.04, "machinequarter",
		[170, 125, 45], "INDUSTRIAL: +2% op rewards, -4% heat", "", "industrial"],
	["Warehouse Row", "Storage and logistics. Operations run smoothly.", 45, 0.0, 0.0, 0.06, "warehouserow",
		[185, 135, 50], "INDUSTRIAL: +2% op rewards, -6% heat", "", "industrial"],
	["Shopping District", "Storefronts and buzz. Reputation spreads fast here.", 5, 0.01, 0.02, 0.0, "shopping",
		[200, 140, 80], "COMMERCIAL: +1% income, +2% clicks", "", "commercial"],
	["Entertainment Row", "Bars and clubs. Everyone talks, everyone pays.", 18, 0.01, 0.02, 0.0, "entertainment",
		[210, 120, 100], "COMMERCIAL: +1% income, +2% clicks", "", "commercial"],
	["Market Square", "Street vendors and merchants under your wing.", 30, 0.01, 0.02, 0.0, "marketsquare",
		[195, 155, 75], "COMMERCIAL: +1% income, +2% clicks", "", "commercial"],
	["Hotel Quarter", "Business travelers bring money and opportunity.", 50, 0.015, 0.03, 0.0, "hotelquarter",
		[210, 165, 95], "COMMERCIAL: +1.5% income, +3% clicks", "", "commercial"],
	["Civic Center", "City officials on the payroll. Fewer problems.", 15, 0.0, 0.0, 0.04, "civiccenter",
		[140, 140, 220], "GOVERNMENT: -4% heat rise, +2% respect gain", "", "government"],
	["Police Precinct", "Compromised cops. Raids hit softer.", 28, 0.0, 0.0, 0.06, "precinct",
		[120, 120, 210], "GOVERNMENT: -6% heat rise, +2% respect gain", "", "government"],
	["Federal Building", "Influence at the federal level. Near-untouchable.", 60, 0.0, 0.0, 0.08, "federal",
		[100, 100, 200], "GOVERNMENT: -8% heat rise, +2% respect gain", "", "government"],
	["City Courts", "Judges and clerks in your pocket. Legal immunity.", 80, 0.0, 0.0, 0.10, "citycourts",
		[90, 90, 200], "GOVERNMENT: -10% heat rise, +2% respect gain", "", "government"],
]


static func make_territories() -> Array:
	var out: Array = []
	for i in _TERRITORY_DEFS.size():
		var d: Array = _TERRITORY_DEFS[i]
		var col: Array = d[7]
		var t: Dictionary = {
			"name": d[0],
			"description": d[1],
			"unlock_cost": float(d[2]),
			"income_bonus": float(d[3]),
			"click_bonus": float(d[4]),
			"heat_resistance": float(d[5]),
			"news_tag": d[6],
			"color": Color(float(col[0]) / 255.0, float(col[1]) / 255.0, float(col[2]) / 255.0),
			"perk": d[8],
			"perk_key": d[9],
			"district_type": d[10],
			"unlocked": false,
			"contested": false,
			"owner": "unclaimed",
		}
		if i == 0:
			t["unlocked"] = true
			t["owner"] = "player"
		out.append(t)
	return out


static func merge_save_territories(territories: Array, saved: Array) -> void:
	for i in mini(saved.size(), territories.size()):
		var td = saved[i]
		if typeof(td) == TYPE_DICTIONARY:
			territories[i]["unlocked"] = bool(td.get("unlocked", false))
			territories[i]["owner"] = str(td.get("owner", "unclaimed"))
		else:
			var owned: bool = bool(td)
			territories[i]["unlocked"] = owned
			territories[i]["owner"] = "player" if owned else "unclaimed"


static func territories_to_save(territories: Array) -> Array:
	var out: Array = []
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY:
			out.append({
				"unlocked": bool(t.get("unlocked", false)),
				"owner": str(t.get("owner", "unclaimed")),
			})
	return out


static func partial_territory_reset(territories: Array, state) -> int:
	var count := 0
	for t in territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if t["name"] not in STRATEGIC_NAMES:
			t["unlocked"] = false
			t["owner"] = "unclaimed"
			t["contested"] = false
			count += 1
	if state != null:
		state.city_control_milestones = []
	return count


static func assign_rival_territories(territories: Array, rivals: Array) -> void:
	var unclaimed: Array = []
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and str(t.get("owner", "")) == "unclaimed":
			unclaimed.append(t)
	if rivals.is_empty() or unclaimed.is_empty():
		return
	var ordered: Array = []
	for r in rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			ordered.append(r)
	ordered.sort_custom(func(a, b): return int(a.get("turf", 0)) > int(b.get("turf", 0)))
	for i in mini(unclaimed.size(), ordered.size()):
		unclaimed[i]["owner"] = str(ordered[i].get("name", "rival"))


static func release_rival_territories(territories: Array, rival_name: String) -> int:
	var freed := 0
	for t in territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "")) == rival_name and not bool(t.get("unlocked", false)):
			t["owner"] = "unclaimed"
			t["contested"] = false
			freed += 1
	return freed


static func rival_claim_unclaimed(territories: Array, rival_name: String) -> String:
	for t in territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "unclaimed")) == "unclaimed" and not bool(t.get("unlocked", false)):
			t["owner"] = rival_name
			return str(t.get("name", ""))
	return ""


static func rival_claim_preferred(
	territories: Array,
	rival_name: String,
	preferred_names: Array = [],
	preferred_types: Array = [],
) -> String:
	var unclaimed: Array = []
	for t in territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "unclaimed")) == "unclaimed" and not bool(t.get("unlocked", false)):
			unclaimed.append(t)
	if unclaimed.is_empty():
		return ""
	for t in unclaimed:
		if str(t.get("name", "")) in preferred_names:
			t["owner"] = rival_name
			return str(t.get("name", ""))
	for t in unclaimed:
		if str(t.get("district_type", "")) in preferred_types:
			t["owner"] = rival_name
			return str(t.get("name", ""))
	unclaimed[0]["owner"] = rival_name
	return str(unclaimed[0].get("name", ""))


static func get_city_control(territories: Array, _rivals: Array) -> Array:
	var total := maxi(1, territories.size())
	var counts: Dictionary = {}
	for t in territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var owner: String = str(t.get("owner", "unclaimed"))
		counts[owner] = int(counts.get(owner, 0)) + 1
	var result: Array = []
	for name in counts:
		if name == "unclaimed":
			continue
		result.append([name, float(counts[name]) / float(total)])
	result.sort_custom(func(a, b): return a[1] > b[1])
	return result


static func territory_economy_scale(state) -> float:
	if state == null:
		return 1.0
	var required: float = _Prestige.prestige_earnings_required(
		int(state.prestige_count), float(state.next_prestige_earnings))
	if required <= 0.0:
		return 1.0
	return minf(1.0, pow(float(state.prestige_route_earnings) / required, 2.0))


static func territory_income_mult(territories: Array, state = null) -> float:
	var bonus := 0.0
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			bonus += float(t.get("income_bonus", 0.0))
	return 1.0 + minf(bonus, 0.25) * territory_economy_scale(state)


static func territory_click_mult(territories: Array, state = null) -> float:
	var bonus := 0.0
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			bonus += float(t.get("click_bonus", 0.0))
	return 1.0 + bonus * territory_economy_scale(state)


static func territory_heat_resistance(territories: Array) -> float:
	var total := 0.0
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			total += float(t.get("heat_resistance", 0.0))
	return total


static func territory_district_count_bonus(territories: Array, state = null) -> float:
	var count := 0
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			count += 1
	return minf(float(count) * 0.005, 0.10) * territory_economy_scale(state)


static func milestone_income_mult(state) -> float:
	if state == null:
		return 1.0
	return 1.50 if "100" in state.city_control_milestones else 1.0


static func milestone_heat_mult(state) -> float:
	if state == null:
		return 1.0
	return 0.85 if "75" in state.city_control_milestones else 1.0


static func player_district_count(territories: Array) -> int:
	var n := 0
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			n += 1
	return n


static func tick_milestones(state) -> Array[String]:
	var events: Array[String] = []
	var territories: Array = state.territories
	var total_t := territories.size()
	if total_t <= 0:
		return events
	var player_t := player_district_count(territories)
	var ctrl_pct: float = float(player_t) / float(total_t)
	if ctrl_pct > state.highest_city_control:
		state.highest_city_control = ctrl_pct
	for thresh in [0.25, 0.50, 0.75, 1.0]:
		var key := str(int(thresh * 100.0))
		if ctrl_pct >= thresh and key not in state.city_control_milestones:
			state.city_control_milestones.append(key)
			var pct_label := int(thresh * 100.0)
			match pct_label:
				25:
					events.append("CITY QUARTER\nYou control 25% of the city!\nREWARD: +10% Influence Gain — permanent.")
				50:
					events.append("HALF THE CITY\nYou control half of the city!\nREWARD: +25% Respect Gain — permanent.")
				75:
					events.append("DOMINANT FORCE\nYou control 75% of the city!\nREWARD: -15% Heat Generation — permanent.")
				100:
					events.append("TOTAL DOMINATION\nYou control the entire city!\nREWARD: +50% Global Income — permanent.")
	return events


static func can_act_on(state, idx: int) -> bool:
	if idx < 0 or idx >= state.territories.size():
		return false
	var t: Dictionary = state.territories[idx]
	if bool(t.get("unlocked", false)):
		return false
	var owner := str(t.get("owner", "unclaimed"))
	# Rival-held districts have no territory buttons in pygame — contest via Rivals tab.
	if owner != "unclaimed" and owner != "player":
		return false
	return state.prestige_tokens >= int(t.get("unlock_cost", 0))


static func broker_best_action(state, terr_idx: int) -> String:
	if not _ManagerSystem.manager_active(state, "The Broker"):
		return ""
	if terr_idx < 0 or terr_idx >= state.territories.size():
		return ""
	var t: Dictionary = state.territories[terr_idx]
	if bool(t.get("unlocked", false)):
		return ""
	var best_action := ""
	var best_chance := 0.0
	for action_def in ACTIONS:
		var action_key: String = str(action_def[0])
		var chance: float = success_chance(state, t, action_key)
		if chance > best_chance:
			best_chance = chance
			best_action = action_key
	return best_action


static func success_chance(state, territory: Dictionary, action: String) -> float:
	var crew_bonus: float = _CrewSystem.territory_action_bonus(state.crew)
	crew_bonus += _ManagerSystem.territory_success_bonus(state)
	crew_bonus += _PrestigeTree.territory_action_bonus(state)
	crew_bonus += _DragonSystem.territory_action_modifier(state, action)
	var inf_bonus: float = minf(float(state.prestige_tokens) * 0.01, 0.25)
	inf_bonus += Prestige.rank_territory_bonus(state.prestige_tokens)
	inf_bonus += state.bw_negotiate_bonus if action == "negotiate" else 0.0
	var base: float = 0.5
	match action:
		"attack":
			base = 0.55
		"bribe":
			base = 0.60
		"negotiate":
			base = 0.70
		"sabotage":
			base = 0.50
	var rival_penalty: float = _territory_rival_penalty(state)
	return clampf(base + crew_bonus + inf_bonus - rival_penalty, 0.10, 0.90)


static func _territory_rival_penalty(state) -> float:
	var total_power := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			total_power += int(r.get("power", 0))
	return minf(0.30, float(total_power) / 1000.0)


static func _apply_respect_gain(state, amount: int) -> int:
	var mult := 1.0
	var gov_count := 0
	for t in state.territories:
		if typeof(t) == TYPE_DICTIONARY and str(t.get("district_type", "")) == "government" and bool(t.get("unlocked", false)):
			gov_count += 1
	mult *= 1.0 + float(gov_count) * 0.02
	if "50" in state.city_control_milestones:
		mult *= 1.25
	return maxi(1, int(round(float(amount) * mult)))


static func perform_action(state, idx: int, action: String, rng: RandomNumberGenerator) -> String:
	var territories: Array = state.territories
	if idx >= territories.size():
		return "Invalid territory."
	var t: Dictionary = territories[idx]
	if bool(t.get("unlocked", false)):
		return "%s is already yours." % t.get("name", "?")
	var owner := str(t.get("owner", "unclaimed"))
	if owner != "unclaimed" and owner != "player":
		return "Held by %s — weaken them in Rivals first." % owner
	if state.prestige_tokens < int(t.get("unlock_cost", 0)):
		return "Need %d Influence to act here." % int(t.get("unlock_cost", 0))

	var success: bool = false
	if _DragonSystem.consume_guaranteed_territory(state):
		success = true
	else:
		success = rng.randf() < success_chance(state, t, action)
		if not success and _ManagerSystem.broker_retry_ready(state):
			state.broker_retry_cd = _ManagerSystem.BROKER_RETRY_CD
			if rng.randf() < success_chance(state, t, action):
				success = true
	var ips: float = state.income_per_second()

	if action == "attack":
		if success:
			_seize_territory(state, t)
			var gain: int = _apply_respect_gain(state, 8)
			state.influence += gain
			state.heat = minf(100.0, state.heat + 15.0)
			return "Seized %s by force! +%d Respect, +15 heat" % [t["name"], gain]
		state.heat = minf(100.0, state.heat + 12.0)
		var loss: float = state.balance * 0.04
		state.balance = maxf(0.0, state.balance - loss)
		return "Attack failed. +12 heat, lost %s" % FormatUtil.format_money(loss)

	if action == "bribe":
		var cost: float = maxf(500.0, ips * 90.0)
		if state.balance < cost:
			return "Need %s to bribe officials." % FormatUtil.format_money(cost)
		state.balance = maxf(0.0, state.balance - cost)
		if success:
			_seize_territory(state, t)
			state.heat = maxf(0.0, state.heat - 5.0)
			return "Bribed your way into %s! -5 heat" % t["name"]
		state.heat = minf(100.0, state.heat + 6.0)
		return "Bribe rejected. +6 heat, lost %s" % FormatUtil.format_money(cost)

	if action == "negotiate":
		if success:
			_seize_territory(state, t)
			var gain: int = _apply_respect_gain(state, 5)
			state.influence += gain
			state.heat = maxf(0.0, state.heat - 3.0)
			return "Negotiated control of %s. +%d Respect, -3 heat" % [t["name"], gain]
		state.heat = minf(100.0, state.heat + 3.0)
		return "Negotiations failed. +3 heat"

	if action == "sabotage":
		var cost: float = maxf(200.0, ips * 30.0)
		if state.balance < cost:
			return "Need %s for sabotage supplies." % FormatUtil.format_money(cost)
		state.balance = maxf(0.0, state.balance - cost)
		if success:
			_seize_territory(state, t)
			state.heat = minf(100.0, state.heat + 8.0)
			var gain: int = _apply_respect_gain(state, 6)
			state.influence += gain
			return "Sabotaged them out of %s! +%d Respect, +8 heat" % [t["name"], gain]
		state.heat = minf(100.0, state.heat + 10.0)
		return "Sabotage discovered. +10 heat, lost %s" % FormatUtil.format_money(cost)

	return "Unknown action."


static func _seize_territory(state, t: Dictionary) -> void:
	t["unlocked"] = true
	t["owner"] = "player"
	t["contested"] = false
	state.total_territories_captured += 1
	_DragonSystem.on_territory_captured(state)
