# Session 4 Handoff — Idle Empire

## PROMPT FOR NEXT SESSION

> Read `HANDOFF_SESSION4.md` and continue with Session 4.

Everything needed to act is below; deeper detail lives in `SESSION1.md`, `SESSION2.md`, `SESSION3.md` and the memory files.

---

## SESSION 4 — Real-Device Mobile Layout & Live-Ops Readiness

Sessions 1–3 fixed the progression deadlock, the economy, the post-prestige loop, manager/territory identities, daily return, and added a local analytics framework. The game is mechanically sound and instrumented. Do NOT revisit that work unless a test proves a regression.

This session is the **last mile before a soft launch**: making the game actually playable and addictive on a phone, and making the analytics actionable.

### Priorities (retention > features, as always)
1. **Responsive layout (highest priority).** The game is hard-coded to 900×720 desktop with small fonts and dense rows. Make the UI scale to real device resolutions / portrait aspect ratios. This is the #1 remaining mobile blocker.
2. **Real return-hook delivery.** The "while you were away" copy exists in-app only. Add push-notification *hooks* (fire-points + payload), even if the actual platform delivery is stubbed, so a backend can wire in later.
3. **Analytics → action.** Add a tiny offline reader/summarizer for `analytics.jsonl` (funnel counts, median time-to-first-prestige, session length, return rate, `near_prestige` churn rate) so the data is usable. Then make the key tuning constants A/B-ready.
4. **Real-device playtest** (or the closest possible) and tune to what the funnel shows.

### Process (same as prior sessions)
- Delete all saves first; verify fresh; test on a fresh account.
- Use the existing sim tools to prove no regression BEFORE and AFTER: `python sim_test_suite.py` (must stay green), `python sim_playthrough.py`, `python sim_postprestige.py`, `python sim_smoke.py`.
- Don't add large new gameplay systems. Deepen/deliver the existing loop.

### Deliverables
Findings, files modified, retention improvements, before/after where measurable, remaining risks, and a Session 5 recommendation. Write `SESSION4.md`.

---

## CURRENT STATE (as of end of Session 3, 2026-06-02)

**Status: mechanically complete, instrumented, soft-launch-candidate pending mobile layout.**
- Window: **900 × 720** (`config.py`), Pygame, `python main.py` → Enter to start.
- Python: project uses `C:\Users\irona\AppData\Local\Python\pythoncore-3.14-64\python.exe` (path stored in `graphify-out\.graphify_python`). pygame-ce 2.5.7.
- All sim/test tools run headless via `SDL_VIDEODRIVER=dummy`. Set `PYTHONIOENCODING=utf-8` when a script prints notification text (arrows/symbols).

### What's been fixed (do not redo)
- **Session 1:** progression deadlock broken (`prestige.visible_tabs` gates tabs on economic progress, not Influence; starter goals in `goals.py` grant 12 Influence by $1M lifetime; Downtown capturable at 0 Influence). Building economy rebalanced so income/$ RISES with tier.
- **Session 2:** post-prestige **head start** (`PrestigeManager._apply_head_start`) — recovery 12m12s→~45s; **escalating prestige gate** (`_next_prestige_earnings = lifetime × 8`, persisted); escalating Influence rewards; Chop Shop proc silenced; Accountant auto-buy + Promoter heat-laundering.
- **Session 3:** 11 **manager identities** (passive-modifier functions in `managers.py`, read across heat/rivals/operations/territory/prestige/states); 4 **territory identities** (`perk_key` in `territory.py`: cash/operations/smuggling/politics); offline cap **12h / 60%** + "while you were away" hook; **`src/analytics.py`** local JSONL funnel logger wired everywhere; buy-quantity toggles enlarged to 36px (`_toggle_rect`).

### Key tuning constants (where to adjust balance)
- `src/prestige.py`: `FIRST_PRESTIGE_EARNINGS` ($20M), `PRESTIGE_EARNINGS_GROWTH` (8×), `calc_influence_gain` (log²/5.0), `PrestigeManager._HEAD_START_*` (40% base, +5%/prestige, 75% cap).
- `src/buildings.py`: `_DEFS` base_income curve (`cost × 0.002 × 1.45^tier` from Racket up; Dealer 0.10).
- `src/save_load.py`: `OFFLINE_CAP_SECONDS` (12h), offline efficiency (0.6).
- `src/managers.py` / `src/territory.py`: identity effect magnitudes.

### Verification baseline (must stay true)
- `python sim_test_suite.py` → **44/44 pass**.
- First prestige ~20–22 min (sim, optimistic floor; ~30–45 min real). 2nd-prestige gap ~2m20s, rewards escalate (+11 → +13/+14 Influence).
- Time-to-first-wow ~2 min. No dead zones >90s except one marginal ~97s lull at ~16–18 min (watch with real analytics).

### Known limitations / risks carried into Session 4
1. **Fixed 900×720 layout** — not responsive; the biggest real-device blocker.
2. **No real push notifications** — return hook is in-app only.
3. **Analytics has no reader** — `analytics.jsonl` accumulates but nothing summarizes it yet.
4. **All validation is the optimistic sim** — no human/real-device playtest yet.
5. `HANDOFF.md` (root) is STALE (pre-Session-1). Trust `SESSION1/2/3.md` + memory files instead.

### Tooling map
- `sim_smoke.py` — boot + deadlock sanity.
- `sim_test_suite.py` — 44-check regression (fresh/prestige/2nd-prestige/save/ach/managers/territory/heat/identities/offline/analytics).
- `sim_playthrough.py` — experiential timeline + dead-zone detector (real PlayingState).
- `sim_postprestige.py` — post-prestige recovery time + GOOD/BAD verdict.
- `sim_harness.py` / `sim_project.py` / `sim_econ.py` — economy/pacing sims.
- Memory: `progression_deadlock.md`, `economy_flat_curve.md`, `prestige-retention.md`, `mobile-readiness.md`, `sim_harness_tool.md` (all FIXED-status where applicable).
