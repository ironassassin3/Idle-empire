extends SceneTree
## Randomised long-session soak: drives real player actions against the live
## shell and fails on any engine error, non-finite economy value, or a save that
## cannot round-trip through JSON. Written after a 20-minute device session
## crashed and left the build unable to reopen — idle-only soaks never touched
## the code paths a player actually walks.
##
##   godot --headless --path godot -s res://scripts/tools/chaos_soak.gd -- \
##       --steps 20000 --seed 1 [--dt 0.25]

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

# Loaded after the autoloads are installed, never preloaded: these scripts
# reference singletons, so compiling them too early poisons the script cache
# for the whole run (every later static call fails with "in base GDScript").
var PrestigeTree: GDScript
var DragonSystem: GDScript
var CrewSystem: GDScript

const TABS := ["bldgs", "upgrs", "mgrs", "turf", "stats"]
const TERRITORY_ACTIONS := ["attack", "bribe", "negotiate"]
const RIVAL_ACTIONS := ["attack", "bribe", "sabotage"]
const STEPS_PER_FRAME := 250
## Random play alone never leaves the first hour of the curve, so the deep-number
## paths (formatting, cost scaling, prestige math) go untested. --wealth walks the
## balance up by three orders of magnitude on a timer to reach them.
const WEALTH_EVERY := 1500
const SAMPLE_EVERY := 5000
const ROUNDTRIP_EVERY := 500


class ErrorSink:
	extends Logger
	var count := 0
	var samples: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		if samples.size() < 20:
			samples.append("%s:%d %s: %s %s" % [file, line, function, code, rationale])


var _gs: Node
var _rng := RandomNumberGenerator.new()
var _sink := ErrorSink.new()
var _steps := 20000
var _dt := 0.25
var _done := 0
var _failures: Array[String] = []
var _prestiges := 0
var _actions := 0
var _shell: Node
var _wealth := false
var _baseline_objects := 0
var _baseline_at := 0
var _events: Node
var _saves: Node
var _config: Node


func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	_steps = int(_arg("--steps", "20000"))
	_dt = float(_arg("--dt", "0.25"))
	_rng.seed = int(_arg("--seed", "1"))
	_wealth = _arg("--wealth", "0") == "1"
	OS.add_logger(_sink)
	SoakAutoloads.install(self)
	PrestigeTree = load("res://scripts/systems/prestige_tree.gd")
	DragonSystem = load("res://scripts/systems/dragon_system.gd")
	CrewSystem = load("res://scripts/systems/crew_system.gd")
	_gs = root.get_node("GameState")
	_events = root.get_node("UiEvents")
	_saves = root.get_node("SaveManager")
	_config = root.get_node("GameConfig")
	_gs.reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	if packed == null:
		printerr("[chaos] failed to load game_shell.tscn")
		quit(1)
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	_gs.set_simulation_active(true)
	print("[chaos] seed=%d steps=%d dt=%.2f wealth=%s" % [_rng.seed, _steps, _dt, str(_wealth)])


func _process(_delta: float) -> bool:
	for _i in STEPS_PER_FRAME:
		if _done >= _steps or _failures.size() >= 10:
			return _finish()
		_done += 1
		_gs._process(_dt)
		_act()
		if _wealth and _done % WEALTH_EVERY == 0:
			_gs.balance = _gs.balance * 1000.0 + 1.0e6
			_gs.lifetime_earnings = maxf(_gs.lifetime_earnings, _gs.balance)
		_check_invariants()
		if _done % ROUNDTRIP_EVERY == 0:
			_check_roundtrip()
		if _done % SAMPLE_EVERY == 0:
			_sample()
	return false


func _act() -> void:
	var roll := _rng.randi_range(0, 99)
	_actions += 1
	if roll < 20:
		_gs.do_click()
	elif roll < 38:
		var idx := _rng.randi_range(0, _gs.buildings.size() - 1)
		_gs.buy_building(idx, _gs.effective_buy_qty(idx))
	elif roll < 43:
		_gs.cycle_buy_mult()
	elif roll < 50:
		_gs.buy_upgrade(_rng.randi_range(0, _gs.upgrades.size() - 1))
	elif roll < 55:
		_gs.hire_manager(_rng.randi_range(0, _gs.managers.size() - 1))
	elif roll < 58:
		_gs.approve_manager_order()
	elif roll < 63:
		_gs.perform_territory_action(
			_rng.randi_range(0, _gs.territories.size() - 1),
			TERRITORY_ACTIONS[_rng.randi_range(0, TERRITORY_ACTIONS.size() - 1)])
	elif roll < 68:
		_gs.perform_rival_action(
			_rng.randi_range(0, _gs.rivals.size() - 1),
			RIVAL_ACTIONS[_rng.randi_range(0, RIVAL_ACTIONS.size() - 1)])
	elif roll < 72:
		var role: String = CrewSystem.ROLES[_rng.randi_range(0, CrewSystem.ROLES.size() - 1)][0]
		_gs.adjust_crew(role, 1 if _rng.randf() < 0.6 else -1)
	elif roll < 77:
		var op := _rng.randi_range(0, _gs.operations.size() - 1)
		if _rng.randf() < 0.5:
			_gs.start_operation(op)
		else:
			_gs.collect_operation(op)
	elif roll < 82:
		_gamble()
	elif roll < 85:
		var keys: Array = DragonSystem.ABILITIES.keys()
		_gs.activate_dragon_ability(str(keys[_rng.randi_range(0, keys.size() - 1)]))
	elif roll < 88:
		_gs.collect_golden_coin()
	elif roll < 91:
		_buy_perk()
	elif roll < 94:
		if _gs.can_prestige() and _gs.do_prestige():
			_prestiges += 1
			var branches: Array = PrestigeTree.BRANCH_PERKS.keys()
			_gs.select_prestige_branch(str(branches[_rng.randi_range(0, branches.size() - 1)]))
	elif roll < 96:
		_events.emit_signal("tab_requested", TABS[_rng.randi_range(0, TABS.size() - 1)])
	elif roll < 97:
		_gs.dismiss_offline_overlay()
	elif roll < 98:
		_saves.save_game()
	elif roll < 99:
		_gs.grant_free_golden_coin()
	else:
		_gs.set_simulation_active(_rng.randf() < 0.9)


