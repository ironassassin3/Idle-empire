class_name PrestigeTree
extends RefCounted
## Branching prestige tree — mirrors src/prestige_tree.py (Session 9).

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

const KINGPIN := "kingpin"
const WARLORD := "warlord"
const CARTEL := "cartel"
const CONSIGLIERE := "consigliere"

const BRANCH_ORDER: PackedStringArray = ["kingpin", "warlord", "cartel", "consigliere"]

const PERK_AUTO_INTERVAL := 5.0

const BRANCH_META: Dictionary = {
	KINGPIN: {
		"name": "Kingpin", "tag": "Economic Empire", "short": "Economy",
		"color": Color(0.82, 0.67, 0.24),
		"blurb": "Income, offline gains, automation. Weak in conflict.",
	},
	WARLORD: {
		"name": "Warlord", "tag": "Force & Intimidation", "short": "Force",
		"color": Color(0.80, 0.29, 0.24),
		"blurb": "Rival pressure, clicks, intimidation. Slow economy.",
	},
	CARTEL: {
		"name": "Cartel", "tag": "Operations & Logistics", "short": "Operations",
		"color": Color(0.24, 0.69, 0.55),
		"blurb": "Operations, expansion, efficiency. Fragile if disrupted.",
	},
	CONSIGLIERE: {
		"name": "Consigliere", "tag": "Influence & Corruption", "short": "Influence",
		"color": Color(0.61, 0.43, 0.86),
		"blurb": "Influence, heat control, Respect. Lower direct output.",
	},
}

# branch -> [[key, name, cost, effect_text, tier], ...]
const BRANCH_PERKS: Dictionary = {
	KINGPIN: [
		["kp_cashflow", "Cash Flow", 2, "+15% all passive income", 1],
		["kp_ledger", "Off the Books", 4, "+40% offline earnings", 2],
		["kp_payroll", "Syndicate Payroll", 7, "Managers give +0.5x more income", 3],
		["kp_monopoly", "Monopoly", 12, "+25% per-building income + auto-buy", 4],
	],
	WARLORD: [
		["wl_knuckles", "Brass Knuckles", 2, "+40% click power", 1],
		["wl_force", "Show of Force", 4, "+20% rival action success", 2],
		["wl_spoils", "Spoils of War", 7, "+60% cash seized from rival attacks", 3],
		["wl_terror", "Reign of Terror", 12, "+4% income per district held (max +24%)", 4],
	],
	CARTEL: [
		["ct_supply", "Supply Lines", 2, "+30% operation rewards", 1],
		["ct_fast", "Fast Track", 4, "Operations finish 20% faster", 2],
		["ct_expand", "Expansion", 7, "+15% territory success, +12% district income", 3],
		["ct_network", "Kingmaker Network", 12, "+60% operation rewards (stacks)", 4],
	],
	CONSIGLIERE: [
		["cs_tongue", "Silver Tongue", 2, "+25% Influence from prestige", 1],
		["cs_clean", "Clean Money", 4, "+0.10/s heat decay", 2],
		["cs_favors", "Favors Owed", 7, "+60% Respect income bonus", 3],
		["cs_puppet", "Puppet Master", 12, "+50% Influence from prestige (stacks)", 4],
	],
}

const PERK_DETAILS: Dictionary = {
	"kp_cashflow": "All passive income ×1.15 while you run the Kingpin path.",
	"kp_ledger": "Offline earnings +40% on top of the base rate. Rewards check-ins.",
	"kp_payroll": "Every hired manager grants +0.5× extra income (stacks with Crew Network).",
	"kp_monopoly": "Each building earns +25% AND buildings auto-buy every 5s. The economic capstone.",
	"wl_knuckles": "Each manual click is worth 40% more cash.",
	"wl_force": "+20% success chance on all actions against rival factions.",
	"wl_spoils": "Attacks on rivals seize 60% more cash.",
	"wl_terror": "Income +4% for every district you control, up to +24%. Turf = power.",
	"ct_supply": "Illegal operations pay out 30% more.",
	"ct_fast": "Operations complete 20% faster — more payouts per hour.",
	"ct_expand": "+15% territory action success and +12% income from controlled districts.",
	"ct_network": "Operations pay out a further +60% (multiplies with Supply Lines). Logistics capstone.",
	"cs_tongue": "Every prestige grants 25% more Influence.",
	"cs_clean": "Heat decays 0.10/s faster — corruption keeps the law off your back.",
	"cs_favors": "Your Respect income bonus is 60% stronger.",
	"cs_puppet": "Prestige Influence +50% more (stacks with Silver Tongue). Corruption capstone.",
}

