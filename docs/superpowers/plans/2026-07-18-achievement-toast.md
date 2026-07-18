# Achievement Toast Placement — Implementation Plan

**Goal:** Float shell toasts in the stage gap; elevate achievement presence. Per
`docs/superpowers/specs/2026-07-18-achievement-toast-design.md`.

---

### Task 1: Theme — achievement toast style

**File:** `godot/scripts/ui/game_theme.gd`

- [ ] After `ink_toast_style()`, add:

```gdscript
static func ink_achievement_toast_style() -> StyleBoxFlat:
	var sb := ink_toast_style()
	sb.bg_color = Color("120c1c", 0.94)
	sb.border_color = Color(GOLD_BRIGHT, 0.85)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	return sb
```

---

### Task 2: Shell — position + achievement treatment

**File:** `godot/scripts/ui/shell/game_shell.gd`

- [ ] On `_notif_shell` build: `mouse_filter = MOUSE_FILTER_IGNORE`; keep
  CENTER_BOTTOM anchors; initial offsets can stay as fallback.
- [ ] Add `_position_notif()` mirroring `_position_tutorial`:

```gdscript
func _position_notif() -> void:
	var gap := _last_gap_rect
	if gap.size.y <= 0.0:
		return
	var vh := float(get_viewport().get_visible_rect().size.y)
	var below := vh - gap.end.y
	var lift := 12.0
	# Stack above the tutorial banner when it is showing.
	if _tutorial_shell.visible:
		lift += 88.0
	var h := 36.0 if _notif_shell.get_combined_minimum_size().y < 20.0 \
		else maxf(36.0, _notif_shell.get_combined_minimum_size().y)
	_notif_shell.offset_bottom = -(below + lift)
	_notif_shell.offset_top = _notif_shell.offset_bottom - h
```

- [ ] Call `_position_notif()` from `_on_notification` (after visible=true), from
  `_sync_gap_rect` when gap changes (also call `_position_tutorial` there), and
  from `_refresh_tutorial` after positioning tutorial so stack order updates.
- [ ] In `_on_notification`:

```gdscript
	var is_achievement := message.begins_with("Achievement:")
	...
	if is_goal or is_autobuy:
		# existing 4.0s path
	elif is_achievement:
		_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_achievement_toast_style())
		_notif.add_theme_font_size_override("font_size", maxi(_notif_default_font_size + 2, 14))
		_notif_timer = 3.5
	else:
		_notif_shell.add_theme_stylebox_override("panel", GameTheme.ink_toast_style())
		_notif.add_theme_font_size_override("font_size", _notif_default_font_size)
		_notif_timer = 2.5
	_position_notif()
```

- [ ] In `_clear_notif`, restore `ink_toast_style()`.

- [ ] Commit docs + code together or split:
  - `docs(spec): achievement toast floats in the stage gap`
  - `feat(ui): achievement toasts float above the sheet, not on the list`

---

### Task 3: Verify

```powershell
shell_smoke + ui_capture early seed that shows Achievement: …
```

READ: toast in city band; list footer / BUY rows unobstructed.
