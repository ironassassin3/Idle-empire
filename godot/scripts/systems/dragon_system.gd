class_name DragonSystem
extends RefCounted
## Dragon Patron — port of src/dragon.py (lifecycle, requests, abilities, passive effects).

const RED := "red"
const JADE := "jade"
const BLACK := "black"
const DRAGON_ORDER: Array[String] = [RED, JADE, BLACK]
const DRAGON_CHANGE_COST := 25

const EGG := "egg"
const HATCHLING := "hatchling"
const YOUNG := "young"
const ADULT := "adult"
const ANCIENT := "ancient"
const STAGE_ORDER: Array[String] = [EGG, HATCHLING, YOUNG, ADULT, ANCIENT]

const STAGE_XP := {
	EGG: 0,
	HATCHLING: 25,
	YOUNG: 100,
	ADULT: 300,
	ANCIENT: 750,
}

const STAGE_LABELS := {
	EGG: "Egg",
	HATCHLING: "Hatchling",
	YOUNG: "Young Dragon",
	ADULT: "Adult Dragon",
	ANCIENT: "Ancient Dragon",
}

const _STAGE_PASSIVE_MULT := {
	EGG: 1.0,
	HATCHLING: 1.0,
	YOUNG: 1.0,
	ADULT: 1.10,
	ANCIENT: 1.25,
}

const MOOD_PLEASED := "pleased"
const MOOD_HUNGRY := "hungry"
const MOOD_RESTLESS := "restless"
const MOOD_AWAKENING := "awakening"

const MOOD_COLORS := {
	MOOD_PLEASED: Color(0.31, 0.78, 0.47),
	MOOD_HUNGRY: Color(0.86, 0.59, 0.24),
	MOOD_RESTLESS: Color(0.63, 0.51, 0.71),
	MOOD_AWAKENING: Color(0.94, 0.82, 0.31),
}

const MOOD_LABELS := {
	MOOD_PLEASED: "Pleased",
	MOOD_HUNGRY: "Waiting",
	MOOD_RESTLESS: "Restless",
	MOOD_AWAKENING: "Awakening",
}

const DRAGON_META := {
	RED: {
		"name": "Crimson Tide",
		"title": "Red Dragon",
		"color": Color(0.86, 0.31, 0.24),
		"tag": "Aggression & Territory",
		"blurb": "Rival pressure drives your empire. More enemies means more power.",
		"strengths": [
			"Each active rival: +3% income (max +15%)",
			"Territory attack/sabotage: +15% success",
			"+4% income per rival eliminated this run",
			"Heat ≥75: raids may counterattack the rival",
		],
		"costs": [
			"Heat decay: −0.04/s slower",
			"All rival aggression: +20%",
			"Raid damage: +10% worse",
		],
	},
	JADE: {
		"name": "Jade Serpent",
		"title": "Jade Dragon",
		"color": Color(0.31, 0.78, 0.55),
		"tag": "Patience & Corruption",
		"blurb": "You own the system. Stability is your weapon.",
		"strengths": [
			"+30% Influence gained at every prestige",
			"Negotiate/Bribe in territory: +40% success",
			"Each district owned: −0.025/s heat",
			"8% chance per AI tick rivals de-escalate",
		],
		"costs": [
			"Territory attack/sabotage: −20% success",
			"Operations rewards: −15%",
			"Raid cash loss: +20% worse",
		],
	},
	BLACK: {
		"name": "Iron Scale",
		"title": "Black Dragon",
		"color": Color(0.47, 0.55, 0.78),
		"tag": "Efficiency & Operations",
		"blurb": "Every resource is optimized. The machine never sleeps.",
		"strengths": [
			"Crew capacity: +25% more slots",
			"Collection crew: ×1.5 income per unit",
			"Each running operation: +0.5% income",
			"Ops within 90s of last: +35% reward",
		],
		"costs": [
			"All territory actions: −15% success",
			"Rival growth rate: +15% faster",
			"Operations heat gain: +25% more",
		],
	},
}

