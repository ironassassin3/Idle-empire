class_name Prestige
extends RefCounted
## Prestige helpers — subset of src/prestige.py for the MVP port.

const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")

const HIERARCHY: Array = [
	[0, "Street Hustler"], [1, "Crew Member"], [5, "Associate"], [12, "Made Man"],
	[25, "Capo"], [45, "Underboss"], [75, "Boss"], [115, "Crime Lord"],
	[165, "Kingpin"], [230, "City Controller"], [310, "State Influence"],
	[410, "National Influence"], [540, "Shadow Government"],
]

const TOKEN_SOFTCAP_D := 14.0
const TOKEN_SOFTCAP_A := 0.90


static func get_rank(tokens: int) -> String:
	var rank := "Street Hustler"
	for entry in HIERARCHY:
		if tokens >= int(entry[0]):
			rank = entry[1]
	return rank


static func rank_index(label: String) -> int:
	for i in HIERARCHY.size():
		if HIERARCHY[i][1] == label:
			return i
	return 0


static func income_mult(tokens: int) -> float:
	var t := maxi(0, tokens)
	return pow(1.0 + float(t) / TOKEN_SOFTCAP_D, TOKEN_SOFTCAP_A)


static func calc_influence_gain(lifetime_earnings: float) -> int:
	if lifetime_earnings < GameConfig.FIRST_PRESTIGE_EARNINGS:
		return 0
	var log_val := log(maxf(1.0, lifetime_earnings)) / log(10.0)
	return maxi(1, int(round(log_val * log_val / 5.0)))


const PRESTIGE_MASTERY_MAX := 1.5
const PRESTIGE_MASTERY_HALF := 120.0


static func prestige_mastery_mult(tokens: int) -> float:
	var t := maxi(0, tokens)
	return 1.0 + PRESTIGE_MASTERY_MAX * float(t) / (PRESTIGE_MASTERY_HALF + float(t))


static func prestige_earnings_required(prestige_count: int, next_prestige_earnings: float) -> float:
	if prestige_count <= 0:
		return GameConfig.FIRST_PRESTIGE_EARNINGS
	return next_prestige_earnings


static func check_requirements(state) -> Dictionary:
	var required := prestige_earnings_required(state.prestige_count, state.next_prestige_earnings)
	var route: float = float(state.prestige_route_earnings)
	var reqs := {
		"earnings": {
			"current": route,
			"required": required,
			"met": route >= required,
		},
	}
	if state.prestige_count <= 0:
		var dealers: int = state.buildings[0].owned if state.buildings.size() > 0 else 0
		var rackets: int = state.buildings[1].owned if state.buildings.size() > 1 else 0
		var chops: int = state.buildings[2].owned if state.buildings.size() > 2 else 0
		var rank := get_rank(state.lifetime_tokens)
		reqs["dealers"] = {"current": dealers, "required": GameConfig.FIRST_PRESTIGE_DEALERS, "met": dealers >= GameConfig.FIRST_PRESTIGE_DEALERS}
		reqs["rackets"] = {"current": rackets, "required": GameConfig.FIRST_PRESTIGE_RACKETS, "met": rackets >= GameConfig.FIRST_PRESTIGE_RACKETS}
		reqs["chops"] = {"current": chops, "required": GameConfig.FIRST_PRESTIGE_CHOPS, "met": chops >= GameConfig.FIRST_PRESTIGE_CHOPS}
		reqs["rank"] = {"current": rank, "required": GameConfig.FIRST_PRESTIGE_RANK, "met": rank_index(rank) >= rank_index(GameConfig.FIRST_PRESTIGE_RANK)}
	else:
		var dealers2: int = state.buildings[0].owned if state.buildings.size() > 0 else 0
		var rackets2: int = state.buildings[1].owned if state.buildings.size() > 1 else 0
		var chops2: int = state.buildings[2].owned if state.buildings.size() > 2 else 0
		reqs["dealers"] = {"current": dealers2, "required": GameConfig.POST_PRESTIGE_DEALERS, "met": dealers2 >= GameConfig.POST_PRESTIGE_DEALERS}
		reqs["rackets"] = {"current": rackets2, "required": GameConfig.POST_PRESTIGE_RACKETS, "met": rackets2 >= GameConfig.POST_PRESTIGE_RACKETS}
		reqs["chops"] = {"current": chops2, "required": GameConfig.POST_PRESTIGE_CHOPS, "met": chops2 >= GameConfig.POST_PRESTIGE_CHOPS}
	if state.prestige_count >= 1:
		var branch: String = str(state.prestige_branch)
		var branch_met := not branch.is_empty()
		reqs["branch"] = {
			"current": branch if branch_met else "none",
			"required": "path",
			"met": branch_met,
		}
		var perk_count := 0
		if branch_met:
			perk_count = _PrestigeTree.branch_perk_count(state, branch)
		reqs["branch_perk"] = {"current": perk_count, "required": 1, "met": branch_met and perk_count >= 1}
	return reqs


