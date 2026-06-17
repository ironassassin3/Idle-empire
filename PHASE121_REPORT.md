# Phase 121 — Presentation Vision & Front-End Redesign Audit

**Date:** 2026-06-15  
**Scope:** Audit, mockup planning, and design direction only — **no code changes.**  
**Builds on:** Phase 120 (UI cohesion metrics via `_measure_p120.py`).

---

## 1. Objective

Begin the **Presentation Saga**: shift focus from mechanics (Phases 104–120) to how Idle Empire *looks and feels*. Systems are stable; save compatibility and progression logic are out of scope.

**Primary goal:** Transform Idle Empire from a collection of systems into a **visually recognizable criminal empire**.

The question is no longer *"Does the game work?"* — it is *"Does the game feel like the fantasy it delivers?"*

---

## 2. Core question — the 15-second test

> If somebody watched Idle Empire for 15 seconds with no text, would they recognize **"a growing criminal empire"** or **"a spreadsheet with buttons"?**

### Verdict: **Spreadsheet with buttons** (today)

| Signal (silent viewer) | Reads as empire? | Reads as idle UI? |
|------------------------|------------------|-------------------|
| Large blue square labeled CLICK | No | **Yes** — generic clicker |
| Right panel: tabbed card lists | No | **Yes** — management dashboard |
| Gold `$` balance + `/sec` in header | Partial | **Yes** — idle numbers |
| Small procedural skyline (bottom-left sliver) | **Weak yes** | Competes with goals + stat cards |
| Heat bar turning red | Partial | Could be any "danger meter" |
| Monospace Consolas typography | No | **Yes** — dev/terminal aesthetic |
| Manager silhouette icons (colored circles) | Partial | Generic avatar placeholders |

**What would flip the verdict:** A dominant **city silhouette** (40%+ of left column or full-width backdrop), visible **crew activity** (cars, neon, smoke tied to heat), and **character presence** (portraits, not circles) in the persistent chrome — without removing the number clarity idle players expect.

The [`landing/index.html`](landing/index.html) page already nails the fantasy (art-deco noir, gold/crimson, Limelight display type). The **in-game UI does not yet inherit that identity**.

---

## 3. Design philosophy (constraints)

### Preserve (non-negotiable)

- All mechanics, formulas, manager behaviors, automation logic
- Progression gates and rank/perk structure
- Manager identities, names, specialties, payroll costs
- Save/load field compatibility
- Performance patterns (`_ips_dirty`, stats surface cache, achievement throttle)

### Redesign (in scope for future phases)

- Layout hierarchy and screen real estate
- Typography, palette application, panel chrome
- Portrait/icon art direction (can remain procedural initially)
- Animation vocabulary tied to *clarity*
- Information surfacing (not information *content*)

**Rule:** Presentation changes may **reveal** systems; they must not **replace** or **rebalance** them.

---

## 4. Visual hierarchy audit

### Player priority model

| Tier | Information | Player need | Current treatment | Match? |
|------|-------------|-------------|-------------------|--------|
| **Primary** | Money (balance) | Always | Header row 1, largest type, gold | **Strong** |
| **Primary** | Income/sec | Always | Header row 2, muted green arrow | **Strong** |
| **Primary** | Rank | Progress identity | Header top-right badge + progress bar | **Good** |
| **Primary** | Current goal | What to do now | Goals panel under prestige (landscape only) | **Good early**, fades late |
| **Secondary** | Heat | Risk/reward | Header bar + conditional hints | **Good** |
| **Secondary** | Shield | Safety net | Header micro-text when Collector hired | **Easy to miss** |
| **Secondary** | Automation status | Delegation trust | Per-card `✓ AUTOMATED`, header fragments | **Weak — no unified strip** |
| **Secondary** | Active operations | Timers / collect | Turf → Ops sub-tab; broken ready-dot on main tab | **Buried + bug** |
| **Tertiary** | Statistics | Review / brag | Stats tab, 2600px virtual scroll | **Correct tier, wrong density** |
| **Tertiary** | Achievements | Completionist | Stats footer button → overlay | **Too buried** |
| **Tertiary** | Rob dashboard, heat breakdown | Optimizer tools | Stats scroll / prestige window | **Correct tier, wrong discoverability** |

