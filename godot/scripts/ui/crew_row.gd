extends PanelContainer

signal adjust_pressed(role_key: String, delta: int)

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")

var role_key: String = ""

@onready var _icon: Label = $Margin/HBox/IconLabel
@onready var _name: Label = $Margin/HBox/Info/NameLabel
@onready var _effect: Label = $Margin/HBox/Info/EffectLabel
@onready var _detail: Label = $Margin/HBox/Info/DetailLabel
@onready var _count: Label = $Margin/HBox/CountLabel
@onready var _minus: Button = $Margin/HBox/MinusBtn
@onready var _plus: Button = $Margin/HBox/PlusBtn


func setup(key: String, icon: String, role_name: String, detail: String) -> void:
	role_key = key
	_icon.text = icon
	_name.text = role_name
	_detail.text = detail
	_refresh()


func _ready() -> void:
	GameTheme.apply_row_affordance(self, GameTheme.RowAffordance.LOCKED)
	for btn in [_minus, _plus]:
		GameTheme.apply_row_buy_button(btn)
		btn.add_theme_font_size_override("font_size", GameTheme.scaled_font(18))
	_apply_label_scale()
	_minus.pressed.connect(func(): adjust_pressed.emit(role_key, -1))
	_plus.pressed.connect(func(): adjust_pressed.emit(role_key, 1))
	GameState.stats_changed.connect(_refresh)
	if not role_key.is_empty():
		_refresh()


func _apply_label_scale() -> void:
	_icon.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_name.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_effect.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_detail.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_count.add_theme_font_size_override("font_size", GameTheme.scaled_font(18))


func _refresh() -> void:
	if role_key.is_empty():
		return
	var count: int = int(GameState.crew.get(role_key, 0))
	_count.text = str(count)
	_effect.text = _CrewSystem.role_effect_str(role_key, count)
	var unlocked: bool = _CrewSystem.is_unlocked(GameState)
	var unassign: int = _CrewSystem.unassigned(GameState)
	_minus.disabled = not unlocked or count <= 0
	_plus.disabled = not unlocked or unassign <= 0
