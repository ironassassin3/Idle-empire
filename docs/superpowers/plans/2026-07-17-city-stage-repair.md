# City Stage Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four confirmed city-stage defects (blank hero towers, floating distant windows, heat unreadable in stills, occluded raid cue) per `docs/superpowers/specs/2026-07-17-city-stage-repair-design.md`.

**Architecture:** All changes are drawn-state edits inside `godot/scripts/ui/city_view.gd` — an immediate-mode `_draw()` canvas (404×320 virtual space, 30 fps redraw cap). No new nodes, signals, save fields, or balance values. Alert state already arrives via `_alert_level` (0 calm / 1 warn ≥60 heat / 2 critical ≥85).

**Tech Stack:** Godot 4.6.3 GDScript, `ui_capture.ps1` still harness, headless probe scripts.

## Global Constraints

- Godot binary: `E:\Downloads\Godot_v4.6.3-stable_win64.exe` (or `$env:GODOT_BIN`).
- ART_POLICY: primitives + existing color tokens only (`GameTheme.SIREN_RED/BLUE`, `NEON_RED`, existing `city_view.gd` palette constants). No assets.
- Reactions are drawn STATE — never nodes layered over the canvas; never a wash over the sheet/balance.
- All new motion must respect `GameTheme.ui_reduced_motion()` (degrade to a static single state).
- Keep the 30 fps `REDRAW_INTERVAL` / `_dirty` discipline; no per-frame allocation.
- Headless-safe: `_draw` already exits when headless; add no node lookups.
- Windows-go-dark must NOT fire at `_alert_level == 0` (calm city stays identical at heat 0).
- Visual work has no unit tests in this repo: the test cycle is headless probes (regression) + `ui_capture.ps1` stills you actually look at.

---

### Task 1: Baseline captures + height-derived window grids + side shade

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (window-grid block inside `_draw_building_signature`, currently lines ~483–495)
- Create (uncommitted, scratch): `godot/design/shots/city_repair_spec.json`

**Interfaces:**
- Consumes: `_draw_building_signature(key, cx, ground_y, bh, tier, seed, t, breath)` — existing private draw helper; `_hash_flicker(seed, t)`, `_hash01(seed, t)` — existing hash utilities.
- Produces: the window loop that Task 3 extends with an alert-band skip. Task 3 shows the full final loop; apply Task 1 first.

- [ ] **Step 1: Capture pre-change baselines (heat 0 and 65)**

Write `godot/design/shots/city_repair_spec.json`:

```json
[
  {"shell": true, "tab": 0, "w": 720, "h": 1280, "cash": 5000000, "heat": 0,  "districts": 6, "prestige_tokens": 12, "city_tier": 3, "no_overlays": true, "out": "D:/2d_game/godot/design/shots/city_before_h0.png"},
  {"shell": true, "tab": 0, "w": 720, "h": 1280, "cash": 5000000, "heat": 65, "districts": 6, "prestige_tokens": 12, "city_tier": 3, "no_overlays": true, "out": "D:/2d_game/godot/design/shots/city_before_h65.png"}
]
```

Run (PowerShell, repo root): `.\ui_capture.ps1 -Spec godot\design\shots\city_repair_spec.json`
Expected: `{"failures":0,"jobs":2,"ok":true}`. Do not commit the JSON or PNGs (shots dir is scratch output).

- [ ] **Step 2: Replace the fixed window grid with a height-derived one + side shade**

In `_draw_building_signature`, the current block:

```gdscript
	# Neon facade trim + hash flicker windows.
	var win_rows := 1 + tier
	var win_cols := 2 + tier / 2
	for wy in win_rows:
		for wx in win_cols:
			var wseed := seed * 31 + wx * 7 + wy * 13
			if not _hash_flicker(wseed, t):
				continue
			var wxp := bx + 8.0 + wx * ((bw - 16.0) / maxf(1.0, float(win_cols - 1)))
			var wyp := by + 14.0 + wy * 16.0
			if wyp + 8.0 > ground_y - 6.0:
				continue
			draw_rect(Rect2(wxp, wyp, 7.0, 9.0), Color(neon, clampf(0.92 * breath, 0.0, 1.0)))
```

becomes:

