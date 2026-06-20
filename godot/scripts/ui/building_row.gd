extends PanelContainer

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

signal buy_pressed(index: int, qty: int)

var building_index: int = -1
var _building: Building
var _affordance: int = GameTheme.RowAffordance.LOCKED

@onready var _name: Label = $Margin/HBox/Info/NameLabel
@onready var _desc: Label = $Margin/HBox/Info/DescLabel
@onready var _owned: Label = $Margin/HBox/Info/OwnedLabel
@onready var _income: Label = $Margin/HBox/Info/IncomeLabel
@onready var _buy1: Button = $Margin/HBox/Buy1
@onready var _buy10: Button = $Margin/HBox/Buy10
@onready var _buy_max: Button = $Margin/HBox/BuyMax


func setup(index: int) -> void:
	building_index = index
	_building = GameState.buildings[index]
	_desc.text = _building.description
	_refresh()


func _ready() -> void:
	for btn in [_buy1, _buy10, _buy_max]:
		GameTheme.apply_row_buy_button(btn)
	_apply_label_scale()
	_buy1.pressed.connect(_on_buy_primary)
	_buy10.pressed.connect(func(): buy_pressed.emit(building_index, 10))
	_buy_max.pressed.connect(_on_buy_max)
	GameState.stats_changed.connect(_refresh)
	if building_index >= 0:
		_refresh()


func _apply_label_scale() -> void:
	_name.add_theme_font_size_override("font_size", GameTheme.scaled_font(15))
	_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_owned.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_income.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))


func _draw() -> void:
	GameTheme.draw_row_wax_seal(self, _affordance)


func _refresh() -> void:
	if building_index < 0 or building_index >= GameState.buildings.size():
		return
	_building = GameState.buildings[building_index]
	var pete_pick := _ManagerSystem.pete_recommends_index(GameState)
	var is_pete := pete_pick == building_index
	if is_pete:
		_name.text = "★ %s" % _building.display_name
	else:
		_name.text = _building.display_name
	_owned.text = "Owned: %d" % _building.owned
	_income.text = "%s/s" % FormatUtil.format_money(_building.income_per_second())
	var qty := GameState.effective_buy_qty(building_index)
	var cost_qty := _building.cost_for_n(qty)
	_buy1.text = "%s\n%s" % [GameState.buy_mult_label(), FormatUtil.format_money(cost_qty)]
	_buy10.text = "×10\n%s" % FormatUtil.format_money(_building.cost_for_n(10))
	var max_n := GameState.max_affordable_building(building_index)
	_buy_max.text = "Max (%d)" % max_n if max_n > 0 else "Max"
	var can_primary := GameState.can_buy_building(building_index, qty)
	_buy1.disabled = not can_primary
	_buy10.disabled = not GameState.can_buy_building(building_index, 10)
	_buy_max.disabled = max_n <= 0
	var can_any := GameState.can_buy_building(building_index, 1)
	if is_pete and can_any:
		_affordance = GameTheme.RowAffordance.PETE
	elif can_any:
		_affordance = GameTheme.RowAffordance.BUYABLE
	else:
		_affordance = GameTheme.RowAffordance.LOCKED
	GameTheme.apply_row_affordance(self, _affordance)
	modulate = Color.WHITE


func _on_buy_primary() -> void:
	var qty := GameState.effective_buy_qty(building_index)
	if qty > 0:
		buy_pressed.emit(building_index, qty)


func _on_buy_max() -> void:
	var n := GameState.max_affordable_building(building_index)
	if n > 0:
		buy_pressed.emit(building_index, n)
