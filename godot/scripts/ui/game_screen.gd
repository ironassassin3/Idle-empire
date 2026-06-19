extends CanvasLayer

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _RivalSystem = preload("res://scripts/systems/rival_system.gd")
const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
const _AchievementSystem = preload("res://scripts/systems/achievement_system.gd")
const _EventSystem = preload("res://scripts/systems/event_system.gd")
const _GoalSystem = preload("res://scripts/systems/goal_system.gd")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")
const _BuffSystem = preload("res://scripts/systems/buff_system.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")
const StatsDashboard = preload("res://scripts/ui/stats_dashboard.gd")

const BUILDING_ROW := preload("res://scenes/building_row.tscn")
const UPGRADE_ROW := preload("res://scenes/upgrade_row.tscn")
const MANAGER_ROW := preload("res://scenes/manager_row.tscn")
const TERRITORY_ROW := preload("res://scenes/territory_row.tscn")
const RIVAL_ROW := preload("res://scenes/rival_row.tscn")
const CREW_ROW := preload("res://scenes/crew_row.tscn")
const OPERATION_ROW := preload("res://scenes/operation_row.tscn")

enum Tab { BLDGS, UPGRS, TURF, RIVALS, CREW, OPS, STATS, MGRS, CONFIG }

@onready var _balance: Label = $Root/VBox/Header/Balance
@onready var _ips: Label = $Root/VBox/Header/Income
@onready var _rank: Label = $Root/VBox/Header/Rank
@onready var _heat_bar: ProgressBar = $Root/VBox/Body/Left/HeatBar
@onready var _heat_label: Label = $Root/VBox/Body/Left/HeatLabel
@onready var _coin_btn: Button = $Root/VBox/Body/Left/CoinBtn
@onready var _shield_label: Label = $Root/VBox/Body/Left/ShieldLabel
@onready var _hustle: Button = $Root/VBox/Body/Left/HustleBtn
@onready var _click_info: Label = $Root/VBox/Body/Left/ClickInfo
@onready var _prestige_btn: Button = $Root/VBox/Body/Left/PrestigeBtn
@onready var _prestige_info: Label = $Root/VBox/Body/Left/PrestigeInfo
@onready var _buff_label: Label = $Root/VBox/Body/Left/BuffLabel
# Bottom nav bar (5 primary tabs) + Turf subtab bar + header gear.
@onready var _tab_bldgs: Button = $Root/VBox/BottomBar/BldgsBtn
@onready var _tab_upgrs: Button = $Root/VBox/BottomBar/UpgrsBtn
@onready var _tab_mgrs: Button = $Root/VBox/BottomBar/MgrsBtn
@onready var _tab_turf: Button = $Root/VBox/BottomBar/TurfBtn
@onready var _tab_stats: Button = $Root/VBox/BottomBar/StatsBtn
@onready var _cfg_btn: Button = $Root/VBox/Header/CfgBtn
@onready var _turf_subbar: HBoxContainer = $Root/VBox/Body/Right/TurfSubBar
@onready var _sub_territory: Button = $Root/VBox/Body/Right/TurfSubBar/TerritoryBtn
@onready var _sub_rivals: Button = $Root/VBox/Body/Right/TurfSubBar/RivalsBtn
@onready var _sub_crew: Button = $Root/VBox/Body/Right/TurfSubBar/CrewBtn
@onready var _sub_ops: Button = $Root/VBox/Body/Right/TurfSubBar/OpsBtn
@onready var _config_scroll: ScrollContainer = $Root/VBox/Body/Right/ConfigScroll
@onready var _config_body: VBoxContainer = $Root/VBox/Body/Right/ConfigScroll/ConfigBody
@onready var _bldgs_scroll: ScrollContainer = $Root/VBox/Body/Right/BldgsScroll
@onready var _upgrs_scroll: ScrollContainer = $Root/VBox/Body/Right/UpgrsScroll
@onready var _turf_scroll: ScrollContainer = $Root/VBox/Body/Right/TurfScroll
@onready var _rivals_scroll: ScrollContainer = $Root/VBox/Body/Right/RivalsScroll
@onready var _crew_scroll: ScrollContainer = $Root/VBox/Body/Right/CrewScroll
@onready var _ops_scroll: ScrollContainer = $Root/VBox/Body/Right/OpsScroll
@onready var _stats_scroll: ScrollContainer = $Root/VBox/Body/Right/StatsScroll
@onready var _mgrs_scroll: ScrollContainer = $Root/VBox/Body/Right/MgrsScroll
@onready var _bldgs_list: VBoxContainer = $Root/VBox/Body/Right/BldgsScroll/List
@onready var _upgrs_list: VBoxContainer = $Root/VBox/Body/Right/UpgrsScroll/List
@onready var _mgrs_list: VBoxContainer = $Root/VBox/Body/Right/MgrsScroll/List
@onready var _turf_bonus: Label = $Root/VBox/Body/Right/TurfScroll/VBox/Header/BonusLabel
@onready var _turf_milestones: Label = $Root/VBox/Body/Right/TurfScroll/VBox/Header/MilestoneLabel
@onready var _turf_control: Label = $Root/VBox/Body/Right/TurfScroll/VBox/Header/ControlLabel
@onready var _turf_list: VBoxContainer = $Root/VBox/Body/Right/TurfScroll/VBox/List
@onready var _rivals_impact: Label = $Root/VBox/Body/Right/RivalsScroll/VBox/Header/ImpactLabel
@onready var _rivals_list: VBoxContainer = $Root/VBox/Body/Right/RivalsScroll/VBox/List
@onready var _rivals_activity: Label = $Root/VBox/Body/Right/RivalsScroll/VBox/ActivityLabel
@onready var _crew_summary: Label = $Root/VBox/Body/Right/CrewScroll/VBox/Header/SummaryLabel
@onready var _crew_lock: Label = $Root/VBox/Body/Right/CrewScroll/VBox/Header/LockLabel
@onready var _crew_list: VBoxContainer = $Root/VBox/Body/Right/CrewScroll/VBox/List
@onready var _ops_summary: Label = $Root/VBox/Body/Right/OpsScroll/VBox/Header/SummaryLabel
@onready var _ops_lock: Label = $Root/VBox/Body/Right/OpsScroll/VBox/Header/LockLabel
@onready var _ops_list: VBoxContainer = $Root/VBox/Body/Right/OpsScroll/VBox/List
@onready var _stats_dashboard: VBoxContainer = $Root/VBox/Body/Right/StatsScroll/VBox/StatsDashboard
@onready var _stats_ach_btn: Button = $Root/VBox/Body/Right/StatsScroll/VBox/AchBtn
@onready var _stats_ach_panel: VBoxContainer = $Root/VBox/Body/Right/StatsScroll/VBox/AchPanel
@onready var _stats_ach_list: Label = $Root/VBox/Body/Right/StatsScroll/VBox/AchPanel/AchList
@onready var _stats_ach_close: Button = $Root/VBox/Body/Right/StatsScroll/VBox/AchPanel/AchCloseBtn
@onready var _notif: Label = $Root/VBox/Notif
@onready var _menu_btn: Button = $Root/VBox/Header/MenuBtn
@onready var _prestige_tree: CanvasLayer = $PrestigeTreeOverlay
@onready var _dragon_patron: CanvasLayer = $DragonPatronOverlay
@onready var _dragon_hud: PanelContainer = $Root/VBox/Body/Left/DragonHud
@onready var _dragon_name: Label = $Root/VBox/Body/Left/DragonHud/VBox/Header/Name
@onready var _dragon_mood: Label = $Root/VBox/Body/Left/DragonHud/VBox/Header/Mood
@onready var _dragon_stage: Label = $Root/VBox/Body/Left/DragonHud/VBox/Stage
@onready var _dragon_xp_bar: ProgressBar = $Root/VBox/Body/Left/DragonHud/VBox/XpBar
@onready var _dragon_request: Label = $Root/VBox/Body/Left/DragonHud/VBox/Request
@onready var _dragon_abilities: HBoxContainer = $Root/VBox/Body/Left/DragonHud/VBox/AbilityRow
@onready var _overlay_dim: ColorRect = $OverlayLayer/Dim
@onready var _milestone_panel: PanelContainer = $OverlayLayer/MilestonePanel
@onready var _milestone_title: Label = $OverlayLayer/MilestonePanel/VBox/Title
@onready var _milestone_body: Label = $OverlayLayer/MilestonePanel/VBox/Body
@onready var _milestone_dismiss: Button = $OverlayLayer/MilestonePanel/VBox/DismissBtn
@onready var _event_panel: PanelContainer = $OverlayLayer/EventPanel
@onready var _event_title: Label = $OverlayLayer/EventPanel/VBox/Title
@onready var _event_desc: Label = $OverlayLayer/EventPanel/VBox/Desc
@onready var _event_choices: VBoxContainer = $OverlayLayer/EventPanel/VBox/Choices
@onready var _offline_panel: PanelContainer = $OverlayLayer/OfflinePanel
@onready var _offline_body: Label = $OverlayLayer/OfflinePanel/VBox/Body
@onready var _offline_continue: Button = $OverlayLayer/OfflinePanel/VBox/ContinueBtn
var _offline_watch_ad: Button
var _coin_ad_btn: Button
@onready var _elim_panel: PanelContainer = $OverlayLayer/ElimPanel
@onready var _elim_name: Label = $OverlayLayer/ElimPanel/VBox/Name
@onready var _elim_flavor: Label = $OverlayLayer/ElimPanel/VBox/Flavor
@onready var _elim_rewards: Label = $OverlayLayer/ElimPanel/VBox/Rewards
@onready var _elim_dismiss: Button = $OverlayLayer/ElimPanel/VBox/DismissBtn
@onready var _tutorial_banner: Label = $TutorialBanner

