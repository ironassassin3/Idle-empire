# Reactive City — session handoff

**State:** designed + planned, **zero code written**. Working tree clean, everything pushed to
`feat/active-gambling`. Paused mid-project on token budget, not on a blocker.

Paste the prompt below into a fresh session.

---

## Handoff prompt

```
Resume the Reactive City UI overhaul on branch feat/active-gambling.

Read first (in this order):
1. docs/superpowers/plans/2026-07-14-reactive-city.md   <- the plan
2. docs/superpowers/specs/2026-07-14-reactive-city-design.md   <- why

Status: spec and plan are committed. NO implementation code exists yet. Nothing is
half-wired — you are starting Task 1 from a clean tree.

Do: execute Stage A (Tasks 1-4) inline, following the plan's TDD steps exactly.
That is: add the three addressed UiEvents signals, write the headless probe
(city_reaction_probe.gd) and watch it FAIL, add city_view's reaction table, make
stage_layer route the key, subscribe the row. Commit after each task as the plan
specifies. Stop when Stage A's probe passes and report.

Do NOT touch Tasks 5-8. They are an OUTLINE, not an executable plan — their steps
have no code because heat_system.gd, territory_system.gd, _draw_searchlights(),
_draw_traffic() and _district_slots() were never read. They need a second planning
pass first. Handing them to an agent as-is gets you improvised GDScript.

Godot: E:\Downloads\Godot_v4.6.3-stable_win64.exe (or $env:GODOT_BIN)
Probe:  "<godot>" --headless --path godot -s res://scripts/tools/city_reaction_probe.gd
Smoke:  "<godot>" --headless --path godot -s res://scripts/tools/shell_smoke.gd
```

---

## The 60-second version of what this is

The idle screen reads as a spreadsheet in a noir palette. **The root cause is code, not art:**

- `stage_layer.gd:185` — `func flash_building(_key: String)`. The key is **unused**. Every
  purchase, any building, fades one gold `ColorRect` over the **entire screen**. `play_raid()`
  does the same in red. Every reaction in the game is an undifferentiated full-screen tint,
  which can only read as a UI blip — never as a city responding.
- `buildings_screen.gd:166` **already passes the correct key.** The address travels end-to-end
  today. Only the receiver drops it.
- `city_view.gd` **already draws** rain, traffic, pedestrians, reflections and searchlights. The
  ambient motion exists. The searchlights are gated on *rank*, which is meaningless to a player.

So the work is not "animate the city." It is **give the city an address space and route events to
places** — and largely, re-point motion that already exists at things that matter.

## Traps that will bite you

- **`city_view.gd` is an immediate-mode canvas** (`_draw()`, 404×320 virtual space, 30fps redraw
  cap behind `_dirty`). Reactions must be **state the canvas draws**, never tweened nodes stacked
  over it — a layered node cannot know where anything is, which is *exactly* how the full-screen
  wash happened. No node allocation per event.
- **Everything gates on `GameTheme.ui_reduced_motion()` and headless**, like `play_raid()` does.
- **`GameTheme.RED` (#9a4a4a) is a ledger red — it reads as loss, not sirens**, on near-black. Two
  independent design agents concluded this without conferring. The heat/patrol work (Task 6) needs
  a hotter alert token proposed as a `GameTheme` amendment with rendered evidence. Do not invent a
  hex literal in `city_view`.
- The **live UI path is the shell** (`stage_layer.gd` / `game_shell.tscn`), **not** `game_screen.gd`.
  Edit the wrong one and nothing renders.

## Still open, unrelated to this

The real ship blocker is the 15-minute device pass (`DEVICE_TEST_CHECKLIST.md`). It needs nothing
but a phone.
