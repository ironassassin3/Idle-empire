# Session Handoff — 2D Idle Clicker (Pygame)

**Date:** 2026-05-31  
**Window:** 900 × 650  
**Run:** `python main.py` → press Enter to start

---

## What Was Built This Session

### Bug Fixes
| Bug | Fix | File |
|---|---|---|
| News ticker doubling/overlapping | Cache rendered surface per `_ticker_idx`; `uw` (tile width) now constant while scrolling | `src/ui.py` — `_TICKER_CACHE`, `draw_news_ticker` |
| Right panel clipped at edge | Outer rect uses `config.SCREEN_WIDTH - 444` dynamically | `src/ui.py` — `draw_right_panel` |
| Window too small | Changed to 900 × 650 | `config.py` |

### Visual Improvements
| Feature | Where |
|---|---|
| Left panel container — framed BG_PANEL rect with ACCENT_DIM border (30% alpha) mirroring the right panel | `draw_click_zone` in `src/ui.py` |
| 3D click button — BLUE_MID base, BLUE_HIGHLIGHT top (40% alpha), BLUE_SHADOW bottom (50% alpha), BLUE_BRIGHT glow ring; highlights invert on press via `press` factor | `draw_click_zone` in `src/ui.py` |
| Building card income text — GREEN instead of TEXT_MUTED | `src/buildings.py` |
| Affordable cards — 2px GREEN left border (50% alpha); unaffordable — 60% alpha card + TEXT_MUTED name | `src/buildings.py` |
| `format_number(n)` — compacts to 1.2K / 4.5M / 2.1B | `src/theme.py`; used in stats bar, click hint, building costs/income, upgrade costs |
| Idle income particles — mint-green `+` glyphs near balance text, spawn every 0.5s when income > 0, drift up 30px, fade over 0.8s | `draw_idle_particles` in `src/ui.py`; spawned in `PlayingState.update` |
| Panel divider — 1px ACCENT_DIM line (25% alpha) between left and right panels | `draw_panel_divider` in `src/ui.py` |
| All inline colour tuples moved to theme constants | `src/theme.py` — `BLUE_HIGHLIGHT`, `BLUE_SHADOW`, `PARTICLE_IDLE`, `CLICK_STORM`, `PRESTIGE_LABEL`, `OVERLAY_DARK`, `BTN_YES`, `BTN_NO`, `BTN_DISABLED` |

### Content Additions
| Item | Details |
|---|---|
| **+3 buildings** | Mine (1M cost, 500/s), Shipment (10M, 2500/s), Alchemy Lab (100M, 12500/s) — indices [5][6][7] in `buildings._DEFS` |
| **+6 upgrades** | Offshore Banking (Bank 2x, 50K), Quantum Portals (Portal 2x, 500K), Double Down (4x click, 100K), Explosive Mining (Mine 2x, 5M), Faster Shipping (Shipment 2x, 50M), Philosopher's Stone (Alchemy 2x, 500M) |
| **+5 achievements** | Big Spender (100 buildings), Deep Pockets (1B lifetime), Click God (10K clicks), Miner (own 1 Mine), Prestiged Pro (3 prestiges) |

**Totals:** 8 buildings · 10 upgrades · 13 achievements

### New Features
| Feature | Details |
|---|---|
| **Mouse-wheel scroll** — buildings and upgrades panels | `MOUSEWHEEL` event in `PlayingState.handle_events`; `_bld_scroll` / `_upg_scroll` state; scroll resets on tab switch; ▲/▼ hints drawn by `_draw_scroll_hints` in `src/ui.py` |
| **Stats tab** (3rd tab) | Shows: clicks, lifetime earned, income/sec, buildings owned, upgrades ratio, achievements ratio, prestige tokens, session time (MM:SS from `state._time`) |
| **3-tab layout** | `_TAB_RECTS` updated to 3 × 150px tabs; Buildings / Upgrades / Stats |

---

## Architecture Snapshot

```
d:\2d_game\
├── main.py           MenuState + entry point (unchanged)
├── config.py         SCREEN_WIDTH=900, SCREEN_HEIGHT=650, FPS=60
└── src\
    ├── engine.py     Engine, game loop, dt (unchanged)
    ├── states.py     GameState ABC, StateManager, PlayingState  [305 lines]
    ├── ui.py         All rendering helpers                       [355 lines]
    ├── theme.py      Colors, fonts, format_number()             [58 lines]
    ├── buildings.py  8 building defs, draw_panel(scroll=)       [141 lines]
    ├── upgrades.py   10 upgrade defs + effects, draw_panel(scroll=) [142 lines]
    ├── achievements.py 13 achievements + toast drawer           [97 lines]
    ├── prestige.py   Threshold 1M lifetime, tokens, execute()   (unchanged)
    └── save_load.py  JSON save/load to save.json                (unchanged)
```

### Key Class/Function Map

| Symbol | File | Notes |
|---|---|---|
| `PlayingState` | `states.py:89` | Main game state; holds all runtime state |
| `PlayingState._bld_scroll` / `_upg_scroll` | `states.py` | Scroll offsets; clamped in MOUSEWHEEL handler |
| `PlayingState.click_value` | `states.py:152` | Checks `double_click` and `quad_click` effect keys |
| `draw_click_zone` | `ui.py:172` | Left panel container + 3D button + idle particle spawn |
| `draw_right_panel` | `ui.py:234` | 3-tab bar + dispatches to bld/upg/stats panel |
| `draw_stats_tab` | `ui.py` | Stats panel; reads `state._time` for session clock |
| `_draw_scroll_hints` | `ui.py` | ▲ / ▼ indicators when content overflows |
| `draw_idle_particles` | `ui.py` | Mint-green `+` particles near balance |
| `draw_panel_divider` | `ui.py` | 1px vertical separator |
| `format_number(n)` | `theme.py` | K/M/B formatter; used everywhere |
| `buildings._DEFS` | `buildings.py:37` | 8 tuples; append-only for save compat |
| `upgrades._DEFS` | `upgrades.py:79` | 10 tuples; append-only for save compat |
| `make_achievements()` | `achievements.py:28` | Returns 13 `Achievement` dataclasses |

---

## Save File Compatibility

`save.json` uses index-based arrays for buildings/upgrades/achievements. New entries were appended to the END of each `_DEFS` list — old saves load correctly (missing indices default to 0/False).

---

## Known Constraints / Rules

- `states.py` must stay under ~350 lines (currently 305)
- All colours must come from `src/theme.py` — no raw tuples in ui/building/upgrade files
- All animation timing must use `dt` — no frame-dependent logic
- `src/engine.py`, `src/prestige.py`, `src/save_load.py` — do not touch
- No new pip dependencies — pygame only
- Buildings/upgrades/achievements data: **append only** to keep save compat

---

## Obvious Next Steps

- **Sound** — `pygame.mixer` not initialised anywhere; add click/purchase/achievement SFX
- **More upgrade tiers** — second prestige multiplier upgrade, achievement-gated bonuses
- **Scroll bar visual** — replace ▲/▼ text hints with a proper scrollbar track
- **Pause / ESC menu** — currently ESC exits to the (empty) MenuState
- **Save versioning** — no migration logic; adding mid-list entries would break saves
- **Offline earnings** — calculate passive income accrued since last `save_game()` call on load
- **Settings tab** — 4th tab for volume, theme, FPS cap
