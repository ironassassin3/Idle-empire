extends Control

signal buy_pressed(index: int, qty: int)

var building_index: int = -1
var _building: Building

@onready var _name: Label = $HBox/Info/NameLabel
@onready var _desc: Label = $HBox/Info/DescLabel
@onready var _owned: Label = $HBox/Info/OwnedLabel
@onready var _income: Label = $HBox/Info/IncomeLabel
@onready var _buy1: Button = $HBox/Buy1
@onready var _buy10: Button = $HBox/Buy10
@onready var _buy_max: Button = $HBox/BuyMax


func setup(index: int) -> void:
	building_index = index
	_building = GameState.buildings[index]
	_name.text = _building.display_name
	_desc.text = _building.description
	_refresh()


func _ready() -> void:
	_buy1.pressed.connect(func(): buy_pressed.emit(building_index, 1))
	_buy10.pressed.connect(func(): buy_pressed.emit(building_index, 10))
	_buy_max.pressed.connect(_on_buy_max)
	GameState.stats_changed.connect(_refresh)


func _refresh() -> void:
	if building_index < 0 or building_index >= GameState.buildings.size():
		return
	_building = GameState.buildings[building_index]
	_owned.text = "Owned: %d" % _building.owned
	_income.text = "%s/s" % FormatUtil.format_money(_building.income_per_second())
	var cost1 := _building.current_cost()
	_buy1.text = "Buy\n%s" % FormatUtil.format_money(cost1)
	_buy10.text = "×10\n%s" % FormatUtil.format_money(_building.cost_for_n(10))
	var max_n := _max_affordable()
	_buy_max.text = "Max (%d)" % max_n if max_n > 0 else "Max"
	_buy1.disabled = not GameState.can_buy_building(building_index, 1)
	_buy10.disabled = not GameState.can_buy_building(building_index, 10)
	_buy_max.disabled = max_n <= 0


func _max_affordable() -> int:
	var n := 0
	var spent := 0.0
	var temp_owned := _building.owned
	while n < 1000:
		var next_cost := _building.base_cost * pow(_building.cost_scale, temp_owned)
		if GameState.balance < spent + next_cost:
			break
		spent += next_cost
		temp_owned += 1
		n += 1
	return n


func _on_buy_max() -> void:
	var n := _max_affordable()
	if n > 0:
		buy_pressed.emit(building_index, n)
