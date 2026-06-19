extends RefCounted
## Remote telemetry sink — batches JSONL to an HTTP endpoint when configured.
##
## Unsent batches persist to user://telemetry_queue.jsonl for retry after kills.

const QUEUE_PATH := "user://telemetry_queue.jsonl"
const BATCH_SIZE := 50
const RETRY_INTERVAL := 30.0

var endpoint_url: String = ""
var _retry_timer: float = 0.0
var _http: HTTPRequest = null
var _pending_batch: PackedStringArray = PackedStringArray()
var _in_flight: bool = false


func configure(url: String, parent: Node) -> void:
	endpoint_url = url.strip_edges()
	if endpoint_url.is_empty():
		return
	if _http == null and parent != null:
		_http = HTTPRequest.new()
		parent.add_child(_http)
		_http.request_completed.connect(_on_request_completed)


func enqueue(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	if endpoint_url.is_empty():
		_persist_queue(lines)
		return
	for line in lines:
		_pending_batch.append(line)
	if _pending_batch.size() >= BATCH_SIZE:
		_flush_pending()


func tick(delta: float, parent: Node) -> void:
	if endpoint_url.is_empty():
		return
	configure(endpoint_url, parent)
	_retry_timer += delta
	if _retry_timer < RETRY_INTERVAL:
		return
	_retry_timer = 0.0
	if not _in_flight:
		_drain_queue_to_pending()
		_flush_pending()


func _flush_pending() -> void:
	if _in_flight or _pending_batch.is_empty() or _http == null:
		return
	var payload := "[\n" + ",\n".join(_pending_batch) + "\n]"
	var headers := ["Content-Type: application/json"]
	_in_flight = true
	var err := _http.request(endpoint_url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		_in_flight = false
		_persist_queue(_pending_batch)
		_pending_batch.clear()


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray,
) -> void:
	_in_flight = false
	if response_code >= 200 and response_code < 300:
		_pending_batch.clear()
	else:
		_persist_queue(_pending_batch)
		_pending_batch.clear()


func _persist_queue(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	var f: FileAccess
	if FileAccess.file_exists(QUEUE_PATH):
		f = FileAccess.open(QUEUE_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f == null:
		return
	for line in lines:
		f.store_line(line)
	f.close()


func _drain_queue_to_pending() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var f := FileAccess.open(QUEUE_PATH, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if not line.is_empty():
			_pending_batch.append(line)
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QUEUE_PATH))
