extends SceneTree
## Headless income probe for pygame ↔ Godot parity (ROADMAP P5 verify).
## Usage: godot --path godot --headless -s res://scripts/tools/income_parity_probe.gd -- --fixture <path> [--ticks N] [--unlock-territories N]

const DEFAULT_TICKS := 600
const SAMPLE_EVERY := 60
const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")


func _initialize() -> void:
	# A `-s` SceneTree run does not init project autoloads; install them so
	# GameState is available (otherwise every access below null-references).
	SoakAutoloads.install(self)
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState autoload missing -- install failed")
		quit(1)
		return
	var fixture_path := _arg_after("--fixture")
	if fixture_path.is_empty():
		push_error("Missing --fixture <path>")
		quit(1)
		return
	var ticks := int(_arg_after("--ticks")) if not _arg_after("--ticks").is_empty() else DEFAULT_TICKS
	if not FileAccess.file_exists(fixture_path):
		push_error("Fixture not found: %s" % fixture_path)
		quit(1)
		return
	var text := FileAccess.get_file_as_string(fixture_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Fixture must be JSON object")
		quit(1)
		return
	# Isolate income: a fresh fixture would otherwise trigger the load-time daily
	# reward (streak 1). Stamp today's date so _apply_daily_reward is a no-op.
	if not parsed.has("last_login_date"):
		parsed["last_login_date"] = Time.get_date_string_from_system()
	gs.apply_save_data(parsed)
	var unlock_n := int(_arg_after("--unlock-territories"))
	if unlock_n > 0:
		var owned := 0
		for t in gs.territories:
			if owned >= unlock_n:
				break
			if typeof(t) == TYPE_DICTIONARY:
				t["unlocked"] = true
				t["owner"] = "player"
				owned += 1
	gs.set_simulation_active(false)
	gs._mark_ips_dirty()
	var dt := 1.0
	var ips0: float = gs.income_per_second()
	var total := 0.0
	var samples: Array = [ips0]
	for i in range(ticks):
		var ips: float = gs.income_per_second()
		if i > 0 and i % SAMPLE_EVERY == 0:
			samples.append(ips)
		total += ips * dt
		gs.balance += ips * dt
		gs.lifetime_earnings += ips * dt
		gs.play_time += dt
	var out := {
		"ips0": ips0,
		"total_passive": total,
		"samples": samples,
		"balance": gs.balance,
		"lifetime_earnings": gs.lifetime_earnings,
	}
	print(JSON.stringify(out))
	quit(0)


func _arg_after(flag: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_args()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	for pack in [user_args, args]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return ""