const _EVOLUTION_LINES := {
	RED: {
		HATCHLING: "The flame kindles. It is hungry.",
		YOUNG: "Growing teeth. Growing hunger. You will feed it well.",
		ADULT: "The Crimson Tide rises. Your enemies will break.",
		ANCIENT: "Ancient fire. Ancient rage. All who stand against you shall burn.",
	},
	JADE: {
		HATCHLING: "The serpent stirs. It watches everything.",
		YOUNG: "It learns. It remembers. It waits.",
		ADULT: "The Jade Serpent coils through your empire. None see it coming.",
		ANCIENT: "Ancient patience. Ancient power. The board was yours before they sat down.",
	},
	BLACK: {
		HATCHLING: "The forge ignites. Precision takes shape.",
		YOUNG: "Efficiency compounds. The machine learns its master.",
		ADULT: "Iron will. Iron scale. Nothing is wasted, nothing undone.",
		ANCIENT: "The Ancient Forge. Your empire runs like clockwork. Like fate.",
	},
}

# key -> [dragon, title, goal_text, xp, reaction, faction_req or ""]
const _REQUEST_DEFS: Array = [
	["red_blood", RED, "I hunger. Show me blood.", "Eliminate 1 rival", 15, "The Crimson Tide swells. More.", ""],
	["red_expand", RED, "Expand. Every inch is mine to burn.", "Capture 2 territories", 12, "Good. The map bleeds red.", ""],
	["red_edge", RED, "Push them to the edge. Push yourself.", "Reach Heat 70+", 10, "Yes. Let them fear what you become.", ""],
	["red_dominate", RED, "Five districts. Show me your reach.", "Own 5+ territories simultaneously", 14, "This is how empires are born.", ""],
	["red_war", RED, "Two rivals must fall. Show no mercy.", "Eliminate 2 rivals", 20, "The Crimson Tide is satisfied. For now.", ""],
	["jade_web", JADE, "Tighten the web. Control more.", "Own 4 territories", 12, "Good. Control is earned, not seized.", ""],
	["jade_influence", JADE, "Gain me influence. Corrupt the system.", "Gain 15 Respect", 15, "The system bends. As it always does.", ""],
	["jade_cool", JADE, "Stay cold. Control your heat. Show restraint.", "Keep Heat below 30", 10, "Restraint is its own weapon.", ""],
	["jade_thread", JADE, "Expand through guile. Capture three districts.", "Capture 3 territories", 18, "Silk is stronger than steel.", ""],
	["jade_elder", JADE, "You must prestige. Show me your growth.", "Prestige 3 times total", 25, "Now you see what patience builds.", ""],
	["iron_ops", BLACK, "Run three operations. Show me efficiency.", "Complete 3 operations", 15, "The machine does not sleep.", ""],
	["iron_chain", BLACK, "Link your operations. Chain two completions.", "Collect 2 ops within 90 seconds of each other", 18, "That is the rhythm I demand.", ""],
	["iron_deploy", BLACK, "Deploy everything. Maximum efficiency.", "Have all 5 ops active simultaneously", 20, "Full deployment. As it should be.", ""],
	["iron_crew", BLACK, "Staff your collection crews. Maximize output.", "Have 5+ crew in Collection", 12, "Every hand employed. Good.", ""],
	["iron_grind", BLACK, "Complete five operations without pause.", "Complete 5 operations", 22, "Iron will. Iron results.", ""],
	["red_blackwater", RED, "The Blackwater Mob guards the harbor. Crush them and take the docks.", "Eliminate the Blackwater Mob", 22, "The harbor runs red. Good.", "blackwater"],
	["red_crimson", RED, "The Crimson Kings think they own the streets. Prove them wrong.", "Eliminate the Crimson Kings", 20, "One fire burns in this city. Yours.", "crimson_kings"],
	["jade_blackwater", JADE, "The Blackwater Mob values loyalty over war. Negotiate — they can be useful.", "Negotiate with 2 rivals", 18, "Patience and sea-craft. Both serve the Jade Serpent.", "blackwater"],
	["jade_silver", JADE, "The Silver Hand understands power. Thread carefully through their web.", "Keep Heat below 25", 15, "Silk moves through water unseen. As do you.", "silver_hand"],
	["iron_ironunion", BLACK, "The Iron Union controls your freight lanes. Dominate their industrial districts.", "Own 3 industrial territories", 20, "Their machine yields to a better one.", "iron_union"],
	["iron_blackwater", BLACK, "The Blackwater Mob runs your shipping lanes. Take their routes. Take their docks.", "Own 2 waterfront/industrial districts", 18, "The freight is ours. The sea bows to iron.", "blackwater"],
]

