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
	# Rows are cards, and Godot stops a pointer event at the first control with
	# MOUSE_FILTER_STOP (the default for PanelContainer). Since the cards tile
	# the whole list, a touch press on one never reached the ScrollContainer, so
	# its drag-to-pan never armed and only the scrollbar scrolled. PASS keeps
	# the card's own events working and forwards them up to the scroller.
	# Applied on entry so every current and future row is covered, including
	# the code-built silhouette cards.
	list.child_entered_tree.connect(func(node: Node) -> void:
		if node is Control and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	)
	scroll.add_child(list)
	add_child(scroll)
	return [scroll, list]