static var _branch_of: Dictionary = {}
static var _perk_def: Dictionary = {}
static var _perk_cost: Dictionary = {}


static func _ensure_maps() -> void:
	if not _branch_of.is_empty():
		return
	for br in BRANCH_PERKS:
		for entry in BRANCH_PERKS[br]:
			var key: String = entry[0]
			_branch_of[key] = br
			_perk_def[key] = entry
			_perk_cost[key] = int(entry[2])


static func has_perk(state, key: String) -> bool:
	return key in state.perks_purchased


static func _active(state, key: String) -> bool:
	_ensure_maps()
	if state.prestige_branch.is_empty():
		return false
	return key in state.perks_purchased and _branch_of.get(key, "") == state.prestige_branch


static func branch_perk_count(state, branch: String) -> int:
	_ensure_maps()
	var n := 0
	for k in state.perks_purchased:
		if _branch_of.get(k, "") == branch:
			n += 1
	return n


static func perk_detail(key: String) -> String:
	return str(PERK_DETAILS.get(key, ""))


static func perk_name(key: String) -> String:
	_ensure_maps()
	if _perk_def.has(key):
		return str(_perk_def[key][1])
	return key


static func is_valid_branch(branch: String) -> bool:
	return branch in BRANCH_PERKS


static func branch_tier_unlocked(state, branch: String, tier: int) -> bool:
	return branch_perk_count(state, branch) >= (tier - 1)


static func can_buy_perk(state, key: String) -> Dictionary:
	_ensure_maps()
	if key in state.perks_purchased:
		return {"ok": false, "reason": "Owned"}
	var branch: String = str(_branch_of.get(key, ""))
	if branch.is_empty():
		return {"ok": false, "reason": "Unavailable"}
	if state.prestige_branch.is_empty():
		return {"ok": false, "reason": "Choose a path first"}
	if state.prestige_branch != branch:
		return {"ok": false, "reason": "Locked (other path)"}
	var tier: int = int(_perk_def[key][4])
	if not branch_tier_unlocked(state, branch, tier):
		return {"ok": false, "reason": "Unlock tier %d" % tier}
	var cost: int = int(_perk_cost[key])
	if state.prestige_tokens < cost:
		return {"ok": false, "reason": "Need %d inf" % cost}
	return {"ok": true, "reason": ""}


static func select_branch(state, branch: String) -> bool:
	if branch not in BRANCH_PERKS:
		return false
	if not state.prestige_branch.is_empty():
		return false
	state.prestige_branch = branch
	apply_perks(state)
	return true


static func reset_branch(state) -> void:
	state.prestige_branch = ""


static func buy_perk(state, key: String) -> bool:
	var gate := can_buy_perk(state, key)
	if not gate.get("ok", false):
		return false
	_ensure_maps()
	state.prestige_tokens -= int(_perk_cost[key])
	state.perks_purchased.append(key)
	apply_perks(state)
	return true


static func offline_earnings_mult(state) -> float:
	var bonus := 0.0
	if has_perk(state, "offline_1"):
		bonus += 0.25
	if _active(state, "kp_ledger"):
		bonus += 0.40
	return 1.0 + bonus


static func manager_income_mult(state) -> float:
	var base := 2.0 if has_perk(state, "manager_unlock") else 1.5
	if _active(state, "kp_payroll"):
		base += 0.5
	return base


