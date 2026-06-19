extends Node
## Local notification scheduler — mock in editor; Android plugin when installed (§5).
##
## Schedules gentle return prompts on app pause; cancels on resume. Respects
## GameState.notifications_enabled (Config tab toggle).

const MockBackend = preload("res://scripts/notifications/mock_backend.gd")
const AndroidBackend = preload("res://scripts/notifications/android_backend.gd")

var _backend: RefCounted
var _enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		_enabled = false
		return
	_pick_backend()


func _pick_backend() -> void:
	var android := AndroidBackend.new()
	if android.is_available():
		_backend = android
	else:
		_backend = MockBackend.new()


func _notification(what: int) -> void:
	if not _enabled or _backend == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if GameState.notifications_enabled:
			_schedule_pending()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_backend.cancel_all()


func _schedule_pending() -> void:
	var offline_secs: float = GameConfig.OFFLINE_CAP_HOURS * 3600.0
	var offline_msg := "Your empire earned cash while you were away. Tap to collect."
	if GameState.offline_gain > 0.0:
		offline_msg = "Your empire earned %s. Tap to collect." % FormatUtil.format_money(
			GameState.offline_gain
		)
	_backend.schedule(
		"offline_cap",
		offline_secs,
		offline_msg,
	)
	var midnight_secs := _seconds_until_local_midnight()
	_backend.schedule(
		"daily_reward",
		midnight_secs,
		"Daily reward ready — don't break your streak!",
	)


func request_permission() -> void:
	if _enabled and _backend != null and _backend.has_method("request_permission"):
		_backend.request_permission()


func _seconds_until_local_midnight() -> float:
	var now := Time.get_datetime_dict_from_system()
	var secs_today := (
		int(now.hour) * 3600
		+ int(now.minute) * 60
		+ int(now.second)
	)
	return maxf(60.0, float(86400 - secs_today))