### Hierarchy mismatch summary

1. **Primary goals compete with secondary chrome** — header packs rank progress, heat hints, shield, forecast, promoter target, ticker, and buff pill into ~116px.
2. **Automation is secondary in importance but tertiary in visibility** — players hire "employees" but see spreadsheet rows.
3. **City/scene is emotionally primary (fantasy) but layout-priority tertiary** — `reinit_layout()` explicitly starves scene for goals + stat cluster.

### Recommended hierarchy (target state)

```
┌─────────────────────────────────────────────────────────────┐
│  PRIMARY STRIP: $ balance · ▲ ips · RANK · #1 GOAL (one line)│
├─────────────────────────────────────────────────────────────┤
│  SECONDARY STRIP: HEAT · SHIELD · AUTO icons · OPS timer     │
├─────────────────────────────────────────────────────────────┤
│  FLAVOR: news ticker OR ambient city edge (not both crowded) │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Header redesign concepts

### Current header anatomy (900×720 reference)

- **116px** total height (~16% of screen)
- Row 1: coin + balance | rank badge | buff pill
- Row 2: ips/sec + prestige mult pill | heat bar + up to 4 micro-hints
- Rows 3–4: **26px news ticker** embedded in header

**Problems:** Information flatness (everything is `xs`/`sm`), no grouping boxes, heat hints overflow horizontally on narrow widths, ticker competes with actionable secondary info.

### Concept A — **Two-strip command bar** (recommended)

| Strip | Height | Contents |
|-------|--------|----------|
| Command | ~52px | Balance (hero) · ips · rank pill · single truncated goal |
| Status | ~28px | Heat meter · shield pips · automation icon row · ops countdown |
| Ticker | ~22px | Optional; collapses when status strip active |

**Premium styling cues:** Subtle gold hairline dividers (match landing page `--line`), grouped panels with 4px inner padding, rank displayed as **badge/medallion** not bracket text.

### Concept B — **Empire crest header**

Left: balance stack. Center: **dynamic city silhouette thumbnail** (same renderer as scene, cropped) — grows with building count. Right: rank + heat. Ticker moves to bottom of left column.

*Trade-off:* Strongest 15-second fantasy; costs horizontal space on 900px width.

### Concept C — **Minimal optimizer header**

Single 48px bar; everything else on hover/tooltip expand. Best for late-game density; **worst** for fantasy and casual clarity. Not recommended as default.

### Permanent screen space — decision matrix

| Element | Keep permanent? | Notes |
|---------|-----------------|-------|
| Balance | **Yes** | Hero typography |
| Income/sec | **Yes** | Core idle loop feedback |
| Rank | **Yes** | Identity + unlock preview |
| Top goal (1 line) | **Yes** | Pull from `goals_mod.next_focus_hint` |
| Heat bar | **Yes** | Unique differentiator vs other idlers |
| Shield state | **Yes** when Collector hired | Icon, not text |
| Automation icons | **Yes** when any auto manager hired | New — see §8 |
| Prestige mult pill | Conditional | After first prestige only |
| Full rank progress numbers | **No** — collapse to bar | Detail on hover |
| News ticker | **Optional / rotatable** | Lower priority than status |
| Buff pill | **Yes** when active | Short label + timer |

---

## 6. Manager presentation audit

### Current card anatomy (`managers.draw_panel`)

- 110px rows (`_ROW_H`), colored circle silhouette icon, name + `[ Title ]`, specialty line
- Hired: green left bar, flavor + bonus_desc text stack
- Locked: LOCKED badge, rank gate progress bar, hire fee
- Affordable: gold pulse border (sin wave)
- Sections: STREET CREW / EXECUTIVE TEAM with collapse teaser (Phase 117)

### Do managers feel like employees or upgrade buttons?

**Verdict: Closer to upgrade buttons.**

| Employee signal | Present? | Gap |
|-----------------|----------|-----|
| Distinct face/portrait | Weak | Procedural silhouette only — interchangeable |
| Personality in UI | Copy only | Flavor text at 150 alpha, below stats |
| "On the job" indicator | Partial | Green bar = hired, not *working* |
| Payroll visibility | Hire fee on card | No ongoing "salary" metaphor (acceptable) |
| Active action feedback | Rare | Mechanic/Accountant silent; Sal shows SAL on coin |
| Status badges | Some | Promoter target, Maxine %, Rudy/Rob one-liners |

### Per-manager presentation opportunities

| Manager | Status badge idea | Active indicator | Portrait direction |
|---------|-------------------|------------------|-------------------|
| Sticky Pete | `PICK` on Buildings tab | Pulse when recommendation changes | Cap + gold tooth, street wear |
| The Collector | Shield pips in header | Flash on raid absorb | Broad shoulders, suit, earpiece |
| The Mechanic | Wrench icon in auto strip | Brief wrench flash on auto-buy | Grease, coveralls |
| Lucky Sal | Coin halo on golden coin | SAL label (exists) | Vegas smile, rings |
| Clean Carl | Forecast arrow in header | Thermometer trend | Glasses, briefcase |
| The Accountant | Ledger icon in auto strip | Receipt toast on auto-buy | Green visor, stacks of paper |
| Maxine the Dealer | `+N%` badge (exists) | Chip cascade on casino buy | Casino floor boss |
| The Promoter | `AUTO≤N` (exists) | Heat bar snaps to target | Nightclub flyer aesthetic |
| The Smuggler | Queue badge on Ops | Crate icon when op starts | Duffel, dock coat |
| The Broker | `INTEL` on best turf action | Map pin pulse on Territory | Wire glasses, dossier |
| The Consigliere | Prestige tab glow | Candle flicker on advice update | Old-world suit |
| Rudy Riches | `ADVICE` on prestige btn | Soft gold pulse when rec changes | Champagne, cufflinks |
| Rob Revenue | `REPORT` chip on Stats | Dashboard line highlight | Tablet, charts |

### Locked state recommendations

1. **Default-collapse** Executive Team until Made Man (Phase 120 rec) — show single **NEXT HIRE** card in header/goals instead of 6 grey rows.
2. Locked cards: show **silhouette + ?** portrait, not full-color icon at 120 alpha — reads as "person waiting" not "disabled button."
3. Hire afford pulse: keep, but add **one-line voice quote** on hover ("Nobody skips a payment.") — personality without layout cost.

---

## 7. City fantasy audit

### Screen real estate (900×720 landscape, typical mid-game)

| Region | Approx. share | Role today |
|--------|---------------|------------|
| Header + ticker | ~16% height | Economy + heat |
| Left: click + prestige | ~45% width, ~55% height | Clicker + prestige gate |
| Left: goals panel | ~140px fixed | Guidance |
| Left: **city scene** | **~70–160px** elastic | Ambience — often **≤12% of screen** |
| Left: stat cluster (CLICKS/CREW/MULT) | ~48px | Tertiary stats |
| Right: tabs + content | ~54% width | Primary interaction |

**Conclusion:** Menus and numbers occupy **~75–85%** of perceived attention; the city is a **footer thumbnail**.

### Can the city become the visual centerpiece?

**Yes — without mechanic changes** — by reprioritizing layout, not adding simulation:

| Idea | Mechanism tie | Presentation only |
|------|---------------|-------------------|
| **Skyline growth** | `total_buildings` tiers already exist in `draw_scene` | Enlarge scene rect; use as left-column background behind translucent click zone |
| **District activity** | Territories owned / contested | Window lights color by player vs rival share; flicker rate ∝ income |
| **Heat atmosphere** | `heat` 0–100 | Red fog overlay, siren flash at 60%+, smoke density |
| **Rank-based visual upgrades** | `prestige.get_rank` | Helicopter pad at Kingpin, crown lighting at Shadow Government |
| **Time-of-day cycle** | `_time` | Slow dusk — neon signs brighten (already partially in scene) |
| **Header crest** | Building count | Mini scene render in header (Concept B) |

### Layout wireframe — **City-first left column** (target mockup)

```
┌──────────────── LEFT (~420px) ─────────────────┐
│  ┌──────────────────────────────────────────┐  │
│  │         CITY SKYLINE (full width, ~45%)    │  │
│  │    heat haze · district lights · cars       │  │
│  │         ┌─────────────┐                     │  │
│  │         │   CLICK     │  (glass overlay)    │  │
│  │         └─────────────┘                     │  │
│  └──────────────────────────────────────────┘  │
│  PRESTIGE BAR (compact)                          │
│  GOALS (2 rows max)                              │
│  CREW/MULT chips (inline, not full cards)      │
└──────────────────────────────────────────────────┘
```

**Portrait mode:** Scene becomes horizontal banner above tabs; goals move to collapsible drawer.

---

## 8. Animation opportunities

Principle: **Clarity > noise.** Every animation must answer a question, not decorate.

| System | Animation | Clarity question answered | Priority |
|--------|-----------|---------------------------|----------|
| Collector shield | Header shield icon **pulse + flash** on absorb | "You were protected" | **P0** |
| Lucky Sal coin | Existing glow; add **arc trail** to balance on collect | "Sal earned that" | P1 |
| Mechanic auto-buy | **Wrench icon** in strip spins once + toast | "Who bought that?" | **P0** |
| Accountant auto-buy | Ledger flip + toast | Same | **P0** |
| Broker intel | Territory card **gold edge breathe** on recommended action | "Where to attack" | P1 |
| Rudy prestige | Prestige button **soft gold breathe** when advice updates | "Timing changed" | P2 |
| Rob dashboard | Changed line **highlight fade** (2s) on Stats tab | "Empire mix shifted" | P2 |
| Promoter | Heat bar **snaps** to target line (already logical) | "Autopilot holding" | P1 |
| Smuggler | Ops card **crate stamp** when op auto-starts | "Op launched" | P1 |
| Heat 60%+ | Scene **red vignette pulse** + RAIDS text shake (once) | "Danger zone" | P1 |
| Pete pick | Buildings card **gold corner tick** (exists partially) | "Buy this" | Keep |
| Rank up | Existing overlay + add scene **fireworks/sparklers** | "Empire tier up" | P2 |

### Animations to avoid

- Continuous shake on header numbers (idle anxiety)
- Multiple simultaneous pulses on same strip (visual noise)
- Per-frame surface allocation (performance regression)

---

## 9. Tab structure audit

*Quantitative data from Phase 120 `_measure_p120.py` (ENGAGED profile, ~31 min).*

### Visit frequency & dwell

| Tab | Dwell share | Role |
|-----|-------------|------|
| Buildings | **28%** | Core loop — correct anchor |
| Managers | **19%** | Automation roster — high engagement |
| Upgrades | **16%** | Power spikes |
| Territory | 10% | Mid-game expansion |
| Crew | 10% | Assignment puzzle |
| Stats | 8% | Review |
| Operations | 6% | Timed payouts |
| Rivals | 4% | Conflict |

### Structural issues

| Issue | Evidence | Impact |
|-------|----------|--------|
| **Ops ready indicator broken** | Pulse checks `key == 'operations'` on *main* tabs; Ops is Turf sub-tab | Players miss collect moments |
| **Stats overload** | ~2600px virtual height | Optimizers scroll; casuals never see Rob |
| **Turf nesting** | 4 sub-systems behind 2 clicks | Rivals/Ops underused (<6% dwell each) |
| **Settings as `#` gear** | Not labeled | Discoverability fine for veterans |
| **Achievements** | Stats footer only | Tertiary buried correctly but *too* hidden |
| **Broker intel** | Territory panel only | Invisible in sim (Phase 120) |

