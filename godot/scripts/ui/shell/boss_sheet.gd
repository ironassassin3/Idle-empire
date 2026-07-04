extends Control
## BossSheet — the thumb-zone up-sheet (ADR-002, owner decision D2).
## Long-pressing the nav dock slides this small sheet up from the dock with
## the actions that used to live only in the red-zone masthead: Settings,
## Luck Wheel, Dragon. Masthead chips remain as mirrors.

const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

var _scrim: ColorRect
var _panel: PanelContainer
var _wheel_row: Button
var _dragon_row: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.45)
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(_on_scrim_input)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.INK_FIELD, 0.97)
	sb.border_color = Color(GameTheme.GOLD, 0.4)
	sb.border_width_top = 1
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	# Anchored to the bottom, riding just above the dock (68px + margin).
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 8.0
	_panel.offset_right = -8.0
	_panel.offset_bottom = -74.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	var handle := UiPrims.Handle.new()
	handle.custom_minimum_size = Vector2(0, 12)
	v.add_child(handle)

	v.add_child(_make_row("gear", "Settings", func():
		close()
		UiEvents.overlay_requested.emit("config")))
	_wheel_row = _make_row("", "🎯  Luck Wheel", func():
		close()
		UiEvents.overlay_requested.emit("gambling"))
	v.add_child(_wheel_row)
	_dragon_row = _make_row("", "Dragon Patron", func():
		close()
		UiEvents.overlay_requested.emit("dragon"))
	v.add_child(_dragon_row)


func _make_row(icon: String, label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", GameFonts.heading())
	b.add_theme_font_size_override("font_size", GameTheme.scaled_font(15))
	b.add_theme_color_override("font_color", GameTheme.TEXT)
	b.add_theme_color_override("font_hover_color", GameTheme.GOLD_BRIGHT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameTheme.STATE_APPROACH_BG
	sb.border_color = GameTheme.STATE_APPROACH_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	if not icon.is_empty():
		b.icon = GameIcons.texture(icon)
		b.add_theme_constant_override("icon_max_width", 20)
		b.add_theme_color_override("icon_normal_color", GameTheme.GOLD)
	b.pressed.connect(on_press)
	return b


func open() -> void:
	# Disclosure mirrors the masthead chips.
	_wheel_row.visible = GameConfig.GAMBLING_ENABLED
	var spins: int = GameState.gambling_free_spins()
	_wheel_row.text = "🎯  Luck Wheel" + ("  ·  %d free spin(s)" % spins if spins > 0 else "")
	_dragon_row.visible = Disclosure.dragon_chip_visible(GameState)
	visible = true
	Telemetry.log_event("ui_boss_sheet_open", {})
	if not GameTheme.ui_reduced_motion():
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.12)


func close() -> void:
	visible = false


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
