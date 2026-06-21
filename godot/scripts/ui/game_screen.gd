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
const MusicDefs = preload("res://scripts/audio/music_defs.gd")

const BUILDING_ROW := preload("res://scenes/building_row.tscn")
const UPGRADE_ROW := preload("res://scenes/upgrade_row.tscn")
const MANAGER_ROW := preload("res://scenes/manager_row.tscn")
const TERRITORY_ROW := preload("res://scenes/territory_row.tscn")
const RIVAL_ROW := preload("res://scenes/rival_row.tscn")
const CREW_ROW := preload("res://scenes/crew_row.tscn")
const OPERATION_ROW := preload("res://scenes/operation_row.tscn")

enum Tab { BLDGS, UPGRS, TURF, RIVALS, CREW, OPS, STATS, MGRS, CONFIG }

@onready var _balance: Label = $Root/VBox/Header/EconomyCol/Balance
@onready var _ips: Label = $Root/VBox/Header/EconomyCol/Income
@onready var _rank: Label = $Root/VBox/Header/RankChip/Rank
@onready var _rank_chip: PanelContainer = $Root/VBox/Header/RankChip
@onready var _advice_chip: Button = $Root/VBox/Header/AdviceChip
@onready var _buy_mult_chip: Button = $Root/VBox/Header/BuyMultChip
@onready var _heat_bar: ProgressBar = $Root/VBox/StatusStrip/HeatRow/HeatBar
@onready var _heat_label: Label = $Root/VBox/StatusStrip/HeatRow/HeatLabel
@onready var _coin_btn: Button = $Root/VBox/StatusStrip/StatusRow/CoinBtn
@onready var _shield_label: Label = $Root/VBox/StatusStrip/StatusRow/ShieldLabel
@onready var _city_view: Control = $Root/VBox/CityViewport/CityView
@onready var _hustle_band: Control = $Root/VBox/HustleBand
@onready var _click_info: Label = $Root/VBox/StatusStrip/StatusRow/ClickInfo
@onready var _prestige_btn: Button = $Root/VBox/StatusStrip/PrestigeRow/PrestigeBtn
@onready var _prestige_info: Label = $Root/VBox/StatusStrip/PrestigeRow/PrestigeInfo
@onready var _buff_label: Label = $Root/VBox/StatusStrip/StatusRow/BuffLabel
@onready var _city_viewport: Control = $Root/VBox/CityViewport
@onready var _status_strip: VBoxContainer = $Root/VBox/StatusStrip
@onready var _status_row: HBoxContainer = $Root/VBox/StatusStrip/StatusRow
@onready var _prestige_row: HBoxContainer = $Root/VBox/StatusStrip/PrestigeRow
@onready var _heat_row: HBoxContainer = $Root/VBox/StatusStrip/HeatRow
# Bottom nav bar (5 primary tabs) + Turf subtab bar + header gear.
@onready var _bottom_bar: HBoxContainer = $Root/VBox/BottomBar
@onready var _header: HBoxContainer = $Root/VBox/Header
@onready var _body_right: VBoxContainer = $Root/VBox/Body/Right
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
@onready var _prestige_tree: CanvasLayer = $PrestigeTreeOverlay
@onready var _dragon_patron: CanvasLayer = $DragonPatronOverlay
@onready var _dragon_hud: PanelContainer = $Root/VBox/StatusStrip/DragonHud
@onready var _dragon_name: Label = $Root/VBox/StatusStrip/DragonHud/VBox/Header/Name
@onready var _dragon_mood: Label = $Root/VBox/StatusStrip/DragonHud/VBox/Header/Mood
@onready var _dragon_stage: Label = $Root/VBox/StatusStrip/DragonHud/VBox/Stage
@onready var _dragon_xp_bar: ProgressBar = $Root/VBox/StatusStrip/DragonHud/VBox/XpBar
@onready var _dragon_request: Label = $Root/VBox/StatusStrip/DragonHud/VBox/Request
@onready var _dragon_abilities: HBoxContainer = $Root/VBox/StatusStrip/DragonHud/VBox/AbilityRow
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
@onready var _offline_title: Label = $OverlayLayer/OfflinePanel/VBox/Title
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
var _notif_shell: PanelContainer
var _tutorial_shell: PanelContainer
var _overlay_kind: String = ""
var _active_overlay_kind: String = ""
var _overlay_shown_at: int = 0
var _tab_badge_snapshot: Dictionary = {}
var _tab_badge_impressions: Dictionary = {}
var _music_ctx_timer := 0.0
const STATS_REFRESH_INTERVAL := 0.2
const _BASE_MARGIN := 12
const _MUSIC_CTX_INTERVAL := 1.0

var _fallback_hustle: Button
var _coin_on_band: bool = false
var _dragon_chip: Button
var _last_city_tier: int = -1


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
	GameState.mark_ui_session_start()
	if AudioManager.is_enabled():
		AudioManager.set_music_mode(MusicDefs.MusicMode.PLAYING_AMBIENT)
	_apply_safe_area()
	_apply_ui_surfaces()
	_apply_header_theme()
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
	_hustle_band.hustle_pressed.connect(_on_hustle)
	_coin_btn.pressed.connect(_on_coin)
	_prestige_btn.pressed.connect(_on_prestige)
	_buy_mult_chip.pressed.connect(_on_buy_mult_chip)
	_advice_chip.pressed.connect(_on_advice_chip)
	_tab_bldgs.pressed.connect(func(): _open_tab(Tab.BLDGS))
	_tab_upgrs.pressed.connect(func(): _open_tab(Tab.UPGRS))
	_tab_mgrs.pressed.connect(func(): _open_tab(Tab.MGRS))
	_tab_turf.pressed.connect(_open_turf)
	_tab_stats.pressed.connect(func(): _open_tab(Tab.STATS))
	_cfg_btn.pressed.connect(func(): _open_tab(Tab.CONFIG))
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
	_apply_overlay_theme()
	_overlay_dim.gui_input.connect(_on_overlay_dim_input)
	_coin_ad_btn = Button.new()
	_coin_ad_btn.text = "Ad → coin"
	_coin_btn.get_parent().add_child(_coin_ad_btn)
	_coin_ad_btn.pressed.connect(_on_coin_watch_ad)
	_apply_city_layout()
	_elim_dismiss.pressed.connect(_dismiss_elim)
	_notif_default_font_size = _notif.get_theme_font_size("font_size")
	_build_config_tab()
	_stats_ach_btn.pressed.connect(_toggle_achievements_panel)
	_stats_ach_close.pressed.connect(_close_achievements_panel)
	_refresh_all()
	Telemetry.log_event("ui_session_start", {"tab": _tab_name(_tab)})


