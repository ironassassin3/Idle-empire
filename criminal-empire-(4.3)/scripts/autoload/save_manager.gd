extends Node
## JSON save/load — compatible subset with src/save_load.py (user://save.json).

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.bak"


func save_game() -> bool:
	var data := GameState.to_save_data()
	var json := JSON.stringify(data, "\t")
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("save.json"):
		dir.copy("save.json", "save.json.bak")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json)
	return true


func load_game() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		if not parsed.has("balance"):
			continue
		GameState.apply_save_data(parsed)
		return true
	return false


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	GameState.reset_new_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func preview() -> Dictionary:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("balance"):
			continue
		return {
			"prestige_count": int(parsed.get("prestige_count", 0)),
			"prestige_tokens": int(parsed.get("prestige_tokens", 0)),
			"play_time": float(parsed.get("play_time", 0.0)),
		}
	return {}


## Optional: import pygame save from project parent folder (dev convenience).
func try_import_python_save() -> bool:
	var base_dir := ProjectSettings.globalize_path("res://")
	var py_path := base_dir.path_join("..").path_join("save.json")
	if not FileAccess.file_exists(py_path):
		return false
	var file := FileAccess.open(py_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("balance"):
		return false
	GameState.apply_save_data(parsed)
	save_game()
	return true
