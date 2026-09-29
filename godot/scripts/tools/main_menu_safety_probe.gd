extends SceneTree
## Returning players see Continue, never a destructive New Game neighbor.
## A no-save/recovery launch still exposes New Game as an escape hatch.

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _frames := 0


func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	var state = root.get_node("GameState")
	state.reset_new_game()
	state.balance = 1234.0
	root.get_node("SaveManager").save_game()
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		printerr("MAIN_MENU_SAFETY FAIL — main menu could not load")
		quit(1)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	var menu := current_scene
	var new_btn: Button = menu.get_node("Margin/Center/LedgerPanel/VBox/NewBtn")
	var continue_btn: Button = menu.get_node("Margin/Center/LedgerPanel/VBox/ContinueBtn")
	if new_btn.visible or not continue_btn.visible:
		printerr("MAIN_MENU_SAFETY FAIL — returning-player buttons are unsafe")
		quit(1)
		return true
	root.get_node("SaveManager").delete_save()
	menu.call("_refresh_save_ui")
	if not new_btn.visible or continue_btn.visible:
		printerr("MAIN_MENU_SAFETY FAIL — no-save recovery path is missing")
		quit(1)
		return true
	print("MAIN_MENU_SAFETY PASS — returning reset hidden; recovery path retained")
	quit(0)
	return true