### Redesign priority order

1. **Managers tab** — highest fantasy gap (employees vs buttons); collapse locked exec section
2. **Header + automation strip** — cross-tab visibility; fixes attribution
3. **Turf tab** — fix ops indicator; Broker highlight; sub-tab badges
4. **Left column / city** — 15-second test pass
5. **Stats tab** — tiered layout (Rob + session above fold)
6. **Buildings / Upgrades** — polish pass only (already functional)
7. **Menu / title** — align with landing page identity (currently plain Consolas title)

### Overloaded vs underused

| Overloaded | Underused |
|------------|-----------|
| Managers (13 rows + gates) | Rivals (4% dwell) |
| Stats (lifetime dump) | Operations (6%, plus indicator bug) |
| Header (crowded row 2) | City scene (visual underuse) |

---

## 10. Theme cohesion

### Current identity (`theme.py` + `ui.py`)

| Dimension | Current state | Reads as |
|-----------|---------------|----------|
| **Fonts** | Consolas/monospace all tiers | Terminal / dev tool |
| **Palette** | Navy `#0C0D14`, gold accent, purple prestige | Generic premium idle |
| **Spacing** | Phase 89 constants — consistent | Modern management UI |
| **Borders** | 8–10px radius cards, 1px accent dim | Cohesive but flat |
| **Shadows** | Minimal; mostly flat fills | No depth hierarchy |
| **Panels** | `BG_PANEL` / `BG_CARD` stack | Same weight everywhere |
| **Copy/flavor** | Strong in managers, events, dragons | **Organized crime writing** |
| **Chrome** | Neutral dashboard | **Not crime-specific** |

