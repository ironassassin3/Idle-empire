extends SceneTree
const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")
var failures: Array[String] = []
var deck: Control

func _initialize() -> void:
	Autoloads.install(self)
	call_deferred("_run")

func _run() -> void:
	deck = load("res://scripts/ui/shell/content_deck.gd").new()
	root.add_child(deck)
	await process_frame
	deck.set_sheet_state(2, true)
	_button(true, 500)
	var tween: Tween = deck.get("_height_tween")
	_check("new press stops active snap tween", tween == null or not tween.is_running())
	_button(false, 500, true)
	deck.call("_apply_state", false)
	await process_frame
	_button(true, 500)
	var start := deck.custom_minimum_size.y
	_motion(503)
	_check("sub-threshold motion leaves height alone", is_equal_approx(start, deck.custom_minimum_size.y))
	_motion(450)
	_motion(500)
	_button(false, 500)
	_check("drag out and back is not a tap", deck.state == 2)
	_button(true, 500)
	_button(false, 500, true)
	_check("cancel does not toggle", deck.state == 2)
	_button(false, 500)
	_check("unpaired release does not toggle", deck.state == 2)
	deck.queue_free()
	for failure in failures:
		printerr(failure)
	print("DECK GESTURE ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _button(pressed: bool, y: float, canceled: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.canceled = canceled
	event.global_position = Vector2(100, y)
	deck._on_handle_input(event)

func _motion(y: float) -> void:
	var event := InputEventMouseMotion.new()
	event.global_position = Vector2(100, y)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	deck._on_handle_input(event)

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures.append(label)
