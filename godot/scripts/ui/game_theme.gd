class_name GameTheme
extends RefCounted
## Noir palette + P14 typography / StyleBox helpers — mirrors src/theme.py Phase 127.
## Rustic surfaces: procedural bake (RusticTextureBaker) with MM PNG drop-in override.

const RusticTextureBaker = preload("res://scripts/ui/rustic_texture_baker.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")
const GameIcons = preload("res://scripts/ui/game_icons.gd")

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
const OVERLAY_BTN_MIN_H := 48
const FONT_TAB := 13

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

const _SLICE_MARGIN := 24
const _CARD_SLICE := 18
# List rows (72–96px tall) cannot use panel card margins — 18+8 per side leaves ~20px
# interior and clips labels/buttons. Tight slice keeps rustic frame without eating content.
const _ROW_SLICE := 4
const _ROW_CONTENT := 0.0

static var _rustic_textures: Dictionary = {}
static var _rustic_style_cache: Dictionary = {}
static var _rustic_init_done: bool = false
static var _rustic_active: bool = false


static func is_rustic_active() -> bool:
	return _rustic_active


static func is_city_v2_active() -> bool:
	return GameConfig.UI_CITY_V2 and GameConfig.UI_CITY_VIEW and not _rustic_active


static func init_rustic() -> void:
	if _rustic_init_done:
		return
	_rustic_init_done = true
	_rustic_active = false
	_rustic_textures.clear()
	_rustic_style_cache.clear()
	if not GameConfig.UI_RUSTIC_THEME:
		return
	if is_city_v2_active():
		return
	var loaded: Dictionary = RusticTextureBaker.load_or_bake()
	if loaded.is_empty():
		push_warning("GameTheme: rustic theme requested but bake produced no textures")
		return
	_rustic_textures = loaded
	_rustic_active = true


static func apply_rustic_theme(tree: SceneTree = null) -> void:
	if not _rustic_active:
		return
	var theme_path := "res://theme/rustic_noir_theme.tres"
	if not ResourceLoader.exists(theme_path):
		return
	var theme := (load(theme_path) as Theme).duplicate(true)
	if theme == null:
		return
	var btn_n := _rustic_btn_style(RusticTextureBaker.KEY_BTN_NORMAL)
	var btn_h := _rustic_btn_style(RusticTextureBaker.KEY_BTN_HOVER)
	var btn_p := _rustic_btn_style(RusticTextureBaker.KEY_BTN_PRESSED)
	if btn_n != null:
		theme.set_stylebox("normal", &"Button", btn_n)
	if btn_h != null:
		theme.set_stylebox("hover", &"Button", btn_h)
	if btn_p != null:
		theme.set_stylebox("pressed", &"Button", btn_p)
	var panel := _rustic_slice_style(RusticTextureBaker.KEY_PANEL, _SLICE_MARGIN)
	if panel != null:
		theme.set_stylebox("panel", &"PanelContainer", panel)
	GameFonts.apply_to_theme(theme)
	if tree != null and tree.root != null:
		tree.root.theme = theme


static func apply_city_v2_theme(tree: SceneTree = null) -> void:
	if not is_city_v2_active():
		return
	var theme_path := "res://theme/city_noir_theme.tres"
	if not ResourceLoader.exists(theme_path):
		return
	var theme := (load(theme_path) as Theme).duplicate(true)
	if theme == null:
		return
	GameFonts.apply_to_theme(theme)
	if tree != null and tree.root != null:
		tree.root.theme = theme


static func ink_panel_style() -> StyleBox:
	var sb := _mm_slice_style(TEX_PANEL, _SLICE_MARGIN, 4.0)
	if sb != null:
		return sb
	return _ink_panel_flat()


static func _ink_panel_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c0c14")
	sb.border_color = Color(GOLD, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4.0)
	return sb


static func ink_scroll_wrap_style() -> StyleBox:
	var sb := ink_panel_style().duplicate()
	sb.set_content_margin_all(2.0)
	return sb


static func ink_header_strip_style() -> StyleBox:
	var sb := ink_panel_style().duplicate()
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = Color("08070a")
	sb.set_content_margin_all(6.0)
	return sb


static func ink_tab_bar_style() -> StyleBox:
	var sb := _mm_slice_style_margins(TEX_TAB_BAR, 16, 8, 16, 8, 4.0)
	if sb != null:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		return sb
	return _ink_tab_bar_flat()


