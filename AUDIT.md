# Idle Empire — Comprehensive Game Audit
*Prepared 2026-06-02 · Lead Game Designer / Economy / Systems / UX / Retention / LiveOps / Idle Expert / Tech Architect / QA*

**Scope:** Audit-only. No large new systems built this pass. All conclusions are grounded in a fresh-save headless simulation (`sim_harness.py`, `sim_project.py`, `sim_econ.py`) running the game's real economic formulas, plus a full read of all 30 modules and a knowledge-graph pass (`graphify-out/`).

**Headline:** The game is feature-rich and architecturally clean, but it is **mathematically unwinnable from a fresh save.** A new player cannot earn their first prestige token within 12+ hours of optimal play, so ranks never advance, most of the game stays locked, and prestige never opens. This single defect dwarfs every other issue. Fixing it is the entire job of the next session.

---

## 1. System Inventory

### What exists (and is wired into the live loop)
| System | Module | Status | Notes |
|---|---|---|---|
| State machine | `state_base.py`, `states.py`, `pause.py`, `engine.py` | **Solid** | Clean `GameState`/`StateManager` stack, dt-driven. Matches CLAUDE.md guidelines. |
| Buildings (11) | `buildings.py` | **Works, flat economy** | Income, cost-scaling, per-building "specials". |
| Upgrades (~27) | `upgrades.py` | **Works but unreachable** | Click mults, per-building 2x/4x, global, prestige synergy. Lives inside the Empire tab → token-gated. |
| Managers (11) | `managers.py` | **Works, gated at Capo** | Flat +1.5× per building. Pure % boost (the brief explicitly warns against this). |
| Prestige + ranks | `prestige.py`, `prestige_tree.py` | **Works, unreachable** | 13 ranks, log influence formula, 10-perk tree. Good confirm/preview UI. |
| Heat | `heat.py` | **Works** | Rise/decay, income & click bonus, raids. Reasonably tuned. |
| Territory (5) | `territory.py` | **Works, double-gated** | Attack/Bribe/Negotiate/Sabotage. Needs tokens to open AND tokens to act. |
| Rivals (5 AI) | `rivals.py` | **Works, gated** | Genuinely good AI: growth, raids, rival-vs-rival, elimination. Behind Empire tab. |
| Crew assignment | `crew.py` | **Works, gated** | 5 roles, real trade-offs. Behind Crew tab (Associate). |
| Operations (5) | `operations.py` | **Works, gated at Boss** | Timed missions w/ success chance. |
| Syndicate events | `events.py` | **Works** | 6 choice events every 3–6 min. Not gated — good. |
| Goals (15) | `goals.py` | **Works** | Early/mid/late, cash + influence rewards. The intended deadlock escape, but too slow. |
| Achievements (60+) | `achievements.py` | **Works** | Money/click/building/prestige/manager/time/secret + toasts. |
| Offline earnings | `save_load.py` | **Works** | 8h cap, 50% (100% w/ perk). Overlay on return. |
| Daily reward | `save_load.py` | **Works** | Streak to 7×. |
| Save/load | `save_load.py` | **Robust** | Atomic temp-write, backup, version migration. Best-engineered subsystem. |
| Tutorial | `tutorial.py` | **Works** | 5-step first-run + milestone queue. |
| Sound | `sound.py` | **Works** | Procedural buffers, no asset files. |
| Theme/UI | `theme.py`, `ui.py` | **Works** | Centralized colors/fonts/number-format; `ui.py` is large (panel dispatch hub). |

### Unfinished / vestigial
- **`sim.py`** (repo root) — an *older, separate* standalone income model with its own `prestige_tokens += 1` loop and milestone tracking. Not imported by the game. Dead/legacy; either delete or repurpose as a balance tool.
- **`capture.py`** — dev screenshot utility (PowerShell window grab). Fine to keep, not game logic.
- **Heat lawyer/bribe tools** (`reduce_heat`) — defined but I found no UI surfacing them; heat is only managed passively (nightclub, crew, territory). The "tools to manage heat" the design calls for are half-built.
- **Operations success/`heat_gain` partial-loss math** is implemented but players rarely reach it (Boss-gated).

