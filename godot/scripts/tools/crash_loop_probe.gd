extends SceneTree
## Proves the launch-loop breaker: a save that kills the boot is quarantined, two
## failed launches enter safe mode, and one healthy session clears the tally.
##
## The tester case this exists for: the game crashed mid-session, and every
## launch afterwards closed instantly. Nothing in the app noticed it was in a
## loop, so nothing ever broke out of it.
##
##   godot --headless --path godot -s res://scripts/tools/crash_loop_probe.gd

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")

const MARKER := "user://diagnostics/session.json"
const SAVE := "user://save.json"
const BACKUP := "user://save.json.bak"
const BROKEN := "user://save.json.broken"

var _failed := false
var _reporter_script: GDScript


func _initialize() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("_audit/runtime"):
		printerr("Set APPDATA to a workspace _audit/runtime directory first")
		quit(2)
		return
	Autoloads.install(self)
	_reporter_script = load("res://scripts/autoload/crash_reporter.gd")
	call_deferred("_run")


func _run() -> void:
	_test_boot_failure_counting()
	_test_save_quarantine()
	_test_repair_keeps_the_file()
	_test_save_on_pause()
	print("CRASH_LOOP %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)


## A fresh instance of the autoload re-runs _init against whatever marker is on
## disk, which is exactly what a relaunch does.
func _boot(marker: Dictionary) -> Node:
	DirAccess.make_dir_recursive_absolute("user://diagnostics")
	if marker.is_empty():
		if FileAccess.file_exists(MARKER):
			DirAccess.remove_absolute(MARKER)
	else:
		_write(MARKER, JSON.stringify(marker))
	var reporter: Node = _reporter_script.new()
	return reporter


func _test_boot_failure_counting() -> void:
	var first := _boot({})
	_check(not first.safe_mode and first.boot_failures == 0, "first launch is not in safe mode")
	_free(first)

	var died_early := _boot({"status": "boot", "healthy": false, "boot_failures": 0})
	_check(died_early.boot_failures == 1, "a launch that died before healthy counts once")
	_check(not died_early.safe_mode, "one failed launch is not yet safe mode")
	_free(died_early)

	var twice := _boot({"status": "loading_save", "healthy": false, "boot_failures": 1})
	_check(twice.boot_failures == 2 and twice.safe_mode, "two failed launches enter safe mode")
	_check(twice.save_suspect, "a launch that died while loading blames the save")
	_free(twice)

	# The 20-minute device crash: the session was healthy, so the next launch is
	# normal — it must not strip sound and ads off a player who can still play.
	var healthy_crash := _boot({"status": "running", "healthy": true, "boot_failures": 0})
	_check(not healthy_crash.safe_mode and healthy_crash.boot_failures == 0,
		"a crash after a healthy session does not trigger safe mode")
	_check(healthy_crash.report_text().contains("Previous session ended without a clean exit"),
		"the crash is still reported")
	_free(healthy_crash)

	# Android reclaiming a backgrounded process is not a failed launch.
	var backgrounded := _boot({"status": "background", "healthy": false, "boot_failures": 1})
	_check(backgrounded.boot_failures == 0 and not backgrounded.safe_mode,
		"a background kill does not count as a failed launch")
	_free(backgrounded)

	var clean := _boot({"status": "clean_exit", "healthy": true, "boot_failures": 0})
	_check(clean.boot_failures == 0, "a clean exit clears the tally")
	_free(clean)


func _test_save_quarantine() -> void:
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	var reporter := root.get_node("CrashReporter")
	gs.reset_new_game()
	gs.balance = 4242.0
	gs.last_login_date = Time.get_date_string_from_system()
	saves.save_game()
	saves.save_game()  # second write promotes the good primary into the backup
	# A save that parses fine but takes the app down while it is applied: the
	# file is not the evidence, the phase marker is.
	_write(SAVE, '{"balance": 1.0, "prestige_count": 0, "prestige_tokens": 0, "play_time": 0.0}')
	reporter.save_suspect = true
	saves.recover_from_failed_boot()
	_check(not FileAccess.file_exists(SAVE), "the suspect save is out of the boot path")
	_check(FileAccess.file_exists(BROKEN), "the suspect save is kept for support")
	_check(saves.has_save() and saves.load_game(), "the backup still loads")
	_check(is_equal_approx(float(gs.balance), 4242.0)
		or absf(float(gs.balance) - 4242.0) < 1000.0, "the backup restored real progress")
	_check(not reporter.recovery_note.is_empty(), "the player is told what happened")
	# Second failure in a row: with the primary already gone, the backup is next.
	reporter.save_suspect = true
	saves.recover_from_failed_boot()
	_check(not FileAccess.file_exists(BACKUP), "a second failed launch retires the backup too")
	_check(not saves.has_save(), "no save is left to crash on")


func _test_repair_keeps_the_file() -> void:
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	gs.reset_new_game()
	gs.balance = 777.0
	gs.last_login_date = Time.get_date_string_from_system()
	saves.save_game()
	saves.save_game()
	var recovered: bool = saves.repair_save()
	_check(recovered, "repair falls back to a readable backup")
	_check(FileAccess.file_exists(BROKEN), "repair never destroys the players save")


## Android kills backgrounded processes without a second warning; the pause
## notification is the last point at which a run can be written.
func _test_save_on_pause() -> void:
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	saves.delete_save()  # this resets the game, so seed the date afterwards
	gs.last_login_date = Time.get_date_string_from_system()
	gs.set_simulation_active(true)
	gs.balance = 31337.0
	gs.notification(NOTIFICATION_APPLICATION_PAUSED)
	_check(FileAccess.file_exists(SAVE), "backgrounding the app writes the save")
	gs.balance = 0.0
	_check(saves.load_game() and absf(float(gs.balance) - 31337.0) < 1.0,
		"the save written on pause loads back")
	gs.set_simulation_active(false)
	saves.delete_save()


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _free(reporter: Node) -> void:
	reporter.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("FAIL " + message)
	else:
		print("ok: " + message)
