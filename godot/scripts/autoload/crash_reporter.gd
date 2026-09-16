extends Node
## Local-only diagnostics, installed before gameplay/native-service autoloads.
##
## Two jobs:
##   1. Record what the app was doing when it died, so a tester can hand back
##      evidence without a cable or a Play Console report.
##   2. Break a launch loop. The marker records which phase the last session was
##      in; a session that dies before it is healthy raises a counter, and two of
##      those put the next launch in safe mode. If the phase was "loading a
##      save", SaveManager quarantines that file instead of loading it again —
##      that is the difference between "crashed once" and "will never open".
const Sink = preload("res://scripts/autoload/diagnostic_logger.gd")
const MARKER := "user://diagnostics/session.json"
const INCIDENT := "user://diagnostics/last_incident.txt"

const PHASE_BOOT := "boot"
const PHASE_LOADING_SAVE := "loading_save"
const PHASE_RUNNING := "running"
const PHASE_BACKGROUND := "background"
const PHASE_CLEAN_EXIT := "clean_exit"
## A launch that survives this long counts as healthy: the menu is up, the save
## is applied, and whatever killed the previous session is behind us.
const HEALTHY_SECONDS := 20.0
const SAFE_MODE_THRESHOLD := 2

var _sink: Logger
var previous_status := ""
## Consecutive launches that died before reaching HEALTHY_SECONDS.
var boot_failures := 0
## Two failed launches in a row: skip native services and music, and offer repair.
var safe_mode := false
## The last launch died while reading or applying a save file.
var save_suspect := false
var recovery_note := ""
var _elapsed := 0.0
var _uptime := 0.0
var _healthy := false
var _phase := PHASE_BOOT
var _scene := ""
var _dialog: AcceptDialog


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://diagnostics")
	var old := Sink.read_bounded(MARKER)
	var prev := {}
	var parser := JSON.new()
	if parser.parse(old) == OK and parser.data is Dictionary:
		prev = parser.data
	previous_status = str(prev.get("status", "unknown"))
	var prev_healthy := bool(prev.get("healthy", false))
	boot_failures = int(prev.get("boot_failures", 0))
	var dirty: bool = previous_status in [
		PHASE_BOOT, PHASE_LOADING_SAVE, PHASE_RUNNING, PHASE_BACKGROUND]
	save_suspect = previous_status == PHASE_LOADING_SAVE
	# Only a launch that never got healthy counts against us. A crash after an
	# hour of play, or Android reclaiming a backgrounded process, is not a loop.
	if dirty and not prev_healthy and previous_status != PHASE_BACKGROUND:
		boot_failures += 1
	else:
		boot_failures = 0
	safe_mode = boot_failures >= SAFE_MODE_THRESHOLD
	if dirty:
		_write(INCIDENT, "Previous session ended without a clean exit. This can mean a crash, "
			+ "force stop, or Android reclaiming the process; it is not proof of a crash.\n"
			+ "Phase: %s | reached healthy: %s | consecutive failed launches: %d\n" % [
				previous_status, str(prev_healthy), boot_failures]
			+ old + "\n" + Sink.read_bounded(Sink.PATH + ".old") + Sink.read_bounded(Sink.PATH))
	for path in [Sink.PATH, Sink.PATH + ".old"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_sink = Sink.new()
	OS.add_logger(_sink)
	_sink.record("START " + JSON.stringify({
		"app_version": ProjectSettings.get_setting("application/config/version", ""),
		"engine": Engine.get_version_info().get("string", ""),
		"os": OS.get_name(), "os_version": OS.get_version(), "model": OS.get_model_name(),
		"debug": OS.is_debug_build(), "renderer": RenderingServer.get_current_rendering_method(),
		"previous_phase": previous_status, "boot_failures": boot_failures,
		"safe_mode": safe_mode, "save_suspect": save_suspect,
	}))
	_mark(PHASE_BOOT)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_navigation")


func _connect_navigation() -> void:
	var events := get_node_or_null("/root/UiEvents")
	if events != null:
		events.tab_requested.connect(func(key): _sink.record("TAB " + str(key)))
		events.overlay_requested.connect(func(key): _sink.record("OVERLAY " + str(key)))


func _process(delta: float) -> void:
	_elapsed += delta
	_uptime += delta
	var current := get_tree().current_scene
	var scene := current.scene_file_path if current != null else "startup"
	if scene != _scene:
		_scene = scene
		_sink.record("SCENE " + scene)
	if not _healthy and _uptime >= HEALTHY_SECONDS:
		# Persist the all-clear so the NEXT launch starts from zero failures.
		_healthy = true
		_mark(_phase)
	if _elapsed >= 30.0:
		_elapsed = 0.0
		_sink.record("HEALTH " + JSON.stringify({
			"scene": _scene, "fps": Engine.get_frames_per_second(),
			"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		}))


func _notification(what: int) -> void:
	if _sink == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_mark(PHASE_BACKGROUND)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_mark(PHASE_RUNNING)
	elif what == NOTIFICATION_OS_MEMORY_WARNING:
		_sink.record("OS MEMORY WARNING")


func _exit_tree() -> void:
	if _sink != null:
		_mark(PHASE_CLEAN_EXIT)
		OS.remove_logger(_sink)


## Called around anything that could take the process down with it — currently
## reading and applying a save. If the app dies here, the next launch knows why.
func mark_phase(phase: String) -> void:
	if _sink == null:
		return
	_mark(phase)


func note(message: String) -> void:
	if _sink != null:
		_sink.record("NOTE " + message)


func set_recovery_note(message: String) -> void:
	recovery_note = message
	note("RECOVERY " + message)


func _mark(status: String) -> void:
	_phase = status
	_sink.record("LIFECYCLE " + status)
	_write(MARKER, JSON.stringify({
		"status": status,
		"utc": Time.get_datetime_string_from_system(true),
		"uptime_sec": _uptime,
		"healthy": _healthy,
		# A healthy session clears the tally for the next launch.
		"boot_failures": 0 if _healthy else boot_failures,
	}))


func _write(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	return file.get_error() == OK


func report_text() -> String:
	var app := str(ProjectSettings.get_setting("application/config/name", "Game"))
	return app + " diagnostics\nLocal report; nothing is uploaded automatically.\n" \
		+ "Native startup failures / Android kills may require Play Console or logcat.\n" \
		+ "Device: %s / %s %s | build %s\n" % [
			OS.get_model_name(), OS.get_name(), OS.get_version(),
			ProjectSettings.get_setting("application/config/version", "")] \
		+ "Last launch phase: %s | failed launches: %d | safe mode: %s\n" % [
			previous_status, boot_failures, str(safe_mode)] \
		+ ("Recovery: %s\n" % recovery_note if not recovery_note.is_empty() else "") \
		+ "\nLAST INTERRUPTED SESSION\n" + _read_incident() \
		+ "\nCURRENT SESSION\n" + _sink.snapshot()


func _read_incident() -> String:
	var file := FileAccess.open(INCIDENT, FileAccess.READ)
	return file.get_buffer(300 * 1024).get_string_from_utf8() if file != null else "None recorded.\n"


func show_report() -> void:
	if is_instance_valid(_dialog):
		_dialog.popup_centered_ratio(0.9)
		return
	_dialog = AcceptDialog.new()
	_dialog.title = "Crash diagnostics"
	_dialog.dialog_text = ""
	_dialog.ok_button_text = "Close"
	var view := TextEdit.new()
	view.text = report_text()
	view.editable = false
	view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	view.custom_minimum_size = Vector2(260, 260)
	_dialog.add_child(view)
	_dialog.add_button("Copy report", false, "copy")
	_dialog.add_button("Clear logs", false, "clear")
	_dialog.custom_action.connect(func(action: StringName):
		if action == &"copy":
			DisplayServer.clipboard_set(view.text)
		elif action == &"clear":
			for path in [INCIDENT, Sink.PATH, Sink.PATH + ".old"]:
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(path)
			view.text = "Logs cleared. New errors will still be recorded locally."
	)
	_dialog.confirmed.connect(func(): _dialog.queue_free())
	_dialog.canceled.connect(func(): _dialog.queue_free())
	add_child(_dialog)
	_dialog.popup_centered_ratio(0.9)
