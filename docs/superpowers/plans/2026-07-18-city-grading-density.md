# City Grading + Dark-City Density Floor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the washed sky, break the distant amber window monoculture, and make the skyline always fully built (dark towers that owned business types light up), per `docs/superpowers/specs/2026-07-18-city-grading-density-design.md`.

**Architecture:** All three edits live in `godot/scripts/ui/city_view.gd` `_draw` code: a stepped gradient replaces three flat sky rects in `_draw_back_parallax`, distant windows pick from a seeded `WINDOW_MIX` const instead of always `NEON_WARM`, and `_draw_mid_skyline` gains a rank of dark understudy towers drawn behind the hero facades. Hero-facade windows are already keyed to `GameTheme.building_neon` — they are NOT touched.

**Tech Stack:** Godot 4.6.3 GDScript, `ui_capture.ps1` still harness, `shell_smoke.gd` headless probe.

## Global Constraints

- Godot binary: `E:\Downloads\Godot_v4.6.3-stable_win64.exe`.
- ART_POLICY: primitives only; colors from existing tokens / `NEON_SET` / `building_neon`. No new palette entries beyond the `WINDOW_MIX` const (which only re-lists existing neon values).
- No per-frame allocation; `_draw`-only changes inside the existing 30fps redraw throttle (`REDRAW_INTERVAL`).
- **Reactive behavior untouched:** facade pulse, `_alert_level` warn/critical cues (window blackout share, beacons, siren rims), district flash, raid surge, rooftop sign glyphs, searchlights, reduced-motion branches.
- No save/balance/signal changes.
- Visual work has no unit tests here: test cycle = `shell_smoke.gd` (compiles every scene script + 200-frame crash check) + `ui_capture.ps1` stills you actually READ.
- Capture gotchas: tutorial + rank-up modals pop mid-capture — dismiss with five taps at frames 50/65/90/115/140 on (360, 668) and `"frames": 180` (verified this session). The ps1 wrapper hides engine prints (only JSON lines echo). `owned_list` seeds per-building owned counts index-ordered (dealer first); `heat` seeds the heat meter 0–100.

---

### Task 1: Baseline stills + stepped sky gradient

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (`_draw_back_parallax`, lines ~301–313)
- Create (scratch, not committed): `godot/design/shots/city_spec.json`

**Interfaces:**
- Consumes: existing consts `SKY_BACK`, `SKY_MID`, `SKY_HAZE`, `VIRTUAL_SIZE`.
- Produces: nothing later tasks depend on (Tasks 2–3 edit other regions of the same file).

- [ ] **Step 1: Baseline stills (before any change)**

Write `godot/design/shots/city_spec.json`:

```json
[
  {"shell": true, "tab": 0, "w": 720, "h": 1280, "cash": 5000000, "owned_list": [35], "districts": 6, "prestige_tokens": 12, "no_overlays": true, "frames": 180, "inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}, {"at": 90, "type": "tap", "x": 360, "y": 668}, {"at": 115, "type": "tap", "x": 360, "y": 668}, {"at": 140, "type": "tap", "x": 360, "y": 668}], "out": "D:/2d_game/godot/design/shots/city_before_1type.png"},
  {"shell": true, "tab": 0, "w": 720, "h": 1280, "cash": 5000000, "owned_list": [35, 12, 8, 5, 3], "districts": 6, "prestige_tokens": 12, "no_overlays": true, "frames": 180, "inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}, {"at": 90, "type": "tap", "x": 360, "y": 668}, {"at": 115, "type": "tap", "x": 360, "y": 668}, {"at": 140, "type": "tap", "x": 360, "y": 668}], "out": "D:/2d_game/godot/design/shots/city_before_5type.png"},
  {"shell": true, "tab": 0, "w": 720, "h": 1280, "cash": 5000000, "owned_list": [35, 12, 8, 5, 3], "heat": 75, "districts": 6, "prestige_tokens": 12, "no_overlays": true, "frames": 180, "inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}, {"at": 90, "type": "tap", "x": 360, "y": 668}, {"at": 115, "type": "tap", "x": 360, "y": 668}, {"at": 140, "type": "tap", "x": 360, "y": 668}], "out": "D:/2d_game/godot/design/shots/city_before_heat75.png"}
]
```

Run: `.\ui_capture.ps1 -Spec godot\design\shots\city_spec.json` → expect `"ok":true, "failures":0`.

- [ ] **Step 2: Replace the flat sky rects with a stepped gradient**

In `godot/scripts/ui/city_view.gd::_draw_back_parallax`, replace exactly this block:

```gdscript
	# Layer 0 — deep haze gradient bands (wider portrait read).
	draw_rect(Rect2(0, 0, sw, sh * 0.45), SKY_BACK)
	draw_rect(Rect2(0, sh * 0.35, sw, sh * 0.25), SKY_MID)
	draw_rect(Rect2(0, sh * 0.55, sw, sh * 0.25), SKY_HAZE)
```

with:

```gdscript
	# Layer 0 — stepped night gradient (study idiom). No flat-band seams, and
	# the haze tail is damped to 60% so the sky stays deep, not washed.
	var grad_h := sh * 0.8
	var grad_steps := 24
	for gi in grad_steps:
		var gt := float(gi) / float(grad_steps - 1)
		var gcol := SKY_BACK.lerp(SKY_MID, clampf(gt / 0.55, 0.0, 1.0))
		if gt > 0.55:
			gcol = gcol.lerp(SKY_HAZE, (gt - 0.55) / 0.45 * 0.6)
		draw_rect(Rect2(0, grad_h * float(gi) / float(grad_steps), sw,
				grad_h / float(grad_steps) + 1.0), gcol)
```

(The old bands covered y 0 → `sh * 0.8`; the gradient covers the same span. Everything after — glow rows, moon, stars, ridges — is untouched.)

- [ ] **Step 3: Compile + crash check**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd | Select-String "PASS|FAIL|ERROR"
```

Expected: `[shell_smoke] PASS — 200 frames, no crash`, no script errors.

- [ ] **Step 4: After-still, READ it**

Edit `city_spec.json`: keep only job 1, change `out` to `city_after1_sky.png`. Run the capture. READ `city_after1_sky.png` next to `city_before_1type.png`: the pale horizontal band seams are gone; upper sky reads deep navy; horizon still glows.

- [ ] **Step 5: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): stepped night-sky gradient replaces flat haze bands"
```

---

### Task 2: Distant-window neon mix

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (const block line ~30, `_draw_back_parallax` three window sites)

**Interfaces:**
- Consumes: existing const `NEON_WARM`; existing neon values (violet `8a5cff`, teal `2fd6c6`, magenta `e5457e` — same values as `NEON_SET`).
- Produces: `const WINDOW_MIX: Array[Color]` — Task 3 does NOT use it (understudy towers are unlit); nothing depends on it downstream.

- [ ] **Step 1: Add the mix const**

In `godot/scripts/ui/city_view.gd`, directly below the `NEON_SET` const (line ~30), add:

```gdscript
# Distant lit-window mix — warm amber is one voice among the city's neon,
# not the only one. Seeded per tower, so the mix is stable frame-to-frame.
const WINDOW_MIX := [
	Color8(255, 180, 70), Color8(138, 92, 255), Color8(47, 214, 198),
	Color8(229, 69, 126), Color8(255, 180, 70), Color8(138, 92, 255),
]
```