static func operation_reward_mult(state) -> float:
	var m := 1.0
	if _active(state, "ct_supply"):
		m *= 1.30
	if _active(state, "ct_network"):
		m *= 1.60
	return m


static func operation_speed_mult(state) -> float:
	return 0.80 if _active(state, "ct_fast") else 1.0


static func territory_action_bonus(state) -> float:
	return 0.15 if _active(state, "ct_expand") else 0.0


static func district_income_mult(state) -> float:
	return 1.12 if _active(state, "ct_expand") else 1.0


static func combat_success_bonus(state) -> float:
	return 0.20 if _active(state, "wl_force") else 0.0


static func combat_reward_mult(state) -> float:
	return 1.60 if _active(state, "wl_spoils") else 1.0


static func turf_intimidation_income_mult(state) -> float:
	if not _active(state, "wl_terror"):
		return 1.0
	var districts := _TerritorySystem.player_district_count(state.territories)
	return 1.0 + minf(0.24, float(districts) * 0.04)


static func influence_gain_mult(state) -> float:
	var m := 1.0
	if _active(state, "cs_tongue"):
		m *= 1.25
	if _active(state, "cs_puppet"):
		m *= 1.50
	return m


static func heat_decay_bonus(state) -> float:
	return 0.10 if _active(state, "cs_clean") else 0.0


static func respect_income_mult(state) -> float:
	return 1.60 if _active(state, "cs_favors") else 1.0


static func apply_perks(state) -> void:
	_ensure_maps()
	var perks: Array = state.perks_purchased
	state.perk_click_mult = 1.0
	state.perk_income_mult = 1.0
	var perk_blds: Array = []
	for _i in state.buildings.size():
		perk_blds.append(1.0)

	for key in perks:
		match key:
			"click_power_1":
				state.perk_click_mult *= 1.10
			"income_1":
				state.perk_income_mult *= 1.10
			"click_power_2":
				state.perk_click_mult *= 1.50
			"income_2":
				state.perk_income_mult *= 1.25
			"empire_bonus":
				state.perk_click_mult *= 2.0
				state.perk_income_mult *= 2.0
			"faster_prog":
				for i in perk_blds.size():
					perk_blds[i] = float(perk_blds[i]) * 1.20

	if _active(state, "kp_cashflow"):
		state.perk_income_mult *= 1.15
	if _active(state, "wl_knuckles"):
		state.perk_click_mult *= 1.40
	if _active(state, "kp_monopoly"):
		for i in perk_blds.size():
			perk_blds[i] = float(perk_blds[i]) * 1.25

	state.perk_bld_mults = perk_blds
	state.perk_auto_buy = ("auto_buy" in perks) or _active(state, "kp_monopoly")
	state.perk_auto_upgrade = ("auto_upgrade" in perks)


static func tick_perk_effects(state, dt: float) -> Array[String]:
	var messages: Array[String] = []
	if state.perk_auto_buy:
		state.perk_autobuy_timer += dt
		if state.perk_autobuy_timer >= PERK_AUTO_INTERVAL:
			state.perk_autobuy_timer = 0.0
			if _ManagerSystem._auto_buy_best(state):
				messages.append("Perk auto-buy secured an asset")
	if state.perk_auto_upgrade:
		state.perk_autoupg_timer += dt
		if state.perk_autoupg_timer >= PERK_AUTO_INTERVAL:
			state.perk_autoupg_timer = 0.0
			var name := _auto_buy_upgrade(state)
			if not name.is_empty():
				messages.append("Auto-upgrade: %s" % name)
	return messages


static func _auto_buy_upgrade(state) -> String:
	var best_idx := -1
	var best_cost := INF
	for i in state.upgrades.size():
		var u: Upgrade = state.upgrades[i]
		if u.purchased:
			continue
		var cost: float = UpgradeDefs.effective_cost(u, state)
		if state.balance >= cost and cost < best_cost:
			best_cost = cost
			best_idx = i
	if best_idx < 0:
		return ""
	if state.buy_upgrade(best_idx):
		return state.upgrades[best_idx].display_name
	return ""
