extends RefCounted
## Editor/headless cloud-save backend — no-op with debug logging.

signal snapshot_pushed(ok: bool)
signal snapshot_pulled(data: Dictionary, ok: bool)


func is_available() -> bool:
	return true


func is_signed_in() -> bool:
	return false


func sign_in() -> void:
	if OS.is_debug_build():
		print("[CloudSave:mock] sign_in — not available in editor")


func push_snapshot(_data: Dictionary) -> void:
	snapshot_pushed.emit(true)


func pull_snapshot() -> void:
	snapshot_pulled.emit({}, false)
