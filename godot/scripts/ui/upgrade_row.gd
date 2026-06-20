extends PanelContainer

signal buy_pressed(index: int)

var upgrade_index: int = -1
var _affordance: int = GameTheme.RowAffordance.LOCKED

@onready var _name: Label = $Margin/HBox/Info/NameLabel
@onready var _desc: Label = $Margin/HBox/Info/DescLabel
@onready var _buy: Button = $Margin/HBox/BuyBtn


func setup(index: int) -> void:
	upgrade_index = index
	var u := GameState.upgrades[index]
	_desc.text = u.description
	_refresh()


func _ready() -> void:
	GameTheme.apply_row_buy_button(_buy)
	_apply_label_scale()
	_buy.pressed.connect(func(): buy_pressed.emit(upgrade_index))
	GameState.stats_changed.connect(_refresh)
	if upgrade_index >= 0:
		_refresh()


func _apply_label_scale() -> void:
	_name.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))


func _draw() -> void:
	GameTheme.draw_row_wax_seal(self, _affordance)


func _refresh() -> void:
	if upgrade_index < 0 or upgrade_index >= GameState.upgrades.size():
		return
	var u := GameState.upgrades[upgrade_index]
	_name.text = u.display_name
	modulate = Color.WHITE
	if u.purchased:
		_buy.text = "Owned"
		_buy.disabled = true
		_affordance = GameTheme.RowAffordance.OWNED
		GameTheme.apply_row_affordance(self, _affordance)
		return
	var cost := UpgradeDefs.effective_cost(u, GameState)
	_buy.text = FormatUtil.format_money(cost)
	var can_buy := GameState.can_buy_upgrade(upgrade_index)
	_buy.disabled = not can_buy
	_affordance = GameTheme.RowAffordance.BUYABLE if can_buy else GameTheme.RowAffordance.LOCKED
	GameTheme.apply_row_affordance(self, _affordance)
