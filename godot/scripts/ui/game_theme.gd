class_name GameTheme
extends RefCounted
## Noir palette + P14 typography / StyleBox helpers — mirrors src/theme.py Phase 127.
## Material Maker texture paths are wired here; flat StyleBoxFlat fallbacks until P14.1 MM export.

const BG := Color("08070a")
const BG_PANEL := Color("121018")
const BG_CARD := Color("1a1520")
const GOLD := Color("c8a35a")
const GOLD_BRIGHT := Color("ecca7d")
const TEXT := Color("e8e0d4")
const TEXT_MUTED := Color("8a8070")
const GREEN := Color("6a9a6a")
const RED := Color("9a4a4a")
const BLUE_BRIGHT := Color("6a9aaa")
const ACCENT := Color("4a6a8a")
const TAB_ACTIVE := Color("2a2030")
const TAB_IDLE := Color("141018")
const BADGE_BG := Color("3a2a18")
const BADGE_BORDER := Color("c8a35a")
const CHIP_BG := Color("1e1828")
const CHIP_BORDER := Color("6a5a40")

# P14 economy HUD — balance 1.4× rank body (14 → 20).
const FONT_BALANCE := 28
const FONT_IPS := 17
const FONT_RANK := 12
const FONT_CHIP := 13
const FONT_TAB_BADGE := 14

# P14 main menu typography hierarchy.
const FONT_MENU_TITLE := 52
const FONT_MENU_SUBTITLE := 18
const FONT_MENU_PREVIEW_HEAD := 12
const FONT_MENU_PREVIEW_LEAD := 22
const FONT_MENU_PREVIEW_BODY := 15
const FONT_MENU_VERSION := 12
const MENU_BTN_MIN_H := 52

# P14 row affordance — code-drawn wax seal + border tints.
enum RowAffordance { LOCKED, BUYABLE, PETE, OWNED }

const ROW_BG_BUYABLE := Color("1a221c")
const ROW_BG_LOCKED := Color("121018")
const ROW_BG_OWNED := Color("161e16")
const ROW_BG_PETE := Color("221e14")

# Material Maker export hooks (empty until P14.1 graphs land).
const TEX_PANEL := "res://assets/ui/textures/panel_9slice.png"
const TEX_CARD := "res://assets/ui/textures/card_frame.png"
const TEX_TAB_BAR := "res://assets/ui/textures/tab_bar.png"
const TEX_MODAL := "res://assets/ui/textures/modal_frame.png"
const TEX_WAX_SEAL := "res://assets/ui/textures/wax_seal.png"


static func truncate(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, maxi(1, max_chars - 1)) + "…"


static func texture_exists(path: String) -> bool:
	return not path.is_empty() and ResourceLoader.exists(path)


static func make_panel_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = Color(GOLD, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	return sb


static func make_chip_flat(active: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BADGE_BG if active else CHIP_BG
	sb.border_color = GOLD_BRIGHT if active else CHIP_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


static func make_tab_badge_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BADGE_BG
	sb.border_color = BADGE_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	return sb


static func panel_style() -> StyleBox:
	if GameConfig.UI_RUSTIC_THEME and texture_exists(TEX_PANEL):
		var tex := StyleBoxTexture.new()
		tex.texture = load(TEX_PANEL)
		return tex
	return make_panel_flat()


static func chip_style(active: bool = false) -> StyleBox:
	return make_chip_flat(active)


static func apply_economy_hud(balance: Label, ips: Label, rank: Label) -> void:
	if balance == null or ips == null or rank == null:
		return
	balance.add_theme_font_size_override("font_size", scaled_font(FONT_BALANCE))
	balance.add_theme_color_override("font_color", GOLD_BRIGHT)
	ips.add_theme_font_size_override("font_size", scaled_font(FONT_IPS))
	ips.add_theme_color_override("font_color", GREEN)
	rank.add_theme_font_size_override("font_size", scaled_font(FONT_RANK))
	rank.add_theme_color_override("font_color", TEXT_MUTED)
	rank.clip_text = true


static func tab_label_with_badge(base: String, count: int) -> String:
	if count <= 0:
		return base
	return "%s •%d" % [base, count]


static func text_scale_mult() -> float:
	if GameState.ui_text_scale >= 1:
		return 1.25
	return 1.0


static func scaled_font(base: int) -> int:
	return int(round(float(base) * text_scale_mult()))


static func make_menu_ledger_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("141018")
	sb.border_color = Color(GOLD, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 32.0
	sb.content_margin_bottom = 28.0
	return sb


static func make_menu_preview_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1520")
	sb.border_color = Color(GOLD, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


static func make_menu_button_flat(primary: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BADGE_BG if primary else CHIP_BG
	sb.border_color = GOLD_BRIGHT if primary else CHIP_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb


static func menu_ledger_style() -> StyleBox:
	return make_menu_ledger_flat()


static func menu_preview_style() -> StyleBox:
	return make_menu_preview_flat()


static func apply_menu_button(btn: Button, primary: bool = false) -> void:
	if btn == null:
		return
	btn.custom_minimum_size.y = maxf(float(btn.custom_minimum_size.y), float(MENU_BTN_MIN_H))
	var normal := make_menu_button_flat(primary)
	var hover := make_menu_button_flat(primary)
	hover.bg_color = hover.bg_color.lightened(0.08)
	var pressed := make_menu_button_flat(primary)
	pressed.bg_color = pressed.bg_color.darkened(0.06)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", make_menu_button_flat(false))
	btn.add_theme_color_override("font_color", GOLD_BRIGHT if primary else TEXT)
	btn.add_theme_font_size_override("font_size", scaled_font(16 if primary else 15))


static func make_row_card_flat(affordance: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match affordance:
		RowAffordance.OWNED:
			sb.bg_color = ROW_BG_OWNED
			sb.border_color = Color(GREEN, 0.35)
		RowAffordance.PETE:
			sb.bg_color = ROW_BG_PETE
			sb.border_color = Color(GOLD_BRIGHT, 0.85)
		RowAffordance.BUYABLE:
			sb.bg_color = ROW_BG_BUYABLE
			sb.border_color = Color(GREEN, 0.75)
		_:
			sb.bg_color = ROW_BG_LOCKED
			sb.border_color = Color(TEXT_MUTED, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


static func row_card_style(affordance: int) -> StyleBox:
	if GameConfig.UI_RUSTIC_THEME and texture_exists(TEX_CARD):
		var tex := StyleBoxTexture.new()
		tex.texture = load(TEX_CARD)
		return tex
	return make_row_card_flat(affordance)


static func apply_row_affordance(row: PanelContainer, affordance: int) -> void:
	if row == null:
		return
	row.add_theme_stylebox_override("panel", row_card_style(affordance))
	row.set_meta("_row_affordance", affordance)
	row.queue_redraw()


static func draw_row_wax_seal(control: Control, affordance: int) -> void:
	if affordance != RowAffordance.BUYABLE and affordance != RowAffordance.PETE:
		return
	var pos := Vector2(10.0, 10.0)
	var radius := 5.5
	var fill := Color(GOLD_BRIGHT, 0.9) if affordance == RowAffordance.PETE else Color(GREEN, 0.85)
	control.draw_circle(pos, radius, fill)
	control.draw_arc(pos, radius + 1.5, 0.0, TAU, 12, Color(fill, 0.35), 1.0)
