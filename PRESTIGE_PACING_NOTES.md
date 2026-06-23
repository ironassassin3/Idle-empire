# Prestige pacing notes (2026-06)

Stress-tested with `sim_prestige_strategies.py` — balanced strategy, 33% active, 120 min cap.

## Root cause

Post-P1 snowball had two drivers:

1. **Route earnings not reset on prestige** (pygame bug; Godot already reset `prestige_route_earnings`). Players carried ~$20M toward the next gate immediately after P1.
2. **Building/rank gates dropped entirely after P1**, so P2+ could prestige on route earnings alone while income mult from tokens made the escalating gate trivial (~1–2 min).

## Fix (minimal, one balance lever + parity)

| Change | pygame | Godot |
|--------|--------|-------|
| Reset route earnings on prestige | `src/prestige.py` | already present |
| Soft rebuild gates on 2nd+ prestige (75% of first) | 15 dealers / 6 rackets / 3 chops | `game_config.gd` + `prestige.gd` |

First prestige gates unchanged: $20M route, 20/8/4 buildings, Made Man rank.

## Cadence — before vs after

**Before** (broken; route carry-over, no post-P1 gates):

| Milestone | Time |
|-----------|------|
| P1 | 14m04s |
| P1→P2 | 1m31s |
| P2→P3 | 2m16s |
| P3→P10 | ~1m each |

**After** (route reset + 75% rebuild gates):

| Milestone | Time |
|-----------|------|
| P1 | 14m31s |
| P1→P2 | 4m05s |
| P2→P3 | 2m47s |
| P3→P4 | 6m16s |
| P4→P5 | 7m31s |
| P5→P6 | 8m55s |
| P6→P7 | 10m28s |
| P7→P8 | 12m13s |
| P8→P9 | 13m10s |
| P9→P10 | 15m23s |

First-prestige gate check (`sim_pacing.py --minutes 45 --active 0.33`): **~10–14 min** turf-engaging — within design band.

## Re-run

```powershell
python sim_prestige_strategies.py --active 0.33 --minutes 120 --prestiges 10 --strategies balanced
python sim_pacing.py --minutes 45 --active 0.33 --cps 2
python sim_smoke.py
```

## Open questions

- P2→P3 (~3 min) is still faster than P1; acceptable if later cycles stretch to 7–15 min. Revisit `POST_PRESTIGE_*` via env (`IDLE_POST_PRESTIGE_DEALERS` etc.) if playtests feel rushed.
- Godot `next_prestige_earnings` uses a fixed $160M bar after P1 plus `max(growth, route×0.5)` on later cycles; pygame uses `route × GROWTH`. Parity gap is intentional for now — sim runs on pygame `PlayingState`.

## Manager auto-buy gate (2026-06-22)

Accountant / Mechanic **purchase** automation and Talent Scout building auto-buy are gated until `prestige_count >= 1`. Income mults (1.5×) remain active when hired pre-P1. Expect **unchanged P1 timing**; post-P1 snowball slightly slower until managers' auto-buy kicks in after first reset. Re-run `sim_prestige_strategies.py --strategies balanced no_managers` to compare.
