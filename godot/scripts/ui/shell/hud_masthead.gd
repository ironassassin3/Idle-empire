extends Control
## HudMasthead — Z1 chrome band (UI_OVERHAUL_ARCHITECTURE.md §4).
## Balance is the single largest text on screen; every number here appears
## nowhere else (rule 4). Prestige progress is a filament, not a chip (kills P0%).

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

const HEIGHT := 128.0

var _rank: Label
var _balance: Label
var _ips: Label
var _heat_pill: PanelContainer
var _heat_label: Label
var _heat_bar: UiPrims.MiniBar
var _dragon_chip: Button
var _wheel_chip: Button
var _filament: UiPrims.Filament
var _filament_hit: Button
var _shield_label: Label
var _buff_label: Label

# ── Performing ledger state (Supremacy §4.1, ADR-001) ──
# Display NEVER exceeds truth: gains ease in, spends snap down same-frame.
var _shown := 0.0
var _synced := false
var _last_truth := 0.0
var _last_text := ""
var _last_suffix := ""
var _suffix_init := false
var _prev_shown := 0.0
var _breath_t := 0.0
var _pop_tween: Tween

const _TICKER_TAU := 0.12       # exponential catch-up ≈ 400ms to settle
const _SNAP_FRACTION := 0.01    # snap when within 1% of truth


func _ready() -> void:
	# Chrome band grows with the accessibility text scale (N6) — a fixed 128px
	# clips the income line at 150%.
	custom_minimum_size = Vector2(0, HEIGHT * GameTheme.text_scale_mult())
	var scrim := UiPrims.Scrim.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 8)
	v.add_child(pad)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	pad.add_child(top)

	top.add_child(_build_rank_chip())
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spring)
	_dragon_chip = _build_chip_button("", func(): UiEvents.overlay_requested.emit("dragon"))
	_dragon_chip.visible = false
	top.add_child(_dragon_chip)
	top.add_child(_build_heat_pill())
	_wheel_chip = _build_chip_button("🎯", func(): UiEvents.overlay_requested.emit("gambling"))
	_wheel_chip.visible = GameConfig.GAMBLING_ENABLED
	top.add_child(_wheel_chip)
	top.add_child(_build_gear())

	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance.add_theme_font_override("font", GameFonts.display())
	_balance.add_theme_font_size_override("font_size", GameTheme.scaled_font(44))
	_balance.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_balance.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_balance.add_theme_constant_override("shadow_offset_y", 3)
	_balance.text = "$0"
	_balance.resized.connect(func(): _balance.pivot_offset = _balance.size * 0.5)
	_balance.add_to_group("ledger_balance")  # FxLayer.ledger_point() launch pad
	v.add_child(_balance)

	_ips = Label.new()
	_ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ips.add_theme_font_override("font", GameFonts.mono(true))
	_ips.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_ips.add_theme_color_override("font_color", GameTheme.GREEN)
	_ips.text = "+ $0 / SEC"
	v.add_child(_ips)

	# Shield / buff status ride under the income line (single home each).
	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 14)
	v.add_child(status)
	_shield_label = _mono_status_label(GameTheme.BLUE_BRIGHT)
	status.add_child(_shield_label)
	_buff_label = _mono_status_label(GameTheme.GOLD_BRIGHT)
	status.add_child(_buff_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)

	# Prestige filament — tap target wraps the 3px thread (48dp floor met by
	# the surrounding button height).
	_filament_hit = Button.new()
	_filament_hit.flat = true
	_filament_hit.custom_minimum_size = Vector2(0, 14)
	_filament_hit.tooltip_text = "Prestige progress — tap to open"
	_filament_hit.pressed.connect(func(): UiEvents.overlay_requested.emit("prestige"))
	var sb := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		_filament_hit.add_theme_stylebox_override(st, sb)
	v.add_child(_filament_hit)
	_filament = UiPrims.filament()
	_filament.anchor_left = 0.0
	_filament.anchor_right = 1.0
	_filament.anchor_top = 0.5
	_filament.anchor_bottom = 0.5
	_filament.offset_left = 0.0
	_filament.offset_right = 0.0
	_filament.offset_top = -1.5
	_filament.offset_bottom = 1.5
	_filament_hit.add_child(_filament)


# ------------------------------------------------- performing ledger (§4.1)

func shown_balance() -> float:
	return _shown


func _process(delta: float) -> void:
	_tick_balance(delta)
	_tick_income_breath(delta)


