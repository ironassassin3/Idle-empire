extends RefCounted
## Persists buffered telemetry lines to user://telemetry.jsonl (current behavior).

const LOG_PATH := "user://telemetry.jsonl"
## Nothing reads this file back and v1 has no endpoint to send it to, so it only
## ever grew — every tab tap, for the life of the install. One rotation keeps the
## recent history useful and the ceiling at 2 MB.
const MAX_BYTES := 1024 * 1024

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
		if f != null and f.get_length() >= MAX_BYTES:
			f.close()
			if FileAccess.file_exists(_path + ".old"):
				DirAccess.remove_absolute(_path + ".old")
			DirAccess.rename_absolute(_path, _path + ".old")
			f = FileAccess.open(_path, FileAccess.WRITE)
		elif f != null:
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
