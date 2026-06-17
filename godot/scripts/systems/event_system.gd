class_name EventSystem
extends RefCounted
## Syndicate events — port of src/events.py (mechanics only).

const _BuffSystem = preload("res://scripts/systems/buff_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

const INTERVAL_MIN := 180.0
const INTERVAL_MAX := 360.0
const OUTCOME_DURATION := 3.5

# title, description, choices [[label, desc, action_key], ...], optional faction_key
const _POOL: Array = [
	["Rival Gang Warehouse", "A rival crew abandoned a warehouse on the edge of your territory.", [
		["Take by Force", "High risk. +15% income for 2 min but +10 heat.", "warehouse_force"],
		["Bribe Officials", "Safe. +8% income for 90s, -5 heat.", "warehouse_bribe"],
		["Ignore It", "Nothing gained, nothing lost.", "ignore"],
	]],
	["Undercover Cop", "Your crew spotted a cop trying to infiltrate operations.", [
		["Expose & Scare", "+cash equal to 30s income, -8 heat.", "cop_expose"],
		["Put on Payroll", "Expensive. -5% balance but -15 heat.", "cop_payroll"],
		["Ignore It", "He stays. Heat keeps climbing.", "ignore"],
	]],
	["Black Market Auction", "Rare goods up for bid — could double returns on a building.", [
		["Bid High", "Costs 5% of balance. +25% income for 3 min.", "auction_bid"],
		["Watch & Wait", "+10% income for 1 min, free.", "auction_watch"],
		["Ignore It", "The lot goes to a rival.", "ignore"],
	]],
	["Shipment Opportunity", "A contact offers a one-time smuggling route — fast cash.", [
		["Take the Deal", "+cash equal to 2 min income. +12 heat.", "ship_take"],
		["Negotiate Down", "+cash equal to 60s income. +4 heat.", "ship_negotiate"],
		["Ignore It", "The contact moves on.", "ignore"],
	]],
	["Politician Needs a Favor", "A city councilman wants something done quietly.", [
		["Help Him", "-10% balance, but -20 heat.", "politician_help"],
		["Threaten Him", "Free. +20% income 90s but +8 heat.", "politician_threaten"],
		["Ignore It", "He goes elsewhere.", "ignore"],
	]],
	["Street War Brewing", "A rival gang is muscling into your territory.", [
		["Crush Them", "+10% income 3 min, +15 heat.", "war_crush"],
		["Pay Them Off", "-8% balance, -10 heat, peace for now.", "war_pay"],
		["Ignore It", "They take a sliver of income.", "war_ignore"],
	]],
	["The Tide Comes In", "Blackwater Mob coordinates a major smuggling run through your territory.", [
		["Intercept", "+cash equal to 90s income, +18 heat.", "bw_intercept"],
		["Let It Run", "Blackwater grows wealthier. Nothing gained.", "ignore"],
		["Exploit the Run", "+cash equal to 45s income, +6 heat, +8% op income 1 min.", "bw_exploit"],
	], "blackwater"],
	["Crab Trap", "The Blackwater Mob fortifies a harbor district.", [
		["Storm It Now", "+15% attack vs Blackwater for 3 min, +12 heat.", "bw_storm"],
		["Bribe the Dockmaster", "-8% balance, Blackwater loses 1 turf.", "bw_bribe_dock"],
		["Ignore It", "The district hardens.", "ignore"],
	], "blackwater"],
	["The Harbor Burns", "Shipping conflict between Blackwater and Iron Union.", [
		["Side with Blackwater", "+15% op rewards 3 min. Blackwater gains turf.", "bw_side_black"],
		["Side with Iron Union", "+10% income 3 min. Iron Union gains turf.", "bw_side_iron"],
		["Stay Out", "Both factions lose power.", "bw_stay_out"],
	], "blackwater"],
	["Salt Water Warning", "A Blackwater lieutenant delivers a message outside your office.", [
		["Send Them Back", "+8 heat. Blackwater becomes more aggressive.", "bw_send_back"],
		["Listen", "-10 heat. Negotiate success +15% for 2 min.", "bw_listen"],
		["Ignore It", "Blackwater claims an industrial district.", "bw_ignore_warn"],
	], "blackwater"],
	["The Dockmaster's Deal", "Blackwater offers a smuggling partnership.", [
		["Take the Deal", "+20% op income 3 min. Blackwater gains +5 power.", "bw_take_deal"],
		["Counter-Offer", "+1 Influence, Blackwater steps back from one district.", "bw_counter"],
		["Refuse", "Nothing gained, nothing lost.", "ignore"],
	], "blackwater"],
]


static func init_timers(state) -> void:
	if state.event_timer < 0.0:
		state.event_timer = randf_range(INTERVAL_MIN, INTERVAL_MAX)


static func update_events(state, dt: float, rng: RandomNumberGenerator) -> void:
	init_timers(state)
	if not state.event_outcome.is_empty():
		state.event_outcome_timer -= dt
		if state.event_outcome_timer <= 0.0:
			state.event_outcome = ""
	if not state.pending_event.is_empty():
		return
	state.event_timer -= dt
	if state.event_timer <= 0.0:
		_spawn_event(state, rng)


static func _active_faction_keys(state) -> Array:
	var keys: Array = []
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			var k: String = str(r.get("faction_key", ""))
			if not k.is_empty() and k not in keys:
				keys.append(k)
	return keys


static func _spawn_event(state, rng: RandomNumberGenerator) -> void:
	var active := _active_faction_keys(state)
	var pool: Array = []
	for entry in _POOL:
		if entry.size() >= 4:
			if str(entry[3]) in active:
				pool.append(entry)
		else:
			pool.append(entry)
	if pool.is_empty():
		for entry in _POOL:
			if entry.size() < 4:
				pool.append(entry)
	if pool.is_empty():
		return
	var picked: Array = pool[rng.randi_range(0, pool.size() - 1)]
	var choices: Array = []
	for c in picked[2]:
		choices.append({"label": c[0], "desc": c[1], "action": c[2]})
	state.pending_event = {"title": picked[0], "description": picked[1], "choices": choices}
	state.event_timer = rng.randf_range(INTERVAL_MIN, INTERVAL_MAX)
	state.event_is_first = not state.shown_syndicate_tutorial


static func resolve_event(state, choice_idx: int) -> void:
	if state.pending_event.is_empty():
		return
	var choices: Array = state.pending_event.get("choices", [])
	if choice_idx < 0 or choice_idx >= choices.size():
		return
	var choice: Dictionary = choices[choice_idx]
	var outcome: String = _apply_action(state, str(choice.get("action", "ignore")))
	state.event_outcome = "%s: %s" % [choice.get("label", "?"), outcome]
	state.event_outcome_timer = OUTCOME_DURATION
	if state.event_is_first:
		state.shown_syndicate_tutorial = true
		state.event_is_first = false
	state.pending_event = {}


static func _find_rival(state, faction_key: String) -> Dictionary:
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("faction_key", "")) == faction_key and str(r.get("status", "")) != "Eliminated":
			return r
	return {}


