class_name CountMedallion
extends Control
## Identity disc for list rows (AdCap-style circular icon): tinted disc +
## Cinzel initial + owned-count badge. Code-drawn per ART_POLICY.

# Distinct dark hues so each business reads at a glance (indexed rotation).
const HUES := [
	Color("3a2430"), Color("24343a"), Color("2e3a24"), Color("3a3324"),
	Color("2c2440"), Color("402424"), Color("24403a"), Color("34283c"),
	Color("3c3028"), Color("283c2c"), Color("30303c"),
]

var count := 0:
	set(v):
		if count != v:
			count = v
			queue_redraw()

var locked := false:
	set(v):
		if locked != v:
			locked = v
			queue_redraw()

var initial := "":
	set(v):
		if initial != v:
			initial = v
			queue_redraw()

var hue_index := -1:
	set(v):
		if hue_index != v:
			hue_index = v
			queue_redraw()

# Business icon_key. When set, the disc tints toward that business's city-skyline
# signature colour so the row and its tower read as the same thing.
var signature_key := "":
	set(v):
		if signature_key != v:
			signature_key = v
			queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if radius <= 2.0:
		return
	var has_sig := not signature_key.is_empty()
	var neon: Color = GameTheme.building_neon(signature_key) if has_sig else GameTheme.GOLD
	var fill: Color
	if locked or hue_index < 0:
		fill = Color("161020")
	elif has_sig:
		fill = neon.darkened(0.74)  # dark disc carrying the signature hue
	else:
		fill = HUES[hue_index % HUES.size()]
	var ring := GameTheme.CHIP_BORDER if locked else GameTheme.GOLD
	draw_circle(c, radius, fill)
	draw_arc(c, radius, 0, TAU, 48, Color(ring, 0.95), 2.0)
	# Inner accent ring carries the business signature (or gold when generic).
	var inner: Color = neon if (has_sig and not locked) else ring
	var inner_a := 0.5 if (has_sig and not locked) else 0.3
	draw_arc(c, radius - 4.0, 0, TAU, 48, Color(inner, inner_a), 1.0)

	# Code-drawn business glyph (ART_POLICY: primitives only). Falls back to the
	# name initial when locked or when the row has no business signature.
	if has_sig and not locked:
		_draw_business_glyph(signature_key, c, radius, GameTheme.GOLD_BRIGHT)
	else:
		var glyph := "?" if locked else initial
		if not glyph.is_empty():
			var font := GameFonts.heading()
			var fs := int(radius * 0.85)
			var ts := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			var col := GameTheme.TEXT_MUTED if locked else GameTheme.GOLD_BRIGHT
			draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.32), glyph,
				HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)

	if count > 0 and not locked:
		# Owned-count badge, bottom-right, gold on dark text.
		var txt := str(count) if count < 1000 else "1K+"
		var bfont := GameFonts.mono(true)
		var bfs := 11 if txt.length() < 3 else 9
		var bts := bfont.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, bfs)
		var br := maxf(10.0, bts.x * 0.5 + 4.0)
		var bc := c + Vector2(radius * 0.72, radius * 0.72)
		draw_circle(bc, br, GameTheme.GOLD)
		draw_arc(bc, br, 0, TAU, 24, GameTheme.GOLD_BRIGHT, 1.0)
		draw_string(bfont, Vector2(bc.x - bts.x * 0.5, bc.y + bts.y * 0.32), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, bfs, GameTheme.GOLD_TEXT_DARK)


## Business glyphs live in the shared SigilGlyphs library so every list
## screen's medallion draws from one visual language.
func _draw_business_glyph(key: String, c: Vector2, radius: float, col: Color) -> void:
	SigilGlyphs.draw_glyph(self, key, c, radius, col)