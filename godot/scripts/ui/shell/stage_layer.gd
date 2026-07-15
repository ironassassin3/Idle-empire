extends Control
## StageLayer — the city promoted from a strip to the app background
## (UI_OVERHAUL_ARCHITECTURE.md §4 Z2). Owns city rendering, tap→hustle
## feedback, and the world-FX API (play_raid / flash_building). No economy math.

const CITY_VIEW := preload("res://scenes/ui/city_view.tscn")
const _BuffSystem = preload("res://scripts/systems/buff_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

const _MAX_FLOATS := 24

var _city: Control
var _float_layer: Control
var _raid_flash: ColorRect
var _tap_chip: PanelContainer
var _tap_chip_label: Label
var _coin_btn: Button
var _gap_rect := Rect2()
var _click_scale := 1.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_city = CITY_VIEW.instantiate()
	_city.set("full_bleed", true)
	_city.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_city)
	# Top-anchored: the city's ground line tracks the sheet's top edge (see
	# set_gap_rect) so the skyline lives in the visible stage, not under chrome.
	_city.anchor_left = 0.0
	_city.anchor_right = 1.0
	_city.anchor_top = 0.0
	_city.anchor_bottom = 0.0
	_city.offset_left = 0.0
	_city.offset_right = 0.0
	_city.offset_top = 0.0
	_city.offset_bottom = 640.0

	_raid_flash = ColorRect.new()
	_raid_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raid_flash.color = Color(0.61, 0.16, 0.16, 0.0)
	_raid_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raid_flash)

	_float_layer = Control.new()
	_float_layer.name = "ClickFloats"
	_float_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)

	_build_tap_chip()
	_build_coin()

	var events: Node = get_node_or_null("/root/UiEvents")
	if events != null:
		events.building_purchased.connect(flash_building)


func _process(delta: float) -> void:
	_t += delta
	if _click_scale < 1.0:
		_click_scale = minf(1.0, _click_scale + delta * 0.55)
	_refresh_tap_chip()
	_refresh_coin(delta)


## The shell tells us which band of the stage is actually visible between the
## rail and the sheet, so diegetic objects sit in open sky, not under chrome.
func set_gap_rect(rect: Rect2) -> void:
	_gap_rect = rect
	# The city canvas ends just below the sheet's top edge, so rooftops and
	# street life stay in view at PEEK/REST instead of hiding under the deck.
	if _city != null:
		_city.offset_bottom = rect.end.y + 56.0
	_layout_gap_children()


func refresh(overlay_blocking: bool) -> void:
	if _city == null:
		return
	_city.call("set_overlay_occluded", overlay_blocking)
	var districts := 0
	for t in GameState.territories:
		if typeof(t) == TYPE_DICTIONARY and bool(t.get("unlocked", false)):
			districts += 1
	var top := _top_buildings()
	var keys: Array = []
	var counts: Array = []
	var shares: Array = []
	for entry in top:
		keys.append(str(entry["key"]))
		counts.append(int(entry["owned"]))
		shares.append(float(entry["share"]))
	_city.call(
		"refresh",
		GameState.total_buildings_owned(),
		GameState.heat,
		districts,
		GameState.lifetime_tokens,
		keys,
		_district_slots(),
		counts,
		shares,
	)


func _top_buildings() -> Array:
	# Most-owned first; the city draws up to 5 hero facades and scales each by
	# its owned count, so the skyline keeps growing with every purchase.
	var ranked: Array = []
	var total_ips := 0.0
	for b in GameState.buildings:
		if b.owned > 0:
			var ips: float = b.income_per_second()  # already × owned (building.gd:40)
			total_ips += ips
			ranked.append({"key": b.icon_key, "owned": b.owned, "ips": ips})
	ranked.sort_custom(func(a, b): return int(a["owned"]) > int(b["owned"]))
	if ranked.size() > 5:
		ranked = ranked.slice(0, 5)
	for e in ranked:
		e["share"] = (float(e["ips"]) / total_ips) if total_ips > 0.0 else 0.0
	return ranked