func _apply_header_theme() -> void:
	GameTheme.apply_economy_hud(_balance, _ips, _rank)
	_rank_chip.add_theme_stylebox_override("panel", GameTheme.chip_style(false))
	_buy_mult_chip.add_theme_stylebox_override("normal", GameTheme.chip_style(true))
	_buy_mult_chip.add_theme_stylebox_override("hover", GameTheme.chip_style(true))
	_buy_mult_chip.add_theme_stylebox_override("pressed", GameTheme.chip_style(true))
	_buy_mult_chip.add_theme_stylebox_override("disabled", GameTheme.chip_style(false))
	_advice_chip.add_theme_stylebox_override("normal", GameTheme.chip_style(false))
	_advice_chip.add_theme_stylebox_override("hover", GameTheme.chip_style(true))
	_advice_chip.add_theme_stylebox_override("pressed", GameTheme.chip_style(true))
	_advice_chip.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_buy_mult_chip.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_buy_mult_chip.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_CHIP))
	_advice_chip.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_CHIP - 1))
	if GameTheme.is_city_v2_active():
		GameTheme.apply_ink_icon_button(_cfg_btn)
	for tab_btn in [_tab_bldgs, _tab_upgrs, _tab_mgrs, _tab_turf, _tab_stats,
			_sub_territory, _sub_rivals, _sub_crew, _sub_ops]:
		GameTheme.apply_tab_button(tab_btn, false)
	_refresh_tab_strip()
	if GameTheme.is_city_v2_active():
		_apply_tab_body_ink()


func _apply_ui_surfaces() -> void:
	if GameTheme.is_rustic_active():
		_apply_rustic_surfaces()
	elif GameTheme.is_city_v2_active():
		_apply_city_v2_surfaces()


func _apply_city_v2_surfaces() -> void:
	_wrap_strip_panel(_header, GameTheme.ink_header_strip_style())
	_wrap_strip_panel(_bottom_bar, GameTheme.ink_tab_bar_style())
	for scroll in [
		_bldgs_scroll, _upgrs_scroll, _turf_scroll, _rivals_scroll,
		_crew_scroll, _ops_scroll, _stats_scroll, _mgrs_scroll, _config_scroll,
	]:
		_wrap_ink_content_panel(scroll)
	_apply_ink_subtab_headers()
	_wrap_notif_toast()
	_wrap_tutorial_banner()
	_apply_tab_body_ink()
	_bottom_bar.add_theme_constant_override("separation", 2)


func _apply_tab_body_ink() -> void:
	if not GameTheme.is_city_v2_active():
		return
	GameTheme.apply_ink_chip_button(_stats_ach_btn, false, GameTheme.FONT_CHIP, GameTheme.GOLD_BRIGHT)
	_stats_ach_btn.custom_minimum_size.y = maxf(float(_stats_ach_btn.custom_minimum_size.y), 40.0)
	GameTheme.apply_ink_chip_button(_stats_ach_close, false)
	var ach_header: Label = _stats_ach_panel.get_node("AchHeader") as Label
	if ach_header != null:
		GameTheme.apply_list_section_title(ach_header)
	_stats_ach_list.add_theme_color_override("font_color", GameTheme.TEXT)
	_stats_ach_list.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))


func _wrap_ink_content_panel(scroll: ScrollContainer) -> void:
	if scroll.get_meta("_city_v2_panel", false):
		return
	var parent := scroll.get_parent()
	if parent == null:
		return
	var idx := scroll.get_index()
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameTheme.ink_scroll_wrap_style())
	parent.remove_child(scroll)
	panel.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	parent.move_child(panel, idx)
	scroll.set_meta("_city_v2_panel", true)


func _apply_ink_subtab_headers() -> void:
	for lbl in [
		_turf_bonus, _turf_milestones, _turf_control, _rivals_impact,
		_rivals_activity, _crew_summary, _crew_lock, _ops_summary, _ops_lock,
	]:
		GameTheme.apply_subtab_header_label(lbl)
		lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)


func _wrap_notif_toast() -> void:
	if _notif.get_meta("_ink_toast", false):
		return
	var parent := _notif.get_parent()
	if parent == null:
		return
	var idx := _notif.get_index()
	var panel := PanelContainer.new()
	panel.visible = false
	panel.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
	parent.remove_child(_notif)
	panel.add_child(_notif)
	_notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notif.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	parent.add_child(panel)
	parent.move_child(panel, idx)
	panel.set_meta("_ink_toast", true)
	_notif.set_meta("_ink_toast", true)
	_notif_shell = panel


func _wrap_tutorial_banner() -> void:
	if _tutorial_banner.get_meta("_ink_banner", false):
		return
	var parent := _tutorial_banner.get_parent()
	if parent == null:
		return
	var panel := PanelContainer.new()
	panel.visible = _tutorial_banner.visible
	panel.anchor_left = _tutorial_banner.anchor_left
	panel.anchor_top = _tutorial_banner.anchor_top
	panel.anchor_right = _tutorial_banner.anchor_right
	panel.anchor_bottom = _tutorial_banner.anchor_bottom
	panel.offset_left = _tutorial_banner.offset_left
	panel.offset_top = _tutorial_banner.offset_top
	panel.offset_right = _tutorial_banner.offset_right
	panel.offset_bottom = _tutorial_banner.offset_bottom
	panel.grow_horizontal = _tutorial_banner.grow_horizontal
	panel.grow_vertical = _tutorial_banner.grow_vertical
	panel.add_theme_stylebox_override("panel", GameTheme.ink_tutorial_banner_style())
	parent.remove_child(_tutorial_banner)
	panel.add_child(_tutorial_banner)
	parent.add_child(panel)
	_tutorial_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_banner.offset_left = 10.0
	_tutorial_banner.offset_top = 6.0
	_tutorial_banner.offset_right = -10.0
	_tutorial_banner.offset_bottom = -6.0
	_tutorial_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_banner.add_theme_color_override("font_color", GameTheme.TEXT)
	_tutorial_banner.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_tutorial_banner.add_theme_constant_override("outline_size", 0)
	panel.set_meta("_ink_banner", true)
	_tutorial_banner.set_meta("_ink_banner", true)
	_tutorial_shell = panel