func _tick_balance(delta: float) -> void:
	var truth: float = GameState.balance
	_prev_shown = _shown
	if not _synced or GameTheme.ui_reduced_motion():
		_shown = truth
		_synced = true
	elif truth < _shown:
		# ADR-001: never display more than the truth — spends land instantly.
		_shown = truth
		_pulse_spend()
	else:
		var diff := truth - _shown
		if diff <= maxf(truth * _SNAP_FRACTION, 0.5):
			_shown = truth
		else:
			_shown += diff * clampf(delta / _TICKER_TAU, 0.0, 1.0)
	# Discrete windfall (collect/coin/offline) beyond passive accrual → pop.
	var jump := truth - _last_truth
	var expected: float = GameState.income_per_second() * delta
	if _synced and jump > expected * 4.0 + 1.0 and _last_truth > 0.0:
		_pulse_gain()
	_last_truth = truth

	var txt := FormatUtil.format_money(_shown)
	if txt != _last_text:
		_last_text = txt
		_balance.text = txt
		_check_rollover(txt)


func _suffix_of(txt: String) -> String:
	var out := ""
	for i in range(txt.length() - 1, -1, -1):
		var c := txt[i]
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z"):
			out = c + out
		else:
			break
	return out


## Suffix rollover ($999K → $1.0M): letterpress stamp + tier-2 cue. The
## mechanical-counter moment — the genre's dopamine, made diegetic.
func _check_rollover(txt: String) -> void:
	var suffix := _suffix_of(txt)
	if not _suffix_init:
		# First formatted value (boot / save load) is not a rollover.
		_suffix_init = true
		_last_suffix = suffix
		return
	if suffix != _last_suffix:
		var grew := _shown > _prev_shown
		_last_suffix = suffix
		if grew and not suffix.is_empty() and not GameTheme.ui_reduced_motion():
			_kill_pop()
			_balance.scale = Vector2(1.25, 1.25)
			_pop_tween = create_tween()
			_pop_tween.tween_property(_balance, "scale", Vector2.ONE, 0.28) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			AudioManager.play("achievement")


