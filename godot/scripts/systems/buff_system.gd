class_name BuffSystem
extends RefCounted
## Temporary buffs — port of PlayingState._buffs / _add_buff (events, hustle, etc.).

static func add_buff(state, name: String, duration: float, mult: float = 1.0) -> void:
	var kept: Array = []
	for b in state.buffs:
		if typeof(b) == TYPE_DICTIONARY and str(b.get("name", "")) != name:
			kept.append(b)
	state.buffs = kept
	state.buffs.append({
		"name": name,
		"remaining": duration,
		"total": duration,
		"mult": mult,
	})


static func has_buff(state, name: String) -> bool:
	for b in state.buffs:
		if typeof(b) == TYPE_DICTIONARY and str(b.get("name", "")) == name:
			return true
	return false


static func tick_buffs(state, dt: float) -> void:
	var had_storm: bool = has_buff(state, "bw_storm")
	var had_negotiate: bool = has_buff(state, "bw_negotiate")
	var alive: Array = []
	for b in state.buffs:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var rem: float = float(b.get("remaining", 0.0)) - dt
		if rem > 0.0:
			b["remaining"] = rem
			alive.append(b)
	state.buffs = alive
	if had_storm and not has_buff(state, "bw_storm"):
		state.bw_attack_bonus = 0.0
	if had_negotiate and not has_buff(state, "bw_negotiate"):
		state.bw_negotiate_bonus = 0.0


static func income_mult(state) -> float:
	var mult := 1.0
	for b in state.buffs:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if str(b.get("name", "")) == "syndicate_income":
			mult *= float(b.get("mult", 1.0))
		elif str(b.get("name", "")) == "bw_side_iron":
			mult *= float(b.get("mult", 1.0))
	return mult


static func operation_reward_mult(state) -> float:
	var mult := 1.0
	for b in state.buffs:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var n: String = str(b.get("name", ""))
		if n in ["bw_op_exploit", "bw_side_black", "bw_deal"]:
			mult *= float(b.get("mult", 1.0))
	return mult
