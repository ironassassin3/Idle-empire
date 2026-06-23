# Criminal Empire — Idle Game

Build a criminal empire: buy buildings → earn income → upgrades → Influence → prestige. Heat, turf, rivals, crew, illegal ops, and a prestige perk tree layer on top.

## Ship target vs prototype

| | Path | Role |
|---|------|------|
| **1.0 product** | [`godot/`](godot/) | **Ship this.** Godot 4.6, portrait mobile UX, audio, all player-facing work. |
| **Prototype / lab** | [`src/`](src/), [`main.py`](main.py) | Balance sims and mechanical reference only. **Not maintained for UI.** |

## Quick start (Godot — recommended)

1. Install [Godot 4.3+](https://godotengine.org/) (project tested on **4.6.3**).
2. **Project → Import** → `godot/project.godot`
3. Press **F5** (title menu → game).

Headless verify from repo root:

```powershell
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
```

See [`godot/README.md`](godot/README.md) for layout, save import, and mobile export.

## Quick start (pygame lab — optional)

```powershell
pip install pygame-ce
python main.py
python sim_pacing.py --minutes 45 --active 0.33 --cps 2
python sim_prestige_strategies.py --active 0.33 --minutes 120 --prestiges 10
python sim_smoke.py
```

## Roadmap status (2026-06)

Full plan: [`ROADMAP.md`](ROADMAP.md). Reports: `P5_REPORT.md` … `P9_REPORT.md`.

| Phase | Goal | Status |
|-------|------|--------|
| **P5** | Parity lockdown (mechanics) | ✅ Done |
| **P6** | Audio & feel | Code done — **manual audio playtest** open |
| **P7** | Mobile UX (portrait, bottom nav, touch targets) | Code done — **device pass** open |
| **P8** | Performance (Compatibility renderer, throttle) | Headless OK — **Moto G (2026) device pass** open |
| **P9** | Retention (pacing, daily login, offline) | Pacing fixed in lab — notifications/telemetry deferred |
| **P10–P12** | Monetization → store → soft launch | Not started |

**Device pass:** [`DEVICE_TEST_CHECKLIST.md`](DEVICE_TEST_CHECKLIST.md) — reference phone: **Motorola Moto G (2026)**.

## Key docs

| Doc | Purpose |
|-----|---------|
| [`CLAUDE.md`](CLAUDE.md) | Agent + contributor conventions |
| [`PROJECT_RULES.md`](PROJECT_RULES.md) | Mechanics rules, prestige, save schema |
| [`ROADMAP.md`](ROADMAP.md) | Godot → mobile launch phases |
| [`godot/P2_HANDOFF.md`](godot/P2_HANDOFF.md) | Session handoff for Godot work |
| [`UI_OVERHAUL_ARCHITECTURE.md`](UI_OVERHAUL_ARCHITECTURE.md) | P14 touch-first UI overhaul (Godot) |

## Balance / pacing (recent)

First prestige target: **~25–45 min** (buildings-only ~25 min; turf-engaging ~17 min in `sim_pacing.py`).

Principled fixes (no play-time gate): **empire route earnings** for prestige + Influence goals, goal cash → balance only, turf income scales with route progress, removed +1 Influence per district capture. Details: [`P9_REPORT.md`](P9_REPORT.md).

Prove balance in pygame sims, port numbers to `godot/scripts/`.

## Art

**Mandatory policy:** [`ART_POLICY.md`](ART_POLICY.md) — no generative-AI assets; build visuals and SFX in code (or use owner-provided hand art only).