func _pulse_gain() -> void:
	if GameTheme.ui_reduced_motion() or (_pop_tween != null and _pop_tween.is_running()):
		return
	_balance.scale = Vector2(1.06, 1.06)
	_pop_tween = create_tween()
	_pop_tween.tween_property(_balance, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pulse_spend() -> void:
	if GameTheme.ui_reduced_motion():
		return
	# Bone-white dip: spending reads as a decision, not a loss.
	_balance.modulate = Color(0.92, 0.90, 0.86)
	var tw := create_tween()
	tw.tween_property(_balance, "modulate", Color.WHITE, 0.15)


func _kill_pop() -> void:
	if _pop_tween != null and _pop_tween.is_running():
		_pop_tween.kill()
	_balance.scale = Vector2.ONE


## The idle promise, visible: the income line breathes while money flows.
func _tick_income_breath(delta: float) -> void:
	if GameTheme.ui_reduced_motion() or GameState.income_per_second() <= 0.0:
		_ips.modulate.a = 1.0
		return
	_breath_t += delta
	_ips.modulate.a = 1.0 - 0.10 * (0.5 + 0.5 * sin(_breath_t * TAU / 1.6))


func _mono_status_label(col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", GameFonts.mono(true))
	l.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.text = ""
	return l


func _build_rank_chip() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG, 0.82)
	sb.border_color = Color(GameTheme.GOLD, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	_rank = Label.new()
	_rank.add_theme_font_override("font", GameFonts.heading())
	_rank.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_rank.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_rank.text = "STREET HUSTLER"
	p.add_child(_rank)
	return p


func _build_heat_pill() -> Control:
	_heat_pill = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG, 0.82)
	sb.border_color = Color(GameTheme.RED, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	_heat_pill.add_theme_stylebox_override("panel", sb)
	_heat_pill.tooltip_text = "Heat rises with income. Above 60% risks police raids that seize cash."
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_heat_pill.add_child(v)
	_heat_label = Label.new()
	_heat_label.add_theme_font_override("font", GameFonts.mono(true))
	_heat_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_heat_label.add_theme_color_override("font_color", GameTheme.TEXT)
	_heat_label.text = "HEAT 0%"
	v.add_child(_heat_label)
	_heat_bar = UiPrims.mini_bar(GameTheme.GREEN, 3.0)
	_heat_bar.custom_minimum_size = Vector2(56, 3)
	v.add_child(_heat_bar)
	_heat_pill.visible = false
	return _heat_pill


func _build_chip_button(txt: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(48, 48)  # rule 9 touch floor (ADR-002)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG, 0.82)
	sb.border_color = Color(GameTheme.GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	b.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	b.pressed.connect(on_press)
	return b


func _build_gear() -> Button:
	var b := _build_chip_button("", func(): UiEvents.overlay_requested.emit("config"))
	b.icon = GameIcons.texture("gear")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_color_override("icon_normal_color", GameTheme.GOLD)
	b.tooltip_text = "Settings"
	return b


func refresh() -> void:
	# Track live text-scale changes from Settings without a scene rebuild.
	custom_minimum_size.y = HEIGHT * GameTheme.text_scale_mult()
	# Balance text is owned by the ticker (_tick_balance) — do not set it here.
	_ips.text = "+ %s / SEC" % FormatUtil.format_money(GameState.income_per_second())
	_rank.text = GameTheme.truncate(GameState.rank_label().to_upper(), 20)

	_heat_pill.visible = Disclosure.heat_pill_visible(GameState)
	if _heat_pill.visible:
		var heat_col := GameTheme.GREEN if GameState.heat < 60.0 else GameTheme.RED
		# N6 colorblind shape channel: danger carries a glyph, never color alone.
		var heat_txt := ("▲ " if GameState.heat >= 60.0 else "") + "HEAT %.0f%%" % GameState.heat
		if _ManagerSystem.manager_active(GameState, "The Promoter"):
			heat_txt += " ·A"
		_heat_label.text = heat_txt
		_heat_bar.fill = heat_col
		_heat_bar.progress = GameState.heat / 100.0

	# Shield pips (Collector) + buff status — single home (rule 4).
	if _ManagerSystem.manager_active(GameState, "The Collector"):
		var frac: float = _ManagerSystem.collector_shield_fraction(GameState)
		var filled: int = 3 if frac >= 1.0 else maxi(0, int(round(frac * 3.0)))
		var pips := ""
		for i in 3:
			pips += "●" if i < filled else "○"
		_shield_label.text = "SHIELD %s" % pips
		_shield_label.visible = true
	else:
		_shield_label.visible = false
	var buffs: PackedStringArray = PackedStringArray()
	for b in GameState.buffs:
		if typeof(b) == TYPE_DICTIONARY:
			var nm := str(b.get("name", ""))
			if nm == "frenzy":
				buffs.append("FRENZY 7× %ds" % int(b.get("remaining", 0.0)))
			elif nm == "click_storm":
				buffs.append("STORM 10× %ds" % int(b.get("remaining", 0.0)))
	_buff_label.text = "  ".join(buffs)
	_buff_label.visible = not buffs.is_empty()

	# Prestige filament (disclosure-gated).
	var show_filament := Disclosure.prestige_filament_visible(GameState)
	_filament_hit.visible = show_filament
	if show_filament:
		var summary: Dictionary = Prestige.gate_progress_summary(GameState)
		_filament.progress = float(summary.get("pct", 0)) / 100.0
		_filament.ready_pulse = GameState.can_prestige()
		_filament_hit.tooltip_text = _prestige_tooltip()

	# Dragon companion chip.
	var patron: String = _DragonSystem.active_dragon(GameState)
	_dragon_chip.visible = not patron.is_empty()
	if _dragon_chip.visible:
		var meta: Dictionary = _DragonSystem.DRAGON_META[patron]
		var mood: String = _DragonSystem.get_mood(GameState)
		_dragon_chip.text = GameTheme.truncate(
			"%s" % str(_DragonSystem.MOOD_LABELS.get(mood, mood)), 10)
		_dragon_chip.add_theme_color_override("font_color", meta.get("color", GameTheme.GOLD))
		_dragon_chip.tooltip_text = "%s — tap to visit your patron" % str(meta.get("title", patron))

	if _wheel_chip.visible:
		var spins: int = GameState.gambling_free_spins()
		_wheel_chip.text = "🎯%d" % spins if spins > 0 else "🎯"
		_wheel_chip.tooltip_text = "Luck Wheel — %d free spin(s)" % spins


func _prestige_tooltip() -> String:
	var reqs: Dictionary = Prestige.check_requirements(GameState)
	var earn: Dictionary = reqs.get("earnings", {})
	var lines: PackedStringArray = PackedStringArray([
		"Empire route income (buildings + clicks only): %s / %s" % [
			FormatUtil.format_money(float(earn.get("current", 0.0))),
			FormatUtil.format_money(float(earn.get("required", 0.0))),
		],
	])
	for key in ["dealers", "rackets", "chops"]:
		if reqs.has(key):
			var r: Dictionary = reqs[key]
			if not bool(r.get("met", true)):
				lines.append("%s: %d / %d" % [
					key.capitalize(), int(r.get("current", 0)), int(r.get("required", 0)),
				])
	if reqs.has("rank") and not bool(reqs["rank"].get("met", true)):
		lines.append("Rank: need %s" % str(reqs["rank"].get("required", "")))
	if reqs.has("branch") and not bool(reqs["branch"].get("met", true)):
		lines.append("Choose a prestige path")
	elif reqs.has("branch_perk") and not bool(reqs["branch_perk"].get("met", true)):
		lines.append("Buy a tier-1 perk in your path")
	var gain: int = Prestige.calc_influence_gain(GameState.lifetime_earnings)
	if gain > 0:
		lines.append("+%d Influence at prestige" % gain)
	return "\n".join(lines)