const ABILITIES := {
	"red_strike": [RED, HATCHLING, "Dragon Strike", "Weaken the strongest rival by 20 power.", 120.0],
	"red_rage": [RED, YOUNG, "Dragon Rage", "+50% territory attack success for 30s.", 600.0],
	"jade_press": [JADE, HATCHLING, "Political Pressure", "Next territory action guaranteed to succeed.", 300.0],
	"jade_couns": [JADE, YOUNG, "Dragon's Counsel", "Instantly gain +5 Respect.", 900.0],
	"iron_drop": [BLACK, HATCHLING, "Supply Drop", "Complete the longest-running operation instantly.", 480.0],
	"iron_logis": [BLACK, YOUNG, "Dragon Logistics", "All active ops run at 2× speed for 60s.", 720.0],
}

const _HarborNames := ["Waterfront", "Rail Yards", "Machine Quarter", "Warehouse Row"]

static var _req_lookup: Dictionary = {}


static func _req_by_key() -> Dictionary:
	if _req_lookup.is_empty():
		for entry in _REQUEST_DEFS:
			_req_lookup[entry[0]] = entry
	return _req_lookup


static func active_dragon(state) -> String:
	var key: String = str(state.dragon_patron)
	return key if key in DRAGON_META else ""


static func has_dragon(state, key: String) -> bool:
	return active_dragon(state) == key


static func dragon_unlocked(state) -> bool:
	return state.prestige_count >= 1


static func get_stage(state) -> String:
	var xp: int = int(state.dragon_xp)
	var stage: String = EGG
	for s in STAGE_ORDER:
		if xp >= int(STAGE_XP[s]):
			stage = s
	return stage


static func stage_xp_progress(state) -> Dictionary:
	var xp: int = int(state.dragon_xp)
	var stg: String = get_stage(state)
	var idx: int = STAGE_ORDER.find(stg)
	if idx >= STAGE_ORDER.size() - 1:
		return {"progress": xp - int(STAGE_XP[ANCIENT]), "needed": 0, "next": ANCIENT}
	var curr_req: int = int(STAGE_XP[stg])
	var next_req: int = int(STAGE_XP[STAGE_ORDER[idx + 1]])
	return {
		"progress": xp - curr_req,
		"needed": next_req - curr_req,
		"next": STAGE_ORDER[idx + 1],
	}


static func _passive_mult(state) -> float:
	return float(_STAGE_PASSIVE_MULT.get(get_stage(state), 1.0))


static func get_mood(state) -> String:
	if active_dragon(state).is_empty():
		return MOOD_PLEASED
	var prog: Dictionary = stage_xp_progress(state)
	var needed: int = int(prog.get("needed", 0))
	if needed > 0 and float(prog.get("progress", 0)) / float(needed) >= 0.90:
		return MOOD_AWAKENING
	if not str(state.dragon_request_key).is_empty():
		return MOOD_HUNGRY
	if float(state.dragon_mood_timer) > 300.0:
		return MOOD_RESTLESS
	return MOOD_PLEASED


