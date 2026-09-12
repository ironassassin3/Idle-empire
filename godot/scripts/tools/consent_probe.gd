extends SceneTree
## Regression probe for the telemetry consent contract (Play Data Safety).
##
## The claim this defends: a first launch records diagnostics on-device only and
## sends NOTHING off-device, and revoking sharing leaves no queued payload behind
## for a later launch to send. Those are promises made in docs/PRIVACY_POLICY.md
## and answered on the Data Safety form, so they need a test, not a code read.

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const RemoteSink = preload("res://scripts/telemetry/remote_sink.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	SoakAutoloads.install(self)
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var telemetry: Node = root.get_node("Telemetry")
	state.reset_new_game()

	_check("first launch records locally", state.telemetry_consent)
	_check("first launch does NOT share off-device", not state.telemetry_share)
	_check("no endpoint is baked into the build", str(telemetry.REMOTE_ENDPOINT).is_empty())
	_check("share gate closed with consent default", not telemetry.call("_share_ok"))

	# Opting in must not be enough on its own — an unprovisioned build still has
	# nowhere to send to, and must not start hoarding payloads for one.
	state.telemetry_share = true
	_check("share gate stays closed without an endpoint", not telemetry.call("_share_ok"))
	telemetry.set_share_consent(true)
	_check("unconfigured build cannot enable sharing", not state.telemetry_share)
	telemetry.enabled = true
	telemetry.log_event("buffered_before_off")
	_check("fixture buffered", telemetry.probe_status().buffer > 0)
	telemetry.set_local_consent(false)
	_check("OFF discards buffered events", telemetry.probe_status().buffer == 0)
	telemetry.log_event("must_not_record")
	_check("OFF records nothing", telemetry.probe_status().buffer == 0)
	telemetry.set_local_consent(true)

	# An unconfigured sink must drop, not persist: the old behaviour grew
	# telemetry_queue.jsonl forever with data it could never deliver.
	var sink := RemoteSink.new()
	sink.enqueue(PackedStringArray(['{"ev":"probe"}']))
	_check(
		"unconfigured sink queues nothing to disk",
		not FileAccess.file_exists(RemoteSink.QUEUE_PATH)
	)

	# Revoking sharing must clear anything already waiting to go out.
	var active_sink: RefCounted = telemetry.get("_remote_sink")
	active_sink.call("_persist_queue", PackedStringArray(['{"ev":"pending"}']))
	_check("queue file exists before revoke", FileAccess.file_exists(RemoteSink.QUEUE_PATH))
	telemetry.set_share_consent(false)
	_check("revoke turns sharing off", not state.telemetry_share)
	_check(
		"revoke leaves no queued payload",
		not FileAccess.file_exists(RemoteSink.QUEUE_PATH)
	)

	# Consent OFF must stop recording at the source, not just at the sink.
	state.telemetry_consent = false
	_check("consent off closes the record gate", not telemetry.call("_consent_ok"))

	if _failures.is_empty():
		print("CONSENT PROBE PASS")
		quit(0)
	else:
		for f in _failures:
			printerr("  FAIL: %s" % f)
		printerr("CONSENT PROBE FAIL (%d)" % _failures.size())
		quit(1)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  [OK] %s" % label)
	else:
		_failures.append(label)
