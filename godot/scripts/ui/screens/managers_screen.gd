extends ScreenBase
## Managers tab — hire list. Rows self-refresh; screen just hosts + hires.
## Supremacy N8 veteran density: compact mode collapses hired managers to a
## one-line summary strip (they need no further action) so the list scrolls
## to the managers still worth deciding about.

const MANAGER_ROW := preload("res://scenes/manager_row.tscn")

var _list: VBoxContainer
var _rows: Array[Control] = []
var _hired_summary: Label


func _ready() -> void:
	var parts := make_scroll_list()
	_list = parts[1]
	_hired_summary = Label.new()
	_hired_summary.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_hired_summary.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_hired_summary.visible = false
	_list.add_child(_hired_summary)
	for i in GameState.managers.size():
		var row: Control = MANAGER_ROW.instantiate()
		_list.add_child(row)
		row.setup(i)
		row.hire_pressed.connect(func(index): GameState.hire_manager(index))
		_rows.append(row)
	GameState.stats_changed.connect(_refresh_compact)
	_refresh_compact()


func screen_title() -> String:
	return "SYNDICATE MANAGERS"


func refresh_slow() -> void:
	_refresh_compact()


func _refresh_compact() -> void:
	if not GameConfig.UI_SHELL_V3 or not GameState.ui_compact_rows:
		_hired_summary.visible = false
		for row in _rows:
			row.visible = true
		return
	var hired_names: Array[String] = []
	for i in _rows.size():
		var m = GameState.managers[i]
		var hired: bool = bool(m.hired)
		_rows[i].visible = not hired
		if hired:
			hired_names.append(str(m.display_name))
	_hired_summary.visible = not hired_names.is_empty()
	if _hired_summary.visible:
		_hired_summary.text = "On payroll: %s" % ", ".join(hired_names)
