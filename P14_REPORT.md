# P14 — Touch-First Retention UI

**Status:** In progress — P14.0–P14.8 done (code-first); P14.9 pending.  
**Architecture:** [`UI_OVERHAUL_ARCHITECTURE.md`](UI_OVERHAUL_ARCHITECTURE.md)  
**Music:** [`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md) M1 landed in P14.8.

---

## Phase summary

| Phase | Status | Notes |
|-------|--------|-------|
| P14.0 Research lock | ✅ | Doc + capture matrix + telemetry events |
| P14.1 Theme foundation | ✅ (fallback) | `GameTheme` StyleBox helpers; MM hooks |
| P14.2 Main menu | ✅ (code-first) | Ledger panel + save preview |
| P14.3 Header / buy-mult | ✅ | Cash-dominant HUD, advice chip |
| P14.4 Tab badges | ✅ Partial | Bldgs/Upgrs/Mgrs pills |
| P14.5 Row affordance | ✅ (code-first) | Wax seal + border tints |
| P14.6 Stats / Config / tree | ✅ (code-first) | Text scale, IAP cards |
| P14.7 Overlays / motion | ✅ (code-first) | Overlay queue, reduced motion |
| P14.8 Atmosphere + device prep | ✅ (code-first) | Grain, M1 music, tension stub |
| P14.9 Telemetry validation | ⬜ | Funnel table, owner sign-off |

---

## Exit criteria checklist

### Presentation (P14.1–P14.8)

- [x] Economy HUD: balance largest, IPS second, rank truncates
- [x] Global ×1/×10/Max buy-multiplier chip
- [x] Tab badge pills on actionable tabs (partial — no MM tab strip)
- [x] Row wax-seal affordance on buyable rows
- [x] Overlay single-flight queue (offline → daily → elim → milestone → event)
- [x] Reduced motion toggle (Particles OFF) skips overlay pulses
- [x] Film grain atmosphere on `game_screen` (skipped headless / reduced motion)
- [x] M1 music: Music/SFX buses, menu + famiglia loops, heat tension stub
- [ ] Material Maker textured surfaces (P14.1 MM export — deferred)
- [ ] Device capture matrix filled (`docs/ui/capture_matrix/`)

### Performance / regression

- [x] `memory_soak.gd` 120s PASS (post P14.8 grain)
- [x] `sim_godot_soak.py` PASS
- [x] `sim_smoke.py` PASS
- [ ] Moto G device pass: notch, FPS, grain + music audible

### Telemetry (P14.9)

- [ ] ≥5 UI events firing in mock telemetry sink
- [ ] FTUE funnel table: tutorial step → drop-off
- [ ] Owner review of first-prestige path

---

## P14.8 deliverables

| Item | File(s) |
|------|---------|
| Film grain overlay | `godot/scripts/ui/film_grain_overlay.gd`, `game_screen.tscn` |
| M1 music stack | `godot/scripts/autoload/audio_manager.gd` |
| Music context hook | `game_screen.gd` (`update_music_context` 1 Hz) |
| Menu music mode | `main_menu.gd` |
| Device matrix notes | `docs/ui/capture_matrix/README.md`, `DEVICE_TEST_CHECKLIST.md` |

---

## Verification log

| Run | Result | Notes |
|-----|--------|-------|
| `memory_soak.gd` 120s | **PASS** | nodes +0, mem +607 KB (2026-06-19) |
| `sim_smoke.py` | **PASS** | |
| `sim_godot_soak.py` | **PASS** | 60s soak + income parity |

---

## Next

1. **P14.9** — Complete telemetry funnel validation; fill verification log.
2. **P14.1 MM textures** — Export Material Maker graphs; flip `GameConfig.UI_RUSTIC_THEME`.
3. **Android** — Export APK; run DEVICE_TEST_CHECKLIST §B on Moto G reference device.
