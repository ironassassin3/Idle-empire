extends PanelContainer

signal buy_pressed(index: int)

var upgrade_index: int = -1

@onready var _name: Label = $HBox/Info/NameLabel
@onready var _desc: Label = $HBox/Info/DescLabel
@onready var _buy: Button = $HBox/BuyBtn


func setup(index: int) -> void:
	upgrade_index = index
	var u := GameState.upgrades[index]
	_name.text = u.display_name
	_desc.text = u.description
	_refresh()


func _ready() -> void:
	_buy.pressed.connect(func(): buy_pressed.emit(upgrade_index))
	GameState.stats_changed.connect(_refresh)


func _refresh() -> void:
	if upgrade_index < 0 or upgrade_index >= GameState.upgrades.size():
		return
	var u := GameState.upgrades[upgrade_index]
	if u.purchased:
		_buy.text = "Owned"
		_buy.disabled = true
		modulate = Color(0.7, 0.85, 0.7)
		return
	modulate = Color.WHITE
	var cost := UpgradeDefs.effective_cost(u, GameState)
	_buy.text = FormatUtil.format_money(cost)
	_buy.disabled = not GameState.can_buy_upgrade(upgrade_index)