```gdscript
	# Tall towers get a shaded edge so they read as massed volume, not slab.
	if bh > 120.0:
		draw_rect(Rect2(bx + bw * 0.8, by, bw * 0.2, bh), Color(0.0, 0.0, 0.0, 0.18))
	# Neon facade trim + hash flicker windows. Rows follow the facade's real
	# height (a fixed 1+tier left tall hero towers 80% blank wall).
	var win_rows := clampi(int((bh - 24.0) / 16.0), 1, 16)
	var win_cols := clampi(2 + tier / 2, 2, maxi(2, int(bw / 14.0)))
	for wy in win_rows:
		for wx in win_cols:
			var wseed := seed * 31 + wx * 7 + wy * 13
			if not _hash_flicker(wseed, t):
				continue
			var wxp := bx + 8.0 + wx * ((bw - 16.0) / maxf(1.0, float(win_cols - 1)))
			var wyp := by + 14.0 + wy * 16.0
			if wyp + 8.0 > ground_y - 6.0:
				continue
			draw_rect(Rect2(wxp, wyp, 7.0, 9.0), Color(neon, clampf(0.92 * breath, 0.0, 1.0)))
```

(The shade draws before the loop so lit windows punch through the shadowed edge.)

- [ ] **Step 3: Regression probes**

Run each; all must print their PASS line and exit 0:

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_alert_probe.gd
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_share_probe.gd
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_district_probe.gd
```

- [ ] **Step 4: Visual check**

Edit `city_repair_spec.json` outputs to `city_after1_h0.png` / `city_after1_h65.png`, re-run `.\ui_capture.ps1 -Spec godot\design\shots\city_repair_spec.json`, and READ both PNGs. Verify: hero tower windowed down its full height (windows stop at the ground guard, not the crown); side shade visible on towers >120 virtual px; heat-0 shot otherwise unchanged vs `city_before_h0.png`.

- [ ] **Step 5: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "fix(city): window grids scale with facade height + side shade on tall towers"
```

---

### Task 2: Attach the distant windows (back-parallax contrast)

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (`_draw_back_parallax`, currently lines ~297–368)

**Interfaces:**
- Consumes: existing constants `SILHOUETTE_BACK`, `SILHOUETTE_RIM`, `NEON_WARM`; `_hash01` / `_hash_flicker`.
- Produces: the anchor-tower beacon block that Task 3 rewrites (Task 3 shows its full final form; apply this task first).

- [ ] **Step 1: Lift far-ridge/anchor body contrast, dim their windows, rim the anchor crowns**

In `_draw_back_parallax`, change the far-ridge color line:

```gdscript
	var far_col := Color(SILHOUETTE_BACK.r * 0.8, SILHOUETTE_BACK.g * 0.8, SILHOUETTE_BACK.b * 0.85, 0.7)
```

to:

```gdscript
	var far_col := Color(SILHOUETTE_BACK.r * 1.15, SILHOUETTE_BACK.g * 1.15, SILHOUETTE_BACK.b * 1.2, 0.85)
```

Change the far-ridge window line from `Color(NEON_WARM, 0.28)` to `Color(NEON_WARM, 0.22)`:

```gdscript
			draw_rect(Rect2(fx + fw * 0.35, far_base - fh * 0.55, 2.0, 2.0), Color(NEON_WARM, 0.22))
```

In the anchor-skyscraper loop, immediately after the body rect
`draw_rect(Rect2(ax - aw * 0.5, atop, aw, far_base - atop), far_col)` add a crown rim:

```gdscript
			draw_line(Vector2(ax - aw * 0.5, atop), Vector2(ax + aw * 0.5, atop), Color(SILHOUETTE_RIM, 0.5), 1.0)
```

And change the anchor window alpha from `0.3` to `0.24`:

```gdscript
					draw_rect(Rect2(ax - aw * 0.25, atop + 10.0 + wy * 14.0, 2.0, 3.0), Color(NEON_WARM, 0.24))
```

Leave the mid-parallax silhouette windows (α 0.35) unchanged — they are nearer and already sit on visible bodies.

- [ ] **Step 2: Regression probes** — same four commands as Task 1 Step 3; all PASS.

- [ ] **Step 3: Visual check** — recapture (`city_after2_h0.png` / `city_after2_h65.png`) and READ: distant lit windows now sit on visible silhouettes; no orphaned orange squares against bare sky.

