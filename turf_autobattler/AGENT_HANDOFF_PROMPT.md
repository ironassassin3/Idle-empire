# Turf Autobattler — Agent Session Prompt

**Copy everything inside the fenced block below into a new agent session.**

---

```
You are continuing work on **Turf Autobattler only** — the TFT-style spin-off in `turf_autobattler/`.

## SCOPE (mandatory)

**IN SCOPE**
- `turf_autobattler/` — sim, data, presentation, tools, tests, export/publish for this project only

**OUT OF SCOPE — do not touch unless the user explicitly asks**
- `godot/` — Criminal Empire idle game (parent product)
- `src/`, `config.py`, `sim_*.py`, CE reports (`P*_REPORT.md`), `device_pass.ps1` (CE toolchain)
- Uncommitted Criminal Empire gameplay/UI changes on `master`
- Android/export work for Criminal Empire

If a task would require editing the idle game, **stop and ask** — default is autobattler-only.

## Read first (order)

1. `turf_autobattler/AGENT_HANDOFF_PROMPT.md` (this file — session context)
2. `TURF_AUTOBATTLER_HANDOFF.md` (architecture + §22 build order)
3. `ART_POLICY.md` (before any visual/audio work)
4. `turf_autobattler/README.md` (quick start + publish checklist)

## Product

**Syndicate Skirmish** — criminal turf auto-battler: shop → bench → 4×4 board → resolve-then-playback combat → metagame Street Cred.

- Godot 4.3+ (repo uses 4.6.3)
- PvE ladder v1; no live multiplayer, no unit merges v1, no heat
- Sim-first: `sim/` never extends Node; UI uses intents via `RunBridge` only

## Current state (2026-06-28)

**Implemented (vertical slice)**
- `sim/` — core, economy, combat, run FSM, metagame
- `data/` — 8 units, 3 traits, rival comps
- `presentation/` — main menu, run shell, shop/bench/board, combat playback, audio, save store
- `tools/headless_runner.gd` + 3 golden replays — **PASS**
- `tools/publish_pass.ps1` — check / smoke / export-win / export-android

**Shippable artifact**
- Windows desktop: `turf_autobattler/build/TurfAutobattler.exe` (~96 MB)
  - Build: `cd turf_autobattler; .\tools\publish_pass.ps1 export-win`

**Not done**
- Android APK — toolchain exists repo-wide, but Turf headless `--export-debug Android` fails with generic Godot preset validation (needs Editor → Export → Android once to surface exact error, or fix `export_presets.cfg` / launcher icons)
- Store listing, compliance, release keystore / AAB
- 2.5D polish (iso tiles, juice) — step 11+ in handoff §22; do not skip sim/headless gates

## Verification (run after every change)

```powershell
cd D:\2d_game\turf_autobattler
.\tools\publish_pass.ps1 smoke
```

Golden replays must stay green. Optional full repo gate (includes CE — read-only sanity only):

```powershell
cd D:\2d_game
.\verify_ship.ps1
```

Do **not** modify CE to fix Turf failures.

## Godot paths

- Project: `D:\2d_game\turf_autobattler\project.godot`
- Godot binary: `E:\Downloads\Godot_v4.6.3-stable_win64.exe` (or `$env:GODOT_BIN`)
- Headless: `.\tools\run_headless.ps1 -Seed 12345 -Iterations 100`

## Architecture reminders

- Combat outcome decided in sim before playback; animations are cosmetic
- Seeded RNG in `sim/core/rng.gd` only
- Player actions = `PlayerIntent` validated by `RunDirector`
- Metagame persists to `user://turf_save.json` via `SaveStore`

## Suggested next work (autobattler only)

1. Unblock Android export (minimal preset, PNG launcher icons, gradle template under `turf_autobattler/android/build/`)
2. Improve run UX (drag-drop polish, trait panel, run-end flow)
3. Balance via headless runner (win rate, round length)
4. Step 11+ presentation polish per handoff §22 — after gates stay green

## Do not

- Implement inside `godot/` or merge modes with Criminal Empire
- Use generative-AI assets (`ART_POLICY.md`)
- Commit `.godot/` cache or `export_presets.cfg` (local keystore paths; use `.example`)
- Start at presentation polish (step 11) before sim + headless pass

## Loop context

A 25-minute publish loop may be active (`AGENT_LOOP_TICK_TURF_PUBLISH`). On tick: run smoke, pick the next highest-impact autobattler publish task, report what changed. Do not duplicate an existing loop.
```
