extends Control
## Task 6 design gate (DESIGN MOCK — godot/design only).
## Renders the REAL city stage (scenes/ui/city_view.tscn) at all three alert
## levels forced — calm / warn / critical+raid — so the SIREN_RED/SIREN_BLUE
## token pair is judged as sirens against the near-black skyline, not as swatches
## on white. Bottom strip proves the pair is distinct from the reds the city
## ALREADY draws (NEON_RED aviation blips, RED ledger-loss).

const CITY := preload("res://scenes/ui/city_view.tscn")

const LEVELS := [
	{"label": "CALM  ·  heat < 60", "alert": 0, "raid": false, "heat": 18.0},
	{"label": "WARN  ·  heat ≥ 60  ·  a cruiser prowls the street", "alert": 1, "raid": false, "heat": 68.0},
	{"label": "CRITICAL  ·  heat ≥ 85  ·  dragnet + raid", "alert": 2, "raid": true, "heat": 95.0},
]

var _cities: Array = []
var _raid_city: Control = null


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = GameTheme.BG
	add_child(bg)

	# Three stacked stages, each 30% of the canvas height; swatch strip fills the
	# remaining 10% at the bottom. Ratios so it composes at 720 and 1080 wide.
	for i in LEVELS.size():
		var spec: Dictionary = LEVELS[i]
		var stage := Control.new()
		stage.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		stage.anchor_top = float(i) * 0.30
		stage.anchor_bottom = float(i) * 0.30 + 0.30
		stage.offset_bottom = 0.0
		stage.clip_contents = true
		add_child(stage)

		var city: Control = CITY.instantiate()
		city.set("full_bleed", true)
		city.mouse_filter = Control.MOUSE_FILTER_IGNORE
		city.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(city)
		city.call("set_alert_level", int(spec["alert"]))
		if bool(spec["raid"]):
			_raid_city = city
		_cities.append({"node": city, "heat": float(spec["heat"])})

		var tag := Label.new()
		tag.add_theme_font_override("font", GameFonts.heading())
		tag.add_theme_font_size_override("font_size", 15)
		tag.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
		tag.add_theme_color_override("font_outline_color", GameTheme.BG)
		tag.add_theme_constant_override("outline_size", 6)
		tag.position = Vector2(14, 10)
		tag.text = str(spec["label"])
		stage.add_child(tag)

	_add_swatch_strip()
	call_deferred("_seed")


func _seed() -> void:
	GameState.balance = 1_240_000.0
	GameState.lifetime_tokens = 4
	var counts := [14, 9, 6, 3, 2, 1, 0, 0, 0, 0, 0]
	for i in GameState.buildings.size():
		if i < counts.size():
			GameState.buildings[i].owned = int(counts[i])
	# Per-stage heat so the sky itself escalates calm→hunted; the forced alert
	# level layers the cruiser/dragnet/raid on top.
	for entry in _cities:
		entry["node"].call(
			"refresh",
			GameState.total_buildings_owned(),
			float(entry["heat"]),
			3,
			GameState.lifetime_tokens,
			["dealer", "racket", "chop", "betting"],
			[],
			[14, 9, 6, 3],
			[0.42, 0.27, 0.19, 0.12],
		)


func _process(_delta: float) -> void:
	# The raid surge decays in city_view._process; re-arm it every frame so the
	# still captures it at full strength (motion note: in-game it fades ~1s).
	if _raid_city != null:
		_raid_city.set("_raid_pulse", 1.0)


## The decisive evidence for the gate: the two proposed siren tokens beside the
## two reds the city already uses. If SIREN_RED is indistinguishable from
## NEON_RED, or SIREN pair reads like RED "loss", the token fails here.
func _add_swatch_strip() -> void:
	var strip := HBoxContainer.new()
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.anchor_top = 0.90
	strip.offset_top = 0.0
	strip.offset_bottom = 0.0
	strip.add_theme_constant_override("separation", 0)
	add_child(strip)

	var swatches := [
		{"name": "SIREN_RED", "col": GameTheme.SIREN_RED, "note": "raid / cruiser"},
		{"name": "SIREN_BLUE", "col": GameTheme.SIREN_BLUE, "note": "dragnet beam"},
		{"name": "NEON_RED", "col": Color8(220, 60, 70), "note": "aviation blip (exists)"},
		{"name": "RED", "col": GameTheme.RED, "note": "ledger loss (exists)"},
	]
	for s in swatches:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		strip.add_child(cell)

		var chip := ColorRect.new()
		chip.color = s["col"]
		chip.custom_minimum_size = Vector2(0, 74)
		chip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.add_child(chip)

		var name_lbl := Label.new()
		name_lbl.add_theme_font_override("font", GameFonts.mono(true))
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", GameTheme.TEXT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.text = str(s["name"])
		cell.add_child(name_lbl)

		var note_lbl := Label.new()
		note_lbl.add_theme_font_override("font", GameFonts.body())
		note_lbl.add_theme_font_size_override("font_size", 12)
		note_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_lbl.text = str(s["note"])
		cell.add_child(note_lbl)