static func add_dragon_xp(state, amount: int) -> void:
	if active_dragon(state).is_empty():
		return
	var old_stage: String = get_stage(state)
	state.dragon_xp = int(state.dragon_xp) + maxi(0, amount)
	var new_stage: String = get_stage(state)
	if new_stage != old_stage:
		_on_evolution(state, old_stage, new_stage)


static func _on_evolution(state, old_stage: String, new_stage: String) -> void:
	var patron: String = active_dragon(state)
	if patron.is_empty():
		return
	var meta: Dictionary = DRAGON_META[patron]
	var line: String = str(_EVOLUTION_LINES.get(patron, {}).get(new_stage, "Your dragon has grown."))
	var label: String = str(STAGE_LABELS[new_stage])
	var new_ab_line := "Passive bonuses enhanced."
	for key in get_available_abilities(state):
		var ab: Array = ABILITIES[key]
		if STAGE_ORDER.find(str(ab[1])) == STAGE_ORDER.find(new_stage):
			new_ab_line = "Ability unlocked: %s." % ab[2]
			break
	state.milestone_queue.append(
		"%s: %s\n%s\n%s" % [meta.get("title", patron).to_upper(), label.to_upper(), line, new_ab_line]
	)
	if float(state.milestone_timer) <= 0.0:
		state.milestone_timer = 8.0
	state.dragon_mood_timer = 0.0
	state.notification.emit("Dragon evolved: %s!" % label, meta.get("color", GameTheme.GOLD))


static func get_active_request(state) -> Dictionary:
	var key: String = str(state.dragon_request_key)
	var lookup: Dictionary = _req_by_key()
	if key.is_empty() or not lookup.has(key):
		return {}
	var entry: Array = lookup[key]
	return {
		"key": entry[0],
		"dragon": entry[1],
		"title": entry[2],
		"goal": entry[3],
		"xp": entry[4],
		"reaction": entry[5],
	}


static func _terr_owned(state) -> int:
	var count := 0
	for t in state.territories:
		if typeof(t) == TYPE_DICTIONARY and str(t.get("owner", "")) == "player":
			count += 1
	return count


static func _industrial_owned(state) -> int:
	var count := 0
	for t in state.territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "")) != "player" or not bool(t.get("unlocked", false)):
			continue
		if str(t.get("district_type", "")) == "industrial":
			count += 1
	return count


static func _harbor_owned(state) -> int:
	var count := 0
	for t in state.territories:
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "")) != "player" or not bool(t.get("unlocked", false)):
			continue
		var dtype: String = str(t.get("district_type", ""))
		var tname: String = str(t.get("name", ""))
		if dtype == "industrial" or tname in _HarborNames:
			count += 1
	return count


static func _rival_elim_by_key(state, faction_key: String) -> bool:
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("faction_key", "")) == faction_key:
			return str(r.get("status", "")) == "Eliminated"
	return false


static func _request_met(state, key: String, snap: Dictionary) -> bool:
	match key:
		"red_blood":
			return state.total_rivals_defeated > int(snap.get("rivals_elim", 0))
		"red_expand":
			return _terr_owned(state) >= int(snap.get("territories", 0)) + 2
		"red_edge":
			return state.heat >= 70.0
		"red_dominate":
			return _terr_owned(state) >= 5
		"red_war":
			return state.total_rivals_defeated >= int(snap.get("rivals_elim", 0)) + 2
		"jade_web":
			return _terr_owned(state) >= 4
		"jade_influence":
			return state.influence >= int(snap.get("influence", 0)) + 15
		"jade_cool":
			return state.heat < 30.0
		"jade_thread":
			return _terr_owned(state) >= int(snap.get("territories", 0)) + 3
		"jade_elder":
			return state.prestige_count >= 3
		"iron_ops":
			return state.total_ops_completed > int(snap.get("ops_completed", 0)) + 2
		"iron_chain":
			return op_combo_mult(state) > 1.0
		"iron_deploy":
			var running := 0
			for op in state.operations:
				if typeof(op) == TYPE_DICTIONARY and bool(op.get("active", false)) and not bool(op.get("collected", false)):
					running += 1
			return running >= 5
		"iron_crew":
			return int(state.crew.get("collection", 0)) >= 5
		"iron_grind":
			return state.total_ops_completed >= int(snap.get("ops_completed", 0)) + 5
		"red_blackwater":
			return _rival_elim_by_key(state, "blackwater")
		"red_crimson":
			return _rival_elim_by_key(state, "crimson_kings")
		"jade_blackwater":
			return state.total_rivals_defeated <= int(snap.get("rivals_elim", 0))
		"jade_silver":
			return state.heat < 25.0
		"iron_ironunion":
			return _industrial_owned(state) >= 3
		"iron_blackwater":
			return _harbor_owned(state) >= 2
	return false


