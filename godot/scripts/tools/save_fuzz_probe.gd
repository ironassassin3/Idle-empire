extends SceneTree
## Hostile-save boot probe: every one of these files goes through the exact path
## a launch takes — title preview, then load — and none of them may raise an
## engine error or leave the game unplayable.
##
## A save is the only attacker-free input that can still be arbitrary: a process
## killed mid-write, a half-synced file, a value that overflowed to infinity
## during play. If one of those can take the boot down, the game never opens
## again, which is the failure this probe exists to make impossible.
##
##   godot --headless --path godot -s res://scripts/tools/save_fuzz_probe.gd

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")

const SAVE := "user://save.json"
const BACKUP := "user://save.json.bak"
const BROKEN := "user://save.json.broken"

var _failed := false
var _sink: ErrorSink


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
		if samples.size() < 5:
			samples.append("%s:%d %s: %s %s" % [file, line, function, code, rationale])

	func drain() -> String:
		var out := "; ".join(samples)
		count = 0
		samples.clear()
		return out


func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	_sink = ErrorSink.new()
	OS.add_logger(_sink)
	call_deferred("_run")


func _cases() -> Array:
	var big_array := "["
	for i in 20000:
		big_array += "1,"
	big_array += "1]"
	var deep := ""
	for i in 200:
		deep += "["
	for i in 200:
		deep += "]"
	return [
		["empty file", ""],
		["whitespace", "   \n\t "],
		["truncated mid-key", '{"balance"'],
		["truncated mid-value", '{"balance": 12'],
		["truncated mid-array", '{"balance": 12, "buildings": [1, 2'],
		["nul bytes", '{"balance": 1}' + String.chr(0) + String.chr(0)],
		["json array", "[1, 2, 3]"],
		["json string", '"save"'],
		["json null", "null"],
		["json number", "42"],
		["no balance", '{"play_time": 10.0}'],
		["balance as string", '{"balance": "lots"}'],
		["balance as dict", '{"balance": {"a": 1}}'],
		["balance as array", '{"balance": [1]}'],
		["balance as bool", '{"balance": true}'],
		["balance null", '{"balance": null}'],
		["balance nan literal", '{"balance": NaN}'],
		["balance inf literal", '{"balance": Infinity}'],
		["balance overflow", '{"balance": 1e999}'],
		["balance huge", '{"balance": 1e308, "lifetime_earnings": 1e308}'],
		["balance negative", '{"balance": -1e12}'],
		["play_time negative", '{"balance": 1, "play_time": -99999}'],
		["timestamp in the future", '{"balance": 1, "timestamp": 99999999999}'],
		["timestamp as string", '{"balance": 1, "timestamp": "yesterday"}'],
		["buildings wrong type", '{"balance": 1, "buildings": "many"}'],
		["buildings mixed junk", '{"balance": 1, "buildings": ["a", {}, null, true, 1e999]}'],
		["buildings too many", '{"balance": 1, "buildings": ' + big_array + "}"],
		["buildings negative", '{"balance": 1, "buildings": [-5, -1e12]}'],
		["managers wrong type", '{"balance": 1, "managers": {"a": 1}}'],
		["upgrades junk", '{"balance": 1, "upgrades": [{}, "yes", 3]}'],
		["territories as string", '{"balance": 1, "territories": "all of them"}'],
		["territories junk rows", '{"balance": 1, "territories": [1, "x", null, {"owner": 5}]}'],
		["rivals as number", '{"balance": 1, "rivals": 7}'],
		["rivals junk rows", '{"balance": 1, "rivals": [null, 3, {"power": "strong"}]}'],
		["crew as array", '{"balance": 1, "crew": [1, 2, 3]}'],
		["crew junk values", '{"balance": 1, "crew": {"protection": "lots", "bogus": 3}}'],
		["operations junk", '{"balance": 1, "operations": ["running", 4]}'],
		["gambling as string", '{"balance": 1, "gambling": "spins"}'],
		["perks as string", '{"balance": 1, "perks_purchased": "kp_cashflow"}'],
		["perks mixed", '{"balance": 1, "perks_purchased": ["kp_cashflow", 5, null, {}]}'],
		["achievements as int", '{"balance": 1, "achievements": 3}'],
		["goals as dict", '{"balance": 1, "goals_completed": {"a": true}}'],
		["city milestones junk", '{"balance": 1, "city_control_milestones": [null, {}, 3]}'],
		["entitlements junk", '{"balance": 1, "entitlements": "remove_ads"}'],
		["dragon cooldowns junk",
			'{"balance": 1, "dragon_patron": "red", "dragon_ability_cooldowns": {"red_strike": "soon", "bogus": 1}}'],
		["dragon patron unknown", '{"balance": 1, "dragon_patron": 12345}'],
		["prestige branch unknown", '{"balance": 1, "prestige_branch": ["kingpin"]}'],
		["volumes out of range",
			'{"balance": 1, "master_volume": 1e9, "sfx_volume": -5, "music_volume": null}'],
		["ui scale absurd", '{"balance": 1, "ui_text_scale": 99999, "fps_cap": -3}'],
		["deep nesting", '{"balance": 1, "buildings": ' + deep + "}"],
		["control chars",
			'{"balance": 1, "last_login_date": "' + String.chr(1) + String.chr(2) + 'bad"}'],
		["unicode keys", '{"balance": 1, "ee": "x", "name": "Klondike"}'],
	]


func _run() -> void:
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	for case in _cases():
		var label: String = case[0]
		_clear()
		_write(SAVE, str(case[1]))
		# GameState builds the world at boot before anything reads a file; a
		# rejected save must leave that world intact, not an empty shell.
		gs.reset_new_game()
		_sink.drain()
		# Exactly what a launch does: title preview first, then Continue.
		saves.preview()
		saves.load_game()
		if _sink.count > 0:
			_fail("%s raised: %s" % [label, _sink.drain()])
		if not is_finite(float(gs.balance)):
			_fail("%s left balance non-finite" % label)
		if gs.buildings.size() == 0 or gs.territories.size() == 0 or gs.rivals.size() == 0:
			_fail("%s left the world empty" % label)
		# Still playable: the game has to keep running whatever it just read.
		gs._process(0.5)
		gs.do_click()
		gs.balance = 1.0e9
		if not gs.buy_building(0, 1):
			_fail("%s left the game unable to buy" % label)
		if not saves.save_game():
			_fail("%s left the game unable to save" % label)
		if _sink.count > 0:
			_fail("%s raised while recovering: %s" % [label, _sink.drain()])
	_clear()
	print("SAVE_FUZZ %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _clear() -> void:
	for path in [SAVE, BACKUP, BROKEN, "user://save.json.tmp", "user://save.json.bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _fail(message: String) -> void:
	_failed = true
	printerr("FAIL " + message)