var _tab: Tab = Tab.BLDGS
var _notif_timer: float = 0.0
var _ui_time: float = 0.0
var _click_scale: float = 1.0
const _CLICK_SCALE_MIN := 0.92
const _CLICK_SCALE_RATE := (1.0 - 0.92) / 0.15
var _float_layer: Control
const _MAX_FLOATS := 24
var _stats_refresh_timer: float = 0.0
# Throttle the header/left-panel refresh: the sim emits stats_changed every frame,
# but rebuilding ~15 labels + tab badges + advice at 60fps wastes mobile CPU/battery.
# 10fps is imperceptible for idle numbers (matches pygame's ~5fps stats throttle).
var _stats_dirty: bool = true
var _stats_ui_timer: float = 0.0
const _STATS_UI_INTERVAL := 0.1
var _last_event_key: String = ""
var _notif_default_font_size: int = 0
const STATS_REFRESH_INTERVAL := 0.2
const _BASE_MARGIN := 12


## Inset the root container by the device safe area (notch / home bar). Safe-area
## coords are native screen px; scale to viewport px. No-op on desktop (safe area
## == screen). Needs on-device verification (P8 device matrix).
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var vp := get_viewport().get_visible_rect().size
	var sx := vp.x / float(screen.x)
	var sy := vp.y / float(screen.y)
	var left := _BASE_MARGIN + int(maxf(0.0, float(safe.position.x)) * sx)
	var top := _BASE_MARGIN + int(maxf(0.0, float(safe.position.y)) * sy)
	var right := _BASE_MARGIN + int(maxf(0.0, float(screen.x - (safe.position.x + safe.size.x))) * sx)
	var bottom := _BASE_MARGIN + int(maxf(0.0, float(screen.y - (safe.position.y + safe.size.y))) * sy)
	var root := $Root
	root.add_theme_constant_override("margin_left", left)
	root.add_theme_constant_override("margin_top", top)
	root.add_theme_constant_override("margin_right", right)
	root.add_theme_constant_override("margin_bottom", bottom)


