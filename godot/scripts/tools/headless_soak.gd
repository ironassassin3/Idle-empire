extends SceneTree
## Headless soak — load game_screen and run live sim + UI tick (ROADMAP P5 verify).
## Usage: godot --path godot --headless -s res://scripts/tools/headless_soak.gd [-- --seconds 60]

const DEFAULT_SECONDS := 60.0
const GAME_SCREEN := "res://scenes/game_screen.tscn"

# Project autoloads, in project.godot declaration order. Running a script via `-s`
# with a custom SceneTree main loop does NOT initialize project autoloads, so
# game_screen.gd (which depends on GameState/GameConfig/FormatUtil/etc.) would
# null-reference every frame and the soak would never reach quit(). Instantiate
# them manually before loading the scene.
const AUTOLOADS := [
	["GameConfig", "res://scripts/autoload/game_config.gd"],
	["FormatUtil", "res://scripts/autoload/format_util.gd"],
	["GameState", "res://scripts/autoload/game_state.gd"],
	["SaveManager", "res://scripts/autoload/save_manager.gd"],
	["AudioManager", "res://scripts/autoload/audio_manager.gd"],
]

var _elapsed := 0.0
var _target := DEFAULT_SECONDS


func _initialize() -> void:
	var arg := _arg_after("--seconds")
	_target = float(arg) if not arg.is_empty() else DEFAULT_SECONDS
	_install_autoloads()
	var packed: PackedScene = load(GAME_SCREEN) as PackedScene
	if packed == null:
		push_error("Failed to load %s" % GAME_SCREEN)
		quit(1)
		return
	root.add_child(packed.instantiate())


func _install_autoloads() -> void:
	for entry in AUTOLOADS:
		var node_name: String = entry[0]
		if root.has_node(NodePath(node_name)):
			continue
		var node: Node = (load(entry[1]) as GDScript).new()
		node.name = node_name
		root.add_child(node)
		# Bind the bare `GameState` / `GameConfig` identifiers for scripts compiled
		# against the project autoloads.
		Engine.register_singleton(node_name, node)


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed < _target:
		return false
	# Always quit after the target, even if state is missing — a soak harness must
	# never spin forever (that is what produced the multi-GB log).
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null:
		var audio: Node = root.get_node_or_null("AudioManager")
		var out := {
			"ok": true,
			"elapsed": _elapsed,
			"play_time": gs.play_time,
			"balance": gs.balance,
			"lifetime_earnings": gs.lifetime_earnings,
			"audio_enabled": audio.is_enabled() if audio != null else false,
		}
		print(JSON.stringify(out))
	else:
		printerr("soak: GameState autoload missing at exit — install failed")
	quit(0)
	return true


func _arg_after(flag: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for pack in [user_args, args]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return ""
