extends MarginContainer
## AttentionRail — Z3, the ONE attention slot (rule 5). Fed exclusively by
## AttentionDirector via UiEvents.attention_changed. Tapping routes to the
## item's target tab/overlay. Collapses when the director has nothing.

var _panel: Button
var _label: Label
var _value: Label
var _bar: UiPrims.MiniBar
var _item: Dictionary = {}


func _ready() -> void:
	for side in ["left", "right"]:
		add_theme_constant_override("margin_" + side, 10)
	add_theme_constant_override("margin_top", 8)

	_panel = Button.new()
	_panel.custom_minimum_size = Vector2(0, 48)
	_panel.clip_text = true
	add_child(_panel)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.INK_FIELD, 0.88)
	sb.border_color = GameTheme.GOLD
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 7
	for st in ["normal", "hover", "pressed", "focus"]:
		_panel.add_theme_stylebox_override(st, sb)
	_panel.pressed.connect(_on_tapped)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)

	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(h)

	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_label.add_theme_color_override("font_color", GameTheme.TEXT)
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_label)

	_value = Label.new()
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_value.add_theme_font_override("font", GameFonts.mono(true))
	_value.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_value.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_value)

	_bar = UiPrims.mini_bar(GameTheme.GOLD, 2.0)
	_bar.custom_minimum_size = Vector2(0, 2)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.visible = false
	col.add_child(_bar)

	visible = false
	UiEvents.attention_changed.connect(_on_attention)


func _on_attention(item: Dictionary) -> void:
	_item = item
	if item.is_empty():
		visible = false
		return
	visible = true
	_label.text = str(item.get("text", ""))
	_value.text = str(item.get("value", ""))
	_value.visible = not _value.text.is_empty()
	var frac := float(item.get("progress", -1.0))
	if frac >= 0.0:
		_bar.visible = true
		_bar.progress = frac
	else:
		_bar.visible = false
	var kind := str(item.get("kind", ""))
	var accent := GameTheme.GOLD
	match kind:
		"raid":
			accent = GameTheme.RED
		"prestige_ready", "goal_done":
			accent = GameTheme.GOLD_BRIGHT
		"op_collect":
			accent = GameTheme.GREEN
		"manager_order":
			accent = GameTheme.GOLD_BRIGHT
		"hint", "afford":
			accent = Color(GameTheme.GOLD, 0.55)
		"goal":
			accent = GameTheme.GOLD
	var style := _panel.get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style.border_color = accent
		_bar.fill = accent


func _on_tapped() -> void:
	if _item.is_empty():
		return
	var kind := str(_item.get("kind", ""))
	Telemetry.log_event("ui_rail_tap", {"kind": kind})
	UiEvents.rail_action.emit(kind)
	if kind == "manager_order" and GameState.approve_manager_order():
		return
	var target := str(_item.get("target", ""))
	match target:
		"prestige":
			UiEvents.overlay_requested.emit("prestige")
		"compact":
			# D5 one-shot offer accepted: veteran density on, reversible in Settings.
			GameState.ui_compact_rows = true
			GameState.stats_changed.emit()
			SaveManager.save_game()
			GameState.notification.emit(
				"Compact ledger ON — change anytime in Settings", GameTheme.GOLD_BRIGHT)
		"ops":
			UiEvents.tab_requested.emit("turf")
			UiEvents.subtab_requested.emit("ops")
		"bldgs", "upgrs", "mgrs", "turf", "stats":
			UiEvents.tab_requested.emit(target)
		_:
			pass