static func _ink_tab_bar_flat() -> StyleBoxFlat:
	var sb := _ink_panel_flat()
	sb.bg_color = BG_PANEL
	sb.set_border_width(Side.SIDE_TOP, 1)
	sb.set_border_width(Side.SIDE_LEFT, 0)
	sb.set_border_width(Side.SIDE_RIGHT, 0)
	sb.set_border_width(Side.SIDE_BOTTOM, 0)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 4.0
	return sb


static func make_ink_chip_flat(active: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("141018") if active else Color("0c0c14")
	sb.border_color = GOLD_BRIGHT if active else Color(GOLD, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	return sb


static func make_ink_tab_strip_flat(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1528") if active else Color("0a0a12")
	sb.border_color = GOLD_BRIGHT if active else Color(GOLD, 0.18)
	sb.set_border_width_all(0)
	sb.set_border_width(Side.SIDE_TOP, 1 if active else 0)
	sb.set_border_width(Side.SIDE_BOTTOM, 3 if active else 1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 2.0
	return sb


static func ink_toast_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0c0c14", 0.92)
	sb.border_color = Color(GOLD, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


static func ink_overlay_modal_style() -> StyleBox:
	var sb := _mm_slice_style(TEX_MODAL, _SLICE_MARGIN, 16.0)
	if sb != null:
		return sb
	var flat := _ink_panel_flat()
	flat.bg_color = Color("0a0a12", 0.96)
	flat.border_color = Color(GOLD, 0.5)
	flat.set_content_margin_all(16.0)
	return flat


static func ink_tutorial_banner_style() -> StyleBoxFlat:
	var sb := ink_toast_style()
	sb.bg_color = Color("0a0a12", 0.94)
	sb.border_color = Color(BLUE_BRIGHT, 0.65)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


static func ink_section_header_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("121018")
	sb.border_color = Color(GOLD, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


static func _rustic_tex(key: String) -> Texture2D:
	return _rustic_textures.get(key) as Texture2D


static func _rustic_slice_style(key: String, margin: int, content: float = 8.0) -> StyleBoxTexture:
	if not _rustic_active:
		return null
	var cache_key := "%s|%d|%.1f" % [key, margin, content]
	if _rustic_style_cache.has(cache_key):
		return _rustic_style_cache[cache_key]
	var tex := _rustic_tex(key)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.set_content_margin_all(content)
	_rustic_style_cache[cache_key] = sb
	return sb


static func _rustic_btn_style(key: String) -> StyleBoxTexture:
	return _rustic_slice_style(key, 10, 10.0)


static func _rustic_tab_style(active: bool) -> StyleBox:
	if not _rustic_active:
		return null
	var key := RusticTextureBaker.KEY_TAB_ACTIVE if active else RusticTextureBaker.KEY_TAB_IDLE
	var sb := _rustic_slice_style(key, 8, 6.0)
	if sb == null:
		return null
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sb


static func _row_card_modulate(affordance: int) -> Color:
	match affordance:
		RowAffordance.OWNED:
			return Color(GREEN, 1.05)
		RowAffordance.PETE:
			return Color(GOLD_BRIGHT, 1.08)
		RowAffordance.BUYABLE:
			return Color(GREEN, 1.12)
		_:
			return Color(TEXT_MUTED, 0.95)


static func header_strip_style() -> StyleBox:
	if is_city_v2_active():
		return ink_header_strip_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_HEADER_STRIP, 6, 6.0)
		if sb != null:
			sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			return sb
	return make_panel_flat()


static func list_section_header_style() -> StyleBox:
	if is_city_v2_active():
		return ink_section_header_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_HEADER_STRIP, 6, 8.0)
		if sb != null:
			sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(BG_CARD, 1.0)
	flat.border_color = Color(GOLD, 0.55)
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(4)
	flat.content_margin_left = 10.0
	flat.content_margin_right = 10.0
	flat.content_margin_top = 8.0
	flat.content_margin_bottom = 6.0
	return flat


static func config_section_header_style() -> StyleBox:
	return list_section_header_style()


static func ink_config_row_style() -> StyleBox:
	var sb := _mm_slice_style(TEX_CARD, _CARD_SLICE, 8.0)
	if sb != null:
		return sb
	var flat := make_ink_row_card_flat(RowAffordance.LOCKED)
	flat.content_margin_left = 10.0
	flat.content_margin_right = 10.0
	flat.content_margin_top = 6.0
	flat.content_margin_bottom = 6.0
	return flat


static func ink_stat_card_style() -> StyleBox:
	var sb := _mm_slice_style(TEX_CARD, _CARD_SLICE, 6.0)
	if sb != null:
		return sb
	var flat := make_ink_row_card_flat(RowAffordance.LOCKED)
	flat.content_margin_left = 8.0
	flat.content_margin_right = 8.0
	flat.content_margin_top = 6.0
	flat.content_margin_bottom = 6.0
	return flat


static func ink_progress_track_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0a0a12")
	sb.border_color = Color(GOLD, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


static func config_row_style() -> StyleBox:
	if is_city_v2_active():
		return ink_config_row_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_CARD, 10, 8.0)
		if sb != null:
			var dup := sb.duplicate() as StyleBoxTexture
			dup.modulate_color = Color(TEXT, 0.92)
			return dup
	var sb_flat := StyleBoxFlat.new()
	sb_flat.bg_color = BG_CARD
	sb_flat.border_color = Color(GOLD, 0.25)
	sb_flat.set_border_width_all(1)
	sb_flat.set_corner_radius_all(6)
	sb_flat.content_margin_left = 10.0
	sb_flat.content_margin_right = 10.0
	sb_flat.content_margin_top = 6.0
	sb_flat.content_margin_bottom = 6.0
	return sb_flat


static func stat_card_style() -> StyleBox:
	if is_city_v2_active():
		return ink_stat_card_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_CARD, _CARD_SLICE, 10.0)
		if sb != null:
			var dup := sb.duplicate() as StyleBoxTexture
			dup.modulate_color = Color(1.1, 1.06, 0.98, 1.0)
			return dup
	return make_row_card_flat(RowAffordance.LOCKED)


static func apply_list_section_title(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
	lbl.add_theme_font_size_override("font_size", scaled_font(12))


static func apply_subtab_header_label(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
	lbl.add_theme_font_size_override("font_size", scaled_font(12))


static func tab_bar_bg_style() -> StyleBox:
	if is_city_v2_active():
		return ink_tab_bar_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_TAB_BAR_BG, 6, 4.0)
		if sb != null:
			sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			return sb
	var sb_flat := StyleBoxFlat.new()
	sb_flat.bg_color = BG_PANEL
	sb_flat.border_color = Color(GOLD, 0.25)
	sb_flat.set_border_width(Side.SIDE_TOP, 1)
	return sb_flat


static func truncate(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, maxi(1, max_chars - 1)) + "…"


static func texture_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


static func _mm_slice_style(tex_path: String, margin: int, content: float = 8.0) -> StyleBoxTexture:
	return _mm_slice_style_margins(tex_path, margin, margin, margin, margin, content)


static func _mm_slice_style_margins(
	tex_path: String,
	ml: int,
	mt: int,
	mr: int,
	mb: int,
	content: float = 8.0,
) -> StyleBoxTexture:
	if not texture_exists(tex_path):
		return null
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = ml
	sb.texture_margin_top = mt
	sb.texture_margin_right = mr
	sb.texture_margin_bottom = mb
	sb.set_content_margin_all(content)
	return sb


static func make_panel_flat() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = Color(GOLD, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	return sb


static func make_chip_flat(active: bool = false) -> StyleBoxFlat:
	if is_city_v2_active():
		return make_ink_chip_flat(active)
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


static func make_tab_strip_flat(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TAB_ACTIVE if active else TAB_IDLE
	sb.border_color = GOLD_BRIGHT if active else Color(GOLD, 0.2)
	sb.set_border_width_all(0)
	sb.set_border_width(Side.SIDE_BOTTOM, 3 if active else 1)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 4.0
	return sb


static func tab_strip_style(active: bool) -> StyleBox:
	var rustic := _rustic_tab_style(active)
	if rustic != null:
		return rustic
	if is_city_v2_active():
		return make_ink_tab_strip_flat(active)
	if _rustic_active and texture_exists(TEX_TAB_BAR):
		var tex := StyleBoxTexture.new()
		tex.texture = load(TEX_TAB_BAR)
		return tex
	return make_tab_strip_flat(active)


static func panel_style() -> StyleBox:
	if is_city_v2_active():
		return ink_panel_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_PANEL, _SLICE_MARGIN)
		if sb != null:
			return sb
	if texture_exists(TEX_PANEL):
		var tex := StyleBoxTexture.new()
		tex.texture = load(TEX_PANEL)
		tex.texture_margin_left = _SLICE_MARGIN
		tex.texture_margin_top = _SLICE_MARGIN
		tex.texture_margin_right = _SLICE_MARGIN
		tex.texture_margin_bottom = _SLICE_MARGIN
		tex.set_content_margin_all(8.0)
		return tex
	return make_panel_flat()


static func chip_style(active: bool = false) -> StyleBox:
	return make_chip_flat(active)


static func apply_economy_hud(balance: Label, ips: Label, rank: Label) -> void:
	if balance == null or ips == null or rank == null:
		return
	balance.add_theme_font_override("font", GameFonts.mono(true))
	balance.add_theme_font_size_override("font_size", scaled_font(FONT_BALANCE))
	balance.add_theme_color_override("font_color", GOLD_BRIGHT)
	ips.add_theme_font_override("font", GameFonts.mono(false))
	ips.add_theme_font_size_override("font_size", scaled_font(FONT_IPS))
	ips.add_theme_color_override("font_color", GREEN)
	rank.add_theme_font_override("font", GameFonts.heading())
	rank.add_theme_font_size_override("font_size", scaled_font(FONT_RANK))
	if is_city_v2_active():
		rank.add_theme_color_override("font_color", GOLD)
	else:
		rank.add_theme_color_override("font_color", TEXT_MUTED)
	rank.clip_text = true


static func apply_flavor_label(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_override("font", GameFonts.body_italic())


static func apply_button_icon(btn: Button, icon_name: String, icon_px: int = 20, active: bool = true) -> void:
	if btn == null or icon_name.is_empty():
		return
	var tex := GameIcons.texture(icon_name)
	if tex == null:
		return
	btn.icon = tex
	btn.add_theme_constant_override("icon_max_width", icon_px)
	btn.add_theme_constant_override("icon_max_height", icon_px)
	var on := GOLD_BRIGHT if active else TEXT_MUTED
	btn.add_theme_color_override("icon_normal_color", on)
	btn.add_theme_color_override("icon_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("icon_pressed_color", GOLD_BRIGHT)
	btn.add_theme_color_override("icon_focus_color", GOLD_BRIGHT)
	btn.add_theme_color_override("icon_disabled_color", TEXT_MUTED)


static func apply_gear_icon_button(btn: Button) -> void:
	if btn == null:
		return
	apply_ink_chip_button(btn, false, scaled_font(16), GOLD_BRIGHT)
	btn.text = ""
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_button_icon(btn, GameIcons.GEAR, 22, true)


static func apply_tab_nav_icon(btn: Button, icon_name: String, active: bool) -> void:
	if btn == null:
		return
	apply_button_icon(btn, icon_name, 16, active)
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP


static func apply_ink_icon_button(btn: Button) -> void:
	if btn == null:
		return
	apply_gear_icon_button(btn)


static func apply_ink_chip_button(
	btn: Button,
	active: bool = false,
	font_size: int = FONT_CHIP,
	font_color: Color = GOLD_BRIGHT,
) -> void:
	if btn == null:
		return
	var normal := make_ink_chip_flat(active)
	var hover := make_ink_chip_flat(true)
	var pressed := make_ink_chip_flat(true)
	pressed.bg_color = pressed.bg_color.darkened(0.08)
	var disabled := make_ink_chip_flat(false)
	disabled.bg_color = disabled.bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", scaled_font(font_size))


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


## Particles OFF doubles as reduced-motion (P14.7) — skip overlay pulses / heavy UI motion.
static func ui_reduced_motion() -> bool:
	return not GameState.show_particles


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


static func make_ink_menu_preview_flat() -> StyleBox:
	var sb := ink_panel_style().duplicate()
	if sb is StyleBoxFlat:
		(sb as StyleBoxFlat).bg_color = Color("0a0a12")
		(sb as StyleBoxFlat).border_color = Color(GOLD, 0.4)
		(sb as StyleBoxFlat).set_corner_radius_all(6)
	sb.set_content_margin_all(12.0)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


static func make_ink_menu_button_flat(primary: bool = false) -> StyleBoxFlat:
	var sb := make_ink_chip_flat(primary)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	sb.set_corner_radius_all(6)
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
	if is_city_v2_active():
		var sb := ink_overlay_modal_style()
		sb.content_margin_left = 24.0
		sb.content_margin_right = 24.0
		sb.content_margin_top = 28.0
		sb.content_margin_bottom = 24.0
		return sb
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_MODAL, _SLICE_MARGIN, 28.0)
		if sb != null:
			return sb
	return make_menu_ledger_flat()


static func overlay_ledger_style() -> StyleBox:
	if is_city_v2_active():
		return ink_overlay_modal_style()
	if _rustic_active:
		var sb := _rustic_slice_style(RusticTextureBaker.KEY_MODAL, _SLICE_MARGIN, 20.0)
		if sb != null:
			return sb
	if texture_exists(TEX_MODAL):
		var tex := StyleBoxTexture.new()
		tex.texture = load(TEX_MODAL)
		tex.texture_margin_left = _SLICE_MARGIN
		tex.texture_margin_top = _SLICE_MARGIN
		tex.texture_margin_right = _SLICE_MARGIN
		tex.texture_margin_bottom = _SLICE_MARGIN
		tex.set_content_margin_all(20.0)
		return tex
	return make_menu_ledger_flat()


static func menu_preview_style() -> StyleBox:
	if is_city_v2_active():
		return make_ink_menu_preview_flat()
	return make_menu_preview_flat()


static func apply_overlay_cta(btn: Button, primary: bool = true) -> void:
	if btn == null:
		return
	apply_menu_button(btn, primary)
	btn.custom_minimum_size.y = maxf(float(btn.custom_minimum_size.y), float(OVERLAY_BTN_MIN_H))


static func apply_tab_button(btn: Button, active: bool = false) -> void:
	if btn == null:
		return
	btn.add_theme_font_size_override("font_size", scaled_font(FONT_TAB))
	var normal := tab_strip_style(active)
	var hover := tab_strip_style(active)
	if hover is StyleBoxFlat:
		(hover as StyleBoxFlat).bg_color = (hover as StyleBoxFlat).bg_color.lightened(0.06)
	var pressed := tab_strip_style(active)
	if pressed is StyleBoxFlat:
		(pressed as StyleBoxFlat).bg_color = (pressed as StyleBoxFlat).bg_color.darkened(0.05)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", tab_strip_style(active))
	if is_city_v2_active():
		btn.add_theme_color_override("font_color", GOLD_BRIGHT if active else TEXT)
		btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	else:
		btn.add_theme_color_override("font_color", GOLD_BRIGHT if active else TEXT_MUTED)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	if is_city_v2_active():
		var icon_name: String = str(btn.get_meta("nav_icon", ""))
		if not icon_name.is_empty():
			apply_tab_nav_icon(btn, icon_name, active)


static func apply_menu_button(btn: Button, primary: bool = false) -> void:
	if btn == null:
		return
	btn.custom_minimum_size.y = maxf(float(btn.custom_minimum_size.y), float(MENU_BTN_MIN_H))
	if is_city_v2_active():
		var normal := make_ink_menu_button_flat(primary)
		var hover := make_ink_menu_button_flat(primary)
		hover.bg_color = hover.bg_color.lightened(0.06)
		var pressed := make_ink_menu_button_flat(primary)
		pressed.bg_color = pressed.bg_color.darkened(0.08)
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("disabled", make_ink_menu_button_flat(false))
		btn.add_theme_color_override("font_color", GOLD_BRIGHT if primary else TEXT)
		btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
		btn.add_theme_font_size_override("font_size", scaled_font(16 if primary else 15))
		return
	if _rustic_active:
		var normal := _rustic_btn_style(RusticTextureBaker.KEY_BTN_NORMAL)
		var hover := _rustic_btn_style(RusticTextureBaker.KEY_BTN_HOVER)
		var pressed := _rustic_btn_style(RusticTextureBaker.KEY_BTN_PRESSED)
		if normal != null:
			btn.add_theme_stylebox_override("normal", normal)
		if hover != null:
			btn.add_theme_stylebox_override("hover", hover)
		if pressed != null:
			btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("disabled", make_menu_button_flat(false))
		btn.add_theme_color_override("font_color", GOLD_BRIGHT if primary else TEXT)
		btn.add_theme_font_size_override("font_size", scaled_font(16 if primary else 15))
		return
	var normal_flat := make_menu_button_flat(primary)
	var hover_flat := make_menu_button_flat(primary)
	hover_flat.bg_color = hover_flat.bg_color.lightened(0.08)
	var pressed_flat := make_menu_button_flat(primary)
	pressed_flat.bg_color = pressed_flat.bg_color.darkened(0.06)
	btn.add_theme_stylebox_override("normal", normal_flat)
	btn.add_theme_stylebox_override("hover", hover_flat)
	btn.add_theme_stylebox_override("pressed", pressed_flat)
	btn.add_theme_stylebox_override("disabled", make_menu_button_flat(false))
	btn.add_theme_color_override("font_color", GOLD_BRIGHT if primary else TEXT)
	btn.add_theme_font_size_override("font_size", scaled_font(16 if primary else 15))


static func make_ink_row_card_flat(affordance: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match affordance:
		RowAffordance.OWNED:
			sb.bg_color = Color("101418")
			sb.border_color = Color(GREEN, 0.45)
		RowAffordance.PETE:
			sb.bg_color = Color("181410")
			sb.border_color = Color(GOLD_BRIGHT, 0.75)
		RowAffordance.BUYABLE:
			sb.bg_color = Color("0e1410")
			sb.border_color = Color(GREEN, 0.55)
		_:
			sb.bg_color = Color("0a0a12")
			sb.border_color = Color(GOLD, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(0.0)
	return sb


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
	sb.set_content_margin_all(0.0)
	return sb


static func row_card_style(affordance: int) -> StyleBox:
	if is_city_v2_active():
		var base := _mm_slice_style(TEX_CARD, _CARD_SLICE, _ROW_CONTENT)
		if base != null:
			var sb := base.duplicate() as StyleBoxTexture
			sb.modulate_color = _row_card_modulate(affordance)
			return sb
		return make_ink_row_card_flat(affordance)
	if _rustic_active:
		var base := _rustic_slice_style(RusticTextureBaker.KEY_CARD, _ROW_SLICE, _ROW_CONTENT)
		if base != null:
			var sb := base.duplicate() as StyleBoxTexture
			sb.modulate_color = _row_card_modulate(affordance)
			return sb
	if texture_exists(TEX_CARD):
		var tex := StyleBoxTexture.new()
		tex.texture = load(TEX_CARD)
		tex.texture_margin_left = _ROW_SLICE
		tex.texture_margin_top = _ROW_SLICE
		tex.texture_margin_right = _ROW_SLICE
		tex.texture_margin_bottom = _ROW_SLICE
		tex.set_content_margin_all(_ROW_CONTENT)
		return tex
	return make_row_card_flat(affordance)


static func apply_row_affordance(row: PanelContainer, affordance: int) -> void:
	if row == null:
		return
	row.add_theme_stylebox_override("panel", row_card_style(affordance))
	row.set_meta("_row_affordance", affordance)
	row.queue_redraw()


static func apply_row_buy_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_font_size_override("font_size", scaled_font(12))
	var normal := make_chip_flat(false)
	var hover := make_chip_flat(false)
	hover.bg_color = hover.bg_color.lightened(0.08)
	var pressed := make_chip_flat(false)
	pressed.bg_color = pressed.bg_color.darkened(0.06)
	var disabled := make_chip_flat(false)
	disabled.bg_color = disabled.bg_color.darkened(0.12)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)


static func draw_row_wax_seal(control: Control, affordance: int) -> void:
	if affordance != RowAffordance.BUYABLE and affordance != RowAffordance.PETE:
		return
	if texture_exists(TEX_WAX_SEAL):
		var tex := load(TEX_WAX_SEAL) as Texture2D
		if tex != null:
			var seal_size := 14.0
			var tint := Color(GREEN, 0.92) if affordance == RowAffordance.BUYABLE else Color(GOLD_BRIGHT, 0.95)
			control.draw_texture_rect(tex, Rect2(3.0, 4.0, seal_size, seal_size), false, tint)
			return
	var pos := Vector2(10.0, 10.0)
	var radius := 5.5
	var fill := Color(GOLD_BRIGHT, 0.9) if affordance == RowAffordance.PETE else Color(GREEN, 0.85)
	control.draw_circle(pos, radius, fill)
	control.draw_arc(pos, radius + 1.5, 0.0, TAU, 12, Color(fill, 0.35), 1.0)
