# Godot Session Handoff — Criminal Empire 1.0

Copy everything inside the **prompt block** below into a new Cursor chat to continue work.

---

## Prompt (paste this)

```
You are continuing Criminal Empire — Godot 4 is the **1.0 ship target**.

## Project
- **Open in Godot:** `d:\2d_game\godot\project.godot` (NOT `criminal-empire-(4.3)/`, NOT repo root)
- **Balance lab (optional):** pygame-ce at `d:\2d_game\` — `python sim_pacing.py`, `python sim_smoke.py`
- **Read first:** `godot/P2_HANDOFF.md`, `README.md`, `ROADMAP.md`, `PROJECT_RULES.md`, `CLAUDE.md`
- **Architecture map:** `graphify-out/port/GRAPH_REPORT.md` — refresh after big changes: `/graphify` on `src/` + `godot/scripts` with `--update`
- **Godot version:** 4.6.3 (`E:/Downloads/Godot_v4.6.3-stable_win64.exe`)
- **No generative AI image assets** (see CLAUDE.md)

## Ship vs lab
| | Path | Role |
|---|------|------|
| **Product** | `godot/` | All player UI, audio, mobile UX, features |
| **Lab** | `src/`, `main.py` | Balance sims + mechanical reference. **Do not polish pygame UI.** |

Mechanics are parity-locked (P5). Prove balance in sims, port numbers to Godot.

## Roadmap status (2026-06)

| Phase | Status | Report |
|-------|--------|--------|
| P5 Parity | ✅ Done | `P5_REPORT.md` |
| P6 Audio & feel | Code done — **manual audio playtest** open | `P6_REPORT.md` |
| P7 Mobile UX | Portrait + bottom nav + touch targets — **device pass** open | `P7_REPORT.md` |
| P8 Performance | Compatibility renderer + UI throttle — **Moto G 2026 FPS pass** open | `P8_REPORT.md` |
| P9 Retention | Pacing + daily login done — push delivery deferred to §5 | `P9_REPORT.md` |
| P10–P12 | Mock-first SHIP services in tree (uncommitted) | `SHIP_ARCHITECTURE.md` |

**Device checklist:** `DEVICE_TEST_CHECKLIST.md` — reference phone: **Motorola Moto G (2026)**.

## What's shipped (do not regress)

### Core (P1–P4)
- 11 buildings, click, upgrades, prestige + 4-branch perk tree, heat/raids
- 20 districts, 5 rivals + AI, crew, 5 illegal ops, 74 achievements, 21 goals
- 11 managers, syndicate events, tutorial/milestones, offline return, daily login
- Save schema shared with pygame import on title screen

### P5 — Parity lockdown ✅
- Dragon patron gameplay + HUD
- Pete/Sal/coin, Promoter, Rudy/Rob dashboards
- Rival elimination epitaph overlay
- Event buff decay (`bw_attack_bonus` / `bw_negotiate_bonus`)
- Raid/first-heat tutorial hooks
- Verify: `python sim_godot_soak.py` + `python sim_income_parity.py`

### P6 — Audio & feel (code done)
- `AudioManager` autoload — procedural SFX + ambient music, volume/mute from Config
- Motion: click floats, hustle squash, goal/autobuy toasts, prestige confirm pulse
- **Open:** manual playtest — Config sliders, distinct milestone cues (`P6_REPORT.md`)

### P7 — Mobile UX (code done)
- Portrait 720×1280, bottom bar (Bldgs/Upgrs/Mgrs/Turf/Stats), Turf subtabs
- Safe-area insets, 44–56px touch targets, gear → Config
- Turf badges (★ Broker / • ops ready)
- Prestige perk detail = visible label (not hover-only)
- **Open:** real device / windowed portrait walk (`DEVICE_TEST_CHECKLIST.md` §A–B)

### P8 — Performance (headless done)
- `gl_compatibility` renderer; stats UI throttled to 10fps (dirty flag)
- `memory_soak.gd` PASS 120s
- **Open:** FPS/thermal on Moto G 2026

### P9 — Retention (pacing done)
- **Empire route earnings** for prestige gate + Influence goals (not lifetime windfalls)
- Goal reward cash → balance only; removed +1 Influence per turf capture
- Turf income scales `(route/required)²`; capped district stacking
- **No play-time gate** on first prestige
- `sim_pacing.py`: buildings-only ~25 min; territory-engaging ~17 min (target 25–45 min)
- **Deferred:** Android notification delivery (mock autoload exists)

### SHIP services (mock-first — uncommitted)
- `Telemetry`, `Monetization`, `Notifications`, `CloudSave` autoloads + mock backends; registered in `soak_autoloads.gd`
- Offline 2× ad button, IAP rows in Config, `iap_income_mult` in income pipeline
- **Deferred:** §5 Android build template + plugins → `AndroidBackend` swap; §6 store/compliance

### Phase 126 — Stats tab (Godot UI)
- `stats_dashboard.gd` — tiered cards; AchBtn at top with bonus %
- `PHASE126_REPORT.md`

## Key Godot files

| Area | Path |
|------|------|
| Sim hub | `scripts/autoload/game_state.gd` |
| Save | `scripts/autoload/save_manager.gd` |
| Audio | `scripts/autoload/audio_manager.gd` |
| Main UI | `scripts/ui/game_screen.gd`, `scenes/game_screen.tscn` |
| Stats dashboard | `scripts/ui/stats_dashboard.gd` |
| Systems | `scripts/systems/*_system.gd` |
| Data defs | `scripts/data/*_defs.gd` |

## Nav model (5 + subtabs)

Bottom bar: **Buildings / Upgrades / Managers / Turf / Stats**. Header ⚙ → Config.

Turf subtabs: Territory / Rivals / Crew / Ops (Crew @ 5 buildings, Ops @ 2 districts or Made Man).

Overlays (priority): offline/daily → syndicate event → milestone → tutorial → rival epitaph.

## Income pipeline

```
building base → ManagerSystem.compute_base_income
  → achievement mult → BuffSystem.income_mult
  → prestige × heat × territory × crew collection
```

Cached in `GameState.income_per_second()` — do not recompute more than once per frame.

## Godot 4.6 gotchas

- **No `//`** — use `int(a / b)` for integer division
- **`trait` reserved** — use `trait_text` in UI
- **Const arrays:** literal values in `const X = [...]`
- **Headless:** AudioManager disabled; click floats skipped
- **Verify:**
  `python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"`

## Recommended next work (pick one)

1. **Device pass (highest value)** — Export Android → Moto G 2026 → walk `DEVICE_TEST_CHECKLIST.md`
2. **P6 sign-off** — Manual audio playtest; confirm milestone cue distinctness + music loop
3. **Commit SHIP work** — `chore:` hygiene + `feat:` mock-first F2P autoloads (see `SHIP_ARCHITECTURE.md`)
4. **§5 Android setup** — Install build template + AdMob/Billing/notification/Play Games plugins
5. **Balance tweak (optional)** — If territory path feels too fast on device, tune in `sim_pacing.py` first

## Rules

- All rates × `dt` in `_process`
- Milestone strings: `\n` separator (title line, then body)
- New save fields need migration defaults in `game_state.gd` / save load
- Do not commit unless user asks
- Do not add new major systems without evidence (PROJECT_RULES.md)
```

---

## Context for the agent

### Repo layout
```
d:\2d_game\
  README.md              Start here
  ROADMAP.md             P5–P12 launch plan
  DEVICE_TEST_CHECKLIST.md
  main.py, src/          pygame lab (sims + reference)
  sim_pacing.py          First-prestige pacing instrument
  sim_godot_soak.py      Headless Godot gate
  godot/                 **Ship target**
    project.godot        Portrait, GL Compatibility
    scenes/              main_menu, game_screen, overlays, *_row
    scripts/             autoload, systems, ui, data, tools
```

### Headless sanity check
```powershell
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
python sim_smoke.py
python sim_pacing.py --minutes 45 --active 0.33 --cps 2
```

### Presentation saga
Phases 121–127 were **pygame-only** UI passes — archived. Godot P6–P7 supersede them. Phase 126 (Stats tiering) is Godot-only and done.
