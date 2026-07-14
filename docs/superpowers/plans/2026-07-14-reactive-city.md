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

**STAGE A ENDS HERE — SHIPPED.** A purchase lights its own building in the skyline and flares its own row, driven by one addressed signal, with no per-event allocation, and `city_reaction_probe.gd` proves it. Stage A landed on `feat/active-gambling` (commits `2d33d3d`→`c7c7c66`). That is a coherent, shippable slice.

> **Stage B (Tasks 5–8) was expanded from an outline into executable code on 2026-07-14**, after reading `heat_system.gd`, `territory_system.gd`, `game_state.gd` (`_process`, `set_simulation_active`), `building.gd`, `game_theme.gd`, and the `city_view` draw helpers. Corrections the reading forced versus the original outline — read these before executing:
>
> - **Task 5:** `Building.income_per_second()` is a **method that already multiplies by `owned`** (`building.gd:40`). The outline's `b.income_per_second * b.owned` double-counted *and* referenced a field that does not exist. Corrected below.
> - **Task 6:** heat is mutated in several places per tick (`HeatSystem.update`, crew decay at `game_state.gd:431`, dragon abilities at `:434`), so band-change detection belongs in **`GameState._process`** after heat settles — not inside `HeatSystem.update`, which sees only its own delta and would miss the rest. `GameTheme` has **no** siren token; `RED` (#9a4a4a) is the sad ledger red (two design agents flagged this). A `SIREN_RED`/`SIREN_BLUE` amendment is proposed with a design-render gate.
> - **Task 7:** rivals never seize a player's *unlocked* district — `rival_claim_*` only take `unclaimed` blocks. The outline's "lose a district to a rival → it goes dark" describes a mechanic that **does not exist**. The real addressed events are **player capture** (`_seize_territory`, reached with `idx` via `perform_action`) and **rival claim** (`rival_claim_preferred`, `rival_ai.gd:83/177`). Task 8's checklist is corrected to match.
>
> Each Stage B task is TDD'd with its **own** headless probe (isolated, no shared finish-line to renumber), modelled on `city_reaction_probe.gd`. Query methods each probe asserts are named in the task's Interfaces block.

---

### Task 5: Income share — which businesses actually carry the empire

The city receives owned *counts*, which cannot tell a Chop Shop's contribution from a Casino's. One array on the existing `refresh()` path fixes that. This is **continuous state, not a signal** — never emit it per frame.

**Files:**
- Create: `godot/scripts/tools/city_share_probe.gd`
- Modify: `godot/scripts/ui/shell/stage_layer.gd` (`_top_buildings` at `:101`, `refresh` at `:75-98`)
- Modify: `godot/scripts/ui/city_view.gd` (`refresh` signature at `:75`; add `_top_building_shares` state; `_draw_mid_skyline` loop at `:281`; `_draw_building_signature` at `:320`)

**Interfaces:**
- Consumes: `GameState.buildings`. **`Building.income_per_second() -> float` is a method that already returns the type's TOTAL (`base_income * owned * income_multiplier`, `building.gd:40`) — call it, do NOT multiply by `owned` again.**
- Produces: `CityView.refresh(..., building_shares: Array = [])` — a float per facade, 0..1, in the same order as `keys`/`counts`. `CityView.income_share(key: String) -> float` (probe query).

- [ ] **Step 1: Write the failing probe**

Create `godot/scripts/tools/city_share_probe.gd`. Buys the sole earner, then asserts its share reached the city as ~1.0 and an unowned key reads 0.0.

```gdscript
extends SceneTree
## Headless probe: a business's share of income/sec reaches the city, so the
## skyline can breathe hardest on the real earner. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_share_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _city: Node
var _frames := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _city == null:
		_city = root.find_child("CityView", true, false)
	if _city == null:
		if _frames >= 10:
			printerr("[share_probe] FAIL: CityView not found")
			quit(1)
			return true
		return false

	if _frames == 20:
		var gs: Node = root.get_node("GameState")
		gs.balance = 1_000_000.0
		gs.buy_building(0, 5)
		gs.emit_signal("stats_changed")

	elif _frames == 45:
		if not _city.has_method("income_share"):
			printerr("[share_probe] FAIL: CityView has no income_share() — shares never reached the city")
			quit(1)
			return true
		var key: String = str(root.get_node("GameState").buildings[0].icon_key)
		var share: float = float(_city.call("income_share", key))
		if share < 0.99:
			printerr("[share_probe] FAIL: sole earner '%s' share = %.3f, expected ~1.0" % [key, share])
			quit(1)
			return true
		if float(_city.call("income_share", "no_such_key")) != 0.0:
			printerr("[share_probe] FAIL: unowned key must read 0.0 share")
			quit(1)
			return true
		print("[share_probe] PASS — income share reaches the city (sole earner %.3f)" % share)
		quit(0)
		return true

	elif _frames >= 120:
		printerr("[share_probe] FAIL: timed out")
		quit(1)
		return true
	return false
```

- [ ] **Step 2: Run the probe — watch it fail**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_share_probe.gd
```

Expected: `FAIL: CityView has no income_share()`, exit 1.

- [ ] **Step 3: Compute shares in `stage_layer._top_buildings()`**

Replace the whole function (`stage_layer.gd:101-111`):

```gdscript
func _top_buildings() -> Array:
	# Most-owned first; the city draws up to 5 hero facades and scales each by
	# its owned count, so the skyline keeps growing with every purchase.
	var ranked: Array = []
	var total_ips := 0.0
	for b in GameState.buildings:
		if b.owned > 0:
			var ips: float = b.income_per_second()  # already × owned (building.gd:40)
			total_ips += ips
			ranked.append({"key": b.icon_key, "owned": b.owned, "ips": ips})
	ranked.sort_custom(func(a, b): return int(a["owned"]) > int(b["owned"]))
	if ranked.size() > 5:
		ranked = ranked.slice(0, 5)
	for e in ranked:
		e["share"] = (float(e["ips"]) / total_ips) if total_ips > 0.0 else 0.0
	return ranked
```

- [ ] **Step 4: Pass shares through `stage_layer.refresh()`**

In `refresh()` (`stage_layer.gd:83-98`), build a `shares` array alongside `keys`/`counts` and append it as the final `refresh` argument:

```gdscript
	var top := _top_buildings()
	var keys: Array = []
	var counts: Array = []
	var shares: Array = []
	for entry in top:
		keys.append(str(entry["key"]))
		counts.append(int(entry["owned"]))
		shares.append(float(entry["share"]))
	_city.call(
		"refresh",
		GameState.total_buildings_owned(),
		GameState.heat,
		districts,
		GameState.lifetime_tokens,
		keys,
		_district_slots(),
		counts,
		shares,
	)
```

- [ ] **Step 5: Accept and store shares in `city_view.refresh()`**

Add the state var next to `_top_building_counts` (`city_view.gd:45`):

```gdscript
var _top_building_shares: Array = []
```

Add a trailing defaulted parameter to `refresh()` (`city_view.gd:75-83`) so every other caller keeps working, and store it. Change the signature's last line from `building_counts: Array = []` to:

```gdscript
	building_counts: Array = [],
	building_shares: Array = []
```

and store it alongside the others (after `_top_building_counts = building_counts`):

```gdscript
	_top_building_shares = building_shares
```

Add the probe query method (next to `is_facade_pulsing`):

```gdscript
func income_share(key: String) -> float:
	var idx := _top_building_keys.find(key)
	if idx < 0 or idx >= _top_building_shares.size():
		return 0.0
	return float(_top_building_shares[idx])
```

- [ ] **Step 6: Breathe each facade at its share**

In `_draw_mid_skyline()`'s loop, the Task 2 pulse block currently reads:

```gdscript
		_draw_building_signature(key, cx, ground_y, base_h, tier, i, t)
		var pulse: float = float(_facade_pulse.get(key, 0.0))
		if pulse > 0.0:
			_draw_facade_pulse(cx, ground_y, base_h, i, pulse)
```

Compute a share-scaled breath and pass it in (reduced-motion freezes it at 1.0):

```gdscript
		var breath := 1.0
		if not GameTheme.ui_reduced_motion():
			var share: float = float(_top_building_shares[i]) if i < _top_building_shares.size() else 0.0
			breath = 1.0 + sin(t * 1.4 + float(i) * 1.7) * 0.10 * share
		_draw_building_signature(key, cx, ground_y, base_h, tier, i, t, breath)
		var pulse: float = float(_facade_pulse.get(key, 0.0))
		if pulse > 0.0:
			_draw_facade_pulse(cx, ground_y, base_h, i, pulse)
```

Add the `breath` parameter to `_draw_building_signature` (`city_view.gd:320-321`), defaulted so nothing else breaks:

```gdscript
func _draw_building_signature(key: String, cx: float, ground_y: float, bh: float,
		tier: int, seed: int, t: float, breath: float = 1.0) -> void:
```

and multiply the lit-window alpha by it. Change the window draw (`city_view.gd:391`) from `Color(neon, 0.92)` to:

```gdscript
				draw_rect(Rect2(wxp, wyp, 7.0, 9.0), Color(neon, clampf(0.92 * breath, 0.0, 1.0)))
```

- [ ] **Step 7: Run the share probe — it must PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_share_probe.gd
```

Expected: `PASS — income share reaches the city`, exit 0.

- [ ] **Step 8: Regression — facade probe + smoke + look**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280
```

Expected: both PASS; the capture shows a skyline with lit windows (a still cannot show breathing — you're checking nothing broke).

- [ ] **Step 9: Commit**

```bash
git add godot/scripts/tools/city_share_probe.gd godot/scripts/ui/shell/stage_layer.gd godot/scripts/ui/city_view.gd
git commit -m "feat(city): facades breathe at their share of income

The city knew owned counts but not contribution, so a Chop Shop and a Casino
looked equally busy. Facades now breathe in proportion to their share of
income/sec — the skyline shows you which businesses actually carry the empire.
Continuous state on the existing refresh path; not a per-frame signal.
income_per_second() already includes owned (building.gd:40) — no re-multiply."
```

---

### Task 6: Heat — you are being hunted

`city_view` already has `_draw_searchlights(t, rank_idx)` and `_draw_traffic(ground_y, t)`. **The motion already exists — it's gated on rank, which means nothing.** Re-point it at danger.

**Emission chokepoint (corrected from the outline):** heat is mutated by `HeatSystem.update`, then again by crew decay (`game_state.gd:431`) and dragon abilities (`:434`) within the same tick. Detecting the band change *inside* `HeatSystem.update` would see only its own delta and miss the rest, and could double-fire. So `HeatSystem` gains a pure `heat_band()` classifier, and the **emit lives at the end of `GameState._process`**, after heat has settled for the tick.

**Design gate (spec §Design phase):** `GameTheme.RED` (#9a4a4a) is a **ledger red — it reads as loss, not sirens** on near-black; two independent design agents concluded this without conferring. Step 1 designs the hunted-city look via `godot-design` and validates a hotter alert token with rendered evidence. **Do not invent a hex literal in `city_view`** — reference `GameTheme.SIREN_*`.

**Files:**
- Create: `godot/scripts/tools/city_alert_probe.gd`
- Modify: `godot/scripts/ui/game_theme.gd` (add `SIREN_RED` / `SIREN_BLUE` near `RED` at `:18`)
- Modify: `godot/scripts/systems/heat_system.gd` (add `heat_band()`)
- Modify: `godot/scripts/autoload/game_state.gd` (`_heat_band` field; init in `set_simulation_active` at `:223`; emit at end of `_process` at `:388`)
- Modify: `godot/scripts/ui/city_view.gd` (`_alert_level` state; `set_alert_level`/`alert_level`; `_draw` calls at `:159`/`:167`; `_draw_searchlights` at `:573`; `_draw_traffic` at `:522`; raid surge)
- Modify: `godot/scripts/ui/shell/stage_layer.gd` (subscribe `heat_crossed`; rewrite `play_raid` at `:176`; drop `_raid_flash` field at `:15` + its `_ready` block at `:40-44`)

**Interfaces:**
- Consumes: `UiEvents.heat_crossed(level: int)` (Task 1). `Building` unaffected.
- Produces: `HeatSystem.heat_band(h: float) -> int`; `CityView.set_alert_level(level: int)`, `CityView.alert_level() -> int` (probe query), `CityView.play_raid_flash()`.

- [ ] **Step 1: Design the hunted-city look + validate the alert token (design gate)**

Use the `godot-design` skill. Build a design scene that renders the real `city_view` with `set_alert_level(0/1/2)` forced and `play_raid_flash()` fired, at 720×1280 and 1080×1920. Critique ≥2 rounds against the near-black palette; the token must read as *sirens*, not loss, and must not muddy into `NEON_RED` (#dc3c46) already used for aviation blips. Land on concrete values. Proposed starting point (validate/adjust in the design loop):

```gdscript
## Reactive-city alert tokens (spec §Open). RED (#9a4a4a) reads as ledger loss on
## near-black, not sirens — two design agents flagged this. These are the hot
## siren pair for the hunted city; distinct from NEON_RED aviation blips.
const SIREN_RED := Color("ff3b30")
const SIREN_BLUE := Color("2b6bff")
```

Add them to `game_theme.gd` immediately after `const RED := Color("9a4a4a")` (`:18`). (Tokens are *defined* here — hex is allowed in `game_theme.gd`; `ui_validators.ps1` only forbids raw hex in `shell/`, `screens/`, `components/`.)

- [ ] **Step 2: Write the failing probe**

Create `godot/scripts/tools/city_alert_probe.gd`. Proves three things: the band classifier emits `heat_crossed` on a *change*, never per frame; the city stores the level; and no node is allocated for it.

```gdscript
extends SceneTree
## Headless probe: crossing a heat band emits heat_crossed ONCE (not per frame),
## and the city stores the alert level with zero node allocation. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_alert_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _city: Node
var _stage: Node
var _frames := 0
var _last_level := -99
var _emit_count := 0
var _spam_baseline := -1
var _stage_baseline := -1


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())
	root.get_node("UiEvents").heat_crossed.connect(_on_heat_crossed)