### Brand fracture

- Window title / menu: **"IDLE EMPIRE"**
- Landing page / CLAUDE.md: **"Criminal Empire"**
- Fantasy copy: crime syndicate throughout

**Recommendation:** Pick one consumer-facing name; apply art-deco noir palette from landing as **in-game accent layer** (gold lines, crimson heat, bone text) while keeping monospace for *numbers only*.

### Target aesthetic: **"Organized crime ledger"**

- **Display font** (rank, tab headers, PRESTIGE): serif/decorative — Cinzel or similar (landing already uses it)
- **Data font** (money, ips, stats): monospace — keep readability
- **Atmosphere:** grain overlay (subtle), vignette on scene, crimson heat bloom
- **Not:** purple-on-navy generic idle (current prestige button is closest to on-theme)

---

## 11. Inspiration pass

### Reference extraction

| Reference | Personality | Atmosphere | Readability |
|-----------|-------------|------------|-------------|
| **Idle Slayer** | Hero avatar always on screen; progression *is* the character | Pixel world behind UI | Huge primary stat; minimal chrome |
| **NGU Idle** | Absurd voice, hidden depth | Chaotic menus with themed headers | Color-coded systems; dense but labeled |
| **Realm Grinder** | Faction choice = instant visual identity | Alignment colors permeate UI | Spell/building icons with strong silhouettes |
| **AdVenture Capitalist** | Satirical business portraits | Clean white/gold optimism | One big number; businesses as illustrations |
| **Fallout Pip-Boy** | Retro-future bureaucracy | Amber/green CRT, scanlines, tabs | High contrast; tick/radio sounds |
| **GTA (HUD)** | Wanted level, minimap, street context | Grit, neon, radio | Minimal HUD; world carries fantasy |