(2 of 6 warm ≈ the spec's ~1/3.)

- [ ] **Step 2: Swap the three distant-window colors**

All three edits are in `_draw_back_parallax`. Hero facades in `_draw_building_signature` already use `GameTheme.building_neon(key)` — do not touch them.

Edit A — far skyline ridge (line ~339), replace:

```gdscript
			draw_rect(Rect2(fx + fw * 0.35, far_base - fh * 0.55, 2.0, 2.0), Color(NEON_WARM, 0.22))
```

with:

```gdscript
			draw_rect(Rect2(fx + fw * 0.35, far_base - fh * 0.55, 2.0, 2.0),
					Color(WINDOW_MIX[(i * 7) % WINDOW_MIX.size()], 0.22))
```

Edit B — anchor skyscraper windows (line ~361), replace:

```gdscript
			if _hash_flicker(a * 19 + wy * 7, t):
				draw_rect(Rect2(ax - aw * 0.25, atop + 10.0 + wy * 14.0, 2.0, 3.0), Color(NEON_WARM, 0.24))
```

with:

```gdscript
			if _hash_flicker(a * 19 + wy * 7, t):
				draw_rect(Rect2(ax - aw * 0.25, atop + 10.0 + wy * 14.0, 2.0, 3.0),
						Color(WINDOW_MIX[(a * 5 + wy) % WINDOW_MIX.size()], 0.24))
```

Edit C — mid-parallax silhouettes (line ~373), replace:

```gdscript
		if i % 3 == 1:
			draw_rect(Rect2(bx + bw * 0.4, back_y + back_h - bh + 4.0, 2.0, 3.0), Color(NEON_WARM, 0.35))
```

with:

```gdscript
		if i % 3 == 1:
			draw_rect(Rect2(bx + bw * 0.4, back_y + back_h - bh + 4.0, 2.0, 3.0),
					Color(WINDOW_MIX[(i * 11 + 2) % WINDOW_MIX.size()], 0.35))
```

- [ ] **Step 3: Compile + crash check**

Same shell_smoke command as Task 1 Step 3. Expected: PASS, no errors.

- [ ] **Step 4: After-still, READ it**

Edit `city_spec.json`: single job 1, `out` = `city_after2_mix.png`. Run, then READ: distant window dots now show violet/teal/magenta alongside amber; no flicker chaos (colors sit still frame to frame — single still can't show flicker, so judge distribution only); hero tower windows still dealer-amber (identity preserved).

- [ ] **Step 5: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): distant windows mix violet/teal/magenta with amber"
```

---

### Task 3: Dark-city density floor

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (`_draw_mid_skyline`, insert after `neon_keys` is set, before the hero `for i in count:` loop)

**Interfaces:**
- Consumes: locals already in scope at the insertion point: `sw`, `slot_w`, `count`, `ground_y`, `tier`; consts `SILHOUETTE_BACK`, `SILHOUETTE_RIM`.
- Produces: nothing downstream.

- [ ] **Step 1: Insert the understudy rank**

In `_draw_mid_skyline`, the function currently opens:

```gdscript
	var count := mini(maxi(keys.size(), 1), 5)
	var slot_w := sw / maxf(1.0, float(count))
	var neon_keys: Array = keys if not keys.is_empty() else ["dealer"]
	for i in count:
```

Insert between `var neon_keys ...` and `for i in count:`:

```gdscript
	# Dark-city floor — the skyline is always fully built. Unowned blocks wait
	# near-black; each business type the player buys converts a dark block into
	# a lit hero facade (the buy loop, drawn on the horizon).
	var floor_slots := 7
	var under_col := Color8(22, 26, 42)
	for j in floor_slots:
		var ux := sw * (float(j) + 0.5) / float(floor_slots)
		var near_hero := false
		for i in count:
			if absf(ux - slot_w * (float(i) + 0.5)) < sw * 0.5 / float(floor_slots) + 26.0:
				near_hero = true
				break
		if near_hero:
			continue
		var uw := 26.0 + float(j % 3) * 8.0
		var uh := 30.0 + float((j * 13) % 4) * 12.0 + float(tier) * 6.0
		draw_rect(Rect2(ux - uw * 0.5, ground_y - uh, uw, uh), under_col)
		draw_line(Vector2(ux - uw * 0.5, ground_y - uh), Vector2(ux + uw * 0.5, ground_y - uh),
				Color(SILHOUETTE_RIM, 0.22), 1.0)
		# One or two dim windows so the dark block reads as sleeping, not dead.
		if j % 2 == 0:
			draw_rect(Rect2(ux - 2.0, ground_y - uh + 8.0, 2.0, 3.0), Color(SILHOUETTE_RIM, 0.25))
```

Draw order = paint order: the rank lands *before* the hero loop, so lit facades render on top. The `near_hero` suppression skips understudies whose slot a hero facade occupies — owning all 5 types leaves at most the outer edges dark.

- [ ] **Step 2: Compile + crash check**

Same shell_smoke command as Task 1 Step 3. Expected: PASS, no errors.

- [ ] **Step 3: After-stills, READ them**

Set `city_spec.json` to jobs 1 and 2 with `out` = `city_after3_1type.png` / `city_after3_5type.png`. Run, then READ both:
- 1-type: hero dealer tower plus dark understudies across the band — no lonely-tower-in-a-void.
- 5-type: five lit towers in their business neons; few or no dark blocks left between them.

- [ ] **Step 4: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): dark-city floor - unowned blocks wait for their business"
```

---

### Task 4: Final verification sweep

**Files:**
- Modify (scratch only): `godot/design/shots/city_spec.json`

- [ ] **Step 1: Full still matrix (after)**

Set `city_spec.json` back to all three jobs with outputs `city_final_1type.png`, `city_final_5type.png`, `city_final_heat75.png`. Run; expect `"ok":true, "failures":0`.

- [ ] **Step 2: READ all three against the spec's acceptance list**

- 1-type: full skyline, no washed band, hero tower amber (dealer identity) but no longer the only structure.
- 5-type: five business-neon towers over dark understudies; mixed distant window colors.
- heat 75: warn/critical reads survive — window blackout share visible, aviation beacons lit, siren rim/rain still legible against the new grading.
- Compare against `godot/design/shots/premium_check_bldgs.png` (the still that triggered this pass): sky depth and skyline density visibly better.

- [ ] **Step 3: Probes + graph refresh + cleanup**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd | Select-String "PASS|FAIL"
python -m graphify update .
Remove-Item -Force godot\design\shots\city_spec.json, godot\design\shots\city_before_*.png, godot\design\shots\city_after*.png -ErrorAction SilentlyContinue
```

Expected: PASS; graph updated. Keep the three `city_final_*.png` for the owner report. No commit (Task 3 made the last code change).
