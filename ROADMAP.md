# Criminal Empire — Godot → Mobile Launch Roadmap

**Track:** Godot 1.0 (release vehicle) → soft launch → mobile.
**Status:** P5 ✅ · P6–P8 code done (manual device/audio pass open) · P9 pacing done (notifications deferred).
**pygame** is a **prototype / balance lab** (sims, quick mechanical experiments). It is **not** the shipped game and is not maintained for UI.

> This is a planning document. It defines *what each phase contains and when it is done*, not the
> implementation. No phase work is performed by this file.

---

## Operating principles (from CLAUDE.md / PROJECT_RULES.md)

- **Priority order:** Retention > Progression > Engagement > Mobile UX > Monetization > New Features.
- **Improve existing systems before adding new ones.** No new currencies / tabs / prestige layers
  / progression systems without strong evidence.
- **No generative-AI assets.** Code-drawn, Material Maker procedural (see `ART_POLICY.md` §4), or hand-authored only.
- **Evidence-based:** balance claims need sim or playtest proof. Prefer `sim_pacing.py` / `sim_godot_soak.py`; pygame `PlayingState` is the fast lab, Godot is what ships.
- **Save schema** stays shared where practical (pygame import on title screen). New fields need migration defaults in **Godot** (`game_state.gd` / save load); mirror in pygame only if sims depend on them.

## Why this order (dependency chain, not pure priority)

Retention is priority #1, but you cannot *tune* retention or mobile feel on an incomplete,
desktop-shaped, audio-less build. The chain forces:

```
Parity (P5) → Feel/Audio (P6) → Mobile UX (P7) → Perf/Device (P8)
→ Retention tuning (P9) → Monetization seams (P10) → Store/Compliance (P11) → Soft launch (P12)
```

Each phase is gated: do not start a phase until the prior phase's **Exit criteria** pass.

---

## Phase template (use for every phase)

```
## P<n> — <name>
Goal:          one sentence — the player/business outcome.
Priority tie:  which CLAUDE.md priority this serves.
Scope (in):    bulleted, bounded.
Out of scope:  what this phase deliberately does NOT touch (anti-creep).
Deliverables:  concrete artifacts (scenes, scripts, docs).
Exit criteria: checklist — objectively testable; gates the next phase.
Dependencies:  prior phases / pygame-lab proofs required first.
Risks:         known traps + mitigation.
Verify:        how it is proven (headless smoke, device test, metric).
```

---

## P5 — Parity Lockdown

**Goal:** Godot is mechanically identical to the pygame reference; no system is "stub only."
**Priority tie:** Progression (the systems players progress through must all exist and match).

**Scope (in):**
- Dragon patron: port `src/dragon.py` in stages — passive mults → HUD chip → abilities/requests;
  wire prestige-tree Dragon Patron button; remove stub-only status.
- Remaining managers: Sticky Pete (best-value highlight), Lucky Sal + golden coin
  (spawn/autocollect/`coins_caught`), The Promoter (heat autopilot target), Rudy/Rob
  (prestige advice + income-breakdown panels).
- Rival elimination overlay (full-screen epitaph, replacing toast-only).
- Event buff decay parity (`bw_attack_bonus` / `bw_negotiate_bonus` clear on buff expiry).
- Raid / first-heat tutorial milestone hook.

**Out of scope:** new content, audio, mobile layout, monetization.

**Deliverables:** `dragon_system.gd` (+ HUD chip), manager parity in `manager_system.gd`,
elimination overlay scene, buff-decay fix, updated `graphify-out/port/` map.

**Exit criteria:**
- [x] Feature-parity matrix (pygame system → Godot system) is 100% — no "stub" rows. *(P5 scoped rows — see `P5_REPORT.md`; full-port partials documented as post-P5 debt.)*
- [x] Headless `game_screen.tscn` → zero `SCRIPT ERROR` after 60s sim tick. (`python sim_godot_soak.py`)
- [x] Same starting save produces income within tolerance of pygame over a fixed tick count. (`python sim_income_parity.py`)
- [x] Defeating a rival shows epitaph overlay + rewards; buff bonuses decay correctly.

**Dependencies:** none (continues P4).
**Risks:** dragon system is large and touches income/ops/rivals — port in sub-slices behind a
flag; do not let it regress `compute_base_income`.
**Verify:** headless smoke + side-by-side income diff vs pygame for an identical save.

---

## P6 — Audio & Feel (Motion Pass)

