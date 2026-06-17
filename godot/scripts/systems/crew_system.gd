class_name CrewSystem
extends RefCounted
## Crew assignments — port of src/crew.py (mechanics only).

const UNLOCK_BUILDINGS := 5

const ROLES: Array = [
	["protection", "Protection", "P", "Reduces rival raid damage",
		"Each crew unit cuts raid damage 1.5% (cap -70%)."],
	["collection", "Collection", "C", "Boosts passive income",
		"Each unit adds +0.8% global income (cap +60%)."],
	["smuggling", "Smuggling", "S", "Boosts operation rewards",
		"Each unit adds +1% to operation payouts (cap +75%)."],
	["territory", "Territory", "T", "Speeds territory action success",
		"Each unit adds +0.5% territory success (cap +25%)."],
	["heat", "Heat Reduction", "H", "Passively lowers heat over time",
		"Each unit removes 0.003 heat/sec (cap 0.5/sec)."],
]


static func default_crew() -> Dictionary:
	return {
		"protection": 0,
		"collection": 0,
		"smuggling": 0,
		"territory": 0,
		"heat": 0,
	}


static func merge_save_crew(crew: Dictionary, saved: Dictionary) -> void:
	for key in ["protection", "collection", "smuggling", "territory", "heat"]:
		if saved.has(key):
			crew[key] = int(saved.get(key, 0))


static func crew_total(crew: Dictionary) -> int:
	var total := 0
	for key in ["protection", "collection", "smuggling", "territory", "heat"]:
		total += int(crew.get(key, 0))
	return total


static func available(state) -> int:
	return maxi(0, state.total_buildings_owned())


static func unassigned(state) -> int:
	return maxi(0, available(state) - crew_total(state.crew))


static func is_unlocked(state) -> bool:
	return state.total_buildings_owned() >= UNLOCK_BUILDINGS


static func unlock_requirement_text(state) -> String:
	var owned: int = state.total_buildings_owned()
	return "Own %d buildings to unlock — assign crew for bonuses  (%d/%d)" % [
		UNLOCK_BUILDINGS, owned, UNLOCK_BUILDINGS,
	]


static func clamp_to_capacity(state) -> void:
	var cap: int = available(state)
	var crew: Dictionary = state.crew
	var total: int = crew_total(crew)
	if total <= cap:
		return
	if cap <= 0:
		for key in ["protection", "collection", "smuggling", "territory", "heat"]:
			crew[key] = 0
		return
	var factor: float = float(cap) / float(total)
	crew["protection"] = int(float(crew.get("protection", 0)) * factor)
	crew["collection"] = int(float(crew.get("collection", 0)) * factor)
	crew["smuggling"] = int(float(crew.get("smuggling", 0)) * factor)
	crew["territory"] = int(float(crew.get("territory", 0)) * factor)
	crew["heat"] = int(float(crew.get("heat", 0)) * factor)


static func adjust_assignment(state, role_key: String, delta: int) -> bool:
	if not is_unlocked(state):
		return false
	if delta == 0:
		return false
	var crew: Dictionary = state.crew
	var current: int = int(crew.get(role_key, 0))
	if delta < 0:
		if current <= 0:
			return false
		crew[role_key] = current - 1
		return true
	if unassigned(state) <= 0:
		return false
	crew[role_key] = current + 1
	return true


static func protection_damage_mult(crew: Dictionary) -> float:
	var count: int = int(crew.get("protection", 0))
	return maxf(0.30, 1.0 - float(count) * 0.015)


static func collection_income_mult(crew: Dictionary, _state = null) -> float:
	var count: int = int(crew.get("collection", 0))
	return 1.0 + minf(float(count) * 0.008, 0.60)


static func smuggling_op_mult(crew: Dictionary) -> float:
	var count: int = int(crew.get("smuggling", 0))
	return 1.0 + minf(float(count) * 0.01, 0.75)


static func territory_action_bonus(crew: Dictionary) -> float:
	var count: int = int(crew.get("territory", 0))
	return minf(float(count) * 0.005, 0.25)


static func heat_reduction_per_sec(crew: Dictionary) -> float:
	var count: int = int(crew.get("heat", 0))
	return minf(float(count) * 0.003, 0.50)


static func role_effect_str(role_key: String, count: int) -> String:
	match role_key:
		"protection":
			var pct: int = mini(int(count * 1.5), 70)
			return "-%d%% raid damage" % pct
		"collection":
			var cpct: float = minf(float(count) * 0.8, 60.0)
			return "+%.1f%% passive income" % cpct
		"smuggling":
			var spct: int = mini(count, 75)
			return "+%d%% operation rewards" % spct
		"territory":
			var tpct: float = minf(float(count) * 0.5, 25.0)
			return "+%.1f%% territory success" % tpct
		"heat":
			var val: float = minf(float(count) * 0.003, 0.5)
			return "-%.3f heat/sec" % val
	return ""
