# Prestige pacing notes

## 2026-07-28 pass (ship target)

Lab: `sim_prestige_strategies.py --active 0.33 --minutes 400 --prestiges 3`

### Targets
| Climb | Target |
|-------|--------|
| P1 | ~40–60m engaged |
| P1→P2 | ~25–40m |
| P2→P3+ | ~30–50m+ |

### Device evidence (pre-fix)
- Phone P1 gate open ~19m / 0 upgrades at **$50M** (pygame lab was ~45–58m — engagement + Godot feel diverge).
- Mid-P2 save: route **$793M / $400M**, buildings 60/24/12, but **no path** — earnings/rebuild were not the brake.

### Knobs shipped (pygame + Godot)
| Knob | Old | New |
|------|-----|-----|
| `FIRST_PRESTIGE_EARNINGS` | 50M | **120M** |
| `PRESTIGE_EARNINGS_GROWTH` | 8 | **12** |
| `POST_PRESTIGE_*` | 19/8/4 (¾ of first) | **25/10/5** (same as first) |
| Rebuild scale | flat | `FIRST * (1 + 0.5 * prestige_count)` → P2=38/15/8, P3=50/20/10 |
| Next earnings gate | `prev * GROWTH` | `max(prev*GROWTH, ips * 25m * income_mult * 6)` |
| pygame territory on prestige | kept strategic districts | **full wipe** (Godot parity) |

### Cadence after (balanced / typical)
| Strategy | P1 | P1→P2 | P2→P3 |
|----------|-----|-------|-------|
| no_upgrades | 45m | 25m | 67m |
| balanced | 51m | 18m | 50m |
| turf_rush | 54m | 15m | 50m |
| click_heavy | 52m | 69m | 103m |
| pure_idle | 119m | 184m | — |

P1→P2 for turf/balanced is still short of the 25m floor; next lever if playtest agrees: raise `PRESTIGE_REBUILD_SCALE_PER` (0.5 → 0.75).

### Env overrides (pygame lab)
`IDLE_PRESTIGE_EARNINGS`, `IDLE_PRESTIGE_GROWTH`, `IDLE_POST_PRESTIGE_*`,
`IDLE_PRESTIGE_PACING_SECS`, `IDLE_PRESTIGE_SNOWBALL_PAD`, `IDLE_PRESTIGE_REBUILD_SCALE`

---

## 2026-09-17 full cadence rebalance

Root cause: late-building income/$ rose by roughly 45% per tier. On P2, the
casino→nightclub→dock unlock chain could raise base IPS about 74× in one minute;
larger cash gates therefore added seconds rather than meaningful playtime.
Short golden-coin Frenzy buffs amplified the variance when they hit that cliff.

Changes:

- Smoothed building income/$ growth to about 20% per tier after Protection Racket.
- Prestige route earnings now use stable passive IPS; temporary income buffs
  still award full cash but do not skip the prestige gate.
- Added a saved, visible 25-minute rebuild floor after P1. Existing saves infer
  progress from recorded playtime so the migration does not strand players.
- Corrected strategy simulations to respect real manager unlock rules.

Deterministic balanced seeds now land P1 at 52:37–60:33 and P1→P2 at
25:00–25:34. The wider strategy sweep produced balanced 54:46 / 25:37 / 46:37,
fast-buyer 50:20 / 27:16 / 30:36, and turf-rush 57:55 / 25:00 / 45:23.

---

## 2026-06 history (superseded)

Earlier fix: reset route earnings + soft 75% rebuild gates. That stopped 1–2 min re-prestiges but left P2→P3 ~6–9m under Influence snowball. See git history for tables.
