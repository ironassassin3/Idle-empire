extends SceneTree
## Rasterises icon.svg to the 512×512 PNG the Play listing requires.
##
##   godot --headless --path godot -s res://scripts/tools/export_store_icon.gd -- --out ../store/icon_512.png
##
## The SVG is the source of truth (code-drawn, per ART_POLICY.md) — regenerate
## rather than hand-editing a raster, so the launcher icon and the store icon can
## never drift apart.
##
## Write OUTSIDE godot/: anything under the project gets imported and swept into
## the export by `export_filter="all_resources"`. Store art ships to Play, not
## to the device.

const SOURCE := "res://icon.svg"
const SIZE := 512


func _initialize() -> void:
	var out := _arg_after("--out", "res://icon_512.png")
	var svg := FileAccess.get_file_as_string(SOURCE)
	if svg.is_empty():
		printerr("export_store_icon: could not read %s" % SOURCE)
		quit(1)
		return
	var img := Image.new()
	# icon.svg has a 128px viewBox; scale up rather than resampling a small raster.
	var err := img.load_svg_from_string(svg, float(SIZE) / 128.0)
	if err != OK:
		printerr("export_store_icon: SVG rasterise failed (%d)" % err)
		quit(1)
		return
	if img.get_width() != SIZE or img.get_height() != SIZE:
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	# Play rejects transparency on the icon; the SVG already paints a full-bleed
	# background, but flatten defensively so an edit upstream cannot ship alpha.
	if img.detect_alpha() != Image.ALPHA_NONE:
		var flat := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		flat.fill(Color("#0d0b12"))
		flat.blend_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
		img = flat
	img.convert(Image.FORMAT_RGB8)
	var path := out if out.begins_with("res://") or out.begins_with("user://") \
		else ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	err = img.save_png(path)
	if err != OK:
		printerr("export_store_icon: save_png failed (%d) for %s" % [err, path])
		quit(1)
		return
	print("export_store_icon: wrote %dx%d -> %s" % [SIZE, SIZE, path])
	quit(0)


func _arg_after(flag: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find(flag)
	if i >= 0 and i + 1 < args.size():
		return args[i + 1]
	return fallback
