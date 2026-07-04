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


## Code-drawn business glyphs (ART_POLICY: primitives only — no bitmap/AI icons).
## Each is a bold, single-colour mark sized to the disc so it reads at ~40px.
func _draw_business_glyph(key: String, c: Vector2, radius: float, col: Color) -> void:
	var g := radius * 0.56
	var lw := maxf(1.8, radius * 0.14)
	match key:
		"dealer":  # product packet — diamond
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.72, 0),
				c + Vector2(0, g), c + Vector2(-g * 0.72, 0)]), col)
		"racket":  # protection — shield
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.74, -g * 0.5),
				c + Vector2(g * 0.74, g * 0.18), c + Vector2(0, g),
				c + Vector2(-g * 0.74, g * 0.18), c + Vector2(-g * 0.74, -g * 0.5)]), col)
		"chop":  # chop shop — open-end wrench
			draw_line(c + Vector2(-g * 0.6, g * 0.6), c + Vector2(g * 0.28, -g * 0.28), col, lw * 1.3)
			draw_arc(c + Vector2(g * 0.46, -g * 0.46), g * 0.34,
				deg_to_rad(-40), deg_to_rad(200), 14, col, lw)
		"betting":  # sports book — die showing three
			draw_rect(Rect2(c - Vector2(g * 0.82, g * 0.82), Vector2(g * 1.64, g * 1.64)), col, false, lw)
			for p in [Vector2(-g * 0.42, -g * 0.42), Vector2.ZERO, Vector2(g * 0.42, g * 0.42)]:
				draw_circle(c + p, g * 0.17, col)
		"pawn":  # pawnbroker — three balls
			draw_circle(c + Vector2(-g * 0.5, -g * 0.22), g * 0.42, col)
			draw_circle(c + Vector2(g * 0.5, -g * 0.22), g * 0.42, col)
			draw_circle(c + Vector2(0, g * 0.46), g * 0.42, col)
		"loan":  # loan shark — percent
			draw_line(c + Vector2(g * 0.62, -g * 0.7), c + Vector2(-g * 0.62, g * 0.7), col, lw)
			draw_circle(c + Vector2(-g * 0.44, -g * 0.44), g * 0.24, col)
			draw_circle(c + Vector2(g * 0.44, g * 0.44), g * 0.24, col)
		"casino":  # underground casino — spade
			draw_circle(c + Vector2(-g * 0.4, g * 0.08), g * 0.42, col)
			draw_circle(c + Vector2(g * 0.4, g * 0.08), g * 0.42, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.72, g * 0.18),
				c + Vector2(-g * 0.72, g * 0.18)]), col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.16, g * 0.1), c + Vector2(g * 0.16, g * 0.1),
				c + Vector2(g * 0.3, g * 0.72), c + Vector2(-g * 0.3, g * 0.72)]), col)
		"club":  # nightclub — martini
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.78, -g * 0.62), c + Vector2(g * 0.78, -g * 0.62),
				c + Vector2(0, g * 0.18)]), col)
			draw_line(c + Vector2(0, g * 0.18), c + Vector2(0, g * 0.72), col, lw)
			draw_line(c + Vector2(-g * 0.5, g * 0.72), c + Vector2(g * 0.5, g * 0.72), col, lw)
		"dock":  # smuggling — anchor
			draw_arc(c + Vector2(0, -g * 0.68), g * 0.26, 0, TAU, 14, col, lw)
			draw_line(c + Vector2(0, -g * 0.42), c + Vector2(0, g * 0.72), col, lw)
			draw_line(c + Vector2(-g * 0.42, -g * 0.12), c + Vector2(g * 0.42, -g * 0.12), col, lw)
			draw_arc(c + Vector2(0, g * 0.2), g * 0.7, deg_to_rad(25), deg_to_rad(155), 16, col, lw)
		"arms":  # arms broker — crosshair
			draw_arc(c, g * 0.74, 0, TAU, 24, col, lw)
			draw_line(c + Vector2(0, -g), c + Vector2(0, -g * 0.36), col, lw)
			draw_line(c + Vector2(0, g), c + Vector2(0, g * 0.36), col, lw)
			draw_line(c + Vector2(-g, 0), c + Vector2(-g * 0.36, 0), col, lw)
			draw_line(c + Vector2(g, 0), c + Vector2(g * 0.36, 0), col, lw)
			draw_circle(c, g * 0.14, col)
		"hq":  # syndicate HQ — crown
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.82, g * 0.5), c + Vector2(-g * 0.82, -g * 0.15),
				c + Vector2(-g * 0.4, g * 0.18), c + Vector2(0, -g * 0.55),
				c + Vector2(g * 0.4, g * 0.18), c + Vector2(g * 0.82, -g * 0.15),
				c + Vector2(g * 0.82, g * 0.5)]), col)
		_:
			draw_circle(c, g * 0.5, col)
