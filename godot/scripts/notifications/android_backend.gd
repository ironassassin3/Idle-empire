extends RefCounted
## Android local-notification plugin wrapper — activated when singleton exists.

var _plugin: Object = null


func _init() -> void:
	if Engine.has_singleton("GodotLocalNotifications"):
		_plugin = Engine.get_singleton("GodotLocalNotifications")


func is_available() -> bool:
	return _plugin != null


func schedule(id: String, delay_secs: float, message: String) -> void:
	if _plugin == null:
		return
	# Wire plugin-specific schedule call when §5 plugin is installed.
	if OS.is_debug_build():
		print("[Notifications:android] schedule %s in %.0fs" % [id, delay_secs])


func cancel_all() -> void:
	if _plugin == null:
		return
	pass


func request_permission() -> void:
	if _plugin == null:
		return
	pass
