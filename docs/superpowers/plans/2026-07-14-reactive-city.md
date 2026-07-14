# Reactive City Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the idle screen feel like a criminal empire by giving the city an address space — reactions land on *places* (this facade, this street, this block) instead of washing the whole screen.

**Architecture:** `city_view.gd` is an immediate-mode canvas (one `_draw()` over a 404×320 virtual space, redraw-capped at 30fps behind `_dirty`). Reactions are therefore **state the canvas draws**, never tweened nodes stacked over it. The existing `UiEvents` autoload gains three *addressed* signals; `city_view` gains a fixed reaction table; the shell surfaces (city, row, masthead) all subscribe to the same signal so one purchase is one orchestrated beat across three surfaces.

**Tech Stack:** Godot 4.6.3, GDScript. No unit-test framework — verification is **headless SceneTree probes** (`godot --headless --path godot -s res://scripts/tools/<probe>.gd`, `quit(0)` = PASS, `quit(1)` = FAIL), modelled on `godot/scripts/tools/shell_smoke.gd`.

## Global Constraints

- **No node allocation per event.** The reaction table is fixed and preallocated. Today's `flash_building()` does `ColorRect.new()` per purchase — that goes away. Manager purchase orders fire these in bursts.
- **Every reaction gates on `GameTheme.ui_reduced_motion()` and headless**, exactly as `play_raid()` / `flash_building()` do today.
- **The 30fps redraw cap (`REDRAW_INTERVAL`) stays.** We change *what* the canvas paints, not how often.
- **ART_POLICY:** code-drawn only. No generated assets.
- **Device floor:** ≥30fps on the Moto G.
- **No raw hex in shipped UI code** — `ui_validators.ps1` token-lints `shell/`, `screens/`, `components/`. (`city_view.gd` predates this and has local `Color8` constants; do **not** add new literals, and do not refactor the old ones — out of scope.)
- **Do not touch:** nav dock, the six screens' internals, IA, overlays, the palette, prestige/rank ceremonies, dragon chip, golden coin.

---

### Task 1: Addressed signals + a probe that proves they're ignored

The whole project in one finding: `buildings_screen.gd:166` **already passes the building key** to `stage_layer.flash_building()`, and `stage_layer.gd:185` declares it `_key` — unused — then fades one gold `ColorRect` over the entire screen. The address already travels; the receiver drops it. This task writes the test that proves it.

**Files:**
- Modify: `godot/scripts/ui/shell/ui_events.gd`
- Create: `godot/scripts/tools/city_reaction_probe.gd`

**Interfaces:**
- Produces: `UiEvents.building_purchased(key: String)`, `UiEvents.heat_crossed(level: int)`, `UiEvents.district_changed(idx: int, holder: String)`. Later tasks connect to these.
- Produces: probe contract — `CityView.is_facade_pulsing(key: String) -> bool` (Task 2 implements it; the probe asserts it exists).

- [ ] **Step 1: Add the three addressed signals to `UiEvents`**