func _ready() -> void:
	GameState.set_simulation_active(true)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_heat_bar.max_value = 100.0
	_populate_buildings()
	_populate_upgrades()
	_populate_managers()
	_populate_territories()
	_populate_rivals()
	_populate_crew()
	_populate_operations()
	_set_tab(Tab.BLDGS)
	GameState.stats_changed.connect(func(): _stats_dirty = true)
	GameState.notification.connect(_on_notification)
	_hustle.pressed.connect(_on_hustle)
	_coin_btn.pressed.connect(_on_coin)
	_prestige_btn.pressed.connect(_on_prestige)
	_menu_btn.pressed.connect(_on_menu)
	_tab_bldgs.pressed.connect(func(): _set_tab(Tab.BLDGS))
	_tab_upgrs.pressed.connect(func(): _set_tab(Tab.UPGRS))
	_tab_mgrs.pressed.connect(func(): _set_tab(Tab.MGRS))
	_tab_turf.pressed.connect(_open_turf)
	_tab_stats.pressed.connect(func(): _set_tab(Tab.STATS))
	_cfg_btn.pressed.connect(func(): _set_tab(Tab.CONFIG))
	_sub_territory.pressed.connect(func(): _set_turf_subtab(Tab.TURF))
	_sub_rivals.pressed.connect(func(): _set_turf_subtab(Tab.RIVALS))
	_sub_crew.pressed.connect(func(): _set_turf_subtab(Tab.CREW))
	_sub_ops.pressed.connect(func(): _set_turf_subtab(Tab.OPS))
	_milestone_dismiss.pressed.connect(_dismiss_milestone)
	_offline_continue.pressed.connect(_dismiss_offline)
	var offline_vbox := _offline_continue.get_parent()
	_offline_watch_ad = Button.new()
	_offline_watch_ad.text = "Watch ad (2× earnings)"
	offline_vbox.add_child(_offline_watch_ad)
	offline_vbox.move_child(_offline_watch_ad, offline_vbox.get_child_count() - 1)
	_offline_watch_ad.pressed.connect(_on_offline_watch_ad)
	_coin_ad_btn = Button.new()
	_coin_ad_btn.text = "Ad → coin"
	_coin_btn.get_parent().add_child(_coin_ad_btn)
	_coin_ad_btn.pressed.connect(_on_coin_watch_ad)
	_elim_dismiss.pressed.connect(_dismiss_elim)
	_notif_default_font_size = _notif.get_theme_font_size("font_size")
	call_deferred("_init_hustle_pivot")
	_build_config_tab()
	_stats_ach_btn.pressed.connect(_toggle_achievements_panel)
	_stats_ach_close.pressed.connect(_close_achievements_panel)
	_refresh_all()


func _populate_buildings() -> void:
	for i in GameState.buildings.size():
		var row: Control = BUILDING_ROW.instantiate()
		_bldgs_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_buy)


func _populate_upgrades() -> void:
	for i in GameState.upgrades.size():
		if GameState.upgrades[i].purchased:
			continue
		var row: Control = UPGRADE_ROW.instantiate()
		_upgrs_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_upgrade)


func _populate_managers() -> void:
	for i in GameState.managers.size():
		var row: Control = MANAGER_ROW.instantiate()
		_mgrs_list.add_child(row)
		row.setup(i)
		row.hire_pressed.connect(_on_hire)


func _populate_territories() -> void:
	for i in GameState.territories.size():
		var row: Control = TERRITORY_ROW.instantiate()
		_turf_list.add_child(row)
		row.setup(i)
		row.action_pressed.connect(_on_territory_action)


func _populate_rivals() -> void:
	for i in GameState.rivals.size():
		var row: Control = RIVAL_ROW.instantiate()
		_rivals_list.add_child(row)
		row.setup(i)
		row.action_pressed.connect(_on_rival_action)


func _populate_crew() -> void:
	for role in _CrewSystem.ROLES:
		var row: Control = CREW_ROW.instantiate()
		_crew_list.add_child(row)
		row.setup(str(role[0]), str(role[2]), str(role[1]), str(role[4]))
		row.adjust_pressed.connect(_on_crew_adjust)


func _populate_operations() -> void:
	for i in GameState.operations.size():
		var row: Control = OPERATION_ROW.instantiate()
		_ops_list.add_child(row)
		row.setup(i)
		row.action_pressed.connect(_on_operation_action)


func _init_hustle_pivot() -> void:
	_hustle.pivot_offset = _hustle.size * 0.5


const _TURF_TABS: Array = [Tab.TURF, Tab.RIVALS, Tab.CREW, Tab.OPS]
var _turf_subtab: Tab = Tab.TURF


# Pressing the Turf bottom-bar button restores the last-used Turf subtab.
func _open_turf() -> void:
	_set_tab(_turf_subtab if _turf_subtab in _TURF_TABS else Tab.TURF)


func _set_turf_subtab(tab: Tab) -> void:
	if tab == Tab.CREW and not _CrewSystem.is_unlocked(GameState):
		return
	if tab == Tab.OPS and not _OperationSystem.is_unlocked(GameState):
		return
	_set_tab(tab)


func _refresh_turf_subbar() -> void:
	var crew_unlocked: bool = _CrewSystem.is_unlocked(GameState)
	var ops_unlocked: bool = _OperationSystem.is_unlocked(GameState)
	_sub_territory.disabled = _tab == Tab.TURF
	_sub_rivals.disabled = _tab == Tab.RIVALS
	_sub_crew.disabled = (_tab == Tab.CREW) or not crew_unlocked
	_sub_ops.disabled = (_tab == Tab.OPS) or not ops_unlocked


