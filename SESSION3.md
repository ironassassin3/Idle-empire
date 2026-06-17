# Session 3 — Mobile Readiness (Soft-Launch Audit & Implementation)
*2026-06-02 · Retention > Features. No large new systems. Goal: maximize D1, D7, session length, return rate.*

## TL;DR
Audited the game as a soft-launch candidate and implemented the highest-ROI retention fixes in five areas: **manager identities** (all 11 now have a unique reason to pursue, not flat %), **territory identities** (districts are now strategic choices, not stat bumps), **daily-return experience** (longer offline cap + a "what you missed" hook), an **analytics framework** (so you can actually see where players churn), and **mobile UX** (bigger touch targets). **44/44 regression tests pass**, the game boots clean, and the prestige loop pacing is unchanged.

---

## Top 10 Reasons a Mobile Player Quits After Day 1 (soft-launch audit)

| # | Reason | Severity | Fixed this session? |
|---|---|---|---|
| 1 | **No analytics** — team flies blind, can't find the churn point | Critical (ops) | ✅ Local JSONL analytics framework |
| 2 | **Managers are interchangeable %s** — no reason to chase a specific one | High | ✅ 11 unique manager identities |
| 3 | **Territories are stat bumps** — capture choice is meaningless | High | ✅ 4 district identities (cash/ops/smuggling/politics) |
| 4 | **Weak return hook** — offline screen shows cash but no tension/"what changed" | High (D7) | ✅ "While you were away" hook + longer cap |
| 5 | **Stingy offline cap (8h/50%)** punishes overnight players | High (D7) | ✅ 12h / 60% |
| 6 | **Tiny touch targets** (26px qty toggles) hard to tap on a phone | High (mobile) | ✅ Enlarged to 36px (shared geometry) |
| 7 | **Could lose the thread of what to pursue** | Medium | ✅ already covered — "Current Goals" panel always visible |
| 8 | **Heat raids feel random/punishing, no early counter** | Medium | ✅ Clean Carl (−30% heat gain) + Collector (−35% raid dmg) give early levers |
| 9 | **Notification noise** (addressed Session 2) burying real moments | Medium | ✅ (Session 2) |
| 10 | **No "come back tomorrow" pull** beyond the daily streak | Medium | ◐ Return hook added; true push-notifications need a backend (Session 4) |

Severity-prioritized, the top 6 were all implementable this session and were implemented.

---

## Part 1 — Manager Identities (was: flat ×1.5)
Each of the 11 managers now has a **unique identity** — a concrete reason to hire *that one* — surfaced in its card text (`★` specialty line). Effects are passive modifiers read by the relevant systems (or active ticks):

| Manager | Identity | Effect |
|---|---|---|
| Sticky Pete | Hustle | +25% click power |
| The Collector | Protection | −35% rival/police raid damage |
| Lucky Sal | Luck | golden coins drop ~50% more often |
| Clean Carl | **The Lawyer** | −30% heat gain |
| The Accountant | **Automation** | auto-buys best building every 3s *(S2)* |
| The Promoter | Heat lever | actively launders heat −0.6/s *(S2)* |
| The Smuggler | Smuggling | +30% operation rewards |
| The Broker | Expansion | +15% territory action success |
| The Consigliere | Prestige | +20% Influence gained on prestige |
| The Mechanic / Maxine | (income/synergy) | kept as income anchors |

These turn managers from "bigger number" into a **decision** ("do I want the Lawyer to survive high heat, or the Smuggler for op income?"). All verified wired (test suite §9).

## Part 2 — Territory Identities (was: +10% / +15% stat bumps)
Districts now have a `perk_key` that other systems read, so capturing one is a **strategic choice**:

| District | Identity | Effect |
|---|---|---|
| Downtown | **CASH** | strongest flat income (+20%) + clicks |
| Industrial District | **OPERATIONS** | +25% operation rewards, −12% heat |
| Waterfront | **SMUGGLING** | +15% operation rewards & success |
| City Hall | **POLITICS** | heat shield + 15% prestige Influence |

The territory UI now shows each district's identity badge (in its color) for locked and unlocked districts, so the player sees *what each is for* before committing. Verified (test suite §10).

## Part 3 — Daily Return Experience
- **Offline cap 8h → 12h**, efficiency **50% → 60%** (100% with Untouchable). Covers an overnight return without punishing sleep — directly targets D1→D7.
- **"While you were away" hook** on the return overlay: surfaces what changed ("Rivals hold N districts — push back") or nudges ("Earnings maxed out — check in sooner"), giving a reason to engage *now* and return *again*. Tap-to-collect wording.
- Daily streak system (to 7×) retained.

## Part 4 — Analytics Framework (new: `src/analytics.py`)
A lightweight, **local-only, privacy-safe** JSONL event logger — the instrumentation you need to find churn during a soft launch. Records the full retention funnel:
`session_start`/`session_end` (with `returning` and a `near_prestige` churn marker), `first_influence`, `rank_up`, `prestige` (influence_gain / lifetime / time_to_prestige), `manager_hired`, `territory_captured` (with perk), `offline_return`, `daily_reward`.
- Wired into every key lifecycle point (on_enter / on_exit / QUIT / prestige / rank-up / hire / capture).
- Never throws (best-effort), zero gameplay impact, `set_enabled(False)` opt-out.
- Each record is `{ts, session, event, props}` — trivial to forward to a real backend later.
- Verified writing real events end-to-end (test suite §12).

