# PROJECT_RULES.md — Idle Empire
*Last updated: Phase 13 complete. 44/44 tests passing. Closed-beta candidate.*

---

## Project Status

**Phase 13 is complete.** The game is stable, feature-complete, and playable from fresh save through multiple prestiges.

**Core systems — complete, do not redesign:**

| System | Module | Notes |
|--------|--------|-------|
| Economy / buildings | `src/buildings.py` | 11 buildings, append-only `_DEFS` |
| Upgrades | `src/upgrades.py` | ~27 upgrades, append-only `_DEFS` |
| Prestige + perk tree | `src/prestige.py`, `src/prestige_tree.py` | 13 ranks, 10 perks, 5 tiers |
| Managers | `src/managers.py` | 11 managers, unique per-manager effect |
| Heat | `src/heat.py` | Rise/decay/raids, income + click bonus |
| Territory | `src/territory.py` | 20 districts, attack/bribe/negotiate/sabotage |
| Rivals | `src/rivals.py` | 5 AI factions, genuine AI (growth, raids, war) |
| Crew | `src/crew.py` | 5 roles, real trade-offs |
| Operations | `src/operations.py` | 5 timed missions, success chance formula |
| Syndicate events | `src/events.py` | 6-choice events, fires every 3–6 min |
| Goals | `src/goals.py` | early/mid/late, influence faucet for new players |
| Achievements | `src/achievements.py` | 60+ achievements, toast system |
| Save / load | `src/save_load.py` | Atomic write, backup, version migration |
| Tutorial | `src/tutorial.py` | 5-step first-run + milestone queue |
| Analytics | `src/analytics.py` | Local-only, JSONL, full funnel + first-X events |
| UI | `src/ui.py` | Responsive layout, all overlays |

**Do not add new major systems.** The game does not need more mechanics.

**Acceptable work in this phase:**
- Retention improvements
- Balance tuning
- UX clarity
- Stability fixes
- Onboarding polish
- Analytics / telemetry

---

## Architecture

```
d:\2d_game\
├── main.py               Engine init + MenuState entry point
├── config.py             SCREEN_WIDTH/HEIGHT, FPS, MIN_WIDTH/HEIGHT
├── analytics_report.py   Dev tool: reads analytics.jsonl, prints funnel report
├── sim_smoke.py          Fast sanity test (~5s) — run before every commit
├── sim_test_suite.py     Full 44-test suite (~30s) — run before releases
├── sim_harness.py        Headless economy simulator for balance work
└── src\
    ├── engine.py         Pygame loop, RESIZABLE events, layout invalidation
    ├── state_base.py     GameState ABC, StateManager stack
    ├── states.py         PlayingState (main loop, update, draw dispatch)
    ├── ui.py             All rendering — reinit_layout(), overlays, panels
    ├── theme.py          Colors, fonts, format_number(), format_money()
    ├── buildings.py      Building defs + click handler + specials
    ├── upgrades.py       Upgrade defs + click handler
    ├── managers.py       Manager defs + automation + click handler
    ├── prestige.py       Rank math, can_prestige(), PrestigeManager.execute()
    ├── prestige_tree.py  Perk defs, PrestigeTreeState, apply_perks(), tick_perk_effects()
    ├── heat.py           Heat system, raid logic
    ├── territory.py      District defs, AI war, click handler
    ├── rivals.py         Rival AI, elimination, click handler
    ├── crew.py           CrewAssignment dataclass, role bonuses
    ├── operations.py     Operation defs, timer logic, click handler
    ├── events.py         Syndicate event pool, overlay, outcomes
    ├── goals.py          Goal list, check_goals(), next_focus_hint()
    ├── achievements.py   Achievement defs, check_and_earn(), toast renderer
    ├── achievements_panel.py  AchievementsState (pushed onto stack)
    ├── tutorial.py       5-step overlay, milestone queue, update_overlays()
    ├── save_load.py      apply_save_data(), save_game(), load_game(), _migrate()
    ├── analytics.py      _write(), start/end session, all first-X events
    ├── sound.py          Procedural SFX (no asset files)
    └── pause.py          PauseState (settings, quit)
```

