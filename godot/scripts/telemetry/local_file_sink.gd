extends RefCounted
## Persists buffered telemetry lines to user://telemetry.jsonl (current behavior).

const LOG_PATH := "user://telemetry.jsonl"

var _io_failed: bool = false


func append_lines(lines: PackedStringArray) -> bool:
	if lines.is_empty() or _io_failed:
		return lines.is_empty()
	var f: FileAccess
	if FileAccess.file_exists(LOG_PATH):
		f = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		_io_failed = true
		return false
	for line in lines:
		f.store_line(line)
	f.close()
	return true
