extends SceneTree
## v1 service/UI/export contract. No network or purchase actions are invoked.
const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")
var failures: Array[String] = []

func _initialize() -> void:
	Autoloads.install(self)
	call_deferred("_run")

func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset_new_game()
	gs.telemetry_share = true  # Compatibility with a saved old SHARED setting.
	var config: Control = load("res://scripts/ui/screens/config_screen.gd").new()
	root.add_child(config)
	config.on_show()
	var texts: Array[String] = []
	_collect(config, texts)
	_check("DEVICE shown for old sharing consent", "DEVICE" in texts)
	for forbidden in ["Notifications", "Sign in (cloud backup)", "Cloud save: signed in", "SHARED"]:
		_check("no visible " + forbidden, not forbidden in texts)
	for path in ["res://scripts/ui/screens/config_screen.gd", "res://scripts/ui/game_screen.gd"]:
		var source := FileAccess.get_file_as_string(path)
		_check(path + " exposes OFF/DEVICE", source.contains('["OFF", "DEVICE"]'))
		for forbidden in ['"SHARED"', '"Notifications"', "CloudSave.", "Notifications.request_permission"]:
			_check(path + " excludes " + forbidden, not source.contains(forbidden))
	for service in ["Notifications", "CloudSave"]:
		var node := root.get_node(service)
		_check(service + " disabled", not node.get("_enabled"))
		_check(service + " has no backend", node.get("_backend") == null)
	var presets := ConfigFile.new()
	_check("presets load", presets.load("res://export_presets.cfg") == OK)
	var android: Array[String] = []
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Android":
			android.append(section)
	_check("two Android presets", android.size() == 2)
	for section in android:
		_check(section + " no notification permission", not presets.get_value(section + ".options", "permissions/post_notifications", true))
		_check(section + " excludes tools", str(presets.get_value(section, "exclude_filter", "")).contains("scripts/tools/*"))
	if android.size() == 2:
		for key in ["version/code", "version/name", "package/unique_name", "gradle_build/min_sdk", "gradle_build/target_sdk", "permissions/post_notifications", "permissions/internet", "permissions/access_network_state", "permissions/vibrate", "screen/immersive_mode"]:
			_check("preset sync " + key, presets.get_value(android[0] + ".options", key) == presets.get_value(android[1] + ".options", key))
		_check("exclusion sync", presets.get_value(android[0], "exclude_filter") == presets.get_value(android[1], "exclude_filter"))
	config.queue_free()
	for failure in failures:
		printerr(failure)
	print("V1 CONTRACT ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _collect(node: Node, texts: Array[String]) -> void:
	if node is Label or node is Button:
		texts.append(node.text)
	for child in node.get_children():
		_collect(child, texts)

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)
