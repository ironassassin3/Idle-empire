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


static func income_mult(tokens: int) -> float:
	var t := maxi(0, tokens)
	return pow(1.0 + float(t) / TOKEN_SOFTCAP_D, TOKEN_SOFTCAP_A)


static func calc_influence_gain(lifetime_earnings: float) -> int:
	var raw := sqrt(maxf(0.0, lifetime_earnings) / 1_000_000.0)
	return maxi(1, int(raw))


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
		var dealers := state.buildings[0].owned if state.buildings.size() > 0 else 0
		var rackets := state.buildings[1].owned if state.buildings.size() > 1 else 0
		var chops := state.buildings[2].owned if state.buildings.size() > 2 else 0
		var rank := get_rank(state.prestige_tokens)
		reqs["dealers"] = {"current": dealers, "required": GameConfig.FIRST_PRESTIGE_DEALERS, "met": dealers >= GameConfig.FIRST_PRESTIGE_DEALERS}
		reqs["rackets"] = {"current": rackets, "required": GameConfig.FIRST_PRESTIGE_RACKETS, "met": rackets >= GameConfig.FIRST_PRESTIGE_RACKETS}
		reqs["chops"] = {"current": chops, "required": GameConfig.FIRST_PRESTIGE_CHOPS, "met": chops >= GameConfig.FIRST_PRESTIGE_CHOPS}
		reqs["rank"] = {"current": rank, "required": GameConfig.FIRST_PRESTIGE_RANK, "met": _rank_index(rank) >= _rank_index(GameConfig.FIRST_PRESTIGE_RANK)}
	return reqs


static func can_prestige(state) -> bool:
	for key in check_requirements(state):
		if not check_requirements(state)[key]["met"]:
			return false
	return true


static func _rank_index(label: String) -> int:
	for i in HIERARCHY.size():
		if HIERARCHY[i][1] == label:
			return i
	return 0