func _apply_city_layout() -> void:
	var city_on := GameConfig.UI_CITY_VIEW and GameConfig.UI_CITY_V2
	_city_viewport.visible = city_on
	_hustle_band.visible = city_on
	if city_on:
		_relocate_coin_to_band()
		_apply_city_v2_status_strip()
		if _fallback_hustle:
			_fallback_hustle.visible = false
	else:
		_restore_coin_to_status()
		_restore_status_strip()
		_ensure_fallback_hustle()


func _apply_city_v2_status_strip() -> void:
	if not GameTheme.is_city_v2_active():
		return
	_status_row.visible = false
	_prestige_row.visible = false
	_click_info.visible = false
	_prestige_info.visible = false
	_prestige_btn.custom_minimum_size = Vector2(0, 28)
	_prestige_btn.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_prestige_btn.add_theme_stylebox_override("normal", GameTheme.make_chip_flat(false))
	_prestige_btn.add_theme_stylebox_override("hover", GameTheme.make_chip_flat(true))
	_prestige_btn.add_theme_stylebox_override("pressed", GameTheme.make_chip_flat(true))
	_prestige_btn.add_theme_stylebox_override("disabled", GameTheme.make_chip_flat(false))
	_prestige_btn.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_prestige_btn.add_theme_color_override("font_disabled_color", GameTheme.TEXT_MUTED)
	_heat_bar.custom_minimum_size = Vector2(0, 12)
	_heat_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_heat_label.add_theme_color_override("font_color", GameTheme.TEXT)
	_shield_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_shield_label.add_theme_color_override("font_color", GameTheme.BLUE_BRIGHT)
	_buff_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_buff_label.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_status_strip.add_theme_constant_override("separation", 2)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("1a1520")
	bar_bg.set_corner_radius_all(3)
	_heat_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GameTheme.GREEN
	bar_fill.set_corner_radius_all(3)
	_heat_bar.add_theme_stylebox_override("fill", bar_fill)
	if _prestige_btn.get_parent() != _heat_row:
		_prestige_btn.reparent(_heat_row)
	if _shield_label.get_parent() != _heat_row:
		_shield_label.reparent(_heat_row)
	if _buff_label.get_parent() != _heat_row:
		_buff_label.reparent(_heat_row)
		_buff_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	if _dragon_chip == null:
		_dragon_chip = Button.new()
		_dragon_chip.custom_minimum_size = Vector2(0, 28)
		_dragon_chip.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
		_dragon_chip.add_theme_stylebox_override("normal", GameTheme.make_chip_flat(false))
		_dragon_chip.add_theme_stylebox_override("hover", GameTheme.make_chip_flat(true))
		_dragon_chip.add_theme_stylebox_override("pressed", GameTheme.make_chip_flat(true))
		_dragon_chip.pressed.connect(_on_dragon_chip)
		_heat_row.add_child(_dragon_chip)


func _restore_status_strip() -> void:
	_status_row.visible = true
	_prestige_row.visible = true
	_click_info.visible = true
	_prestige_info.visible = true
	if _prestige_btn.get_parent() != _prestige_row:
		_prestige_btn.reparent(_prestige_row)
		_prestige_row.move_child(_prestige_btn, 0)
	if _shield_label.get_parent() != _status_row:
		_shield_label.reparent(_status_row)
		_status_row.move_child(_shield_label, 0)
	if _buff_label.get_parent() != _status_row:
		_buff_label.reparent(_status_row)
	_prestige_btn.custom_minimum_size = Vector2(0, 36)
	_prestige_btn.remove_theme_font_size_override("font_size")
	for state in ["normal", "hover", "pressed", "disabled"]:
		_prestige_btn.remove_theme_stylebox_override(state)
	_heat_bar.custom_minimum_size = Vector2(0, 16)
	_heat_label.remove_theme_font_size_override("font_size")
	_status_strip.remove_theme_constant_override("separation")
	for part in ["background", "fill"]:
		_heat_bar.remove_theme_stylebox_override(part)
	if _dragon_chip:
		_dragon_chip.visible = false


func _on_dragon_chip() -> void:
	_dragon_patron.open()


func _relocate_coin_to_band() -> void:
	if _coin_on_band:
		return
	var col := _hustle_band.call("get_coin_column") as Control
	if col == null:
		return
	_coin_btn.reparent(col)
	_coin_ad_btn.reparent(col)
	_coin_btn.custom_minimum_size = Vector2(0, 32)
	_coin_btn.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_coin_ad_btn.custom_minimum_size = Vector2(0, 32)
	_coin_ad_btn.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_coin_on_band = true


func _restore_coin_to_status() -> void:
	if not _coin_on_band:
		return
	_coin_btn.reparent(_status_row)
	_coin_ad_btn.reparent(_status_row)
	_coin_btn.custom_minimum_size = Vector2(0, 32)
	_coin_btn.remove_theme_font_size_override("font_size")
	_coin_ad_btn.custom_minimum_size = Vector2(0, 32)
	_coin_ad_btn.remove_theme_font_size_override("font_size")
	_coin_on_band = false


func _ensure_fallback_hustle() -> void:
	if GameConfig.UI_CITY_VIEW and GameConfig.UI_CITY_V2:
		if _fallback_hustle:
			_fallback_hustle.visible = false
		return
	if _fallback_hustle == null:
		_fallback_hustle = Button.new()
		_fallback_hustle.text = "HUSTLE"
		_fallback_hustle.custom_minimum_size = Vector2(0, 36)
		_fallback_hustle.pressed.connect(_on_hustle)
		_status_row.add_child(_fallback_hustle)
		_status_row.move_child(_fallback_hustle, 0)
	_fallback_hustle.visible = true