func _set_tab(tab: Tab) -> void:
	_tab = tab
	var is_turf: bool = tab in _TURF_TABS
	_bldgs_scroll.visible = tab == Tab.BLDGS
	_upgrs_scroll.visible = tab == Tab.UPGRS
	_turf_scroll.visible = tab == Tab.TURF
	_rivals_scroll.visible = tab == Tab.RIVALS
	_crew_scroll.visible = tab == Tab.CREW
	_ops_scroll.visible = tab == Tab.OPS
	_stats_scroll.visible = tab == Tab.STATS
	_mgrs_scroll.visible = tab == Tab.MGRS
	_config_scroll.visible = tab == Tab.CONFIG
	_turf_subbar.visible = is_turf
	_tab_bldgs.disabled = tab == Tab.BLDGS
	_tab_upgrs.disabled = tab == Tab.UPGRS
	_tab_mgrs.disabled = tab == Tab.MGRS
	_tab_turf.disabled = is_turf
	_tab_stats.disabled = tab == Tab.STATS
	if is_turf:
		_turf_subtab = tab
		_refresh_turf_subbar()
	match tab:
		Tab.UPGRS:
			if GameState.tutorial_step == 2:
				_TutorialSystem.advance_tutorial(GameState)
		Tab.MGRS:
			if GameState.tutorial_step == 3:
				_TutorialSystem.advance_tutorial(GameState)
		Tab.CREW:
			_TutorialSystem.on_tab_opened(GameState, "crew")
		Tab.OPS:
			_TutorialSystem.on_tab_opened(GameState, "ops")
		Tab.TURF:
			_TutorialSystem.on_tab_opened(GameState, "turf")
		Tab.RIVALS:
			_TutorialSystem.on_tab_opened(GameState, "rivals")
	if tab == Tab.STATS:
		_stats_refresh_timer = 0.0
		_refresh_stats_tab()
	elif tab == Tab.CONFIG:
		_build_config_tab()
	else:
		_close_achievements_panel()


func _process(delta: float) -> void:
	_ui_time += delta
	_stats_ui_timer -= delta
	if _stats_dirty and _stats_ui_timer <= 0.0:
		_stats_ui_timer = _STATS_UI_INTERVAL
		_stats_dirty = false
		_refresh_all()
	if _notif_timer > 0.0:
		_notif_timer -= delta
		if _notif_timer <= 0.0:
			_notif.text = ""
			_notif.add_theme_font_size_override("font_size", _notif_default_font_size)
	if _tab == Tab.STATS:
		_stats_refresh_timer -= delta
		if _stats_refresh_timer <= 0.0:
			_stats_refresh_timer = STATS_REFRESH_INTERVAL
			_refresh_stats_tab()
	_update_motion_cues()
	_refresh_overlays()
	if _click_scale < 1.0:
		_click_scale = minf(1.0, _click_scale + _CLICK_SCALE_RATE * delta)
		_hustle.scale = Vector2(_click_scale, _click_scale)


func _refresh_overlays() -> void:
	var blocking := false
	if GameState.show_offline_overlay or GameState.show_daily_overlay:
		blocking = true
		_offline_panel.visible = true
		var hours: int = int(GameState.offline_secs_away / 3600.0)
		var mins: int = int(int(GameState.offline_secs_away) % 3600 / 60.0)
		var away: String = "Away for %dh %dm" % [hours, mins] if hours > 0 else "Away for %dm" % mins
		var cap_note: String = "\nCap reached — check in sooner for more" if GameState.offline_capped else ""
		var rival_news: String = ""
		if not GameState.offline_rival_events.is_empty():
			rival_news = "\n\nWhile you were away:\n• " + "\n• ".join(GameState.offline_rival_events)
		var body_text: String = (
			"%s\n\nCash earned: +%s%s\n\nOps ready: %d\nTerritory: %d / %d\nRivals active: %d (%d at war)%s"
			% [
				away,
				FormatUtil.format_money(GameState.offline_gain),
				cap_note,
				GameState.return_ops_ready,
				GameState.return_territory_player,
				GameState.return_territory_total,
				GameState.return_rival_active,
				GameState.return_rival_at_war,
				rival_news,
			]
		)
		if GameState.show_daily_overlay:
			body_text += "\n\n★ Daily reward — day %d streak: +%s" % [
				GameState.daily_streak, FormatUtil.format_money(GameState.daily_reward),
			]
		_offline_body.text = body_text
		_offline_watch_ad.visible = (
			Monetization.ads_available() and GameState.can_double_offline_via_ad()
		)
	elif GameState.elim_overlay_active:
		blocking = true
		_elim_panel.visible = true
		_elim_name.text = GameState.elim_overlay_name
		_elim_flavor.text = GameState.elim_overlay_flavor
		_elim_rewards.text = GameState.elim_overlay_rewards
		var pulse: float = 0.6 + 0.4 * sin(_ui_time * 3.0)
		_elim_dismiss.modulate = Color(1.0, 1.0, 1.0, pulse)
	elif not GameState.pending_event.is_empty():
		blocking = true
		_event_panel.visible = true
		_event_title.text = str(GameState.pending_event.get("title", "Syndicate Event"))
		_event_desc.text = str(GameState.pending_event.get("description", ""))
		var event_key: String = str(GameState.pending_event.get("title", ""))
		if event_key != _last_event_key:
			_last_event_key = event_key
			_rebuild_event_choices()
	elif not GameState.milestone_queue.is_empty() and GameState.milestone_timer > 0.0:
		blocking = true
		_milestone_panel.visible = true
		var raw: String = str(GameState.milestone_queue[0])
		var parts: PackedStringArray = raw.split("\n", false)
		if parts.size() >= 2:
			_milestone_title.text = parts[0]
			_milestone_body.text = "\n".join(parts.slice(1))
		else:
			_milestone_title.text = raw
			_milestone_body.text = ""
	else:
		_milestone_panel.visible = false
		_event_panel.visible = false
		_offline_panel.visible = false
		_offline_watch_ad.visible = false
		_elim_panel.visible = false
		_last_event_key = ""
	_overlay_dim.visible = blocking
	if not _TutorialSystem.is_complete(GameState) and not blocking:
		_tutorial_banner.visible = true
		var tut: String = _TutorialSystem.current_text(GameState)
		_tutorial_banner.text = tut + "\n(Skip tutorial in Config)"
	else:
		_tutorial_banner.visible = false
	if not GameState.event_outcome.is_empty():
		_notif.text = GameState.event_outcome
		_notif.add_theme_color_override("font_color", GameTheme.GOLD)


