extends RefCounted
## Editor/headless notification backend — logs scheduled prompts.

var _scheduled: Array = []


func is_available() -> bool:
	return true


func schedule(id: String, delay_secs: float, message: String) -> void:
	_scheduled.append({"id": id, "delay": delay_secs, "message": message})
	if OS.is_debug_build():
		print("[Notifications:mock] schedule %s in %.0fs — %s" % [id, delay_secs, message])


func cancel_all() -> void:
	if not _scheduled.is_empty() and OS.is_debug_build():
		print("[Notifications:mock] cancelled %d pending" % _scheduled.size())
	_scheduled.clear()


func request_permission() -> void:
	pass
