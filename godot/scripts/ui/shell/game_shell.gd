extends CanvasLayer
## GameShell — thin coordinator for the Stage & Ledger UI (UI_OVERHAUL §4–5).
## Owns routing, screen lifecycle, and the safe area. Theming lives in
## components; list population lives in screens; city logic in StageLayer.

const StageLayerScript = preload("res://scripts/ui/shell/stage_layer.gd")
const MastheadScript = preload("res://scripts/ui/shell/hud_masthead.gd")
const RailScript = preload("res://scripts/ui/shell/attention_rail.gd")
const DeckScript = preload("res://scripts/ui/shell/content_deck.gd")
const DockScript = preload("res://scripts/ui/shell/nav_dock.gd")
const DirectorScript = preload("res://scripts/ui/shell/attention_director.gd")
const OverlayHostScript = preload("res://scripts/ui/shell/overlay_host.gd")
const FxLayerScript = preload("res://scripts/ui/shell/fx_layer.gd")
const BossSheetScript = preload("res://scripts/ui/shell/boss_sheet.gd")
const PrestigeClimaxScript = preload("res://scripts/ui/shell/prestige_climax.gd")
const FilmGrain = preload("res://scripts/ui/film_grain_overlay.gd")
const MusicDefs = preload("res://scripts/audio/music_defs.gd")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")

const BuildingsScreen = preload("res://scripts/ui/screens/buildings_screen.gd")
const UpgradesScreen = preload("res://scripts/ui/screens/upgrades_screen.gd")
const ManagersScreen = preload("res://scripts/ui/screens/managers_screen.gd")
const TurfScreen = preload("res://scripts/ui/screens/turf_screen.gd")
const StatsScreen = preload("res://scripts/ui/screens/stats_screen.gd")
const ConfigScreen = preload("res://scripts/ui/screens/config_screen.gd")

const PRESTIGE_TREE := preload("res://scenes/prestige_tree_overlay.tscn")
const DRAGON_OVERLAY := preload("res://scenes/dragon_patron_overlay.tscn")
const GAMBLING_OVERLAY := preload("res://scenes/gambling_overlay.tscn")

const _STATS_UI_INTERVAL := 0.1
const _STAGE_REFRESH_INTERVAL := 0.1
const _MUSIC_CTX_INTERVAL := 1.0
const _BASE_MARGIN := 0

var _stage: Control
var _root_margin: MarginContainer
var _masthead: Control
var _rail: Control
var _gap: Control
var _deck: PanelContainer
var _dock: PanelContainer
var _director: Node
var _overlays: CanvasLayer
var _prestige_tree: CanvasLayer
var _dragon_patron: CanvasLayer
var _gambling: CanvasLayer
var _boss_sheet: Control
var _climax: CanvasLayer
var _notif_shell: PanelContainer
var _notif: Label
var _tutorial_shell: PanelContainer
var _tutorial_banner: Label
var _fps_debug: Label
var _fps_log_timer: float = 0.0
## Stamped at the top of _process so the fps line can report what this node's
## own frame work actually cost, rather than an engine monitor of unclear units.
var _process_started_us: int = 0

const _BACK_EXIT_WINDOW := 2.0
var _back_exit_armed_until: float = 0.0

var _tab := "bldgs"
var _stats_dirty := true
var _stats_ui_timer := 0.0
var _stage_refresh_timer := 0.0
var _music_ctx_timer := 0.0
var _notif_timer := 0.0
var _notif_default_font_size := 0
var _last_gap_rect := Rect2()


func _ready() -> void:
	GameState.set_simulation_active(true)
	GameState.mark_ui_session_start()
	Disclosure.session_started_msec = Time.get_ticks_msec()
	if AudioManager.is_enabled():
		AudioManager.set_music_mode(MusicDefs.MusicMode.PLAYING_AMBIENT)

	_build_stage_and_chrome()
	_build_transient_surfaces()
	_build_modal_overlays()
	_wire_events()

	# The project setting alone does not hold on Android: the notification fires
	# and GodotActivity force-quits anyway (verified on device 2026-07-30 —
	# "[back] go-back request received" immediately followed by "Force quitting
	# Godot instance"). Setting it on the live SceneTree is what actually sticks.
	get_tree().quit_on_go_back = false
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	GameTheme.apply_device_font_boost.call_deferred(self)
	_show_tab("bldgs")
	_refresh_all()
	Telemetry.log_event("ui_session_start", {"tab": _tab, "shell": "v3"})


