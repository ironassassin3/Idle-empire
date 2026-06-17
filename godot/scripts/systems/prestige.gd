class_name Prestige
extends RefCounted
## Prestige helpers — subset of src/prestige.py for the MVP port.

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
	var raw := sqrt(maxf(0.0, lifetime_earnings) / 1_000_000.0)
	return maxi(1, int(raw))


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
	var reqs := {
		"earnings": {
			"current": state.lifetime_earnings,
			"required": required,
			"met": state.lifetime_earnings >= required,
		},
	}
	if state.prestige_count <= 0:
		var dealers: int = state.buildings[0].owned if state.buildings.size() > 0 else 0
		var rackets: int = state.buildings[1].owned if state.buildings.size() > 1 else 0
		var chops: int = state.buildings[2].owned if state.buildings.size() > 2 else 0
		var rank := get_rank(state.prestige_tokens)
		reqs["dealers"] = {"current": dealers, "required": GameConfig.FIRST_PRESTIGE_DEALERS, "met": dealers >= GameConfig.FIRST_PRESTIGE_DEALERS}
		reqs["rackets"] = {"current": rackets, "required": GameConfig.FIRST_PRESTIGE_RACKETS, "met": rackets >= GameConfig.FIRST_PRESTIGE_RACKETS}
		reqs["chops"] = {"current": chops, "required": GameConfig.FIRST_PRESTIGE_CHOPS, "met": chops >= GameConfig.FIRST_PRESTIGE_CHOPS}
		reqs["rank"] = {"current": rank, "required": GameConfig.FIRST_PRESTIGE_RANK, "met": rank_index(rank) >= rank_index(GameConfig.FIRST_PRESTIGE_RANK)}
	return reqs


static func can_prestige(state) -> bool:
	for key in check_requirements(state):
		if not check_requirements(state)[key]["met"]:
			return false
	return true


static func _rank_index(label: String) -> int:
	return rank_index(label)


static func rank_territory_bonus(_tokens: int) -> float:
	return 0.0  # rank perk table — full port in P3


static func get_next_rank(tokens: int) -> Variant:
	for entry in HIERARCHY:
		var thresh: int = int(entry[0])
		if tokens < thresh:
			return [entry[1], thresh]
	return null


static func respect_income_bonus(respect: int) -> float:
	var r := maxi(0, respect)
	return minf(0.5, float(r) * 0.0004)
