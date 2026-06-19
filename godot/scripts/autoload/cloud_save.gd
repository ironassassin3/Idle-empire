extends Node
## Cloud save seam — local-first backup via Play Games Saved Games (§4.3).
##
## Wraps SaveManager without replacing it. Pushes throttled snapshots on save;
## pulls and merges on sign-in by higher play_time / lifetime_earnings.

const MockBackend = preload("res://scripts/cloud_save/mock_backend.gd")
const AndroidBackend = preload("res://scripts/cloud_save/android_backend.gd")

const PUSH_INTERVAL := 120.0

var _backend: RefCounted
var _enabled := true
var _push_timer: float = 0.0
var _last_push_at: float = -PUSH_INTERVAL


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		_enabled = false
		return
	_pick_backend()
	if SaveManager.has_signal("game_saved"):
		SaveManager.game_saved.connect(_on_game_saved)
	if _backend.has_signal("snapshot_pulled"):
		_backend.snapshot_pulled.connect(_on_snapshot_pulled)


func _pick_backend() -> void:
	var android := AndroidBackend.new()
	if android.is_available():
		_backend = android
	else:
		_backend = MockBackend.new()


func sign_in() -> void:
	if not _enabled or _backend == null:
		return
	_backend.sign_in()
	if _backend.has_method("pull_snapshot"):
		_backend.pull_snapshot()


func is_signed_in() -> bool:
	return _enabled and _backend != null and _backend.is_signed_in()


func _on_game_saved(data: Dictionary) -> void:
	if not _enabled or _backend == null or not is_signed_in():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_push_at < PUSH_INTERVAL:
		return
	_last_push_at = now
	_backend.push_snapshot(data)


func _on_snapshot_pulled(cloud: Dictionary, ok: bool) -> void:
	if not ok or cloud.is_empty() or not cloud.has("balance"):
		return
	var local_pt: float = GameState.play_time
	var cloud_pt: float = float(cloud.get("play_time", 0.0))
	var local_le: float = GameState.lifetime_earnings
	var cloud_le: float = float(cloud.get("lifetime_earnings", 0.0))
	var use_cloud := cloud_pt > local_pt or (
		is_equal_approx(cloud_pt, local_pt) and cloud_le > local_le
	)
	if use_cloud:
		GameState.apply_save_data(cloud)
		SaveManager.save_game()
