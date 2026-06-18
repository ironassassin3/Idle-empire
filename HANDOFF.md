# Repo handoff — Criminal Empire

> **Start here:** [`README.md`](README.md) · **Ship target:** [`godot/`](godot/) · **Roadmap:** [`ROADMAP.md`](ROADMAP.md)

This file preserves **early pygame session notes** (2026-05-31). Mechanics and architecture below are **historical** — the live product is Godot.

**Current session handoff:** [`godot/P2_HANDOFF.md`](godot/P2_HANDOFF.md)  
**Mechanics rules:** [`PROJECT_RULES.md`](PROJECT_RULES.md) · **Retention/pacing:** [`P9_REPORT.md`](P9_REPORT.md)

---

# Session Handoff — 2D Idle Clicker (Pygame) *(archived)*

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

## Architecture Snapshot *(historical — game has grown significantly since)*

See [`graphify-out/port/GRAPH_REPORT.md`](graphify-out/port/GRAPH_REPORT.md) for current pygame↔Godot map.

---

## Save File Compatibility

`save.json` uses index-based arrays for buildings/upgrades/achievements. New entries were appended to the END of each `_DEFS` list — old saves load correctly (missing indices default to 0/False).

---

## Known Constraints / Rules *(2026-05-31 — superseded by CLAUDE.md / PROJECT_RULES.md)*

- All animation timing must use `dt` — no frame-dependent logic
- No new pip dependencies beyond pygame-ce
- Buildings/upgrades/achievements data: **append only** to keep save compat