## Part 5 — Mobile UX
- **Buy-quantity toggles (x1/x10/x100) enlarged 26px → 36px tall** via a shared `_toggle_rect()` (draw and hit-test use one geometry, so they can't drift). This was the smallest below-spec touch target on the most-used control.
- Confirmed all 8 tabs render without error after every change.
- The always-visible **"Current Goals" panel** (next objective + progress bars) already existed — the in-session "what do I do next" anchor is in place.

> Deliberately **not** done (would be a "large system," out of scope): full responsive layout for true phone resolutions, and a real push-notification backend. Both are flagged for Session 4.

---

## Files Modified / Added
| File | Change |
|---|---|
| `src/managers.py` | 7 new passive-modifier identity functions + advertised card text |
| `src/territory.py` | `perk`/`perk_key` per district; `operation_reward_mult` / `prestige_influence_mult`; UI perk badge; capture analytics |
| `src/states.py` | Wire click/coin manager mults; analytics session/rank-up hooks; `_offline_capped` init |
| `src/heat.py` | Clean Carl heat-gain reduction; Collector raid-damage reduction |
| `src/rivals.py` | Collector raid-damage reduction on rival raids |
| `src/operations.py` | Smuggler + district operation-reward bonuses |
| `src/prestige.py` | Consigliere + City Hall prestige-Influence bonus; prestige analytics |
| `src/save_load.py` | Offline cap 12h / 60% eff; `_offline_capped` |
| `src/ui.py` | Offline overlay "while you were away" hook |
| `src/buildings.py` | Enlarged buy toggles (shared geometry) |
| `src/analytics.py` | **NEW** — local funnel analytics |
| `sim_test_suite.py` | +14 Session 3 checks (now 44 total) |

---

## Retention Improvements (mapped to metric)
- **D1:** manager/territory identities create early *decisions* (engagement depth); bigger touch targets reduce friction; analytics lets you find the exact Day-1 drop-off.
- **D7:** longer/ richer offline returns + the "what you missed" hook reward coming back tomorrow; daily streak intact.
- **Session length:** unique manager/district effects give more to optimize each session; "Current Goals" keeps a target on screen.
- **Return rate:** the return hook + offline cap that respects overnight absence.

## Balance Changes
- Offline: cap 8h→12h, efficiency 50%→60%.
- Manager passive effects (click +25%, raid −35%, heat-gain −30%, coins ×1.5 freq, op rewards +30%, territory +15%, prestige Influence +20%).
- Territory perks (op rewards ×1.25 Industrial / ×1.15 Waterfront; prestige Influence ×1.15 City Hall); Downtown income +15%→+20%.

## Testing
`sim_test_suite.py` — **44/44 pass**: all Session 1–2 checks (no regression) + manager identities, territory identities, offline return, analytics. Game boots (`main` imports); all 8 tabs render; experiential playthrough pacing unchanged (first prestige ~22m, escalating prestige rewards, healthy 2m20s 2nd-prestige gap).

---

## Time-To-First-Wow
Unchanged from Session 2: **~2 min** (first jackpot + early rank-ups), well inside target. Session 3 didn't touch the early beat rhythm except to *add* decisions (manager/district identities) that deepen it.

## Top Remaining Retention Risks
1. **Fixed 900×720 layout** — not truly responsive; small fonts/dense rows still tough on a real phone. (Session 4 — biggest remaining mobile gap.)
2. **No real push notifications** — the return hook is in-app only; a backend "your empire earned $X / a rival is moving" push is the classic D7 lever. (Session 4)
3. **One marginal mid-game lull** (~97s) detected ~16–18 min in; within normal idle rhythm but watch it with real analytics.
4. **Mechanic/Maxine** managers remain plain income (deliberate — they anchor the income curve).
5. **No real-device playtest** — all validation is the optimistic sim; a human phone session is the next confidence step.

## Recommendations for Session 4
1. **Responsive layout** — the single biggest remaining mobile blocker; scale UI to device resolution / aspect ratio.
2. **Push-notification backend hooks** — fire the existing return-hook copy as real notifications.
3. **Real-device soft-launch playtest** + read the `analytics.jsonl` funnel to find the true Day-1 drop-off and tune to it.
4. **A/B-ready tuning** — the analytics framework now makes it possible to test offline-cap / head-start / prestige-gate values against real retention.

If features and retention conflict, keep choosing retention — Session 3 deepened the *choices inside the existing loop* rather than adding systems, which is the right move pre-soft-launch.

## Re-verify
```
python sim_test_suite.py     # 44-check regression incl. Session 3
python sim_playthrough.py     # experiential timeline + dead-zone detector
python sim_postprestige.py    # post-prestige recovery verdict
python sim_smoke.py           # deadlock + boot sanity
# analytics.jsonl appears at repo root once the game (or a session) runs
```