- [ ] **Step 4: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "fix(city): distant towers visible under their windows — no more floating lights"
```

---

### Task 3: Warn-band cues — urgent beacons, windows go dark, stronger crimson

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (`_draw_back_parallax` beacon block, `_draw_building_signature` window loop + crown, `_draw_atmosphere`)

**Interfaces:**
- Consumes: `_alert_level` member (0/1/2, already fed by `set_alert_level`), `GameTheme.ui_reduced_motion()`, `NEON_RED`, Task 1's window loop, Task 2's beacon block.
- Produces: final window-loop form (below) that Task 4 leaves untouched.

- [ ] **Step 1: Urgent anchor beacons at warn+**

In `_draw_back_parallax`, replace the aviation-blip block:

```gdscript
			if _hash01(a * 41 + 3, t * 1.5) > 0.5:
				draw_rect(Rect2(ax - 1.0, atop - 11.0, 2.0, 2.0), Color(NEON_RED, 0.5))
```

with:

```gdscript
			var beacon_on := _hash01(a * 41 + 3, t * 1.5) > 0.5
			if _alert_level >= 1 and not GameTheme.ui_reduced_motion():
				beacon_on = int(t * 5.0 + float(a)) % 2 == 0
			if beacon_on:
				var beacon_a := 0.5 if _alert_level == 0 else 0.9
				draw_rect(Rect2(ax - 1.0, atop - 11.0, 2.0, 2.0), Color(NEON_RED, beacon_a))
```

(Reduced motion keeps the lazy hash blink but still gets the brighter alpha at warn.)

- [ ] **Step 2: Hero-crown beacons + windows-go-dark**

In `_draw_building_signature`, the window loop (as left by Task 1) gains one skip after `wseed` — full final form:

```gdscript
	var win_rows := clampi(int((bh - 24.0) / 16.0), 1, 16)
	var win_cols := clampi(2 + tier / 2, 2, maxi(2, int(bw / 14.0)))
	for wy in win_rows:
		for wx in win_cols:
			var wseed := seed * 31 + wx * 7 + wy * 13
			if not _hash_flicker(wseed, t):
				continue
			# The city lies low when the police circle: a deterministic share of
			# windows goes dark at warn (25%) and critical (50%). Never at calm.
			if _alert_level > 0 and _hash01(wseed * 7 + 1, 0.0) < 0.25 * float(_alert_level):
				continue
			var wxp := bx + 8.0 + wx * ((bw - 16.0) / maxf(1.0, float(win_cols - 1)))
			var wyp := by + 14.0 + wy * 16.0
			if wyp + 8.0 > ground_y - 6.0:
				continue
			draw_rect(Rect2(wxp, wyp, 7.0, 9.0), Color(neon, clampf(0.92 * breath, 0.0, 1.0)))
```

Then, after the neon roof-strip line
`draw_rect(Rect2(bx, ground_y - bh - 5.0, bw, 4.0), Color(neon, 0.65 + 0.3 * sin(t * 2.0 + seed)))`, add:

```gdscript
	# Warn+: a hot aviation beacon on the crown — danger reads in a still frame.
	if _alert_level >= 1:
		var bk_on := true if GameTheme.ui_reduced_motion() else int(t * 5.0 + float(seed)) % 2 == 0
		if bk_on:
			draw_circle(Vector2(cx, ground_y - bh - 9.0), 2.0, Color(NEON_RED, 0.85))
```

- [ ] **Step 3: Stronger crimson sky at 60+ heat**

In `_draw_atmosphere`, the band draw:

```gdscript
				draw_rect(Rect2(0, band_h * frac, sw, band_h),
						Color(INK_CRIMSON.r, INK_CRIMSON.g, INK_CRIMSON.b, intensity * 0.22))
```

becomes:

```gdscript
				var band_a := 0.22 if heat < 60.0 else 0.30
				draw_rect(Rect2(0, band_h * frac, sw, band_h),
						Color(INK_CRIMSON.r, INK_CRIMSON.g, INK_CRIMSON.b, intensity * band_a))
