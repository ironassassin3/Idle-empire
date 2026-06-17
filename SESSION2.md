# Session 2 — First-Prestige Retention & Mobile Addictiveness
*2026-06-02 · Focus: does the game become MORE fun after prestige? End goal: a maximally addictive mobile-store idle game.*

## TL;DR
The honest answer before this session was **NO** — prestige felt like a punishment. The real playthrough proved it: after prestige, income collapsed and took **12m12s** to recover, the second prestige fired with the *same* reward for the *same* grind, and the feed was buried in "Chop Shop bonus!" spam. All three are now fixed. Post-prestige recovery is **~45s**, each prestige escalates (bigger reward, new rank, a real run in between), managers now *create gameplay* (automation, active heat lever), and the notification feed is clean. **30/30 regression tests pass on the real game code.**

---

## How I tested (real gameplay, not just simulation)
Built `sim_playthrough.py` — drives the **actual `PlayingState`** (real income, click, prestige, territory, rival code paths) through fresh save → first prestige → continue → second prestige, capturing the *experience timeline*: every notification, rank-up, tab unlock, and prestige with timestamps, plus an automatic **dead-zone detector** (>90s of silence = boredom risk). `sim_postprestige.py` measures the post-prestige income **recovery time** and returns a GOOD/BAD verdict. This is the boredom detector the brief asked for — simulations find balance bugs, this finds emotional dead zones.

---

# PART 1 — First-Prestige Retention Audit

### Fresh-save milestones (real playthrough)
| Milestone | Time |
|---|---|
| First building | instant |
| First upgrade | ~2 min |
| First Influence | ~2 min |
| First territory | ~2 min |
| First manager | ~10–19 min |
| First rival interaction | ~2 min |
| First prestige | ~9–22 min (varies with rival/territory engagement) |

### Post-prestige (BEFORE fixes)
| Measure | Before | After |
|---|---|---|
| Time to recover pre-prestige income | **12m12s** | **~45s** |
| Time to first new unlock | immediate (rank-up) | immediate |
| Second prestige eligibility | **instant (0s)** — broken | **~2m20s** (a real run) |

## CRITICAL QUESTION — "I can't wait to do that again" vs "I just lost everything"
**Before:** unambiguously *"I just lost everything."* Income 187K/s → ~500/s, a 12-minute crawl back for a weak ×1.7 bonus.
**After:** *"I'm so much faster now."* The head start restores ~40% of your build instantly, income climbs back in ~45s, then **rockets past the prior peak** (one run hit 25M/s, ~130× the pre-prestige income, within a minute of prestiging). Verdict flipped from BAD to **GOOD** in `sim_postprestige.py`.

---

# PART 2 — Wow-Moment Analysis
- **Time to first wow: ~2m12s** (first Betting jackpot) — inside the 5–10 min target. ✅
- Early rank-ups (Crew Member, Associate, Made Man) land at 2–5 min.
- **Problem found & fixed:** the wows were *buried* in "Chop Shop bonus! +873" spam firing every ~5 seconds. After silencing it, the feed is a clean rhythm of meaningful beats (jackpots every ~2 min escalating in value, rank-ups, manager hires, prestige). **Dead-zone scan: none.**

---

# PARTS 3–6 — System Excitement Audits

### Part 3 — Managers → **REDESIGNED**
Were a flat ×1.5 income with no gameplay. Now two have unique, advertised effects (`managers.tick_manager_effects`):
- **The Accountant — AUTO-BUYS** the best-value building every 3s. This is the single most important mobile-idle retention feature: the game makes visible progress while you watch, and frees the player from tapping. (Verified: 3 auto-buys in 10s.)
- **The Promoter — actively launders Heat** (−0.6/s while hired), turning Heat into a managed resource. (Verified: 80 → 60 in 10s.)
These convert managers from "bigger number" into "new mode of play," and give the player a *reason to pursue specific managers*. (Others remain income boosts — deliberately scoped; more unique effects are a clean Session 3 follow-up.)

