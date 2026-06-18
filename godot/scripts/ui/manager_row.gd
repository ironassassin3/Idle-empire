extends PanelContainer

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

signal hire_pressed(index: int)

var manager_index: int = -1

@onready var _name: Label = $VBox/Header/NameLabel
@onready var _title: Label = $VBox/Header/TitleLabel
@onready var _desc: Label = $VBox/DescLabel
@onready var _bonus: Label = $VBox/BonusLabel
@onready var _status: Label = $VBox/StatusLabel
@onready var _hire: Button = $VBox/HireBtn
@onready var _target: Button = $VBox/TargetBtn


func setup(index: int) -> void:
	manager_index = index
	var m := GameState.managers[index]
	_name.text = m.display_name
	_title.text = m.title
	_desc.text = m.flavor
	_bonus.text = m.bonus_desc
	_refresh()


func _ready() -> void:
	_hire.pressed.connect(func(): hire_pressed.emit(manager_index))
	_target.pressed.connect(_on_cycle_promoter_target)
	GameState.stats_changed.connect(_refresh)


func _on_cycle_promoter_target() -> void:
	var tgt: float = _ManagerSystem.cycle_promoter_target(GameState)
	GameState.notification.emit("Promoter target: keep heat ≤%.0f%%" % tgt, GameTheme.GOLD)
	GameState.stats_changed.emit()


func _refresh() -> void:
	if manager_index < 0 or manager_index >= GameState.managers.size():
		return
	var m := GameState.managers[manager_index]
	if m.hired:
		_status.text = "On payroll"
		_hire.text = "Hired"
		_hire.disabled = true
		modulate = Color(0.75, 0.85, 0.75)
		if m.display_name == "The Promoter":
			_target.visible = true
			_target.text = "Heat target ≤%.0f%%  (tap to cycle)" % _ManagerSystem.promoter_heat_target(GameState)
		else:
			_target.visible = false
		return
	_target.visible = false
	modulate = Color.WHITE
	if ManagerDefs.is_unlocked(GameState, manager_index):
		_status.text = "Unlocked"
		_hire.text = "Hire %s" % FormatUtil.format_money(m.cost)
		_hire.disabled = not GameState.can_hire_manager(manager_index)
	else:
		_status.text = "Locked: %s" % ManagerDefs.unlock_text(manager_index)
		_hire.text = "Locked"
		_hire.disabled = true