### State Stack

`main.py` → `MenuState` → (player clicks) → `PlayingState`  
ESC → `PauseState` (pushed, not replaced)  
Prestige button → `PrestigeTreeState` (pushed, not replaced)  
Stats tab → achievement btn → `AchievementsState` (pushed)

### Overlay Priority (draw order in `PlayingState.draw`)

1. Syndicate event (`_pending_event`)
2. Offline return summary (`_show_offline_overlay`)
3. Daily reward (`_show_daily_overlay`)
4. Rival elimination (`_elim_overlay`)
5. Milestone/rank-up (`_milestone_queue`)
6. Tutorial steps 0–4

Only one overlay renders at a time. Dismissing one reveals the next.

---

## Critical Rules — Save Compatibility

**Building and upgrade definitions are append-only.**  
`buildings._DEFS` and `upgrades._DEFS` are loaded by index. Adding to the middle breaks all existing saves. Never insert — always append.

**Save migration lives in `save_load._migrate()`.**  
Every new field added to `save_game()` must have a `.get(key, default)` in `apply_save_data()` and a `data.setdefault(key, default)` in `_migrate()`. No exceptions.

**`apply_save_data()` loading order matters.**  
Buildings → Upgrades (apply effects) → Managers → Territories → Rivals → Crew → Operations → Prestige perks (apply_perks) → Return summary snapshot → Offline earnings. Do not reorder; `income_per_second` must be correct before offline earnings are computed.

**Never reset lifetime stats on prestige.**  
`_total_buildings_purchased`, `_total_territories_captured`, `_total_rivals_defeated`, `_total_ops_completed`, `_total_influence_earned`, `_total_respect_earned` survive all prestiges. They gate analytics first-X events.

**Test saves after any `save_game()` / `apply_save_data()` change:**
```
python sim_smoke.py        # quick
python sim_test_suite.py   # full
```

---

## Critical Rules — Economy

**The influence faucet must never be broken.**  
The progression deadlock (fresh save → cannot earn first influence token → ranks never advance → entire game locked) was fixed by adding goal-based influence rewards in `goals.py`. The early goals grant exactly 12 influence (= Made Man) from pure economic play with no token-gate dependency. Do not change the `reward_influence` values on `start_cash_*` goals without re-running the fresh-save smoke test.

**The A/B tuning constants are env-var-driven.**  
Key economy values are read from env vars at module import — do not hardcode them:
| Constant | Env var | Default | File |
|----------|---------|---------|------|
| First prestige earnings gate | `IDLE_PRESTIGE_EARNINGS` | `20_000_000` | `prestige.py` |
| First prestige rank gate | `IDLE_PRESTIGE_RANK` | `"Made Man"` | `prestige.py` |
| Prestige escalation mult | `IDLE_PRESTIGE_GROWTH` | `8.0` | `prestige.py` |
| Offline earnings cap (hours) | `IDLE_OFFLINE_CAP_H` | `12.0` | `save_load.py` |
| Offline earnings efficiency | `IDLE_OFFLINE_EFF` | `0.6` | `save_load.py` |

**Do not introduce:**
- New income sources that bypass the heat system
- Infinite scaling loops (any multiplier stack must have a cap or logarithmic curve)
- Buildings with higher base income/cost ratio than Corner Dealer (it is intentionally the best early-game building)

**Any income-formula change must document:**
- Effect at 0 prestige tokens (fresh player)
- Effect at 10 tokens (mid-game)
- Effect at 100 tokens (late-game)

---

## Critical Rules — Prestige

