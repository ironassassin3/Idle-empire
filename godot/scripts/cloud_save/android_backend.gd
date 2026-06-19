extends RefCounted
## Google Play Games Saved Games wrapper — Jacob Ibáñez `GodotPlayGameServices` (§5).
##
## Plugin v3+ uses Nodes (SnapshotClient) for save/load; this backend detects the
## main autoload and stubs snapshot I/O until SnapshotClient is wired on device.

signal snapshot_pushed(ok: bool)
signal snapshot_pulled(data: Dictionary, ok: bool)

const AUTOLOAD_PATH := "/root/GodotPlayGamesServices"
const SNAPSHOT_NAME := "criminal_empire_save"

var _plugin: Node = null
var _signed_in := false


func _init() -> void:
	_plugin = _resolve_autoload()


func is_available() -> bool:
	return _plugin != null


func is_signed_in() -> bool:
	return _signed_in and _plugin != null


func sign_in() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("initialize"):
		_plugin.call("initialize")
	elif _plugin.has_method("init"):
		_plugin.call("init")
	_signed_in = true


func push_snapshot(data: Dictionary) -> void:
	if _plugin == null:
		snapshot_pushed.emit(false)
		return
	# SnapshotClient.save_game(file_name, description, bytes, played_time, progress)
	var payload := JSON.stringify(data)
	if OS.is_debug_build():
		print("[CloudSave:android] push %d bytes to %s" % [payload.length(), SNAPSHOT_NAME])
	snapshot_pushed.emit(true)


func pull_snapshot() -> void:
	if _plugin == null:
		snapshot_pulled.emit({}, false)
		return
	# SnapshotClient.load_game(SNAPSHOT_NAME) → game_loaded signal
	snapshot_pulled.emit({}, false)


func _resolve_autoload() -> Node:
	var tree := Engine.get_main_loop()
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(AUTOLOAD_PATH))
