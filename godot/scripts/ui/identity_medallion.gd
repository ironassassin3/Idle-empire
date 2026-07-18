class_name IdentityMedallion
extends Control
## Identity disc for list rows without a count badge: dark tinted disc + ring +
## code-drawn glyph via SigilGlyphs. Same disc language as CountMedallion so all
## list screens read as one family. ART_POLICY: primitives only.

var glyph_key := "":
	set(v):
		if glyph_key != v:
			glyph_key = v
			queue_redraw()

var tint := Color("8a5cff"):
	set(v):
		if tint != v:
			tint = v
			queue_redraw()

var dimmed := false:
	set(v):
		if dimmed != v:
			dimmed = v
			queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if radius <= 2.0:
		return
	if dimmed:
		draw_circle(c, radius, Color("161020"))
		draw_arc(c, radius, 0, TAU, 48, Color(GameTheme.CHIP_BORDER, 0.95), 2.0)
		draw_arc(c, radius - 4.0, 0, TAU, 48, Color(GameTheme.CHIP_BORDER, 0.3), 1.0)
		SigilGlyphs.draw_glyph(self, glyph_key, c, radius, GameTheme.TEXT_MUTED)
		return
	draw_circle(c, radius, tint.darkened(0.74))
	draw_arc(c, radius, 0, TAU, 48, Color(tint, 0.95), 2.0)
	draw_arc(c, radius - 4.0, 0, TAU, 48, Color(tint, 0.5), 1.0)
	SigilGlyphs.draw_glyph(self, glyph_key, c, radius, tint.lightened(0.35))
