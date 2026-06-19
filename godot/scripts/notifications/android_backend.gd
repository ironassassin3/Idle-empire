extends RefCounted
## Android local-notification wrapper — kyoz LocalNotification autoload (§5).
##
## Requires: native plugin in `android/plugins/` + kyoz autoload registered as
## `LocalNotification` in project.godot (copy from kyoz repo `autoload/`).

const AUTOLOAD_PATH := "/root/LocalNotification"

var _plugin: Node = null
var _tags: Dictionary = {}


func _init() -> void:
	_plugin = _resolve_autoload()


func is_available() -> bool:
	return _plugin != null


func schedule(id: String, delay_secs: float, message: String) -> void:
	if _plugin == null:
		return
	_ensure_init()
	var tag: int = abs(id.hash()) % 100000
	_tags[id] = tag
	if _plugin.has_method("show"):
		_plugin.call(
			"show",
			"Criminal Empire",
			message,
			maxi(1, int(delay_secs)),
			tag,
		)
	elif OS.is_debug_build():
		print("[Notifications:android] schedule %s in %.0fs (no show method)" % [id, delay_secs])


func cancel_all() -> void:
	if _plugin == null:
		return
	if not _plugin.has_method("cancel"):
		return
	for id in _tags:
		_plugin.call("cancel", _tags[id])
	_tags.clear()


func request_permission() -> void:
	if _plugin == null:
		return
	_ensure_init()
	if _plugin.has_method("requestPermission"):
		_plugin.call("requestPermission")


func _ensure_init() -> void:
	if _plugin.has_method("init"):
		_plugin.call("init")


func _resolve_autoload() -> Node:
	var tree := Engine.get_main_loop()
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(AUTOLOAD_PATH))