static func can_prestige(state) -> bool:
	for key in check_requirements(state):
		if not check_requirements(state)[key]["met"]:
			return false
	return true


static func gate_progress_pct(state) -> int:
	var reqs: Dictionary = check_requirements(state)
	var earn: Dictionary = reqs.get("earnings", {})
	var required: float = float(earn.get("required", 0.0))
	if required <= 0.0:
		return 100
	return mini(100, int(100.0 * float(earn.get("current", 0.0)) / required))


static func compact_gate_label(state) -> String:
	if can_prestige(state):
		return "PRESTIGE"
	return "P%d%%" % gate_progress_pct(state)


static func gate_progress_summary(state) -> Dictionary:
	var reqs: Dictionary = check_requirements(state)
	var earn: Dictionary = reqs.get("earnings", {})
	var ready := can_prestige(state)
	var pct := gate_progress_pct(state)
	var blockers: PackedStringArray = PackedStringArray()
	for key in ["earnings", "dealers", "rackets", "chops", "rank", "branch", "branch_perk"]:
		if not reqs.has(key):
			continue
		var r: Dictionary = reqs[key]
		if bool(r.get("met", true)):
			continue
		blockers.append(_blocker_text(key, r))
	return {
		"ready": ready,
		"pct": pct,
		"route": float(earn.get("current", 0.0)),
		"required": float(earn.get("required", 0.0)),
		"blockers": blockers,
		"influence_gain": calc_influence_gain(state.lifetime_earnings),
	}


static func _blocker_text(key: String, r: Dictionary) -> String:
	match key:
		"earnings":
			return "Empire earnings"
		"dealers":
			return "Dealers %d/%d" % [int(r.get("current", 0)), int(r.get("required", 0))]
		"rackets":
			return "Rackets %d/%d" % [int(r.get("current", 0)), int(r.get("required", 0))]
		"chops":
			return "Chop shops %d/%d" % [int(r.get("current", 0)), int(r.get("required", 0))]
		"rank":
			return "Rank: need %s" % str(r.get("required", ""))
		"branch":
			return "Choose a prestige path"
		"branch_perk":
			return "Buy a tier-1 path perk"
	return key.capitalize()


static func _rank_index(label: String) -> int:
	return rank_index(label)


# Per-rank perk bonuses (cumulative — all ranks at/below current stack).
# Mirror of src/prestige.py _RANK_PERK_TABLE. Keys: territory_success,
# operation_reward (additive fractions), heat_decay (/s), income_bonus (additive).
const _RANK_PERK_TABLE: Dictionary = {
	"Crew Member": {"territory_success": 0.05},
	"Associate": {"operation_reward": 0.05},
	"Made Man": {},
	"Capo": {"heat_decay": 0.05},
	"Underboss": {"operation_reward": 0.10},
	"Boss": {"territory_success": 0.10},
	"Crime Lord": {"income_bonus": 0.05},
	"Kingpin": {"heat_decay": 0.05},
	"City Controller": {"operation_reward": 0.15},
	"State Influence": {"territory_success": 0.10},
	"National Influence": {"income_bonus": 0.05},
	"Shadow Government": {"operation_reward": 0.20},
}


static func get_cumulative_rank_perks(influence: int) -> Dictionary:
	var totals: Dictionary = {}
	for entry in HIERARCHY:
		var threshold: int = int(entry[0])
		var label: String = entry[1]
		if influence >= threshold and _RANK_PERK_TABLE.has(label):
			var perks: Dictionary = _RANK_PERK_TABLE[label]
			for k in perks:
				totals[k] = float(totals.get(k, 0.0)) + float(perks[k])
	return totals


static func rank_territory_bonus(tokens: int) -> float:
	return float(get_cumulative_rank_perks(tokens).get("territory_success", 0.0))


static func rank_operation_reward_bonus(tokens: int) -> float:
	return float(get_cumulative_rank_perks(tokens).get("operation_reward", 0.0))


static func rank_heat_decay_bonus(tokens: int) -> float:
	return float(get_cumulative_rank_perks(tokens).get("heat_decay", 0.0))


static func rank_income_bonus(tokens: int) -> float:
	return float(get_cumulative_rank_perks(tokens).get("income_bonus", 0.0))


static func get_next_rank(tokens: int) -> Variant:
	for entry in HIERARCHY:
		var thresh: int = int(entry[0])
		if tokens < thresh:
			return [entry[1], thresh]
	return null


static func respect_income_bonus(respect: int) -> float:
	var r := maxi(0, respect)
	return minf(0.5, float(r) * 0.0004)