func _apply_rustic_surfaces() -> void:
	if not GameTheme.is_rustic_active():
		return
	_wrap_strip_panel(_header, GameTheme.header_strip_style())
	_wrap_strip_panel(_bottom_bar, GameTheme.tab_bar_bg_style())
	for scroll in [
		_bldgs_scroll, _upgrs_scroll, _turf_scroll, _rivals_scroll,
		_crew_scroll, _ops_scroll, _stats_scroll, _mgrs_scroll, _config_scroll,
	]:
		_wrap_content_panel(scroll)
	_dragon_hud.add_theme_stylebox_override("panel", GameTheme.panel_style())
	_apply_rustic_subtab_headers()


func _wrap_strip_panel(inner: Control, style: StyleBox) -> void:
	if inner.get_meta("_rustic_wrapped", false):
		return
	var parent := inner.get_parent()
	if parent == null:
		return
	var idx := inner.get_index()
	var shell := PanelContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_stylebox_override("panel", style)
	parent.remove_child(inner)
	shell.add_child(inner)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(shell)
	parent.move_child(shell, idx)
	inner.set_meta("_rustic_wrapped", true)


func _wrap_content_panel(scroll: ScrollContainer) -> void:
	if scroll.get_meta("_rustic_panel", false):
		return
	var parent := scroll.get_parent()
	if parent == null:
		return
	var idx := scroll.get_index()
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameTheme.panel_style())
	parent.remove_child(scroll)
	panel.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	parent.move_child(panel, idx)
	scroll.set_meta("_rustic_panel", true)


func _wrap_body_panel(inner: Control, style: StyleBox) -> void:
	if inner.get_meta("_rustic_wrapped", false):
		return
	var parent := inner.get_parent()
	if parent == null:
		return
	var idx := inner.get_index()
	var shell := PanelContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", style)
	parent.remove_child(inner)
	shell.add_child(inner)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(shell)
	parent.move_child(shell, idx)
	inner.set_meta("_rustic_wrapped", true)


func _apply_rustic_subtab_headers() -> void:
	for lbl in [
		_turf_bonus, _turf_milestones, _turf_control, _rivals_impact,
		_rivals_activity, _crew_summary, _crew_lock, _ops_summary, _ops_lock,
	]:
		GameTheme.apply_subtab_header_label(lbl)


func _apply_overlay_theme() -> void:
	_milestone_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_milestone_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(18))
	_milestone_body.add_theme_color_override("font_color", GameTheme.TEXT)
	_milestone_body.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_event_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_event_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(17))
	_event_desc.add_theme_color_override("font_color", GameTheme.TEXT)
	_event_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_offline_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_offline_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(20))
	_offline_body.add_theme_color_override("font_color", GameTheme.TEXT)
	_offline_body.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_elim_name.add_theme_color_override("font_color", GameTheme.GOLD)
	_elim_name.add_theme_font_size_override("font_size", GameTheme.scaled_font(18))
	_elim_flavor.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_elim_flavor.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_elim_rewards.add_theme_color_override("font_color", GameTheme.GREEN)
	_elim_rewards.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	GameTheme.apply_overlay_cta(_milestone_dismiss, true)
	_milestone_dismiss.text = "Tap to continue"
	GameTheme.apply_overlay_cta(_offline_continue, true)
	_offline_continue.mouse_filter = Control.MOUSE_FILTER_STOP
	GameTheme.apply_overlay_cta(_offline_watch_ad, false)
	GameTheme.apply_overlay_cta(_elim_dismiss, true)
	_elim_dismiss.text = "Tap to continue"


func _tab_name(tab: Tab) -> String:
	match tab:
		Tab.BLDGS: return "bldgs"
		Tab.UPGRS: return "upgrs"
		Tab.MGRS: return "mgrs"
		Tab.TURF: return "turf"
		Tab.RIVALS: return "rivals"
		Tab.CREW: return "crew"
		Tab.OPS: return "ops"
		Tab.STATS: return "stats"
		Tab.CONFIG: return "config"
		_: return "unknown"


func _open_tab(tab: Tab) -> void:
	_maybe_log_badge_click(tab)
	_set_tab(tab)


func _maybe_log_badge_click(tab: Tab) -> void:
	var key := _tab_name(tab)
	if _tab_badge_snapshot.get(key, 0) > 0:
		Telemetry.log_event("ui_badge_click", {"tab": key, "count": _tab_badge_snapshot[key]})


func _populate_buildings() -> void:
	_add_list_section_header(_bldgs_list, "FRONT BUSINESSES")
	for i in GameState.buildings.size():
		var row: Control = BUILDING_ROW.instantiate()
		_bldgs_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_buy)


func _populate_upgrades() -> void:
	_add_list_section_header(_upgrs_list, "EMPIRE UPGRADES")
	for i in GameState.upgrades.size():
		if GameState.upgrades[i].purchased:
			continue
		var row: Control = UPGRADE_ROW.instantiate()
		_upgrs_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_upgrade)


func _populate_managers() -> void:
	_add_list_section_header(_mgrs_list, "SYNDICATE MANAGERS")
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


func _districts_owned() -> int:
	var n := 0
	for t in GameState.territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			n += 1
	return n


func _city_top_building_keys() -> Array:
	var ranked: Array = []
	for b in GameState.buildings:
		if b.owned > 0:
			ranked.append({"key": b.icon_key, "owned": b.owned})
	ranked.sort_custom(func(a, b): return int(a["owned"]) > int(b["owned"]))
	var out: Array = []
	for entry in ranked:
		out.append(str(entry["key"]))
		if out.size() >= 3:
			break
	return out


func _city_district_slots() -> Array:
	var out: Array = []
	var limit := mini(GameState.territories.size(), 12)
	for i in limit:
		var t = GameState.territories[i]
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var name_str := str(t.get("name", ""))
		var short := name_str.substr(0, mini(3, name_str.length())).to_upper()
		out.append({
			"unlocked": bool(t.get("unlocked", false)),
			"color": t.get("color", Color8(60, 60, 80)),
			"short": short,
		})
	return out


