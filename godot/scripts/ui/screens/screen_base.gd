class_name ScreenBase
extends Control
## One self-contained scene per tab (UI_OVERHAUL_ARCHITECTURE.md §5). Screens
## own their populate/refresh/input; they never touch other tabs' state or the
## global chrome. The ContentDeck reads title/header_control when swapping.


func screen_title() -> String:
	return ""


## Optional contextual control for the sheet header (e.g. buy multiplier).
func header_control() -> Control:
	return null


func on_show() -> void:
	pass


## Throttled refresh from the shell (~10fps while visible).
func refresh_slow() -> void:
	pass


func make_scroll_list() -> Array:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	add_child(scroll)
	return [scroll, list]
