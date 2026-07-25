extends PanelContainer
## ContentDeck — Z4, the single content sheet over the stage. Hosts one screen
## per tab, owns the sheet header (title + contextual control slot — the buy
## multiplier lives HERE, fixing D4) and the PEEK/REST/FULL snap states (M4).
## The city is never fully hidden except at FULL.

enum SheetState { PEEK, REST, FULL }

const SNAP_FRACTIONS := {SheetState.PEEK: 0.30, SheetState.REST: 0.55, SheetState.FULL: 0.86}
const SNAP_TIME := 0.22

var state: int = SheetState.REST
var _handle: Control
var _title: Label
var _control_slot: Control
var _host: Control
var _screens: Dictionary = {}      # id -> Control (ScreenBase contract)
var _current_id := ""
var _dragging := false
var _drag_start_y := 0.0
var _drag_start_h := 0.0
var _height_tween: Tween


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameTheme.SHEET_GLASS
	sb.border_color = Color(GameTheme.GOLD, 0.35)
	sb.border_width_top = 1
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)

	_handle = Control.new()
	_handle.custom_minimum_size = Vector2(0, 18)
	_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var notch := UiPrims.Handle.new()
	notch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_handle.add_child(notch)
	_handle.gui_input.connect(_on_handle_input)
	v.add_child(_handle)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(4, 0)
	header.add_child(pad_l)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.add_theme_font_override("font", GameFonts.heading())
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(16))
	_title.add_theme_color_override("font_color", GameTheme.GOLD)
	header.add_child(_title)
	_control_slot = Control.new()
	_control_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(_control_slot)

	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.clip_contents = true
	v.add_child(_host)

	# Re-derive the snap height when the VIEWPORT changes (rotation, window
	# resize) — never on our own `resized`, which fires for every drag delta
	# and tween step and would instantly cancel them.
	get_viewport().size_changed.connect(func(): _apply_state(false))
	_apply_state.call_deferred(false)


func register_screen(id: String, screen: Control) -> void:
	_screens[id] = screen
	screen.visible = false
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.add_child(screen)


func show_screen(id: String) -> void:
	if not _screens.has(id):
		return
	for sid in _screens:
		(_screens[sid] as Control).visible = sid == id
	_current_id = id
	var screen: Control = _screens[id]
	_title.text = str(screen.call("screen_title")) if screen.has_method("screen_title") else id.to_upper()
	# Swap the contextual control (segmented buy control, subtab bar hooks...).
	for c in _control_slot.get_children():
		_control_slot.remove_child(c)
	var ctl: Control = screen.call("header_control") if screen.has_method("header_control") else null
	if ctl != null:
		_control_slot.add_child(ctl)
		_control_slot.custom_minimum_size = ctl.get_combined_minimum_size()
	else:
		_control_slot.custom_minimum_size = Vector2.ZERO
	if screen.has_method("on_show"):
		screen.call("on_show")


func current_screen() -> Control:
	return _screens.get(_current_id)


func current_id() -> String:
	return _current_id


# --------------------------------------------------------------- snap states

func set_sheet_state(new_state: int, animate: bool = true) -> void:
	if state == new_state:
		return
	state = new_state
	_apply_state(animate)
	UiEvents.sheet_state_changed.emit(state)
	Telemetry.log_event("ui_sheet_state", {"state": state})


# Floor for the chrome reserve, used only before the column has been measured
# once (boot). The real reserve is measured — see _max_height().
const CHROME_RESERVE_FLOOR := 200.0


## The sheet must be measured against the VIEWPORT, never against our own
## parent. The parent is the chrome column we live in: its size grows when our
## min height grows, so sizing off it let each drag raise its own ceiling — a
## ratchet that walked the nav dock off the bottom of the screen and, because
## _snap_to_nearest divided by the same inflated number, never snapped back.
func _viewport_height() -> float:
	return float(get_viewport_rect().size.y)


## Every px in the column that isn't us: masthead + rail + dock + separations,
## taken from the column's own minimum size with our contribution removed, so
## the result cannot move when we resize. Plus margins outside the column
## (safe-area insets), which the old fixed 260 forgot to count.
func _max_height() -> float:
	var others := 0.0
	var parent := get_parent()
	if parent is Control:
		others = (parent as Control).get_combined_minimum_size().y - get_combined_minimum_size().y
	others = maxf(others, CHROME_RESERVE_FLOOR) + _outer_insets()
	return maxf(120.0, _viewport_height() - others)


func _outer_insets() -> float:
	var insets := 0.0
	var node := get_parent()
	while node != null and node is Control:
		if node is MarginContainer:
			insets += float(node.get_theme_constant("margin_top")) \
				+ float(node.get_theme_constant("margin_bottom"))
		node = node.get_parent()
	return insets


func _target_height() -> float:
	return minf(_viewport_height() * float(SNAP_FRACTIONS[state]), _max_height())


func _apply_state(animate: bool) -> void:
	var target := _target_height()
	if _height_tween != null and _height_tween.is_running():
		_height_tween.kill()
	if animate and not GameTheme.ui_reduced_motion():
		_height_tween = create_tween()
		_height_tween.tween_property(self, "custom_minimum_size:y", target, SNAP_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		custom_minimum_size.y = target


func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging = true
			_drag_start_y = mb.global_position.y
			_drag_start_h = size.y
		else:
			if _dragging and absf(mb.global_position.y - _drag_start_y) < 6.0:
				# Tap: toggle REST ↔ FULL.
				set_sheet_state(SheetState.REST if state == SheetState.FULL else SheetState.FULL)
			else:
				_snap_to_nearest()
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var dy := (event as InputEventMouseMotion).global_position.y - _drag_start_y
		# Ceiling is _max_height(), the same bound the snap states honour — a
		# drag may never reach a height the sheet cannot snap back from.
		var h := clampf(_drag_start_h - dy, _viewport_height() * 0.24, _max_height())
		custom_minimum_size.y = h


func _snap_to_nearest() -> void:
	var frac := size.y / maxf(1.0, _viewport_height())
	var best: int = SheetState.REST
	var best_d := 99.0
	for s in SNAP_FRACTIONS:
		var d: float = absf(frac - float(SNAP_FRACTIONS[s]))
		if d < best_d:
			best_d = d
			best = s
	if best == state:
		_apply_state(true)
	else:
		set_sheet_state(best)
