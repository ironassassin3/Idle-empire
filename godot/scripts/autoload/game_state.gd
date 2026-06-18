extends Node
## Core simulation — mirrors PlayingState economy loop.

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _WorldState = preload("res://scripts/systems/world_state.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _RivalSystem = preload("res://scripts/systems/rival_system.gd")
const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
const _AchievementSystem = preload("res://scripts/systems/achievement_system.gd")
const _PrestigeTree = preload("res://scripts/systems/prestige_tree.gd")
const _BuffSystem = preload("res://scripts/systems/buff_system.gd")
const _EventSystem = preload("res://scripts/systems/event_system.gd")
const _GoalSystem = preload("res://scripts/systems/goal_system.gd")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")
const _OfflineSystem = preload("res://scripts/systems/offline_system.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

signal stats_changed
signal notification(message: String, color: Color)

var balance: float = 0.0
var lifetime_earnings: float = 0.0
var prestige_tokens: int = 0
var prestige_count: int = 0
var next_prestige_earnings: float = 0.0
var arms_influence_frac: float = 0.0  # Arms Broker special: fractional Influence accrual
var click_count: int = 0
var play_time: float = 0.0
var heat: float = 0.0
var total_heat_generated: float = 0.0
var influence: int = 0

var buildings: Array[Building] = []
var managers: Array[Manager] = []
var upgrades: Array[Upgrade] = []

# Mid-game data (P1 stubs — preserved in save for pygame import)
var territories: Array = []
var rivals: Array = []
var crew: Dictionary = {}
var operations: Array = []
var perks_purchased: Array = []
var prestige_branch: String = ""

# Prestige perk runtime (computed by PrestigeTree.apply_perks)
var perk_click_mult: float = 1.0
var perk_income_mult: float = 1.0
var perk_bld_mults: Array = []
var perk_auto_buy: bool = false
var perk_auto_upgrade: bool = false
var perk_autobuy_timer: float = 0.0
var perk_autoupg_timer: float = 0.0

# Territory runtime (P2)
var city_control_milestones: Array = []
var total_territories_captured: int = 0
var highest_city_control: float = 0.0
var total_rivals_defeated: int = 0
var rival_activity_log: Array = []
var total_ops_completed: int = 0

# Lifetime stats + achievements (P3 stats tiering)
var peak_income: float = 0.0
var highest_cash_held: float = 0.0
var total_buildings_purchased: int = 0
var achievements: Array = []
var coins_caught: int = 0
var golden_coin_active: bool = false
var golden_coin_lifetime: float = 0.0
var golden_coin_timer: float = 0.0
var promoter_heat_target: float = 50.0
var offline_gain: float = 0.0
var offline_rival_events: Array[String] = []  # runtime-only; rebuilt on load

# Manager runtime (P1 behaviors)
var collector_shield_cd: float = 0.0
var carl_emergency_used: bool = false
var mechanic_timer: float = 0.0
var autobuy_timer: float = 0.0
var broker_retry_cd: float = 0.0
var smuggler_timer: float = 0.0
var smuggler_notified: Array = []

# Events / goals / tutorial (P4)
var buffs: Array = []
var event_timer: float = -1.0
var pending_event: Dictionary = {}
var event_outcome: String = ""
var event_outcome_timer: float = 0.0
var event_is_first: bool = false
var goals: Array = []
var tutorial_step: int = 0
var milestone_queue: Array = []
var milestone_timer: float = 0.0
var shown_raid_tutorial: bool = false
var shown_ops_tutorial: bool = false
var shown_influence_tutorial: bool = false
var shown_syndicate_tutorial: bool = false
var shown_crew_tutorial: bool = false
var shown_territory_tutorial: bool = false
var shown_rivals_tutorial: bool = false
var shown_heat_warning: bool = false
var bw_attack_bonus: float = 0.0
var bw_negotiate_bonus: float = 0.0
var elim_overlay_active: bool = false
var elim_overlay_name: String = ""
var elim_overlay_flavor: String = ""
var elim_overlay_rewards: String = ""
var elim_overlay_timer: float = 0.0
var recent_clicks: Array = []
var last_click_crit: bool = false
var _last_rank: String = ""
var _rank_tracking_ready: bool = false

# Settings (Config tab)
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.5
var mute_all: bool = false
var fps_cap: int = 60
var show_particles: bool = true

# Offline return overlay
var show_offline_overlay: bool = false
var offline_secs_away: float = 0.0
var offline_capped: bool = false
var return_ops_ready: int = 0
# Daily login reward (port of src/save_load.py). Persisted: last_login_date, daily_streak.
var last_login_date: String = ""
var daily_streak: int = 0
var daily_reward: float = 0.0
var show_daily_overlay: bool = false
var return_territory_player: int = 0
var return_territory_total: int = 0
var return_rival_active: int = 0
var return_rival_at_war: int = 0

# Dragon patron (P5 — ROADMAP parity with src/dragon.py)
var dragon_patron: String = ""
var dragon_xp: int = 0
var dragon_ability_cooldowns: Dictionary = {}
var dragon_red_elim_count: int = 0
var dragon_request_key: String = ""
var dragon_req_snapshot: Dictionary = {}
var dragon_request_cooldown: float = 15.0
var dragon_recent_requests: Array = []
var dragon_mood_timer: float = 0.0
var dragon_rage_timer: float = 0.0
var dragon_logistics_timer: float = 0.0
var dragon_guaranteed_territory: bool = false
var dragon_black_last_op_time: float = -1.0

var simulation_active: bool = false

var _ips_dirty: bool = true
var _ips_cached: float = 0.0
var _autosave_timer: float = 0.0
var _ach_check_timer: float = 0.0
var _goal_check_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

const COIN_SPAWN_MIN := 30.0
const COIN_SPAWN_MAX := 60.0


func set_simulation_active(active: bool) -> void:
	simulation_active = active
	if not active:
		_autosave_timer = 0.0


func _ready() -> void:
	_rng.randomize()
	call_deferred("reset_new_game")


func reset_new_game() -> void:
	buildings = BuildingDefs.make_buildings()
	managers = ManagerDefs.make_managers()
	upgrades = UpgradeDefs.make_upgrades()
	territories = _WorldState.make_territories()
	rivals = _WorldState.make_rivals(_rng)
	_TerritorySystem.assign_rival_territories(territories, rivals)
	_RivalSystem.clear_activity_log(self)
	crew = _WorldState.default_crew()
	operations = _WorldState.make_operations()
	perks_purchased = []
	prestige_branch = ""
	_reset_perk_runtime()
	city_control_milestones = []
	total_territories_captured = 0
	highest_city_control = 0.0
	total_rivals_defeated = 0
	rival_activity_log.clear()
	total_ops_completed = 0
	peak_income = 0.0
	highest_cash_held = 0.0
	total_buildings_purchased = 0
	achievements = _AchievementSystem.make_achievements()
	goals = _GoalSystem.make_goals()
	coins_caught = 0
	golden_coin_active = false
	golden_coin_lifetime = 0.0
	golden_coin_timer = _rng.randf_range(COIN_SPAWN_MIN, COIN_SPAWN_MAX)
	promoter_heat_target = 50.0
	offline_gain = 0.0
	offline_rival_events = []
	buffs.clear()
	event_timer = -1.0
	pending_event = {}
	event_outcome = ""
	event_outcome_timer = 0.0
	milestone_queue.clear()
	milestone_timer = 0.0
	tutorial_step = 0
	shown_raid_tutorial = false
	shown_ops_tutorial = false
	shown_influence_tutorial = false
	shown_syndicate_tutorial = false
	shown_crew_tutorial = false
	shown_territory_tutorial = false
	shown_rivals_tutorial = false
	shown_heat_warning = false
	bw_attack_bonus = 0.0
	bw_negotiate_bonus = 0.0
	elim_overlay_active = false
	elim_overlay_name = ""
	elim_overlay_flavor = ""
	elim_overlay_rewards = ""
	elim_overlay_timer = 0.0
	recent_clicks.clear()
	show_offline_overlay = false
	offline_secs_away = 0.0
	offline_capped = false
	last_login_date = ""
	daily_streak = 0
	daily_reward = 0.0
	show_daily_overlay = false
	dragon_patron = ""
	dragon_xp = 0
	dragon_ability_cooldowns = {}
	dragon_red_elim_count = 0
	dragon_request_key = ""
	dragon_req_snapshot = {}
	dragon_request_cooldown = 15.0
	dragon_recent_requests = []
	dragon_mood_timer = 0.0
	dragon_rage_timer = 0.0
	dragon_logistics_timer = 0.0
	dragon_guaranteed_territory = false
	dragon_black_last_op_time = -1.0
	influence = 0
	_ManagerSystem.reset_runtime(self)
	balance = 0.0
	lifetime_earnings = 0.0
	prestige_tokens = 0
	arms_influence_frac = 0.0
	prestige_count = 0
	next_prestige_earnings = 0.0
	click_count = 0
	play_time = 0.0
	heat = 0.0
	total_heat_generated = 0.0
	_PrestigeTree.apply_perks(self)
	_mark_ips_dirty()
	stats_changed.emit()
	_sync_rank_tracking()
	_apply_audio_settings()


func _audio() -> Node:
	return get_node_or_null("/root/AudioManager")


func _play_sfx(cue: String) -> void:
	var am := _audio()
	if am:
		am.play(cue)


func _apply_audio_settings() -> void:
	var am := _audio()
	if am:
		am.apply_from_state(self)


func _sync_rank_tracking() -> void:
	_last_rank = Prestige.get_rank(prestige_tokens)
	_rank_tracking_ready = true


func _check_rank_up() -> void:
	if not _rank_tracking_ready or not simulation_active:
		return
	var current := Prestige.get_rank(prestige_tokens)
	if current == _last_rank:
		return
	_last_rank = current
	notification.emit("Rank Up → %s" % current, GameTheme.GOLD_BRIGHT)
	_TutorialSystem.push_milestone(self, "RANK UP\n%s" % current, 6.0)
	_play_sfx("rankup")


func _process(delta: float) -> void:
	if not simulation_active:
		return
	play_time += delta
	_tick_golden_coin(delta)
	var passive := income_per_second() * delta
	if is_finite(passive):
		balance += passive
		lifetime_earnings += passive
	_tick_building_specials(delta)
	_tick_loan_interest(delta)
	_BuffSystem.tick_buffs(self, delta)
	_EventSystem.update_events(self, delta, _rng)
	_TutorialSystem.tick_milestones(self, delta)
	_TutorialSystem.tick_contextual(self)
	if elim_overlay_active:
		elim_overlay_timer -= delta
		if elim_overlay_timer <= 0.0:
			dismiss_elimination_overlay()
	for msg in _TerritorySystem.tick_milestones(self):
		_TutorialSystem.push_milestone(self, msg, 6.0)
	for msg in _ManagerSystem.tick_manager_effects(self, delta):
		notification.emit(msg, GameTheme.GREEN)
	for msg in _OperationSystem.tick_smuggler_ops(self, delta):
		var smug_col := GameTheme.GOLD_BRIGHT if msg.begins_with("Smuggler:") else GameTheme.GREEN
		notification.emit(msg, smug_col)
	for msg in HeatSystem.update(self, delta, _rng):
		if msg.begins_with("Police raid") or msg.begins_with("Raid blocked"):
			_TutorialSystem.on_police_raid(self)
		var raid_col := GameTheme.GREEN if msg.begins_with("Raid blocked") else GameTheme.RED
		notification.emit(msg, raid_col)
	var crew_heat_decay: float = _CrewSystem.heat_reduction_per_sec(crew) * delta
	if crew_heat_decay > 0.0:
		heat = maxf(0.0, heat - crew_heat_decay)
	_DragonSystem.dragon_update(self, delta, _rng)
	for msg in _RivalSystem.update_rivals(self, delta, _rng):
		if msg.is_empty():
			continue
		var col := GameTheme.RED if msg.begins_with("RAID:") else GameTheme.TEXT_MUTED
		notification.emit(msg, col)
	for msg in _PrestigeTree.tick_perk_effects(self, delta):
		notification.emit(msg, GameTheme.GREEN)
	var ips := income_per_second()
	if ips > peak_income:
		peak_income = ips
	if balance > highest_cash_held:
		highest_cash_held = balance
	_ach_check_timer -= delta
	if _ach_check_timer <= 0.0:
		_ach_check_timer = 0.5
		for ach_name in _AchievementSystem.check_and_earn(self):
			notification.emit("Achievement: %s" % ach_name, GameTheme.GOLD_BRIGHT)
			_mark_ips_dirty()
	_goal_check_timer -= delta
	if _goal_check_timer <= 0.0:
		_goal_check_timer = 1.0
		for msg in _GoalSystem.check_goals(self):
			notification.emit(msg, GameTheme.GOLD_BRIGHT)
			_mark_ips_dirty()
	_autosave_timer += delta
	if _autosave_timer >= GameConfig.AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		SaveManager.save_game()
	_check_rank_up()
	_mark_ips_dirty()
	stats_changed.emit()


func _mark_ips_dirty() -> void:
	_ips_dirty = true


func income_per_second() -> float:
	if not _ips_dirty:
		return _ips_cached
	var base: float = _ManagerSystem.compute_base_income(self)
	var mult := Prestige.income_mult(prestige_tokens)
	if UpgradeDefs.has_prestige_boost(upgrades):
		mult *= Prestige.prestige_mastery_mult(prestige_tokens)
	mult *= perk_income_mult
	mult *= _PrestigeTree.turf_intimidation_income_mult(self)
	mult *= _PrestigeTree.district_income_mult(self)
	mult *= HeatSystem.heat_income_mult(heat)
	mult *= _TerritorySystem.territory_income_mult(territories)
	mult *= 1.0 + _TerritorySystem.territory_district_count_bonus(territories)
	mult *= _TerritorySystem.milestone_income_mult(self)
	mult *= _CrewSystem.collection_income_mult(crew, self)
	mult *= _AchievementSystem.income_mult(achievements)
	mult *= _BuffSystem.income_mult(self)
	if _BuffSystem.has_buff(self, "frenzy"):
		mult *= 7.0
	mult *= _DragonSystem.rival_presence_income_mult(self)
	mult *= _DragonSystem.eliminated_rival_income_mult(self)
	mult *= 1.0 + _DragonSystem.active_ops_income_bonus(self)
	mult *= 1.0 + Prestige.respect_income_bonus(influence) * _PrestigeTree.respect_income_mult(self)
	mult *= 1.0 + Prestige.rank_income_bonus(prestige_tokens)
	_ips_cached = base * mult
	_ips_dirty = false
	return _ips_cached


func click_value() -> float:
	var mult := Prestige.income_mult(prestige_tokens)
	var dealer_bonus := BuildingDefs.dealer_click_bonus(buildings)
	var ips_term := GameConfig.CLICK_IPS_FRACTION * income_per_second()
	var value := mult + dealer_bonus + ips_term
	value *= UpgradeDefs.click_multiplier(upgrades)
	value *= perk_click_mult
	value *= HeatSystem.heat_click_mult(heat)
	value *= _TerritorySystem.territory_click_mult(territories)
	if _BuffSystem.has_buff(self, "hustle"):
		value *= GameConfig.CLICK_HUSTLE_MULT
	if _BuffSystem.has_buff(self, "click_storm"):
		value *= 10.0
	return value


func _register_active_click() -> void:
	var now: float = play_time
	recent_clicks.append(now)
	var win: float = GameConfig.CLICK_HUSTLE_WINDOW
	var kept: Array = []
	for t in recent_clicks:
		if now - float(t) <= win:
			kept.append(t)
	recent_clicks = kept
	if recent_clicks.size() >= GameConfig.CLICK_HUSTLE_CLICKS:
		var was_active: bool = _BuffSystem.has_buff(self, "hustle")
		_BuffSystem.add_buff(self, "hustle", GameConfig.CLICK_HUSTLE_DURATION, GameConfig.CLICK_HUSTLE_MULT)
		if not was_active:
			notification.emit(
				"HUSTLE ACTIVE  ×%.2f clicks" % GameConfig.CLICK_HUSTLE_MULT,
				GameTheme.GOLD,
			)


func do_click() -> float:
	click_count += 1
	var value := click_value()
	last_click_crit = false
	if _rng.randf() < GameConfig.CLICK_CRIT_CHANCE:
		value *= _rng.randf_range(GameConfig.CLICK_CRIT_MIN, GameConfig.CLICK_CRIT_MAX)
		last_click_crit = true
		notification.emit("Critical hit!", GameTheme.GOLD_BRIGHT)
	else:
		_play_sfx("click")
	balance += value
	lifetime_earnings += value
	_register_active_click()
	_mark_ips_dirty()
	stats_changed.emit()
	return value


func can_buy_building(index: int, qty: int = 1) -> bool:
	if index < 0 or index >= buildings.size():
		return false
	return balance >= buildings[index].cost_for_n(qty)


func buy_building(index: int, qty: int = 1) -> bool:
	if not can_buy_building(index, qty):
		return false
	var cost := buildings[index].cost_for_n(qty)
	balance -= cost
	buildings[index].owned += qty
	record_building_purchase(qty)
	BuildingDefs.sync_racket_multiplier(buildings)
	_mark_ips_dirty()
	stats_changed.emit()
	_play_sfx("purchase")
	return true


func can_buy_upgrade(index: int) -> bool:
	if index < 0 or index >= upgrades.size():
		return false
	var u := upgrades[index]
	if u.purchased:
		return false
	return balance >= UpgradeDefs.effective_cost(u, self)


func buy_upgrade(index: int) -> bool:
	if not can_buy_upgrade(index):
		return false
	var u := upgrades[index]
	var cost := UpgradeDefs.effective_cost(u, self)
	balance -= cost
	u.purchased = true
	UpgradeDefs.apply_effect(u, self)
	notification.emit("Upgrade: %s" % u.display_name, GameTheme.GREEN)
	_mark_ips_dirty()
	stats_changed.emit()
	return true


func can_hire_manager(index: int) -> bool:
	return ManagerDefs.can_hire(self, index)


func hire_manager(index: int) -> bool:
	if not can_hire_manager(index):
		return false
	var m := managers[index]
	balance -= m.cost
	m.hired = true
	notification.emit("Hired %s" % m.display_name, GameTheme.GOLD)
	_mark_ips_dirty()
	stats_changed.emit()
	return true


func can_prestige() -> bool:
	return Prestige.can_prestige(self)


func do_prestige() -> bool:
	if not can_prestige():
		return false
	var raw_gain: float = float(Prestige.calc_influence_gain(lifetime_earnings))
	raw_gain *= _ManagerSystem.influence_gain_mult(self)
	raw_gain *= _PrestigeTree.influence_gain_mult(self)
	raw_gain *= _DragonSystem.prestige_influence_mult(self)
	var gain := maxi(1, int(round(raw_gain)))
	prestige_tokens += gain
	influence += gain
	prestige_count += 1
	if prestige_count == 1:
		next_prestige_earnings = GameConfig.FIRST_PRESTIGE_EARNINGS * GameConfig.PRESTIGE_EARNINGS_GROWTH
	else:
		next_prestige_earnings = maxf(next_prestige_earnings * GameConfig.PRESTIGE_EARNINGS_GROWTH, lifetime_earnings * 0.5)
	balance = 0.0
	lifetime_earnings = 0.0
	for b in buildings:
		b.owned = 0
		b.income_multiplier = 1.0
	for u in upgrades:
		u.purchased = false
	_ManagerSystem.reset_runtime(self)
	promoter_heat_target = 50.0
	_TerritorySystem.partial_territory_reset(territories, self)
	_RivalSystem.reconstitute_eliminated_rivals(rivals, _rng)
	crew = _CrewSystem.default_crew()
	operations = _OperationSystem.make_operations()
	_buildings_reset_specials()
	peak_income = 0.0
	_PrestigeTree.reset_branch(self)
	perk_autobuy_timer = 0.0
	perk_autoupg_timer = 0.0
	_DragonSystem.on_prestige(self)
	_DragonSystem.reset_for_prestige(self)
	_PrestigeTree.apply_perks(self)
	notification.emit("Prestige! +%d Influence" % gain, GameTheme.GOLD_BRIGHT)
	_mark_ips_dirty()
	stats_changed.emit()
	SaveManager.save_game()
	return true


func rank_label() -> String:
	return Prestige.get_rank(prestige_tokens)


func total_buildings_owned() -> int:
	var n := 0
	for b in buildings:
		n += b.owned
	return n


func record_building_purchase(qty: int) -> void:
	if qty > 0:
		total_buildings_purchased += qty


func select_prestige_branch(branch: String) -> String:
	if _PrestigeTree.select_branch(self, branch):
		_mark_ips_dirty()
		stats_changed.emit()
		var meta: Dictionary = PrestigeTree.BRANCH_META[branch]
		return "Path committed: %s" % meta.get("name", branch)
	return "Cannot select that path"


func buy_prestige_perk(key: String) -> String:
	var gate: Dictionary = _PrestigeTree.can_buy_perk(self, key)
	if not gate.get("ok", false):
		return str(gate.get("reason", "Cannot buy"))
	if _PrestigeTree.buy_perk(self, key):
		_mark_ips_dirty()
		stats_changed.emit()
		return "Purchased: %s" % _PrestigeTree.perk_name(key)
	return "Purchase failed"


func _reset_perk_runtime() -> void:
	perk_click_mult = 1.0
	perk_income_mult = 1.0
	perk_bld_mults = []
	perk_auto_buy = false
	perk_auto_upgrade = false
	perk_autobuy_timer = 0.0
	perk_autoupg_timer = 0.0


## Null-safe save-field readers. Dictionary.get(key, default) only returns
## `default` when the key is ABSENT; a present-but-null value (older saves, or
## saves produced elsewhere) would reach float()/int()/bool() and raise
## "Nonexistent constructor". These coalesce both absent and null to the default.
func _f(data: Dictionary, key: String, def: float = 0.0) -> float:
	var v = data.get(key)
	return float(v) if v != null else def


func _i(data: Dictionary, key: String, def: int = 0) -> int:
	var v = data.get(key)
	return int(v) if v != null else def


func _b(data: Dictionary, key: String, def: bool = false) -> bool:
	var v = data.get(key)
	return bool(v) if v != null else def


func _arr(data: Dictionary, key: String) -> Array:
	var v = data.get(key)
	return v if v is Array else []


func apply_save_data(data: Dictionary) -> void:
	buildings = BuildingDefs.make_buildings()
	managers = ManagerDefs.make_managers()
	upgrades = UpgradeDefs.make_upgrades()
	territories = _WorldState.make_territories()
	rivals = _WorldState.make_rivals(_rng)
	crew = _WorldState.default_crew()
	operations = _WorldState.make_operations()
	perks_purchased = []
	achievements = _AchievementSystem.make_achievements()
	goals = _GoalSystem.make_goals()
	var prev_timestamp: float = _f(data, "save_timestamp", 0.0)
	balance = _f(data, "balance", 0.0)
	lifetime_earnings = _f(data, "lifetime_earnings", 0.0)
	prestige_tokens = _i(data, "prestige_tokens", 0)
	arms_influence_frac = _f(data, "arms_influence_frac", 0.0)
	prestige_count = _i(data, "prestige_count", 0)
	next_prestige_earnings = _f(data, "next_prestige_earnings", 0.0)
	click_count = _i(data, "click_count", 0)
	play_time = _f(data, "play_time", 0.0)
	heat = _f(data, "heat", 0.0)
	total_heat_generated = _f(data, "total_heat_generated", 0.0)
	influence = _i(data, "influence", 0)
	collector_shield_cd = _f(data, "collector_shield_cd", 0.0)
	carl_emergency_used = _b(data, "carl_emergency_used", false)
	mechanic_timer = _f(data, "mechanic_timer", 0.0)
	autobuy_timer = _f(data, "autobuy_timer", 0.0)
	if data.has("territories"):
		_TerritorySystem.merge_save_territories(territories, data["territories"])
	if data.has("rivals"):
		_RivalSystem.merge_save_rivals(rivals, data["rivals"])
	if data.has("crew") and typeof(data["crew"]) == TYPE_DICTIONARY:
		_CrewSystem.merge_save_crew(crew, data["crew"])
	if data.has("operations"):
		_OperationSystem.merge_save_operations(operations, data["operations"])
	if data.has("perks_purchased"):
		perks_purchased = data["perks_purchased"]
	var branch_raw = data.get("prestige_branch", "")
	if typeof(branch_raw) == TYPE_STRING and _PrestigeTree.is_valid_branch(branch_raw):
		prestige_branch = branch_raw
	else:
		prestige_branch = ""
	city_control_milestones = []
	for key in data.get("city_control_milestones", []):
		city_control_milestones.append(str(key))
	total_territories_captured = _i(data, "total_territories_captured", 0)
	highest_city_control = _f(data, "highest_city_control", 0.0)
	total_rivals_defeated = _i(data, "total_rivals_defeated", 0)
	total_ops_completed = _i(data, "total_ops_completed", 0)
	peak_income = _f(data, "peak_income", 0.0)
	highest_cash_held = _f(data, "highest_cash_held", 0.0)
	total_buildings_purchased = _i(data, "total_buildings_purchased", 0)
	coins_caught = _i(data, "coins_caught", 0)
	promoter_heat_target = _f(data, "promoter_heat_target", 50.0)
	offline_gain = _f(data, "offline_gain", 0.0)
	if data.has("achievements"):
		_AchievementSystem.merge_save(achievements, data["achievements"])
	if data.has("goals_completed"):
		_GoalSystem.merge_completed(goals, data["goals_completed"])
	tutorial_step = _i(data, "tutorial_step", 0)
	shown_raid_tutorial = _b(data, "shown_raid_tutorial", false)
	shown_ops_tutorial = _b(data, "shown_ops_tutorial", false)
	shown_influence_tutorial = _b(data, "shown_influence_tutorial", false)
	shown_syndicate_tutorial = _b(data, "shown_syndicate_tutorial", false)
	shown_crew_tutorial = _b(data, "shown_crew_tutorial", false)
	shown_territory_tutorial = _b(data, "shown_territory_tutorial", false)
	shown_rivals_tutorial = _b(data, "shown_rivals_tutorial", false)
	shown_heat_warning = _b(data, "shown_heat_warning", false)
	master_volume = _f(data, "master_volume", 1.0)
	sfx_volume = _f(data, "sfx_volume", 1.0)
	music_volume = _f(data, "music_volume", 0.5)
	mute_all = _b(data, "mute_all", false)
	fps_cap = _i(data, "fps_cap", 60)
	show_particles = _b(data, "show_particles", true)
	var patron_raw = data.get("dragon_patron", data.get("dragon_key", null))
	if patron_raw != null and str(patron_raw) in _DragonSystem.DRAGON_META:
		dragon_patron = str(patron_raw)
	else:
		dragon_patron = ""
	dragon_xp = maxi(0, _i(data, "dragon_xp", 0))
	dragon_red_elim_count = _i(data, "dragon_red_elim_count", 0)
	dragon_ability_cooldowns = {}
	var raw_cds = data.get("dragon_ability_cooldowns", {})
	if typeof(raw_cds) == TYPE_DICTIONARY:
		for k in raw_cds.keys():
			if str(k) in _DragonSystem.ABILITIES and raw_cds[k] != null:
				dragon_ability_cooldowns[str(k)] = float(raw_cds[k])
	dragon_request_key = ""
	dragon_req_snapshot = {}
	dragon_request_cooldown = 15.0
	dragon_recent_requests = []
	dragon_mood_timer = 0.0
	dragon_rage_timer = 0.0
	dragon_logistics_timer = 0.0
	dragon_guaranteed_territory = false
	dragon_black_last_op_time = -1.0
	buffs.clear()
	event_timer = -1.0
	pending_event = {}
	show_offline_overlay = false
	var owned: Array = _arr(data, "buildings")
	for i in mini(owned.size(), buildings.size()):
		buildings[i].owned = int(owned[i]) if owned[i] != null else 0
	var mgr: Array = _arr(data, "managers")
	for i in mini(mgr.size(), managers.size()):
		managers[i].hired = bool(mgr[i]) if mgr[i] != null else false
	var upg: Array = _arr(data, "upgrades")
	for i in mini(upg.size(), upgrades.size()):
		if upg[i] != null and bool(upg[i]):
			upgrades[i].purchased = true
			UpgradeDefs.apply_effect(upgrades[i], self)
	BuildingDefs.sync_racket_multiplier(buildings)
	_PrestigeTree.apply_perks(self)
	var login_raw = data.get("last_login_date")
	last_login_date = str(login_raw) if login_raw != null else ""
	daily_streak = _i(data, "daily_streak", 0)
	if prev_timestamp > 0.0:
		var away: float = float(Time.get_unix_time_from_system()) - prev_timestamp
		_OfflineSystem.apply_offline_return(self, away)
	_apply_daily_reward()
	_mark_ips_dirty()
	stats_changed.emit()
	_sync_rank_tracking()
	_apply_audio_settings()


# Once-per-calendar-day login reward (port of src/save_load.py). Streak +1 on a
# consecutive day (cap 7), else reset to 1. Reward = max(3× cheapest building,
# 5 min of income × streak). Granted silently into balance; overlay flagged so the
# return screen can surface the streak.
func _apply_daily_reward() -> void:
	var today := Time.get_date_string_from_system()
	if last_login_date == today:
		return
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	if last_login_date == yesterday:
		daily_streak = mini(7, daily_streak + 1)
	else:
		daily_streak = 1
	last_login_date = today
	var cheapest: float = buildings[0].current_cost() if buildings.size() > 0 else 30.0
	var reward: float = maxf(cheapest * 3.0, income_per_second() * 300.0 * float(daily_streak))
	daily_reward = reward
	balance += reward
	lifetime_earnings += reward
	show_daily_overlay = true


func to_save_data() -> Dictionary:
	var owned: Array = []
	for b in buildings:
		owned.append(b.owned)
	var mgr: Array = []
	for m in managers:
		mgr.append(m.hired)
	var upg: Array = []
	for u in upgrades:
		upg.append(u.purchased)
	return {
		"balance": balance,
		"lifetime_earnings": lifetime_earnings,
		"prestige_tokens": prestige_tokens,
		"arms_influence_frac": arms_influence_frac,
		"prestige_count": prestige_count,
		"next_prestige_earnings": next_prestige_earnings,
		"click_count": click_count,
		"play_time": play_time,
		"heat": heat,
		"total_heat_generated": total_heat_generated,
		"influence": influence,
		"buildings": owned,
		"managers": mgr,
		"upgrades": upg,
		"territories": _TerritorySystem.territories_to_save(territories),
		"city_control_milestones": city_control_milestones.duplicate(),
		"total_territories_captured": total_territories_captured,
		"highest_city_control": highest_city_control,
		"total_rivals_defeated": total_rivals_defeated,
		"total_ops_completed": total_ops_completed,
		"peak_income": peak_income,
		"highest_cash_held": highest_cash_held,
		"total_buildings_purchased": total_buildings_purchased,
		"coins_caught": coins_caught,
		"promoter_heat_target": promoter_heat_target,
		"offline_gain": offline_gain,
		"achievements": _AchievementSystem.to_save(achievements),
		"rivals": _RivalSystem.rivals_to_save(rivals),
		"crew": crew,
		"operations": _OperationSystem.operations_to_save(operations),
		"perks_purchased": perks_purchased,
		"prestige_branch": prestige_branch if not prestige_branch.is_empty() else null,
		"collector_shield_cd": collector_shield_cd,
		"carl_emergency_used": carl_emergency_used,
		"mechanic_timer": mechanic_timer,
		"autobuy_timer": autobuy_timer,
		"goals_completed": _goals_completed_keys(),
		"last_login_date": last_login_date,
		"daily_streak": daily_streak,
		"tutorial_step": tutorial_step,
		"shown_raid_tutorial": shown_raid_tutorial,
		"shown_ops_tutorial": shown_ops_tutorial,
		"shown_influence_tutorial": shown_influence_tutorial,
		"shown_syndicate_tutorial": shown_syndicate_tutorial,
		"shown_crew_tutorial": shown_crew_tutorial,
		"shown_territory_tutorial": shown_territory_tutorial,
		"shown_rivals_tutorial": shown_rivals_tutorial,
		"shown_heat_warning": shown_heat_warning,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"mute_all": mute_all,
		"fps_cap": fps_cap,
		"show_particles": show_particles,
		"dragon_patron": dragon_patron if not dragon_patron.is_empty() else null,
		"dragon_xp": dragon_xp,
		"dragon_ability_cooldowns": dragon_ability_cooldowns.duplicate(),
		"dragon_red_elim_count": dragon_red_elim_count,
		"save_timestamp": Time.get_unix_time_from_system(),
		"godot_port": true,
	}


func _tick_building_specials(dt: float) -> void:
	if buildings.size() < 3:
		return
	var chop := buildings[2]
	if chop.owned > 0:
		chop.special_timer += dt
		if chop.special_timer >= 1.0:
			chop.special_timer -= 1.0
			if _rng.randf() < 0.08:
				var bonus := chop.income_per_second() * 2.0
				balance += bonus
				lifetime_earnings += bonus
	if buildings.size() > 3:
		# Betting Ring jackpot every 60–150s: 30s of the building's own income.
		var betting := buildings[3]
		if betting.owned > 0:
			betting.special_timer -= dt
			if betting.special_timer <= 0.0:
				var jackpot := betting.income_per_second() * 30.0
				balance += jackpot
				lifetime_earnings += jackpot
				notification.emit("Betting jackpot! +%s" % FormatUtil.format_money(jackpot), GameTheme.GOLD_BRIGHT)
				betting.special_timer = _rng.randf_range(60.0, 150.0)
	# Arms Broker: 0.1 Influence/hour per broker, accrued as a fraction.
	if buildings.size() > 9:
		var arms := buildings[9]
		if arms.owned > 0:
			arms_influence_frac += float(arms.owned) * (0.1 / 3600.0) * dt
			if arms_influence_frac >= 1.0:
				var whole := int(arms_influence_frac)
				prestige_tokens += whole
				arms_influence_frac -= float(whole)
				_mark_ips_dirty()


func _tick_loan_interest(dt: float) -> void:
	if buildings.size() <= 5:
		return
	var loan := buildings[5]
	if loan.owned <= 0:
		return
	# +0.05%/min balance per office, capped at 2 offices (matches src/buildings.py).
	var offices := mini(loan.owned, 2)
	var interest := balance * (0.0005 / 60.0) * float(offices) * dt
	if interest > 0.0:
		balance += interest
		lifetime_earnings += interest


func _buildings_reset_specials() -> void:
	for b in buildings:
		b.special_timer = 0.0


func perform_territory_action(index: int, action: String) -> String:
	var outcome: String = _TerritorySystem.perform_action(self, index, action, _rng)
	_mark_ips_dirty()
	stats_changed.emit()
	return outcome


func perform_rival_action(index: int, action: String) -> String:
	var outcome: String = _RivalSystem.perform_action(self, index, action, _rng)
	_mark_ips_dirty()
	stats_changed.emit()
	return outcome


func adjust_crew(role_key: String, delta: int) -> bool:
	if not _CrewSystem.adjust_assignment(self, role_key, delta):
		return false
	_mark_ips_dirty()
	stats_changed.emit()
	return true


func start_operation(index: int) -> String:
	var outcome: String = _OperationSystem.start_operation(self, index)
	_mark_ips_dirty()
	stats_changed.emit()
	return outcome


func collect_operation(index: int) -> String:
	var outcome: String = _OperationSystem.collect_operation(self, index, _rng)
	_mark_ips_dirty()
	stats_changed.emit()
	return outcome


func activate_dragon_ability(key: String) -> bool:
	if not _DragonSystem.activate_ability(self, key):
		return false
	_mark_ips_dirty()
	stats_changed.emit()
	return true


func _goals_completed_keys() -> Array:
	var out: Array = []
	for g in goals:
		if typeof(g) == TYPE_DICTIONARY and bool(g.get("completed", false)):
			out.append(str(g.get("key", "")))
	return out


func _tick_golden_coin(dt: float) -> void:
	if not golden_coin_active:
		golden_coin_timer -= dt
		if golden_coin_timer <= 0.0:
			_spawn_golden_coin()
		return
	golden_coin_lifetime += dt
	if _ManagerSystem.manager_active(self, "Lucky Sal"):
		if golden_coin_lifetime >= _ManagerSystem.sal_autocollect_delay(self):
			collect_golden_coin(true)
	elif golden_coin_lifetime >= _ManagerSystem.COIN_LIFETIME:
		golden_coin_active = false
		golden_coin_timer = _next_coin_timer()


func _spawn_golden_coin() -> void:
	golden_coin_active = true
	golden_coin_lifetime = 0.0


func _next_coin_timer() -> float:
	return _rng.randf_range(COIN_SPAWN_MIN, COIN_SPAWN_MAX)


func has_golden_coin() -> bool:
	return golden_coin_active


func collect_golden_coin(auto: bool = false) -> void:
	if not golden_coin_active:
		return
	golden_coin_active = false
	golden_coin_timer = _next_coin_timer()
	coins_caught += 1
	_play_sfx("coin")
	if auto:
		notification.emit("Sal caught a golden coin!", GameTheme.GOLD)
	var effects: Array[String] = ["frenzy", "lucky", "click_storm"]
	var effect: String = effects[_rng.randi() % effects.size()]
	match effect:
		"frenzy":
			_BuffSystem.add_buff(self, "frenzy", 15.0)
			notification.emit("FRENZY! 7× income for 15s", GameTheme.GOLD_BRIGHT)
		"lucky":
			var gain: float = minf(income_per_second() * 60.0, maxf(balance * 0.15, 1.0))
			balance += gain
			lifetime_earnings += gain
			notification.emit("Lucky! +%s" % FormatUtil.format_money(gain), GameTheme.GREEN)
		"click_storm":
			_BuffSystem.add_buff(self, "click_storm", 20.0)
			notification.emit("CLICK STORM! 10× clicks for 20s", GameTheme.GOLD_BRIGHT)
	_mark_ips_dirty()
	stats_changed.emit()


func dismiss_offline_overlay() -> void:
	show_offline_overlay = false
	show_daily_overlay = false


func show_elimination_overlay(name: String, flavor: String, rewards: String) -> void:
	elim_overlay_name = name
	elim_overlay_flavor = flavor
	elim_overlay_rewards = rewards
	elim_overlay_active = true
	elim_overlay_timer = 5.0
	_play_sfx("rival")
	stats_changed.emit()


func dismiss_elimination_overlay() -> void:
	elim_overlay_active = false
	elim_overlay_name = ""
	elim_overlay_flavor = ""
	elim_overlay_rewards = ""
	elim_overlay_timer = 0.0
	stats_changed.emit()


func reset_tutorial() -> void:
	tutorial_step = 0
	shown_crew_tutorial = false
	shown_ops_tutorial = false
	shown_territory_tutorial = false
	shown_rivals_tutorial = false
	shown_influence_tutorial = false
	shown_heat_warning = false
	shown_raid_tutorial = false
	shown_syndicate_tutorial = false
	stats_changed.emit()