func _on_heat_crossed(level: int) -> void:
	_last_level = level
	_emit_count += 1


func _fail(msg: String) -> bool:
	printerr("[alert_probe] FAIL: " + msg)
	quit(1)
	return true


func _process(_delta: float) -> bool:
	_frames += 1
	if _city == null:
		_city = root.find_child("CityView", true, false)
		_stage = root.find_child("StageLayer", true, false)
	if _city == null or _stage == null:
		if _frames >= 10:
			return _fail("StageLayer or CityView not found")
		return false
	var gs: Node = root.get_node("GameState")

	if _frames == 18:
		# Baseline BEFORE any alert activity, so the no-alloc check has meaning.
		_stage_baseline = _stage.get_child_count()
	elif _frames == 20:
		if not _city.has_method("alert_level"):
			return _fail("CityView has no alert_level() — heat cannot address the city")
		gs.heat = 75.0  # -> band 1; a raid drops 15 to 60, still band 1 (raid-proof)
	elif _frames == 24:
		if _last_level != 1:
			return _fail("crossing to warn heat did not emit heat_crossed(1); last=%d" % _last_level)
		if int(_city.call("alert_level")) != 1:
			return _fail("city alert_level != 1 after warn crossing")
		gs.heat = 100.0  # -> band 2; a raid drops to 85, still band 2 (raid-proof)
	elif _frames == 26:
		if _last_level != 2:
			return _fail("crossing to critical heat did not emit heat_crossed(2); last=%d" % _last_level)
		gs.heat = 5.0  # -> band 0 (calm); no raids possible below 60
	elif _frames == 30:
		if _last_level != 0:
			return _fail("dropping to calm heat did not emit heat_crossed(0); last=%d" % _last_level)
		_spam_baseline = _emit_count  # heat now stable at band 0
	elif _frames == 70:
		# Band unchanged for 40 frames: not a single extra emit may have fired.
		if _emit_count != _spam_baseline:
			return _fail("heat_crossed fired %d extra time(s) with no band change — must emit on CHANGE only" % (_emit_count - _spam_baseline))
		if _stage.get_child_count() != _stage_baseline:
			return _fail("alert reaction allocated a node — must be drawn state")
		print("[alert_probe] PASS — band crossings emit once each, city stores the level, zero nodes")
		quit(0)
		return true
	elif _frames >= 120:
		return _fail("timed out")
	return false
