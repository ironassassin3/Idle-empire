# Criminal Empire — Godot 4 (**1.0 ship target**)

GDScript rebuild of the pygame prototype. **This folder is the product** — all player-facing development happens here.

**Engine:** Godot 4.3+ (tested on **4.6.3**). **Platform:** portrait mobile-first (720×1280), `gl_compatibility` renderer.

## Run

1. **Project → Import** → `godot/project.godot`
2. Press **F5** (main menu → game)

CLI:

```powershell
& "E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path "d:\2d_game\godot"
```

Headless verify (from repo root):

```powershell
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
```

## Roadmap status

| Phase | Status |
|-------|--------|
| P5 Parity | ✅ `P5_REPORT.md` |
| P6 Audio & feel | Code done — manual playtest open (`P6_REPORT.md`) |
| P7 Mobile UX | Portrait + bottom nav + touch targets — **device pass** open (`P7_REPORT.md`) |
| P8 Performance | Compatibility renderer + UI throttle — **Moto G 2026** pass open (`P8_REPORT.md`) |
| P9 Retention | Pacing + daily login — notifications deferred (`P9_REPORT.md`) |

Device checklist: [`../DEVICE_TEST_CHECKLIST.md`](../DEVICE_TEST_CHECKLIST.md)

## What's in the build

| Area | Notes |
|------|-------|
| Core loop | 11 buildings, click, upgrades, 11 managers, prestige + 4-branch perk tree |
| World | 20 districts, 5 rivals, crew, 5 illegal ops, heat/raids |
| Meta | 74 achievements, 21 goals, syndicate events, tutorial, offline/daily return |
| P5 | Dragon patron, golden coin, Pete/Sal/Promoter/Rudy/Rob, rival epitaph overlay |
| P6 | `audio_manager.gd` — procedural SFX + ambient music, motion cues |
| P6 music plan | Procedural 8-bit mafia score spec + motif scaffold � [MUSIC_ARCHITECTURE.md](../MUSIC_ARCHITECTURE.md), scripts/audio/music_defs.gd (MusicDefs) |
| P7 | Bottom bar nav, Turf subtabs, safe-area insets, 44–56px touch targets |
| P7 UI | Tiered Stats tab (`stats_dashboard.gd`), turf badges (★/•), prestige perk labels |

Architecture map: [`../graphify-out/port/graph.html`](../graphify-out/port/graph.html)

## Save

Godot writes `user://save.json`. Title screen can **import** a pygame `save.json` from the repo root (prototype migration only).

## Project layout

```
godot/
  project.godot
  scenes/              main_menu, game_screen, prestige_tree_overlay, *_row
  scripts/
    autoload/          GameConfig, GameState, SaveManager, FormatUtil, AudioManager,
                       Telemetry, Monetization, Notifications, CloudSave
    systems/           territory, rivals, crew, ops, heat, prestige, events, …
    ui/                game_screen.gd, stats_dashboard.gd, row scripts, GameTheme
    data/              building, upgrade, manager defs
    tools/             memory_soak.gd, headless probes
  theme/noir_theme.tres
```

## Mobile export (Android)

Plugin scaffolding (SHIP §5): [../ANDROID_SETUP.md](../ANDROID_SETUP.md).

1. **Editor → Manage Export Templates** → install Android templates.
2. **Project → Export → Android** — debug keystore OK for personal testing.
3. Moto G (2026): enable USB debugging → **Export & Run**, or sideload debug APK.

Portrait + Compatibility renderer already set in `project.godot`.

## pygame prototype (lab only)

Repo root [`../src/`](../src/) + [`../sim_pacing.py`](../sim_pacing.py) — balance proofs only. Not shipped. Do not polish pygame UI.

Session handoff: [`P2_HANDOFF.md`](P2_HANDOFF.md)
