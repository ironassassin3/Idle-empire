extends Control
## ev1b — heat warning banner IN CONTEXT (DESIGN MOCK — godot/design only).
## Real city stage (scenes/ui/city_view.tscn) + the real shipped masthead
## (scripts/ui/shell/hud_masthead.gd) so the banner is judged against the pixels
## it will actually land on: gold balance above, heat-reddened skyline behind.

const Banner := preload("res://design/ev1b_heat_banner.gd")
const CITY := preload("res://scenes/ui/city_view.tscn")
const Masthead := preload("res://scripts/ui/shell/hud_masthead.gd")

const MASTHEAD_H := 128.0
const SHEET_AT := 0.48  # content sheet top, as a fraction of canvas height

# Heat to preview. 64% = "just crossed"; 91% = the critical tier.
@export var heat := 64.0

var _city: Control
var _mast: Control
var _banner: Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = GameTheme.BG
	add_child(bg)

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.anchor_bottom = SHEET_AT  # ratio, so the mock composes at any canvas
	stage.offset_bottom = 0.0
	stage.clip_contents = true  # the full-bleed city paints past its own rect
	add_child(stage)
	_city = CITY.instantiate()
	_city.set("full_bleed", true)
	_city.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_city.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_city)

	_add_sheet()

	_mast = Control.new()
	_mast.set_script(Masthead)
	_mast.anchor_right = 1.0
	_mast.offset_bottom = MASTHEAD_H
	_mast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mast)

	_banner = Banner.new()
	_banner.heat = heat
	# Slides down ACROSS the masthead (z-above) and parks flush on its bottom
	# rule — the balance/income lines stay readable, the band owns the seam
	# between chrome and stage.
	_banner.rest_y = MASTHEAD_H + 4.0
	add_child(_banner)

	# GameState._ready defers reset_new_game(), so anything seeded in _ready is
	# wiped on the first idle frame. Seed after it, then refresh the chrome.
	call_deferred("_seed_and_refresh")


func _seed_and_refresh() -> void:
	GameState.balance = 1_240_000.0
	GameState.lifetime_earnings = 8_600_000.0
	GameState.lifetime_tokens = 4
	GameState.heat = heat
	var counts := [14, 9, 6, 3, 2, 1, 0, 0, 0, 0, 0]
	for i in GameState.buildings.size():
		if i < counts.size():
			GameState.buildings[i].owned = int(counts[i])

	_city.call(
		"refresh",
		GameState.total_buildings_owned(),
		GameState.heat,
		3,
		GameState.lifetime_tokens,
		["dealer", "racket", "chop", "betting"],
		[],
		[14, 9, 6, 3],
	)
	_mast.call("refresh")
	_banner.call("refresh")
	_banner.call("play_in")
	_retire_heat_pill()


## Rule 4 — every number has ONE home. While the band is up it owns heat, so the
## masthead pill fades out as the band drops (and returns when it retracts).
## Runtime-only here; at port time this is a `_heat_pill.visible` branch in
## hud_masthead.refresh(), keyed off the same >=60% predicate.
func _retire_heat_pill() -> void:
	var pill: Control = _mast.get("_heat_pill")
	if pill == null:
		return
	var tw := create_tween()
	tw.tween_property(pill, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): pill.visible = false)


## Just enough deck to prove the banner is an OVERLAY: nothing below it reflows
## when heat crosses 60 — the list never jumps under the player's thumb.
func _add_sheet() -> void:
	var sheet := PanelContainer.new()
	sheet.anchor_right = 1.0
	sheet.anchor_bottom = 1.0
	sheet.anchor_top = SHEET_AT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.INK_DEEP, 0.97)
	sb.border_color = Color(GameTheme.GOLD, 0.45)
	sb.set_border_width(Side.SIDE_TOP, 1)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 14.0
	sheet.add_theme_stylebox_override("panel", sb)
	add_child(sheet)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)
	var head := Label.new()
	GameTheme.apply_list_section_title(head)
	head.text = "BUSINESSES"
	v.add_child(head)
	for i in 4:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 66)
		row.add_theme_stylebox_override(
			"panel",
			GameTheme.row_card_style(
				GameTheme.RowAffordance.BUYABLE if i == 0 else GameTheme.RowAffordance.LOCKED
			),
		)
		v.add_child(row)
