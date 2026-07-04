extends CanvasLayer
## OverlayHost — Z6 modal ceremonies for the Stage & Ledger shell. Ports the
## proven single-flight overlay queue (offline → daily → elim → milestone →
## event, never parallel) unchanged from game_screen.gd (Phase 92 pattern).

const _EventSystem = preload("res://scripts/systems/event_system.gd")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")
const OVERLAY_DIM := preload("res://scripts/ui/overlay_dim.gd")
const OVERLAY_FRAME := preload("res://scripts/ui/overlay_frame.gd")
const CEREMONY := preload("res://scripts/ui/shell/welcome_ceremony.gd")

var _dim: ColorRect
var _milestone_panel: PanelContainer
var _milestone_title: Label
var _milestone_body: Label
var _milestone_dismiss: Button
var _event_panel: PanelContainer
var _event_title: Label
var _event_desc: Label
var _event_choices: VBoxContainer
var _offline_panel: PanelContainer
var _offline_title: Label
var _offline_body: Label
var _offline_continue: Button
var _offline_watch_ad: Button
var _offline_spin_btn: Button
var _elim_panel: PanelContainer
var _elim_name: Label
var _elim_flavor: Label
var _elim_rewards: Label
var _elim_dismiss: Button

var _ceremony: Control
var _active_kind := ""
var _telemetry_kind := ""
var _shown_at := 0
var _last_event_key := ""
var _ui_time := 0.0

signal blocking_changed(blocking: bool)

var blocking := false


func _ready() -> void:
	layer = 10
	_dim = ColorRect.new()
	_dim.set_script(OVERLAY_DIM)
	_dim.color = Color(0, 0, 0, 0.65)
	_dim.visible = false
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)

	_build_milestone()
	_build_event()
	_build_offline()
	_build_elim()

	# Offline returns run the full ceremony (§4.6, D4); the text panel remains
	# for the daily-reward variant only.
	_ceremony = CEREMONY.new()
	add_child(_ceremony)
	_ceremony.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _panel(width: float, height: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_script(OVERLAY_FRAME)
	p.visible = false
	add_child(p)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -width * 0.5
	p.offset_top = -height * 0.5
	p.offset_right = width * 0.5
	p.offset_bottom = height * 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p


func _title_label(size_px: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameFonts.heading())
	l.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	l.add_theme_font_size_override("font_size", GameTheme.scaled_font(size_px))
	return l


func _body_label(size_px: int, col: Color = GameTheme.TEXT) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", GameTheme.scaled_font(size_px))
	GameTheme.apply_flavor_label(l)
	return l


func _build_milestone() -> void:
	_milestone_panel = _panel(440, 200)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_milestone_panel.add_child(v)
	_milestone_title = _title_label(18)
	v.add_child(_milestone_title)
	_milestone_body = _body_label(14)
	v.add_child(_milestone_body)
	_milestone_dismiss = Button.new()
	_milestone_dismiss.text = "Tap to continue"
	GameTheme.apply_overlay_cta(_milestone_dismiss, true)
	_milestone_dismiss.pressed.connect(_dismiss_milestone)
	v.add_child(_milestone_dismiss)


func _build_event() -> void:
	_event_panel = _panel(480, 320)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_event_panel.add_child(v)
	_event_title = _title_label(17)
	_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(_event_title)
	_event_desc = _body_label(14)
	v.add_child(_event_desc)
	_event_choices = VBoxContainer.new()
	_event_choices.add_theme_constant_override("separation", 6)
	v.add_child(_event_choices)


func _build_offline() -> void:
	_offline_panel = _panel(520, 360)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_offline_panel.add_child(v)
	_offline_title = _title_label(20)
	_offline_title.text = "WELCOME BACK, BOSS"
	v.add_child(_offline_title)
	_offline_body = _body_label(14)
	v.add_child(_offline_body)
	_offline_continue = Button.new()
	_offline_continue.text = "Tap to continue"
	_offline_continue.mouse_filter = Control.MOUSE_FILTER_STOP
	GameTheme.apply_overlay_cta(_offline_continue, true)
	_offline_continue.pressed.connect(_dismiss_offline)
	v.add_child(_offline_continue)
	_offline_watch_ad = Button.new()
	_offline_watch_ad.text = "Watch ad (2× earnings)"
	GameTheme.apply_overlay_cta(_offline_watch_ad, false)
	_offline_watch_ad.pressed.connect(
		func(): Monetization.show_rewarded(Monetization.PLACEMENT_OFFLINE_DOUBLE))
	v.add_child(_offline_watch_ad)
	_offline_spin_btn = Button.new()
	_offline_spin_btn.text = "🎯 Spin now"
	_offline_spin_btn.visible = false
	GameTheme.apply_overlay_cta(_offline_spin_btn, false)
	_offline_spin_btn.pressed.connect(_on_offline_spin)
	v.add_child(_offline_spin_btn)


func _build_elim() -> void:
	_elim_panel = _panel(580, 320)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_elim_panel.add_child(v)
	var t := _title_label(22)
	t.text = "RIVAL ELIMINATED"
	t.add_theme_color_override("font_color", Color(1, 0.31, 0.31))
	v.add_child(t)
	_elim_name = _title_label(18)
	_elim_name.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(_elim_name)
	_elim_flavor = _body_label(13, GameTheme.TEXT_MUTED)
	_elim_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_elim_flavor)
	_elim_rewards = _body_label(14, GameTheme.GREEN)
	_elim_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_elim_rewards)
	_elim_dismiss = Button.new()
	_elim_dismiss.text = "Tap to continue"
	GameTheme.apply_overlay_cta(_elim_dismiss, true)
	_elim_dismiss.pressed.connect(_dismiss_elim)
	v.add_child(_elim_dismiss)


