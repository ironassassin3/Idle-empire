extends Node
## Telemetry — local-first analytics for Criminal Empire.
##
## Buffers gameplay events to user://telemetry.jsonl (one JSON object per line),
## flushing on a timer and on app pause / exit. Provider-agnostic: the local
## file is the only sink today; forwarding to GameAnalytics / Firebase later is a
## single addition in flush() — no gameplay code changes.
##
## Decoupled from gameplay: it only *listens* to GameState signals, so the
## headless sims behave identically whether or not it is installed. Disabled
## entirely under the headless display server (mirrors AudioManager).

const LOG_PATH := "user://telemetry.jsonl"
const FLUSH_INTERVAL := 5.0
const MAX_BUFFER := 200

var enabled: bool = true
var _session: String = ""
var _buffer: PackedStringArray = PackedStringArray()
var _flush_timer: float = 0.0
var _io_failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		enabled = false
		return
	_session = "%d-%05d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	log_event("app_launch", {
		"version": GameConfig.VERSION,
		"platform": OS.get_name(),
		"debug": OS.is_debug_build(),
	})
	_connect_game_signals()


func _connect_game_signals() -> void:
	# GameState is a core autoload (and is singleton-registered by the headless
	# soak tools), so the bare global resolves in both the game and -s tool runs.
	if GameState == null:
		return
	if GameState.has_signal("prestiged"):
		GameState.prestiged.connect(_on_prestiged)
	if GameState.has_signal("ranked_up"):
		GameState.ranked_up.connect(_on_ranked_up)
	if GameState.has_signal("run_started"):
		GameState.run_started.connect(_on_run_started)
	if GameState.has_signal("tutorial_advanced"):
		GameState.tutorial_advanced.connect(_on_tutorial_advanced)


## Single entry point. `props` is merged into the record. Never throws.
func log_event(ev: String, props: Dictionary = {}) -> void:
	if not enabled or _io_failed:
		return
	var rec: Dictionary = {
		"t": Time.get_unix_time_from_system(),
		"s": _session,
		"ev": ev,
	}
	for k in props:
		rec[k] = props[k]
	_buffer.append(JSON.stringify(rec))
	if _buffer.size() >= MAX_BUFFER:
		flush()


func _process(delta: float) -> void:
	if _buffer.is_empty():
		return
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL:
		_flush_timer = 0.0
		flush()


func flush() -> void:
	if _buffer.is_empty() or _io_failed:
		return
	# Godot has no append mode; open READ_WRITE + seek_end to append.
	var f: FileAccess
	if FileAccess.file_exists(LOG_PATH):
		f = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		_io_failed = true
		return
	for line in _buffer:
		f.store_line(line)
	f.close()
	_buffer.clear()


func _notification(what: int) -> void:
	# Flush when the OS backgrounds the app (mobile) or on exit, so events aren't
	# lost when the process is killed without a clean shutdown.
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_EXIT_TREE
	):
		flush()


func _on_run_started(info: Dictionary) -> void:
	log_event("run_start", info)


func _on_prestiged(info: Dictionary) -> void:
	log_event("prestige", info)


func _on_ranked_up(rank: String) -> void:
	log_event("rank_up", {"rank": rank})


func _on_tutorial_advanced(step: int) -> void:
	log_event("ftue_step", {"step": step})
