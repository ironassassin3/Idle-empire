extends PanelContainer

signal adjust_pressed(role_key: String, delta: int)

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")

var role_key: String = ""

@onready var _icon: Label = $HBox/IconLabel
@onready var _name: Label = $HBox/Info/NameLabel
@onready var _effect: Label = $HBox/Info/EffectLabel
@onready var _detail: Label = $HBox/Info/DetailLabel
@onready var _count: Label = $HBox/CountLabel
@onready var _minus: Button = $HBox/MinusBtn
@onready var _plus: Button = $HBox/PlusBtn


func setup(key: String, icon: String, role_name: String, detail: String) -> void:
	role_key = key
	_icon.text = icon
	_name.text = role_name
	_detail.text = detail
	_refresh()


func _ready() -> void:
	_minus.pressed.connect(func(): adjust_pressed.emit(role_key, -1))
	_plus.pressed.connect(func(): adjust_pressed.emit(role_key, 1))
	GameState.stats_changed.connect(_refresh)


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
