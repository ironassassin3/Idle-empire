class_name RusticTextureBaker
extends RefCounted
## Procedural 9-slice UI textures — warm paper/leather noir palette (P14 rustic path).
## Baked once at startup; MM PNGs in assets/ui/textures/ override when present.

const SLICE_MARGIN := 24
const PANEL_SIZE := 256
const CARD_SIZE := 192
const MODAL_SIZE := 320
const TAB_STRIP_H := 56
const TAB_STRIP_W := 256
const BTN_W := 128
const BTN_H := 48
const HEADER_H := 48
const HEADER_W := 512

const KEY_PANEL := "panel"
const KEY_CARD := "card"
const KEY_MODAL := "modal"
const KEY_TAB_IDLE := "tab_idle"
const KEY_TAB_ACTIVE := "tab_active"
const KEY_TAB_BAR_BG := "tab_bar_bg"
const KEY_HEADER_STRIP := "header_strip"
const KEY_BTN_NORMAL := "btn_normal"
const KEY_BTN_HOVER := "btn_hover"
const KEY_BTN_PRESSED := "btn_pressed"

const MM_PATHS := {
	KEY_PANEL: GameTheme.TEX_PANEL,
	KEY_CARD: GameTheme.TEX_CARD,
	KEY_MODAL: GameTheme.TEX_MODAL,
	KEY_TAB_BAR_BG: GameTheme.TEX_TAB_BAR,
}


static func bake_all() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	return {
		KEY_PANEL: _bake_panel(rng, PANEL_SIZE, PANEL_SIZE, false),
		KEY_CARD: _bake_panel(rng, CARD_SIZE, CARD_SIZE, true),
		KEY_MODAL: _bake_panel(rng, MODAL_SIZE, MODAL_SIZE, false, 1.15),
		KEY_TAB_IDLE: _bake_tab_strip(rng, false),
		KEY_TAB_ACTIVE: _bake_tab_strip(rng, true),
		KEY_TAB_BAR_BG: _bake_tab_bar_bg(rng),
		KEY_HEADER_STRIP: _bake_header_strip(rng),
		KEY_BTN_NORMAL: _bake_button(rng, 0.0),
		KEY_BTN_HOVER: _bake_button(rng, 0.06),
		KEY_BTN_PRESSED: _bake_button(rng, -0.05),
	}


static func load_or_bake() -> Dictionary:
	var out: Dictionary = {}
	for key in MM_PATHS:
		var path: String = MM_PATHS[key]
		if _mm_file_exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				out[key] = tex
	var baked := bake_all()
	for key in baked:
		if not out.has(key):
			out[key] = baked[key]
	return out


static func _mm_file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


static func _base_paper() -> Color:
	return Color(GameTheme.TEXT).lerp(GameTheme.BG_PANEL, 0.72)


static func _fill_paper_noise(img: Image, base: Color, rng: RandomNumberGenerator, grain: float = 0.045) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var n := rng.randf_range(-1.0, 1.0)
			var stain := sin(float(x) * 0.07 + float(y) * 0.05) * 0.015
			var c := base
			c.r = clampf(c.r + n * grain + stain, 0.0, 1.0)
			c.g = clampf(c.g + n * grain * 0.9 + stain * 0.8, 0.0, 1.0)
			c.b = clampf(c.b + n * grain * 0.75, 0.0, 1.0)
			c.a = 1.0
			img.set_pixel(x, y, c)


static func _apply_worn_border(img: Image, margin: int, gold_strength: float = 0.55) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var gold := GameTheme.GOLD
	for y in h:
		for x in w:
			var dx := mini(x, w - 1 - x)
			var dy := mini(y, h - 1 - y)
			var edge := mini(dx, dy)
			if edge >= margin:
				continue
			var t := 1.0 - float(edge) / float(margin)
			var c: Color = img.get_pixel(x, y)
			var dark := GameTheme.BG.darkened(0.15)
			c = c.lerp(dark, t * 0.55)
			var edge_gold := gold.lerp(dark, 0.35)
			if edge < 3:
				c = c.lerp(edge_gold, gold_strength * (1.0 - float(edge) / 3.0))
			img.set_pixel(x, y, c)