static func _make_snapshot(state) -> Dictionary:
	return {
		"territories": _terr_owned(state),
		"rivals_elim": state.total_rivals_defeated,
		"ops_completed": state.total_ops_completed,
		"influence": state.influence,
	}


static func _active_rival_faction_keys(state) -> Array:
	var out: Array = []
	for r in state.rivals:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if str(r.get("status", "")) == "Eliminated":
			continue
		var fk: String = str(r.get("faction_key", ""))
		if not fk.is_empty():
			out.append(fk)
	return out


static func _issue_new_request(state, rng: RandomNumberGenerator) -> void:
	var patron: String = active_dragon(state)
	if patron.is_empty():
		return
	var active_factions: Array = _active_rival_faction_keys(state)
	var pool: Array = []
	for entry in _REQUEST_DEFS:
		if entry[1] != patron:
			continue
		var faction_req: String = str(entry[6])
		if faction_req.is_empty():
			pool.append(entry)
		elif faction_req in active_factions:
			pool.append(entry)
	if pool.is_empty():
		for entry in _REQUEST_DEFS:
			if entry[1] == patron and str(entry[6]).is_empty():
				pool.append(entry)
	var recent: Array = state.dragon_recent_requests
	var available: Array = []
	for entry in pool:
		var rk: String = str(entry[0])
		if recent.size() >= 2 and rk in recent.slice(recent.size() - 2):
			continue
		available.append(entry)
	if available.is_empty():
		available = pool
	if available.is_empty():
		return
	var chosen: Array = available[rng.randi_range(0, available.size() - 1)]
	state.dragon_request_key = str(chosen[0])
	state.dragon_req_snapshot = _make_snapshot(state)
	var meta: Dictionary = DRAGON_META[patron]
	state.notification.emit("%s: %s" % [meta.get("title", ""), chosen[2]], meta.get("color", GameTheme.GOLD))


static func _complete_request(state, entry: Array) -> void:
	add_dragon_xp(state, int(entry[4]))
	var recent: Array = state.dragon_recent_requests.duplicate()
	recent.append(str(entry[0]))
	state.dragon_recent_requests = recent.slice(maxi(0, recent.size() - 6))
	state.dragon_request_key = ""
	state.dragon_req_snapshot = {}
	state.dragon_request_cooldown = 90.0
	state.dragon_mood_timer = 0.0
	var dragon_key: String = str(entry[1])
	state.notification.emit(str(entry[5]), DRAGON_META[dragon_key].get("color", GameTheme.GOLD))


static func get_available_abilities(state) -> Array[String]:
	var patron: String = active_dragon(state)
	if patron.is_empty():
		return []
	var stage_idx: int = STAGE_ORDER.find(get_stage(state))
	var out: Array[String] = []
	for key in ABILITIES.keys():
		var ab: Array = ABILITIES[key]
		if str(ab[0]) != patron:
			continue
		if STAGE_ORDER.find(str(ab[1])) <= stage_idx:
			out.append(str(key))
	return out


static func ability_cooldown_remaining(state, key: String) -> float:
	return float(state.dragon_ability_cooldowns.get(key, 0.0))


