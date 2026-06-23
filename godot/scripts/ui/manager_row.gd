extends PanelContainer

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

signal hire_pressed(index: int)

var manager_index: int = -1
var _affordance: int = GameTheme.RowAffordance.LOCKED

@onready var _name: Label = $Margin/VBox/Header/NameLabel
@onready var _title: Label = $Margin/VBox/Header/TitleLabel
@onready var _badge: Label = $Margin/VBox/Header/BadgeLabel
@onready var _desc: Label = $Margin/VBox/DescLabel
@onready var _bonus: Label = $Margin/VBox/BonusLabel
@onready var _status: Label = $Margin/VBox/StatusLabel
@onready var _hire: Button = $Margin/VBox/HireBtn
@onready var _target: Button = $Margin/VBox/TargetBtn


func setup(index: int) -> void:
	manager_index = index
	var m := GameState.managers[index]
	_name.text = m.display_name
	_title.text = m.title
	_desc.text = m.flavor
	_bonus.text = m.bonus_desc
	_refresh()


func _ready() -> void:
	for btn in [_hire, _target]:
		GameTheme.apply_row_buy_button(btn)
	_apply_label_scale()
	_hire.pressed.connect(func(): hire_pressed.emit(manager_index))
	_target.pressed.connect(_on_cycle_promoter_target)
	GameState.stats_changed.connect(_refresh)
	if manager_index >= 0:
		_refresh()


func _apply_label_scale() -> void:
	_name.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_badge.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_bonus.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_status.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))


func _draw() -> void:
	GameTheme.draw_row_wax_seal(self, _affordance)


func _on_cycle_promoter_target() -> void:
	var tgt: float = _ManagerSystem.cycle_promoter_target(GameState)
	GameState.notification.emit("Promoter target: keep heat \u2264%.0f%%" % tgt, GameTheme.GOLD)
	GameState.stats_changed.emit()


func _apply_badge(kind: String, accent: Color) -> void:
	if kind.is_empty():
		_badge.visible = false
		return
	var label := "AUTO"
	if kind == "ready":
		label = "READY"
	elif kind == "working":
		label = "ACTIVE"
	var muted := kind == "gated"
	var fg: Color = GameTheme.TEXT_MUTED if muted else accent
	_badge.visible = true
	_badge.text = "  %s  " % label
	_badge.add_theme_color_override("font_color", fg)
	var pill := StyleBoxFlat.new()
	var fill := Color(fg.r * 0.25, fg.g * 0.25, fg.b * 0.25, 0.55 if muted else 0.75)
	pill.bg_color = fill
	pill.set_border_width_all(1)
	pill.border_color = Color(fg.r, fg.g, fg.b, 0.45 if muted else 0.85)
	pill.set_corner_radius_all(4)
	pill.content_margin_left = 4
	pill.content_margin_right = 4
	pill.content_margin_top = 1
	pill.content_margin_bottom = 1
	_badge.add_theme_stylebox_override("normal", pill)


func _refresh() -> void:
	if manager_index < 0 or manager_index >= GameState.managers.size():
		return
	var m := GameState.managers[manager_index]
	modulate = Color.WHITE
	if m.hired:
		var st: Dictionary = _ManagerSystem.employee_status(GameState, manager_index)
		_status.text = st.get("text", "On payroll")
		_status.add_theme_color_override("font_color", st.get("color", GameTheme.TEXT_MUTED))
		_apply_badge(st.get("badge_kind", ""), st.get("color", GameTheme.GREEN))
		_hire.text = "Hired"
		_hire.disabled = true
		_affordance = GameTheme.RowAffordance.OWNED
		GameTheme.apply_row_affordance(self, _affordance)
		if m.display_name == "The Promoter":
			_target.visible = true
			_target.text = "Heat target \u2264%.0f%%  (tap to cycle)" % _ManagerSystem.promoter_heat_target(GameState)
		else:
			_target.visible = false
		return
	_apply_badge("", Color.WHITE)
	_target.visible = false
	if ManagerDefs.is_unlocked(GameState, manager_index):
		_status.text = "Unlocked"
		_status.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		_hire.text = "Hire %s" % FormatUtil.format_money(m.cost)
		var can_hire := GameState.can_hire_manager(manager_index)
		_hire.disabled = not can_hire
		_affordance = GameTheme.RowAffordance.BUYABLE if can_hire else GameTheme.RowAffordance.LOCKED
	else:
		_status.text = "Locked: %s" % ManagerDefs.unlock_text(manager_index)
		_status.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		_hire.text = "Locked"
		_hire.disabled = true
		_affordance = GameTheme.RowAffordance.LOCKED
	GameTheme.apply_row_affordance(self, _affordance)
