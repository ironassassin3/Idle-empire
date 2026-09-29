extends SceneTree
## Headless bounds check for the content sheet (ContentDeck).
##
## The deck's own contract: "FULL keeps the dock on screen at every aspect
## ratio". This drags the sheet grab-handle upward repeatedly — the gesture that
## broke on device — and asserts the chrome column still fits the viewport.
##
##   godot --headless --path godot -s res://scripts/tools/deck_bounds_smoke.gd
##
## Regression guarded: the deck used to size itself against
## get_parent_area_size(), which is the very column the deck sits in. Growing
## the sheet grew the parent, which raised the drag ceiling, which grew the
## sheet — a ratchet that walked the nav dock off the bottom of the screen and
## never snapped back.

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const SIZES := [Vector2i(720, 1604), Vector2i(1080, 1920), Vector2i(720, 1280)]
const DRAGS := 4

var _shell: Node
var _sv: SubViewport
var _frames := 0
var _size_index := -1
var _failures := 0
var _drag_from := Vector2.ZERO


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	_next_size()


func _next_size() -> void:
	_size_index += 1
	if _size_index >= SIZES.size():
		if _failures > 0:
			printerr("[deck_bounds] FAIL — %d viewport(s) overflowed" % _failures)
			quit(1)
		else:
			print("[deck_bounds] PASS — sheet stays within every viewport")
			quit(0)
		return
	if _sv != null:
		_sv.queue_free()
		_sv = null
		_shell = null
	# The root window is not resizable headless, so lay the shell out inside a
	# SubViewport sized to the device we are testing (same trick as ui_capture).
	_sv = SubViewport.new()
	_sv.size = SIZES[_size_index]
	_sv.disable_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.gui_embed_subwindows = true
	root.add_child(_sv)
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	_shell = packed.instantiate()
	_sv.add_child(_shell)
	_frames = 0


const SETTLE := 20
const DRAG_FRAMES := 10   # 0 press · 1-6 motion · 7 release · 8-9 settle


func _process(_delta: float) -> bool:
	if _shell == null:
		return false
	_frames += 1
	# One pointer event per frame: the gesture MUST straddle layout passes, or
	# the parent column never re-measures mid-drag and the bug cannot appear.
	var t := _frames - SETTLE
	if t >= 0 and t < DRAGS * DRAG_FRAMES:
		_drag_frame(t % DRAG_FRAMES)
	elif t >= DRAGS * DRAG_FRAMES + SETTLE:
		_check()
		_next_size()
	return false


func _drag_frame(step: int) -> void:
	var from := _handle_pos()
	if from == Vector2.ZERO:
		return
	match step:
		0:
			_drag_from = from
			_push(from, true)
		1, 2, 3, 4, 5, 6:
			var mm := InputEventMouseMotion.new()
			mm.position = Vector2(_drag_from.x, _drag_from.y - float(step) * 90.0)
			mm.global_position = mm.position
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			_sv.push_input(mm)
		7:
			_push(Vector2(_drag_from.x, _drag_from.y - 540.0), false)


func _handle_pos() -> Vector2:
	var deck: Node = _shell.find_child("ContentDeck", true, false)
	if deck == null:
		return Vector2.ZERO
	# Handle is the first child of the deck's column.
	var col: Node = deck.get_child(0)
	var handle: Control = col.get_child(0) as Control
	return handle.get_global_rect().get_center()


func _push(pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	mb.global_position = pos
	_sv.push_input(mb)


func _check() -> void:
	var vp_h := float(_sv.size.y)
	var deck: Control = _shell.find_child("ContentDeck", true, false) as Control
	var dock: Control = _shell.find_child("NavDock", true, false) as Control
	if deck == null or dock == null:
		printerr("[deck_bounds] %dx%d — deck/dock not found" % [_sv.size.x, _sv.size.y])
		_failures += 1
		return
	var dock_bottom := dock.get_global_rect().end.y
	var ok := dock_bottom <= vp_h + 0.5
	print("[deck_bounds] %dx%d deck_h=%.0f dock_bottom=%.0f viewport_h=%.0f %s" % [
		_sv.size.x, _sv.size.y, deck.size.y, dock_bottom, vp_h,
		"OK" if ok else "OVERFLOW",
	])
	if not ok:
		printerr("[deck_bounds] %dx%d — nav dock pushed %.0fpx off screen" % [
			_sv.size.x, _sv.size.y, dock_bottom - vp_h,
		])
		_failures += 1
