# Device pass results

> **Re-pass 2026-07-30 supersedes the P0 section below.** All three P0s have
> moved: FPS measured **40–48 idle** (not 12–20), the prestige CTA shipped
> (`4769cb3`), and the gate went 50M → 120M (`b34b8cb`). The 07-27 record is
> kept intact underneath as the baseline that motivated those fixes.
> Jump to: [Re-pass 2026-07-30](#re-pass-2026-07-30).

---

## Baseline pass — 2026-07-27

**Device:** moto g (2026) · MediaTek MT6835 (Dimensity 6300, Mali-G57 MC2) · Android 16
**Build:** debug APK, Godot 4.6.3, `gl_compatibility`
**Automated smoke:** PASS (deck bounds 3 viewports, soak 30s, income parity 4 fixtures)
**Verdict:** **FAIL** — 3 P0 blockers (perf, prestige discoverability, first-prestige pacing)

Save pulled from device (`adb shell run-as … cat files/save.json`) after a 19-minute
fresh run — numbers below are measured, not estimated.

| Field | Value |
|---|---|
| `play_time` | 1140s (19 min) |
| `prestige_route_earnings` | **126,272,513** |
| gate required (`FIRST_PRESTIGE_EARNINGS`) | **50,000,000** |
| `prestige_count` | 0 |
| `prestige_tokens` / `lifetime_tokens` | 16 / 16 |
| `balance` / `lifetime_earnings` | 31.2M / 139.9M |
| buildings owned | `[48,22,36,19,16,14,1,0,0,0,0]` (156 total) |
| managers owned | 6 of 13 |
| upgrades purchased | **0** |
| `total_territories_captured` | 0 |
| `heat` | 52.1 |

---

## What passed

- **Noir fantasy reads.** City grows, towers get taller as businesses are bought. Owner: "I like how the fantasy feels."
- **Per-business city reaction works.** Buying a business lights *that* facade; a different business lights a different one. Stage A/B of the reactive-city work is confirmed on hardware.
- **Golden coin fully passes.** Appears occasionally, tap fires a powerup, stays gone after collect, ad-for-coin grants a respawn. Closes the regression from the previous build.
- **Audio passes.** Sounds good, sliders adjust live.
- **List scrolling now works** past 3 buildings — the `MOUSE_FILTER_PASS` fix (`11eb98a`) landed. Still finnicky (see P1).
- **Cash wager feels right.** Pure-RNG path reads as a gamble, does not bait you into grinding it.

---

## P0 — blockers

### 1. Framerate 12–20 FPS, permanently red
Never reaches the ≥30 pass criterion at any point in normal play. This alone fails the pass.

Root cause is not post-processing — there is no `WorldEnvironment` or glow in
`project.godot`, and no `.gdshader` in the project. It is CPU/draw-call cost in the
immediate-mode canvas: [`city_view.gd`](godot/scripts/ui/city_view.gd) is 940 lines with
**176 `draw_*` call sites**, most inside nested loops that run every redraw —
per-facade window grids (`for wy in win_rows: for wx in win_cols:`), stars, rain drops,
pedestrians, wet-street reflections, vignette steps, sky-gradient steps, and a full-height
scanline loop. Distinct per-primitive colours defeat the compatibility renderer's 2D
batching, so these become thousands of individual draw calls per frame on a Mali-G57.

The 30fps `_dirty` redraw cap does not help: the cost is per-redraw, and the ambient
motion (rain/traffic/pedestrians) keeps the canvas permanently dirty.

### 2. Prestige is undiscoverable once unlocked
The gate was met (126M route vs 50M required) and the owner still could not find prestige.

Only two entry points exist, and both fail:
- [`hud_masthead.gd:121-127`](godot/scripts/ui/shell/hud_masthead.gd#L121-L127) — a **3px filament thread** with a 14px hit box. A hairline is not an affordance for the single most important run-ending action.
- [`attention_director.gd:164-170`](godot/scripts/ui/shell/attention_director.gd#L164-L170) — "EMPIRE READY TO ASCEND" in the attention rail, but the rail is **one slot** and this is a first-match cascade below raid (100), op-collect (80) and goal-done (70). At 52% heat with ops running, prestige-ready never wins the slot.

### 3. First prestige reachable in ~19 minutes with zero upgrades
`prestige_route_earnings` hit **2.5× the gate** in 19 minutes, on 0 upgrades purchased and
6 auto-bought managers. The owner's account — turf money spike, buy one Loan Shark Office,
prestige immediately available — matches: the curve is steep enough that a single
mid-tier purchase can cross the remaining gate distance in one step.

Note the owner's phrasing "prestiged instantly" describes the gate *opening* instantly;
`prestige_count` is still 0, so no unintended prestige actually fired. The bug is pacing,
not a broken gate. Related: [memory] rebalance was already flagged as wanted 2026-07-18.

---

## P1 — significant

### 4. Content sheet drag handle behaves weirdly
The "dropdown line" is awkward and unpredictable. `deck_bounds_smoke` passes (the sheet no
longer ratchets off-screen, `1c90531`), so this is remaining *feel*: snap targets,
drag threshold, and what the handle communicates about its own state.
[`content_deck.gd`](godot/scripts/ui/shell/content_deck.gd)

### 5. Scrolling still finnicky
`MOUSE_FILTER_PASS` unblocked drags, but touch scrolling is not yet smooth — likely
drag threshold / scroll deceleration, possibly starved by the framerate in P0-1.

### 6. City grows out of the screen
As the empire scales, the skyline overflows its stage bounds. No clamp on cumulative
facade height/width against the virtual canvas.

### 7. Tutorials vanish permanently after a few taps
Tutorial hints disappear and can never be seen again — no replay path, no Config entry.
Anything missed on first run is lost for good.

### 8. Free spin does not feel skill-based
The timing window is too tight to read as skill, so the "skill vs luck" split that the
whole gambling design rests on collapses — both paths feel random. This is the one
mechanic the checklist explicitly calls out as *must feel different*, and it fails.
Contrast: the cash wager passes and feels good.

---

## P2 — polish

### 9. Base text should be ~150%
Current body text is too small at arm's length on a real phone.

### 10. Only ~4 businesses visible in portrait
Late game you cannot see which facade lit up because the viewport shows so few rows at
once — this partly defeats the reactive-city payoff that otherwise works.

---

## Re-test list for next pass

1. FPS ≥30 sustained through normal play, purchase burst, and a click storm
2. Prestige reachable from an obvious, always-available affordance once the gate is met
3. First prestige paced to a deliberate target (not 19 min / 0 upgrades)
4. Sheet handle + list scroll feel smooth under thumb
5. Skyline stays inside its stage at high building counts
6. Tutorial replay path exists
7. Free spin timing window readable as skill

---

# Re-pass 2026-07-30

**Device:** moto g · `ZA223JN722` · 720×1604 · Android 16 · debug APK, Godot 4.6.3
**Driven by:** `adb` (screencap + `input`), fresh New Game, plus a loaded late-game save
**Automated smoke:** PASS — now includes `layout_invariants` (28 surfaces × 1.0/1.6 font scale)

## P0 status — all three moved

### 1. FPS — was 12–20, now 40–48 idle
Measured off `adb logcat` with repaired instrumentation:

```
[fps] 43.0  frame_ms=23.3 shell_ms=0.11 draw_calls=184
[fps] 47.0  frame_ms=21.3 shell_ms=0.09 draw_calls=184
```

Idle 40–48 fps on a fresh save; 34–44 on a 1000+ building save. Above the ≥30
gate, still short of the 60 cap.

**The old `process_ms` number was meaningless** — it printed ~68 whether the
device was doing 26fps or 45, because a per-frame script cost cannot stay flat
while frame time doubles. Replaced with two directly defined numbers: `frame_ms`
(1000/fps) and `shell_ms` (measured `_process` cost). The result settles the
diagnosis the old metric obscured: **`shell_ms` is 0.09–0.15 of a ~23ms frame —
0.4%.** The cost is renderer-side, which supports the 07-27 `city_view`
draw-call analysis as the place to optimise for headroom.

**Not settled: the stress case.** Driving 300 clicks through `adb shell input
tap` showed 2–3 fps, but each `input tap` spawns a process on the device, which
starves the game regardless of its own cost. That number is an artefact of the
measurement, not evidence. Purchase-burst and 20cps-click-storm FPS still needs
a human thumb.

### 2. Prestige discoverability — shipped
`PRESTIGE` chip in the masthead ([`hud_masthead.gd:84`](godot/scripts/ui/shell/hud_masthead.gd#L84)),
plus the run-ending beat winning the attention rail (`4769cb3`). Chip observed on
device. Not yet re-tested by a player actually hunting for it at gate-met.

### 3. First-prestige pacing — constants changed
`FIRST_PRESTIGE_EARNINGS` 50M → **120M** ([`game_config.gd:23`](godot/scripts/autoload/game_config.gd#L23), `b34b8cb`).
The 07-27 run hit 126M in 19 min, so that same curve now lands just at the gate
rather than 2.5× past it. **Unverified by playthrough** — needs a real fresh run.

## Fixed this pass

- **Sub-$1 money floored to `$0`.** With nine Corner Dealers the row read `$0/s`
  and the masthead `+ $0 / SEC`, one tutorial step after promising passive
  income — `format_number` fell through to `str(int(n))`. Now two decimals below
  10. Verified on device: `$0.91/s`, `$0.11/s`, `+ $1.15 / SEC`.
- **Layout at a phone's 1.6 font boost** (`0a0f704`, `58a2e0d`): masthead
  overflow hiding the gear, income line under the rail, APPROVE price clipped
  mid-number, emoji tofu, menu title clipped at both edges, Dragon Patron's third
  patron off-screen, boss sheet rows under the nav dock. All verified on hardware.
- **Android save backup** never existed on device (`DirAccess`-relative copy).

## New — open

### Android Back kills the app (P1, store-relevant)
Back exits from anywhere, including with a modal open. A GDScript handler now
unwinds overlay → boss sheet → tab → press-again-to-exit
([`game_shell.gd`](godot/scripts/ui/shell/game_shell.gd)), **but it does not take
effect**: neither `application/config/quit_on_go_back=false` nor a runtime
`get_tree().quit_on_go_back = false` stops it on Godot 4.6 / Android 16.

```
[back] go-back request received      <- our handler runs
OnGodotTerminating
GodotActivity: Force quitting Godot instance   <- activity kills it anyway
```

The manifest has `android:enableOnBackInvokedCallback="false"`, so this is the
legacy `onBackPressed()` path. Closing it needs an override in the Java build
template under `godot/android/build/` — a managed, regenerated directory, so it
is an owner decision rather than a drive-by edit. The GDScript handler is left in
place: correct, inert, and live the moment the engine side allows it.

### Still untested on device
Audio · touch feel / free-spin STOP timing · one-handed reach · golden coin ·
real rewarded ads · portrait-lock rotation · offline overlay. Also open from the
07-27 list and **not attempted this pass**: sheet drag feel (#4), scroll feel
(#5), skyline overflow (#6), tutorial replay (#7), free spin skill-read (#8),
base text size (#9), rows visible in portrait (#10).
