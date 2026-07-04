class_name UiPrims
extends RefCounted
## Stage & Ledger drawn primitives (UI_OVERHAUL_ARCHITECTURE.md §5 components/).
## ART_POLICY: code-drawn only. Shared by masthead, rail, deck, dock, rows.


## Prestige progress — a thin gold thread (masthead bottom rule, afford underbars).
class Filament extends Control:
	var progress := 0.0:
		set(v):
			progress = clampf(v, 0.0, 1.0)
			queue_redraw()
	var track_alpha := 0.16
	var fill := GameTheme.GOLD_BRIGHT
	var ready_pulse := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if ready_pulse and not GameTheme.ui_reduced_motion():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(GameTheme.GOLD, track_alpha))
		var a := 0.95
		if ready_pulse and not GameTheme.ui_reduced_motion():
			a = 0.7 + 0.3 * sin(_t * 4.0)
		draw_rect(Rect2(0, 0, size.x * progress, size.y), Color(fill, a))


## Tiny progress bar (heat pill, afford-progress).
class MiniBar extends Control:
	var progress := 0.0:
		set(v):
			progress = clampf(v, 0.0, 1.0)
			queue_redraw()
	var fill := GameTheme.GOLD:
		set(v):
			fill = v
			queue_redraw()
	var track_alpha := 0.25

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if track_alpha > 0.0:
			draw_rect(Rect2(0, 0, size.x, size.y), Color(fill, track_alpha))
		if progress > 0.0:
			draw_rect(Rect2(0, 0, size.x * progress, size.y), fill)


## READY badge dot on nav tabs (affordance grammar).
class BadgeDot extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 5.0, GameTheme.GOLD_BRIGHT)
		draw_arc(c, 5.0, 0, TAU, 24, Color(GameTheme.GOLD_TEXT_DARK, 0.9), 1.0)


## Sheet drag notch.
class Handle extends Control:
	func _draw() -> void:
		var w := 40.0
		var r := Rect2((size.x - w) * 0.5, (size.y - 4.0) * 0.5, w, 4.0)
		draw_rect(r, Color(GameTheme.TEXT_MUTED, 0.55))


## Masthead legibility gradient — opaque top fading toward the stage.
class Scrim extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var steps := 18
		for i in steps:
			var t := float(i) / steps
			draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0),
				Color(0.031, 0.027, 0.039, lerpf(0.95, 0.35, t)))


static func filament() -> Filament:
	var f := Filament.new()
	f.custom_minimum_size = Vector2(0, 3)
	return f


static func mini_bar(fill_col: Color, h: float = 3.0) -> MiniBar:
	var b := MiniBar.new()
	b.fill = fill_col
	b.custom_minimum_size = Vector2(0, h)
	return b