func _rebuild_event_choices() -> void:
	for c in _event_choices.get_children():
		c.queue_free()
	var choices: Array = GameState.pending_event.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%s\n%s" % [ch.get("label", "?"), ch.get("desc", "")]
		var idx: int = i
		btn.pressed.connect(func(): _pick_event_choice(idx))
		_event_choices.add_child(btn)


func _pick_event_choice(idx: int) -> void:
	_EventSystem.resolve_event(GameState, idx)
	GameState.stats_changed.emit()
	_refresh_overlays()


func _dismiss_milestone() -> void:
	_TutorialSystem.dismiss_milestone(GameState)


func _dismiss_offline() -> void:
	GameState.dismiss_offline_overlay()
	_refresh_overlays()


func _on_offline_watch_ad() -> void:
	Monetization.show_rewarded(Monetization.PLACEMENT_OFFLINE_DOUBLE)


func _on_coin_watch_ad() -> void:
	Monetization.show_rewarded(Monetization.PLACEMENT_FREE_COIN)


func _dismiss_elim() -> void:
	GameState.dismiss_elimination_overlay()
	_refresh_overlays()


func _update_motion_cues() -> void:
	if _ManagerSystem.manager_active(GameState, "The Collector"):
		_shield_label.visible = true
		var frac: float = _ManagerSystem.collector_shield_fraction(GameState)
		var filled: int = 3 if frac >= 1.0 else maxi(0, int(round(frac * 3.0)))
		var pips: String = ""
		for i in 3:
			pips += "● " if i < filled else "○ "
		_shield_label.text = "SHIELD %s" % pips.strip_edges()
		if frac >= 1.0:
			var pulse: float = 0.6 + 0.4 * sin(_ui_time * 3.0)
			_shield_label.modulate = Color(1.0, 1.0, 1.0, pulse)
			_heat_bar.modulate = Color(0.85, 0.95, 1.0, pulse)
		else:
			_shield_label.modulate = Color.WHITE
			_heat_bar.modulate = Color.WHITE
	else:
		_shield_label.visible = false
		_heat_bar.modulate = Color.WHITE
	if _BuffSystem.has_buff(GameState, "hustle"):
		var hustle_pulse: float = 0.7 + 0.3 * sin(_ui_time * 5.0)
		_hustle.modulate = Color(1.0, 0.92, 0.55, hustle_pulse)
		_hustle.text = "HUSTLE ×%.2f" % GameConfig.CLICK_HUSTLE_MULT
	else:
		_hustle.modulate = Color.WHITE
		_hustle.text = "HUSTLE"
	var buff_lines: PackedStringArray = PackedStringArray()
	if _BuffSystem.has_buff(GameState, "frenzy"):
		var rem: float = _buff_remaining("frenzy")
		buff_lines.append("FRENZY 7× income  %.0fs" % rem)
	if _BuffSystem.has_buff(GameState, "click_storm"):
		var storm_rem: float = _buff_remaining("click_storm")
		buff_lines.append("CLICK STORM 10×  %.0fs" % storm_rem)
	_buff_label.text = "\n".join(buff_lines)
	var show_coin: bool = (
		GameState.has_golden_coin()
		and not _ManagerSystem.manager_active(GameState, "Lucky Sal")
	)
	_coin_btn.visible = show_coin
	var ads_ok: bool = Monetization.ads_available()
	_coin_ad_btn.visible = (
		ads_ok
		and not show_coin
		and not _ManagerSystem.manager_active(GameState, "Lucky Sal")
	)
	if show_coin:
		var coin_pulse: float = 0.65 + 0.35 * sin(_ui_time * 6.0)
		_coin_btn.modulate = Color(1.0, 0.88, 0.35, coin_pulse)


func _buff_remaining(name: String) -> float:
	for b in GameState.buffs:
		if typeof(b) == TYPE_DICTIONARY and str(b.get("name", "")) == name:
			return float(b.get("remaining", 0.0))
	return 0.0


func _refresh_all() -> void:
	_balance.text = FormatUtil.format_money(GameState.balance)
	_ips.text = "%s/s passive" % FormatUtil.format_money(GameState.income_per_second())
	_rank.text = "%s  ·  %d Influence" % [GameState.rank_label(), GameState.prestige_tokens]
	_heat_bar.value = GameState.heat
	var heat_col := GameTheme.GREEN if GameState.heat < 60.0 else GameTheme.RED
	var heat_txt := "Heat %.0f%%" % GameState.heat
	if _ManagerSystem.manager_active(GameState, "The Promoter"):
		heat_txt += "  ·  autopilot ≤%.0f%%" % _ManagerSystem.promoter_heat_target(GameState)
	_heat_label.text = heat_txt
	_heat_label.add_theme_color_override("font_color", heat_col)
	_click_info.text = "Click: %s" % FormatUtil.format_money(GameState.click_value())
	_prestige_btn.disabled = not GameState.can_prestige()
	var req := Prestige.prestige_earnings_required(GameState.prestige_count, GameState.next_prestige_earnings)
	var prestige_lines: PackedStringArray = PackedStringArray([
		"Prestige: %s / %s lifetime" % [
			FormatUtil.format_money(GameState.lifetime_earnings),
			FormatUtil.format_money(req),
		],
	])
	var adv: Dictionary = _ManagerSystem.prestige_advice(GameState)
	if not adv.is_empty():
		prestige_lines.append("%s — %s" % [adv.get("source", "Advisor"), adv.get("recommend", "")])
		if adv.has("summary"):
			prestige_lines.append(str(adv.get("summary")))
	_prestige_info.text = "\n".join(prestige_lines)
	_refresh_turf_header()
	_refresh_rivals_tab()
	_refresh_crew_tab()
	_refresh_ops_tab()
	_refresh_tab_badges()
	_refresh_dragon_hud()