**Goal:** The game *sounds and reacts*; parity systems gain the juice that drives session feel.
**Priority tie:** Engagement.

**Scope (in):**
- Wire SFX/music playback to existing config volume sliders (currently save-only, no playback).
- Audio hierarchy mirroring pygame: purchase → manager/territory/rankup/rival → prestige climax.
- Motion pass (Phase 128 equivalent): Collector shield pulse on heat bar, hustle/crit feedback,
  auto-buy toasts, goal-complete toast styling, prestige climax polish.

**Out of scope:** new mechanics; mobile-specific layout; balance changes.

**Deliverables:** `audio_manager.gd` (autoload), SFX/music bus wiring, motion cues in
`game_screen.gd` / overlays. Code-drawn or hand-authored audio only (no AI-generated assets).

**Exit criteria:**
- [~] Every milestone tier plays its distinct cue; sliders + mute actually affect output. **Code wired
  — manual playtest open** (`P6_REPORT.md`).
- [x] No audio on headless/`--headless` (guarded); no per-frame surface/audio allocation spikes.
- [x] Motion cues fire on the correct events and never block input.

**Dependencies:** P5 (events to attach cues to must all exist).
**Risks:** audio latency / overlap on mobile — keep clips short, pool players.
**Verify:** manual playtest + headless guard test.

---

## P7 — Mobile UX & Responsive Layout

**Goal:** The 9-tab desktop UI becomes touch-first and works in portrait on a phone.
**Priority tie:** Mobile UX.

**Scope (in):**
- Input model: remove hover-dependent affordances; everything reachable by tap.
- Touch-target audit on all `*_row.tscn` prefabs (min tap size; spacing).
- Responsive layout: portrait lock, safe-area insets (notch/home bar), anchor-based scaling
  across phone aspect ratios; collapse/scroll for narrow widths.
- Tab navigation ergonomics for thumb reach (bottom bar candidate — evidence first).

**Out of scope:** perf tuning (P8), monetization UI, new systems.

**Deliverables:** responsive scene updates, portrait config in `project.godot`, touch-target
report, before/after captures at 2–3 device aspect ratios.

**Exit criteria:**
- [~] Playable end-to-end in portrait on a real phone (or device-sim) — no clipped/unreachable UI.
  **Structure verified headless; F5 + Moto G pass open** (`DEVICE_TEST_CHECKLIST.md`).
- [x] All interactive targets meet the minimum tap-size standard.
- [x] No reliance on hover/right-click anywhere in the play loop.

**Dependencies:** P5, P6.
**Risks:** dense tabs (Stats, Mgrs, Turf subtabs) hardest to fit — budget layout time there;
reuse the pygame font-driven geometry lessons (Phase 90/91 overlap fixes).
**Verify:** device/sim capture matrix at min/typical/max phone aspect ratios.

---

## P8 — Performance & Device Matrix

**Goal:** Stable frame rate and acceptable battery on low/mid-tier phones.
**Priority tie:** Mobile UX (perf is UX on mobile).

**Scope (in):**
- Switch renderer Forward+ → **Compatibility** (2D-only project; mobile/GLES target).
- Frame-budget pass: draw-call audit, overdraw, label/atlas reuse, particle caps.
- Battery/thermal sanity; background-tab CPU; tick cadence when idle.
- Long-run soak: headless + on-device extended session for leaks.

**Out of scope:** feature work; balance.

**Deliverables:** renderer switch, perf report (FPS + frame time on target device tiers),
particle/draw-call budgets documented.

**Exit criteria:**
- [~] Holds target FPS on a defined low-tier reference device through a full session. **Reference:
  Moto G (2026)** — headless throttle + renderer done; on-device FPS pending.
- [x] No memory growth over a multi-hour soak (headless + device). Headless 120s soak PASS
  (`memory_soak.gd`); multi-hour device soak pending.
- [~] Compatibility renderer verified — no visual regressions vs Forward+ captures. **Desktop F5
  visual check open** (`DEVICE_TEST_CHECKLIST.md` §A).

**Dependencies:** P7 (final layout must exist before profiling it).
**Risks:** Compatibility renderer can change blending/shaders — re-verify noir theme visuals.
**Verify:** on-device profiler + headless soak script.

---

## P9 — Retention Loop Hardening