**Prestige must always feel rewarding, never punitive.**  
Prestige is a **hard reset** (Phase 20): buildings, income, heat, crew, rivals, territory and operations all wipe back to a fresh-start state — there is **no** building head start (the old `_apply_head_start` was removed). What makes it rewarding instead of punitive is the **enhanced bonus that persists**: the prestige Influence multiplier (`prestige.income_mult`) plus perks/rank carry over, so the rebuild from zero is dramatically faster than the first run and quickly rockets past the prior peak. The feeling to preserve is "a semi-fresh restart, but I'm permanently stronger now" — not "I kept my buildings." Do not re-introduce a building head start.

**The prestige confirmation dialog is mandatory.**  
Prestige is irreversible within a run. The confirm → YES/NO dialog in `PrestigeTreeState` must always be present.

**Perks must have verifiable effects.**  
Every perk in `_PERK_DEFS` must have a matching implementation in `apply_perks()` or `tick_perk_effects()`. The `PERK_DETAILS` dict must accurately describe what the perk does — it is a promise to the player.

**Near-prestige flags reset on every prestige:**
```python
# In PrestigeManager._do_execute — do not remove
state._push_near_prestige_fired = False
state._notif_near_prestige_80 = False
```

---

## Critical Rules — Tab Gating

Tab visibility is controlled by `prestige.visible_tabs(state)`. Current gates:

| Tab | Minimum influence (prestige_tokens) |
|-----|-------------------------------------|
| Buildings | 0 (always) |
| Empire (→ Upgrades, Managers, Territory, Rivals) | 0 (always — fixed in Phase 12) |
| Crew | 1 (Crew Member rank) |
| Operations | 12 (Made Man rank) |
| Stats | 0 (always) |

Do not add new token gates to early content. The deadlock was caused by exactly this pattern. If gating is needed, use cash thresholds or building counts instead.

---

## Critical Rules — Tutorial & Onboarding

**Every milestone overlay must answer: what do I do next?**  
The `next_focus_hint(state)` in `goals.py` provides a contextual one-liner. Keep it accurate and honest — do not show hints for actions the player can't currently take.

**Tutorial steps fire in order and each waits for the correct trigger:**
1. Step 0: click the click button
2. Step 1: buy any building
3. Step 2: open the Upgrades subtab
4. Step 3: open the Managers subtab
5. Step 4: open prestige tree (auto-advances after 6 seconds)

**The milestone queue is the right place for system explanations.**  
When a player first encounters heat/raids, operations, influence, territory — queue a milestone popup (`state._milestone_queue.insert(0, "TITLE\nbody\n...")`). These are already gated by `_shown_*` flags to appear exactly once.

**Avoid walls of text.** Every tutorial/milestone message must be readable in under 4 seconds.

---

## Critical Rules — Analytics

**Analytics never raises and never blocks the game.**  
Every analytics call is wrapped in `try/except`. This is non-negotiable.

**First-X events fire on lifetime firsts, not session firsts.**  
These events carry `session_time_s` (elapsed seconds since session start) for beta funnel analysis. They fire exactly once per player lifetime, gated by `_total_*` lifetime stats:
- `first_building` — gated by `_total_buildings_purchased == 0`
- `first_upgrade` — gated by no upgrades purchased
- `first_manager` — gated by no managers hired
- `first_territory` — gated by `_total_territories_captured == 0`
- `first_rival_defeat` — gated by `_total_rivals_defeated == 0`
- `first_operation` — gated by `_total_ops_completed == 0`
- `first_influence` — gated by `_total_influence_earned == 0`

**`analytics.jsonl` is local-only and opt-out capable.**  
No PII is collected. `analytics.set_enabled(False)` fully disables writes. Any future backend integration must go through `_push_deliver()` — do not add network calls anywhere else.

To read beta data: `python analytics_report.py`

---

## Critical Rules — UI / Rendering

**All layout values come from `ui.reinit_layout(w, h)` — never hardcode pixel positions.**  
The game supports any window size from 480×480 to unlimited. Use `ui.CLICK_RECT`, `ui.PRESTIGE_RECT`, `ui.RIGHT_X`, `ui.HEADER_H` etc. everywhere.

