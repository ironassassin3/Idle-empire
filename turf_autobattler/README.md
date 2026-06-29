# Turf Autobattler

2.5D criminal turf auto-battler (TFT-style). **Separate Godot project** from Criminal Empire idle game in `godot/`.

## Quick start

1. Open Godot 4.3+ → Import → `turf_autobattler/project.godot`
2. Press **F5** to run the vertical slice (shop, bench, 4×4 board, combat playback)

## Headless sim

```powershell
.\tools\run_headless.ps1 -Seed 12345 -Iterations 100
.\tools\publish_pass.ps1 smoke
```

Or with Godot directly:

```powershell
godot --headless --path turf_autobattler --main-scene res://tools/headless_main.tscn -- --seed=12345 --iterations=100
```

## Publishing checklist

1. Install Godot export templates (Project → Export)
2. Copy `export_presets.cfg.example` → `export_presets.cfg` and set keystore paths for Android
3. Run `tools/run_headless.ps1` — all golden replays must pass
4. Export Windows/Android builds to `build/`
5. Metagame progress persists to `user://turf_save.json` between sessions

## Architecture

- `sim/` — pure GDScript, no `extends Node`, headless-testable
- `data/` — unit/trait/rival registries
- `presentation/` — RunBridge + UI scenes
- `tools/` — headless runner, golden replay smoke

See **`../TURF_AUTOBATTLER_HANDOFF.md`** for full design spec.

## MVP defaults (locked for v1)

- 4×4 board, isometric-style flat UI (code-drawn rectangles)
- 8 units, 3 traits, 10 rival comp bands
- Resolve-then-playback combat
- No unit merges, no heat system
