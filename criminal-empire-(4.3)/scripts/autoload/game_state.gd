extends Node
## Core simulation — mirrors PlayingState economy loop (MVP subset).

signal stats_changed
signal notification(message: String, color: Color)

var balance: float = 0.0
var lifetime_earnings: float = 0.0
var prestige_tokens: int = 0
var prestige_count: int = 0
var next_prestige_earnings: float = 0.0
var click_count: int = 0
var play_time: float = 0.0
var heat: float = 0.0

var buildings: Array[Building] = []
var managers_hired: Array[bool] = []

var _ips_dirty: bool = true
var _ips_cached: float = 0.0
var _autosave_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset_new_game()


func reset_new_game() -> void:
	buildings = BuildingDefs.make_buildings()
	managers_hired.resize(13)
	for i in managers_hired.size():
		managers_hired[i] = false
	balance = 0.0
	lifetime_earnings = 0.0
	prestige_tokens = 0
	prestige_count = 0
	next_prestige_earnings = 0.0
	click_count = 0
	play_time = 0.0
	heat = 0.0
	_mark_ips_dirty()
	stats_changed.emit()


func _process(delta: float) -> void:
	play_time += delta
	var passive := income_per_second * delta
	if is_finite(passive):
		balance += passive
		lifetime_earnings += passive
	_tick_building_specials(delta)
	_autosave_timer += delta
	if _autosave_timer >= GameConfig.AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		SaveManager.save_game()
	_mark_ips_dirty()
	stats_changed.emit()


func _mark_ips_dirty() -> void:
	_ips_dirty = true


func income_per_second() -> float:
	if not _ips_dirty:
		return _ips_cached
	BuildingDefs.sync_racket_multiplier(buildings)
	var global_mult := BuildingDefs.global_special_mult(buildings)
	var total := 0.0
	for i in buildings.size():
		var b := buildings[i]
		var base := b.base_income * b.owned * b.income_multiplier
		if i < managers_hired.size() and managers_hired[i]:
			base *= GameConfig.MANAGER_INCOME_MULT
		total += base
	_ips_cached = total * global_mult * Prestige.income_mult(prestige_tokens)
	_ips_dirty = false
	return _ips_cached


func click_value() -> float:
	var mult := Prestige.income_mult(prestige_tokens)
	var dealer_bonus := BuildingDefs.dealer_click_bonus(buildings)
	var ips_term := GameConfig.CLICK_IPS_FRACTION * income_per_second()
	return mult + dealer_bonus + ips_term


func do_click() -> float:
	click_count += 1
	var value := click_value()
	if _rng.randf() < GameConfig.CLICK_CRIT_CHANCE:
		value *= _rng.randf_range(GameConfig.CLICK_CRIT_MIN, GameConfig.CLICK_CRIT_MAX)
		notification.emit("Critical hit!", Color(1.0, 0.84, 0.35))
	balance += value
	lifetime_earnings += value
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
	BuildingDefs.sync_racket_multiplier(buildings)
	_mark_ips_dirty()
	stats_changed.emit()
	return true


func can_prestige() -> bool:
	return Prestige.can_prestige(self)


func do_prestige() -> bool:
	if not can_prestige():
		return false
	var gain := Prestige.calc_influence_gain(lifetime_earnings)
	prestige_tokens += gain
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
	_buildings_reset_specials()
	notification.emit("Prestige! +%d Influence" % gain, Color(0.92, 0.78, 0.48))
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


func apply_save_data(data: Dictionary) -> void:
	buildings = BuildingDefs.make_buildings()
	balance = float(data.get("balance", 0.0))
	lifetime_earnings = float(data.get("lifetime_earnings", 0.0))
	prestige_tokens = int(data.get("prestige_tokens", 0))
	prestige_count = int(data.get("prestige_count", 0))
	next_prestige_earnings = float(data.get("next_prestige_earnings", 0.0))
	click_count = int(data.get("click_count", 0))
	play_time = float(data.get("play_time", 0.0))
	heat = float(data.get("heat", 0.0))
	var owned: Array = data.get("buildings", [])
	for i in mini(owned.size(), buildings.size()):
		buildings[i].owned = int(owned[i])
	var mgr: Array = data.get("managers", [])
	managers_hired.resize(13)
	for i in managers_hired.size():
		managers_hired[i] = i < mgr.size() and bool(mgr[i])
	BuildingDefs.sync_racket_multiplier(buildings)
	_mark_ips_dirty()
	stats_changed.emit()


func to_save_data() -> Dictionary:
	var owned: Array = []
	for b in buildings:
		owned.append(b.owned)
	return {
		"balance": balance,
		"lifetime_earnings": lifetime_earnings,
		"prestige_tokens": prestige_tokens,
		"prestige_count": prestige_count,
		"next_prestige_earnings": next_prestige_earnings,
		"click_count": click_count,
		"play_time": play_time,
		"heat": heat,
		"buildings": owned,
		"managers": managers_hired,
		"save_timestamp": Time.get_unix_time_from_system(),
		"godot_port": true,
	}


func _tick_building_specials(dt: float) -> void:
	if buildings.size() < 3:
		return
	var chop := buildings[2]
	if chop.owned <= 0:
		return
	chop.special_timer += dt
	if chop.special_timer < 1.0:
		return
	chop.special_timer -= 1.0
	if _rng.randf() < 0.08:
		var bonus := chop.income_per_second() * 2.0
		balance += bonus
		lifetime_earnings += bonus


func _buildings_reset_specials() -> void:
	for b in buildings:
		b.special_timer = 0.0
