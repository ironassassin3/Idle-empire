extends Control
## WelcomeCeremony — the retention crown jewel (UI_MARKET_SUPREMACY_SPEC §4.6,
## owner decision D4: FULL). Replaces the offline text-wall with a staged
## moment on the city: lights come up → the night's take counts in → the
## ledger card settles → offers appear (never gating dismiss).
## Tap anywhere: skip to settled; tap again: dismiss. Reduced motion: instant.

const _LIGHTS_TIME := 1.2
const _COUNT_TIME := 1.4

enum Phase { OFF, LIGHTS, COUNT, SETTLED }

var phase: int = Phase.OFF
var _t := 0.0
var _gain := 0.0
var _shown_take := 0.0
var _backdrop: _Backdrop
var _card: PanelContainer
var _title: Label
var _take: Label
var _detail: Label
var _offers: HBoxContainer
var _ad_btn: Button
var _spin_btn: Button
var _continue_btn: Button


## Dark-to-dawn scrim + staggered district glints, drawn over the live stage.
class _Backdrop extends Control:
	var scrim_a := 0.95
	var lights_t := 0.0   # 0..1 across the light-up

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, scrim_a))
		if lights_t <= 0.0:
			return
		# Five district glints sweep on left→right as the city "wakes".
		for i in 5:
			var wake: float = clampf(lights_t * 5.0 - float(i), 0.0, 1.0)
			if wake <= 0.0:
				continue
			var x := size.x * (0.08 + 0.18 * float(i))
			var y := size.y * (0.30 + 0.04 * float(i % 3))
			var a := wake * (1.0 - lights_t * 0.55)
			draw_rect(Rect2(x, y, 34.0, 8.0), Color(GameTheme.GOLD_BRIGHT, a * 0.8))
			draw_rect(Rect2(x - 6.0, y + 12.0, 46.0, 3.0), Color(GameTheme.GOLD, a * 0.35))


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_tap)

	_backdrop = _Backdrop.new()
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_card = PanelContainer.new()
	_card.set_script(load("res://scripts/ui/overlay_frame.gd"))
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.offset_left = -270.0
	_card.offset_right = 270.0
	_card.offset_top = -220.0
	_card.offset_bottom = 220.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_card.add_child(v)

	_title = Label.new()
	_title.text = "WELCOME BACK, BOSS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", GameFonts.heading())
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(20))
	_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	v.add_child(_title)

	_take = Label.new()
	_take.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_take.add_theme_font_override("font", GameFonts.display())
	_take.add_theme_font_size_override("font_size", GameTheme.scaled_font(34))
	_take.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_take.text = "+$0"
	v.add_child(_take)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", GameTheme.TEXT)
	_detail.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	GameTheme.apply_flavor_label(_detail)
	v.add_child(_detail)

	_offers = HBoxContainer.new()
	_offers.alignment = BoxContainer.ALIGNMENT_CENTER
	_offers.add_theme_constant_override("separation", 8)
	v.add_child(_offers)
	_ad_btn = Button.new()
	_ad_btn.text = "Watch ad (2× earnings)"
	GameTheme.apply_overlay_cta(_ad_btn, false)
	_ad_btn.pressed.connect(
		func(): Monetization.show_rewarded(Monetization.PLACEMENT_OFFLINE_DOUBLE))
	_offers.add_child(_ad_btn)
	_spin_btn = Button.new()
	_spin_btn.text = "🎯 Spin now"
	GameTheme.apply_overlay_cta(_spin_btn, false)
	_spin_btn.pressed.connect(_on_spin)
	_offers.add_child(_spin_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Tap to continue"
	GameTheme.apply_overlay_cta(_continue_btn, true)
	_continue_btn.pressed.connect(_dismiss)
	v.add_child(_continue_btn)


func is_active() -> bool:
	return phase != Phase.OFF


func start() -> void:
	_gain = maxf(0.0, GameState.offline_gain)
	_shown_take = 0.0
	_t = 0.0
	visible = true
	Telemetry.log_event("ui_ceremony_start", {"gain": _gain})
	if GameTheme.ui_reduced_motion():
		_enter_settled()
		return
	phase = Phase.LIGHTS
	_card.visible = false
	# Offers appear ONLY after the count settles (§4.6 — never gate, never rush).
	_offers.visible = false
	_detail.text = ""
	_take.text = "+$0"
	_backdrop.scrim_a = 0.95
	_backdrop.lights_t = 0.0
	_backdrop.queue_redraw()


func stop() -> void:
	phase = Phase.OFF
	visible = false


func _process(delta: float) -> void:
	if phase == Phase.OFF:
		return
	_t += delta
	match phase:
		Phase.LIGHTS:
			var k := clampf(_t / _LIGHTS_TIME, 0.0, 1.0)
			_backdrop.scrim_a = lerpf(0.95, 0.40, k)
			_backdrop.lights_t = k
			_backdrop.queue_redraw()
			if k >= 0.75 and not _card.visible:
				_card.visible = true
				_card.modulate.a = 0.0
			if _card.visible:
				_card.modulate.a = clampf((k - 0.75) * 4.0, 0.0, 1.0)
			if k >= 1.0:
				phase = Phase.COUNT
				_t = 0.0
		Phase.COUNT:
			# Honesty rule (ADR-001 family): the shown take never exceeds the
			# real gain; it lands exactly on it.
			var k := clampf(_t / _COUNT_TIME, 0.0, 1.0)
			var eased := 1.0 - pow(1.0 - k, 3.0)
			_shown_take = _gain * eased
			_take.text = "+%s" % FormatUtil.format_money(_shown_take)
			if k >= 1.0:
				_enter_settled()
		Phase.SETTLED:
			_ad_btn.visible = (
				Monetization.ads_available() and GameState.can_double_offline_via_ad()
			)


func _enter_settled() -> void:
	phase = Phase.SETTLED
	visible = true
	_card.visible = true
	_card.modulate.a = 1.0
	_backdrop.scrim_a = 0.40
	_backdrop.lights_t = 1.0
	_backdrop.queue_redraw()
	_shown_take = _gain
	_take.text = "+%s" % FormatUtil.format_money(_gain)
	_detail.text = _detail_text()
	_offers.visible = true
	_ad_btn.visible = Monetization.ads_available() and GameState.can_double_offline_via_ad()
	_spin_btn.visible = GameConfig.GAMBLING_ENABLED and GameState.gambling_spins_granted > 0
	if not GameTheme.ui_reduced_motion():
		AudioManager.play("achievement")


func _detail_text() -> String:
	var hours: int = int(GameState.offline_secs_away / 3600.0)
	var mins: int = int(int(GameState.offline_secs_away) % 3600 / 60.0)
	var away: String
	if GameState.offline_capped:
		# N10: the cap is an invitation, not a punishment.
		away = "The crew worked %dh — check in sooner and they'll keep the take flowing." % hours
	elif hours > 0 and mins > 0:
		away = "Away for %dh %dm" % [hours, mins]
	elif hours > 0:
		away = "Away for %dh" % hours
	else:
		away = "Away for %dm" % mins
	var lines: PackedStringArray = PackedStringArray([away, ""])
	lines.append("Ops ready: %d   ·   Territory: %d / %d" % [
		GameState.return_ops_ready,
		GameState.return_territory_player,
		GameState.return_territory_total,
	])
	lines.append("Rivals active: %d (%d at war)" % [
		GameState.return_rival_active,
		GameState.return_rival_at_war,
	])
	if not GameState.offline_rival_events.is_empty():
		lines.append("")
		lines.append("While you were away:")
		for ev in GameState.offline_rival_events:
			lines.append("• %s" % ev)
	return "\n".join(lines)


func _on_tap(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if phase == Phase.SETTLED:
		_dismiss()
	else:
		# Skip the theater at any point — the player's time is borrowed.
		Telemetry.log_event("ui_ceremony_skip", {"at": phase})
		_enter_settled()


func _on_spin() -> void:
	while GameState.show_offline_overlay or GameState.show_daily_overlay:
		GameState.dismiss_offline_overlay()
	stop()
	Telemetry.log_event("ui_luck_wheel_open", {
		"spins": GameState.gambling_free_spins(), "from": "return",
	})
	UiEvents.overlay_requested.emit("gambling")


func _dismiss() -> void:
	Telemetry.log_event("ui_ceremony_done", {"phase": phase})
	GameState.dismiss_offline_overlay()
	stop()