func _district_slots() -> Array:
	var out: Array = []
	var limit := mini(GameState.territories.size(), 12)
	for i in limit:
		var t = GameState.territories[i]
		if typeof(t) != TYPE_DICTIONARY:
			continue
		var name_str := str(t.get("name", ""))
		out.append({
			"unlocked": bool(t.get("unlocked", false)),
			"color": t.get("color", Color8(60, 60, 80)),
			"short": name_str.substr(0, mini(3, name_str.length())).to_upper(),
		})
	return out


# ------------------------------------------------------------- tap → hustle

## Called by the shell's stage-gap control; pos is global.
func handle_tap(pos: Vector2) -> void:
	Telemetry.log_event("ui_hustle_tap", {
		"source": "stage",
		"tutorial_step": GameState.tutorial_step,
	})
	var TutorialSystem = load("res://scripts/systems/tutorial_system.gd")
	if GameState.tutorial_step == 0:
		TutorialSystem.advance_tutorial(GameState)
	var gained: float = GameState.do_click()
	_click_scale = 0.92
	_spawn_click_float(gained, GameState.last_click_crit, pos)


func _spawn_click_float(amount: float, crit: bool, origin: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _float_layer.get_child_count() >= _MAX_FLOATS:
		return
	var lbl := Label.new()
	var money: String = FormatUtil.format_money(amount)
	lbl.text = ("CRIT +%s" % money) if crit else ("+%s" % money)
	lbl.add_theme_font_override("font", GameFonts.mono(true))
	lbl.add_theme_font_size_override("font_size", 22 if crit else 16)
	lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT if crit else GameTheme.TEXT)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(lbl)
	var pos := origin + Vector2(randf_range(-24.0, 24.0), randf_range(-10.0, 2.0))
	lbl.global_position = pos
	var rise: float = 64.0 if crit else 44.0
	var dur: float = 0.9 if crit else 0.7
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "global_position:y", pos.y - rise, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)


# ----------------------------------------------------------------- world FX

## Raid takeover: crimson flash over the whole stage; the rail carries the text.
func play_raid() -> void:
	if DisplayServer.get_name() == "headless" or GameTheme.ui_reduced_motion():
		return
	var tw := create_tween()
	tw.tween_property(_raid_flash, "color:a", 0.30, 0.12)
	tw.tween_property(_raid_flash, "color:a", 0.0, 0.9).set_ease(Tween.EASE_OUT)


## A purchase lights that business's own facade in the skyline. This used to
## fade one gold ColorRect over the ENTIRE screen and ignore its key, which is
## why every purchase felt identical and the city felt dead.
func flash_building(key: String) -> void:
	# The pulse table is drawn STATE, not an allocated node — safe to set even
	# headless (city_view._draw/_process are headless-gated; _draw_facade_pulse
	# gates reduced-motion). Only reduced-motion suppresses the reaction here.
	if GameTheme.ui_reduced_motion():
		return
	if _city != null and _city.has_method("pulse_facade"):
		_city.call("pulse_facade", key)


# ------------------------------------------------- diegetic gap objects (Z2)