### Transferable principles for Idle Empire

1. **Character-forward chrome** (Idle Slayer, AdCap) — managers as faces in header strip, not only list rows
2. **World behind UI** (GTA, Idle Slayer) — city scene as backdrop, not footer
3. **System color coding** (NGU, Realm Grinder) — heat=crimson, turf=map green, prestige=purple/gold, ops=amber
4. **Themed container** (Fallout) — tab bar as "case file" tabs or "dossier" folders
5. **One hero number** (AdCap) — balance already qualifies; protect its size during redesign

---

## 12. Deliverables

### 12.1 This document

`PHASE121_REPORT.md` — presentation vision, audits, and phased mockup plan.

### 12.2 Mockup plan (implementation phases)

| Phase | Focus | Output | Status |
|-------|-------|--------|--------|
| **122** | Header v2 + automation status strip | Wireframe → pygame mock | Done |
| **123** | Manager cards v2 (roster, badges, collapse) | Card component spec | Done |
| **124** | City-first left column | Layout refactor + scene scaling | Done |
| **127** | Theme pass (typography + palette + menu) | Align with landing; mafia ledger feel | **Done** |
| **125** | Turf tab indicators (ops ready, broker) | Sub-tab badge system | **Next** |
| **126** | Stats tiering + achievement entry | Above-fold dashboard | Queued |
| **128** | Animation package P0 (shield, auto-buy, toasts) | Motion spec | Queued |

