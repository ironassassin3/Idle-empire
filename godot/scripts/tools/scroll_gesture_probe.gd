extends SceneTree
## Uses the engine's touch-emulation and real viewport dispatch, not signal-only tests.
const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")
const CASES := [
	{"name": "buildings", "tests_button": true},
	{"name": "upgrades", "tests_button": true},
	{"name": "config", "tests_button": true},
	{"name": "turf", "tests_button": false},
	{"name": "turf:rivals", "tests_button": true},
	{"name": "stats", "tests_button": false},
]
var failures: Array[String] = []
var sv: SubViewport
var presses := 0

func _initialize() -> void:
	Autoloads.install(self)
	Input.emulate_touch_from_mouse = true
	call_deferred("_run")

func _run() -> void:
	await _settle()  # Finish deferred autoload initialization before seeding.
	_check("touch emulation available", DisplayServer.is_touchscreen_available())
	var gs := root.get_node("GameState")
	gs.reset_new_game()
	gs.balance = 1e21
	gs.lifetime_earnings = 1e21
	gs.prestige_tokens = 30
	for building in gs.buildings:
		building.owned = 20
	gs.tutorial_step = 99
	for probe_case in CASES:
		var screen_name: String = probe_case["name"]
		var tests_button: bool = probe_case["tests_button"]
		sv = SubViewport.new()
		sv.size = Vector2i(720, 500)
		root.add_child(sv)
		var screen: Control = load("res://scripts/ui/screens/" + screen_name.split(":")[0] + "_screen.gd").new()
		sv.add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen.on_show()
		if screen_name.contains(":"):
			screen.set_subtab(screen_name.split(":")[1])
		await _settle()
		var scroll := _find_scroll(screen)
		_check(screen_name + " has scrolling content", scroll != null and scroll.get_v_scroll_bar().max_value > 500)
		if scroll != null:
			var button: Button = _find_button(scroll) if tests_button else null
			if tests_button:
				_check(screen_name + " has visible enabled button", button != null)
			else:
				print(screen_name, " button interaction: scroll-only case")
			var start := Vector2(350, 250)
			if button != null:
				start = button.get_global_rect().get_center()
				button.pressed.connect(func(): presses += 1)
			presses = 0
			_mouse(start, true)
			for i in range(1, 9):
				var event := InputEventMouseMotion.new()
				event.position = start - Vector2(0, i * 15)
				event.global_position = event.position
				event.relative = Vector2(0, -15)
				event.button_mask = MOUSE_BUTTON_MASK_LEFT
				sv.push_input(event)
				await process_frame
			_mouse(start - Vector2(0, 120), false)
			_check(screen_name + " vertical drag scrolls", scroll.scroll_vertical > 0)
			if tests_button and button != null:
				_check(screen_name + " drag does not activate button", presses == 0)
				presses = 0
				await _settle()
				scroll.scroll_vertical = 0
				await _settle()
				var button_still_tappable := _button_is_tappable(button)
				_check(screen_name + " button remains visible and enabled for tap", button_still_tappable)
				if button_still_tappable:
					start = button.get_global_rect().get_center()
					_mouse(start, true)
					_mouse(start, false)
					_check(screen_name + " deliberate tap fires exactly once", presses == 1)
		# These screens own detached header/footer controls in standalone probes.
		var header: Control = screen.header_control()
		if header != null and header.get_parent() == null:
			header.free()
		if screen_name == "upgrades":
			var footer: Control = screen.get("_footer")
			if footer != null and footer.get_parent() == null:
				footer.free()
		sv.queue_free()
		await process_frame
	await _settle()
	for failure in failures:
		printerr(failure)
	print("SCROLL GESTURE ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	for i in 12:
		await process_frame

func _mouse(pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	sv.push_input(event)

func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null

func _find_button(node: Node) -> Button:
	if node is Button and _button_is_tappable(node):
		return node
	for child in node.get_children():
		var found := _find_button(child)
		if found != null:
			return found
	return null

func _button_is_tappable(button: Button) -> bool:
	if not button.is_visible_in_tree() or button.disabled:
		return false
	var rect := button.get_global_rect()
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(sv.size))
	return viewport_rect.has_point(rect.get_center()) and rect.end.y < 450

func _check(label: String, ok: bool) -> void:
	print(label, ": ", ok)
	if not ok:
		failures.append(label)
