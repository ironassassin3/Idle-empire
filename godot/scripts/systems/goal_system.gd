class_name GoalSystem
extends RefCounted
## Dynamic goals — port of src/goals.py.

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

const _GOAL_DEFS: Array = [
	["start_cash_5k", "First Real Money ($5K)", "", "early", "lifetime", 5000.0, 500.0, 0, 1],
	["start_cash_25k", "Getting Noticed ($25K)", "", "early", "lifetime", 25000.0, 2000.0, 0, 1],
	["start_cash_100k", "Six Figures ($100K)", "", "early", "lifetime", 100000.0, 8000.0, 0, 2],
	["start_cash_250k", "Connected ($250K)", "", "early", "lifetime", 250000.0, 20000.0, 0, 2],
	["start_cash_500k", "Respected ($500K)", "", "early", "lifetime", 500000.0, 40000.0, 0, 3],
	["start_cash_1m_inf", "Made (lifetime $1M)", "", "early", "lifetime", 1000000.0, 80000.0, 0, 3],
	["cash_1m", "Reach $1M", "", "early", "balance", 1000000.0, 5000.0, 5, 0],
	["buy_pawn", "Own a Pawn Shop", "", "early", "bld_4", 1.0, 3000.0, 3, 0],
	["crew_50", "Hire 50 Crew", "", "early", "crew", 50.0, 15000.0, 8, 0],
	["heat_60", "Survive 60% Heat", "", "early", "heat_cap", 60.0, 10000.0, 6, 0],
	["first_territory", "Capture First District", "", "early", "terr_extra", 1.0, 30000.0, 12, 0],
	["cash_100m", "Reach $100M", "Fortune Built in Blood", "mid", "balance", 100000000.0, 500000.0, 20, 1],
	["downtown", "Capture Downtown", "Own the Heart of the City", "mid", "downtown", 1.0, 200000.0, 25, 2],
	["defeat_rival", "Defeat a Rival", "Send a Message", "mid", "rivals_elim", 1.0, 500000.0, 40, 3],
	["capo_rank", "Reach Capo Rank", "Earn Your Stripes", "mid", "tokens", 25.0, 300000.0, 20, 2],
	["crew_200", "Command 200 Crew", "Build an Army", "mid", "crew", 200.0, 1000000.0, 30, 0],
	["cash_1t", "Reach $1T", "Build a Financial Empire", "late", "balance", 1e12, 2e9, 80, 5],
	["all_territories", "Own All Territories", "Become the Shadow Government", "late", "terr_all", 1.0, 5e8, 120, 8],
	["rivals_3", "Eliminate 3 Rivals", "Eliminate the Competition", "late", "rivals_elim", 3.0, 1e9, 150, 10],
	["boss_rank", "Reach Boss Rank", "Rise to the Throne", "late", "tokens", 75.0, 0.0, 300, 20],
	["cash_1qa", "Reach $1Qa", "Untouchable Wealth", "late", "balance", 1e15, 5e11, 200, 15],
]


static func make_goals() -> Array:
	var out: Array = []
	for d in _GOAL_DEFS:
		out.append({
			"key": d[0],
			"label": d[1],
			"narrative": d[2],
			"phase": d[3],
			"progress_kind": d[4],
			"target": float(d[5]),
			"reward_cash": float(d[6]),
			"reward_respect": int(d[7]),
			"reward_influence": int(d[8]),
			"completed": false,
		})
	return out


static func merge_completed(goals: Array, completed_keys: Array) -> void:
	var done: Dictionary = {}
	for k in completed_keys:
		done[str(k)] = true
	for g in goals:
		if typeof(g) == TYPE_DICTIONARY and done.has(str(g.get("key", ""))):
			g["completed"] = true


static func _crew_total(state) -> float:
	var c: Dictionary = state.crew
	return float(c.get("protection", 0)) + float(c.get("collection", 0)) + float(c.get("smuggling", 0)) + float(c.get("territory", 0)) + float(c.get("heat_reduction", 0))


static func _rivals_eliminated(state) -> float:
	var n := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) == "Eliminated":
			n += 1
	return float(n)


static func _progress(state, kind: String, target: float) -> float:
	match kind:
		"lifetime":
			return float(state.lifetime_earnings)
		"balance":
			return float(state.balance)
		"bld_4":
			return float(state.buildings[4].owned) if state.buildings.size() > 4 else 0.0
		"crew":
			return _crew_total(state)
		"heat_cap":
			return minf(float(state.heat), target)
		"terr_extra":
			return maxf(0.0, float(_TerritorySystem.player_district_count(state.territories) - 1))
		"downtown":
			for t in state.territories:
				if typeof(t) == TYPE_DICTIONARY and str(t.get("name", "")) == "Downtown" and bool(t.get("unlocked", false)):
					return 1.0
			return 0.0
		"rivals_elim":
			return _rivals_eliminated(state)
		"tokens":
			return float(state.prestige_tokens)
		"terr_all":
			return float(_TerritorySystem.player_district_count(state.territories))
	return 0.0


static func check_goals(state) -> Array[String]:
	var messages: Array[String] = []
	for g in state.goals:
		if typeof(g) != TYPE_DICTIONARY or bool(g.get("completed", false)):
			continue
		var kind: String = str(g.get("progress_kind", ""))
		var target: float = float(g.get("target", 0.0))
		var cur: float = _progress(state, kind, target)
		if kind == "terr_all":
			target = float(state.territories.size())
		if target <= 0.0 or cur < target:
			continue
		g["completed"] = true
		var cash: float = float(g.get("reward_cash", 0.0))
		if cash > 0.0:
			state.balance += cash
			state.lifetime_earnings += cash
		var resp: int = int(g.get("reward_respect", 0))
		if resp > 0:
			state.influence += resp
		var inf: int = int(g.get("reward_influence", 0))
		if inf > 0:
			state.prestige_tokens += inf
		var parts: PackedStringArray = PackedStringArray()
		if cash > 0.0:
			parts.append("+%s" % FormatUtil.format_money(cash))
		if resp > 0:
			parts.append("+%d Resp" % resp)
		if inf > 0:
			parts.append("+%d Inf" % inf)
		var title: String = str(g.get("narrative", ""))
		if title.is_empty():
			title = str(g.get("label", "Goal"))
		messages.append("%s\n%s" % [title, " ".join(parts)])
	return messages


static func progress_for(state, g: Dictionary) -> Dictionary:
	var kind: String = str(g.get("progress_kind", ""))
	var target: float = float(g.get("target", 0.0))
	if kind == "terr_all":
		target = float(state.territories.size())
	return {"current": _progress(state, kind, target), "target": target}


static func current_goals(state, max_count: int = 4) -> Array:
	var phase_order := {"early": 0, "mid": 1, "late": 2}
	var incomplete: Array = []
	for g in state.goals:
		if typeof(g) == TYPE_DICTIONARY and not bool(g.get("completed", false)):
			incomplete.append(g)
	incomplete.sort_custom(func(a, b): return int(phase_order.get(str(a.get("phase", "")), 9)) < int(phase_order.get(str(b.get("phase", "")), 9)))
	return incomplete.slice(0, max_count)
