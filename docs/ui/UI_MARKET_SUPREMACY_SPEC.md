# UI Market Supremacy Spec — "The City Answers" (Stage & Ledger v2)

**Date:** 2026-07-03
**Status:** DESIGN — full-surface overhaul spec on the shipped `UI_SHELL_V3` shell
**Method:** [claude-code-game-studios](https://github.com/donchitos/claude-code-game-studios) studio pipeline, solo mode — Creative-Director vision → theory anchoring → department UX specs per surface → owner decision points → QA gates. Nothing in §5 is final until the owner decides; nothing merges without the §7 gates.
**Constraints:** `ART_POLICY.md` (code-built only) · ink art-deco noir locked · in-game currency gambling only · verification via `ui_capture.ps1` + telemetry.

---

## 1. Market research — the scoreboard we must beat

Live sources July 2026 (§8). Condensed:

**Players reward:** single-surface clarity (AdCap: "no clutter, no tutorials to wade through") · polish-as-identity + generous adjustable tap targets (Egg Inc) · numbers that *perform* (the genre's core dopamine) · the welcome-back moment (73% of dailies return 2×/day when it's done well) · **trust** — 2026's "cleanest games" lists are purchase criteria; players pay $4–8 flat to escape dark patterns (Melvor's lane).

**Players punish:** clutter on phones · popup ads at moments of intent · the six researched dark-pattern families · <48px targets, tiny light text (Egg Inc's one recurring criticism) · badge fatigue · critical controls in the thumb red zone · punitive offline caps.

**The open lane:** AdCap won clarity, Egg Inc won charm, Melvor won trust — nobody holds clarity + charm + trust + touch ergonomics at once. Our chrome-capped shell is already shaped for that intersection. This spec claims all four axes.

---

## 2. Creative vision (Director tier)

> **You are the boss reading the night's ledger, and the city outside the glass answers to every line of it.**

Three pillars. Every spec in §4 must serve at least one; anything serving none is cut.

- **P1 — THE CITY ANSWERS.** The skyline is the save file. Purchases light windows, heat draws rain and sirens, prestige rebuilds the skyline. No floating chrome does what the city can do itself.
- **P2 — THE LEDGER PERFORMS.** Numbers are the show: they count, pulse, roll over suffixes like a mechanical counter. A balance that teleports is a bug against this pillar.
- **P3 — THE HOUSE DOESN'T CHEAT.** No popups, no pressure timers, no disguised buttons. The player's attention is borrowed, never stolen. Trust is a feature with a spec, not a vibe.

## 3. Theory anchoring (the framework's design foundation, applied)

- **MDA:** Mechanics (buy/upgrade/prestige/heat) → Dynamics (accumulate → automate → ascend) → target Aesthetics: *power fantasy of ownership* + *sensory satisfaction*. UI's job is making the dynamics legible (§4 deck) and the aesthetics felt (§4 masthead/stage).
- **Self-Determination Theory:** Competence = visible mastery (afford underbars, milestone counters, Empire Report trends). Autonomy = build identity (prestige branches, veteran density toggle, buy-mult control). Relatedness = personified world (dragon companion, faction voices in the rail/wire). Each surface spec below tags which need it feeds.
- **Flow:** the AttentionDirector is the flow guardian — exactly one suggestion at a time, priority-ordered, so the player is never arbitrating between competing alarms (the failure mode that kills Idle Miner sessions).
- **Bartle mix for idle:** Achiever-dominant (ranks, milestones), Explorer served by disclosure ("??? unlocks at $150K" is a map edge, not a wall), Socializer lightly via faction narrative. No Killer surfaces — rivals are PvE theater.

---

## 4. Full-surface specification (department pass: UX · motion · audio · haptics · accessibility · telemetry)

Template per surface: **Intent → Spec → Motion/Audio/Haptics → Accessibility → Telemetry → Gate.** All motion honors reduced-motion; all audio honors mute; haptics has a global toggle (default: owner decision D3).

### 4.1 Masthead (Z1) — "the ledger line" [P2, competence]
- **Intent:** one glance = am I richer, am I safe, am I close to ascending.
- **Spec:** rank chip · display balance (largest text on screen, Limelight, mono-tabular digits) · income line · heat pill (disclosure-gated) · prestige filament. **Top of screen is READ-ONLY** (owner decision D2 governs where gear/wheel/dragon land) — thumb-zone law: no high-frequency control above 55% height.
- **Motion:** balance runs a **count-up ticker** (eased, ≤400ms catch-up, snap under 1%); purchase = 1.06× scale-pop gold flash; spend = brief bone-white dip; suffix rollover ($999K→$1.0M) = one-shot letterpress stamp. Income line ticks its true accrual. **ADR-001: the displayed value may never exceed the true value.**
- **Audio/Haptics:** rollover uses Phase 99 tier-2 arpeggio; no per-tick sound (fatigue).
- **Accessibility:** heat pill gains warning chevrons ≥60% (shape channel, not color-only); all masthead text ≥12sp floor.
- **Telemetry:** `ui_rollover_seen`, session heat-pill visibility time.
- **Gate:** ticker-honesty assert in shell_smoke; mid-count capture frame; deuteranopia capture pass.

### 4.2 Stage (Z2) — "the city answers" [P1, relatedness]
- **Intent:** the world is the progress bar and the tap target.
- **Spec (shipped + deltas):** full-bleed city, ground line tracks sheet top. Tap anywhere = hustle. Diegetic golden coin (only player-initiated ad entry). NEW: **purchase echo** — buying building type X lights a matching facade window cluster (key-matched, not generic flash); **rank-up vignette** — 2s searchlight sweep, once per session max; **raid theater** — existing crimson flash + rail takeover stays the only alarm channel.
- **Motion:** all vignettes ≤2s, one per session, reduced-motion = off.
- **Haptics:** tap = light tick throttled ≥60ms; crit = medium.
- **Accessibility:** tap target is the whole gap — the genre's most generous (beats Egg Inc's button).
- **Telemetry:** taps/session, vignette impressions.
- **Gate:** input-playback tap storm (20cps) — floats bounded, haptic throttle held.