static func _apply_warm_stains(img: Image, rng: RandomNumberGenerator, count: int = 3) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _i in count:
		var cx := rng.randi_range(int(w / 4), int(w * 3 / 4))
		var cy := rng.randi_range(int(h / 4), int(h * 3 / 4))
		var rad := rng.randi_range(int(mini(w, h) / 8), int(mini(w, h) / 4))
		var tint := Color(GameTheme.GOLD, 0.12).lerp(Color(GameTheme.TEXT_MUTED, 0.08), rng.randf())
		for y in h:
			for x in w:
				var d := Vector2(x - cx, y - cy).length()
				if d > float(rad):
					continue
				var falloff := 1.0 - d / float(rad)
				var c: Color = img.get_pixel(x, y)
				c = c.lerp(tint, falloff * tint.a)
				img.set_pixel(x, y, c)


static func _bake_panel(
	rng: RandomNumberGenerator,
	w: int,
	h: int,
	compact: bool,
	border_boost: float = 1.0
) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := _base_paper()
	if compact:
		base = base.lerp(GameTheme.BG_CARD, 0.35)
	_fill_paper_noise(img, base, rng)
	_apply_warm_stains(img, rng, 2 if compact else 4)
	var margin := SLICE_MARGIN if w >= PANEL_SIZE else int(SLICE_MARGIN * float(w) / float(PANEL_SIZE))
	_apply_worn_border(img, margin, 0.45 * border_boost)
	return ImageTexture.create_from_image(img)


static func _bake_tab_strip(rng: RandomNumberGenerator, active: bool) -> ImageTexture:
	var img := Image.create(TAB_STRIP_W, TAB_STRIP_H, false, Image.FORMAT_RGBA8)
	var base := GameTheme.TAB_ACTIVE if active else GameTheme.TAB_IDLE
	base = base.lerp(_base_paper(), 0.25 if active else 0.12)
	_fill_paper_noise(img, base, rng, 0.035)
	if active:
		for x in TAB_STRIP_W:
			for y in 3:
				var t := 1.0 - float(y) / 3.0
				var c: Color = img.get_pixel(x, TAB_STRIP_H - 1 - y)
				c = c.lerp(GameTheme.GOLD_BRIGHT, t * 0.85)
				img.set_pixel(x, TAB_STRIP_H - 1 - y, c)
	else:
		for x in TAB_STRIP_W:
			var c: Color = img.get_pixel(x, TAB_STRIP_H - 1)
			c = c.lerp(Color(GameTheme.GOLD, 0.35), 0.6)
			img.set_pixel(x, TAB_STRIP_H - 1, c)
	return ImageTexture.create_from_image(img)


static func _bake_tab_bar_bg(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(TAB_STRIP_W, TAB_STRIP_H, false, Image.FORMAT_RGBA8)
	var base := GameTheme.BG_PANEL.lerp(GameTheme.BG, 0.4)
	_fill_paper_noise(img, base, rng, 0.03)
	for y in 2:
		for x in TAB_STRIP_W:
			var c: Color = img.get_pixel(x, y)
			c = c.lerp(GameTheme.GOLD, 0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _bake_header_strip(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(HEADER_W, HEADER_H, false, Image.FORMAT_RGBA8)
	var base := GameTheme.BG_PANEL.lerp(_base_paper(), 0.18)
	_fill_paper_noise(img, base, rng, 0.028)
	for x in HEADER_W:
		var c: Color = img.get_pixel(x, HEADER_H - 1)
		c = c.lerp(Color(GameTheme.GOLD, 0.4), 0.5)
		img.set_pixel(x, HEADER_H - 1, c)
	return ImageTexture.create_from_image(img)


static func _bake_button(rng: RandomNumberGenerator, lift: float) -> ImageTexture:
	var img := Image.create(BTN_W, BTN_H, false, Image.FORMAT_RGBA8)
	var base := GameTheme.BADGE_BG if lift >= 0.0 else GameTheme.CHIP_BG
	base = base.lightened(lift)
	_fill_paper_noise(img, base, rng, 0.04)
	var margin := 10
	_apply_worn_border(img, margin, 0.65)
	return ImageTexture.create_from_image(img)
