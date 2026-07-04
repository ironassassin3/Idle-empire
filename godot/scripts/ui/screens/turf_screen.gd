extends ScreenBase
## Turf tab — hosts Territory / Rivals / Crew / Ops subtabs inside the sheet
## (§8). Locked subtabs stay visible-dimmed with live requirements (Phase 102).

const TERRITORY_ROW := preload("res://scenes/territory_row.tscn")
const RIVAL_ROW := preload("res://scenes/rival_row.tscn")
const CREW_ROW := preload("res://scenes/crew_row.tscn")
const OPERATION_ROW := preload("res://scenes/operation_row.tscn")

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _RivalSystem = preload("res://scripts/systems/rival_system.gd")
const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")

var subtab := "turf"

var _sub_buttons: Dictionary = {}
var _panes: Dictionary = {}
var _turf_bonus: Label
var _turf_milestones: Label
var _turf_control: Label
var _rivals_impact: Label
var _rivals_activity: Label
var _crew_summary: Label
var _crew_lock: Label
var _ops_summary: Label
var _ops_lock: Label


func _ready() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 48)
	bar.add_theme_constant_override("separation", 4)
	v.add_child(bar)
	for id in ["turf", "rivals", "crew", "ops"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_id: String = id
		b.pressed.connect(func(): _on_subtab_pressed(tab_id))
		bar.add_child(b)
		_sub_buttons[id] = b

	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	v.add_child(host)

	# Panes must be IN the tree before rows are populated — row scenes read
	# their @onready nodes inside setup().
	_panes["turf"] = _build_territory_pane(host)
	_panes["rivals"] = _build_rivals_pane(host)
	_panes["crew"] = _build_crew_pane(host)
	_panes["ops"] = _build_ops_pane(host)

	UiEvents.subtab_requested.connect(func(id): set_subtab(id))
	set_subtab("turf")


func screen_title() -> String:
	return "TURF"


func on_show() -> void:
	set_subtab(subtab)


func refresh_slow() -> void:
	_refresh_subtab_bar()
	match subtab:
		"turf":
			_refresh_turf_header()
		"rivals":
			_refresh_rivals_header()
		"crew":
			_refresh_crew_header()
		"ops":
			_refresh_ops_header()


func set_subtab(id: String) -> void:
	subtab = id
	for pid in _panes:
		(_panes[pid] as Control).visible = pid == id
	_TutorialSystem.on_tab_opened(GameState, id if id != "turf" else "turf")
	Telemetry.log_event("ui_tab_open", {"tab": id if id != "turf" else "turf"})
	refresh_slow()


func _on_subtab_pressed(id: String) -> void:
	# Phase 102: locked subtabs are tappable and explain their unlock.
	if id == "crew" and not _CrewSystem.is_unlocked(GameState):
		GameState.notification.emit(
			_CrewSystem.unlock_requirement_text(GameState), GameTheme.TEXT_MUTED)
	elif id == "ops" and not _OperationSystem.is_unlocked(GameState):
		GameState.notification.emit(
			_OperationSystem.unlock_requirement_text(GameState), GameTheme.TEXT_MUTED)
	set_subtab(id)


func _refresh_subtab_bar() -> void:
	var crew_unlocked: bool = _CrewSystem.is_unlocked(GameState)
	var ops_unlocked: bool = _OperationSystem.is_unlocked(GameState)
	var labels := {
		"turf": "Territory",
		"rivals": "Rivals",
		"crew": "Crew" if crew_unlocked else "Crew %d/5" % mini(GameState.total_buildings_owned(), 5),
		"ops": "",
	}
	var ready_ops := 0
	for op in GameState.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(GameState, op):
			ready_ops += 1
	if ops_unlocked:
		labels["ops"] = "Ops*" if ready_ops > 0 else "Ops"
	else:
		labels["ops"] = "Ops %d/2" % mini(
			_TerritorySystem.player_district_count(GameState.territories), 2)
	for id in _sub_buttons:
		var b: Button = _sub_buttons[id]
		b.text = str(labels[id])
		GameTheme.apply_tab_button(b, id == subtab)
		var locked: bool = (id == "crew" and not crew_unlocked) \
			or (id == "ops" and not ops_unlocked)
		b.modulate = Color(1, 1, 1, 0.55) if locked and id != subtab else Color.WHITE


# ------------------------------------------------------------------ builders

func _pane_scroll(host: Control) -> Array:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	host.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return [scroll, box]


func _header_label(gold: bool = false) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameTheme.apply_subtab_header_label(l)
	l.add_theme_color_override("font_color",
		GameTheme.GOLD_BRIGHT if gold else GameTheme.TEXT_MUTED)
	return l


func _build_territory_pane(host: Control) -> Control:
	var parts := _pane_scroll(host)
	var box: VBoxContainer = parts[1]
	_turf_bonus = _header_label(true)
	box.add_child(_turf_bonus)
	_turf_milestones = _header_label()
	box.add_child(_turf_milestones)
	_turf_control = _header_label()
	box.add_child(_turf_control)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	for i in GameState.territories.size():
		var row: Control = TERRITORY_ROW.instantiate()
		list.add_child(row)
		row.setup(i)
		row.action_pressed.connect(_on_territory_action)
	return parts[0]


func _build_rivals_pane(host: Control) -> Control:
	var parts := _pane_scroll(host)
	var box: VBoxContainer = parts[1]
	_rivals_impact = _header_label(true)
	box.add_child(_rivals_impact)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	for i in GameState.rivals.size():
		var row: Control = RIVAL_ROW.instantiate()
		list.add_child(row)
		row.setup(i)
		row.action_pressed.connect(_on_rival_action)
	_rivals_activity = _header_label()
	box.add_child(_rivals_activity)
	return parts[0]


func _build_crew_pane(host: Control) -> Control:
	var parts := _pane_scroll(host)
	var box: VBoxContainer = parts[1]
	_crew_summary = _header_label(true)
	box.add_child(_crew_summary)
	_crew_lock = _header_label()
	box.add_child(_crew_lock)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	for role in _CrewSystem.ROLES:
		var row: Control = CREW_ROW.instantiate()
		list.add_child(row)
		row.setup(str(role[0]), str(role[2]), str(role[1]), str(role[4]))
		row.adjust_pressed.connect(func(key, delta): GameState.adjust_crew(key, delta))
	return parts[0]


func _build_ops_pane(host: Control) -> Control:
	var parts := _pane_scroll(host)
	var box: VBoxContainer = parts[1]
	_ops_summary = _header_label(true)
	box.add_child(_ops_summary)
	_ops_lock = _header_label()
	box.add_child(_ops_lock)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	for i in GameState.operations.size():
		var row: Control = OPERATION_ROW.instantiate()
		list.add_child(row)
		row.setup(i)
		row.action_pressed.connect(_on_operation_action)
	return parts[0]


# ------------------------------------------------------------- header refresh

func _refresh_turf_header() -> void:
	var territories: Array = GameState.territories
	var total := maxi(1, territories.size())
	var player_count := _TerritorySystem.player_district_count(territories)
	var badge := ""
	var ready_ops := 0
	for op in GameState.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(GameState, op):
			ready_ops += 1
	if ready_ops > 0:
		badge += "  ·  %d ops ready" % ready_ops
	if _ManagerSystem.manager_active(GameState, "The Broker"):
		badge += "  ·  Broker intel"
	_turf_bonus.text = "%d Districts Controlled  ·  +%d%% Global Income%s" % [
		player_count, player_count * 2, badge,
	]
	var ms_lines: PackedStringArray = []
	for entry in _TerritorySystem.MILESTONE_DEFS:
		var key: String = entry[0]
		var thresh: float = entry[1]
		var desc: String = entry[2]
		var earned := key in GameState.city_control_milestones
		var need := maxi(0, int(ceil(thresh * float(total))) - player_count)
		if earned:
			ms_lines.append("v %s%%  %s  EARNED" % [int(thresh * 100.0), desc])
		else:
			ms_lines.append("o %s%%  %s  need %d more" % [int(thresh * 100.0), desc, need])
	_turf_milestones.text = "CITY MILESTONES\n" + "\n".join(ms_lines)
	var ctrl := _TerritorySystem.get_city_control(territories, GameState.rivals)
	var unclaimed := 0
	for t in territories:
		if typeof(t) == TYPE_DICTIONARY and str(t.get("owner", "")) == "unclaimed":
			unclaimed += 1
	var ctrl_lines: PackedStringArray = []
	for entry in ctrl.slice(0, 3):
		var name: String = str(entry[0])
		var share: float = float(entry[1])
		var count := int(round(share * float(total)))
		var label := "YOU" if name == "player" else name.substr(0, 12)
		ctrl_lines.append("%s: %d/%d (%d%%)" % [label, count, total, int(round(share * 100.0))])
	if unclaimed > 0:
		ctrl_lines.append("Unclaimed: %d/%d" % [unclaimed, total])
	_turf_control.text = "CITY CONTROL\n" + "\n".join(ctrl_lines)


func _refresh_rivals_header() -> void:
	var impact: Dictionary = _RivalSystem.get_empire_impact(GameState)
	var penalty_pct: int = int(float(impact.get("territory_penalty", 0.0)) * 100.0)
	_rivals_impact.text = (
		"RIVAL SYNDICATES — strategic threats to your empire\n"
		+ "Combined power: %d  ·  Turf success penalty: -%d%%  ·  Defeated: %d"
		% [int(impact.get("total_power", 0)), penalty_pct, GameState.total_rivals_defeated]
	)
	var log := _RivalSystem.get_activity_log(GameState)
	if log.is_empty():
		_rivals_activity.text = "RECENT ACTIVITY\nNo rival activity yet."
	else:
		var lines: PackedStringArray = PackedStringArray(["RECENT ACTIVITY"])
		for i in range(log.size() - 1, -1, -1):
			lines.append(log[i])
			if lines.size() > 9:
				break
		_rivals_activity.text = "\n".join(lines)


func _refresh_crew_header() -> void:
	var total: int = _CrewSystem.available(GameState)
	var unassign: int = _CrewSystem.unassigned(GameState)
	_crew_summary.text = "CREW ASSIGNMENTS  —  %d total crew, %d unassigned" % [total, unassign]
	if _CrewSystem.is_unlocked(GameState):
		if unassign > 0:
			_crew_lock.text = "%d crew unassigned — assign them for maximum effect!" % unassign
			_crew_lock.add_theme_color_override("font_color", GameTheme.GOLD)
		else:
			_crew_lock.text = "All crew deployed."
			_crew_lock.add_theme_color_override("font_color", GameTheme.GREEN)
	else:
		_crew_lock.text = _CrewSystem.unlock_requirement_text(GameState)
		_crew_lock.add_theme_color_override("font_color", GameTheme.GOLD)


func _refresh_ops_header() -> void:
	var free: int = _OperationSystem.free_crew(GameState)
	_ops_summary.text = "ILLEGAL OPERATIONS  —  %d free crew  ·  %d completed" % [
		free, GameState.total_ops_completed,
	]
	if _OperationSystem.is_unlocked(GameState):
		_ops_lock.text = "Start timed heists — collect when the timer finishes."
		_ops_lock.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	else:
		_ops_lock.text = _OperationSystem.unlock_requirement_text(GameState)
		_ops_lock.add_theme_color_override("font_color", GameTheme.GOLD)


# ------------------------------------------------------------ action handlers

func _on_territory_action(index: int, action: String) -> void:
	var was_unlocked: bool = bool(GameState.territories[index].get("unlocked", false))
	var outcome := GameState.perform_territory_action(index, action)
	var color := GameTheme.GREEN if GameState.territories[index].get("unlocked", false) else GameTheme.GOLD
	GameState.notification.emit(outcome, color)
	if not was_unlocked and bool(GameState.territories[index].get("unlocked", false)):
		AudioManager.play("territory")


func _on_rival_action(index: int, action: String) -> void:
	var outcome := GameState.perform_rival_action(index, action)
	if outcome.is_empty():
		return
	var color := GameTheme.GOLD
	if outcome.begins_with("ELIMINATED"):
		color = GameTheme.GOLD_BRIGHT
	elif outcome.begins_with("Victory") or outcome.begins_with("Bribed") \
			or outcome.begins_with("Peace") or outcome.begins_with("Sabotage succeeded"):
		color = GameTheme.GREEN
	GameState.notification.emit(outcome.replace("\n", "  "), color)


func _on_operation_action(index: int) -> void:
	var op: Dictionary = GameState.operations[index]
	if _OperationSystem.is_ready(GameState, op):
		var first_op: bool = GameState.total_ops_completed == 0
		var outcome := GameState.collect_operation(index)
		var color := GameTheme.GREEN if outcome.contains("Complete") else GameTheme.RED
		GameState.notification.emit(outcome.replace("\n", "  "), color)
		if outcome.contains("Complete") and not outcome.contains("FAILED"):
			AudioManager.play("manager" if first_op else "achievement")
	else:
		GameState.notification.emit(GameState.start_operation(index), GameTheme.GOLD)
