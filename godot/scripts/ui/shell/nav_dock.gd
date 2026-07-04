extends PanelContainer
## NavDock — Z5, the bottom chrome band. 5 tabs (Phase 100 IA stands), icon +
## label, READY badge dots fed by AttentionDirector via UiEvents.badges_changed.

const TABS := [
	["bldgs", "buildings", "Bldgs"],
	["upgrs", "trend-up", "Upgrs"],
	["mgrs", "users-three", "Mgrs"],
	["turf", "map-pin", "Turf"],
	["stats", "chart-bar", "Stats"],
]

var _slots: Dictionary = {}   # tab_id -> {btn, fill, icon, label, dot}
var _active := "bldgs"

# ADR-002: long-pressing anywhere on the dock opens the boss up-sheet
# (Settings / Luck Wheel / Dragon) so no session-critical action needs the
# red-zone masthead.
const _LONG_PRESS_SECS := 0.5
var _press_timer: SceneTreeTimer
var _long_press_fired := false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 68)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.INK_FIELD, 0.97)
	sb.border_color = Color(GameTheme.GOLD, 0.4)
	sb.border_width_top = 1
	add_theme_stylebox_override("panel", sb)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	add_child(pad)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	pad.add_child(h)

	for t in TABS:
		h.add_child(_build_tab(str(t[0]), str(t[1]), str(t[2])))

	UiEvents.badges_changed.connect(_on_badges)
	set_active("bldgs")


func _build_tab(tab_id: String, icon: String, label: String) -> Control:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56)
	btn.pressed.connect(func():
		if _long_press_fired:
			_long_press_fired = false
			return
		UiEvents.tab_requested.emit(tab_id))
	btn.button_down.connect(_on_any_down)
	btn.button_up.connect(_on_any_up)

	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(5)
	fill.bg_color = Color(0, 0, 0, 0)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, fill)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)

	var tex := TextureRect.new()
	tex.texture = GameIcons.texture(icon)
	tex.custom_minimum_size = Vector2(22, 22)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.modulate = GameTheme.TEXT_MUTED
	v.add_child(tex)

	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameFonts.heading())
	l.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(l)

	var dot := UiPrims.BadgeDot.new()
	dot.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dot.offset_left = 14.0
	dot.offset_top = 3.0
	dot.offset_right = 24.0
	dot.offset_bottom = 13.0
	dot.visible = false
	btn.add_child(dot)

	_slots[tab_id] = {"btn": btn, "fill": fill, "icon": tex, "label": l, "dot": dot}
	return btn


func _on_any_down() -> void:
	_long_press_fired = false
	_press_timer = get_tree().create_timer(_LONG_PRESS_SECS)
	_press_timer.timeout.connect(_on_long_press)


func _on_any_up() -> void:
	_press_timer = null


func _on_long_press() -> void:
	# Timer identity check: only the still-held press may fire.
	if _press_timer == null:
		return
	_press_timer = null
	_long_press_fired = true
	UiEvents.overlay_requested.emit("boss")


func set_active(tab_id: String) -> void:
	_active = tab_id
	for id in _slots:
		var s: Dictionary = _slots[id]
		var active: bool = id == tab_id
		(s["fill"] as StyleBoxFlat).bg_color = GameTheme.GOLD if active else Color(0, 0, 0, 0)
		(s["icon"] as TextureRect).modulate = GameTheme.GOLD_TEXT_DARK if active else GameTheme.TEXT_MUTED
		(s["label"] as Label).add_theme_color_override(
			"font_color", GameTheme.GOLD_TEXT_DARK if active else GameTheme.TEXT_MUTED)
		# Badge dot hides on the active tab (you're already looking at it).
		if active:
			(s["dot"] as Control).visible = false


func _on_badges(counts: Dictionary) -> void:
	for id in _slots:
		var s: Dictionary = _slots[id]
		var n := int(counts.get(id, 0))
		(s["dot"] as Control).visible = n > 0 and id != _active