```

- [ ] **Step 3: Run the probe — watch it fail**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_alert_probe.gd
```

Expected: `FAIL: CityView has no alert_level()`, exit 1.

- [ ] **Step 4: Add the `heat_band()` classifier to `HeatSystem`**

In `godot/scripts/systems/heat_system.gd`, after `heat_click_mult` (`:31`):

```gdscript
## Danger band for the reactive city: 0 calm, 1 warn (>=60, raids begin),
## 2 critical (>=85). RAID_THRESHOLD is 60.
static func heat_band(h: float) -> int:
	if h >= 85.0:
		return 2
	if h >= RAID_THRESHOLD:
		return 1
	return 0
```

- [ ] **Step 5: Emit `heat_crossed` from `GameState._process`, on change only**

Add the runtime field next to the other `GameState` state vars:

```gdscript
var _heat_band: int = 0
```

Sync it when the sim starts so a loaded high-heat save doesn't spuriously fire. In `set_simulation_active(active)` (`:223`), when `active` is true:

```gdscript
	if active:
		_heat_band = HeatSystem.heat_band(heat)
```

Add as the **final statement of `_process(delta)`** (after every existing line, so heat has settled for the tick):

```gdscript
	var band: int = HeatSystem.heat_band(heat)
	if band != _heat_band:
		_heat_band = band
		UiEvents.heat_crossed.emit(band)
```