**Goal:** First-week retention behavior is tuned and the return-session is compelling.
**Status:** In progress — daily login + principled pacing pass done in pygame lab and ported to Godot
(`P9_REPORT.md`). Push notifications and FTUE telemetry remain.
**Priority tie:** Retention (priority #1) — placed here because it must be tuned on the
final mobile-shaped, perf-stable build with real feel.

**Scope (in):**
- Return session: validate offline-earnings + welcome overlay; daily-return cadence.
- Local push notifications (lapse nudges) — opt-in, platform-correct.
- Port the **pygame-proven** pacing fixes from the Phase 103 audit:
  empire-route prestige gate, Influence-snowball removal, turf income backloading, goal-cash
  decoupling. *Prove each change in the pygame lab first; port validated values to Godot.*
  *(Done — see `P9_REPORT.md` §3; play-time gate explicitly rejected.)*
- First-time-user funnel review (tutorial → first prestige) against retention goals.

**Out of scope:** new progression systems/currencies (CLAUDE.md prohibits without evidence).

**Deliverables:** notification scheduling, tuned balance constants (ported from lab),
FTUE funnel report, retention instrumentation (events for D1/D7 milestones).

**Exit criteria:**
- [~] Offline/daily loop works (daily reward verified headless). **Push notifications + on-device
  consent = device pass** — not started.
- [~] Pacing fixes verified in pygame sim **and** ported to Godot — see `P9_REPORT.md` §3–4.
  Buildings-only first prestige ~25 min; territory-engaging ~17 min (was 4–8 min runaway). No
  play-time gate. On-device feel validation still pending.
- [~] FTUE funnel reviewed — no dead-ends in first-prestige path. **Telemetry instrumentation
  deferred** (mobile analytics not scoped).

**Dependencies:** P5–P8; pygame-lab balance proofs.
**Risks:** notification permission/spam policy per platform — follow store rules; gentle cadence.
**Verify:** sim harness (pygame) + on-device funnel telemetry.

---

## P10 — Monetization Scaffold

**Goal:** Revenue seams exist and are ethical, without compromising the core loop.
**Priority tie:** Monetization (#5 — built late, after the loop is proven retentive).

**Scope (in):**
- IAP architecture + product catalog seams (no live SDK required to design the seam).
- Rewarded-ad hook points (optional boosters), placed where they *add* value, not gate it.
- Cosmetic / time-saver framework consistent with no-AI-asset rule.
- Consent/privacy plumbing for ad/analytics SDKs (feeds P11).

**Out of scope:** aggressive paywalls, anything that breaks the idle fantasy or balance.

**Deliverables:** monetization design doc + integration seams (interfaces/stubs), consent flow.

**Exit criteria:**
- [ ] Purchase/reward seams callable behind interfaces; core loop unaffected when disabled.
- [ ] Monetization touchpoints reviewed against "doesn't harm retention" rule with evidence.

**Dependencies:** P9 (do not monetize an un-retentive loop).
**Risks:** scope creep into new currencies/systems — keep to seams + cosmetics/boosters only.
**Verify:** loop plays identically with monetization disabled (A/B sanity).

---

## P11 — Store Readiness & Compliance

**Goal:** A submittable, signed, compliant build with crash/analytics reporting.
**Priority tie:** Mobile UX / Monetization (launch enablement).

**Scope (in):**
- Export templates, signing, build pipeline (Android first / per target).
- Crash reporting + analytics consent (GDPR/age-gating as applicable).
- Store metadata: icon, screenshots (code-drawn/hand-authored), description, age rating,
  privacy policy.
- Save-migration hardening: pygame→Godot import test matrix; versioned save with defaults.

**Out of scope:** new features; balance.

**Deliverables:** signed build, store listing package, privacy policy, crash/analytics wired,
save-migration test matrix doc.

**Exit criteria:**
- [ ] Clean signed build installs and runs on target device(s).
- [ ] Crash reporting verified (forced test crash appears in dashboard).
- [ ] Old-save import produces no data loss / no crash across schema versions.
- [ ] Store listing passes platform pre-submission checklist.

**Dependencies:** P8 (perf), P10 (consent plumbing).
**Risks:** store rejection on privacy/ads disclosure — pre-validate against platform policy.
**Verify:** device install + forced-crash dashboard check + import matrix run.

---

## P12 — Soft Launch

**Goal:** Limited-geo live release producing real retention/monetization signal.
**Priority tie:** Retention (validate the #1 metric with real users).

**Scope (in):**
- Limited-geo release; KPI baselines (D1/D7/D30 retention, session length/count, ARPDAU).
- Live telemetry dashboards + alerting; hotfix cadence; remote-config kill-switches for
  monetization/notifications.
- Feedback intake loop → prioritized backlog feeding post-launch phases (P13+).

**Out of scope:** major new systems mid-soft-launch (only balance/hotfix unless data demands).

**Deliverables:** live build, KPI dashboard, hotfix process doc, post-launch backlog.

**Exit criteria:**
- [ ] Telemetry flowing; KPI baselines established against retention targets.
- [ ] Hotfix path validated (ship a config-only change without full resubmit).
- [ ] Go/no-go decision for wider launch is data-backed.

**Dependencies:** P11.
**Risks:** chasing vanity metrics — define target KPIs and decision thresholds *before* launch.
**Verify:** live dashboards + cohort retention curves.

---

## P13 — Rustic Noir UI Overhaul (presentation track)

**Goal:** Match commercial idle-game tactile polish while keeping ledger/noir identity.  
**Status:** Planned — see [`P13_REPORT.md`](P13_REPORT.md).  
**Priority tie:** Retention + Engagement (visual clarity and session feel).  
**Toolchain:** Material Maker procedural textures → Godot `StyleBoxTexture` (not generative AI; `ART_POLICY.md` §4).

**Scope (in):** Theme swap, main menu, header/nav, row cards, overlays, tab badges, atmosphere grain.  
**Out of scope:** New mechanics, AI texture packs, replacing procedural audio or code-driven motion/bars.

**Dependencies:** P7 layout stable (done in code); P8 device pass recommended before full texture rollout.  
**Can run in parallel** with P6–P9 device/audio pass if owner prioritizes visual retention uplift.

---

## P14 — Touch-First Retention UI (UX overhaul track)

**Goal:** Research-backed UI overhaul—economy HUD, badges, progressive disclosure, overlays, accessibility—on top of P13 surfaces.  
**Status:** Code-first complete (P14.0–P14.9) — see [`P14_REPORT.md`](P14_REPORT.md). MM textures + Moto G capture deferred.  
**Priority tie:** Retention + Mobile UX.  
**Scope (in):** P14.0–P14.9 sub-phases (theme/HUD/rows/overlays/FTUE telemetry); integrates P13 Material Maker + [`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md) M1–M2 layers.  
**Out of scope:** New mechanics/tabs/currencies; generative-AI art.  
**Dependencies:** P7 layout ✓; P13.1 MM export (owner); P8 device pass for capture matrix sign-off.

---

## P15 — City-First UI Rebuild v2 (presentation track)

**Goal:** Restore visible city/skyline fantasy (pygame Phase 124 parity) and retire rustic-ledger default; keep P14 UX patterns.  
**Status:** Architecture only — see [`UI_REBUILD_V2_ARCHITECTURE.md`](UI_REBUILD_V2_ARCHITECTURE.md). **No implementation until owner picks concept direction.**  
**Priority tie:** Retention + Engagement (15-second empire test).  
**Scope (in):** P15.0–P15.8 (`city_view` module, layout restructure, theme v2, hustle-on-city, validation).  
**Out of scope:** New mechanics/tabs; generative-AI art; executing rebuild in architecture phase.  
**Dependencies:** P14 complete ✓; owner sign-off on Concept A/B/C (doc §5–6).

---

## Cross-track sync rule (prototype ↔ Godot 1.0)

- **Godot = ship target.** Player UI, audio, mobile UX, and new features land here only.
- **pygame = lab.** Use for `sim_pacing.py`, income parity vs Godot, and quick balance experiments on `PlayingState`. Ignore pygame UI work.
- **Balance numbers:** prove in sim, then port to `godot/scripts/` (defs + systems). Don't drift the two runtimes without intent.
- After Godot edits: `python -m graphify update .` and refresh `graphify-out/port/`.

## Launch gate (definition of "ready to widen")

All true: parity (P5) ✓ · perf on low-tier device (P8) · retention loop tuned & instrumented
(P9 — pacing done in lab; notifications/telemetry pending) · monetization seams + consent (P10) ·
signed/compliant build + crash reporting (P11) · soft-launch KPIs meet pre-set thresholds (P12).

## Out of scope for this entire roadmap

- New currencies, tabs, prestige layers, or progression systems (CLAUDE.md prohibition).
- Generative-AI art/audio assets.
- Abandoning the hybrid port approach (faithful mechanics, Godot-native UI).
