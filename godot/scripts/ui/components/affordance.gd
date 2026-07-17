class_name Affordance
extends RefCounted
## Rule 10 — the three-state affordance grammar, one place (UI_OVERHAUL §3.10).
## READY = solid gold fill · APPROACHING = outline + progress-to-afford underbar
## · LOCKED = dimmed silhouette. Same treatment on rows, buttons, tabs, perks.

enum { READY, APPROACHING, LOCKED }


static func state_for_cost(cost: float, balance: float, locked: bool = false) -> int:
	if locked:
		return LOCKED
	return READY if balance >= cost else APPROACHING


static func progress(cost: float, balance: float) -> float:
	if cost <= 0.0:
		return 1.0
	return clampf(balance / cost, 0.0, 1.0)


## Style an action button (rows' BUY, hire, capture...). ≥48dp touch floor.
static func apply_action_button(b: Button, state: int) -> void:
	b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, 116.0), 56.0)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	match state:
		READY:
			# Cyberpunk neon-outline CTA: faint violet-lit fill behind a bright
			# glowing edge, neon text — reads "live" without the solid-block gold.
			sb.bg_color = Color(GameTheme.GOLD, 0.14)
			sb.set_border_width_all(2)
			sb.border_width_bottom = 3
			sb.border_color = GameTheme.GOLD_BRIGHT
			b.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
			b.add_theme_color_override("font_pressed_color", GameTheme.GOLD_BRIGHT)
			b.add_theme_color_override("font_hover_color", GameTheme.TEXT)
		APPROACHING:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(GameTheme.GOLD, 0.45)
			sb.set_border_width_all(1)
			b.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
			b.add_theme_color_override("font_hover_color", GameTheme.TEXT)
		_:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = GameTheme.STATE_LOCKED_EDGE
			sb.set_border_width_all(1)
			b.add_theme_color_override("font_color", Color(GameTheme.TEXT_MUTED, 0.55))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", GameFonts.heading())
	b.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))


## Style a row card panel for the three states (elevation, not border noise).
static func row_style(state: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match state:
		READY:
			sb.bg_color = GameTheme.STATE_READY_BG
			sb.border_color = Color(GameTheme.GOLD, 0.65)
		APPROACHING:
			sb.bg_color = GameTheme.STATE_APPROACH_BG
			sb.border_color = GameTheme.STATE_APPROACH_EDGE
		_:
			sb.bg_color = GameTheme.STATE_LOCKED_BG
			sb.border_color = GameTheme.STATE_LOCKED_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