func _refresh_dragon_hud() -> void:
	var patron: String = _DragonSystem.active_dragon(GameState)
	if patron.is_empty():
		_dragon_hud.visible = false
		return
	_dragon_hud.visible = true
	var meta: Dictionary = _DragonSystem.DRAGON_META[patron]
	var col: Color = meta.get("color", GameTheme.GOLD)
	_dragon_name.text = str(meta.get("title", patron))
	_dragon_name.add_theme_color_override("font_color", col)
	var stage: String = _DragonSystem.get_stage(GameState)
	_dragon_stage.text = _DragonSystem.STAGE_LABELS.get(stage, stage)
	var mood: String = _DragonSystem.get_mood(GameState)
	_dragon_mood.text = _DragonSystem.MOOD_LABELS.get(mood, mood)
	_dragon_mood.add_theme_color_override("font_color", _DragonSystem.MOOD_COLORS.get(mood, GameTheme.TEXT_MUTED))
	var prog: Dictionary = _DragonSystem.stage_xp_progress(GameState)
	var needed: int = int(prog.get("needed", 0))
	if needed > 0:
		_dragon_xp_bar.max_value = float(needed)
		_dragon_xp_bar.value = float(prog.get("progress", 0))
	else:
		_dragon_xp_bar.max_value = 1.0
		_dragon_xp_bar.value = 1.0
	var req: Dictionary = _DragonSystem.get_active_request(GameState)
	if req.is_empty():
		if float(GameState.dragon_request_cooldown) > 1.0:
			_dragon_request.text = "Dragon is resting…"
		else:
			_dragon_request.text = ""
	else:
		_dragon_request.text = "%s\n▸ %s" % [req.get("title", ""), req.get("goal", "")]
	for child in _dragon_abilities.get_children():
		child.queue_free()
	for ab_key in _DragonSystem.get_available_abilities(GameState):
		var ab: Array = _DragonSystem.ABILITIES[ab_key]
		var btn := Button.new()
		var cd: float = _DragonSystem.ability_cooldown_remaining(GameState, ab_key)
		btn.custom_minimum_size = Vector2(0, 24)
		btn.add_theme_font_size_override("font_size", 9)
		if cd > 0.0:
			btn.text = "%s %ds" % [str(ab[2]).substr(0, 8), int(ceil(cd))]
			btn.disabled = true
		else:
			btn.text = str(ab[2]).substr(0, 10)
			var key: String = ab_key
			btn.pressed.connect(func(): GameState.activate_dragon_ability(key))
		_dragon_abilities.add_child(btn)


func _refresh_crew_tab() -> void:
	var total: int = _CrewSystem.available(GameState)
	var unassign: int = _CrewSystem.unassigned(GameState)
	_crew_summary.text = "CREW ASSIGNMENTS  —  %d total crew, %d unassigned" % [total, unassign]
	if _CrewSystem.is_unlocked(GameState):
		_crew_lock.text = ""
		if unassign > 0:
			_crew_lock.text = "%d crew unassigned — assign them for maximum effect!" % unassign
			_crew_lock.add_theme_color_override("font_color", GameTheme.GOLD)
		else:
			_crew_lock.text = "All crew deployed."
			_crew_lock.add_theme_color_override("font_color", GameTheme.GREEN)
	else:
		_crew_lock.text = _CrewSystem.unlock_requirement_text(GameState)
		_crew_lock.add_theme_color_override("font_color", GameTheme.GOLD)


func _refresh_ops_tab() -> void:
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


func _refresh_stats_tab() -> void:
	var ach_earned: int = _AchievementSystem.earned_count(GameState.achievements)
	var ach_total: int = GameState.achievements.size()
	var ach_mult: float = _AchievementSystem.income_mult(GameState.achievements)
	_stats_ach_btn.text = "★ Achievements  %d / %d  ·  +%.0f%% income" % [
		ach_earned, ach_total, (ach_mult - 1.0) * 100.0,
	]
	_stats_ach_btn.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	StatsDashboard.rebuild(_stats_dashboard, GameState)
	if _stats_ach_panel.visible:
		_refresh_achievements_list()


func _refresh_achievements_list() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var cat_order: PackedStringArray = PackedStringArray([
		"money", "clicks", "building", "prestige", "manager",
		"time", "territory", "rival", "operations", "secret",
	])
	var by_cat: Dictionary = {}
	for a in GameState.achievements:
		var cat: String = str(a.get("category", "other"))
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(a)
	for cat in cat_order:
		if not by_cat.has(cat):
			continue
		lines.append(cat.to_upper())
		for a in by_cat[cat]:
			var mark: String = "✓" if bool(a.get("earned", false)) else "○"
			lines.append("  %s  %s — %s" % [mark, a.get("name", ""), a.get("description", "")])
		lines.append("")
	_stats_ach_list.text = "\n".join(lines)


func _toggle_achievements_panel() -> void:
	_stats_ach_panel.visible = not _stats_ach_panel.visible
	if _stats_ach_panel.visible:
		_refresh_achievements_list()


func _close_achievements_panel() -> void:
	_stats_ach_panel.visible = false


func _refresh_turf_header() -> void:
	var territories: Array = GameState.territories
	var total := maxi(1, territories.size())
	var player_count := _TerritorySystem.player_district_count(territories)
	var count_bonus_pct := player_count * 2
	var badge := ""
	var ready_ops := 0
	for op in GameState.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(GameState, op):
			ready_ops += 1
	if ready_ops > 0:
		badge += "  ·  %d ops ready" % ready_ops
	if _ManagerSystem.manager_active(GameState, "The Broker"):
		badge += "  ·  Broker intel"
	_turf_bonus.text = "%d Districts Controlled  ·  +%d%% Global Income%s" % [player_count, count_bonus_pct, badge]
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


func _refresh_rivals_tab() -> void:
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


func _refresh_upgrade_list() -> void:
	for child in _upgrs_list.get_children():
		child.queue_free()
	for i in GameState.upgrades.size():
		if GameState.upgrades[i].purchased:
			continue
		var row: Control = UPGRADE_ROW.instantiate()
		_upgrs_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_upgrade)