func _build_stage_and_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_stage = StageLayerScript.new()
	_stage.name = "StageLayer"
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var grain: TextureRect = FilmGrain.new()
	add_child(grain)
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_root_margin = MarginContainer.new()
	add_child(_root_margin)
	_root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_root_margin.add_child(col)

	_masthead = MastheadScript.new()
	_masthead.name = "Masthead"
	col.add_child(_masthead)

	_rail = RailScript.new()
	_rail.name = "AttentionRail"
	col.add_child(_rail)

	# Stage gap — transparent spacer; forwards taps to the stage (Z2 tap target).
	_gap = Control.new()
	_gap.name = "StageGap"
	_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gap.mouse_filter = Control.MOUSE_FILTER_STOP
	_gap.gui_input.connect(_on_gap_input)
	col.add_child(_gap)

	_deck = DeckScript.new()
	_deck.name = "ContentDeck"
	col.add_child(_deck)

	_dock = DockScript.new()
	_dock.name = "NavDock"
	col.add_child(_dock)

	_director = DirectorScript.new()
	_director.name = "AttentionDirector"
	add_child(_director)
	_director.call("set_stage", _stage)

	# Transient deco garnish (coin arcs, sparks, ripples). Sits above the
	# chrome column so coins can travel deck -> masthead, and BEFORE the
	# notification/tutorial/overlay children so garnish never draws over a
	# modal scrim (spec: below OverlayHost).
	add_child(FxLayerScript.new())

	var bldgs: Control = BuildingsScreen.new()
	bldgs.set("stage", _stage)
	var stats: Control = StatsScreen.new()
	stats.set("director", _director)
	var screens := {
		"bldgs": bldgs,
		"upgrs": UpgradesScreen.new(),
		"mgrs": ManagersScreen.new(),
		"turf": TurfScreen.new(),
		"stats": stats,
		"config": ConfigScreen.new(),
	}
	for id in screens:
		_deck.call("register_screen", id, screens[id])


func _build_transient_surfaces() -> void:
	_notif_shell = PanelContainer.new()
	_notif_shell.visible = false
	_notif_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
	add_child(_notif_shell)
	_notif_shell.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notif_shell.offset_top = -150.0
	_notif_shell.offset_bottom = -118.0
	_notif_shell.offset_left = -240.0
	_notif_shell.offset_right = 240.0
	_notif_shell.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notif_shell.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notif = Label.new()
	_notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notif.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_notif_shell.add_child(_notif)
	_notif_default_font_size = GameTheme.scaled_font(12)

	_tutorial_shell = PanelContainer.new()
	_tutorial_shell.visible = false
	_tutorial_shell.add_theme_stylebox_override("panel", GameTheme.ink_tutorial_banner_style())
	_tutorial_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_shell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tutorial_shell.gui_input.connect(_on_tutorial_banner_input)
	add_child(_tutorial_shell)
	_tutorial_shell.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial_shell.offset_top = -240.0
	_tutorial_shell.offset_bottom = -160.0
	_tutorial_shell.offset_left = -250.0
	_tutorial_shell.offset_right = 250.0
	_tutorial_shell.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorial_shell.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tutorial_banner = Label.new()
	_tutorial_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_banner.add_theme_color_override("font_color", GameTheme.TEXT)
	_tutorial_banner.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_tutorial_shell.add_child(_tutorial_banner)

	_fps_debug = Label.new()
	_fps_debug.visible = false
	_fps_debug.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_fps_debug.add_theme_color_override("font_color", GameTheme.GREEN)
	add_child(_fps_debug)
	_fps_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_debug.offset_left = -88.0
	_fps_debug.offset_top = 2.0
	_fps_debug.offset_right = -4.0
	_fps_debug.offset_bottom = 18.0


