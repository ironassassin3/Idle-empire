extends SceneTree
## A clean install enters gameplay without asking the player to create a save.
## Recovery launches are covered separately by recovery_ui_probe.gd and must
## remain on the title screen.
##
##   godot --headless --path godot -s res://scripts/tools/fresh_start_probe.gd

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _frames := 0


func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	var saves := root.get_node("SaveManager")
	saves.delete_save()
	var reporter := root.get_node("CrashReporter")
	reporter.safe_mode = false
	reporter.boot_failures = 0
	reporter.recovery_note = ""
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		printerr("FRESH_START FAIL — main menu could not load")
		quit(1)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	var scene := current_scene
	var path := scene.scene_file_path if scene != null else ""
	var expected := "res://scenes/game_shell.tscn" if root.get_node("GameConfig").UI_SHELL_V3 \
		else "res://scenes/game_screen.tscn"
	if path != expected:
		printerr("FRESH_START FAIL — expected %s, got %s" % [expected, path])
		quit(1)
		return true
	print("FRESH_START PASS — clean install entered gameplay")
	quit(0)
	return true