static func activate_ability(state, key: String) -> bool:
	if not ABILITIES.has(key):
		return false
	var ab: Array = ABILITIES[key]
	if not has_dragon(state, str(ab[0])):
		return false
	if key not in get_available_abilities(state):
		return false
	if ability_cooldown_remaining(state, key) > 0.0:
		return false
	match key:
		"red_strike":
			_fx_red_strike(state)
		"red_rage":
			state.dragon_rage_timer = 30.0
		"jade_press":
			state.dragon_guaranteed_territory = true
		"jade_couns":
			state.influence += 5
			state.prestige_tokens += 5
		"iron_drop":
			_fx_iron_drop(state)
		"iron_logis":
			_fx_iron_logistics(state)
	if not state.dragon_ability_cooldowns is Dictionary:
		state.dragon_ability_cooldowns = {}
	state.dragon_ability_cooldowns[key] = float(ab[4])
	state.dragon_mood_timer = 0.0
	var patron: String = active_dragon(state)
	state.notification.emit("%s!" % ab[2], DRAGON_META[patron].get("color", GameTheme.GOLD))
	return true


static func _fx_red_strike(state) -> void:
	var active: Array = []
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			active.append(r)
	if active.is_empty():
		return
	active.sort_custom(func(a, b): return int(a.get("power", 0)) > int(b.get("power", 0)))
	var target: Dictionary = active[0]
	target["power"] = maxi(0, int(target.get("power", 0)) - 20)
	if int(target.get("power", 0)) < 10:
		target["status"] = "Weakened"
	state.notification.emit(
		"Dragon Strike hit %s! (-20 power)" % target.get("name", "?"),
		DRAGON_META[RED].get("color", GameTheme.RED),
	)


static func _fx_iron_drop(state) -> void:
	var running: Array = []
	for op in state.operations:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		if bool(op.get("active", false)) and not bool(op.get("collected", false)):
			running.append(op)
	if running.is_empty():
		return
	running.sort_custom(func(a, b): return float(a.get("start_play_time", 0.0)) < float(b.get("start_play_time", 0.0)))
	var target: Dictionary = running[0]
	var dur: float = float(target.get("duration", 0.0)) * float(target.get("speed_mult", 1.0))
	target["start_play_time"] = state.play_time - dur
	state.notification.emit(
		"Supply Drop: %s complete!" % target.get("name", "?"),
		DRAGON_META[BLACK].get("color", GameTheme.BLUE_BRIGHT),
	)


static func _fx_iron_logistics(state) -> void:
	state.dragon_logistics_timer = 60.0
	for op in state.operations:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		if not bool(op.get("active", false)) or bool(op.get("collected", false)):
			continue
		var dur: float = float(op.get("duration", 0.0)) * float(op.get("speed_mult", 1.0))
		var elapsed: float = maxf(0.0, state.play_time - float(op.get("start_play_time", 0.0)))
		var remaining: float = maxf(0.0, dur - elapsed)
		if remaining > 0.0:
			op["start_play_time"] = float(op.get("start_play_time", 0.0)) - remaining * 0.5
	state.notification.emit("Dragon Logistics: all ops at 2× speed!", DRAGON_META[BLACK].get("color", GameTheme.BLUE_BRIGHT))


static func dragon_logistics_active(state) -> bool:
	return float(state.dragon_logistics_timer) > 0.0


static func dragon_rage_active(state) -> bool:
	return has_dragon(state, RED) and float(state.dragon_rage_timer) > 0.0


static func consume_guaranteed_territory(state) -> bool:
	if not state.dragon_guaranteed_territory:
		return false
	state.dragon_guaranteed_territory = false
	return true