### Part 4 — Territory → audited, identity deferred
Territories function and are reachable (Session 1). They still differ mostly by stat magnitude rather than identity (Downtown=cash vs Waterfront=smuggling). This is real but **lower retention-ROI than the prestige collapse**, so per the brief's "choose retention" rule I prioritized the loop. Flagged for Session 3 with concrete identities.

### Part 5 — Rivals → audited
Rivals already have genuine AI (the playthrough showed them capturing districts and raiding the player for real cash). They create tension passively. Deeper player-driven rivalry (named grudges, "take that territory back") is a Session 3 opportunity, not a Session 2 emergency.

### Part 6 — Heat → improved
Heat was passive drift the player couldn't steer early. The Promoter manager now gives an **active heat lever**, and the existing nightclub/crew levers remain. Heat's risk/reward (income bonus above 50, raids above 60) is intact. Surfacing the coded-but-hidden lawyer/bribe buttons remains a Session 3 item.

---

# PART 7 — Second-Prestige Motivation → **FIXED (core of this session)**
**The biggest long-term risk** was: prestige once, get +10 Influence, prestige again instantly for another +10, feel nothing, quit. Fixes:
1. **Escalating earnings gate** — each prestige sets the next bar to `lifetime × 8`, so every prestige requires a full new run and is a *bigger* achievement. (Persisted in saves.)
2. **Escalating reward** — `calc_influence_gain` now scales so deeper prestiges grant *more* Influence (run 1 **+11** → run 2 **+14** → keeps climbing), each often crossing a new rank (Capo → Underboss).
3. **Head start** makes each new run start strong, so the escalating bar feels like acceleration, not a wall.

Result: prestige #2 gives more, reaches a new rank, and sits a satisfying ~2m20s of play after #1. The player has a concrete reason to keep going.

---

# PART 8 — Mobile Retention: Top 5 Uninstall Reasons

| # | Reason | Severity | Solution | Cost | Status |
|---|---|---|---|---|---|
| 1 | **Post-prestige collapse** — "I lost everything," 12-min crawl back | CRITICAL | Head start restores ~40%+ of build instantly | Low | ✅ FIXED |
| 2 | **No reason to prestige again** — flat repeat | CRITICAL | Escalating gate + escalating reward + new ranks | Low | ✅ FIXED |
| 3 | **Notification spam** burying real moments | High | Silenced ambient Chop procs; kept meaningful beats | Low | ✅ FIXED |
| 4 | **No automation** — endless manual tapping | High (mobile) | The Accountant auto-buys buildings | Low | ✅ FIXED |
| 5 | **Shallow managers / unsteerable heat** | Medium | Promoter active heat lever; manager effects framework | Low | ◐ PARTIAL (framework in; more in S3) |

---

# PART 9 — App-Store Readiness
- **10-min session rewarding?** ✅ A fresh 10-min session reaches multiple rank-ups, the first jackpot, the first manager, and visible approach to prestige.
- **Offline progress rewarding?** ✅ Present (8h cap, overlay on return) from Session 1 era; untouched.
- **Goal visibility?** ✅ The escalating prestige bar + goals give an always-approaching target; prestige tree shows the next reward.
- **Progress visibility?** ✅ Income, rank, Influence, and the prestige progress bar all read clearly; the head start makes post-prestige *gains* legible.
- **Addiction loop?** ✅ Now intact: play → grow → prestige (instant power spike via head start) → escalating bar → bigger prestige. The "one more prestige" hook exists where before it didn't.

---

# Files Modified
| File | Change |
|---|---|
| `src/prestige.py` | **Head start** (`_apply_head_start`) restoring a scaling fraction of the player's build post-prestige; **escalating gate** (`prestige_earnings_required`, `_next_prestige_earnings`, `PRESTIGE_EARNINGS_GROWTH=8`); `check_requirements` drops building/rank gates after first prestige; `calc_influence_gain` escalates (`log²/5.0`). |
| `src/managers.py` | `tick_manager_effects` + `_auto_buy_best`: The Accountant auto-buys, The Promoter launders heat; advertised in bonus_desc/specialty. |
| `src/states.py` | Calls `mgr_mod.tick_manager_effects`; inits `_next_prestige_earnings`. |
| `src/buildings.py` | Chop Shop proc made silent (denoise). |
| `src/save_load.py` | Persists `next_prestige_earnings`. |
| `src/prestige_tree.py` | Requirements panel builds rows dynamically (handles reduced post-first-prestige req set without crashing). |
| `sim_playthrough.py`, `sim_postprestige.py`, `sim_test_suite.py` | New experiential/recovery/regression tools. |

