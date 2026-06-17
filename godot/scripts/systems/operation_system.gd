class_name OperationSystem
extends RefCounted
## Illegal operations — port of src/operations.py (mechanics only).

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _BuffSystem = preload("res://scripts/systems/buff_system.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

const SMUGGLER_CHECK_INTERVAL := 2.0

const UNLOCK_TERRITORIES := 2

const _OP_DEFS: Array = [
	["Drug Run", "Transport product across three districts.", 300.0, 5, 2000.0, 1, 180.0, 12.0, "DR"],
	["Casino Skim", "Quietly siphon from the house take.", 480.0, 3, 5000.0, 1, 300.0, 6.0, "CS"],
	["Union Extortion", "Shake down a construction union for tribute.", 600.0, 8, 15000.0, 2, 480.0, 16.0, "UE"],
	["Political Bribery", "Place a city councilman on retainer.", 900.0, 2, 50000.0, 2, 720.0, -20.0, "PB"],
	["International Smuggling", "Ship contraband through the waterfront.", 1800.0, 12, 150000.0, 3, 1800.0, 25.0, "IS"],
]


static func make_operations() -> Array:
	var out: Array = []
	for d in _OP_DEFS:
		out.append({
			"name": d[0],
			"desc": d[1],
			"duration": float(d[2]),
			"crew_cost": int(d[3]),
			"money_cost": float(d[4]),
			"turf_needed": int(d[5]),
			"reward_mult": float(d[6]),
			"heat_gain": float(d[7]),
			"icon": d[8],
			"active": false,
			"start_play_time": 0.0,
			"reward": 0.0,
			"completed": false,
			"collected": false,
			"speed_mult": 1.0,
		})
	return out


static func merge_save_operations(ops: Array, saved: Array) -> void:
	for i in mini(saved.size(), ops.size()):
		var sd = saved[i]
		if typeof(sd) != TYPE_DICTIONARY:
			continue
		for key in ["active", "start_play_time", "reward", "completed", "collected", "speed_mult"]:
			if sd.has(key):
				ops[i][key] = sd[key]


static func operations_to_save(ops: Array) -> Array:
	var out: Array = []
	for op in ops:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		out.append({
			"active": bool(op.get("active", false)),
			"start_play_time": float(op.get("start_play_time", 0.0)),
			"reward": float(op.get("reward", 0.0)),
			"completed": bool(op.get("completed", false)),
			"collected": bool(op.get("collected", false)),
			"speed_mult": float(op.get("speed_mult", 1.0)),
		})
	return out


static func is_unlocked(state) -> bool:
	var terr: int = _TerritorySystem.player_district_count(state.territories)
	if terr >= UNLOCK_TERRITORIES:
		return true
	return Prestige.rank_index(Prestige.get_rank(state.prestige_tokens)) >= Prestige.rank_index("Made Man")


static func unlock_requirement_text(state) -> String:
	var terr: int = _TerritorySystem.player_district_count(state.territories)
	return "Capture %d districts to unlock — timed heists pay big  (%d/%d)" % [
		UNLOCK_TERRITORIES, terr, UNLOCK_TERRITORIES,
	]


static func effective_duration(op: Dictionary) -> float:
	return float(op.get("duration", 0.0)) * float(op.get("speed_mult", 1.0))


static func elapsed(state, op: Dictionary) -> float:
	if not bool(op.get("active", false)):
		return 0.0
	return maxf(0.0, state.play_time - float(op.get("start_play_time", 0.0)))


static func progress(state, op: Dictionary) -> float:
	if not bool(op.get("active", false)):
		return 0.0
	var dur: float = effective_duration(op)
	if dur <= 0.0:
		return 0.0
	return clampf(elapsed(state, op) / dur, 0.0, 1.0)


static func is_ready(state, op: Dictionary) -> bool:
	return bool(op.get("active", false)) and elapsed(state, op) >= effective_duration(op) and not bool(op.get("collected", false))


static func time_remaining(state, op: Dictionary) -> float:
	if not bool(op.get("active", false)):
		return 0.0
	return maxf(0.0, effective_duration(op) - elapsed(state, op))


static func free_crew(state) -> int:
	return _CrewSystem.unassigned(state)


static func can_start(state, op: Dictionary) -> Dictionary:
	if not is_unlocked(state):
		return {"ok": false, "reason": unlock_requirement_text(state)}
	if bool(op.get("active", false)) and not bool(op.get("collected", false)):
		return {"ok": false, "reason": "Already running"}
	var turf: int = _TerritorySystem.player_district_count(state.territories)
	if turf < int(op.get("turf_needed", 0)):
		return {"ok": false, "reason": "Need %d territories" % int(op.get("turf_needed", 0))}
	if free_crew(state) < int(op.get("crew_cost", 0)):
		return {"ok": false, "reason": "Need %d free crew" % int(op.get("crew_cost", 0))}
	var money_cost: float = float(op.get("money_cost", 0.0))
	if state.balance < money_cost:
		return {"ok": false, "reason": "Need %s" % FormatUtil.format_money(money_cost)}
	return {"ok": true, "reason": ""}


static func operation_reward_mult(state) -> float:
	var mult: float = _PrestigeTree.operation_reward_mult(state)
	for t in state.territories:
		if typeof(t) != TYPE_DICTIONARY or not bool(t.get("unlocked", false)):
			continue
		var perk_key: String = str(t.get("perk_key", ""))
		if perk_key == "operations":
			mult *= 1.25
		if perk_key == "smuggling":
			mult *= 1.15
		if str(t.get("district_type", "")) == "industrial":
			mult *= 1.02
	mult *= _BuffSystem.operation_reward_mult(state)
	return mult


static func start_operation(state, index: int) -> String:
	if index < 0 or index >= state.operations.size():
		return "Operation unavailable"
	var op: Dictionary = state.operations[index]
	var gate := can_start(state, op)
	if not gate.get("ok", false):
		return str(gate.get("reason", "Cannot start"))
	var mult: float = (
		_CrewSystem.smuggling_op_mult(state.crew)
		* operation_reward_mult(state)
		* _ManagerSystem.operation_reward_mult(state)
	)
	op["reward"] = state.income_per_second() * float(op.get("reward_mult", 0.0)) * mult
	op["start_play_time"] = state.play_time
	op["active"] = true
	op["completed"] = false
	op["collected"] = false
	op["speed_mult"] = _PrestigeTree.operation_speed_mult(state)
	var money_cost: float = float(op.get("money_cost", 0.0))
	state.balance = maxf(0.0, state.balance - money_cost)
	var heat_gain: float = float(op.get("heat_gain", 0.0))
	state.heat = minf(100.0, state.heat + maxf(0.0, heat_gain * 0.3))
	return "%s started — collect in %s" % [op.get("name", "?"), fmt_duration(effective_duration(op))]


static func success_chance(state, op: Dictionary) -> float:
	var base: float = 0.80
	var heat: float = state.heat
	var heat_penalty: float = maxf(0.0, (heat - 40.0) * 0.004)
	var terr_bonus: float = 0.0
	for t in state.territories:
		if typeof(t) == TYPE_DICTIONARY and str(t.get("name", "")) == "Waterfront" and bool(t.get("unlocked", false)):
			terr_bonus = 0.10
			break
	var crew_mult: float = _CrewSystem.smuggling_op_mult(state.crew)
	var crew_bonus: float = minf(0.15, (crew_mult - 1.0) * 0.5)
	return clampf(base + terr_bonus + crew_bonus - heat_penalty, 0.20, 0.95)


static func collect_operation(state, index: int, rng: RandomNumberGenerator) -> String:
	if index < 0 or index >= state.operations.size():
		return "Operation unavailable"
	var op: Dictionary = state.operations[index]
	if not is_ready(state, op):
		return "Not ready yet"
	var success: bool = rng.randf() < success_chance(state, op)
	op["active"] = false
	op["completed"] = true
	op["collected"] = true
	var op_name: String = str(op.get("name", "?"))
	if success:
		var reward: float = float(op.get("reward", 0.0))
		state.balance += reward
		state.lifetime_earnings += reward
		var heat_gain: float = float(op.get("heat_gain", 0.0))
		if heat_gain < 0.0:
			state.heat = maxf(0.0, state.heat + heat_gain)
		else:
			state.heat = minf(100.0, state.heat + heat_gain * 0.7)
		state.prestige_tokens += 1
		state.influence += 5
		state.total_ops_completed += 1
		return "%s Complete\n+%s\n+5 Respect" % [op_name, FormatUtil.format_money(reward)]
	var penalty: float = float(op.get("money_cost", 0.0)) * 0.5
	state.balance = maxf(0.0, state.balance - penalty)
	state.heat = minf(100.0, state.heat + float(op.get("heat_gain", 0.0)) * 0.5 + 5.0)
	return "%s FAILED\nLost %s  +heat" % [op_name, FormatUtil.format_money(penalty)]


static func tick_smuggler_ops(state, dt: float) -> Array[String]:
	if not _ManagerSystem.manager_active(state, "The Smuggler"):
		return []
	state.smuggler_timer += dt
	if state.smuggler_timer < SMUGGLER_CHECK_INTERVAL:
		return []
	state.smuggler_timer = 0.0
	var messages: Array[String] = []
	for i in state.operations.size():
		var op = state.operations[i]
		if typeof(op) != TYPE_DICTIONARY:
			continue
		if bool(op.get("collected", false)):
			if i in state.smuggler_notified:
				state.smuggler_notified.erase(i)
		elif is_ready(state, op) and i not in state.smuggler_notified:
			state.smuggler_notified.append(i)
			messages.append("Smuggler: %s ready to collect!" % op.get("name", "?"))
	for op in state.operations:
		if typeof(op) == TYPE_DICTIONARY and bool(op.get("active", false)) and not bool(op.get("collected", false)):
			return messages
	for i in state.operations.size():
		var op = state.operations[i]
		if typeof(op) != TYPE_DICTIONARY:
			continue
		var gate := can_start(state, op)
		if gate.get("ok", false):
			start_operation(state, i)
			messages.append("Smuggler launched %s" % op.get("name", "?"))
			break
	return messages


static func fmt_duration(seconds: float) -> String:
	var total: int = int(round(seconds))
	var mins: int = total / 60
	var secs: int = total % 60
	if mins > 0 and secs > 0:
		return "%dm %ds" % [mins, secs]
	if mins > 0:
		return "%dm" % mins
	return "%ds" % secs