func _city_tier_from_buildings(total: int) -> int:
	if total < 5:
		return 0
	if total < 15:
		return 1
	if total < 35:
		return 2
	if total < 80:
		return 3
	return 4


func _track_city_tier(total: int) -> void:
	if not GameConfig.UI_CITY_VIEW or not GameConfig.UI_CITY_V2:
		return
	var tier := _city_tier_from_buildings(total)
	if tier == _last_city_tier:
		return
	if _last_city_tier >= 0:
		Telemetry.log_event("ui_city_tier_change", {
			"tier": tier,
			"from": _last_city_tier,
			"buildings": total,
		})
	_last_city_tier = tier


func _refresh_city_view(overlay_blocking: bool) -> void:
	var total := GameState.total_buildings_owned()
	_track_city_tier(total)
	if _hustle_band != null and _hustle_band.has_method("set_overlay_occluded"):
		_hustle_band.call("set_overlay_occluded", overlay_blocking)
		_hustle_band.call("set_click_scale", _click_scale)
		_hustle_band.call(
			"refresh",
			GameState.click_value(),
			GameState.income_per_second(),
			_BuffSystem.has_buff(GameState, "hustle"),
			GameConfig.CLICK_HUSTLE_MULT,
			_click_scale,
		)
	if _city_view == null or not _city_view.has_method("refresh"):
		return
	_city_view.call("set_overlay_occluded", overlay_blocking)
	_city_view.call(
		"refresh",
		total,
		GameState.heat,
		_districts_owned(),
		GameState.prestige_tokens,
		_city_top_building_keys(),
		_city_district_slots(),
	)


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


## Toggle a tab's scroll visibility. Under the rustic theme each scroll is wrapped
## in an EXPAND_FILL PanelContainer (_wrap_content_panel); the wrapper must follow
## the scroll's visibility or all 9 wrappers stay visible and split Right's height,
## clipping the active tab to a ~51px sliver.
func _scroll_vis(scroll: Control, vis: bool) -> void:
	scroll.visible = vis
	if scroll.get_meta("_rustic_panel", false) or scroll.get_meta("_city_v2_panel", false):
		var wrapper := scroll.get_parent()
		if wrapper is PanelContainer:
			(wrapper as PanelContainer).visible = vis


func _set_tab(tab: Tab) -> void:
	_tab = tab
	var is_turf: bool = tab in _TURF_TABS
	_scroll_vis(_bldgs_scroll, tab == Tab.BLDGS)
	_scroll_vis(_upgrs_scroll, tab == Tab.UPGRS)
	_scroll_vis(_turf_scroll, tab == Tab.TURF)
	_scroll_vis(_rivals_scroll, tab == Tab.RIVALS)
	_scroll_vis(_crew_scroll, tab == Tab.CREW)
	_scroll_vis(_ops_scroll, tab == Tab.OPS)
	_scroll_vis(_stats_scroll, tab == Tab.STATS)
	_scroll_vis(_mgrs_scroll, tab == Tab.MGRS)
	_scroll_vis(_config_scroll, tab == Tab.CONFIG)
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
		Telemetry.log_event("ui_config_open", {})
	else:
		_close_achievements_panel()
	Telemetry.log_event("ui_tab_open", {"tab": _tab_name(tab)})
	_refresh_tab_strip()


func _refresh_tab_strip() -> void:
	var tab: Tab = _tab
	var is_turf: bool = tab in _TURF_TABS
	GameTheme.apply_tab_button(_tab_bldgs, tab == Tab.BLDGS)
	GameTheme.apply_tab_button(_tab_upgrs, tab == Tab.UPGRS)
	GameTheme.apply_tab_button(_tab_mgrs, tab == Tab.MGRS)
	GameTheme.apply_tab_button(_tab_turf, is_turf)
	GameTheme.apply_tab_button(_tab_stats, tab == Tab.STATS)
	if is_turf:
		GameTheme.apply_tab_button(_sub_territory, tab == Tab.TURF)
		GameTheme.apply_tab_button(_sub_rivals, tab == Tab.RIVALS)
		GameTheme.apply_tab_button(_sub_crew, tab == Tab.CREW)
		GameTheme.apply_tab_button(_sub_ops, tab == Tab.OPS)


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
			_clear_notif()
	if _tab == Tab.STATS:
		_stats_refresh_timer -= delta
		if _stats_refresh_timer <= 0.0:
			_stats_refresh_timer = STATS_REFRESH_INTERVAL
			_refresh_stats_tab()
	_update_motion_cues()
	_refresh_overlays()
	var blocking: bool = bool(_pick_blocking_overlay().get("blocking", false))
	_refresh_city_view(blocking)
	_music_ctx_timer -= delta
	if _music_ctx_timer <= 0.0:
		_music_ctx_timer = _MUSIC_CTX_INTERVAL
		if AudioManager.is_enabled():
			AudioManager.update_music_context({"heat": GameState.heat, "tab": _tab})
	if _click_scale < 1.0:
		_click_scale = minf(1.0, _click_scale + _CLICK_SCALE_RATE * delta)


func _refresh_overlays() -> void:
	var pick := _pick_blocking_overlay()
	var blocking: bool = pick.get("blocking", false)
	var overlay_kind: String = str(pick.get("kind", ""))
	if overlay_kind != _active_overlay_kind:
		_hide_all_overlay_panels()
		_apply_active_overlay(overlay_kind)
		_active_overlay_kind = overlay_kind
	elif overlay_kind in ["offline", "daily"]:
		_refresh_offline_panel_extras(overlay_kind)
	elif overlay_kind == "elim" and not GameTheme.ui_reduced_motion():
		var pulse: float = 0.6 + 0.4 * sin(_ui_time * 3.0)
		_elim_dismiss.modulate = Color(1.0, 1.0, 1.0, pulse)
	_sync_overlay_telemetry(overlay_kind, blocking)
	_overlay_dim.visible = blocking
	if not _TutorialSystem.is_complete(GameState) and not blocking:
		_tutorial_banner.visible = true
		if _tutorial_shell:
			_tutorial_shell.visible = true
		var tut: String = _TutorialSystem.current_text(GameState)
		_tutorial_banner.text = tut + "\n(Skip tutorial in Config)"
	else:
		_tutorial_banner.visible = false
		if _tutorial_shell:
			_tutorial_shell.visible = false
	if not GameState.event_outcome.is_empty():
		_notif.text = GameState.event_outcome
		_notif.add_theme_color_override("font_color", GameTheme.GOLD)
		if _notif_shell:
			_notif_shell.visible = true


