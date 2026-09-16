extends Logger
## No scene access from callbacks: Godot may call these on worker threads.
const PATH := "user://diagnostics/session.log"
const LIMIT := 128 * 1024
var _mutex := Mutex.new()
var _errors := 0
var _warnings := 0

func _log_error(function: String, file: String, line: int, code: String,
		rationale: String, _editor_notify: bool, error_type: int,
		script_backtraces: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	var warning := error_type == ERROR_TYPE_WARNING
	if warning:
		_warnings += 1
	else:
		_errors += 1
	var count := _warnings if warning else _errors
	# A per-frame script failure must not fill storage or cause a disk-write storm.
	if count <= 64:
		var message := "%s %s:%d %s: %s %s" % [
			"WARNING" if warning else "ERROR", file, line, function, code, rationale]
		for trace in script_backtraces:
			message += "\n" + trace.format().left(4096)
		_append_locked(message.left(8192))
	elif count == 65:
		_append_locked("Further %s suppressed for this session" % ("warnings" if warning else "errors"))
	_mutex.unlock()

func _log_message(message: String, error: bool) -> void:
	# Engine errors arrive through _log_error; avoid duplicate console output.
	if error:
		_mutex.lock()
		if _errors < 64:
			_errors += 1
			_append_locked("STDERR " + message.left(4096))
		_mutex.unlock()

func record(message: String) -> void:
	_mutex.lock()
	_append_locked(message.left(8192))
	_mutex.unlock()

func _append_locked(message: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	if file.get_length() >= LIMIT:
		file.close()
		if DirAccess.rename_absolute(PATH, PATH + ".old") != OK:
			return
		file = FileAccess.open(PATH, FileAccess.WRITE)
		if file == null:
			return
	file.seek_end()
	file.store_line("%s +%dms %s" % [Time.get_datetime_string_from_system(true), Time.get_ticks_msec(), message])
	file.flush()
	file.close()

func snapshot() -> String:
	_mutex.lock()
	var result := read_bounded(PATH + ".old") + read_bounded(PATH)
	_mutex.unlock()
	return result

static func read_bounded(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_buffer(LIMIT + 16384).get_string_from_utf8()
