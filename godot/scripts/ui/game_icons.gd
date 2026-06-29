class_name GameIcons
extends RefCounted
## Phosphor Icons (MIT) — gold-tinted nav chrome. Sources: assets/icons/phosphor/

const DIR := "res://assets/icons/phosphor/"

const GEAR := "gear"
const BUILDINGS := "buildings"
const TREND_UP := "trend-up"
const USERS_THREE := "users-three"
const MAP_PIN := "map-pin"
const CHART_BAR := "chart-bar"
const SWORD := "sword"
const USERS := "users"
const BRIEFCASE := "briefcase"

static var _cache: Dictionary = {}


static func texture(icon_name: String) -> Texture2D:
	if icon_name.is_empty():
		return null
	if _cache.has(icon_name):
		return _cache[icon_name] as Texture2D
	var path := DIR + icon_name + ".svg"
	if not ResourceLoader.exists(path):
		push_warning("GameIcons: missing %s" % path)
		return null
	var tex: Texture2D = load(path)
	_cache[icon_name] = tex
	return tex
