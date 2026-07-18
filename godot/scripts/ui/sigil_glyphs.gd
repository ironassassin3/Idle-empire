class_name SigilGlyphs
extends RefCounted
## Shared code-drawn glyph library (ART_POLICY: primitives only). One dispatch
## for business, faction, district, and crew marks so every list screen's
## medallion draws from the same visual language.

## Canonical building key order — index-aligned with building_defs._RAW and
## Manager.building_index.
const BUILDING_KEYS: Array[String] = [
	"dealer", "racket", "chop", "betting", "pawn", "loan",
	"casino", "club", "dock", "arms", "hq",
]


static func draw_glyph(canvas: CanvasItem, key: String, c: Vector2, radius: float, col: Color) -> void:
	var g := radius * 0.56
	var lw := maxf(1.8, radius * 0.14)
	match key:
		# ---- business marks (moved from count_medallion.gd) ----
		"dealer":  # product packet — diamond
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.72, 0),
				c + Vector2(0, g), c + Vector2(-g * 0.72, 0)]), col)
		"racket":  # protection — shield
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.74, -g * 0.5),
				c + Vector2(g * 0.74, g * 0.18), c + Vector2(0, g),
				c + Vector2(-g * 0.74, g * 0.18), c + Vector2(-g * 0.74, -g * 0.5)]), col)
		"chop":  # chop shop — open-end wrench
			canvas.draw_line(c + Vector2(-g * 0.6, g * 0.6), c + Vector2(g * 0.28, -g * 0.28), col, lw * 1.3)
			canvas.draw_arc(c + Vector2(g * 0.46, -g * 0.46), g * 0.34,
				deg_to_rad(-40), deg_to_rad(200), 14, col, lw)
		"betting":  # sports book — die showing three
			canvas.draw_rect(Rect2(c - Vector2(g * 0.82, g * 0.82), Vector2(g * 1.64, g * 1.64)), col, false, lw)
			for p in [Vector2(-g * 0.42, -g * 0.42), Vector2.ZERO, Vector2(g * 0.42, g * 0.42)]:
				canvas.draw_circle(c + p, g * 0.17, col)
		"pawn":  # pawnbroker — three balls
			canvas.draw_circle(c + Vector2(-g * 0.5, -g * 0.22), g * 0.42, col)
			canvas.draw_circle(c + Vector2(g * 0.5, -g * 0.22), g * 0.42, col)
			canvas.draw_circle(c + Vector2(0, g * 0.46), g * 0.42, col)
		"loan":  # loan shark — percent
			canvas.draw_line(c + Vector2(g * 0.62, -g * 0.7), c + Vector2(-g * 0.62, g * 0.7), col, lw)
			canvas.draw_circle(c + Vector2(-g * 0.44, -g * 0.44), g * 0.24, col)
			canvas.draw_circle(c + Vector2(g * 0.44, g * 0.44), g * 0.24, col)
		"casino":  # underground casino — spade
			canvas.draw_circle(c + Vector2(-g * 0.4, g * 0.08), g * 0.42, col)
			canvas.draw_circle(c + Vector2(g * 0.4, g * 0.08), g * 0.42, col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.72, g * 0.18),
				c + Vector2(-g * 0.72, g * 0.18)]), col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.16, g * 0.1), c + Vector2(g * 0.16, g * 0.1),
				c + Vector2(g * 0.3, g * 0.72), c + Vector2(-g * 0.3, g * 0.72)]), col)
		"club":  # nightclub — martini
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.78, -g * 0.62), c + Vector2(g * 0.78, -g * 0.62),
				c + Vector2(0, g * 0.18)]), col)
			canvas.draw_line(c + Vector2(0, g * 0.18), c + Vector2(0, g * 0.72), col, lw)
			canvas.draw_line(c + Vector2(-g * 0.5, g * 0.72), c + Vector2(g * 0.5, g * 0.72), col, lw)
		"dock":  # smuggling — anchor
			canvas.draw_arc(c + Vector2(0, -g * 0.68), g * 0.26, 0, TAU, 14, col, lw)
			canvas.draw_line(c + Vector2(0, -g * 0.42), c + Vector2(0, g * 0.72), col, lw)
			canvas.draw_line(c + Vector2(-g * 0.42, -g * 0.12), c + Vector2(g * 0.42, -g * 0.12), col, lw)
			canvas.draw_arc(c + Vector2(0, g * 0.2), g * 0.7, deg_to_rad(25), deg_to_rad(155), 16, col, lw)
		"arms":  # arms broker — crosshair
			canvas.draw_arc(c, g * 0.74, 0, TAU, 24, col, lw)
			canvas.draw_line(c + Vector2(0, -g), c + Vector2(0, -g * 0.36), col, lw)
			canvas.draw_line(c + Vector2(0, g), c + Vector2(0, g * 0.36), col, lw)
			canvas.draw_line(c + Vector2(-g, 0), c + Vector2(-g * 0.36, 0), col, lw)
			canvas.draw_line(c + Vector2(g, 0), c + Vector2(g * 0.36, 0), col, lw)
			canvas.draw_circle(c, g * 0.14, col)
		"hq":  # syndicate HQ — crown
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.82, g * 0.5), c + Vector2(-g * 0.82, -g * 0.15),
				c + Vector2(-g * 0.4, g * 0.18), c + Vector2(0, -g * 0.55),
				c + Vector2(g * 0.4, g * 0.18), c + Vector2(g * 0.82, -g * 0.15),
				c + Vector2(g * 0.82, g * 0.5)]), col)

		# ---- faction crests ----
		"crimson_kings":  # flame
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.55, -g * 0.1),
				c + Vector2(g * 0.38, g * 0.72), c + Vector2(0, g * 0.4),
				c + Vector2(-g * 0.38, g * 0.72), c + Vector2(-g * 0.55, -g * 0.1)]), col)
		"silver_hand":  # open palm
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.5, -g * 0.05), Vector2(g, g * 0.75)), col)
			for i in 4:
				var fx := -g * 0.44 + float(i) * g * 0.3
				canvas.draw_rect(Rect2(c + Vector2(fx, -g * 0.85), Vector2(g * 0.2, g * 0.85)), col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.5, g * 0.1), c + Vector2(-g * 0.85, -g * 0.25),
				c + Vector2(-g * 0.62, -g * 0.42), c + Vector2(-g * 0.5, -g * 0.05)]), col)
		"iron_union":  # gear
			canvas.draw_arc(c, g * 0.55, 0, TAU, 20, col, lw * 1.4)
			for i in 6:
				var ang := TAU * float(i) / 6.0
				canvas.draw_line(c + Vector2(cos(ang), sin(ang)) * g * 0.62,
					c + Vector2(cos(ang), sin(ang)) * g * 0.95, col, lw * 1.6)
			canvas.draw_circle(c, g * 0.18, col)
		"network":  # eye
			canvas.draw_arc(c + Vector2(0, g * 0.55), g * 1.05, deg_to_rad(235), deg_to_rad(305), 14, col, lw)
			canvas.draw_arc(c + Vector2(0, -g * 0.55), g * 1.05, deg_to_rad(55), deg_to_rad(125), 14, col, lw)
			canvas.draw_circle(c, g * 0.3, col)
		"blackwater":  # triple wave
			for i in 3:
				var wy := -g * 0.5 + float(i) * g * 0.5
				canvas.draw_arc(c + Vector2(-g * 0.4, wy), g * 0.4, PI, TAU, 10, col, lw)
				canvas.draw_arc(c + Vector2(g * 0.4, wy), g * 0.4, 0, PI, 10, col, lw)

		# ---- district types ----
		"residential":  # house
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.9, 0), c + Vector2(0, -g * 0.85), c + Vector2(g * 0.9, 0)]), col)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.6, 0), Vector2(g * 1.2, g * 0.8)), col, false, lw)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.14, g * 0.25), Vector2(g * 0.28, g * 0.55)), col)
		"commercial":  # awning storefront
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.85, -g * 0.7), Vector2(g * 1.7, g * 0.3)), col)
			for i in 3:
				var ax := -g * 0.57 + float(i) * g * 0.57
				canvas.draw_arc(c + Vector2(ax, -g * 0.4), g * 0.28, 0, PI, 10, col, lw)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.6, -g * 0.05), Vector2(g * 1.2, g * 0.75)), col, false, lw)
		"industrial":  # sawtooth factory + stack
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.9, g * 0.8), c + Vector2(-g * 0.9, 0), c + Vector2(-g * 0.3, -g * 0.45),
				c + Vector2(-g * 0.3, 0), c + Vector2(g * 0.3, -g * 0.45), c + Vector2(g * 0.3, 0),
				c + Vector2(g * 0.9, -g * 0.45), c + Vector2(g * 0.9, g * 0.8)]), col)
			canvas.draw_rect(Rect2(c + Vector2(g * 0.45, -g * 0.95), Vector2(g * 0.24, g * 0.5)), col)
		"government":  # columned portico
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.95, -g * 0.35), c + Vector2(0, -g * 0.9), c + Vector2(g * 0.95, -g * 0.35)]), col)
			for i in 3:
				var px := -g * 0.55 + float(i) * g * 0.55
				canvas.draw_line(c + Vector2(px, -g * 0.25), c + Vector2(px, g * 0.55), col, lw * 1.4)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.95, g * 0.6), Vector2(g * 1.9, g * 0.22)), col)

		# ---- crew roles ----
		"crew_protection":  # shield (same silhouette family as racket)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.74, -g * 0.5),
				c + Vector2(g * 0.74, g * 0.18), c + Vector2(0, g),
				c + Vector2(-g * 0.74, g * 0.18), c + Vector2(-g * 0.74, -g * 0.5)]), col)
		"crew_collection":  # coin stack
			for i in 3:
				var sy := g * 0.55 - float(i) * g * 0.45
				canvas.draw_rect(Rect2(c + Vector2(-g * 0.7, sy - g * 0.16), Vector2(g * 1.4, g * 0.32)), col)
		"crew_smuggling":  # crate
			canvas.draw_rect(Rect2(c - Vector2(g * 0.75, g * 0.75), Vector2(g * 1.5, g * 1.5)), col, false, lw)
			canvas.draw_line(c + Vector2(-g * 0.75, -g * 0.75), c + Vector2(g * 0.75, g * 0.75), col, lw)
			canvas.draw_line(c + Vector2(g * 0.75, -g * 0.75), c + Vector2(-g * 0.75, g * 0.75), col, lw)
		"crew_territory":  # pennant flag
			canvas.draw_line(c + Vector2(-g * 0.55, -g), c + Vector2(-g * 0.55, g), col, lw)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.45, -g * 0.95), c + Vector2(g * 0.8, -g * 0.55),
				c + Vector2(-g * 0.45, -g * 0.15)]), col)
		"crew_heat":  # droplet
			canvas.draw_circle(c + Vector2(0, g * 0.25), g * 0.6, col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.5, 0.0), c + Vector2(-g * 0.5, 0.0)]), col)
		_:
			canvas.draw_circle(c, g * 0.5, col)