- [ ] **Step 6: City receiver — `set_alert_level` / `alert_level`**

In `city_view.gd`, add state next to `_alert_level`'s neighbours (`:43`, by `_rank_idx`):

```gdscript
var _alert_level: int = 0
var _raid_pulse: float = 0.0
```

Add the API next to `is_facade_pulsing`:

```gdscript
func set_alert_level(level: int) -> void:
	if _alert_level == level:
		return
	_alert_level = level
	_dirty = true


func alert_level() -> int:
	return _alert_level


## A raid hits the street — a hot siren surge low in the frame, not a wash over
## the player's balance. Decays in _process like the facade pulses.
func play_raid_flash() -> void:
	if GameTheme.ui_reduced_motion():
		return
	_raid_pulse = 1.0
	_dirty = true
```

Decay `_raid_pulse` in `_process`, in the same block that decays `_facade_pulse` (right after the facade-decay loop added in Task 2):

```gdscript
	if _raid_pulse > 0.0:
		_raid_pulse = maxf(0.0, _raid_pulse - REDRAW_INTERVAL)
		_dirty = true
```

- [ ] **Step 7: Re-point searchlights + traffic at the alert level; draw the raid surge**

In `_draw()`, change the two call sites (`:159`, `:167`):

```gdscript
	_draw_searchlights(_t, _alert_level)
```
```gdscript
	_draw_traffic(ground_y, _t, _alert_level)
```

and, immediately after the `_draw_traffic(...)` line, add:

```gdscript
	if _raid_pulse > 0.0:
		_draw_raid_surge(ground_y)
```

Rewrite `_draw_searchlights` (`:573-587`) — hunted, not promoted; cold police beam in `SIREN_BLUE`:

```gdscript
func _draw_searchlights(t: float, alert_level: int) -> void:
	# Sweeping police beams once they're actively hunting you (critical heat).
	if alert_level < 2 or GameTheme.ui_reduced_motion():
		return
	var sw := VIRTUAL_SIZE.x
	var base_y := VIRTUAL_SIZE.y * 0.56
	var beam := GameTheme.SIREN_BLUE
	for i in 2:
		var ox := sw * (0.26 + 0.48 * float(i))
		var ang := -PI * 0.5 + sin(t * 0.5 + float(i) * 2.1) * 0.55
		var length := VIRTUAL_SIZE.y * 0.6
		var tip := Vector2(ox + cos(ang) * length, base_y + sin(ang) * length)
		draw_colored_polygon(PackedVector2Array([
			Vector2(ox - 6.0, base_y), Vector2(ox + 6.0, base_y), tip,
		]), Color(beam.r, beam.g, beam.b, 0.07))
		draw_circle(Vector2(ox, base_y), 3.0, Color(beam.r, beam.g, beam.b, 0.45))
```

Rewrite `_draw_traffic` (`:522-541`) — one lane becomes a cruiser when hunted, slowing at critical:

```gdscript
func _draw_traffic(ground_y: float, t: float, alert_level: int = 0) -> void:
	# Headlight streaks crossing the foreground street — the city is awake.
	if GameTheme.ui_reduced_motion():
		return
	var sw := VIRTUAL_SIZE.x
	for i in 2:
		var patrol := alert_level >= 1 and i == 0
		var dir := 1.0 if i == 0 else -1.0
		var speed := 64.0 + float(i) * 28.0
		if patrol and alert_level >= 2:
			speed *= 0.6  # they slow and sweep at critical
		var span := sw + 48.0
		var prog := fmod(t * speed + float(i) * 150.0, span)
		var cx: float = (prog - 24.0) if dir > 0.0 else (sw + 24.0 - prog)
		var cy := ground_y + 14.0 + float(i) * 6.0
		draw_rect(Rect2(cx - 7.0, cy - 3.0, 14.0, 5.0), Color8(28, 30, 44))
		if patrol:
			var bar := GameTheme.SIREN_RED if int(t * 6.0) % 2 == 0 else GameTheme.SIREN_BLUE
			draw_rect(Rect2(cx - 3.0, cy - 6.0, 6.0, 3.0), bar)
			draw_circle(Vector2(cx, cy - 5.0), 5.0, Color(bar.r, bar.g, bar.b, 0.25))
		var lead := cx + dir * 7.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(lead, cy - 1.0), Vector2(lead + dir * 20.0, cy - 3.5),
			Vector2(lead + dir * 20.0, cy + 3.5),
		]), Color(1.0, 0.92, 0.6, 0.10))
		draw_circle(Vector2(lead, cy), 2.4, Color(1.0, 0.94, 0.66, 0.55))
		draw_circle(Vector2(cx - dir * 7.0, cy), 1.5, Color(0.92, 0.22, 0.2, 0.6))
```

Add the raid-surge helper next to `_draw_traffic`:

```gdscript
## Street-level raid surge — hot siren red below the ground line only, never a
## tint over the player's whole screen (the flash_building fix, applied to raids).
func _draw_raid_surge(ground_y: float) -> void:
	var a := clampf(_raid_pulse, 0.0, 1.0)
	var col := GameTheme.SIREN_RED
	draw_rect(Rect2(0.0, ground_y - 6.0, VIRTUAL_SIZE.x, VIRTUAL_SIZE.y - ground_y + 6.0),
			Color(col.r, col.g, col.b, 0.28 * a))
```

- [ ] **Step 8: Route the beat + kill the full-screen raid wash in `stage_layer`**

In `stage_layer._ready()`, next to the `building_purchased` connect from Task 3:

```gdscript
		events.heat_crossed.connect(_on_heat_crossed)
```

Add the forwarder (state, so no headless guard — mirrors `set_alert_level` being pure state):

```gdscript
func _on_heat_crossed(level: int) -> void:
	if _city != null and _city.has_method("set_alert_level"):
		_city.call("set_alert_level", level)
```

Delete the `var _raid_flash: ColorRect` field (`:15`) and its construction block in `_ready` (`:40-44`, the five `_raid_flash` lines). Rewrite `play_raid` (`:176-181`) — the structural twin of the `flash_building` fix:

```gdscript
## Raid takeover: a street-level siren surge in the city, not a crimson wash over
## the whole stage. The rail still carries the text.
func play_raid() -> void:
	if DisplayServer.get_name() == "headless" or GameTheme.ui_reduced_motion():
		return
	if _city != null and _city.has_method("play_raid_flash"):
		_city.call("play_raid_flash")
```

- [ ] **Step 9: Run the alert probe — it must PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_alert_probe.gd
```

Expected: `PASS — band crossings emit once each, city stores the level, zero nodes`, exit 0.

- [ ] **Step 10: Regression — all probes, smoke, token lint**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_share_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
powershell -File ui_validators.ps1
```