### Redundant / overlapping
- **Two influence currencies that are actually one field.** `prestige_tokens` and `influence` are tracked separately, but `prestige_tokens` is *also* called "Influence" in the UI, drives ranks, and is spent in the perk tree. `influence` is a second number ("Respect") that does almost nothing mechanically. This is confusing in code and UI.
- **Goals vs Achievements vs Milestones** — three parallel "you did a thing" systems with overlapping triggers (e.g. cash thresholds appear in all three). Not harmful, but noisy.

---

## 2. Progression Analysis (fresh save, simulated)

Method: `SimState` reproduces the live `income_per_second` / `click_value` formulas exactly; AI player clicks 3×/s for 20 min then idles, buys greedily by income/cost ratio, hires managers/upgrades when affordable.

**Time-to-milestone (fresh save):**
| Milestone | Time | Verdict |
|---|---|---|
| 2nd building | 1s | ✅ instant |
| 5 Corner Dealers | 5s | ✅ |
| First upgrade (if reachable) | 27s | ⚠️ but upgrades are token-gated → a real player sees this **never** |
| First Protection Racket | 29s | ✅ |
| First Chop Shop | 4m11s | ✅ ok |
| **First territory** | **NEVER** | ❌ needs 10 tokens |
| **First manager** | **NEVER** | ❌ needs Capo (25 tokens) |
| **First prestige available** | **NEVER (>12h)** | ❌ **deadlock** |
| **First rank-up (Crew Member)** | **NEVER** | ❌ needs 1 token, no faucet |

**Deadlock-escape projection (`sim_project.py`):** the only token source not behind a token gate is the `cash_100m` goal (+1 Influence at $100M lifetime).
- WITHOUT upgrades (what a real fresh player gets): **$100M is not reached in 12 hours.** Final lifetime @12h ≈ $57M.
- WITH upgrades (hypothetical, requires breaking the gate): $100M at **10h34m**.

**Dev save corroboration:** `save.json` = 26 min played, $145K lifetime, rank Street Hustler, 0 tokens, 0 managers, buildings `[30,9,10,2,0,...]`. The developer's own longest run never escaped tier 3 or earned a token.

**Pacing problems:**
1. **Hard wall at minute ~5.** After the first chop shop, nothing new unlocks. No rank-up, no tab opens, no prestige goal moves. Pure number-go-up with no events of consequence for hours.
2. **The first 20 minutes are the entire game a new player will ever see** before quitting — and they're the most barren.

---

## 3. Retention Analysis

**Why a player quits in the first 5 minutes:**
- After buying a few dealers/rackets the screen stops changing. Only two tabs (Buildings, Stats) exist. There is no visible goal that feels close. The "Empire/Crew/Operations" tabs are absent with no explanation of how to unlock them.

**Why a player quits at 30 minutes:**
- Still Street Hustler. Still 2 tabs. Income crept from 35/s to ~150/s — numbers rising with zero new decisions. The prestige button is visible but permanently locked with requirements ("Made Man rank") that have no reachable path. This reads as *broken*, not *aspirational*.

**Why a player quits after first prestige:**
- N/A — **no player reaches first prestige.** This is the most important sentence in the audit. The entire meta-progression layer (perk tree, rank unlocks, territory, rivals, operations, managers) is content almost no one will ever see.

**Structural retention gaps (even after the deadlock is fixed):**
- Flat economy (Section 4) means "what to buy" is never an interesting decision.
- Managers are flat % boosts, not the "level up / unique effect / unlock gameplay" the design wants.
- No anticipation mechanics: nothing counts down toward a reward the player is watching for in the first hour.

---

## 4. Economy Analysis

**Building income scaling (`sim_econ.py`):** income-per-dollar *decreases monotonically* by tier:
```
Corner Dealer      0.0100 inc/$   payback   100s   ← best in game
Protection Racket  0.0040          250s
Chop Shop          0.00175         571s
...
Crime Syndicate HQ 0.00004 inc/$   payback 26,667s ← 250× worse
```
**Implication:** the cheapest building is always the best value. There is never a moment where buying a *new* tier is mathematically better than buying more of an old one — higher tiers are just price-gated cash sinks. A healthy idle curve (AdVenture Capitalist) has each tier *overtake* the previous once unlocked. This one never does.