func _build_modal_overlays() -> void:
	_prestige_tree = PRESTIGE_TREE.instantiate()
	add_child(_prestige_tree)
	_dragon_patron = DRAGON_OVERLAY.instantiate()
	add_child(_dragon_patron)
	_gambling = GAMBLING_OVERLAY.instantiate()
	add_child(_gambling)
	_overlays = OverlayHostScript.new()
	add_child(_overlays)
	# Thumb-zone up-sheet (ADR-002) — above chrome, below modal ceremonies.
	_boss_sheet = BossSheetScript.new()
	add_child(_boss_sheet)
	_boss_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_sheet.call("set_dock", _dock)
	# Prestige ceremony (§4.7) — own CanvasLayer above all other overlays.
	_climax = PrestigeClimaxScript.new()
	add_child(_climax)


func _wire_events() -> void:
	GameState.stats_changed.connect(func(): _stats_dirty = true)
	GameState.notification.connect(_on_notification)
	GameState.prestiged.connect(_on_prestiged)
	UiEvents.tab_requested.connect(_show_tab)
	UiEvents.overlay_requested.connect(_on_overlay_requested)


func _on_prestiged(info: Dictionary) -> void:
	_climax.call("start", int(info.get("gain", 0)), str(info.get("rank", "")))


# -------------------------------------------------------------------- routing

func _show_tab(tab_id: String) -> void:
	_tab = tab_id
	_deck.call("show_screen", tab_id)
	_dock.call("set_active", tab_id)
	match tab_id:
		"upgrs":
			if GameState.tutorial_step == 2:
				_TutorialSystem.advance_tutorial(GameState)
		"mgrs":
			if GameState.tutorial_step == 3:
				_TutorialSystem.advance_tutorial(GameState)
	Telemetry.log_event("ui_tab_open", {"tab": tab_id})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_requested()


## Android Back unwinds the UI one layer at a time and only leaves from the top.
## Godot's default is to quit the process outright (quit_on_go_back), which on
## device meant Back-to-close-the-Luck-Wheel killed a live run — the kind of
## thing store reviewers fail a build for. Order mirrors what is on top of what.
func _on_back_requested() -> void:
	# A ceremony owns the screen and is already dismissed by tapping it; Back
	# during the run-ending beat should do nothing rather than skip it blind.
	if _climax != null and bool(_climax.call("is_active")):
		return
	for overlay in [_gambling, _dragon_patron, _prestige_tree]:
		if overlay != null and overlay.visible:
			overlay.call("close")
			return
	if _boss_sheet != null and _boss_sheet.visible:
		_boss_sheet.call("close")
		return
	# Milestone/offline/event overlays are tap-to-continue and drive game state;
	# let them finish rather than dismissing them from under the player.
	if bool(_overlays.get("blocking")):
		return
	if _tab != "bldgs":
		_show_tab("bldgs")
		return
	# Top level: the Android convention is press-again-to-exit, not an instant
	# kill. Save first — an idle game losing a session to a stray tap is worse
	# than the tap itself.
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now < _back_exit_armed_until:
		SaveManager.save_game()
		get_tree().quit()
		return
	_back_exit_armed_until = now + _BACK_EXIT_WINDOW
	GameState.notification.emit("Press back again to exit", GameTheme.TEXT)


func _on_overlay_requested(kind: String) -> void:
	match kind:
		"boss":
			_boss_sheet.call("open")
		"config":
			_deck.call("show_screen", "config")
			_dock.call("set_active", "")
			Telemetry.log_event("ui_config_open", {})
		"prestige":
			if GameState.tutorial_step == 4:
				_TutorialSystem.advance_tutorial(GameState)
			Telemetry.log_event("ui_prestige_tree_open", {"eligible": GameState.can_prestige()})
			_prestige_tree.call("open")
		"dragon":
			_dragon_patron.call("open")
		"gambling":
			Telemetry.log_event("ui_luck_wheel_open", {"spins": GameState.gambling_free_spins()})
			_gambling.call("open")


func _on_gap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# The diegetic coin lives in the stage; depending on z-order it may
			# be under this catcher, so give it the tap first (the coin also
			# handles its own gui_input for when it ends up on top).
			if bool(_stage.call("try_tap_coin", mb.global_position)):
				return
			_stage.call("handle_tap", mb.global_position)


