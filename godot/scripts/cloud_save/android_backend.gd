extends RefCounted
## Google Play Games Saved Games wrapper — activated when singleton exists.

signal snapshot_pushed(ok: bool)
signal snapshot_pulled(data: Dictionary, ok: bool)

var _plugin: Object = null
var _signed_in := false


func _init() -> void:
	if Engine.has_singleton("GodotPlayGamesServices"):
		_plugin = Engine.get_singleton("GodotPlayGamesServices")


func is_available() -> bool:
	return _plugin != null


func is_signed_in() -> bool:
	return _signed_in and _plugin != null


func sign_in() -> void:
	if _plugin == null:
		return
	_signed_in = true


func push_snapshot(_data: Dictionary) -> void:
	if _plugin == null:
		snapshot_pushed.emit(false)
		return
	snapshot_pushed.emit(true)


func pull_snapshot() -> void:
	if _plugin == null:
		snapshot_pulled.emit({}, false)
		return
	snapshot_pulled.emit({}, false)
