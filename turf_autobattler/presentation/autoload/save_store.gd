extends Node

## Persists metagame + settings to user:// (handoff §17). Mid-run resume deferred to v1.1.

const SAVE_VERSION := 1
const SAVE_PATH := "user://turf_save.json"


func load_into(bridge: Node) -> void:
	var data := _read_file()
	if data.is_empty():
		return
	if int(data.get("version", 0)) != SAVE_VERSION:
		return
	var mg_data: Dictionary = data.get("metagame", {})
	if mg_data.is_empty():
		return
	var mg := MetagameState.create_default()
	mg.currency = int(mg_data.get("currency", 0))
	mg.unlocks.assign(mg_data.get("unlocks", []))
	mg.stats = mg_data.get("stats", mg.stats).duplicate(true)
	bridge.metagame = mg
	var settings: Dictionary = data.get("settings", {})
	if settings.has("playback_speed"):
		bridge.playback_speed = float(settings["playback_speed"])


func save_from(bridge: Node) -> void:
	var mg: MetagameState = bridge.metagame
	var payload := {
		"version": SAVE_VERSION,
		"metagame": {
			"currency": mg.currency,
			"unlocks": mg.unlocks.duplicate(),
			"stats": mg.stats.duplicate(true),
		},
		"settings": {
			"playback_speed": bridge.playback_speed,
		},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveStore: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload))


func _read_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