func _gamble() -> void:
	if not _config.GAMBLING_ENABLED:
		return
	if _rng.randf() < 0.5:
		_gs.start_gamble_round()
		_gs.resolve_gamble(_rng.randf())
		return
	if not _gs.gambling_wager_enabled():
		return
	# Stakes a real player can produce from the wager UI, including the extremes.
	var stakes: Array = [0.0, 1.0, _gs.balance, _gs.balance * 0.5]
	var res: Dictionary = _gs.place_wager(float(stakes[_rng.randi_range(0, stakes.size() - 1)]))
	if not res.is_empty():
		_gs.notify_wager_result(res)


func _buy_perk() -> void:
	var keys: Array = []
	for branch in PrestigeTree.BRANCH_PERKS:
		for entry in PrestigeTree.BRANCH_PERKS[branch]:
			keys.append(entry[0])
	_gs.buy_prestige_perk(str(keys[_rng.randi_range(0, keys.size() - 1)]))


func _check_invariants() -> void:
	for field in ["balance", "lifetime_earnings", "heat", "play_time", "peak_income",
			"prestige_route_earnings", "highest_cash_held"]:
		var value: float = float(_gs.get(field))
		if not is_finite(value):
			_fail("%s is not finite (%s) after %d steps" % [field, str(value), _done])
	if not is_finite(_gs.income_per_second()):
		_fail("income_per_second is not finite after %d steps" % _done)
	if not is_finite(_gs.click_value()):
		_fail("click_value is not finite after %d steps" % _done)
	if _gs.heat < 0.0 or _gs.heat > 100.0:
		_fail("heat out of range: %f" % _gs.heat)
	if _gs.prestige_tokens < 0 or _gs.influence < 0:
		_fail("negative tokens/influence: %d / %d" % [_gs.prestige_tokens, _gs.influence])
	if _sink.count > 0:
		var joined := "; ".join(_sink.samples)
		_sink.count = 0
		_sink.samples.clear()
		_fail("engine error logged at step %d: %s" % [_done, joined])


## The save must always survive the exact path a returning player takes:
## stringify on quit, parse on launch. A NaN or INF anywhere in the state makes
## JSON.stringify emit a token that JSON.parse rejects, which is how a live save
## turns into "no save" — or worse, a half-applied one.
func _check_roundtrip() -> void:
	var first: Dictionary = _parse_or_fail(_gs.to_save_data())
	if first.is_empty():
		return
	# The first apply legitimately moves money (daily reward, offline return), so
	# the invariant is that a *reloaded* save is stable: load it twice and the
	# second load must change nothing.
	_gs.apply_save_data(first)
	var second: Dictionary = _parse_or_fail(_gs.to_save_data())
	if second.is_empty():
		return
	var before: float = float(_gs.balance)
	_gs.apply_save_data(second)
	var after: float = float(_gs.balance)
	if absf(after - before) > maxf(1.0, absf(before) * 0.001):
		_fail("reload is not stable at step %d: %f -> %f" % [_done, before, after])


func _parse_or_fail(data: Dictionary) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(JSON.stringify(data, "	")) != OK:
		_fail("save is not parseable JSON at step %d: %s" % [_done, parser.get_error_message()])
		return {}
	if not parser.data is Dictionary:
		_fail("save did not parse back to a Dictionary at step %d" % _done)
		return {}
	return parser.data


## A crash 20 minutes into a session is what started this work, and a leak is the
## one cause that looks exactly like that on a phone. Take a baseline once the
## shell has settled, then hold the rest of the run against it.
func _sample() -> void:
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("[chaos] SAMPLE " + JSON.stringify({
		"step": _done, "play_time": int(_gs.play_time), "objects": objects, "nodes": nodes,
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}))
	if _baseline_at == 0:
		_baseline_at = _done
		_baseline_objects = objects
	elif objects > int(_baseline_objects * 1.5) + 5000:
		_fail("object count grew from %d (step %d) to %d (step %d)" % [
			_baseline_objects, _baseline_at, objects, _done])


func _fail(message: String) -> void:
	if _failures.size() < 10:
		_failures.append(message)
		printerr("[chaos] FAIL " + message)


func _finish() -> bool:
	var summary := {
		"steps": _done, "actions": _actions, "prestiges": _prestiges,
		"play_time": _gs.play_time, "balance": _gs.balance,
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}
	print("[chaos] " + JSON.stringify(summary))
	print("[chaos] %s" % ("FAIL" if _failures.size() > 0 else "PASS"))
	quit(1 if _failures.size() > 0 else 0)
	return true


func _arg(flag: String, def: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return def
