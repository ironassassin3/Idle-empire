# Session 4 — Real-Device Mobile Layout & Live-Ops Readiness

**Date:** 2026-06-02  
**Status:** All four priorities delivered. 44/44 tests pass. Soft-launch candidate.

---

## What Was Done

### 1. Responsive Layout (Priority 1 — highest)

The game was hard-coded to 900×720. Now it scales to any window size, including portrait phones.

**Files changed:** `src/ui.py`, `src/engine.py`, `src/theme.py`, `config.py`, `src/states.py`

**How it works:**
- `ui.reinit_layout(w, h)` recomputes all layout globals from the actual window dimensions. Call it on startup and on every `VIDEORESIZE` event.
- `engine.py` now opens the window with `pygame.RESIZABLE` and calls `_apply_layout` on resize. Cached surfaces (glow, bg) are invalidated automatically.
- `theme.make_fonts(screen_height)` scales all font sizes proportionally. Fonts are re-created and propagated to active states on resize.
- `config.MIN_WIDTH = 480`, `config.MIN_HEIGHT = 480` are enforced as hard floors.
- **Portrait mode** (`w < h` or `w < 600`): `RIGHT_X = 0`, the click zone stays at top, the right panel starts immediately below the prestige button. Scene panel and stat cluster are hidden. Objectives panel is suppressed.
- **Landscape mode**: same split logic as before — left panel ~46% width (min 260, max 420), right panel fills the rest. All constants scale with window size.
- Tab widths (`_TAB_W_MAIN`, `_SUBTAB_W`) scale to fit the right panel width.

**Verified layout math at key sizes:**
| Size | Mode | RIGHT_X | Click rect |
|------|------|---------|-----------|
| 900×720 | landscape | 418 | 259×259 |
| 600×480 | landscape | 279 | 172×172 |
| 480×800 | portrait | 0 | 260×260 |
| 360×640 | portrait | 0 | 223×223 |
| 1920×1080 | landscape | 420 | 260×260 |

**Known limitations:** `draw_scene` (the city animation) is skipped in portrait mode — no room for it below the click zone. The stat cluster (clicks / crew / mult) is also hidden in portrait. Both are non-critical for gameplay.

---

### 2. Push-Notification Hooks (Priority 2)

**File:** `src/analytics.py`

Four fire-point functions added:
- `push_offline_idle(secs_idle, projected_earnings, prestige_pct)` — call from backend when player has been away long enough. Phrases the message based on context (near-prestige > earnings > generic).
- `push_near_prestige(lifetime, needed)` — fires in-session at 90% of prestige gate. Also queued as a delayed background push ("you were so close"). Wired into `states.py` update loop.
- `push_rival_threat(rival_name, aggression)` — urgency hook for rival AI events.
- `push_daily_reminder(streak)` — daily streak protection.

All calls route through `_push_deliver(title, body, payload)` which logs the push as an analytics event. To go live: replace `_push_deliver` with a platform SDK call (APNs / FCM / local notifications).

The `_push_near_prestige_fired` flag on the state resets after each prestige so the hook fires once per run.

---

### 3. Analytics Reader (Priority 3)

**File:** `analytics_report.py` (new)

Run: `python analytics_report.py [--file analytics.jsonl] [--json]`

Reports:
- **Sessions:** total, returning count, return rate
- **Session length:** median (with ⚠ if <2 min)
- **Return gap:** median gap between sessions (flags >24h as push-notification opportunity)
- **Prestige funnel:** total prestige events, median time-to-first-prestige (flags >60m as churn risk, <15m as too easy)
- **Churn signals:** near-prestige exit rate (flags >30% as nudge opportunity)
- **Funnel breadth:** first building, first influence, prestige conversions
- **Rank progression:** count of each rank-up event
- **Push hooks:** total logged, trigger types
- **Recommendations:** actionable bullet points based on the data

`--json` flag outputs machine-readable JSON for dashboard integration.

---

### 4. A/B-Ready Tuning Constants (Priority 4)

**Files:** `src/prestige.py`, `src/save_load.py`

All key balance constants now read from env vars at import time:

| Env var | Default | Controls |
|---------|---------|---------|
| `IDLE_PRESTIGE_EARNINGS` | 20000000 | First prestige gate ($) |
| `IDLE_PRESTIGE_DEALERS` | 20 | First prestige dealer count gate |
| `IDLE_PRESTIGE_RACKETS` | 8 | First prestige racket gate |
| `IDLE_PRESTIGE_CHOPS` | 4 | First prestige chop gate |
| `IDLE_PRESTIGE_RANK` | "Made Man" | First prestige rank gate |
| `IDLE_PRESTIGE_GROWTH` | 8.0 | Escalation multiplier per prestige |
| `IDLE_OFFLINE_CAP_H` | 12 | Offline earnings cap (hours) |
| `IDLE_OFFLINE_EFF` | 0.6 | Offline earnings efficiency (0–1) |

Usage: `IDLE_PRESTIGE_EARNINGS=10000000 IDLE_PRESTIGE_GROWTH=6 python main.py`

These are evaluated once at module import, so they're safe for A/B testing via launch args on desktop. For mobile, set them via a remote config system before the module loads.

---

## Regression Results

| Suite | Before | After |
|-------|--------|-------|
| `sim_test_suite.py` | 44/44 | **44/44** |
| `sim_smoke.py` | PASS | **PASS** |
| `sim_postprestige.py` | GOOD | **GOOD (1m35s recovery)** |

---

## Remaining Risks / Session 5 Recommendations

1. **Real-device playtest still needed.** The layout is now mathematically correct but untested on an actual phone. Priorities:
   - Does the click zone feel large enough on a 360dp screen?
   - Does scrolling in the buildings tab work with touch?
   - Does the tab bar have fat-finger-friendly hit targets in portrait?

2. **Push notifications not wired to platform.** The fire-points are in place; `_push_deliver` needs a platform SDK implementation. On Windows/desktop this is a no-op. On mobile (if porting to pygame-ce Android or Kivy), hook it up in Session 5.

3. **Analytics still thin.** Until there are real sessions, the analytics reader reports mostly zeros. After even 5–10 real playthroughs, the funnel will be readable.

4. **Portrait UI is functional but not polished.** The click zone and right panel are correctly positioned but the city scene, stat cluster, and objectives panel are hidden. A future session could add a compact portrait-specific header for those stats.

5. **`sim_playthrough.py` dead-zone check.** The 97s lull at ~16–18 min noted in Session 3 should be re-checked with a real player — the sim optimises optimally, real players take longer buying decisions.

### Suggested Session 5 focus
- **Real-device smoke test** (even on an emulator) with touch-input verification.
- **Portrait UI polish:** compact stats bar at top of portrait mode instead of hiding everything.
- Wire `_push_deliver` to Windows toast notifications as a proof-of-concept (winrt / plyer).
- `analytics_report.py` integration test: run 3–5 real playthroughs and review the output.
