class_name HeatSystem
extends RefCounted

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")
const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const HEAT_MIN := 0.0
const HEAT_MAX := 100.0
const RAID_THRESHOLD := 60.0
const RAID_BALANCE_PENALTY := 0.08
const RAID_HEAT_REDUCTION := 15.0

const _PASSIVE_RISE := 0.01
const _RISE_PER_BLD := 0.0003
const _NATURAL_DECAY := 0.004
const _INCOME_BONUS_PER_PT := 0.008
const _CLICK_BONUS_PER_PT := 0.005
const _RAID_CHANCE_PER_SEC := 0.0012
const _RAID_HEAT_SCALE := 0.004


static func heat_income_mult(heat: float) -> float:
	var bonus := maxf(0.0, heat - 50.0) * _INCOME_BONUS_PER_PT
	return 1.0 + bonus


static func heat_click_mult(heat: float) -> float:
	var bonus := maxf(0.0, heat - 30.0) * _CLICK_BONUS_PER_PT
	return 1.0 + bonus


## Net heat change per second (rise − decay − crew − promoter), for Carl forecast UI.
static func net_rate_per_sec(state) -> float:
	var total_bld := 0
	for b in state.buildings:
		total_bld += b.owned
	var rise := (_PASSIVE_RISE + total_bld * _RISE_PER_BLD)
	rise *= maxf(0.0, 1.0 - _TerritorySystem.territory_heat_resistance(state.territories))
	rise *= _TerritorySystem.milestone_heat_mult(state)
	rise *= _ManagerSystem.heat_gain_mult(state)
	if state.buildings.size() > 7:
		var clubs: int = state.buildings[7].owned
		if clubs > 0:
			rise -= 0.5 * float(clubs)
	var decay := (
		_NATURAL_DECAY
		+ Prestige.rank_heat_decay_bonus(state.lifetime_tokens)
		+ _PrestigeTree.heat_decay_bonus(state)
		+ _DragonSystem.heat_decay_bonus(state)
		- _DragonSystem.heat_decay_penalty(state)
	)
	if _ManagerSystem.manager_active(state, "The Promoter"):
		var target: float = _ManagerSystem.promoter_heat_target(state)
		if state.heat > target:
			decay += minf(state.heat - target, 20.0) * 0.06
	decay += _CrewSystem.heat_reduction_per_sec(state.crew)
	return rise - decay


static func forecast_delta(state, horizon_sec: float = 120.0) -> float:
	var current: float = float(state.heat)
	var end: float = clampf(current + net_rate_per_sec(state) * horizon_sec, HEAT_MIN, HEAT_MAX)
	return end - current


static func update(state, dt: float, rng: RandomNumberGenerator) -> Array[String]:
	var events: Array[String] = []
	var heat_before: float = state.heat
	var total_bld := 0
	for b in state.buildings:
		total_bld += b.owned
	var rise := (_PASSIVE_RISE + total_bld * _RISE_PER_BLD) * dt
	rise *= maxf(0.0, 1.0 - _TerritorySystem.territory_heat_resistance(state.territories))
	rise *= _TerritorySystem.milestone_heat_mult(state)
	rise *= _ManagerSystem.heat_gain_mult(state)
	if state.buildings.size() > 7:
		var clubs: int = state.buildings[7].owned
		if clubs > 0:
			rise -= 0.5 * float(clubs) * dt
	var decay := (
		_NATURAL_DECAY
		+ Prestige.rank_heat_decay_bonus(state.lifetime_tokens)
		+ _PrestigeTree.heat_decay_bonus(state)
		+ _DragonSystem.heat_decay_bonus(state)
		- _DragonSystem.heat_decay_penalty(state)
	) * dt
	var delta := rise - decay
	if delta > 0.0:
		state.total_heat_generated += delta
	var heat: float = clampf(heat_before + delta, HEAT_MIN, HEAT_MAX)
	if _ManagerSystem.tick_carl_emergency(state, heat_before, heat):
		heat = state.heat
		events.append("Carl dumped heat — emergency rescue")
	else:
		state.heat = heat
	if state.heat >= RAID_THRESHOLD:
		var excess: float = state.heat - RAID_THRESHOLD
		var raid_prob: float = (_RAID_CHANCE_PER_SEC + excess * _RAID_HEAT_SCALE) * dt
		if rng.randf() < raid_prob:
			var penalty: float = state.balance * RAID_BALANCE_PENALTY
			var result := _ManagerSystem.apply_raid_penalty(state, penalty)
			state.heat = maxf(HEAT_MIN, state.heat - RAID_HEAT_REDUCTION)
			if result["absorbed"]:
				events.append("Raid blocked by The Collector's shield!")
			else:
				events.append("Police raid! Lost %s" % FormatUtil.format_money(result["actual"]))
	return events
