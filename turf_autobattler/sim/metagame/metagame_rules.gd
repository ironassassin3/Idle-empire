class_name MetagameRules
extends RefCounted

# Permanent meta-unlocks bought with Street Cred — the progression sink that
# gives the metagame currency a purpose. Effects are applied at run start via
# starting_bonuses() / RunDirector.start_run.
const UNLOCKS := {
	"war_chest": {
		"name": "War Chest",
		"desc": "Start every run with +3 gold.",
		"cost": 75,
		"effect": {"start_gold": 3},
	},
	"old_connections": {
		"name": "Old Connections",
		"desc": "Start every run with +4 XP (faster first level-up).",
		"cost": 150,
		"effect": {"start_xp": 4},
	},
	"kingpin_seed": {
		"name": "Kingpin Seed Money",
		"desc": "Start every run with +6 gold.",
		"cost": 260,
		"effect": {"start_gold": 6},
	},
}


static func can_purchase(state: MetagameState, unlock_id: String) -> bool:
	if not UNLOCKS.has(unlock_id):
		return false
	if state.unlocks.has(unlock_id):
		return false
	return state.currency >= int(UNLOCKS[unlock_id].get("cost", 0))


static func purchase(state: MetagameState, unlock_id: String) -> bool:
	if not can_purchase(state, unlock_id):
		return false
	state.currency -= int(UNLOCKS[unlock_id].get("cost", 0))
	state.unlocks.append(unlock_id)
	return true


static func starting_bonuses(unlocks: Array) -> Dictionary:
	# Aggregate the run-start effects of all owned unlocks.
	var bonuses := {"start_gold": 0, "start_xp": 0}
	for unlock_id in unlocks:
		var effect: Dictionary = UNLOCKS.get(String(unlock_id), {}).get("effect", {})
		for key in effect.keys():
			bonuses[key] = int(bonuses.get(key, 0)) + int(effect[key])
	return bonuses


static func build_run_result(run_state: RunState, won: bool) -> Dictionary:
	return {
		"won": won,
		"round_reached": run_state.round,
		"damage_dealt": 0,
		"traits_used": run_state.traits_cache.duplicate(true),
		"reward": _reward_for_run(run_state, won),
	}


static func _reward_for_run(run_state: RunState, won: bool) -> int:
	var base := run_state.round * 2
	return base + (20 if won else 5)