**Constraints:** presentation only; no generative AI assets (code-drawn UI or user-provided art). See `CLAUDE.md`.

### 12.3 Wireframe — full screen (target)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ $ 12.4M          ▲ 86.4K/sec        [ CAPO ▓▓▓░░ ]   ▸ Capture District 3│
│ HEAT ▓▓▓▓▓░░ 42%  🛡️  ⚙️×2  🪙Sal  📦Op 0:42                              │
│ ─── Syndicate news: Rival Black Hand expanding in Industrial... ──────── │
├───────────────────────────────┬──────────────────────────────────────────┤
│ ┌─ CITY SKYLINE ─────────────┐ │ Bldgs │ Upgrs │ Mgrs │ Turf▾ │ Stats  ⚙ │
│ │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  │ │────────────────────────────────────────│
│ │  ░░ neon ░░  🚗  ▓▓▓▓▓▓▓  │ │ ┌ Sticky Pete ──── [HIRED] ✓ ─────────┐ │
│ │       ┌──────────┐          │ │ │ ◉ Runs the corner crew…              │ │
│ │       │  CLICK   │          │ │ └──────────────────────────────────────┘ │
│ │       └──────────┘          │ │ ┌ The Mechanic ─── AUTO CHOP ─────────┐ │
│ └─────────────────────────────┘ │ │ ◉ Night shift running…               │ │
│ * PRESTIGE  ▓▓▓░░  2/5 reqs     │ └──────────────────────────────────────┘ │
│ CURRENT GOALS                   │                                          │
│ ▸ Own 10 dealers  ▓▓▓▓░░       │                                          │
└───────────────────────────────┴──────────────────────────────────────────┘
```

### 12.4 Before / after concept summary

| Dimension | Before (now) | After (vision) |
|-----------|--------------|----------------|
| 15-second read | Spreadsheet + clicker | City + crew + heat |
| Managers | Upgrade list | Employee roster with faces |
| Automation | Hidden / silent | Strip + toasts |
| Typography | All monospace | Display + mono data |
| City | 12% sliver | 40%+ backdrop |
| Brand | Split Idle/Criminal | Unified criminal empire |
| Landing vs game | Strong / weak | Cohesive |

---

## 13. Primary conclusion

Idle Empire's **systems already tell a crime syndicate story** in text — managers have voice, heat creates tension, turf expands territory, prestige climbs a hierarchy. The **presentation still reads as a capable idle-game dashboard** because:

1. Layout prioritizes tabs and numbers over the city
2. Typography and palette are genre-generic, not crime-specific
3. Managers look like purchasable perks, not people working for you
4. Automation success is often silent

**Phase 121 direction:** Do not add systems. **Re-surface existing ones through hierarchy, city weight, character presentation, and motion that explains cause and effect.**

The next implementation phase should start with **Header v2 + automation strip + ops indicator fix** — highest clarity ROI before a full visual theme pass.

---

## 14. References

- Phase 120 metrics: `PHASE120_REPORT.md`, `_measure_p120.py`
- Layout source: `src/ui.py` (`reinit_layout`, `draw_stats`, `draw_scene`, `draw_right_panel`)
- Theme: `src/theme.py`
- Manager panel: `src/managers.py` (`draw_panel`, `_make_icon`)
- Tab gates: `src/prestige.py` (`visible_tabs`, `visible_turf_subtabs`)
- Landing aesthetic target: `landing/index.html`