# --------------------------------------------------------------------- loop

func _process(delta: float) -> void:
	_process_started_us = Time.get_ticks_usec()
	_stats_ui_timer -= delta
	if _stats_dirty and _stats_ui_timer <= 0.0:
		_stats_ui_timer = _STATS_UI_INTERVAL
		_stats_dirty = false
		_refresh_all()
	if _notif_timer > 0.0:
		_notif_timer -= delta
		if _notif_timer <= 0.0:
			_clear_notif()
	_overlays.call("refresh", delta)
	var blocking: bool = _overlays.get("blocking")
	# City ranking + district slots were rebuilt every frame (income_per_second
	# per building). Ambient skyline motion lives in CityView._process; this only
	# needs to push empire state at chrome rate. Purchase/heat flashes still go
	# through UiEvents immediately.
	_stage_refresh_timer -= delta
	if _stage_refresh_timer <= 0.0:
		_stage_refresh_timer = _STAGE_REFRESH_INTERVAL
		_stage.call("refresh", blocking)
	else:
		_stage.call("set_overlay_blocking", blocking)
	_refresh_tutorial(blocking)
	_sync_gap_rect()
	_music_ctx_timer -= delta
	if _music_ctx_timer <= 0.0:
		_music_ctx_timer = _MUSIC_CTX_INTERVAL
		if AudioManager.is_enabled():
			AudioManager.update_music_context({"heat": GameState.heat, "tab": _tab})
	_refresh_fps_debug()


func _refresh_all() -> void:
	_masthead.call("refresh")
	var screen: Control = _deck.call("current_screen")
	if screen != null and screen.has_method("refresh_slow"):
		screen.call("refresh_slow")
	if not GameState.event_outcome.is_empty():
		_notif.text = GameState.event_outcome
		_notif.add_theme_color_override("font_color", GameTheme.GOLD)
		_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
		_notif_shell.visible = true
		_position_notif()


func _sync_gap_rect() -> void:
	var r := _gap.get_global_rect()
	if r != _last_gap_rect:
		_last_gap_rect = r
		_stage.call("set_gap_rect", r)
		_position_tutorial()
		if _notif_shell.visible:
			_position_notif()


func _refresh_tutorial(blocking: bool) -> void:
	if not _TutorialSystem.is_complete(GameState) and not blocking:
		_tutorial_shell.visible = true
		_tutorial_banner.text = _TutorialSystem.current_text(GameState) + "\n(tap to continue)"
		_position_tutorial()
		if _notif_shell.visible:
			_position_notif()
	else:
		_tutorial_shell.visible = false
		if _notif_shell.visible:
			_position_notif()


func _position_tutorial() -> void:
	# Float the hint just above the content sheet (in the city stage) so it never
	# covers — or blocks taps on — the building rows. The stage gap's bottom edge
	# tracks the sheet's top at any resolution / dock state (see _sync_gap_rect).
	var gap := _last_gap_rect
	if gap.size.y <= 0.0:
		return  # gap not measured yet — keep the scene's default placement
	var vh := float(get_viewport().get_visible_rect().size.y)
	var below := vh - gap.end.y  # sheet-top → screen-bottom, in the CENTER_BOTTOM frame
	_tutorial_shell.offset_bottom = -(below + 12.0)
	_tutorial_shell.offset_top = _tutorial_shell.offset_bottom - 80.0


func _position_notif() -> void:
	# Same stage-gap home as the tutorial — never cover list rows or the dock.
	var gap := _last_gap_rect
	if gap.size.y <= 0.0:
		return
	var vh := float(get_viewport().get_visible_rect().size.y)
	var below := vh - gap.end.y
	var lift := 12.0
	if _tutorial_shell.visible:
		lift += 88.0
	var h := maxf(36.0, _notif_shell.get_combined_minimum_size().y)
	_notif_shell.offset_bottom = -(below + lift)
	_notif_shell.offset_top = _notif_shell.offset_bottom - h


func _on_tutorial_banner_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _TutorialSystem.is_complete(GameState):
		return
	if bool(_overlays.get("blocking")):
		return
	_TutorialSystem.advance_tutorial(GameState)


