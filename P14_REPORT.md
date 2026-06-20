# P14 — Touch-First Retention UI

**Status:** Code-first complete — P14.0–P14.9 done; MM textures + device capture deferred.  
**Architecture:** [`UI_OVERHAUL_ARCHITECTURE.md`](UI_OVERHAUL_ARCHITECTURE.md)  
**Music:** [`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md) M1 landed in P14.8.

---

## Phase summary

| Phase | Status | Notes |
|-------|--------|-------|
| P14.0 Research lock | ✅ | Doc + capture matrix + telemetry events |
| P14.1 Theme foundation | ✅ (fallback) | `GameTheme` StyleBox helpers; MM hooks; `UI_RUSTIC_THEME` |
| P14.2 Main menu | ✅ (code-first) | Ledger panel + save preview |
| P14.3 Header / buy-mult | ✅ | Cash-dominant HUD, advice chip |
| P14.4 Tab badges + strip | ✅ (code-first) | Pills + active gold rule / inactive muted tabs |
| P14.5 Row affordance | ✅ (code-first) | Wax seal + border tints |
| P14.6 Stats / Config / tree | ✅ (code-first) | Text scale, IAP cards |
| P14.7 Overlays / motion | ✅ (code-first) | Overlay queue, reduced motion |
| P14.8 Atmosphere + device prep | ✅ (code-first) | Grain, M1 music, tension stub |
| P14.9 Telemetry validation | ✅ | Probe + `analyze_telemetry.py` P14 funnel |

---

## Exit criteria checklist

### Presentation (P14.1–P14.8)

- [x] Economy HUD: balance largest, IPS second, rank truncates
- [x] Global ×1/×10/Max buy-multiplier chip
- [x] Tab badge pills on actionable tabs (code-first tab strip; MM PNG deferred)
- [x] Row wax-seal affordance on buyable rows
- [x] Overlay single-flight queue (offline → daily → elim → milestone → event)
- [x] Reduced motion toggle (Particles OFF) skips overlay pulses
- [x] Film grain atmosphere on `game_screen` (skipped headless / reduced motion)
- [x] M1 music: Music/SFX buses, menu + famiglia loops, heat tension stub
- [ ] Material Maker textured surfaces (P14.1 MM export — owner deferred)
- [ ] Device capture matrix filled ([`docs/ui/capture_matrix/`](docs/ui/capture_matrix/README.md))

### Performance / regression

- [x] `memory_soak.gd` 120s PASS (post P14.8 grain)
- [x] `sim_godot_soak.py` PASS
- [x] `sim_smoke.py` PASS
- [ ] Moto G device pass: notch, FPS, grain + music audible

### Telemetry (P14.9)

- [x] ≥5 UI events firing in mock telemetry sink (probe validates 10 kinds)
- [x] FTUE funnel table: tutorial step → drop-off (`analyze_telemetry.py`)
- [ ] Owner review of first-prestige path (manual)

---

## P14.9 deliverables

| Item | File(s) |
|------|---------|
| UI event audit + gaps | `game_screen.gd` — `ui_prestige_tree_open`, `ui_badge_impression` |
| P14 funnel analyzer | `analyze_telemetry.py` — FTUE drop-off, overlay ms, tab paths |
| Headless probe | `godot/scripts/tools/telemetry_probe.gd` (`--telemetry-probe`; not in soak) |
| Probe sink path override | `telemetry.gd`, `local_file_sink.gd` |
| Tab strip polish (P14.4) | `game_theme.gd` — active gold bottom rule, muted inactive |

### UI telemetry events (§9)

| Event | Wired |
|-------|-------|
| `ui_session_start` | `game_screen._ready` |
| `ui_tab_open` | `_set_tab` |
| `ui_overlay_shown` | `_sync_overlay_telemetry` |
| `ui_overlay_dismiss_ms` | `_log_overlay_dismiss` |
| `ui_buy_mult_changed` | `_on_buy_mult_chip` |
| `ui_badge_click` | `_maybe_log_badge_click` |
| `ui_badge_impression` | `_refresh_tab_badges` (count change) |
| `ui_prestige_tree_open` | `_on_prestige` |
| `ui_config_open` | `_set_tab(CONFIG)` |
| `ui_first_building_buy_ms` | `_on_buy` |
| `ui_tutorial_step` | `telemetry.gd` ← `tutorial_advanced` |

---

## Verification log

| Run | Result | Notes |
|-----|--------|-------|
| `memory_soak.gd` 120s | **PASS** | nodes +0, mem +607 KB (2026-06-19) |
| `sim_smoke.py` | **PASS** | (2026-06-20 P14.9) |
| `sim_godot_soak.py` | **PASS** | 60s soak + income parity (2026-06-20 P14.9) |
| `telemetry_probe.gd` | **PASS** | ≥5 UI event kinds → JSONL (2026-06-20 P14.9) |
| `analyze_telemetry.py` | **PASS** | P14 funnel section on probe output |
| Moto G device matrix | **Pending** | [`docs/ui/capture_matrix/README.md`](docs/ui/capture_matrix/README.md) |
| Owner first-prestige review | **Pending** | Manual |

---

## Remaining (post-P14 code-first)

1. **P14.1 MM textures** — Export Material Maker graphs; flip `GameConfig.UI_RUSTIC_THEME`.
2. **Device capture** — Fill capture matrix; `DEVICE_TEST_CHECKLIST.md` §A–B on Moto G.
3. **Owner sign-off** — First-prestige funnel path review from exported JSONL.

---

## Next

Android export + device checklist; MM owner drop-in when graphs are exported.