### 4.3 Attention rail (Z3) — "the whisper, not the alarm" [Flow]
- **Intent:** exactly one suggestion; the player never triages.
- **Spec (shipped + deltas):** priority queue stands. NEW: goal lines pull from the Phase 55/56 narrative backlog (faction-voiced variants, ≥3 per beat) — charm density where eyes actually are; rail item tap always routes (never dead text).
- **Accessibility:** 44px min height stands; text ≥14sp.
- **Telemetry:** `ui_rail_tap` by kind (exists) + dwell-to-tap conversion.
- **Gate:** line-slot coverage count; zero simultaneous-alert captures across matrix.

### 4.4 Content deck (Z4) — "one sheet, three heights" [competence, autonomy]
- **Intent:** every decision the player can act on lives in one scrollable sheet; the city never fully dies except FULL.
- **Spec (shipped + deltas):** PEEK/REST/FULL stands. NEW: **veteran compact mode** (rows 64px: name + cost + underbar; hide-owned filter in sheet header) — disclosure-gated behind prestige ≥1; **first-frontier rule** stands (first locked item always fully readable).
- **Rows:** 3-state grammar is law (READY solid gold / APPROACHING outline + afford underbar / LOCKED silhouette). Afford underbar doubles as the competence meter.
- **Motion:** row state transitions cross-fade 150ms (no popping between states).
- **Accessibility:** action buttons ≥48dp (shipped); compact mode keeps 48dp buttons (row shrinks, target doesn't).
- **Telemetry:** compact-mode adoption, rows-scrolled/session.
- **Gate:** compact capture ≥7 rows at REST 720×1280; 150% text-scale matrix with zero overflow.

### 4.5 Nav dock (Z5) [Flow]
- **Spec (shipped + deltas):** 5 tabs stand. Badge dots resolve or die: a dot must clear within one visit or it never fires again for that cause (anti-badge-fatigue rule, H5). Owner decision D2 may add gear here.
- **Gate:** badge-resolution assert in shell_smoke (visit tab → dot clears).

### 4.6 Welcome-back ceremony — the retention crown jewel [P1+P2, 73% stat]
- **Intent:** the single moment that decides tomorrow's session; currently a text wall, must become the signature.
- **Spec:** staged on the city itself: (1) city fades in from dark, districts light in sequence ~1.2s → (2) masthead ticker counts the offline gain live → (3) compact ledger card: earnings · ops ready · territory/rival deltas · one rival news line (narrative slot) → (4) ad-double + wheel-spin buttons appear only after the count settles, never gating dismiss. Tap anywhere skips to summary instantly.
- **Cap copy flips to invitation:** "The crew worked 8h — check in sooner and they'll keep the take flowing."
- **Audio/Haptics:** tier-3 prestige-family cue at count completion; single medium haptic.
- **Telemetry:** ceremony completion vs skip rate, ad-double conversion pre/post (the honest A/B).
- **Gate:** input-playback spec — 8h seed, dismiss at frames 10/40/90 all clean; reduced-motion = instant summary capture.

### 4.7 Prestige ceremony [P2, achiever]
- **Spec:** port the Phase 101 climax to the stage: skyline dims to silhouette → gold "EMPIRE ASCENDED +X INFLUENCE" over the city → skyline rebuilds at tier 0 as the fade lifts (the wipe becomes visible fiction, not a loading hiccup). 3s, skippable.
- **Gate:** capture triptych (pre/climax/post); no save-schema change.

### 4.8 Empire Report (stats) [competence]
- **Spec (shipped + deltas):** three sections stand. NEW: "Tonight's Wire" becomes the narrative archive (elimination lines, rank epitaphs from the Phase 55 backlog); career section gains a per-run vs career split when run-stats fields exist (deferred until then — Phase 57 lesson: don't spec against fields that don't exist).
- **Gate:** wire shows ≥3 authored line variants per beat class.

### 4.9 Settings & trust surface [P3]
- **Spec:** existing config screen + NEW **Fair Play panel**: the charter, in-game, player-readable: no interstitials ever · ads only player-initiated with reward stated up-front · no countdown offers · no disguised buttons · offline progress never ad-gated · haptics/motion/text-scale controls. Charter also ships as `docs/TRUST_CHARTER.md` — **ADR-003: charter violations are release blockers.**
- **Text scale:** extend to 150%.
- **Gate:** V4 zone audit (zero monetization nodes in Z1/Z3/Z5); charter panel capture.

### 4.10 First minute [L1: "no tutorials to wade through"]
- **Spec:** for the first 60s the only instruction surfaces are the stage tap-halo and one rail line. Tutorial banner may not appear before the first purchase. Target: median `ui_first_building_buy_ms` < 25s (telemetry exists).
- **Gate:** fresh-save capture shows no banner; telemetry threshold on beta data.

---

## 5. Owner decision points — DECIDED 2026-07-03

| # | Decision | Outcome |
|---|---|---|
| D1 | Balance placement | **Top-center hero stays** (read-only, so red-zone is acceptable; it's the show) |
| D2 | Red-zone controls (gear · wheel · dragon) | **Dock up-sheet** — long-press/overflow on the nav dock opens a bottom sheet with all three; masthead chips become mirrors or retire |
| D3 | Haptics default | **ON + one-time first-session toast** pointing at the settings toggle |
| D4 | Welcome-back intensity | **Full ceremony** (§4.6 as specced: city light-up → live ticker → ledger card) |
| D5 | Compact mode entry | **Rail offer once after prestige 1** (AttentionDirector one-shot) |

All choices reversible behind flags. These decisions satisfy the Ready gates of V2-B (D4), V2-C (D3), V2-D (D2), V2-E (D5).

---

## 6. Production plan (studio solo mode)

Stories, each one shippable diff with Ready/Done gates; Done always includes capture-matrix diff + owner sign-off (draft-and-approve).

| Story | Content | Ready gate | Done gate | Effort |
|---|---|---|---|---|
| **V2-A** | §4.1 performing ledger + type/colorblind floors | ADR-001 approved | ticker-honesty assert · reduced-motion pair · V3 token lint green | S–M |
| **V2-B** | §4.6 welcome-back ceremony + cap-invitation copy | V2-A merged · D4 answered · 4-frame storyboard capture approved | playback dismiss spec green · skip telemetry wired | M |
| **V2-C** | §4.2 stage echoes + haptics layer | D3 answered · device pass available | tap-storm throttle held · vignette cap asserted | M |
| **V2-D** | §4.9 trust surface + §4.10 first minute + D2 thumb moves | D2 answered · charter text approved (ADR-003) | V4+V5 audits green · fresh-save capture clean | S–M |
| **V2-E** | §4.4 compact mode + §4.3/§4.8 narrative density + §4.7 prestige ceremony | D5 answered · line inventory triaged | compact capture gate · triptych · wire variants ≥3 | M |

**Validators (pre-merge set):** V1 shell_smoke · V2 capture matrix · V3 token lint (no raw hex/fonts in shell/screens/components) · V4 zone audit (monetization only in Z6, via rects JSON) · V5 thumb audit (frequent controls ≤55% height, targets ≥48px) · V6 type-floor audit (≥14sp body/≥12sp caption at 100% & 150%, zero collapsed controls) — V4–V6 run on `--debug-rects` output.

**Path-scoped rules (review law):** `shell/**` routing+chrome only, GameState mutations via public methods only · `screens/**` own tab only · `components/**` stateless, tokens only · `systems/**` never touch UI nodes · all UI: ×delta or Tween, no hot-path allocations.

**ADRs** (`docs/ui/adr/`): ADR-001 ticker honesty · ADR-002 top-read-only policy · ADR-003 charter as release blocker. Disputes get an ADR before code.

**Non-goals:** no balance changes · no save-schema changes beyond settings fields (haptics, compact — with migration defaults) · no new monetization surfaces.

---

## 7. Acceptance matrix (all machine-checkable)

| Surface | Gate | Tool |
|---|---|---|
| Masthead | ticker never exceeds truth; mid-count + rollover captures; deuteranopia pass | shell_smoke assert + ui_capture |
| Stage | 20cps tap storm: floats ≤24, haptics throttled | input playback |
| Rail | one item max across all matrix captures; ≥3 line variants/beat | matrix + grep |
| Deck | compact ≥7 rows @REST 720; 150% scale zero-overflow; state cross-fade capture | matrix + V6 |
| Dock | badge clears on visit | shell_smoke |
| Welcome-back | dismiss at any frame; reduced-motion instant | playback spec |
| Trust | zero monetization nodes Z1/Z3/Z5; Fair Play panel present | V4 |
| First minute | no banner pre-purchase; median first-buy <25s | capture + telemetry |

## 8. Sources

- Method: [claude-code-game-studios](https://github.com/donchitos/claude-code-game-studios) — director vision → department specs → present-options-user-decides → quality gates; MDA/SDT/Flow/Bartle foundation (applied §2–§3, §5).
- [Egg Inc usability analysis](https://medium.com/design-bootcamp/as-addictive-as-raising-chickens-1c59c804a5bf) · [Egg Inc sentiment intel](https://marlvel.ai/intel-report/games/egg) · [Egg Inc App Store](https://apps.apple.com/us/app/egg-inc/id993492744)
- [Idle-family clutter reviews](https://apps.apple.com/us/app/idle-zombie-miner-gold-tycoon/id6471983323) · [AdCap clean-screen praise](https://kbhgames.com/game/adventure-capitalist)
- 2026 roundups / zero-ad lists: [GameSpot](https://www.gamespot.com/gallery/best-idle-games/2900-5676/) · [Pro Game Guides](https://progameguides.com/mobile/best-idle-mobile-games/) · [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/best-idle-games) · [Mr. Mine](https://blog.mrmine.com/11-best-idle-games-on-pc-in-2025/)
- Dark patterns: [CHI paper](https://dl.acm.org/doi/fullHtml/10.1145/3491101.3519837) · [MUM '24](https://arxiv.org/html/2412.05039v1) · [PocketGamer.biz](https://www.pocketgamer.biz/prevent-ui-ux-dark-patterns-f2p-mobile-games/)
- Thumb zone: [Smashing Magazine](https://www.smashingmagazine.com/2016/09/the-thumb-zone-designing-for-mobile-users/) · [Mobile Free To Play](https://mobilefreetoplay.com/control-mechanics/) · [Parachute Design](https://parachutedesign.ca/blog/thumb-zone-ux/)
- Retention/offline: [Mind Studios](https://games.themindstudios.com/post/idle-clicker-game-design-and-monetization/) · [Draco Arts](https://dracoarts.com/blogs/why-idle-mechanics-work-even-when-you-re-offline-the-science-of-passive-progress) · [Gamigion](https://www.gamigion.com/idle/)
- Juice: [Design Lab](https://thedesignlab.blog/2025/01/06/making-gameplay-irresistibly-satisfying-using-game-juice/) · [Juicy UI](https://medium.com/@mezoistvan/juicy-ui-why-the-smallest-interactions-make-the-biggest-difference-5cb5a5ffc752) · [DesignTheGame](https://www.designthegame.com/learning/tutorial/how-tactile-interactions-game-juice-drive-player-engagement)