static func _credit(state, amount: float) -> void:
	state.balance += amount
	state.lifetime_earnings += amount


static func _apply_action(state, action_key: String) -> String:
	var ips: float = state.income_per_second()
	match action_key:
		"ignore":
			return "You let it pass."
		"war_ignore":
			return "You let it pass."
		"warehouse_force":
			_BuffSystem.add_buff(state, "syndicate_income", 120.0, 1.15)
			state.heat = minf(100.0, state.heat + 10.0)
			return "+15% income 2min, +10 heat"
		"warehouse_bribe":
			_BuffSystem.add_buff(state, "syndicate_income", 90.0, 1.08)
			state.heat = maxf(0.0, state.heat - 5.0)
			return "+8% income 90s, -5 heat"
		"cop_expose":
			var gain: float = ips * 30.0
			_credit(state, gain)
			state.heat = maxf(0.0, state.heat - 8.0)
			return "+%s cash, -8 heat" % FormatUtil.format_money(gain)
		"cop_payroll":
			var cost: float = state.balance * 0.05
			state.balance = maxf(0.0, state.balance - cost)
			state.heat = maxf(0.0, state.heat - 15.0)
			return "-%s balance, -15 heat" % FormatUtil.format_money(cost)
		"auction_bid":
			var cost2: float = state.balance * 0.05
			state.balance = maxf(0.0, state.balance - cost2)
			_BuffSystem.add_buff(state, "syndicate_income", 180.0, 1.25)
			return "-%s balance, +25% income 3min" % FormatUtil.format_money(cost2)
		"auction_watch":
			_BuffSystem.add_buff(state, "syndicate_income", 60.0, 1.10)
			return "+10% income 1min"
		"ship_take":
			var g1: float = ips * 120.0
			_credit(state, g1)
			state.heat = minf(100.0, state.heat + 12.0)
			return "+%s cash, +12 heat" % FormatUtil.format_money(g1)
		"ship_negotiate":
			var g2: float = ips * 60.0
			_credit(state, g2)
			state.heat = minf(100.0, state.heat + 4.0)
			return "+%s cash, +4 heat" % FormatUtil.format_money(g2)
		"politician_help":
			var c3: float = state.balance * 0.10
			state.balance = maxf(0.0, state.balance - c3)
			state.heat = maxf(0.0, state.heat - 20.0)
			return "-%s balance, -20 heat" % FormatUtil.format_money(c3)
		"politician_threaten":
			_BuffSystem.add_buff(state, "syndicate_income", 90.0, 1.20)
			state.heat = minf(100.0, state.heat + 8.0)
			return "+20% income 90s, +8 heat"
		"war_crush":
			_BuffSystem.add_buff(state, "syndicate_income", 180.0, 1.10)
			state.heat = minf(100.0, state.heat + 15.0)
			return "+10% income 3min, +15 heat"
		"war_pay":
			var c4: float = state.balance * 0.08
			state.balance = maxf(0.0, state.balance - c4)
			state.heat = maxf(0.0, state.heat - 10.0)
			return "-%s balance, -10 heat" % FormatUtil.format_money(c4)
		"bw_intercept":
			var g3: float = ips * 90.0
			_credit(state, g3)
			state.heat = minf(100.0, state.heat + 18.0)
			return "+%s cash, +18 heat" % FormatUtil.format_money(g3)
		"bw_exploit":
			var g4: float = ips * 45.0
			_credit(state, g4)
			state.heat = minf(100.0, state.heat + 6.0)
			_BuffSystem.add_buff(state, "bw_op_exploit", 60.0, 1.08)
			return "+%s cash, +6 heat, +8% op income 1 min" % FormatUtil.format_money(g4)
		"bw_storm":
			_BuffSystem.add_buff(state, "bw_storm", 180.0, 1.0)
			state.bw_attack_bonus += 0.15
			state.heat = minf(100.0, state.heat + 12.0)
			return "+15% attack vs Blackwater 3 min, +12 heat"
		"bw_bribe_dock":
			var c5: float = state.balance * 0.08
			state.balance = maxf(0.0, state.balance - c5)
			var bw: Dictionary = _find_rival(state, "blackwater")
			if not bw.is_empty():
				bw["turf"] = maxi(0, int(bw.get("turf", 0)) - 1)
				bw["wealth"] = maxf(0.0, float(bw.get("wealth", 0.0)) - 500000.0)
			return "-%s balance, Blackwater loses 1 turf" % FormatUtil.format_money(c5)
		"bw_side_black":
			_BuffSystem.add_buff(state, "bw_side_black", 180.0, 1.15)
			var bw2: Dictionary = _find_rival(state, "blackwater")
			var iu: Dictionary = _find_rival(state, "iron_union")
			if not bw2.is_empty():
				bw2["turf"] = mini(8, int(bw2.get("turf", 0)) + 1)
			if not iu.is_empty():
				iu["power"] = maxi(0, int(iu.get("power", 0)) - 8)
			return "+15% op rewards 3 min, Blackwater grows"
		"bw_side_iron":
			_BuffSystem.add_buff(state, "bw_side_iron", 180.0, 1.10)
			var bw3: Dictionary = _find_rival(state, "blackwater")
			var iu2: Dictionary = _find_rival(state, "iron_union")
			if not bw3.is_empty():
				bw3["power"] = maxi(0, int(bw3.get("power", 0)) - 8)
			if not iu2.is_empty():
				iu2["turf"] = mini(8, int(iu2.get("turf", 0)) + 1)
			return "+10% income 3 min, Iron Union grows"
		"bw_stay_out":
			for key in ["blackwater", "iron_union"]:
				var r: Dictionary = _find_rival(state, key)
				if not r.is_empty():
					r["power"] = maxi(0, int(r.get("power", 0)) - 6)
					r["wealth"] = maxf(0.0, float(r.get("wealth", 0.0)) - 1000000.0)
			return "Both factions weakened."
		"bw_send_back":
			state.heat = minf(100.0, state.heat + 8.0)
			var bw4: Dictionary = _find_rival(state, "blackwater")
			if not bw4.is_empty():
				bw4["aggression"] = minf(0.95, float(bw4.get("aggression", 0.5)) + 0.10)
			return "+8 heat, Blackwater more aggressive"
		"bw_listen":
			state.heat = maxf(0.0, state.heat - 10.0)
			_BuffSystem.add_buff(state, "bw_negotiate", 120.0, 1.0)
			state.bw_negotiate_bonus += 0.15
			return "-10 heat, +15% negotiate success 2 min"
		"bw_ignore_warn":
			var bw5: Dictionary = _find_rival(state, "blackwater")
			if not bw5.is_empty():
				_TerritorySystem.rival_claim_preferred(
					state.territories, str(bw5.get("name", "")),
					bw5.get("preferred_district_names", []),
					bw5.get("preferred_district_types", []))
				bw5["turf"] = mini(8, int(bw5.get("turf", 0)) + 1)
			return "Blackwater claims an industrial district."
		"bw_take_deal":
			_BuffSystem.add_buff(state, "bw_deal", 180.0, 1.20)
			var bw6: Dictionary = _find_rival(state, "blackwater")
			if not bw6.is_empty():
				bw6["power"] = mini(300, int(bw6.get("power", 0)) + 5)
			return "+20% op income 3 min, Blackwater gains +5 power"
		"bw_counter":
			state.prestige_tokens += 1
			var bw7: Dictionary = _find_rival(state, "blackwater")
			if not bw7.is_empty() and int(bw7.get("turf", 0)) > 0:
				var freed: int = _TerritorySystem.release_rival_territories(state.territories, str(bw7.get("name", "")))
				if freed > 0:
					bw7["turf"] = maxi(0, int(bw7.get("turf", 0)) - freed)
			return "+1 Influence, Blackwater steps back"
	return "Done."
