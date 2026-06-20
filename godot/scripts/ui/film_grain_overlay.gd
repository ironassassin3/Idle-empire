extends TextureRect
## P14.8 film grain — procedural tileable noise, low alpha. Skipped headless / reduced motion.

const TILE_SIZE := 128
const GRAIN_ALPHA := 0.055

func _ready() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = MOUSE_FILTER_IGNORE
	stretch_mode = STRETCH_TILE
	expand_mode = EXPAND_IGNORE_SIZE
	if _should_skip():
		visible = false
		return
	texture = _bake_grain_texture()
	modulate = Color(1.0, 1.0, 1.0, GRAIN_ALPHA)


func _should_skip() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--headless":
			return true
	for arg in OS.get_cmdline_args():
		if arg == "--headless":
			return true
	return GameTheme.ui_reduced_motion()


func _bake_grain_texture() -> ImageTexture:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var v := rng.randf()
			var grey := int(v * 255.0)
			img.set_pixel(x, y, Color8(grey, grey, grey, 255))
	return ImageTexture.create_from_image(img)
