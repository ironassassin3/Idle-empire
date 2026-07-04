extends SceneTree
## Headless smoke for the Stage & Ledger shell: instantiate game_shell.tscn,
## pump frames, tap through tabs, and report script errors. Usage:
##   godot --headless --path godot -s res://scripts/tools/shell_smoke.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const TABS := ["bldgs", "upgrs", "mgrs", "turf", "stats"]

var _shell: Node
var _frames := 0
var _step := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	var gs: Node = root.get_node("GameState")
	gs.reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	if packed == null:
		push_error("[shell_smoke] failed to load game_shell.tscn")
		quit(1)
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	print("[shell_smoke] shell instantiated OK")


func _process(_delta: float) -> bool:
	_frames += 1
	var events: Node = root.get_node_or_null("UiEvents")
	if events == null:
		return false
	if _frames % 20 == 0 and _step < TABS.size():
		events.emit_signal("tab_requested", TABS[_step])
		print("[shell_smoke] tab -> %s" % TABS[_step])
		_step += 1
	elif _frames == 130:
		events.emit_signal("overlay_requested", "config")
		print("[shell_smoke] overlay -> config")
	elif _frames == 150:
		var gs: Node = root.get_node("GameState")
		gs.balance += 1000.0
		gs.emit_signal("stats_changed")
	elif _frames == 170:
		# Spend path for the ADR-001 assert (display snaps down with truth).
		var gs: Node = root.get_node("GameState")
		gs.balance = maxf(0.0, gs.balance - 500.0)
		gs.emit_signal("stats_changed")
	elif _frames >= 200:
		print("[shell_smoke] PASS — 200 frames, no crash")
		quit(0)
		return true
	# ADR-001 ticker honesty: the displayed balance may never exceed the truth.
	# Skip the exact frame WE mutate balance downward — the masthead reacts on
	# its next _process; the rule is per rendered frame, not mid-mutation.
	if _frames > 10 and _frames != 170:
		var masthead: Node = root.find_child("Masthead", true, false)
		if masthead != null and masthead.has_method("shown_balance"):
			var gs2: Node = root.get_node("GameState")
			var shown: float = masthead.call("shown_balance")
			if shown > float(gs2.balance) + 0.01:
				printerr("[shell_smoke] ADR-001 VIOLATION: shown %.2f > true %.2f" % [
					shown, gs2.balance,
				])
				quit(1)
				return true
	return false
