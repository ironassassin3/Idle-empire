class_name OfflineSystem
extends RefCounted
## Offline return earnings — port of src/save_load.py offline block.

const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

const CAP_SECONDS := 12.0 * 3600.0
const BASE_EFFICIENCY := 0.6


static func apply_offline_return(state, raw_away_secs: float) -> void:
	if raw_away_secs < 60.0:
		return
	var elapsed: float = minf(raw_away_secs, CAP_SECONDS)
	var eff: float = minf(1.0, BASE_EFFICIENCY * _PrestigeTree.offline_earnings_mult(state))
	var ips: float = state.income_per_second()
	var gain: float = ips * elapsed * eff
	if gain <= 0.0:
		return
	state.balance += gain
	state.lifetime_earnings += gain
	state.offline_gain = gain
	state.offline_secs_away = elapsed
	state.offline_capped = raw_away_secs > CAP_SECONDS
	state.return_ops_ready = _count_ready_ops(state)
	state.return_territory_player = _TerritorySystem.player_district_count(state.territories)
	state.return_territory_total = state.territories.size()
	state.return_rival_active = _count_active_rivals(state)
	state.return_rival_at_war = _count_at_war(state)
	# Rival activity during the offline window (snapshot above is pre-sim, matching pygame).
	state.offline_rival_events = simulate_offline_rivals(state, elapsed)
	state.show_offline_overlay = true


## Lightweight offline rival sim — port of src/save_load.py _simulate_offline_rivals.
## Adjusts rival turf/power only (never steals player territory) and returns up to
## 3 narrative strings. Deterministic per elapsed_secs (seeded RNG). Not income-
## affecting, so outcomes need not byte-match pygame's RNG — only the logic/odds.
static func simulate_offline_rivals(state, elapsed_secs: float) -> Array[String]:
	var events: Array[String] = []
	if state.rivals.is_empty() or elapsed_secs < 60.0:
		return events
	var active: Array = []
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			active.append(r)
	if active.is_empty():
		return events

	var rng := RandomNumberGenerator.new()
	rng.seed = int(elapsed_secs * 37.0) & 0xFFFFFFFF
	var ticks: int = clampi(int(elapsed_secs / 135.0), 1, 30)

	for _t in ticks:
		for rival in active:
			if rng.randf() > float(rival.get("aggression", 0.5)) * 0.25:
				continue
			# Weighted action: expand 3/9, rival_war 2/9, weaken 4/9.
			var pick := rng.randi_range(0, 8)
			var action := "weaken"
			if pick < 3:
				action = "expand"
			elif pick < 5:
				action = "rival_war"

			if action == "expand":
				if int(rival.get("turf", 0)) < 8:
					rival["turf"] = mini(8, int(rival.get("turf", 0)) + 1)
					if events.size() < 3:
						events.append("%s captured a district" % str(rival.get("name", "A rival")))
			elif action == "rival_war" and active.size() > 1:
				var others: Array = []
				for r in active:
					if r != rival:
						others.append(r)
				var target = others[rng.randi_range(0, others.size() - 1)]
				target["power"] = maxi(0, int(target.get("power", 0)) - rng.randi_range(2, 6))
				if int(target["power"]) < 10:
					target["status"] = "Weakened"
				if events.size() < 3:
					events.append("%s clashed with %s" % [str(rival.get("name", "")), str(target.get("name", ""))])
			elif action == "weaken":
				rival["power"] = maxi(0, int(rival.get("power", 0)) - rng.randi_range(1, 4))
				if int(rival["power"]) < 10:
					rival["status"] = "Weakened"
				if rng.randf() < 0.25 and events.size() < 3:
					events.append("%s lost ground in street conflict" % str(rival.get("name", "")))

	return events


static func _count_ready_ops(state) -> int:
	var n := 0
	for op in state.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(state, op):
			n += 1
	return n


static func _count_active_rivals(state) -> int:
	var n := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			n += 1
	return n


static func _count_at_war(state) -> int:
	var n := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and bool(r.get("at_war", false)) and str(r.get("status", "")) != "Eliminated":
			n += 1
	return n
