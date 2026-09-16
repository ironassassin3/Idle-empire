extends Node
## JSON save/load — compatible subset with src/save_load.py (user://save.json).

signal game_saved(data: Dictionary)

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.bak"
const TEMP_PATH := "user://save.json.tmp"
const BACKUP_TEMP_PATH := "user://save.json.bak.tmp"
## Kept, never deleted: a save that took the app down is still the player's
## progress, and support can ask for it.
const QUARANTINE_PATH := "user://save.json.broken"
const MAX_SAVE_BYTES := 2 * 1024 * 1024


## The previous launch died while this file was being read or applied. Loading it
## again would reproduce the crash forever, so it is moved aside before anything
## in this launch can touch it — including the title screen preview.
func _ready() -> void:
	if CrashReporter.save_suspect:
		recover_from_failed_boot()


func recover_from_failed_boot() -> void:
	var moved := _quarantine(SAVE_PATH)
	if not moved:
		moved = _quarantine(BACKUP_PATH)
	if moved:
		CrashReporter.set_recovery_note(
			"The last save could not be opened and was set aside; your backup was restored.")
	else:
		CrashReporter.set_recovery_note("The last launch failed while loading a save.")


func _quarantine(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if FileAccess.file_exists(QUARANTINE_PATH):
		DirAccess.remove_absolute(QUARANTINE_PATH)
	if DirAccess.rename_absolute(path, QUARANTINE_PATH) != OK:
		# Losing the rename must not leave the killer file in the boot path.
		DirAccess.remove_absolute(path)
	CrashReporter.note("quarantined " + path)
	return true


## Moves the primary aside by player request (Repair save in the menu) and
## reports whether a usable save is still available afterwards.
func repair_save() -> bool:
	_quarantine(SAVE_PATH)
	return not _read_save(BACKUP_PATH).is_empty()


func save_game() -> bool:
	var data := GameState.to_save_data()
	var json := JSON.stringify(data, "\t")
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: %s" % FileAccess.get_open_error())
		return false
	file.store_string(json)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_save(TEMP_PATH).is_empty():
		push_warning("Save failed: temporary file could not be verified")
		return false
	# A recovered backup must never be replaced with the damaged primary.
	if not _read_save(SAVE_PATH).is_empty():
		if DirAccess.copy_absolute(SAVE_PATH, BACKUP_TEMP_PATH) != OK:
			push_warning("Save failed: backup copy failed")
			return false
		if DirAccess.rename_absolute(BACKUP_TEMP_PATH, BACKUP_PATH) != OK:
			push_warning("Save failed: backup commit failed")
			return false
	# Same-directory rename commits only a complete, closed JSON file.
	if DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH) != OK:
		push_warning("Save failed: primary commit failed")
		return false
	game_saved.emit(data)
	return true


func load_game() -> bool:
	# Phase-marked so that a crash inside parsing or apply_save_data is attributed
	# to the save on the next launch instead of repeating forever.
	CrashReporter.mark_phase(CrashReporter.PHASE_LOADING_SAVE)
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed := _read_save(path)
		if parsed.is_empty():
			continue
		if path == BACKUP_PATH:
			push_warning("Recovered save from backup; primary missing or invalid")
			CrashReporter.set_recovery_note("Your backup save was restored.")
		GameState.apply_save_data(parsed)
		CrashReporter.mark_phase(CrashReporter.PHASE_RUNNING)
		return true
	CrashReporter.mark_phase(CrashReporter.PHASE_RUNNING)
	return false


func _read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var data = parser.data
	if not data is Dictionary or not data.get("balance") is float and not data.get("balance") is int:
		return {}
	# Preview uses numeric conversions before the player even presses Continue.
	for key in ["balance", "prestige_count", "prestige_tokens", "play_time"]:
		var value = data.get(key, 0)
		if not (value is float or value is int) or not is_finite(float(value)):
			return {}
	return data


func delete_save() -> void:
	for path in [TEMP_PATH, BACKUP_TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	GameState.reset_new_game()


## Readable, not merely present: the title screen used to offer Continue for a
## file it could not parse, so the button did nothing when tapped and the player
## had no way to tell a broken save from a broken game.
func has_save() -> bool:
	return not _read_save(SAVE_PATH).is_empty() or not _read_save(BACKUP_PATH).is_empty()


func preview() -> Dictionary:
	# The title screen reads the save before the player touches anything, so this
	# is part of the boot path and gets the same crash attribution as load_game.
	CrashReporter.mark_phase(CrashReporter.PHASE_LOADING_SAVE)
	var result := _preview_inner()
	CrashReporter.mark_phase(CrashReporter.PHASE_RUNNING)
	return result


func _preview_inner() -> Dictionary:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed := _read_save(path)
		if parsed.is_empty():
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