Expected: all probes PASS, smoke PASS, token lint clean. (The *look* was validated in Step 1's design gate — `ui_capture.ps1` has no `-Heat` flag, so the design scene is where the hunted city is eyeballed.)

- [ ] **Step 11: Commit**

```bash
git add godot/scripts/tools/city_alert_probe.gd godot/scripts/ui/game_theme.gd godot/scripts/systems/heat_system.gd godot/scripts/autoload/game_state.gd godot/scripts/ui/city_view.gd godot/scripts/ui/shell/stage_layer.gd
git commit -m "feat(city): heat turns the street hostile — you are being hunted

Crossing a heat band (>=60 warn, >=85 critical) now emits heat_crossed once, from
GameState._process after heat settles (not from HeatSystem.update, which sees only
its own delta). The city puts a cruiser on the street at warn and sweeps police
searchlights at critical; play_raid becomes a street-level siren surge instead of
a full-screen red wash. New SIREN_RED/SIREN_BLUE tokens (RED #9a4a4a read as loss,
not sirens). Searchlights were gated on RANK — meaningless; now gated on danger."
```

---

### Task 7: Districts — turf you can see

The district strip (`_draw_district_strip`, fed by `stage_layer._district_slots()`) already colours *unlocked* blocks and leaves the rest dark — so a rival-held (unclaimed) block is dark at rest already. What's missing is the **transition beat**: a block flashes gold the moment you take it, red the moment a rival claims one. Strip slot index `i` maps 1:1 to territory index `i` for the first 12 (`_district_slots` iterates `mini(territories.size(), 12)` in order), so the addressed `idx` is the territory index.

**Corrected from the outline:** rivals never seize a player's *unlocked* district — `rival_claim_unclaimed`/`rival_claim_preferred` only take `unclaimed` blocks (`territory_system.gd:171,181`). So the two real events are **player capture** (`_seize_territory`, reached with `idx` in `perform_action`) and **rival claim**. There is no "player loses an owned block to a rival" path to wire.

**Design phase (spec §Design):** the "dark-block" look is the lightest of the spec's three — it reuses the existing district strip geometry and only adds a gold/red flash border+fill on transition, in already-approved tokens (`INK_GOLD_BRIGHT`, and `SIREN_RED` validated in Task 6). A full `godot-design` round is optional here; if the flash reads weak against the strip at 720×1280, design it then. (Facade-light shipped in Stage A; patrol-street is Task 6's gate.)

**Files:**
- Create: `godot/scripts/tools/city_district_probe.gd`
- Modify: `godot/scripts/systems/territory_system.gd` (`_seize_territory` at `:466` + its 4 callers at `:417,433,441,455`; `rival_claim_unclaimed` at `:171`; `rival_claim_preferred` at `:181`)
- Modify: `godot/scripts/ui/city_view.gd` (district pulse state; `set_district`/`is_district_pulsing`; decay in `_process`; draw in `_draw_district_strip` at `:599`)
- Modify: `godot/scripts/ui/shell/stage_layer.gd` (subscribe `district_changed`)

**Interfaces:**
- Consumes: `UiEvents.district_changed(idx, holder)` (Task 1); `GameTheme.SIREN_RED` (Task 6).
- Produces: `CityView.set_district(idx: int, holder: String)`, `CityView.is_district_pulsing(idx: int) -> bool` (probe query).

- [ ] **Step 1: Write the failing probe**

Create `godot/scripts/tools/city_district_probe.gd`. Tests the city receiver (both holders, zero alloc), the deterministic rival-claim emitter, and the player-capture emitter (bounded negotiate loop — no rng-flakiness at 200 tries).

```gdscript
extends SceneTree
## Headless probe: a district changing hands emits district_changed(idx, holder)
## and the city flashes THAT block, zero nodes allocated. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_district_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _city: Node
var _stage: Node
var _frames := 0
var _last_idx := -1
var _last_holder := ""
var _stage_baseline := -1


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())
	root.get_node("UiEvents").district_changed.connect(_on_district_changed)


func _on_district_changed(idx: int, holder: String) -> void:
	_last_idx = idx
	_last_holder = holder


func _fail(msg: String) -> bool:
	printerr("[district_probe] FAIL: " + msg)
	quit(1)
	return true


func _process(_delta: float) -> bool:
	_frames += 1
	if _city == null:
		_city = root.find_child("CityView", true, false)
		_stage = root.find_child("StageLayer", true, false)
	if _city == null or _stage == null:
		if _frames >= 10:
			return _fail("StageLayer or CityView not found")
		return false
	var gs: Node = root.get_node("GameState")
	var events: Node = root.get_node("UiEvents")

	if _frames == 20:
		if not _city.has_method("is_district_pulsing"):
			return _fail("CityView has no is_district_pulsing() — turf cannot be addressed")
		_stage_baseline = _stage.get_child_count()
		events.district_changed.emit(3, "player")
		events.district_changed.emit(4, "rival")
	elif _frames == 24:
		if not bool(_city.call("is_district_pulsing", 3)):
			return _fail("player block 3 not pulsing after emit")
		if not bool(_city.call("is_district_pulsing", 4)):
			return _fail("rival block 4 not pulsing after emit")
		if _stage.get_child_count() != _stage_baseline:
			return _fail("district reaction allocated a node — must be drawn state")
	elif _frames == 30:
		# Deterministic rival-claim emitter (no rng).
		_last_holder = ""
		TerritorySystem.rival_claim_preferred(gs.territories, "TestRival")
		if _last_holder != "rival":
			return _fail("rival_claim_preferred did not emit district_changed(_, 'rival')")
		if str(gs.territories[_last_idx].get("owner", "")) != "TestRival":
			return _fail("claimed block %d owner is not TestRival" % _last_idx)
	elif _frames == 36:
		# Player-capture emitter via _seize_territory (bounded to kill rng flake).
		gs.prestige_tokens = 1000
		_last_holder = ""
		var rng := RandomNumberGenerator.new()
		var ok := false
		for _attempt in 200:
			if bool(gs.territories[5].get("unlocked", false)):
				ok = true
				break
			TerritorySystem.perform_action(gs, 5, "negotiate", rng)
		if not ok:
			return _fail("could not capture district 5 in 200 negotiate attempts")
		if _last_holder != "player" or _last_idx != 5:
			return _fail("player capture emitted (%d, '%s'), expected (5, 'player')" % [_last_idx, _last_holder])
		print("[district_probe] PASS — captures and claims flash their own block, zero nodes")
		quit(0)
		return true
	elif _frames >= 120:
		return _fail("timed out")
	return false
```