static func dragon_update(state, dt: float, rng: RandomNumberGenerator) -> void:
	var patron: String = active_dragon(state)
	if patron.is_empty():
		return
	var cds: Dictionary = state.dragon_ability_cooldowns if state.dragon_ability_cooldowns is Dictionary else {}
	for k in cds.keys():
		cds[k] = maxf(0.0, float(cds[k]) - dt)
	state.dragon_ability_cooldowns = cds
	if float(state.dragon_rage_timer) > 0.0:
		state.dragon_rage_timer = maxf(0.0, float(state.dragon_rage_timer) - dt)
	if float(state.dragon_logistics_timer) > 0.0:
		state.dragon_logistics_timer = maxf(0.0, float(state.dragon_logistics_timer) - dt)
	state.dragon_mood_timer = float(state.dragon_mood_timer) + dt
	if float(state.dragon_request_cooldown) > 0.0:
		state.dragon_request_cooldown = maxf(0.0, float(state.dragon_request_cooldown) - dt)
	var req: Dictionary = get_active_request(state)
	if not req.is_empty():
		var entry: Array = _req_by_key().get(req.get("key", ""), [])
		if not entry.is_empty() and _request_met(state, str(entry[0]), state.dragon_req_snapshot):
			_complete_request(state, entry)
	elif str(state.dragon_request_key).is_empty() and float(state.dragon_request_cooldown) <= 0.0:
		_issue_new_request(state, rng)
		state.dragon_request_cooldown = 999.0


static func rival_presence_income_mult(state) -> float:
	if not has_dragon(state, RED):
		return 1.0
	var active := 0
	for r in state.rivals:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("status", "")) != "Eliminated":
			active += 1
	var base: float = 1.0 + minf(0.15, float(active) * 0.03)
	return 1.0 + (base - 1.0) * _passive_mult(state)


static func eliminated_rival_income_mult(state) -> float:
	if not has_dragon(state, RED):
		return 1.0
	var count: int = int(state.dragon_red_elim_count)
	var base: float = 1.0 + minf(0.20, float(count) * 0.04)
	return 1.0 + (base - 1.0) * _passive_mult(state)


static func active_ops_income_bonus(state) -> float:
	if not has_dragon(state, BLACK):
		return 0.0
	var running := 0
	for op in state.operations:
		if typeof(op) == TYPE_DICTIONARY and bool(op.get("active", false)) and not bool(op.get("collected", false)):
			running += 1
	return minf(0.025, float(running) * 0.005) * _passive_mult(state)


static func rival_aggression_mult(state) -> float:
	return 1.20 if has_dragon(state, RED) else 1.0


static func raid_damage_mult(state) -> float:
	if has_dragon(state, RED):
		return 1.10
	if has_dragon(state, JADE):
		return 1.20
	return 1.0


static func rival_growth_mult(state) -> float:
	return 1.15 if has_dragon(state, BLACK) else 1.0


static func territory_action_modifier(state, action_type: String) -> float:
	var bonus := 0.0
	if action_type in ["attack", "sabotage"]:
		if has_dragon(state, RED):
			bonus += 0.15
			if dragon_rage_active(state):
				bonus += 0.50
		if has_dragon(state, JADE):
			bonus -= 0.20
	elif action_type in ["negotiate", "bribe"]:
		if has_dragon(state, JADE):
			bonus += 0.40 * _passive_mult(state)
	if has_dragon(state, BLACK):
		bonus -= 0.15
	return bonus


static func heat_decay_bonus(state) -> float:
	if not has_dragon(state, JADE):
		return 0.0
	var owned := 0
	for t in state.territories:
		if typeof(t) == TYPE_DICTIONARY and str(t.get("owner", "")) == "player":
			owned += 1
	return minf(0.25, float(owned) * 0.025) * _passive_mult(state)


static func heat_decay_penalty(state) -> float:
	return 0.04 if has_dragon(state, RED) else 0.0


static func op_reward_mult(state) -> float:
	var mult := 1.0
	if has_dragon(state, JADE):
		mult *= 0.85
	if has_dragon(state, BLACK):
		mult *= op_combo_mult(state)
	return mult