func _on_hustle() -> void:
	if GameState.tutorial_step == 0:
		_TutorialSystem.advance_tutorial(GameState)
	var gained: float = GameState.do_click()
	_click_scale = _CLICK_SCALE_MIN
	_spawn_click_float(gained, GameState.last_click_crit)


func _ensure_float_layer() -> void:
	if _float_layer and is_instance_valid(_float_layer):
		return
	_float_layer = Control.new()
	_float_layer.name = "ClickFloats"
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)


## Floating "+$X" / "CRIT +$X" that drifts up and fades — port of the pygame
## click float particles. Cosmetic only; skipped on headless.
func _spawn_click_float(amount: float, crit: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_ensure_float_layer()
	if _float_layer.get_child_count() >= _MAX_FLOATS:
		return
	var lbl := Label.new()
	var money: String = FormatUtil.format_money(amount)
	lbl.text = ("CRIT +%s" % money) if crit else ("+%s" % money)
	lbl.add_theme_font_size_override("font_size", 22 if crit else 16)
	lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT if crit else GameTheme.GREEN)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(lbl)
	var origin: Vector2 = _hustle.global_position + _hustle.size * 0.5
	origin.x += randf_range(-24.0, 24.0)
	origin.y += randf_range(-6.0, 6.0)
	lbl.global_position = origin
	var rise: float = 64.0 if crit else 44.0
	var dur: float = 0.9 if crit else 0.7
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", origin.y - rise, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)


func _on_coin() -> void:
	if GameState.has_golden_coin() and not _ManagerSystem.manager_active(GameState, "Lucky Sal"):
		GameState.collect_golden_coin(false)


func _on_buy(index: int, qty: int) -> void:
	var before: int = GameState.total_buildings_owned()
	GameState.buy_building(index, qty)
	if GameState.tutorial_step == 1 and GameState.total_buildings_owned() > before:
		_TutorialSystem.advance_tutorial(GameState)


func _on_upgrade(index: int) -> void:
	if GameState.buy_upgrade(index):
		_refresh_upgrade_list()


func _on_hire(index: int) -> void:
	GameState.hire_manager(index)


func _on_territory_action(index: int, action: String) -> void:
	var was_unlocked: bool = bool(GameState.territories[index].get("unlocked", false))
	var outcome := GameState.perform_territory_action(index, action)
	var color := GameTheme.GREEN if GameState.territories[index].get("unlocked", false) else GameTheme.GOLD
	_on_notification(outcome, color)
	if not was_unlocked and bool(GameState.territories[index].get("unlocked", false)):
		AudioManager.play("territory")


func _on_rival_action(index: int, action: String) -> void:
	var outcome := GameState.perform_rival_action(index, action)
	if outcome.is_empty():
		_refresh_overlays()
		return
	var color := GameTheme.GOLD_BRIGHT if outcome.begins_with("ELIMINATED") else GameTheme.GREEN if outcome.begins_with("Victory") or outcome.begins_with("Bribed") or outcome.begins_with("Peace") or outcome.begins_with("Sabotage succeeded") else GameTheme.GOLD
	_on_notification(outcome.replace("\n", "  "), color)


func _on_crew_adjust(role_key: String, delta: int) -> void:
	GameState.adjust_crew(role_key, delta)


func _on_operation_action(index: int) -> void:
	var op: Dictionary = GameState.operations[index]
	var outcome: String
	if _OperationSystem.is_ready(GameState, op):
		var first_op: bool = GameState.total_ops_completed == 0
		outcome = GameState.collect_operation(index)
		var color := GameTheme.GREEN if outcome.contains("Complete") else GameTheme.RED
		_on_notification(outcome.replace("\n", "  "), color)
		if outcome.contains("Complete") and not outcome.contains("FAILED"):
			AudioManager.play("manager" if first_op else "achievement")
	else:
		outcome = GameState.start_operation(index)
		_on_notification(outcome, GameTheme.GOLD)


func _on_prestige() -> void:
	if GameState.tutorial_step == 4:
		_TutorialSystem.advance_tutorial(GameState)
	_prestige_tree.open()


func _exit_tree() -> void:
	GameState.set_simulation_active(false)


func _on_menu() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_notification(message: String, color: Color) -> void:
	_notif.text = message
	_notif.add_theme_color_override("font_color", color)
	var is_goal: bool = _is_goal_notification(message, color)
	var is_autobuy: bool = AudioManager.is_autobuy_message(message)
	if is_goal or is_autobuy:
		_notif.add_theme_font_size_override("font_size", maxi(_notif_default_font_size + 2, 15))
		_notif_timer = 4.0 if is_goal else 3.5
		if is_autobuy:
			_notif.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	else:
		_notif.add_theme_font_size_override("font_size", _notif_default_font_size)
		_notif_timer = 2.5
	var cue := AudioManager.cue_for_notification(message, color)
	if not cue.is_empty() and cue != "rankup":
		AudioManager.play(cue)


func _is_goal_notification(message: String, color: Color) -> bool:
	if color != GameTheme.GOLD_BRIGHT or not message.contains("\n"):
		return false
	var parts: PackedStringArray = message.split("\n", false, 1)
	return parts.size() == 2 and parts[1].begins_with("+")