## Single-flight overlay queue — offline → daily → elim → milestone → event (never parallel).
func _pick_blocking_overlay() -> Dictionary:
	if GameState.show_offline_overlay:
		return {"kind": "offline", "blocking": true}
	if GameState.show_daily_overlay:
		return {"kind": "daily", "blocking": true}
	if GameState.elim_overlay_active:
		return {"kind": "elim", "blocking": true}
	if not GameState.milestone_queue.is_empty() and GameState.milestone_timer > 0.0:
		return {"kind": "milestone", "blocking": true}
	if not GameState.pending_event.is_empty():
		return {"kind": "event", "blocking": true}
	return {"kind": "", "blocking": false}


func _hide_all_overlay_panels() -> void:
	_milestone_panel.visible = false
	_event_panel.visible = false
	_offline_panel.visible = false
	_offline_watch_ad.visible = false
	_elim_panel.visible = false
	_elim_dismiss.modulate = Color.WHITE


func _apply_active_overlay(overlay_kind: String) -> void:
	match overlay_kind:
		"offline":
			_offline_panel.visible = true
			_offline_title.text = "WELCOME BACK, BOSS"
			_offline_body.text = _offline_body_text(false)
			_offline_continue.text = "Tap to continue"
			_offline_watch_ad.visible = (
				Monetization.ads_available() and GameState.can_double_offline_via_ad()
			)
		"daily":
			_offline_panel.visible = true
			_offline_title.text = "DAILY REWARD"
			_offline_body.text = _offline_body_text(true)
			_offline_continue.text = "Collect reward"
			_offline_watch_ad.visible = false
		"elim":
			_elim_panel.visible = true
			_elim_name.text = GameState.elim_overlay_name
			_elim_flavor.text = GameState.elim_overlay_flavor
			_elim_rewards.text = GameState.elim_overlay_rewards
			if not GameTheme.ui_reduced_motion():
				var pulse: float = 0.6 + 0.4 * sin(_ui_time * 3.0)
				_elim_dismiss.modulate = Color(1.0, 1.0, 1.0, pulse)
		"milestone":
			_milestone_panel.visible = true
			var raw: String = str(GameState.milestone_queue[0])
			var parts: PackedStringArray = raw.split("\n", false)
			if parts.size() >= 2:
				_milestone_title.text = parts[0]
				_milestone_body.text = "\n".join(parts.slice(1))
			else:
				_milestone_title.text = raw
				_milestone_body.text = ""
		"event":
			_event_panel.visible = true
			_event_title.text = str(GameState.pending_event.get("title", "Syndicate Event"))
			_event_desc.text = str(GameState.pending_event.get("description", ""))
			var event_key: String = str(GameState.pending_event.get("title", ""))
			if event_key != _last_event_key:
				_last_event_key = event_key
				_rebuild_event_choices()
		_:
			_last_event_key = ""


func _refresh_offline_panel_extras(overlay_kind: String) -> void:
	if overlay_kind != "offline":
		_offline_watch_ad.visible = false
		return
	_offline_watch_ad.visible = (
		Monetization.ads_available() and GameState.can_double_offline_via_ad()
	)


func _on_overlay_dim_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	match _active_overlay_kind:
		"offline", "daily":
			_dismiss_offline()
		"milestone":
			_dismiss_milestone()
		"elim":
			_dismiss_elim()


func _sync_overlay_telemetry(overlay_kind: String, _blocking: bool) -> void:
	if overlay_kind != _overlay_kind:
		if not overlay_kind.is_empty():
			Telemetry.log_event("ui_overlay_shown", {"kind": overlay_kind})
			_overlay_shown_at = Time.get_ticks_msec()
		_overlay_kind = overlay_kind


func _log_overlay_dismiss(kind: String) -> void:
	if kind.is_empty() or _overlay_shown_at <= 0:
		return
	var ms: int = Time.get_ticks_msec() - _overlay_shown_at
	Telemetry.log_event("ui_overlay_dismiss_ms", {"kind": kind, "ms": ms})
	_overlay_shown_at = 0


