extends SceneTree
## The safe-mode title screen is the one screen a broken build has to render
## correctly — it carries the recovery notice, Repair save and the diagnostics
## report. It also adds two controls and a wrapped paragraph to a panel that was
## already tight at a phone's 1.6 font boost, so it gets its own fit check.
##
##   CE_FONT_BOOST=1.6 godot --path godot --resolution 720x1280 \
##       -s res://scripts/tools/recovery_ui_probe.gd

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _failed := false
var _menu: Node


func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	var reporter := root.get_node("CrashReporter")
	reporter.safe_mode = true
	reporter.boot_failures = 2
	reporter.set_recovery_note(
		"The last save could not be opened and was set aside; your backup was restored.")
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	gs.reset_new_game()
	gs.last_login_date = Time.get_date_string_from_system()
	saves.save_game()
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_menu = packed.instantiate()
	root.add_child(_menu)
	call_deferred("_run")


func _run() -> void:
	# Two frames: the menu defers its font boost and title fit, and containers
	# only settle once those have run.
	await process_frame
	await process_frame
	await process_frame
	var viewport: Rect2 = root.get_visible_rect()
	var panel: Control = _menu.get_node("Margin/Center/LedgerPanel")
	var vbox: Control = _menu.get_node("Margin/Center/LedgerPanel/VBox")
	_check(_menu.get_node_or_null("Margin/Center/LedgerPanel/VBox/RecoveryNote") != null,
		"the recovery notice is on screen")
	_check(_menu.get_node_or_null("Margin/Center/LedgerPanel/VBox/RepairBtn") != null,
		"Repair save is on screen")
	_check(_menu.get_node_or_null("Margin/Center/LedgerPanel/VBox/DiagnosticsBtn") != null,
		"Crash diagnostics is on screen")
	var panel_rect := Rect2(panel.global_position, panel.size)
	_check(viewport.encloses(panel_rect),
		"the menu panel fits the viewport (panel %s, viewport %s)" % [panel_rect, viewport])
	for child in vbox.get_children():
		if not child is Control or not (child as Control).visible:
			continue
		var c := child as Control
		var rect := Rect2(c.global_position, c.size)
		_check(viewport.encloses(rect), "%s is fully on screen (%s)" % [c.name, rect])
		if c is Button:
			# Play's own accessibility guidance: 48dp minimum touch target.
			_check(c.size.y >= 44.0, "%s is thumb-sized (%.0fpx)" % [c.name, c.size.y])
	print("RECOVERY_UI %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("FAIL " + message)