func _refresh_tab_badges() -> void:
	var bld: int = GameState.total_buildings_owned()
	_tab_bldgs.text = "Bldgs"
	_tab_upgrs.text = "Upgrs"
	_tab_mgrs.text = "Mgrs"
	_tab_stats.text = "Stats"
	# Turf subtab badges (Crew/Ops lock progress).
	_sub_territory.text = "Territory"
	_sub_rivals.text = "Rivals"
	if _CrewSystem.is_unlocked(GameState):
		_sub_crew.text = "Crew"
	else:
		_sub_crew.text = "Crew %d/5" % mini(bld, 5)
	var ready_ops := 0
	for op in GameState.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(GameState, op):
			ready_ops += 1
	var ops_unlocked: bool = _OperationSystem.is_unlocked(GameState)
	if ops_unlocked:
		_sub_ops.text = "Ops*" if ready_ops > 0 else "Ops"
	else:
		var terr: int = _TerritorySystem.player_district_count(GameState.territories)
		_sub_ops.text = "Ops %d/2" % mini(terr, 2)
	# Turf bottom-bar button rolls up its subtabs' status.
	var turf_label := "Turf"
	if _ManagerSystem.manager_active(GameState, "The Broker"):
		turf_label = "Turf ★"
	elif ops_unlocked and ready_ops > 0:
		turf_label = "Turf •"
	_tab_turf.text = turf_label


func _build_config_tab() -> void:
	for c in _config_body.get_children():
		c.queue_free()
	_add_config_header("AUDIO")
	_add_cycle_row("Master Volume", ["0%", "25%", "50%", "75%", "100%"], _vol_index(GameState.master_volume), func(i): _set_master_volume(i))
	_add_cycle_row("SFX Volume", ["0%", "25%", "50%", "75%", "100%"], _vol_index(GameState.sfx_volume), func(i): _set_sfx_volume(i))
	_add_cycle_row("Music Volume", ["0%", "25%", "50%", "75%", "100%"], _vol_index(GameState.music_volume), func(i): _set_music_volume(i))
	_add_cycle_row("Mute All", ["OFF", "ON"], 1 if GameState.mute_all else 0, func(i):
		GameState.mute_all = i == 1
		AudioManager.apply_from_state(GameState)
	)
	_add_config_header("DISPLAY")
	_add_cycle_row("FPS Cap", ["30", "60", "120"], [30, 60, 120].find(GameState.fps_cap), func(i): _set_fps_cap(i))
	_add_cycle_row("Particles", ["ON", "OFF"], 0 if GameState.show_particles else 1, func(i): GameState.show_particles = i == 0)
	_add_config_header("RETENTION")
	_add_cycle_row("Notifications", ["OFF", "ON"], 1 if GameState.notifications_enabled else 0, func(i):
		var on: bool = i == 1
		GameState.notifications_enabled = on
		if on:
			Notifications.request_permission()
		SaveManager.save_game()
	)
	_add_cycle_row("Analytics", ["OFF", "ON"], 1 if GameState.telemetry_consent else 0, func(i):
		GameState.telemetry_consent = i == 1
		SaveManager.save_game()
	)
	if CloudSave.is_signed_in():
		var cloud_lbl := Label.new()
		cloud_lbl.text = "Cloud save: signed in"
		cloud_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		_config_body.add_child(cloud_lbl)
	else:
		var cloud_btn := Button.new()
		cloud_btn.text = "Sign in (cloud backup)"
		cloud_btn.pressed.connect(func(): CloudSave.sign_in())
		_config_body.add_child(cloud_btn)
	_add_config_header("STORE")
	_add_iap_row("Remove ads", Monetization.PRODUCT_REMOVE_ADS, "Hides ads permanently")
	_add_iap_row("Starter pack", Monetization.PRODUCT_STARTER, "Cash + Influence boost")
	_add_iap_row("2× income (permanent)", Monetization.PRODUCT_INCOME_X2, "Doubles passive income")
	var restore := Button.new()
	restore.text = "Restore purchases"
	restore.pressed.connect(func(): Monetization.restore())
	_config_body.add_child(restore)
	_add_config_header("DATA")
	var reset_tut := Button.new()
	reset_tut.text = "Reset Tutorial"
	reset_tut.pressed.connect(func(): GameState.reset_tutorial(); _build_config_tab())
	_config_body.add_child(reset_tut)
	var del := Button.new()
	del.text = "Delete Save"
	del.pressed.connect(func(): SaveManager.delete_save(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_config_body.add_child(del)
	var note := Label.new()
	note.text = "Auto-save every %ds" % int(GameConfig.AUTOSAVE_INTERVAL)
	note.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_config_body.add_child(note)


func _add_config_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", GameTheme.GOLD)
	_config_body.add_child(lbl)


func _add_cycle_row(label: String, options: Array, index: int, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	var holder: Dictionary = {"i": clampi(index, 0, options.size() - 1)}
	btn.text = str(options[holder.i])
	btn.pressed.connect(func():
		holder.i = (int(holder.i) + 1) % options.size()
		btn.text = str(options[holder.i])
		cb.call(holder.i)
	)
	row.add_child(btn)
	_config_body.add_child(row)


func _add_iap_row(label: String, product_id: String, hint: String) -> void:
	if Monetization.product_owned(product_id):
		var owned := Label.new()
		owned.text = "%s — owned" % label
		owned.add_theme_color_override("font_color", GameTheme.GREEN)
		_config_body.add_child(owned)
		return
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn := Button.new()
	btn.text = "Buy"
	btn.tooltip_text = hint
	btn.pressed.connect(func(): Monetization.purchase(product_id))
	row.add_child(btn)
	_config_body.add_child(row)


func _vol_index(v: float) -> int:
	if v <= 0.01:
		return 0
	if v <= 0.26:
		return 1
	if v <= 0.51:
		return 2
	if v <= 0.76:
		return 3
	return 4


func _set_master_volume(i: int) -> void:
	GameState.master_volume = [0.0, 0.25, 0.5, 0.75, 1.0][i]
	AudioManager.apply_from_state(GameState)


func _set_sfx_volume(i: int) -> void:
	GameState.sfx_volume = [0.0, 0.25, 0.5, 0.75, 1.0][i]
	AudioManager.apply_from_state(GameState)


func _set_music_volume(i: int) -> void:
	GameState.music_volume = [0.0, 0.25, 0.5, 0.75, 1.0][i]
	AudioManager.apply_from_state(GameState)


func _set_fps_cap(i: int) -> void:
	var caps: Array = [30, 60, 120]
	GameState.fps_cap = int(caps[i])
	Engine.max_fps = GameState.fps_cap
