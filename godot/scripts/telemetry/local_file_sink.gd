extends RefCounted
## Persists buffered telemetry lines to user://telemetry.jsonl (current behavior).

const LOG_PATH := "user://telemetry.jsonl"

var _path: String = LOG_PATH
var _io_failed: bool = false


func set_output_path(path: String) -> void:
	if not path.is_empty():
		_path = path
		_io_failed = false


func get_output_path() -> String:
	return _path


func append_lines(lines: PackedStringArray) -> bool:
	if lines.is_empty():
		return true
	if _io_failed:
		return false
	var f: FileAccess
	if FileAccess.file_exists(_path):
		f = FileAccess.open(_path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		_io_failed = true
		push_error("LocalFileSink: cannot open %s (err %s)" % [_path, FileAccess.get_open_error()])
		return false
	for line in lines:
		f.store_line(line)
	f.close()
	return true