---

# Balance Changes
- Prestige head start: restore `0.40 + 0.05·(prestige_count−1)` (cap 0.75) of each tier's pre-reset count, + ~10s seed cash.
- Prestige gate now escalates ×8 lifetime each prestige (was a flat $20M forever).
- Influence gain `log²/5.5 → log²/5.0` (deeper prestiges escalate; run 1 ≈ +11).
- Chop Shop bonus: unchanged value, **no notification**.
- Managers: The Accountant gains auto-buy (every 3s); The Promoter gains −0.6 heat/s.

---

# New Milestone Timings (real playthrough, after fixes)
| Milestone | Time |
|---|---|
| First wow (jackpot) | ~2m12s ✅ (target 5–10 min — even better) |
| First prestige | ~9–22 min (engagement-dependent) |
| **Post-prestige income recovery** | **~45s** (was 12m12s) |
| Second prestige | ~2m20s after first (was instant) |
| Prestige #1 → #2 reward | +11 → +14 Influence (escalating) |

---

# Time-To-First-Wow
**~2 minutes 12 seconds** (first Betting jackpot), with rank-ups immediately around it. Well inside the 5–10 min target. The fix wasn't *adding* a wow — it was *unburying* the existing ones by killing notification spam.

---

# Testing (all on real game code)
`sim_test_suite.py` — **30/30 pass**: fresh save · first prestige (+ head start) · second prestige (+ escalation) · save/load round-trip (incl. new field) · achievements · manager unique effects · territory · heat. Plus `sim_smoke.py` passes, the game boots (`main` imports), and the prestige-tree UI renders in both fresh and post-first-prestige states.

---

# Top Remaining Retention Risks
1. **Territory/Rival identity** — still mostly numeric. Medium ROI; give each district a strategic identity and add player-driven rival grudges. (Session 3)
2. **Manager depth beyond two** — the framework exists; the other 9 managers are still flat %. Add unique effects (Lawyer cuts heat-growth, Fixer improves event outcomes, Enforcer territory bonus, Consigliere prestige bonus). (Session 3)
3. **Heat levers under-surfaced** — the coded lawyer/bribe actions aren't in the UI. (Session 3)
4. **Prestige-tree perks** — solid but could escalate harder to reward deep prestigers. (Session 3)
5. **No real-device playtest** — all validation is the (optimistic) sim; a human session on a phone is the next confidence step.

---

# Recommendations for Session 3
1. **Manager identities (highest ROI now that the loop is fixed):** flesh out the remaining managers with unique effects using the `tick_manager_effects` framework — the brief's Accountant/Lawyer/Fixer/Enforcer/Consigliere design.
2. **Territory identities:** Downtown=cash, Waterfront=smuggling/ops, Industrial=operations, Financial=laundering — make capture choices strategic.
3. **Surface heat levers** (lawyer/bribe buttons) so Heat is an active decision early.
4. **Push notifications / offline hooks** — the classic mobile retention loop ("your empire earned $X while away; a rival is moving on your turf — come back").
5. **Real-device playtest** to validate sim→reality timing.

If a conflict arises between adding systems and improving retention, keep choosing retention — the loop is now sound; Session 3 should *deepen the choices inside it*, not bolt on new systems.

## Re-verify
```
python sim_test_suite.py    # 30-check regression (fresh/prestige/2nd-prestige/save/ach/mgr/terr/heat)
python sim_playthrough.py    # experiential timeline + dead-zone detector
python sim_postprestige.py   # post-prestige recovery time + GOOD/BAD verdict
python sim_smoke.py          # deadlock + boot sanity (Session 1)
```
