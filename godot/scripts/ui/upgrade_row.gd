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
	GameTheme.apply_row_title(_name, 14)
	_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))


# Rule 10 (Stage & Ledger): progress-to-afford underbar while APPROACHING.
var _afford := 0.0


func _draw() -> void:
	GameTheme.draw_row_wax_seal(self, _affordance)
	if _afford > 0.0 and _afford < 1.0:
		draw_rect(Rect2(0, size.y - 3.0, size.x, 3.0), Color(GameTheme.GOLD, 0.14))
		draw_rect(Rect2(0, size.y - 3.0, size.x * _afford, 3.0), GameTheme.GOLD)


func _refresh() -> void:
	if upgrade_index < 0 or upgrade_index >= GameState.upgrades.size():
		return
	var u := GameState.upgrades[upgrade_index]
	_name.text = u.display_name
	if GameConfig.UI_SHELL_V3:
		var compact: bool = GameState.ui_compact_rows
		_desc.visible = not compact
		custom_minimum_size.y = 64.0 if compact else 0.0
		_buy.custom_minimum_size.y = 48.0 if compact else _buy.custom_minimum_size.y
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
	if GameConfig.UI_SHELL_V3:
		Affordance.apply_action_button(
			_buy, Affordance.READY if can_buy else Affordance.APPROACHING)
		_afford = 0.0 if can_buy else Affordance.progress(cost, GameState.balance)
		queue_redraw()