static func op_combo_mult(state) -> float:
	if not has_dragon(state, BLACK):
		return 1.0
	var last: float = float(state.dragon_black_last_op_time)
	if last < 0.0:
		return 1.0
	return 1.35 if (state.play_time - last) <= 90.0 else 1.0


static func op_heat_gain_mult(state) -> float:
	return 1.25 if has_dragon(state, BLACK) else 1.0


static func crew_capacity_mult(state) -> float:
	return 1.25 if has_dragon(state, BLACK) else 1.0


static func collection_efficiency_mult(state) -> float:
	return 1.50 * _passive_mult(state) if has_dragon(state, BLACK) else 1.0


static func prestige_influence_mult(state) -> float:
	if not has_dragon(state, JADE):
		return 1.0
	return 1.30 * _passive_mult(state)


static func try_counterattack(state, rival: Dictionary) -> bool:
	if not has_dragon(state, RED) or state.heat < 75.0:
		return false
	rival["power"] = maxi(0, int(rival.get("power", 0)) - 15)
	if int(rival.get("power", 0)) < 10:
		rival["status"] = "Weakened"
	return true


static func try_jade_de_escalate(state, rng: RandomNumberGenerator) -> Array[String]:
	if not has_dragon(state, JADE) or rng.randf() >= 0.08:
		return []
	var candidates: Array = []
	for r in state.rivals:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if str(r.get("status", "")) == "Eliminated":
			continue
		if bool(r.get("at_war", false)) or float(r.get("aggression", 0.0)) > 0.35:
			candidates.append(r)
	if candidates.is_empty():
		return []
	var r: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	r["at_war"] = false
	r["aggression"] = maxf(0.10, float(r.get("aggression", 0.5)) - 0.08)
	var name: String = str(r.get("name", "?"))
	return ["Jade Serpent whispered — %s backed down." % name]


static func on_rival_eliminated(state, _rival) -> void:
	if active_dragon(state).is_empty():
		return
	if has_dragon(state, RED):
		state.dragon_red_elim_count = int(state.dragon_red_elim_count) + 1
	add_dragon_xp(state, 3 if has_dragon(state, RED) else 1)


static func on_op_collected(state) -> void:
	if has_dragon(state, BLACK):
		state.dragon_black_last_op_time = state.play_time
	add_dragon_xp(state, 2 if has_dragon(state, BLACK) else 1)


static func on_territory_captured(state) -> void:
	add_dragon_xp(state, 2 if has_dragon(state, JADE) else 1)


static func on_prestige(state) -> void:
	add_dragon_xp(state, 25)


static func reset_for_prestige(state) -> void:
	state.dragon_red_elim_count = 0
	state.dragon_black_last_op_time = -1.0
	state.dragon_request_key = ""
	state.dragon_req_snapshot = {}
	state.dragon_request_cooldown = 30.0


static func select_dragon(state, key: String) -> Dictionary:
	if key not in DRAGON_META:
		return {"ok": false, "message": "Unknown patron"}
	if not dragon_unlocked(state):
		return {"ok": false, "message": "Complete your first prestige first"}
	var current: String = active_dragon(state)
	if current == key:
		return {"ok": false, "message": "Already your patron"}
	if not current.is_empty():
		if state.prestige_tokens < DRAGON_CHANGE_COST:
			return {"ok": false, "message": "Switching costs %d Influence" % DRAGON_CHANGE_COST}
		state.prestige_tokens -= DRAGON_CHANGE_COST
	state.dragon_patron = key
	state.dragon_request_key = ""
	state.dragon_req_snapshot = {}
	state.dragon_request_cooldown = 10.0
	return {"ok": true, "message": ""}


static func reset_runtime(state) -> void:
	state.dragon_red_elim_count = 0
	state.dragon_black_last_op_time = -1.0
	state.dragon_rage_timer = 0.0
	state.dragon_logistics_timer = 0.0
	state.dragon_guaranteed_territory = false