func _offline_body_text(daily_only: bool) -> String:
	if daily_only:
		return (
			"★ Daily reward\n\nDay %d streak\n+%s added to your balance"
			% [GameState.daily_streak, FormatUtil.format_money(GameState.daily_reward)]
		)
	var hours: int = int(GameState.offline_secs_away / 3600.0)
	var mins: int = int(int(GameState.offline_secs_away) % 3600 / 60.0)
	var away: String = "Away for %dh %dm" % [hours, mins] if hours > 0 else "Away for %dm" % mins
	var cap_note: String = "\nCap reached — check in sooner for more" if GameState.offline_capped else ""
	var rival_news: String = ""
	if not GameState.offline_rival_events.is_empty():
		rival_news = "\n\nWhile you were away:\n• " + "\n• ".join(GameState.offline_rival_events)
	return (
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


func _rebuild_event_choices() -> void:
	for c in _event_choices.get_children():
		c.queue_free()
	var choices: Array = GameState.pending_event.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%s\n%s" % [ch.get("label", "?"), ch.get("desc", "")]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		GameTheme.apply_overlay_cta(btn, true)
		var idx: int = i
		btn.pressed.connect(func(): _pick_event_choice(idx))
		_event_choices.add_child(btn)


func _pick_event_choice(idx: int) -> void:
	_log_overlay_dismiss("event")
	_EventSystem.resolve_event(GameState, idx)
	GameState.stats_changed.emit()
	_refresh_overlays()


func _dismiss_milestone() -> void:
	_log_overlay_dismiss("milestone")
	_TutorialSystem.dismiss_milestone(GameState)


func _dismiss_offline() -> void:
	var kind := "offline" if GameState.show_offline_overlay else "daily"
	_log_overlay_dismiss(kind)
	GameState.dismiss_offline_overlay()
	_refresh_overlays()


func _on_offline_watch_ad() -> void:
	Monetization.show_rewarded(Monetization.PLACEMENT_OFFLINE_DOUBLE)


func _on_coin_watch_ad() -> void:
	Monetization.show_rewarded(Monetization.PLACEMENT_FREE_COIN)


func _dismiss_elim() -> void:
	_log_overlay_dismiss("elim")
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
		if frac >= 1.0 and not GameTheme.ui_reduced_motion():
			var pulse: float = 0.6 + 0.4 * sin(_ui_time * 3.0)
			_shield_label.modulate = Color(1.0, 1.0, 1.0, pulse)
			_heat_bar.modulate = Color(0.85, 0.95, 1.0, pulse)
		else:
			_shield_label.modulate = Color.WHITE
			_heat_bar.modulate = Color.WHITE
	else:
		_shield_label.visible = false
		_heat_bar.modulate = Color.WHITE
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
	_ips.text = "+%s/s" % FormatUtil.format_money(GameState.income_per_second())
	var rank_full := "%s · %d Inf" % [GameState.rank_label(), GameState.prestige_tokens]
	_rank.text = GameTheme.truncate(rank_full, 18)
	_buy_mult_chip.text = GameState.buy_mult_label()
	var hint := GameState.next_purchase_hint()
	if hint.is_empty():
		_advice_chip.visible = false
	else:
		_advice_chip.visible = true
		_advice_chip.text = GameTheme.truncate("▸ %s" % hint, 16)
	_heat_bar.value = GameState.heat
	var heat_col := GameTheme.GREEN if GameState.heat < 60.0 else GameTheme.RED
	if GameTheme.is_city_v2_active():
		var fill := _heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			fill.bg_color = heat_col
	var heat_txt := "Heat %.0f%%" % GameState.heat
	if _ManagerSystem.manager_active(GameState, "The Promoter"):
		heat_txt += "  ·  autopilot ≤%.0f%%" % _ManagerSystem.promoter_heat_target(GameState)
	_heat_label.text = heat_txt
	_heat_label.add_theme_color_override("font_color", heat_col)
	_click_info.text = "Click: %s" % FormatUtil.format_money(GameState.click_value())
	if not GameTheme.is_city_v2_active():
		_click_info.visible = true
	_prestige_btn.disabled = not GameState.can_prestige()
	if GameTheme.is_city_v2_active():
		var pcol := GameTheme.GOLD_BRIGHT if GameState.can_prestige() else GameTheme.TEXT_MUTED
		_prestige_btn.add_theme_color_override("font_color", pcol)
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
	var compact := GameTheme.is_city_v2_active()
	if patron.is_empty():
		_dragon_hud.visible = false
		if _dragon_chip:
			_dragon_chip.visible = false
		return
	if compact:
		_dragon_hud.visible = false
		if _dragon_chip:
			_dragon_chip.visible = true
			var meta: Dictionary = _DragonSystem.DRAGON_META[patron]
			var mood: String = _DragonSystem.get_mood(GameState)
			_dragon_chip.text = GameTheme.truncate("%s · %s" % [
				str(meta.get("title", patron)), _DragonSystem.MOOD_LABELS.get(mood, mood),
			], 22)
			_dragon_chip.add_theme_color_override("font_color", meta.get("color", GameTheme.GOLD))
		return
	if _dragon_chip:
		_dragon_chip.visible = false
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
	_add_list_section_header(_upgrs_list, "EMPIRE UPGRADES")
	for i in GameState.upgrades.size():
		if GameState.upgrades[i].purchased:
			continue
		var row: Control = UPGRADE_ROW.instantiate()
		_upgrs_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_upgrade)


func _on_hustle() -> void:
	Telemetry.log_event("ui_hustle_tap", {
		"source": "band" if GameTheme.is_city_v2_active() else "fallback",
		"tutorial_step": GameState.tutorial_step,
	})
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
	var origin: Vector2
	if GameTheme.is_city_v2_active() and _hustle_band != null:
		origin = _hustle_band.call("get_hustle_center_global")
	else:
		origin = get_viewport().get_visible_rect().get_center()
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
	if not GameState.buy_building(index, qty):
		return
	var ms := GameState.record_first_building_buy_ms()
	if ms >= 0:
		Telemetry.log_event("ui_first_building_buy_ms", {"ms": ms})
	if GameState.tutorial_step == 1 and GameState.total_buildings_owned() > before:
		_TutorialSystem.advance_tutorial(GameState)


func _on_buy_mult_chip() -> void:
	GameState.cycle_buy_mult()
	_buy_mult_chip.text = GameState.buy_mult_label()
	Telemetry.log_event("ui_buy_mult_changed", {"mode": GameState.buy_mult_label()})


func _on_advice_chip() -> void:
	var hint := GameState.next_purchase_hint()
	if hint.is_empty():
		return
	for i in GameState.upgrades.size():
		if GameState.can_buy_upgrade(i) and GameState.upgrades[i].display_name == hint:
			_open_tab(Tab.UPGRS)
			return
	_open_tab(Tab.BLDGS)


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
	Telemetry.log_event("ui_prestige_tree_open", {"eligible": GameState.can_prestige()})
	_prestige_tree.open()


func _exit_tree() -> void:
	GameState.set_simulation_active(false)


func _on_menu() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_notification(message: String, color: Color) -> void:
	_notif.text = message
	_notif.add_theme_color_override("font_color", color)
	if _notif_shell:
		_notif_shell.visible = true
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


func _clear_notif() -> void:
	_notif.text = ""
	_notif.add_theme_font_size_override("font_size", _notif_default_font_size)
	if _notif_shell:
		_notif_shell.visible = false


func _is_goal_notification(message: String, color: Color) -> bool:
	if color != GameTheme.GOLD_BRIGHT or not message.contains("\n"):
		return false
	var parts: PackedStringArray = message.split("\n", false, 1)
	return parts.size() == 2 and parts[1].begins_with("+")


