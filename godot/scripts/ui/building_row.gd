extends PanelContainer

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

signal buy_pressed(index: int, qty: int)

var building_index: int = -1
var _building: Building
var _affordance: int = GameTheme.RowAffordance.LOCKED

@onready var _medal: CountMedallion = $Margin/HBox/Medal
@onready var _name: Label = $Margin/HBox/Info/NameLabel
@onready var _desc: Label = $Margin/HBox/Info/DescLabel
@onready var _special: Label = $Margin/HBox/Info/SpecialLabel
@onready var _owned: Label = $Margin/HBox/Info/OwnedLabel
@onready var _income: Label = $Margin/HBox/Info/IncomeLabel
@onready var _buy1: Button = $Margin/HBox/Buy1
@onready var _buy10: Button = $Margin/HBox/Buy10
@onready var _buy_max: Button = $Margin/HBox/BuyMax


func setup(index: int) -> void:
	building_index = index
	_building = GameState.buildings[index]
	_desc.text = _building.description
	_medal.initial = _building.display_name.left(1)
	_medal.hue_index = index
	_medal.signature_key = _building.icon_key
	_apply_special_line()
	_refresh()


func _ready() -> void:
	for btn in [_buy1, _buy10, _buy_max]:
		GameTheme.apply_row_buy_button(btn)
	# Genre convention (AdCap): ONE fat buy button per row; quantity comes
	# from the global ×1/×10/Max chip in the masthead.
	_buy10.visible = false
	_buy_max.visible = false
	_buy1.custom_minimum_size = Vector2(118, 56)
	_buy1.add_theme_font_override("font", GameFonts.heading())
	_buy1.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_apply_label_scale()
	_buy1.pressed.connect(_on_buy_primary)
	_buy10.pressed.connect(func(): buy_pressed.emit(building_index, 10))
	_buy_max.pressed.connect(_on_buy_max)
	GameState.stats_changed.connect(_refresh)
	if building_index >= 0:
		_refresh()


func _apply_label_scale() -> void:
	GameTheme.apply_row_title(_name, 16)
	_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_special.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_owned.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_income.add_theme_font_override("font", GameFonts.mono(false))
	_income.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_income.add_theme_color_override("font_color", GameTheme.GREEN)


func _apply_special_line() -> void:
	if _building == null or _building.special.is_empty():
		_special.visible = false
		_special.text = ""
		return
	_special.visible = true
	_special.text = "* %s" % _building.special


# Rule 10 (Stage & Ledger): progress-to-afford underbar while APPROACHING.
var _afford := 0.0


func _draw() -> void:
	GameTheme.draw_row_wax_seal(self, _affordance)
	if _afford > 0.0 and _afford < 1.0:
		draw_rect(Rect2(0, size.y - 3.0, size.x, 3.0), Color(GameTheme.GOLD, 0.14))
		draw_rect(Rect2(0, size.y - 3.0, size.x * _afford, 3.0), GameTheme.GOLD)


func _refresh() -> void:
	if building_index < 0 or building_index >= GameState.buildings.size():
		return
	_building = GameState.buildings[building_index]
	# Supremacy N8 veteran density: compact rows keep name + cost + underbar
	# only; touch targets stay at the 48px floor.
	if GameConfig.UI_SHELL_V3:
		var compact: bool = GameState.ui_compact_rows
		_desc.visible = not compact
		_special.visible = not compact and not _building.special.is_empty()
		_income.visible = not compact
		_owned.visible = not compact
		custom_minimum_size.y = 64.0 if compact else 0.0
		_buy1.custom_minimum_size = Vector2(118, 48 if compact else 56)
	var advisor_idx := _ManagerSystem.building_advisor_index(GameState)
	var is_advised := advisor_idx == building_index
	var prefix := _ManagerSystem.building_advisor_prefix(GameState, building_index)
	if is_advised and not prefix.is_empty():
		_name.text = "%s%s" % [prefix, _building.display_name]
	else:
		_name.text = _building.display_name
	_apply_special_line()
	var dim := _building.owned <= 0
	_special.add_theme_color_override(
		"font_color",
		GameTheme.BLUE_BRIGHT if not dim else GameTheme.TEXT_MUTED
	)
	_owned.text = "Owned: %d" % _building.owned
	_income.text = "%s/s" % FormatUtil.format_money(_building.income_per_second())
	var qty := GameState.effective_buy_qty(building_index)
	var cost_qty := _building.cost_for_n(qty)
	_buy1.text = "BUY %s\n%s" % [GameState.buy_mult_label(), FormatUtil.format_money(cost_qty)]
	_buy10.text = "×10\n%s" % FormatUtil.format_money(_building.cost_for_n(10))
	var max_n := GameState.max_affordable_building(building_index)
	_buy_max.text = "Max (%d)" % max_n if max_n > 0 else "Max"
	var can_primary := GameState.can_buy_building(building_index, qty)
	_buy1.disabled = not can_primary
	_buy10.disabled = not GameState.can_buy_building(building_index, 10)
	_buy_max.disabled = max_n <= 0
	var can_any := GameState.can_buy_building(building_index, 1)
	if is_advised and can_any:
		_affordance = GameTheme.RowAffordance.PETE
	elif can_any:
		_affordance = GameTheme.RowAffordance.BUYABLE
	else:
		_affordance = GameTheme.RowAffordance.LOCKED
	_medal.count = _building.owned
	_medal.locked = _affordance == GameTheme.RowAffordance.LOCKED and _building.owned <= 0
	GameTheme.apply_row_affordance(self, _affordance)
	if GameConfig.UI_SHELL_V3:
		Affordance.apply_action_button(
			_buy1, Affordance.READY if can_primary else Affordance.APPROACHING)
		_afford = 0.0 if can_primary else Affordance.progress(cost_qty, GameState.balance)
		queue_redraw()
	modulate = Color.WHITE


func _on_buy_primary() -> void:
	var qty := GameState.effective_buy_qty(building_index)
	if qty > 0:
		buy_pressed.emit(building_index, qty)


func _on_buy_max() -> void:
	var n := GameState.max_affordable_building(building_index)
	if n > 0:
		buy_pressed.emit(building_index, n)