Append to `godot/scripts/ui/shell/ui_events.gd` (keep the file's `##` doc-comment style — it documents every signal):

```gdscript
## A building was bought — carries WHICH one, so the city, its row, and the
## masthead can all react to the same addressed beat.
signal building_purchased(key: String)
## Heat crossed a band boundary. level: 0 calm, 1 warn (>=60), 2 critical (>=85).
signal heat_crossed(level: int)
## A district changed hands. holder: "player" | "rival" | "neutral".
signal district_changed(idx: int, holder: String)
```

- [ ] **Step 2: Write the failing probe**

Create `godot/scripts/tools/city_reaction_probe.gd`. This follows `shell_smoke.gd` exactly: install autoloads, instantiate the shell, pump frames, assert, `quit(0|1)`.

```gdscript
extends SceneTree
## Headless probe: a purchase must light THAT facade, and must not allocate a
## node to do it. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_reaction_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _shell: Node
var _city: Node
var _stage: Node
var _frames := 0
var _stage_children_before := -1


func _initialize() -> void:
	SoakAutoloads.install(self)
	var gs: Node = root.get_node("GameState")
	gs.reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	if packed == null:
		push_error("[city_probe] failed to load game_shell.tscn")
		quit(1)
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	_stage = root.find_child("StageLayer", true, false)
	_city = root.find_child("CityView", true, false)
	if _stage == null or _city == null:
		printerr("[city_probe] FAIL: StageLayer or CityView not found")
		quit(1)


func _process(_delta: float) -> bool:
	_frames += 1
	var events: Node = root.get_node_or_null("UiEvents")
	if events == null:
		return false

	if _frames == 20:
		# Own a business so it has a facade to light.
		var gs: Node = root.get_node("GameState")
		gs.balance = 1_000_000.0
		gs.buy_building(0, 1)
		gs.emit_signal("stats_changed")

	elif _frames == 40:
		if not _city.has_method("is_facade_pulsing"):
			printerr("[city_probe] FAIL: CityView has no is_facade_pulsing() — the city cannot be addressed")
			quit(1)
			return true
		_stage_children_before = _stage.get_child_count()
		var key: String = str(root.get_node("GameState").buildings[0].icon_key)
		events.emit_signal("building_purchased", key)

	elif _frames == 45:
		var key: String = str(root.get_node("GameState").buildings[0].icon_key)
		if not bool(_city.call("is_facade_pulsing", key)):
			printerr("[city_probe] FAIL: bought '%s' but its facade is not lit" % key)
			quit(1)
			return true
		if _stage.get_child_count() != _stage_children_before:
			printerr("[city_probe] FAIL: reaction allocated %d node(s) — reactions must be drawn state, not stacked nodes" % [
				_stage.get_child_count() - _stage_children_before,
			])
			quit(1)
			return true
		print("[city_probe] PASS — purchase lit its own facade, zero nodes allocated")
		quit(0)
		return true

	elif _frames >= 120:
		printerr("[city_probe] FAIL: timed out before assertions ran")
		quit(1)
		return true
	return false
```

- [ ] **Step 3: Run the probe and watch it fail**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
```

Expected: `FAIL: CityView has no is_facade_pulsing() — the city cannot be addressed`, exit 1.

- [ ] **Step 4: Commit the failing probe**

```bash
git add godot/scripts/ui/shell/ui_events.gd godot/scripts/tools/city_reaction_probe.gd
git commit -m "test(city): probe proves the city cannot be addressed

buildings_screen already passes the building key to stage_layer, which declares
it _key and ignores it, fading one gold ColorRect over the whole screen. This
probe asserts what should happen instead: the bought business's facade lights,
and no node is allocated to do it. Fails today.

Adds the three addressed UiEvents signals the fix will ride on."
```

---

### Task 2: The reaction table — `city_view` learns where things are

The address space **already exists** and nobody used it: `_draw_mid_skyline()` maps `keys[i]` → facade `i` at center `cx` with height `base_h`. We hang a decaying pulse off that mapping.

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (add state near line 45; decay in `_process` after the `REDRAW_INTERVAL` gate at line 120; draw inside `_draw_mid_skyline` at line 281)

**Interfaces:**
- Consumes: nothing.
- Produces: `CityView.pulse_facade(key: String) -> void`, `CityView.is_facade_pulsing(key: String) -> bool`.

- [ ] **Step 1: Add the reaction table state**

In `godot/scripts/ui/city_view.gd`, alongside the other `var _...` state (near line 45):

```gdscript
## How long a purchase keeps its facade lit (seconds).
const FACADE_PULSE_TIME := 1.6
## key -> remaining seconds. Reactions are drawn STATE, never stacked nodes:
## this canvas is immediate-mode, so a node layered over it cannot know where
## anything is — which is exactly how the old full-screen wash happened.
var _facade_pulse: Dictionary = {}
```

- [ ] **Step 2: Add the public API**

```gdscript
## A business was bought — light ITS facade. No-op if that business has no
## facade on screen (only the top 5 owned types get one).
func pulse_facade(key: String) -> void:
	if not _top_building_keys.has(key):
		return
	_facade_pulse[key] = FACADE_PULSE_TIME
	_dirty = true


func is_facade_pulsing(key: String) -> bool:
	return float(_facade_pulse.get(key, 0.0)) > 0.0
```

- [ ] **Step 3: Decay the table in `_process`**

In `_process()`, immediately **after** `_t += REDRAW_INTERVAL` (line ~127) and before the `animating` check. Decay by `REDRAW_INTERVAL`, not `delta` — this code only runs once the accumulator gate has passed.

```gdscript
	if not _facade_pulse.is_empty():
		for k in _facade_pulse.keys():
			var left: float = float(_facade_pulse[k]) - REDRAW_INTERVAL
			if left <= 0.0:
				_facade_pulse.erase(k)
			else:
				_facade_pulse[k] = left
		_dirty = true
```

- [ ] **Step 4: Draw the pulse at the facade's rect**

Inside `_draw_mid_skyline()`'s `for i in count:` loop, replace the existing single call at line 297:

```gdscript
		_draw_building_signature(key, cx, ground_y, base_h, tier, i, t)
```

with:

```gdscript
		_draw_building_signature(key, cx, ground_y, base_h, tier, i, t)
		var pulse: float = float(_facade_pulse.get(key, 0.0))
		if pulse > 0.0:
			_draw_facade_pulse(cx, ground_y, base_h, i, pulse)
```

Then add the draw helper next to the other `_draw_*` helpers. `bw` is recomputed exactly as `_draw_building_signature` does it (`52.0 + float(seed % 3) * 10.0`), so the glow lands on the real facade rect:

```gdscript
## The bought business's facade lights up — the empire acknowledging a purchase
## in the world, not a tint over the player's whole screen.
func _draw_facade_pulse(cx: float, ground_y: float, bh: float, seed: int, pulse: float) -> void:
	if GameTheme.ui_reduced_motion():
		return
	var a := clampf(pulse / FACADE_PULSE_TIME, 0.0, 1.0)
	var bw := 52.0 + float(seed % 3) * 10.0
	var rect := Rect2(cx - bw * 0.5, ground_y - bh, bw, bh)
	var glow := INK_GOLD_BRIGHT
	draw_rect(rect, Color(glow.r, glow.g, glow.b, 0.10 * a), true)
	draw_rect(rect, Color(glow.r, glow.g, glow.b, 0.55 * a), false, 1.5)
```

- [ ] **Step 5: Run the probe — it still fails, but further along**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
```

Expected: now gets past the `is_facade_pulsing` check and fails with `FAIL: bought '<key>' but its facade is not lit` — because nothing calls `pulse_facade()` yet. That's Task 3.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): reaction table — the city can be addressed

_draw_mid_skyline already mapped keys[i] to facade i; nothing used it. Adds a
decaying per-facade pulse table (drawn state, not stacked nodes — the canvas is
immediate-mode) plus pulse_facade()/is_facade_pulsing(). Nothing emits into it
yet."
```

---

### Task 3: Route the beat — stop washing the screen

**Files:**
- Modify: `godot/scripts/ui/shell/stage_layer.gd:184-196` (`flash_building`)
- Modify: `godot/scripts/ui/screens/buildings_screen.gd:164-166` (emit on the bus instead of calling the stage point-to-point)

**Interfaces:**
- Consumes: `UiEvents.building_purchased(key)` (Task 1), `CityView.pulse_facade(key)` (Task 2).
- Produces: `StageLayer.flash_building(key: String)` now honours its key. Signature is unchanged, so `buildings_screen`'s existing call site stays valid.

- [ ] **Step 1: Make `flash_building` use the key it was always given**

In `godot/scripts/ui/shell/stage_layer.gd`, replace the whole function (lines 184–196) — the `ColorRect.new()` full-screen wash goes away entirely:

```gdscript
## A purchase lights that business's own facade in the skyline. This used to
## fade one gold ColorRect over the ENTIRE screen and ignore its key, which is
## why every purchase felt identical and the city felt dead.
func flash_building(key: String) -> void:
	if DisplayServer.get_name() == "headless" or GameTheme.ui_reduced_motion():
		return
	if _city != null and _city.has_method("pulse_facade"):
		_city.call("pulse_facade", key)
```

- [ ] **Step 2: Subscribe the stage to the bus**

In `stage_layer.gd`'s `_ready()` (line ~23), connect so *any* purchase source drives the beat, not just the buildings screen:

```gdscript
	var events: Node = get_node_or_null("/root/UiEvents")
	if events != null:
		events.building_purchased.connect(flash_building)
```

- [ ] **Step 3: Emit on the bus from the purchase site**

In `godot/scripts/ui/screens/buildings_screen.gd`, replace the point-to-point call at lines 164–166:

```gdscript
	if stage != null and stage.has_method("flash_building"):
		stage.flash_building(GameState.buildings[index].icon_key)
```

with an emit — this is what lets the row and masthead react to the same beat in Task 4:

```gdscript
	UiEvents.building_purchased.emit(GameState.buildings[index].icon_key)
```

- [ ] **Step 4: Run the probe — it must now PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
```

Expected: `PASS — purchase lit its own facade, zero nodes allocated`, exit 0.

- [ ] **Step 5: Run the shell smoke — no regression**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
```

Expected: `[shell_smoke] PASS — 200 frames, no crash`, exit 0.

- [ ] **Step 6: Look at it — the whole point is the pixels**

```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280
```

Open the PNG. The skyline must be present and unwashed. (A still frame cannot show a 1.6s pulse; the probe is what proves the pulse. This capture proves we didn't break the city.)

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/ui/shell/stage_layer.gd godot/scripts/ui/screens/buildings_screen.gd
git commit -m "feat(city): a purchase lights its own building, not the whole screen

flash_building() ignored its key and faded a gold ColorRect over the entire
screen — every purchase, identical, undifferentiated. It now routes the key to
that facade's pulse. Purchases emit on UiEvents so the city, the row and the
masthead can share one beat. Also removes a per-purchase node allocation, which
mattered more once manager purchase orders started firing these in bursts."
```

---

### Task 4: Mesh — the row joins the beat

This is the task that makes the surfaces agree *architecturally* rather than by taste: they listen to one addressed signal.

**On the masthead:** the spec said "masthead ticks", and it already does — the balance drops through `stats_changed` on every purchase. **Do not add a second masthead flare.** A purchase would then announce itself three times, and the third announcement is noise competing with the beat rather than part of it. The masthead's existing tick *is* its share of the beat.

**Files:**
- Modify: `godot/scripts/ui/building_row.gd`

**Interfaces:**
- Consumes: `UiEvents.building_purchased(key)` (Task 1).
- Produces: nothing downstream.

- [ ] **Step 1: The row's medallion flares when its own business is bought**

In `godot/scripts/ui/building_row.gd`, in `_ready()`, subscribe and flare only if the key is *this* row's:

```gdscript
	var events: Node = get_node_or_null("/root/UiEvents")
	if events != null:
		events.building_purchased.connect(_on_any_purchase)
```

Add the handler. `_data` is this row's building; use whatever field the file already uses for its icon key (`icon_key`):

```gdscript
## Same beat as the city facade: this row's medallion acknowledges the purchase.
func _on_any_purchase(key: String) -> void:
	if _data == null or str(_data.icon_key) != key:
		return
	if GameTheme.ui_reduced_motion():
		return
	var medallion: Control = get_node_or_null("%Medallion")
	if medallion == null:
		return
	var tw := create_tween()
	tw.tween_property(medallion, "modulate", GameTheme.GOLD_BRIGHT, 0.12)
	tw.tween_property(medallion, "modulate", Color.WHITE, 0.45).set_ease(Tween.EASE_OUT)
```

If the medallion node's unique name differs, read the scene (`godot/scenes/building_row.tscn`) and use the real one — do not invent a node path.

- [ ] **Step 2: Run the shell smoke**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
```

Expected: PASS, exit 0. (The smoke pumps tabs and would surface a bad node path as a script error.)

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/ui/building_row.gd
git commit -m "feat(ui): row medallion joins the purchase beat

The row reacts to the same addressed UiEvents.building_purchased as the city
facade, so the two surfaces cannot drift — they read one event, not two
independently-styled animations."
```

---

**STAGE A ENDS HERE — and Stage A is the only part of this plan that is executable as written.**

At this point a purchase lights its own building in the skyline and flares its own row, driven by one addressed signal, with no per-event allocation, and a probe proves it. That is a coherent, shippable slice. Stop here if budget is short.

> **⚠️ Tasks 5–8 are an OUTLINE, not an executable plan.** They name the right files, interfaces, and order, but their steps describe *what* to do without showing the code — which is a plan failure by this skill's own rules, and an agent handed them would improvise. They were left as an outline deliberately rather than filled with invented code: writing them properly requires first reading `heat_system.gd`, `territory_system.gd`, `_draw_searchlights()`, `_draw_traffic()`, and `_district_slots()`, none of which have been read yet.
>
> **Before executing Task 5 or beyond, run a second planning pass** over those files to expand each step into real code. Do not hand Tasks 5–8 to a subagent in their current state.

---

### Task 5: Income share — which businesses actually carry the empire

The city receives owned *counts*, which cannot tell a Chop Shop's contribution from a Casino's. One array on the existing `refresh()` path fixes that. This is **continuous state, not a signal** — never emit it per frame.

**Files:**
- Modify: `godot/scripts/ui/shell/stage_layer.gd:75-98` (`refresh`)
- Modify: `godot/scripts/ui/city_view.gd:75` (`refresh` signature + `_draw_building_signature` call path)

**Interfaces:**
- Consumes: `GameState.buildings` (each has `income_per_second`-equivalent; use the field `buildings_screen.gd` already reads for its per-row rate).
- Produces: `CityView.refresh(..., shares: Array)` — a float per facade, 0..1, matching the existing `keys`/`counts` array order.

- [ ] **Step 1: Compute shares in `stage_layer._top_buildings()`**

Extend the returned entries with each business's share of total income. Read the real per-building income field from `game_state.gd` rather than assuming a name.

```gdscript
func _top_buildings() -> Array:
	var ranked: Array = []
	var total_ips := 0.0
	for b in GameState.buildings:
		if b.owned > 0:
			var ips: float = float(b.income_per_second) * float(b.owned)
			total_ips += ips
			ranked.append({"key": b.icon_key, "owned": b.owned, "ips": ips})
	ranked.sort_custom(func(a, b): return int(a["owned"]) > int(b["owned"]))
	if ranked.size() > 5:
		ranked = ranked.slice(0, 5)
	for e in ranked:
		e["share"] = float(e["ips"]) / total_ips if total_ips > 0.0 else 0.0
	return ranked
```

- [ ] **Step 2: Pass shares through `stage_layer.refresh()`**

In `refresh()`, build a `shares` array alongside `keys`/`counts` and append it to the existing `_city.call("refresh", ...)` argument list as the final argument.

- [ ] **Step 3: Accept and store shares in `city_view.refresh()`**

Add a trailing `shares: Array = []` parameter (defaulted, so any other caller keeps working), store it as `_top_building_shares`, and `_mark_dirty()`.

- [ ] **Step 4: Breathe each facade at its share**

In `_draw_mid_skyline()`'s loop, modulate the facade's lit-window brightness by a slow sine whose amplitude scales with that facade's share — the biggest earner visibly works hardest:

```gdscript
		var share: float = 0.0
		if i < _top_building_shares.size():
			share = float(_top_building_shares[i])
		var breath := 1.0 + sin(t * 1.4 + float(i) * 1.7) * 0.10 * share
```

Pass `breath` into `_draw_building_signature` as a new trailing parameter (default `1.0`) and multiply the lit-window alpha by it there.

- [ ] **Step 5: Verify — probe, smoke, and look**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280 -Cash 500000
```

Expected: both probes PASS; the capture shows a skyline whose windows are lit (a still cannot show breathing — you're checking nothing broke).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/ui/shell/stage_layer.gd godot/scripts/ui/city_view.gd
git commit -m "feat(city): facades breathe at their share of income

The city knew owned counts but not contribution, so a Chop Shop and a Casino
looked equally busy. Facades now breathe in proportion to their share of
income/sec — the skyline shows you which businesses actually carry the empire.
Continuous state on the existing refresh path; not a per-frame signal."
```

---

### Task 6: Heat — you are being hunted

`city_view` already has `_draw_searchlights(t, rank_idx)` and `_draw_traffic(t)`. **The motion already exists — it's gated on rank, which means nothing.** Re-point it at danger.

**Design gate:** the *look* of the patrol/siren pass should be designed via the `godot-design` skill before porting (spec §Design phase). `GameTheme.RED` (#9a4a4a) is a **ledger red — it reads as loss, not sirens** on near-black; two independent design agents concluded this without conferring. Propose a hotter alert token as a `GameTheme` amendment with rendered evidence. **Do not invent a hex literal in `city_view`.**

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (`_draw_searchlights`, `_draw_traffic`)
- Modify: `godot/scripts/ui/shell/stage_layer.gd` (`play_raid`)
- Modify: `godot/scripts/systems/heat_system.gd` (emit `heat_crossed` on band change — **emit only on a band CHANGE, never per frame**)
- Modify: `godot/scripts/ui/game_theme.gd` (new alert token, if the design earns it)

**Interfaces:**
- Consumes: `UiEvents.heat_crossed(level: int)` (Task 1).
- Produces: `CityView.set_alert_level(level: int)`.

- [ ] **Step 1: Emit `heat_crossed` from `heat_system` on band change only**

Track the last band (0 calm / 1 warn ≥60 / 2 critical ≥85) and emit `UiEvents.heat_crossed.emit(band)` only when it differs from the previous band.

- [ ] **Step 2: `city_view.set_alert_level(level)` stores the band and `_mark_dirty()`**

- [ ] **Step 3: Re-point `_draw_searchlights` from `rank_idx` to the alert level**

Searchlights sweep when hunted, not when promoted. Keep the existing sweep maths; change what turns it on.

- [ ] **Step 4: Patrol cars in `_draw_traffic`**

At level ≥1, a share of traffic becomes patrol cars (alert-token flicker on the roof); at level 2 they slow and sweep.

- [ ] **Step 5: `play_raid()` stops washing the screen**

Replace the full-screen red `ColorRect` tween with a street-level siren surge — the same structural fix as `flash_building`.

- [ ] **Step 6: Verify + commit** (probe, smoke, capture at heat 0 / 65 / 90 via `ui_capture.ps1 -Shell -Tab 0`, `ui_validators.ps1` token lint must pass)

---

### Task 7: Districts — turf you can see

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` (district block state; `_district_slots()` already feeds it)
- Modify: `godot/scripts/systems/territory_system.gd` (emit `district_changed` on capture/loss)

**Interfaces:**
- Consumes: `UiEvents.district_changed(idx, holder)` (Task 1).
- Produces: `CityView.set_district(idx: int, holder: String)`.

- [ ] **Step 1: Emit `district_changed(idx, holder)` on capture and on loss**
- [ ] **Step 2: `city_view.set_district()` stores per-block holder + a decaying transition pulse**
- [ ] **Step 3: Draw it — a block you take lights; a block a rival takes goes dark**
- [ ] **Step 4: Verify + commit** (probe, smoke, capture, token lint)

---

### Task 8: Prove it on the device

**Files:**
- Modify: `DEVICE_TEST_CHECKLIST.md`

- [ ] **Step 1: Add a "Living city" block to the checklist**

```markdown
## Living city (reactive city — new this build)

- [ ] Buy a business → **that** business's tower lights up in the skyline (not a flash over the whole screen), and **its** row medallion flares at the same moment
- [ ] Buy a different type → a **different** tower lights. Two purchases must never look identical
- [ ] Watch the skyline idle → the biggest earner visibly works hardest (windows breathe strongest on the tallest tower)
- [ ] Raise heat past 60% → **patrol cars** appear on the street; past 85% → searchlights sweep
- [ ] Take a district → **that block** lights. Lose one to a rival → it goes dark
- [ ] Config → Reduced motion ON → all of the above go still, nothing flickers
- [ ] FPS overlay stays **green ≥30** through a burst of purchases (manager purchase orders fire these rapidly)

**Fail:** any reaction that covers the whole screen, two different purchases looking the same, FPS dip during a purchase burst, or motion continuing with reduced-motion ON.
```

- [ ] **Step 2: Run the full gate**

```bash
powershell -File ui_validators.ps1
powershell -File device_pass.ps1 smoke
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/memory_soak.gd -- --seconds 300
```

Expected: token lint clean, `Smoke PASS`, soak holds the 30fps cap with no leak.

- [ ] **Step 3: Frame-time claim — prove, don't assert**

The reaction table replaces a per-purchase `ColorRect.new()`, so frame time should **improve** under purchase bursts, not regress. Confirm on the Moto G with the FPS overlay during a manager-order burst. If it regresses, the reaction table is allocating somewhere — find it.

- [ ] **Step 4: Commit**

```bash
git add DEVICE_TEST_CHECKLIST.md
git commit -m "docs(device): living-city checks for the reactive city pass"
```
