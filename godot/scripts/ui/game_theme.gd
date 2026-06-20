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
	balance.add_theme_font_size_override("font_size", FONT_BALANCE)
	balance.add_theme_color_override("font_color", GOLD_BRIGHT)
	ips.add_theme_font_size_override("font_size", FONT_IPS)
	ips.add_theme_color_override("font_color", GREEN)
	rank.add_theme_font_size_override("font_size", FONT_RANK)
	rank.add_theme_color_override("font_color", TEXT_MUTED)
	rank.clip_text = true


static func tab_label_with_badge(base: String, count: int) -> String:
	if count <= 0:
		return base
	return "%s •%d" % [base, count]
