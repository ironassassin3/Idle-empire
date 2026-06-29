class_name MetagameState
extends RefCounted

var currency: int = 0
var unlocks: Array[String] = []
var stats: Dictionary = {"runs": 0, "wins": 0, "best_round": 0}


static func create_default() -> MetagameState:
	return MetagameState.new()


func apply_run_result(result: Dictionary) -> void:
	stats["runs"] = int(stats.get("runs", 0)) + 1
	if result.get("won", false):
		stats["wins"] = int(stats.get("wins", 0)) + 1
	var round_reached := int(result.get("round_reached", 0))
	if round_reached > int(stats.get("best_round", 0)):
		stats["best_round"] = round_reached
	currency += int(result.get("reward", 0))
