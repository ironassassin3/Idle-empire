extends SceneTree
## Headless probe: legacy saves without prestige_route_earnings must not inherit lifetime_earnings.
## Usage: godot --path godot --headless -s res://scripts/tools/save_migration_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")


func _initialize() -> void:
	SoakAutoloads.install(self)
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		push_error("GameState autoload missing")
		quit(1)
		return
	var legacy := {
		"balance": 1_000_000.0,
		"lifetime_earnings": 50_000_000.0,
		"prestige_tokens": 0,
		"prestige_count": 0,
		"last_login_date": Time.get_date_string_from_system(),
	}
	gs.apply_save_data(legacy)
	var route: float = float(gs.prestige_route_earnings)
	var lifetime: float = float(gs.lifetime_earnings)
	if route != 0.0:
		push_error("legacy migration: prestige_route_earnings=%s expected 0" % route)
		quit(1)
		return
	if lifetime != 50_000_000.0:
		push_error("legacy migration: lifetime_earnings=%s expected 50000000" % lifetime)
		quit(1)
		return
	var explicit := legacy.duplicate()
	explicit["prestige_route_earnings"] = 12_345_678.0
	gs.apply_save_data(explicit)
	route = float(gs.prestige_route_earnings)
	if abs(route - 12_345_678.0) > 1.0:
		push_error("explicit route: prestige_route_earnings=%s expected 12345678" % route)
		quit(1)
		return
	print("SAVE_MIGRATION_PROBE PASS")
	quit(0)
