class_name InkTextureBaker
extends RefCounted
## P15 ink UI 9-slice bake — procedural per MATERIAL_MAKER_SPEC.md (no AI).
## Export via scripts/tools/bake_ink_ui_textures.gd → assets/ui/textures/*.png

const INK_PANEL := Color("0c0c14")
const INK_BG := Color("08070a")
const GOLD := Color("c8a35a")
const GOLD_BRIGHT := Color("ecca7d")

const PANEL_SIZE := 256
const CARD_SIZE := 256
const MODAL_SIZE := 320
const TAB_W := 512
const TAB_H := 64
const GRAIN_SIZE := 256


static func bake_panel_image() -> Image:
	return _bake_ink_frame(PANEL_SIZE, PANEL_SIZE, 24, 0.35, false)


static func bake_card_image() -> Image:
	return _bake_ink_frame(CARD_SIZE, CARD_SIZE, 18, 0.30, true)


static func bake_modal_image() -> Image:
	return _bake_ink_frame(MODAL_SIZE, MODAL_SIZE, 24, 0.50, false)


static func bake_tab_bar_image() -> Image:
	var img := Image.create(TAB_W, TAB_H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	_fill_ink_noise(img, INK_PANEL.lerp(INK_BG, 0.35), rng, 0.02)
	for x in TAB_W:
		img.set_pixel(x, TAB_H - 1, GOLD.lerp(INK_PANEL, 0.4))
		if TAB_H > 2:
			img.set_pixel(x, TAB_H - 2, Color(GOLD, 0.12))
	return img


static func bake_wax_seal_image() -> Image:
	const SIZE := 96
	const CRIMSON := Color("9d1c22")
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var cx := SIZE * 0.5
	var cy := SIZE * 0.5
	var radius := 38.0
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(float(x) - cx, float(y) - cy).length()
			if d > radius:
				continue
			var c := CRIMSON
			var n := rng.randf_range(-1.0, 1.0) * 0.035
			c = c.lightened(n)
			if d > radius - 7.0:
				var rim := clampf((radius - d) / 7.0, 0.0, 1.0)
				c = c.lerp(GOLD, rim * 0.85)
			img.set_pixel(x, y, c)
	return img


static func bake_film_grain_image() -> Image:
	var img := Image.create(GRAIN_SIZE, GRAIN_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for y in GRAIN_SIZE:
		for x in GRAIN_SIZE:
			var v := rng.randf()
			var a := int(clampf(v * 0.07, 0.02, 0.08) * 255.0)
			img.set_pixel(x, y, Color8(220, 210, 195, a))
	return img


static func _bake_ink_frame(
	w: int,
	h: int,
	margin: int,
	gold_strength: float,
	compact: bool,
) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 997 + h * 131
	var base := INK_PANEL if not compact else INK_PANEL.lightened(0.025)
	_fill_ink_noise(img, base, rng, 0.028 if compact else 0.034)
	_apply_ink_border(img, margin, gold_strength)
	_apply_corner_glint(img, margin)
	return img


static func _fill_ink_noise(img: Image, base: Color, rng: RandomNumberGenerator, grain: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var n := rng.randf_range(-1.0, 1.0)
			var stain := sin(float(x) * 0.09 + float(y) * 0.07) * 0.012
			var c := base
			c.r = clampf(c.r + n * grain + stain, 0.0, 1.0)
			c.g = clampf(c.g + n * grain * 0.95 + stain * 0.85, 0.0, 1.0)
			c.b = clampf(c.b + n * grain * 1.05, 0.0, 1.0)
			c.a = 1.0
			img.set_pixel(x, y, c)


static func _apply_ink_border(img: Image, margin: int, gold_strength: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dark := INK_BG.darkened(0.08)
	for y in h:
		for x in w:
			var dx := mini(x, w - 1 - x)
			var dy := mini(y, h - 1 - y)
			var edge := mini(dx, dy)
			if edge >= margin:
				continue
			var t := 1.0 - float(edge) / float(margin)
			var c: Color = img.get_pixel(x, y)
			c = c.lerp(dark, t * 0.45)
			var gold_edge := Color(GOLD, gold_strength)
			if edge < 2:
				c = c.lerp(gold_edge, (1.0 - float(edge) / 2.0) * gold_strength)
			elif edge < 4:
				c = c.lerp(Color(GOLD, gold_strength * 0.45), 0.35)
			img.set_pixel(x, y, c)


static func _apply_corner_glint(img: Image, margin: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var corners: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(w - 2, 1), Vector2i(1, h - 2), Vector2i(w - 2, h - 2),
	]
	for p in corners:
		var c: Color = img.get_pixel(p.x, p.y)
		c = c.lerp(Color(GOLD_BRIGHT, 0.15), 0.55)
		img.set_pixel(p.x, p.y, c)