func _refresh_tab_badges() -> void:
	var aff_bldgs := GameState.count_affordable_buildings()
	var aff_upgrs := GameState.count_affordable_upgrades()
	var hire_mgrs := GameState.count_hireable_managers()
	_tab_badge_snapshot = {
		"bldgs": aff_bldgs,
		"upgrs": aff_upgrs,
		"mgrs": hire_mgrs,
	}
	for key in ["bldgs", "upgrs", "mgrs"]:
		var count: int = int(_tab_badge_snapshot.get(key, 0))
		if count <= 0:
			continue
		var prev: int = int(_tab_badge_impressions.get(key, -1))
		if prev != count:
			_tab_badge_impressions[key] = count
			Telemetry.log_event("ui_badge_impression", {"tab": key, "count": count})
	_tab_bldgs.text = GameTheme.tab_label_with_badge("Bldgs", aff_bldgs)
	_tab_upgrs.text = GameTheme.tab_label_with_badge("Upgrs", aff_upgrs)
	_tab_mgrs.text = GameTheme.tab_label_with_badge("Mgrs", hire_mgrs)
	_tab_stats.text = "Stats"
	# Turf subtab badges (Crew/Ops lock progress).
	_sub_territory.text = "Territory"
	_sub_rivals.text = "Rivals"
	if _CrewSystem.is_unlocked(GameState):
		_sub_crew.text = "Crew"
	else:
		var bld: int = GameState.total_buildings_owned()
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
	_add_cycle_row("Text scale", ["100%", "125%"], GameState.ui_text_scale, func(i):
		GameState.ui_text_scale = i
		_apply_header_theme()
		_apply_overlay_theme()
		if _tab == Tab.STATS:
			_refresh_stats_tab()
		elif _tab == Tab.CONFIG:
			_build_config_tab()
		SaveManager.save_game()
	)
	_add_cycle_row("FPS Cap", ["30", "60", "120"], [30, 60, 120].find(GameState.fps_cap), func(i): _set_fps_cap(i))
	_add_cycle_row("Particles / motion", ["ON", "OFF"], 0 if GameState.show_particles else 1, func(i):
		GameState.show_particles = i == 0
		SaveManager.save_game()
	)
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
		_apply_config_action_button(cloud_btn)
		cloud_btn.pressed.connect(func(): CloudSave.sign_in())
		_config_body.add_child(cloud_btn)
	_add_config_header("STORE")
	_add_iap_row("Remove ads", Monetization.PRODUCT_REMOVE_ADS, "Hides ads permanently")
	_add_iap_row("Starter pack", Monetization.PRODUCT_STARTER, "Cash + Influence boost")
	_add_iap_row("2× income (permanent)", Monetization.PRODUCT_INCOME_X2, "Doubles passive income")
	var restore := Button.new()
	restore.text = "Restore purchases"
	_apply_config_action_button(restore)
	restore.pressed.connect(func(): Monetization.restore())
	_config_body.add_child(restore)
	_add_config_header("DATA")
	var menu := Button.new()
	menu.text = "Save & Main Menu"
	_apply_config_action_button(menu)
	menu.pressed.connect(_on_menu)
	_config_body.add_child(menu)
	var reset_tut := Button.new()
	reset_tut.text = "Reset Tutorial"
	_apply_config_action_button(reset_tut)
	reset_tut.pressed.connect(func(): GameState.reset_tutorial(); _build_config_tab())
	_config_body.add_child(reset_tut)
	var del := Button.new()
	del.text = "Delete Save"
	_apply_config_action_button(del)
	del.pressed.connect(func(): SaveManager.delete_save(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	_config_body.add_child(del)
	var note := Label.new()
	note.text = "Auto-save every %ds" % int(GameConfig.AUTOSAVE_INTERVAL)
	note.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_config_body.add_child(note)


func _apply_config_action_button(btn: Button) -> void:
	if btn == null:
		return
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if GameTheme.is_city_v2_active():
		GameTheme.apply_ink_chip_button(btn, false, 14, GameTheme.TEXT)
	else:
		GameTheme.apply_menu_button(btn, false)


func _add_list_section_header(parent: Control, title: String) -> void:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameTheme.is_rustic_active() or GameTheme.is_city_v2_active():
		strip.add_theme_stylebox_override("panel", GameTheme.list_section_header_style())
	var lbl := Label.new()
	lbl.text = title
	GameTheme.apply_list_section_title(lbl)
	strip.add_child(lbl)
	parent.add_child(strip)


func _add_config_header(text: String) -> void:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_stylebox_override("panel", GameTheme.config_section_header_style())
	var lbl := Label.new()
	lbl.text = text
	GameTheme.apply_list_section_title(lbl)
	strip.add_child(lbl)
	_config_body.add_child(strip)


func _add_cycle_row(label: String, options: Array, index: int, cb: Callable) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameTheme.config_row_style())
	var row := HBoxContainer.new()
	panel.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	if GameTheme.is_city_v2_active():
		lbl.add_theme_color_override("font_color", GameTheme.TEXT)
	row.add_child(lbl)
	var btn := Button.new()
	var holder: Dictionary = {"i": clampi(index, 0, options.size() - 1)}
	btn.text = str(options[holder.i])
	btn.custom_minimum_size.x = 88.0
	if GameTheme.is_city_v2_active():
		GameTheme.apply_ink_chip_button(btn, false)
	else:
		GameTheme.apply_menu_button(btn, false)
	btn.pressed.connect(func():
		holder.i = (int(holder.i) + 1) % options.size()
		btn.text = str(options[holder.i])
		cb.call(holder.i)
	)
	row.add_child(btn)
	_config_body.add_child(panel)


func _add_iap_row(label: String, product_id: String, hint: String) -> void:
	if Monetization.product_owned(product_id):
		var owned := Label.new()
		owned.text = "%s — owned" % label
		owned.add_theme_color_override("font_color", GameTheme.GREEN)
		owned.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
		_config_body.add_child(owned)
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameTheme.row_card_style(GameTheme.RowAffordance.BUYABLE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vbox)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	vbox.add_child(lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	hint_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	vbox.add_child(hint_lbl)
	var btn := Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size.x = 96.0
	GameTheme.apply_overlay_cta(btn, true)
	btn.pressed.connect(func(): Monetization.purchase(product_id))
	row.add_child(btn)
	_config_body.add_child(panel)


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