```

- [ ] **Step 4: Regression probes** — same four commands as Task 1 Step 3; all PASS.

- [ ] **Step 5: Visual check** — recapture heat 0 AND 65 (`city_after3_h0.png` / `city_after3_h65.png`) and READ both. Verify: heat-65 shows bright fast beacons, visibly darker window coverage, stronger crimson sky; heat-0 is pixel-equivalent to `city_after2_h0.png` (calm untouched — the Global Constraint).

- [ ] **Step 6: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): warn-band heat reads in a still — urgent beacons, dark windows, hotter sky"
```

---

### Task 4: Critical rim glow + visible raid surge

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (`_draw_building_signature` rim, `_draw_raid_surge`)

**Interfaces:**
- Consumes: `GameTheme.SIREN_RED` / `GameTheme.SIREN_BLUE` tokens, `_alert_level`, `_raid_pulse`, Task 3's final window loop (untouched here).
- Produces: nothing consumed later; final task before verification.

- [ ] **Step 1: Alternating siren rim on facades at critical**

In `_draw_building_signature`, after the crown-beacon block added in Task 3 Step 2, add:

```gdscript
	# Critical: the dragnet's light catches the towers — alternating siren rim.
	if _alert_level >= 2:
		var siren := GameTheme.SIREN_RED
		if not GameTheme.ui_reduced_motion() and int(t * 4.0 + float(seed)) % 2 == 1:
			siren = GameTheme.SIREN_BLUE
		draw_rect(Rect2(bx, ground_y - bh, bw, bh), Color(siren.r, siren.g, siren.b, 0.10), false, 1.5)
```

(Reduced motion holds SIREN_RED statically — the ever-present pairing across towers still disambiguates from "loss" red, per the Session-B token validation.)

- [ ] **Step 2: Raise the raid surge above the sheet occlusion**

In `_draw_raid_surge`, change:

```gdscript
	draw_rect(Rect2(0.0, ground_y - 6.0, VIRTUAL_SIZE.x, VIRTUAL_SIZE.y - ground_y + 6.0),
			Color(col.r, col.g, col.b, 0.28 * a))
```

to:

```gdscript
	draw_rect(Rect2(0.0, ground_y - 20.0, VIRTUAL_SIZE.x, VIRTUAL_SIZE.y - ground_y + 20.0),
			Color(col.r, col.g, col.b, 0.28 * a))
```

- [ ] **Step 3: Regression probes** — same four commands as Task 1 Step 3; all PASS.

- [ ] **Step 4: Visual check** — recapture with a critical job (edit spec: `"heat": 90`, out `city_after4_h90.png`) plus heat 0; READ both. Verify: siren rims on facades + searchlights at 90; heat-0 unchanged.

- [ ] **Step 5: Commit**

```powershell
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): critical siren rims + raid surge visible above the sheet"
```

---

### Task 5: Final verification sweep

**Files:**
- Modify (scratch only): `godot/design/shots/city_repair_spec.json`

**Interfaces:**
- Consumes: all prior tasks' drawing changes.
- Produces: the spec's acceptance evidence (three final stills + probe PASSes).

- [ ] **Step 1: Full still matrix**

Set the spec to three jobs — heat 0, 65, 90 — outputs `city_final_h0.png`, `city_final_h65.png`, `city_final_h90.png` (all: tab 0, 720×1280, cash 5000000, districts 6, prestige_tokens 12, city_tier 3, no_overlays true). Run `.\ui_capture.ps1 -Spec godot\design\shots\city_repair_spec.json`; expect `"ok":true`.

- [ ] **Step 2: READ all three PNGs against the spec's acceptance list**

- Towers windowed full-height; side shade present; no blank slab.
- Distant windows attached to visible silhouettes.
- h65 unmistakably hostile vs h0 (beacons, dark windows, crimson); h90 adds siren rims + searchlights.
- h0 calm city visually equivalent to `city_before_h0.png` except the Task 1 window/shade fix.

- [ ] **Step 3: Probes + graph refresh**

Run the four probe commands (Task 1 Step 3) once more; all PASS. Then per CLAUDE.md:

```powershell
python -m graphify update .
```

- [ ] **Step 4: Clean scratch + report**

Delete `godot/design/shots/city_repair_spec.json` and the audit/interim PNGs if desired (shots dir is scratch). Report results with the three final still paths for owner review. No commit (Task 4 committed the last code change).