- **Cost scaling** 1.15 (tier 1) / 1.18–1.20 (rest): shallow. No pressure to diversify or to stop at a tier.
- **Upgrade scaling:** 2x/4x per-building and global multipliers are well-placed *in principle*, but unreachable in practice (token gate).
- **Prestige scaling:** `influence = round(log10(lifetime)² / 5.5)`. Reasonable logarithmic shape, but with no reachable prestige it's untested in the wild. Token income bonus is +2%/token (multiplicative) — fine.
- **Manager scaling:** flat ×1.5 per building, ×casino bonus. Single dimension.
- **Heat scaling:** rise ≈ 0.01/s + 0.0003/building, decay 0.004/s, income bonus +0.8%/pt above 50, raids at 60+. Net: heat drifts up to the 50–65 band and parks there. Functional, mild, not yet a "meaningful decision" because the player has no active levers exposed early.

---

## 5. Feature Utilization

| System | Likely real-world usage | Provides a decision? | Verdict |
|---|---|---|---|
| Buildings | 100% | Weak (always buy cheapest) | Cosmetic-tier decision |
| Upgrades | ~0% (gated) | Would be yes | **Stranded content** |
| Clicking | High early, then 0 | No | Fine for an idle |
| Heat | Passive only | Not early | Under-exposed |
| Events | Medium (every 3–6 min) | **Yes** | Best decision system in the game |
| Territory/Rivals/Crew/Ops | ~0% (gated) | Yes (good!) | **Stranded content** |
| Managers | ~0% (Capo-gated) | No (flat %) | Stranded + shallow |
| Goals/Achievements | Passive | No | Dopamine drip, fine |
| Prestige/perks | ~0% | Yes | **Stranded — the whole meta** |

The tragedy: the systems that *do* offer real decisions (rivals, crew, operations, events, prestige perks) are exactly the ones locked away. The game's best content is invisible.

---

## 6. UI Analysis

