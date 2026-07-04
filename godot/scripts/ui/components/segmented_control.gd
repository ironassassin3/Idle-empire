class_name SegmentedControl
extends HBoxContainer
## ×1 / ×10 / MAX buy-quantity control — lives in the sheet header next to the
## buy context it modifies (fixes D4). Binds directly to GameState.buy_mult_mode.

const OPTIONS := [["×1", 0], ["×10", 1], ["MAX", 2]]

var _buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	for i in OPTIONS.size():
		var b := Button.new()
		b.text = str(OPTIONS[i][0])
		b.custom_minimum_size = Vector2(52, 48)
		b.add_theme_font_override("font", GameFonts.mono(true))
		b.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
		var mode := int(OPTIONS[i][1])
		b.pressed.connect(func(): _select(mode))
		add_child(b)
		_buttons.append(b)
	_restyle()
	GameState.stats_changed.connect(_restyle)


func _select(mode: int) -> void:
	GameState.buy_mult_mode = mode
	GameState.stats_changed.emit()
	Telemetry.log_event("ui_buy_mult_changed", {"mode": GameState.buy_mult_label()})


func _restyle() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var active: bool = GameState.buy_mult_mode == int(OPTIONS[i][1])
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameTheme.GOLD if active else Color(GameTheme.CHIP_BG, 0.9)
		sb.border_color = Color(GameTheme.GOLD, 0.6)
		sb.set_border_width_all(1)
		if i == 0:
			sb.corner_radius_top_left = 5
			sb.corner_radius_bottom_left = 5
		if i == _buttons.size() - 1:
			sb.corner_radius_top_right = 5
			sb.corner_radius_bottom_right = 5
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override(
			"font_color", GameTheme.GOLD_TEXT_DARK if active else GameTheme.TEXT_MUTED)
