extends SceneTree

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")

func _initialize() -> void:
	# Never run destructive fixtures against a developer's real save directory.
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	call_deferred("_run")

func _run() -> void:
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	gs.reset_new_game()
	gs.balance = 1234.0
	gs.last_login_date = Time.get_date_string_from_system()
	saves.save_game()
	saves.save_game()
	var file := FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string('{"balance":')
	file.close()
	if not saves.load_game() or gs.balance != 1234.0:
		printerr("FAIL: interrupted primary did not recover backup")
		quit(1)
		return
	gs.balance = 5678.0
	saves.save_game()
	var backup = JSON.parse_string(FileAccess.get_file_as_string("user://save.json.bak"))
	if not backup is Dictionary or backup.get("balance") != 1234.0:
		printerr("FAIL: saving after recovery destroyed the last good backup")
		quit(1)
		return
	file = FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string('{"balance": 42, "prestige_count": {"invalid": true}}')
	file.close()
	if saves.preview().get("prestige_count", -1) != 0 or not saves.load_game():
		printerr("FAIL: malformed title preview did not fall back to backup")
		quit(1)
		return
	print("SAVE_RECOVERY PASS")
	quit(0)
