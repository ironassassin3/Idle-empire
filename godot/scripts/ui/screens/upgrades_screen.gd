extends ScreenBase
## Upgrades tab — grouped by target (Hustle / Businesses / Empire) with the
## §6.2 horizon filter: purchasable now + the next few, rest behind a count
## footer. READY items float to the top of their group.

const UPGRADE_ROW := preload("res://scenes/upgrade_row.tscn")

var _list: VBoxContainer
var _footer: Label
var _built_sig := ""


func _ready() -> void:
	var parts := make_scroll_list()
	_list = parts[1]
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_footer.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	GameState.prestiged.connect(func(_info): _rebuild(true))
	_rebuild(true)


func screen_title() -> String:
	return "EMPIRE UPGRADES"


func on_show() -> void:
	_rebuild()


func refresh_slow() -> void:
	_rebuild()


func _group_of(u) -> String:
	var key := str(u.effect_key)
	if key.contains("click"):
		return "HUSTLE"
	for b in GameState.buildings:
		if key.begins_with(str(b.icon_key)):
			return "BUSINESSES"
	return "EMPIRE"


## Rebuild only when the visible set actually changes — rows self-refresh
## their own affordance, so churn here is pure layout.
func _rebuild(force: bool = false) -> void:
	var visible_idx: Array = []
	var hidden := 0
	for i in GameState.upgrades.size():
		match Disclosure.upgrade_mode(GameState, i):
			"shown":
				visible_idx.append(i)
			"hidden":
				if not GameState.upgrades[i].purchased:
					hidden += 1
	# READY first within each group, stable otherwise.
	var groups := {"HUSTLE": [], "BUSINESSES": [], "EMPIRE": []}
	for i in visible_idx:
		groups[_group_of(GameState.upgrades[i])].append(i)
	for g in groups:
		var arr: Array = groups[g]
		arr.sort_custom(func(a, b):
			var ra := GameState.can_buy_upgrade(a)
			var rb := GameState.can_buy_upgrade(b)
			if ra != rb:
				return ra
			return a < b)
	var sig := "%s|%s|%s|%d" % [groups["HUSTLE"], groups["BUSINESSES"], groups["EMPIRE"], hidden]
	if sig == _built_sig and not force:
		return
	_built_sig = sig

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for g in ["HUSTLE", "BUSINESSES", "EMPIRE"]:
		var arr: Array = groups[g]
		if arr.is_empty():
			continue
		_list.add_child(_group_header(g))
		for i in arr:
			var row: Control = UPGRADE_ROW.instantiate()
			_list.add_child(row)
			row.setup(i)
			row.buy_pressed.connect(_on_upgrade)
	if hidden > 0:
		var foot := Label.new()
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		foot.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		foot.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
		foot.text = "%d more discovered as you grow" % hidden
		_list.add_child(foot)


func _group_header(title: String) -> Control:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", GameTheme.list_section_header_style())
	var lbl := Label.new()
	lbl.text = title
	GameTheme.apply_list_section_title(lbl)
	strip.add_child(lbl)
	return strip


func _on_upgrade(index: int) -> void:
	if GameState.buy_upgrade(index):
		_rebuild(true)
