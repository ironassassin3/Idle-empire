extends Node
## Telemetry — local-first analytics with pluggable sinks (§4.4).
##
## Buffers gameplay events, flushing to LocalFileSink always and RemoteSink when
## configured. Consent-gated via GameState.telemetry_consent. Disabled under
## headless display server (mirrors AudioManager).

const LocalFileSink = preload("res://scripts/telemetry/local_file_sink.gd")
const RemoteSink = preload("res://scripts/telemetry/remote_sink.gd")

const FLUSH_INTERVAL := 5.0
const MAX_BUFFER := 200
const REMOTE_ENDPOINT := ""  # Set when analytics backend is provisioned.

var enabled: bool = true
var _session: String = ""
var _buffer: PackedStringArray = PackedStringArray()
var _flush_timer: float = 0.0
var _local_sink: RefCounted
var _remote_sink: RefCounted


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_local_sink = LocalFileSink.new()
	_remote_sink = RemoteSink.new()
	if not REMOTE_ENDPOINT.is_empty():
		_remote_sink.configure(REMOTE_ENDPOINT, self)
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


func _consent_ok() -> bool:
	return GameState == null or GameState.telemetry_consent


## Single entry point. `props` is merged into the record. Never throws.
func log_event(ev: String, props: Dictionary = {}) -> void:
	if not enabled or not _consent_ok():
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
	if _remote_sink != null:
		_remote_sink.tick(delta, self)
	if _buffer.is_empty():
		return
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL:
		_flush_timer = 0.0
		flush()


func flush() -> void:
	if _buffer.is_empty():
		return
	var batch := _buffer.duplicate()
	_buffer.clear()
	if _local_sink != null:
		_local_sink.append_lines(batch)
	if _remote_sink != null:
		_remote_sink.enqueue(batch)


func _notification(what: int) -> void:
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
