extends SceneTree
## Headless P14 UI telemetry probe — exercises tab/overlay/buy-mult events and writes JSONL.
##
## Usage:
##   godot --path godot --headless -s res://scripts/tools/telemetry_probe.gd -- --telemetry-probe
##   godot ... -- --telemetry-probe --output D:/2d_game/telemetry_probe.jsonl
##
## Not run from sim_godot_soak (telemetry stays disabled in normal headless soak).

const GAME_SCREEN := "res://scenes/game_screen.tscn"
const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _elapsed := 0.0
var _phase := 0
var _screen: Node
var _out_path := ""
var _telemetry: Node
var _game_state: Node


func _initialize() -> void:
	if not _has_flag("--telemetry-probe"):
		printerr("telemetry_probe: pass --telemetry-probe")
		quit(1)
		return
	SoakAutoloads.install(self)
	_telemetry = root.get_node("Telemetry") as Node
	_game_state = root.get_node("GameState") as Node
	_out_path = _arg_after("--output")
	if _out_path.is_empty():
		_out_path = "user://telemetry_probe.jsonl"
	_telemetry.configure_probe_sink(_out_path)
	var packed: PackedScene = load(GAME_SCREEN) as PackedScene
	if packed == null:
		printerr("telemetry_probe: failed to load game_screen")
		quit(1)
		return
	_screen = packed.instantiate()
	root.add_child(_screen)
	_game_state.balance = 1.0e12
	_game_state.lifetime_earnings = 1.0e12


func _process(delta: float) -> bool:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed >= 0.05:
				_screen._open_tab(_screen.Tab.UPGRS)
				_phase = 1
				_elapsed = 0.0
		1:
			if _elapsed >= 0.05:
				_screen._on_buy_mult_chip()
				_phase = 2
				_elapsed = 0.0
		2:
			if _elapsed >= 0.05:
				_screen._open_tab(_screen.Tab.CONFIG)
				_phase = 3
				_elapsed = 0.0
		3:
			if _elapsed >= 0.05:
				# P14 overlay queue: offline → daily dismiss must advance without UI click.
				_game_state.show_offline_overlay = true
				_game_state.show_daily_overlay = false
				_game_state.daily_reward = 250.0
				_game_state.dismiss_offline_overlay()
				var daily_pending: bool = _game_state.show_daily_overlay
				_game_state.dismiss_offline_overlay()
				var queue_ok: bool = daily_pending and not _game_state.show_daily_overlay
				_telemetry.log_event("ui_overlay_queue_ok", {"ok": queue_ok})
				_screen._open_tab(_screen.Tab.BLDGS)
				if _game_state.can_buy_building(0, 1):
					_game_state.buy_building(0, 1)
					var ms: int = _game_state.record_first_building_buy_ms()
					if ms >= 0:
						_telemetry.log_event("ui_first_building_buy_ms", {"ms": ms})
				_phase = 4
				_elapsed = 0.0
		4:
			if _elapsed >= 0.05:
				_telemetry.log_event("ui_overlay_shown", {"kind": "probe_offline"})
				_telemetry.log_event("ui_overlay_dismiss_ms", {"kind": "probe_offline", "ms": 1200})
				_game_state.tutorial_advanced.emit(1)
				_telemetry.log_event("ui_prestige_tree_open", {"eligible": false, "probe": true})
				_phase = 5
				_elapsed = 0.0
		5:
			if _elapsed >= 0.05:
				_telemetry.flush()
				var read_path := ProjectSettings.globalize_path(_telemetry.get_output_path())
				var kinds := _read_ui_event_kinds(read_path)
				var out := {
					"ok": kinds.size() >= 5,
					"ui_event_kinds": kinds.size(),
					"events": kinds,
					"output": read_path,
				}
				print(JSON.stringify(out))
				quit(0 if out["ok"] else 1)
	return false


func _read_ui_event_kinds(path: String) -> PackedStringArray:
	var kinds: Dictionary = {}
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedStringArray()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var name: String = str(parsed.get("ev", ""))
		if name.begins_with("ui_"):
			kinds[name] = true
	f.close()
	return PackedStringArray(kinds.keys())


func _has_flag(flag: String) -> bool:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		if flag in pack:
			return true
	return false


func _arg_after(flag: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return ""