- **Hidden information / unclear goals:** A fresh player has no on-screen explanation of *how* to unlock Empire/Crew/Operations. The locked Prestige panel lists requirements ("Made Man") with no hint that the path is currently impossible.
- **The two-currency confusion:** "Influence" (prestige_tokens) vs "Respect" (influence) are easy to conflate; Respect has almost no use.
- **`ui.py` size:** the central dispatch/draw hub is large (>300 lines, exceeds CLAUDE.md's refactor threshold). It's the natural place for tech-debt to accumulate; candidate for splitting (header, panels, overlays).
- **Positives:** strong visual hierarchy, good number formatting, pulse/shimmer affordances on buyable items, clean confirm/preview on prestige, notification stack + toasts + ticker all polished. The *feel* is commercial-grade; the *content gating* is the problem, not the chrome.

---

## 7. Competitive Analysis — what successful idles do that this doesn't

| Principle (from AdVenture Capitalist / Cookie Clicker / Realm Grinder / NGU / Trimps / Paperclips) | Idle Empire today |
|---|---|
| **First prestige in 30–90 min, reachable by pure play** | ❌ unreachable ever |
| **Each building tier overtakes the last once unlocked** | ❌ monotonically worse |
| **Managers/automation as a felt power spike** | ⚠️ flat %, gated |
| **A constant "next unlock" visible & approaching** | ❌ wall at min 5 |
| **Prestige currency earned from the core loop** | ❌ only from gated side-systems |
| **Meaningful risk/reward choices early** | ⚠️ events yes, heat under-exposed |
| **Offline progression that excites on return** | ✅ present & good |
| **Layered long-term meta (multiple prestige layers)** | ⚠️ exists (perk tree) but stranded |

---

## 8. Top 10 Highest-Impact Improvements (ranked by ROI)

Ranking key: **Impact** = player/retention value, **Effort** = dev time. Sorted by Impact/Effort.

| # | Improvement | Effort | Player Impact | Retention Impact |
|---|---|---|---|---|
| **1** | **Break the token deadlock.** Award the first 1–3 Influence tokens from pure economic play: ungate the **Upgrades** subtab entirely, and add early cash/building goals that grant +1 Influence at reachable thresholds ($10K, $100K, 10 buildings). | **Low** | **Critical** | **Critical** |
| **2** | **Ungate the side-systems' entry points.** Make Empire (territory/rivals) visible much earlier (rank 0–1), even if individual actions still cost tokens. Let players *see* and reach the faucets. | Low | High | High |
| **3** | **Rebalance the building curve** so each tier overtakes the previous in inc/$ once owned (raise late-tier base_income or flatten the inc/$ decay). Makes "what to buy next" a real decision. | Medium | High | High |
| **4** | **Add a dev/cheat console** (add money/influence, force prestige, unlock territory, spawn event, reset save, view hidden stats). Turns balance iteration from hours into seconds. *(You explicitly asked for this; it accelerates every other fix.)* | Low | (dev) | (dev) |
| **5** | **Make the first prestige reachable in ~45–60 min** and re-tune `FIRST_PRESTIGE_*` against the sim once #1–3 land. | Low | High | High |
| **6** | **Give managers a second dimension** (levels, or a unique unlock each) instead of flat ×1.5. | Medium | Medium | High |
| **7** | **Expose heat tools early** (lawyer/bribe buttons already coded in `reduce_heat`) so heat becomes an active choice, not passive drift. | Low | Medium | Medium |
| **8** | **Collapse the two-currency confusion** — either give "Respect"/`influence` a real purpose or merge it into the Influence display. | Low | Medium | Low |
| **9** | **Add a persistent "Next Unlock" tracker** to the header so there's always a visible, approaching goal in the first hour. | Low | Medium | High |
| **10** | **Refactor `ui.py`** into header/panels/overlays modules (CLAUDE.md compliance) before it grows further. | Medium | (none) | (maintainability) |

---

## 9. Recommended Roadmap — Next 10 Development Sessions

1. **Session 1 — Dev console + sim harness hardening.** Build the in-game debug overlay (add money/influence, force prestige, unlock territory/tab, spawn event, reset, hidden stats). Wire `sim_harness.py` as the canonical balance check. *Unblocks all iteration.*
2. **Session 2 — Break the deadlock (Improvement #1 & #2).** Ungate Upgrades; add early influence-granting goals; surface Empire early. Re-run sim until a fresh player reaches Crew Member in <10 min and can act on territory/rivals.
3. **Session 3 — First-prestige loop (#5).** Tune so prestige is available ~45–60 min and *feels* like a power spike. Verify the post-prestige restart is faster and stronger.
4. **Session 4 — Building curve rebalance (#3).** Make tiers overtake; re-tune upgrade/cost anchors against the sim. Validate "what to buy next" changes over a run.
5. **Session 5 — Manager depth (#6) + heat tools (#7).** Managers get levels/unique effects; expose lawyer/bribe. Heat becomes an active risk lever.
6. **Session 6 — Mid-game pacing pass.** With the gates open, walk minutes 30–180 in the sim; close any new dead zones; tune rival/operation token yields.
7. **Session 7 — Currency clarity + UI goal tracker (#8, #9).** Resolve Influence/Respect; add the always-visible Next Unlock.
8. **Session 8 — Meta-progression validation.** Confirm the perk tree + multi-prestige loop holds interest across 2–3 prestiges in sim; add 1–2 cross-prestige goals if a cliff appears.
9. **Session 9 — `ui.py` refactor (#10) + QA pass.** Split UI modules; full save/load/prestige/migration regression with the console.
10. **Session 10 — Game-feel & long-term content.** Rank-up celebrations, prestige FX, "next unlock" anticipation beats; design the 5h/20h/100h goal ladder now that the early game is sound.

---

## 10. Remaining Weaknesses & Notes

- **`influence`/Respect** remains nearly inert until Session 7 — flag for design intent (is it meant to be a soft currency, a leaderboard score, or removed?).
- **`sim.py`** legacy model should be deleted or folded into the harness to avoid confusion.
- **Heat raid variance** is fine but untested at scale because few players reach high balances; revisit after the economy rebalance.
- **Operations use wall-clock `time.time()`** for timers, not game `dt` — they progress while the game is closed (intended for an idle, but interacts with offline earnings; verify no double-dipping after Session 6).
- All findings are reproducible: `python sim_harness.py`, `python sim_project.py`, `python sim_econ.py`.

**Bottom line:** This is not a game that needs more features — it's a game whose existing, well-built features are locked behind an unreachable gate. Open the gate (Sessions 1–3) and Idle Empire goes from "unwinnable" to genuinely promising, because the deeper systems are already here and they're good.
