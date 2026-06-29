class_name GameFonts
extends RefCounted
## Landing-page typography (OFL) — Cinzel, Cormorant Garamond, Space Mono, Limelight.
## Sources: godot/assets/fonts/ (Google Fonts). Mirrors landing/index.html stack.

const PATH_BODY := "res://assets/fonts/CormorantGaramond-Variable.ttf"
const PATH_BODY_ITALIC := "res://assets/fonts/CormorantGaramond-Italic-Variable.ttf"
const PATH_HEADING := "res://assets/fonts/Cinzel-Variable.ttf"
const PATH_DISPLAY := "res://assets/fonts/Limelight-Regular.ttf"
const PATH_MONO := "res://assets/fonts/SpaceMono-Regular.ttf"
const PATH_MONO_BOLD := "res://assets/fonts/SpaceMono-Bold.ttf"

static var _ready: bool = false
static var _body: Font
static var _body_italic: Font
static var _heading: Font
static var _display: Font
static var _mono: Font
static var _mono_bold: Font


static func ensure_loaded() -> void:
	if _ready:
		return
	_ready = true
	_body = _variation(load(PATH_BODY) as FontFile, 400.0)
	_body_italic = _variation(load(PATH_BODY_ITALIC) as FontFile, 400.0)
	_heading = _variation(load(PATH_HEADING) as FontFile, 600.0)
	_display = load(PATH_DISPLAY) as FontFile
	_mono = _mono_font(load(PATH_MONO) as FontFile, false)
	_mono_bold = _mono_font(load(PATH_MONO_BOLD) as FontFile, true)


static func body() -> Font:
	ensure_loaded()
	return _body if _body != null else ThemeDB.fallback_font


static func body_italic() -> Font:
	ensure_loaded()
	if _body_italic != null:
		return _body_italic
	return body()


static func heading() -> Font:
	ensure_loaded()
	return _heading if _heading != null else ThemeDB.fallback_font


static func display() -> Font:
	ensure_loaded()
	return _display if _display != null else ThemeDB.fallback_font


static func mono(bold: bool = true) -> Font:
	ensure_loaded()
	if bold and _mono_bold != null:
		return _mono_bold
	if _mono != null:
		return _mono
	return ThemeDB.fallback_font


static func apply_to_theme(theme: Theme) -> void:
	if theme == null:
		return
	ensure_loaded()
	if _body == null and _heading == null:
		return
	if _body != null:
		theme.default_font = _body
		for type_name: StringName in [
			&"Label", &"RichTextLabel", &"LineEdit", &"TextEdit", &"ItemList",
			&"Tree", &"CheckBox", &"CheckButton", &"OptionButton",
		]:
			theme.set_font(&"font", type_name, _body)
	if _heading != null:
		for type_name: StringName in [&"Button", &"TabBar"]:
			theme.set_font(&"font", type_name, _heading)


static func apply_to_tree(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	var theme: Theme = tree.root.theme
	if theme == null:
		theme = Theme.new()
	else:
		theme = theme.duplicate(true)
	apply_to_theme(theme)
	tree.root.theme = theme


static func _variation(file: FontFile, weight: float) -> Font:
	if file == null:
		return null
	var v := FontVariation.new()
	v.base_font = file
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): weight}
	return v


static func _mono_font(file: FontFile, _bold: bool) -> Font:
	if file == null:
		return null
	var v := FontVariation.new()
	v.base_font = file
	var ts := TextServerManager.get_primary_interface()
	var tnum := ts.name_to_tag("tnum")
	if tnum != 0:
		v.opentype_features = {tnum: 1}
	return v