- [ ] **Step 2: Run the probe — watch it fail**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_district_probe.gd
```

Expected: `FAIL: CityView has no is_district_pulsing()`, exit 1.

- [ ] **Step 3: City receiver — `set_district` + decaying pulse**

In `city_view.gd`, add state next to `_facade_pulse` (`:45` area):

```gdscript
## How long a captured/claimed block stays flashing (seconds).
const DISTRICT_PULSE_TIME := 1.4
## territory idx -> {"t": seconds_left, "holder": String}. Drawn state, like the
## facade pulses — never a node stacked over the immediate-mode canvas.
var _district_pulse: Dictionary = {}
```

Add the API next to `is_facade_pulsing`:

```gdscript
func set_district(idx: int, holder: String) -> void:
	_district_pulse[idx] = {"t": DISTRICT_PULSE_TIME, "holder": holder}
	_dirty = true


func is_district_pulsing(idx: int) -> bool:
	return _district_pulse.has(idx) and float(_district_pulse[idx].get("t", 0.0)) > 0.0
```

Decay it in `_process`, in the same block that decays `_facade_pulse`:

```gdscript
	if not _district_pulse.is_empty():
		for k in _district_pulse.keys():
			var left: float = float(_district_pulse[k]["t"]) - REDRAW_INTERVAL
			if left <= 0.0:
				_district_pulse.erase(k)
			else:
				_district_pulse[k]["t"] = left
		_dirty = true
```

- [ ] **Step 4: Draw the transition flash on the block**

In `_draw_district_strip()`'s `for i in count:` loop (`city_view.gd:607`), after the existing block is drawn (i.e. at the end of the loop body), overlay the pulse — gold for a block you took, `SIREN_RED` for one a rival took:

```gdscript
		if _district_pulse.has(i):
			var dp: float = float(_district_pulse[i]["t"])
			if dp > 0.0:
				var holder := str(_district_pulse[i]["holder"])
				var fc := GameTheme.SIREN_RED if holder == "rival" else INK_GOLD_BRIGHT
				var da := clampf(dp / DISTRICT_PULSE_TIME, 0.0, 1.0)
				draw_rect(Rect2(bx, by, block_w, 12.0), Color(fc.r, fc.g, fc.b, 0.18 * da), true)
				draw_rect(Rect2(bx, by, block_w, 12.0), Color(fc.r, fc.g, fc.b, 0.55 * da), false, 1.5)
```

- [ ] **Step 5: Subscribe the stage to `district_changed`**

In `stage_layer._ready()`, next to the other two `events.*.connect(...)` lines:

```gdscript
		events.district_changed.connect(_on_district_changed)
```

Add the forwarder (state, no headless guard):

```gdscript
func _on_district_changed(idx: int, holder: String) -> void:
	if _city != null and _city.has_method("set_district"):
		_city.call("set_district", idx, holder)
```

- [ ] **Step 6: Emit on player capture**

In `territory_system.gd`, change `_seize_territory` (`:466`) to take the index and emit:

```gdscript
static func _seize_territory(state, idx: int, t: Dictionary) -> void:
	t["unlocked"] = true
	t["owner"] = "player"
	t["contested"] = false
	state.total_territories_captured += 1
	_DragonSystem.on_territory_captured(state)
	UiEvents.district_changed.emit(idx, "player")
```

Update its four call sites inside `perform_action` (`:417,433,441,455`) — each is in scope of that function's `idx` parameter — from `_seize_territory(state, t)` to:

```gdscript
			_seize_territory(state, idx, t)
```

- [ ] **Step 7: Emit on rival claim**

Rewrite `rival_claim_unclaimed` (`:171`) to iterate by index and emit:

```gdscript
static func rival_claim_unclaimed(territories: Array, rival_name: String) -> String:
	for i in territories.size():
		var t = territories[i]
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "unclaimed")) == "unclaimed" and not bool(t.get("unlocked", false)):
			t["owner"] = rival_name
			UiEvents.district_changed.emit(i, "rival")
			return str(t.get("name", ""))
	return ""