**All colours come from `src/theme.py`.** No raw RGB tuples in rendering code.

**All timing uses `dt` (delta time).** No `time.sleep()`, no frame-count logic.

**Overlay pattern for new blocking screens:**
```python
# In draw chain (states.py PlayingState.draw):
elif <condition>:
    ui.draw_my_overlay(surface, self, self._fonts)

# Dismiss in _dismiss_overlay():
if <my condition>:
    self._my_flag = False
    return True
```

**Tooltip system already exists.** Use `ui.set_tooltip(key)` on hover and `ui.TOOLTIPS` for the text. Do not build separate tooltip mechanisms.

---

## Code Style

- PEP 8: `snake_case` functions/vars, `PascalCase` classes, `UPPER_CASE` module constants
- Files over ~300 lines: extract helper functions into a new module
- No `from pygame.locals import *` — explicit imports only
- No new pip dependencies — pygame-ce only
- Comments only for non-obvious WHY, not for describing WHAT the code does

---

## Testing Protocol

Before any commit:
```bash
python sim_smoke.py          # must pass (~5s)
python -m py_compile src/*.py  # no syntax errors
```

Before any release:
```bash
python sim_test_suite.py     # all 44 must pass (~30s)
```

Manual verification checklist:
- [ ] Fresh save (delete `save.json`, run `main.py`)
- [ ] Existing save loads without error
- [ ] After prestige: buildings/income hard-reset to 0, influence increases, prestige income multiplier persists (faster rebuild)
- [ ] Offline earnings overlay appears on return after >1 min away
- [ ] Tutorial completes without softlock

For balance changes: use `python sim_harness.py` to run headless simulations.

---

## Anti-Patterns — Things We Tried That Failed

**The progression deadlock.** Gating tab visibility behind influence tokens when influence tokens can only be earned from those same tabs. This made the game mathematically unwinnable from a fresh save. The fix: early goals grant influence from pure cash play, independent of any tab gate.

**Perk keys that drift from their implementation.** Old perks (`untouchable`, `the_network`, `crew_loyalty`) were removed but their string keys lingered in migration code and produced silent dead branches. Always clean up both the `_PERK_DEFS` definition and the `apply_perks()` / `tick_perk_effects()` implementation together.

**Hardcoded pixel positions.** Before `reinit_layout()`, every panel coordinate was a magic number. The layout broke on any window size other than 900×720. Always use the layout globals.

**Manager income with no unique hook.** Early managers were "+1.5× income" clones. Each manager now has a named, unique effect (Sticky Pete = click power, The Promoter = active heat lever, etc.). Do not add managers that are pure income multipliers.

---

## Current Priority Order

1. Beta launch readiness — resolve MAJOR blockers from Phase 13 report
2. Retention polish — return-to-game experience, offline world simulation
3. Balance tuning — use `sim_harness.py` and `analytics_report.py` data
4. Stability — fix any crashes or invalid states discovered in beta
5. UX clarity — surfacing what players miss (e.g. prestige button unlock hint)
6. New content — only if a genuine content gap is identified from telemetry

Do not reorder. New content is last because telemetry will tell us what players actually want, not what we assume.

---

## Known Open Issues (Phase 13 exit)

**MAJOR — Prestige button gives no hint when locked.**  
Players click it, enter the perk tree, and see a requirements list buried in the UI. A badge or inline text on the button face showing the blocking condition would prevent abandonment at the prestige gate.

**MAJOR — Rivals are static offline.**  
Rivals do not tick during offline periods. The return summary shows rival counts but they reflect the same state as when the player left. For the "living city" promise to hold, rivals need a fast-forward offline simulation step in `apply_save_data`.

**MINOR — No analytics opt-out in settings UI.**  
`analytics.set_enabled(False)` exists but is not exposed to the player. For GDPR compliance a toggle is needed in the pause/settings panel.

**MINOR — `analytics.jsonl` has no size cap.**  
For extended beta periods, this file will grow. Add rotation or a max-line cap.