# ------------------------------------------------------------------- refresh

func pick_blocking() -> Dictionary:
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


func refresh(delta: float) -> void:
	_ui_time += delta
	var pick := pick_blocking()
	var now_blocking: bool = pick.get("blocking", false)
	var kind: String = str(pick.get("kind", ""))
	if kind != _active_kind:
		_hide_all()
		_apply_active(kind)
		_active_kind = kind
	elif kind == "daily":
		_offline_watch_ad.visible = false
	elif kind == "elim" and not GameTheme.ui_reduced_motion():
		_elim_dismiss.modulate = Color(1, 1, 1, 0.6 + 0.4 * sin(_ui_time * 3.0))
	if kind != _telemetry_kind:
		if not kind.is_empty():
			Telemetry.log_event("ui_overlay_shown", {"kind": kind})
			_shown_at = Time.get_ticks_msec()
		_telemetry_kind = kind
	_dim.visible = now_blocking
	if now_blocking != blocking:
		blocking = now_blocking
		blocking_changed.emit(blocking)


func _hide_all() -> void:
	_milestone_panel.visible = false
	_event_panel.visible = false
	_offline_panel.visible = false
	_offline_watch_ad.visible = false
	_offline_spin_btn.visible = false
	_elim_panel.visible = false
	_elim_dismiss.modulate = Color.WHITE
	if _ceremony != null:
		_ceremony.call("stop")


func _apply_active(kind: String) -> void:
	match kind:
		"offline":
			_ceremony.call("start")
		"daily":
			_offline_panel.visible = true
			_offline_title.text = "DAILY REWARD"
			_offline_body.text = _offline_body_text(true)
			_offline_continue.text = "Collect reward"
			_offline_watch_ad.visible = false
			_offline_spin_btn.visible = _has_spin_grant()
		"elim":
			_elim_panel.visible = true
			_elim_name.text = GameState.elim_overlay_name
			_elim_flavor.text = GameState.elim_overlay_flavor
			_elim_rewards.text = GameState.elim_overlay_rewards
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
	_log_dismiss("event")
	_EventSystem.resolve_event(GameState, idx)
	GameState.stats_changed.emit()


func _offline_body_text(daily_only: bool) -> String:
	if daily_only:
		return (
			"★ Daily reward\n\nDay %d streak\n+%s added to your balance%s"
			% [
				GameState.daily_streak,
				FormatUtil.format_money(GameState.daily_reward),
				_spin_grant_line(),
			]
		)
	var hours: int = int(GameState.offline_secs_away / 3600.0)
	var mins: int = int(int(GameState.offline_secs_away) % 3600 / 60.0)
	var away: String = "Away for %dh %dm" % [hours, mins] if hours > 0 else "Away for %dm" % mins
	var cap_note: String = "\nCap reached — check in sooner for more" if GameState.offline_capped else ""
	var rival_news: String = ""
	if not GameState.offline_rival_events.is_empty():
		rival_news = "\n\nWhile you were away:\n• " + "\n• ".join(GameState.offline_rival_events)
	return (
		"%s\n\nCash earned: +%s%s\n\nOps ready: %d\nTerritory: %d / %d\nRivals active: %d (%d at war)%s%s"
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
			_spin_grant_line(),
		]
	)


func _has_spin_grant() -> bool:
	return GameConfig.GAMBLING_ENABLED and GameState.gambling_spins_granted > 0


func _spin_grant_line() -> String:
	if not _has_spin_grant():
		return ""
	var n: int = GameState.gambling_spins_granted
	return "\n\n🎯 +%d free Luck Wheel spin%s" % [n, "" if n == 1 else "s"]


func _on_offline_spin() -> void:
	while GameState.show_offline_overlay or GameState.show_daily_overlay:
		GameState.dismiss_offline_overlay()
	Telemetry.log_event("ui_luck_wheel_open", {
		"spins": GameState.gambling_free_spins(), "from": "return",
	})
	UiEvents.overlay_requested.emit("gambling")


func _on_dim_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	match _active_kind:
		"daily":
			_dismiss_offline()
		"milestone":
			_dismiss_milestone()
		"elim":
			_dismiss_elim()


func _log_dismiss(kind: String) -> void:
	if kind.is_empty() or _shown_at <= 0:
		return
	Telemetry.log_event("ui_overlay_dismiss_ms", {
		"kind": kind, "ms": Time.get_ticks_msec() - _shown_at,
	})
	_shown_at = 0


func _dismiss_milestone() -> void:
	_log_dismiss("milestone")
	_TutorialSystem.dismiss_milestone(GameState)


func _dismiss_offline() -> void:
	_log_dismiss("offline" if GameState.show_offline_overlay else "daily")
	GameState.dismiss_offline_overlay()


func _dismiss_elim() -> void:
	_log_dismiss("elim")
	GameState.dismiss_elimination_overlay()