```

Rewrite `rival_claim_preferred` (`:181-204`) to resolve the picked index and emit:

```gdscript
static func rival_claim_preferred(
	territories: Array,
	rival_name: String,
	preferred_names: Array = [],
	preferred_types: Array = [],
) -> String:
	var unclaimed: Array = []  # indices into territories
	for i in territories.size():
		var t = territories[i]
		if typeof(t) != TYPE_DICTIONARY:
			continue
		if str(t.get("owner", "unclaimed")) == "unclaimed" and not bool(t.get("unlocked", false)):
			unclaimed.append(i)
	if unclaimed.is_empty():
		return ""
	var pick := -1
	for i in unclaimed:
		if str(territories[i].get("name", "")) in preferred_names:
			pick = i
			break
	if pick < 0:
		for i in unclaimed:
			if str(territories[i].get("district_type", "")) in preferred_types:
				pick = i
				break
	if pick < 0:
		pick = int(unclaimed[0])
	territories[pick]["owner"] = rival_name
	UiEvents.district_changed.emit(pick, "rival")
	return str(territories[pick].get("name", ""))
```

- [ ] **Step 8: Run the district probe — it must PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_district_probe.gd
```

Expected: `PASS — captures and claims flash their own block, zero nodes`, exit 0.

- [ ] **Step 9: Regression — all probes, smoke, token lint, look**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_share_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_alert_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
powershell -File ui_validators.ps1
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280
```

Expected: all probes PASS, smoke PASS, token lint clean, capture shows the district strip present (a still cannot show a 1.4s flash — the probe proves the flash).

- [ ] **Step 10: Commit**

```bash
git add godot/scripts/tools/city_district_probe.gd godot/scripts/systems/territory_system.gd godot/scripts/ui/city_view.gd godot/scripts/ui/shell/stage_layer.gd
git commit -m "feat(city): turf you can see — a block flashes when it changes hands

Taking a district flashes its block gold; a rival claiming one flashes it red,
both driven by the addressed UiEvents.district_changed(idx, holder). Emitted from
the two real ownership mutations — _seize_territory (player) and rival_claim_*
(rival); rivals never take an unlocked block, so there is no phantom 'loss' path.
Drawn state on the existing district strip, zero node allocation."
```

---

### Task 8: Prove it on the device

**Files:**
- Modify: `DEVICE_TEST_CHECKLIST.md`

- [ ] **Step 1: Add a "Living city" block to the checklist**

Append to `DEVICE_TEST_CHECKLIST.md`. Note the district line matches the real mechanic (Task 7): rivals claim *unclaimed* blocks, they never seize your unlocked turf.

```markdown
## Living city (reactive city — new this build)

- [ ] Buy a business → **that** business's tower lights up in the skyline (not a flash over the whole screen), and **its** row medallion flares at the same moment
- [ ] Buy a different type → a **different** tower lights. Two purchases must never look identical
- [ ] Watch the skyline idle → the biggest earner visibly works hardest (windows breathe strongest on the facade carrying the most income/sec)
- [ ] Raise heat to ≥60% → a **patrol cruiser** (red/blue roof bar) appears on the street; ≥85% → police **searchlights sweep** the sky
- [ ] Trigger a police raid → a **street-level red siren surge** (below the skyline), NOT a red wash over your balance
- [ ] Capture a district → **that block flashes gold** in the strip. A rival claiming an unclaimed district → **that block flashes red**
- [ ] Config → Reduced motion ON → all of the above go still, nothing flickers
- [ ] FPS overlay stays **green ≥30** through a burst of purchases (manager purchase orders fire these rapidly)

**Fail:** any reaction that covers the whole screen, two different purchases looking the same, FPS dip during a purchase burst, or motion continuing with reduced-motion ON.
```

- [ ] **Step 2: Run the full headless gate**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_share_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_alert_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/city_district_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
powershell -File ui_validators.ps1
powershell -File device_pass.ps1 smoke
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/memory_soak.gd -- --seconds 300
```

Expected: all four city probes + smoke PASS, token lint clean, `Smoke PASS`, soak holds the 30fps cap with no leak. (If `memory_soak.gd` is absent, use the existing `sim_godot_soak.py` soak harness instead.)

- [ ] **Step 3: Frame-time claim — prove, don't assert**

The reaction table replaces a per-purchase `ColorRect.new()` (Task 3) and a per-raid one (Task 6), so frame time should **improve** under purchase/raid bursts, not regress. Confirm on the Moto G with the FPS overlay during a manager-order burst and a raid. If it regresses, a reaction is allocating somewhere — the probes assert zero stage-child growth, so look in the draw path.

- [ ] **Step 4: Commit**

```bash
git add DEVICE_TEST_CHECKLIST.md
git commit -m "docs(device): living-city checks for the reactive city pass"
```