func _build_tap_chip() -> void:
	_tap_chip = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG, 0.6)
	sb.border_color = Color(GameTheme.GOLD, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_tap_chip.add_theme_stylebox_override("panel", sb)
	_tap_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_chip_label = Label.new()
	_tap_chip_label.add_theme_font_override("font", GameFonts.mono(false))
	_tap_chip_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_tap_chip_label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_tap_chip.add_child(_tap_chip_label)
	_tap_chip.visible = false
	add_child(_tap_chip)


func _refresh_tap_chip() -> void:
	# Rule 7: the $/tap chip only exists while a buff or the tap tutorial is live.
	var TutorialSystem = load("res://scripts/systems/tutorial_system.gd")
	var hustling: bool = _BuffSystem.has_buff(GameState, "hustle")
	var show: bool = hustling or GameState.tutorial_step == 0 \
		or not TutorialSystem.is_complete(GameState) and GameState.tutorial_step <= 1
	_tap_chip.visible = show and _gap_rect.size.y > 60.0
	if not _tap_chip.visible:
		return
	var txt := "+%s / TAP" % FormatUtil.format_money(GameState.click_value())
	if hustling:
		txt = "HUSTLE ×%.1f  ·  %s" % [GameConfig.CLICK_HUSTLE_MULT, txt]
		_tap_chip_label.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	else:
		_tap_chip_label.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_tap_chip_label.text = txt
	_layout_gap_children()


func _build_coin() -> void:
	# Golden-coin / ad entry as a diegetic city object (§4 Z2) — a glinting
	# coin hovering in the skyline, not a bordered chrome button.
	_coin_btn = Button.new()
	_coin_btn.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameTheme.GOLD
	sb.border_color = GameTheme.GOLD_BRIGHT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(24)
	for st in ["normal", "hover", "pressed"]:
		_coin_btn.add_theme_stylebox_override(st, sb)
	_coin_btn.text = "★"
	_coin_btn.add_theme_font_size_override("font_size", 22)
	_coin_btn.add_theme_color_override("font_color", GameTheme.GOLD_TEXT_DARK)
	_coin_btn.tooltip_text = "Golden coin"
	_coin_btn.visible = false
	_coin_btn.pressed.connect(_on_coin_pressed)
	# Direct gui_input as well: the pressed signal has been observed to not fire
	# for this button in the shell, yet it still grabs the mouse (blocking the
	# hustle tap). Handling the raw event guarantees the coin action runs.
	_coin_btn.gui_input.connect(_on_coin_gui_input)
	add_child(_coin_btn)


func _on_coin_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_coin_pressed()
			_coin_btn.accept_event()


func _refresh_coin(_delta: float) -> void:
	var lucky: bool = _ManagerSystem.manager_active(GameState, "Lucky Sal")
	var has_coin: bool = GameState.has_golden_coin() and not lucky
	var ad_coin: bool = not has_coin and not lucky and Disclosure.ad_coin_visible(GameState)
	_coin_btn.visible = (has_coin or ad_coin) and _gap_rect.size.y > 70.0
	if not _coin_btn.visible:
		return
	_coin_btn.set_meta("ad_mode", ad_coin and not has_coin)
	_coin_btn.tooltip_text = "Golden coin!" if has_coin else "Watch an ad for a golden coin"
	if not GameTheme.ui_reduced_motion():
		var pulse := 0.75 + 0.25 * sin(_t * (6.0 if has_coin else 2.5))
		_coin_btn.modulate = Color(1, 1, 1, pulse)
	var drift := sin(_t * 0.8) * 4.0 if not GameTheme.ui_reduced_motion() else 0.0
	_coin_btn.position = Vector2(
		_gap_rect.end.x - 68.0,
		_gap_rect.position.y + _gap_rect.size.y * 0.30 + drift,
	)


func _on_coin_pressed() -> void:
	if bool(_coin_btn.get_meta("ad_mode", false)):
		Monetization.show_rewarded(Monetization.PLACEMENT_FREE_COIN)
	else:
		GameState.collect_golden_coin(false)


## The stage gap is one STOP tap-catcher sitting ABOVE the city, so the diegetic
## coin (a stage child, behind the gap) can never receive its own press — every
## tap on it was being consumed as a hustle click. The shell routes gap taps here
## first; a hit on the visible coin acts on the coin and swallows the tap.
func try_tap_coin(global_pos: Vector2) -> bool:
	if _coin_btn == null or not _coin_btn.visible:
		return false
	if _coin_btn.get_global_rect().grow(10.0).has_point(global_pos):
		_on_coin_pressed()
		return true
	return false


func _layout_gap_children() -> void:
	if _tap_chip != null and _tap_chip.visible:
		var chip_size := _tap_chip.get_combined_minimum_size()
		_tap_chip.position = Vector2(
			_gap_rect.position.x + (_gap_rect.size.x - chip_size.x) * 0.5,
			_gap_rect.end.y - chip_size.y - 10.0,
		)
