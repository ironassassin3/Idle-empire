extends SceneTree
## Headless probe: replaying the tutorial (P1 #7) actually re-arms every hint
## and tells the player it happened. Usage:
##   godot --headless --path godot -s res://scripts/tools/tutorial_replay_probe.gd
##
## Deliberately does not reference the global TutorialSystem class (preloading
## or naming it here sent GDScript's dependent-script reload into a broken
## compile cascade — "GameState"/"FormatUtil" not found — in this headless
## script-mode run). `gs.tutorial_step = 99` is the existing project idiom for
## "tutorial complete" (see layout_invariants.gd, ui_capture.gd).

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const SHOWN_FLAGS := [
	"shown_crew_tutorial", "shown_ops_tutorial", "shown_territory_tutorial",
	"shown_rivals_tutorial", "shown_influence_tutorial", "shown_heat_warning",
	"shown_raid_tutorial", "shown_syndicate_tutorial",
]

var _got_notification := false


func _initialize() -> void:
	SoakAutoloads.install(self)
	var gs: Node = root.get_node("GameState")
	gs.reset_new_game()

	# Simulate a player who blew through every hint.
	gs.tutorial_step = 99
	for flag in SHOWN_FLAGS:
		gs.set(flag, true)

	# `gs.notification` is ambiguous with Object's built-in notification() method
	# when `gs` is statically typed Node, so connect by signal name instead.
	gs.connect("notification", func(_msg: String, _col: Color): _got_notification = true)
	gs.reset_tutorial()

	var failures: Array = []
	if gs.tutorial_step != 0:
		failures.append("tutorial_step = %d, expected 0" % gs.tutorial_step)
	for flag in SHOWN_FLAGS:
		if bool(gs.get(flag)):
			failures.append("%s still true — that hint would never replay" % flag)
	if not _got_notification:
		failures.append("no notification emitted — silent reset, player has no confirmation")

	if not failures.is_empty():
		for f in failures:
			printerr("[tutorial_replay] FAIL: %s" % f)
		quit(1)
		return

	print("[tutorial_replay] PASS — reset re-arms every hint and confirms via toast")
	quit(0)