func _on_notification(message: String, color: Color) -> void:
	_notif.text = message
	_notif.add_theme_color_override("font_color", color)
	_notif_shell.visible = true
	var is_goal: bool = _is_goal_notification(message, color)
	var is_autobuy: bool = AudioManager.is_autobuy_message(message)
	var is_achievement := message.begins_with("Achievement:")
	if is_goal or is_autobuy:
		_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
		_notif.add_theme_font_size_override("font_size", maxi(_notif_default_font_size + 2, 15))
		_notif_timer = 4.0
		if is_autobuy:
			_notif.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
		if is_goal and _director != null:
			_director.call("announce_goal_complete", message.split("\n")[0])
	elif is_achievement:
		_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_achievement_toast_style())
		_notif.add_theme_font_size_override("font_size", maxi(_notif_default_font_size + 2, 14))
		_notif.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
		_notif_timer = 3.5
	else:
		_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
		_notif.add_theme_font_size_override("font_size", _notif_default_font_size)
		_notif_timer = 2.5
	_position_notif()
	var cue := AudioManager.cue_for_notification(message, color)
	if not cue.is_empty() and cue != "rankup":
		AudioManager.play(cue)


func _clear_notif() -> void:
	_notif.text = ""
	_notif.add_theme_font_size_override("font_size", _notif_default_font_size)
	_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
	_notif_shell.visible = false


func _is_goal_notification(message: String, color: Color) -> bool:
	if color != GameTheme.GOLD_BRIGHT or not message.contains("\n"):
		return false
	var parts: PackedStringArray = message.split("\n", false, 1)
	return parts.size() == 2 and parts[1].begins_with("+")


func _refresh_fps_debug() -> void:
	var fps: float = Engine.get_frames_per_second()
	# Always emit to stdout once a second so a device pass can read hardware
	# numbers off `adb logcat`. Overlay text stays gated by the Config toggle.
	#
	# This used to print Performance.TIME_PROCESS * 1000 as "process_ms", which
	# read ~68 no matter whether the device was doing 26fps or 45 — a per-frame
	# script cost cannot stay flat while frame time nearly doubles, so the number
	# was worse than useless for diagnosing the city's draw cost. Two directly
	# defined numbers instead: frame_ms is the wall clock budget (1000/fps), and
	# shell_ms is what this node's own _process actually consumed, measured. If
	# shell_ms is a small fraction of frame_ms, the cost is in the renderer.
	_fps_log_timer -= get_process_delta_time()
	if _fps_log_timer <= 0.0:
		_fps_log_timer = 1.0
		print("[fps] %.1f  frame_ms=%.1f shell_ms=%.2f draw_calls=%d" % [
			fps,
			1000.0 / maxf(fps, 1.0),
			float(Time.get_ticks_usec() - _process_started_us) / 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		])
	if not GameState.show_debug_fps:
		_fps_debug.visible = false
		return
	_fps_debug.visible = true
	_fps_debug.add_theme_color_override(
		"font_color", GameTheme.GREEN if fps >= 30.0 else GameTheme.RED)
	_fps_debug.text = "%.0f FPS" % fps


## Inset the chrome by the device safe area (notch / home bar). Stage stays
## full-bleed underneath — only interactive chrome respects the inset.
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var vp := get_viewport().get_visible_rect().size
	var sx := vp.x / float(screen.x)
	var sy := vp.y / float(screen.y)
	_root_margin.add_theme_constant_override("margin_left",
		_BASE_MARGIN + int(maxf(0.0, float(safe.position.x)) * sx))
	_root_margin.add_theme_constant_override("margin_top",
		_BASE_MARGIN + int(maxf(0.0, float(safe.position.y)) * sy))
	_root_margin.add_theme_constant_override("margin_right",
		_BASE_MARGIN + int(maxf(0.0, float(screen.x - (safe.position.x + safe.size.x))) * sx))
	_root_margin.add_theme_constant_override("margin_bottom",
		_BASE_MARGIN + int(maxf(0.0, float(screen.y - (safe.position.y + safe.size.y))) * sy))


func _exit_tree() -> void:
	GameState.set_simulation_active(false)
