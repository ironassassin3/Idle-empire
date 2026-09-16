extends SceneTree
const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")
const Sink = preload("res://scripts/autoload/diagnostic_logger.gd")
var _failed := false

func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	call_deferred("_run")

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("FAIL " + message)

func _run() -> void:
	var reporter := root.get_node("CrashReporter")
	_check(reporter.report_text().contains("PREVIOUS_SESSION_TEST_EVIDENCE"), "previous interrupted session retained")
	push_error("INTENTIONAL_DIAGNOSTICS_PROBE")
	_check(reporter.report_text().contains("INTENTIONAL_DIAGNOSTICS_PROBE"), "engine errors captured synchronously")
	_check(reporter.report_text().contains("crash_reporter_probe.gd"), "source location captured")
	var sink = reporter.get("_sink")
	for i in 100:
		sink.record("ROTATE_%d " % i + "x".repeat(8192))
	for path in [Sink.PATH, Sink.PATH + ".old"]:
		var file := FileAccess.open(path, FileAccess.READ)
		_check(file != null and file.get_length() <= Sink.LIMIT + 16384, "bounded log " + path)
	_check(reporter.report_text().contains("PREVIOUS_SESSION_TEST_EVIDENCE"), "rotation preserves incident")
	# Exercise the dialog with real engine Controls, including clear and reopen.
	reporter.show_report()
	await process_frame
	var dialog: AcceptDialog = reporter.get("_dialog")
	_check(is_instance_valid(dialog) and dialog.visible, "diagnostics dialog opens")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("D:/2d_game/_audit/crash_diagnostics.png")
	dialog.custom_action.emit(&"clear")
	_check(not reporter.report_text().contains("PREVIOUS_SESSION_TEST_EVIDENCE"), "clear removes incident")
	dialog.confirmed.emit()
	await process_frame
	reporter.show_report()
	_check(is_instance_valid(reporter.get("_dialog")), "dialog reopens")
	print("CRASH_REPORTER %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
