# UI Overhaul Architecture — Criminal Empire (Godot 1.0)

**Status:** Design document (2026-06). **P14 in progress** — first tranche landed 2026-06-19.  
**Recommended phase ID:** **P14 — Touch-First Retention UI** (extends [`P13_REPORT.md`](P13_REPORT.md) Material Maker skin + [`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md) audio layers).  
**Policy:** [`ART_POLICY.md`](ART_POLICY.md) — Material Maker procedural textures OK; no generative AI; motion/fills stay code-drawn.  
**Ship surface:** `godot/scripts/ui/game_screen.gd` (5-tab bottom nav, portrait 720×1280, 9 logical tabs collapsed to 5+Turf subtabs).

### P14 progress (session 2026-06-19)

| Phase | Status | Notes |
|-------|--------|-------|
| **P14.0** Research lock & metrics | ✅ Done | Doc frozen; `docs/ui/capture_matrix/`; UI telemetry events wired |
| **P14.1** Theme foundation (code-first) | ✅ Done (fallback) | `GameTheme` StyleBox helpers + MM texture hooks; `UI_RUSTIC_THEME` flag |
| **P14.2** Main menu | ⬜ Next | Deferred — no MM textures yet |
| **P14.3** Header / economy HUD / buy-mult | ✅ Done | Cash-dominant header, ×1/×10/Max chip, advice chip, rank truncate |
| **P14.4** Bottom nav tab badges | ✅ Partial | Bldgs/Upgrs/Mgrs pill counts; Turf ★/• preserved; no MM tab strip |
| **P14.5–P14.9** | ⬜ Pending | Rows, overlays polish, device pass, funnel validation |

---

## 1. Executive summary

**North star:** *A ledger-clear idle crime sim where cash and income never leave the thumb zone, every screen has one obvious next action, and complexity unlocks like rank—not like a live-ops sticker wall.*

Criminal Empire already has mechanical depth (11 buildings, turf/rivals/crew/ops, prestige tree, dragon patron). Genre leaders win on **persistent economy HUD**, **affordability scanability**, **progressive disclosure**, and **zero launch friction**—not on more tabs. Players punish **icon floods**, **pop-up stacks**, **notch-blocked currency**, and **menus that fight the core loop** (Idle Miner, Army Tycoon, Cookie Clicker mobile, Melvor mobile). Egg Inc. and polished tycoons prove a **single focal column + bottom nav** scales. Hades / Slay the Spire (premium references) transfer **peripheral HUD**, **functional clustering**, **actionable-only highlights**, and **non-blocking feedback**—adapted for portrait idle, not PC hover.

P14 delivers this by layering **P13 rustic-noir surfaces** (Material Maker → `StyleBoxTexture`) under a **research-driven UX pass**: economy-first header, buy-multiplier chip, tab badge system, collapsible left column, ledger overlays, FTUE pacing, accessibility, and telemetry validation—without new mechanics or AI art.

---

## 2. Research matrix

| Game | UI strength players cite | UI pain players cite | Steal / Avoid for Criminal Empire |
|------|---------------------------|----------------------|-----------------------------------|
| **AdVenture Capitalist** | Simple core loop; optional ad boosts; events add freshness ([GameBrain](https://gamebrain.co/game/adventure-capitalist)) | Portrait-only scrolling fatigue; slow/unintuitive menus; repetitive angel screens ([JustUseApp problems](https://justuseapp.com/en/app/927006017/adventure-capitalist/problems)); dev QOL plan targets animation skip + equipment flow ([CommunityOne QOL](https://communityone.io/servers/635098884481482783/adventure-capitalist/news/adventure-capitalist-qol-update-animations-ui-keys/)) | **Steal:** one-tap buy on primary resource rows; prestige reset clarity. **Avoid:** stacking event portals on launch; repetitive post-prestige re-buy UI. |
| **Idle Miner Tycoon** | Satisfying offline loop; deep mine progression ([Play Store](https://play.google.com/store/apps/details?id=com.fluffyfairygames.idleminertycoon)) | Launch pop-up floods (5–10 after absence); floating event buttons overlap gameplay ([MWM reviews](https://mwm.ai/apps/idle-miner-tycoon-money-games/1116645064)); dense top bar ([Ballmann case study](https://www.ballmann.design/idle-miner)) | **Steal:** bottom nav in dedicated bar; collapsible secondary drawer for events/ads. **Avoid:** IAP/offer modals on session start; floating promo columns. |
| **Cookie Clicker (mobile)** | Tab split mirrors desktop complexity ([Fandom Mobile App](https://cookieclicker.fandom.com/wiki/Mobile_App)); ad-less version praised for screen reclaim ([Play Store ad-less](https://play.google.com/store/apps/details?id=org.dashnet.cookieclickeradless)) | Overlapping buttons; ads push UI → mis-taps ([AllBestApps](https://allbestapps.net/android/cookie-clicker-1)); golden cookies off-screen behind UI | **Steal:** dedicated Store/Stats subtabs; settings isolated. **Avoid:** banner-ad layout shift; cramming desktop density without reflow. |
| **Egg Inc.** | “Pixel perfect UI”; minimal menus vs 3D farm ([App Store](https://apps.apple.com/us/app/egg-inc/id993492744)); clean aesthetic vs “cluttered mess” tycoons ([iofreeonline review](https://www.iofreeonline.com/IOS/game/Egg,-Inc.html)) | Progress loss anxiety (save/cloud—not UI); depth hidden until mid-game | **Steal:** one primary tap target (coin btn ↔ hatchery); research as progressive unlock. **Avoid:** hiding critical stats behind decorative chrome. |
| **Melvor Idle** | “Never struggled to find information” on PC ([Steam review Synik](https://steamcommunity.com/id/Synikx/recommended/1267910/)) | Mobile header wraps, hides XP bar ([#4641](https://github.com/MelvorIdle/melvoridle.github.io/issues/4641)); bank/trader chrome eats screen ([#4165](https://github.com/MelvorIdle/melvoridle.github.io/issues/4165)); UI update backlash on spacing ([Steam discussion](https://steamcommunity.com/app/1267910/discussions/0/4337609701284804840/)) | **Steal:** deep stats when requested; cross-save continuity story in Config. **Avoid:** multi-line header cram; fixed panels that steal scroll area on small phones. |
| **Tap Titans 2** *(genre adjacent)* | Persistent DPS/ gold; hero upgrade list scan | Late-game ability button sprawl; clan/event icon creep (common incremental complaint pattern) | **Steal:** always-visible DPS analog (IPS + click value). **Avoid:** skill bar explosion—use Turf subtabs instead of new icon rows. |
| **Idle Slayer** *(genre adjacent)* | Minimal HUD; platformer clarity | Platform UI ≠ management density—limited transfer | **Steal:** milestone celebration real estate (full-width toast). **Avoid:** literal platform HUD—CE is menu-forward. |
| **Burger Please!** *(hyper-casual idle)* | Large tap targets; obvious next station | Shallow—UI hides depth intentionally | **Steal:** first-session single-column focus. **Avoid:** oversimplifying turf/crew unlock messaging. |
| **Army Tycoon: Idle Base** | “Satisfying” early week ([Marlvel intel](https://marlvel.ai/intel-report/games/army-tycoon-idle-base)) | “Entire screen filled with icons for other stuff” | **Steal:** none on density. **Avoid:** icon grid for every live-op feature. |
| **Cat Snack Bar** *(casual idle)* | Calming loop | Side-quest buttons obscure play ([Marlvel intel](https://marlvel.ai/intel-report/games/cat-snack-bar-food-games)) | **Steal:** optional hide for secondary quests (Config toggle for ad/IAP promos). **Avoid:** permanent side-column promo stacks. |
| **Hades** *(premium reference)* | Peripheral HUD; codex unlock notifications; diegetic hub ([Medium — Responsive Underworld](https://medium.com/@Nat.Rowley/how-hades-creates-a-responsive-underworld-915715a7c2a)) | PC-first hover/tooltip density | **Steal:** Mirror/Codex clarity → prestige tree + stats tiers; invalid-action voice → error SFX + toast. **Avoid:** requiring hover for perk details (already fixed in `prestige_tree_overlay.gd`). |
| **Slay the Spire** *(premium reference)* | Actionable highlights; non-blocking animations; massive hit targets ([Cloudfall UI thoughts](https://www.cloudfallstudios.com/blog/2018/2/20/flash-thoughts-slay-the-spires-ui)) | Full card text on screen impossible ([Steam discussion](https://steamcommunity.com/app/646570/discussions/0/4756451924767171846/)) | **Steal:** highlight only affordable/actionable rows; input never waits on animation. **Avoid:** hiding row consequences behind tap-to-expand on mobile primary actions. |

---

## 3. Player sentiment synthesis

Evidence snippets are paraphrased from public reviews, forums, and industry write-ups (2024–2026). Not invented quotes.

### Top 10 likes (cross-genre)

| # | Theme | Evidence snippet | CE implication |
|---|--------|------------------|----------------|
| 1 | **Persistent economy visibility** | Clicker UX guides: “Top HUD: current resources and production rate (always visible)” ([SEELE clicker UI](https://www.seeles.ai/resources/blogs/scratch-clicker-game-ui)) | Balance + IPS dominate header; rank demoted (P13 retention #1). |
| 2 | **Clean / minimal chrome** | Egg Inc.: “Instead of menus, crisp colorful graphics” + “pixel perfect UI” ([App Store listing](https://apps.apple.com/us/app/egg-inc/id993492744)) | MM textures add warmth, not boxes-on-boxes. |
| 3 | **Obvious affordability** | “Make affordability obvious: color-code upgrade buttons” ([SEELE](https://www.seeles.ai/resources/blogs/scratch-clicker-game-ui)) | Wax seal / green tint buyable; flat grey locked (P13 #3). |
| 4 | **Satisfying tap feedback** | StS: “cast cards as quickly as you'd like… animations do their own pace” ([Cloudfall](https://www.cloudfallstudios.com/blog/2018/2/20/flash-thoughts-slay-the-spires-ui)) | Keep `<50ms` click response; float text + SFX (P6 wired). |
| 5 | **Offline / return clarity** | Idle Miner: “offline capabilities” praised ([MWM](https://mwm.ai/apps/idle-miner-tycoon-money-games/1116645064)) | Ledger offline modal—not toast-only (already exists; polish in P14). |
| 6 | **Bottom nav thumb reach** | Mobile UX guides: “bottom third… primary actions” ([Draco Arts HUD hierarchy](https://dracoarts.com/blogs/master-the-hud-the-science-of-visual-hierarchy-in-mobile-game-ui)) | P7 bottom bar validated; extend badge grammar. |
| 7 | **Findable deep stats** | Melvor PC: “never once struggled to find a piece of information” ([Steam Synik](https://steamcommunity.com/id/Synikx/recommended/1267910/)) | Stats dashboard tiers (`stats_dashboard.gd`)—surface summaries, drill down. |
| 8 | **Progressive unlock feels rewarding** | “Unlock UI elements as players progress” ([Appnality FTUE](https://www.appnality.com/blog/guide-to-mobile-game-ui-ux-design/)) | Crew/Ops lock labels (`n/5`, `n/2`) → wax-stamp locked subtabs. |
| 9 | **Optional ads, not layout hijack** | Cookie ad-less: “no more ads taking ridiculous amount of screen” ([Play Store](https://play.google.com/store/apps/details?id=org.dashnet.cookieclickeradless)) | Ad buttons in overlay/Config—not banner push. |
| 10 | **Milestone celebration** | Idle design tutorial: “Celebrate milestones and significant upgrades” ([DesignTheGame](https://www.designthegame.com/learning/tutorial/crafting-compelling-idle-games)) | Bracket + vignette overlays (Phase 127 / P13 #9). |

### Top 10 dislikes (cross-genre)

| # | Theme | Evidence snippet | CE implication |
|---|--------|------------------|----------------|
| 1 | **Screen flooded with icons** | Army Tycoon: “entire screen becomes filled with icons for other stuff” ([Marlvel](https://marlvel.ai/intel-report/games/army-tycoon-idle-base)) | Cap persistent chrome: header + left column + bottom bar only. |
| 2 | **Launch pop-up stacks** | Idle Miner: “5 to 10 pop ups for events” after short absence ([MWM](https://mwm.ai/apps/idle-miner-tycoon-money-games/1116645064)) | Queue overlays: offline → daily → milestone; never parallel modals. |
| 3 | **Currency hidden by notch** | Idle Factory: “currency information behind camera cutouts” ([Marlvel](https://marlvel.ai/intel-report/games/idle-factory-tycoon-business)) | `_apply_safe_area()` + header stress test on punch-hole ([`DEVICE_TEST_CHECKLIST.md`](DEVICE_TEST_CHECKLIST.md)). |
| 4 | **UI overlap / broken tabs** | Cookie mobile: “Can't switch from buildings to upgrades tab” ([AllBestApps](https://allbestapps.net/android/cookie-clicker-1)) | Regression suite at min/max aspect; no overlapping scroll regions. |
| 5 | **Ads pushing interactive UI** | Cookie: “banner ads… push the rest of the UI up… accidental click” ([AllBestApps](https://allbestapps.net/android/cookie-clicker-1)) | Rewarded buttons inline; no banner strip in ship layout. |
| 6 | **Header bloat wrapping** | Melvor: “top bar… wrapping incorrectly… covers the xp bar” ([#4641](https://github.com/MelvorIdle/melvoridle.github.io/issues/4641)) | Single-line header; truncate rank; overflow menu for secondary stats. |
| 7 | **Slow / unintuitive menus** | AdCap: “Menu is slow and unintuitive” ([JustUseApp](https://justuseapp.com/en/app/927006017/adventure-capitalist/problems)) | Config as scroll list OK—add section anchors; avoid gear → full-screen rebuild lag. |
| 8 | **Repetitive post-prestige UI** | AdCap QOL: “less repetitive… re-buy the same upgrades” ([CommunityOne](https://communityone.io/servers/635098884481482783/adventure-capitalist/news/adventure-capitalist-qol-update-animations-ui-keys/)) | Prestige tree: show owned perks; bulk advice from Rudy/Rob panels. |
| 9 | **Too many simultaneous missions** | Sunshine Island: “overwhelming volume of simultaneous tasks… cluttered” ([Marlvel](https://marlvel.ai/intel-report/games/com-newmoonproduction-sunshineisland)) | One tutorial banner; goal toast throttle; syndicate events modal-only. |
| 10 | **Mobile = afterthought density** | Melvor: “phone UI can get a bit cluttered… choose only to play on PC” ([Steam Synik](https://steamcommunity.com/id/Synikx/recommended/1267910/)) | Turf/Stats/Mgrs get dedicated layout budget (P7 debt). |

---

## 4. Competitive gap analysis (honest — today vs leaders)

| Dimension | Genre leaders | Criminal Empire today (`game_screen.gd` / P7) | Gap severity |
|-----------|---------------|-----------------------------------------------|--------------|
| **Economy HUD** | Balance largest type; +IPS always visible | Header has Balance, Income, Rank—functional but flat `StyleBoxFlat` theme | Medium — hierarchy not yet visual |
| **Primary action** | Egg Inc. central tap; AdCap row buy | Coin + Hustle in left column—good, but competes with heat/prestige/dragon stack | Medium — left column crowded |
| **Navigation** | 4–5 bottom tabs; Melvor sidebar on PC | 5 bottom + Turf 4 subtabs + gear Config—sound IA | Low — architecture OK |
| **Affordability scan** | Color/seal on every buy row | Rows exist; no global ×1/×10/Max chip; no wax-seal affordance | High — P13 #2–3 not shipped |
| **Tab badges** | Notification dots on actionable tabs | Turf ★/• and Crew/Ops lock text; **no** Upgrs/Mgrs affordable badges | High — P13 #5 |
| **Progressive disclosure** | Cookie mobile drops subtabs; SEELE unlock table | Crew/Ops locks present; dragon HUD always expanded | Medium |
| **Visual polish** | Egg “pixel perfect”; MM-style tactile panels | `noir_theme.tres` flat panels only | High — P13 not started |
| **Overlay discipline** | Best: single return modal | Offline, milestone, event, elim, prestige tree, dragon—**queued** but visually same flat panel | Medium |
| **Monetization UI** | Idle Miner pop-ups (anti-pattern) | Ad buttons on offline + coin; IAP in Config—**better**, but unstyled dynamic buttons | Low–medium |
| **Audio/UI sync** | AdCap separate music/SFX sliders (requested) | Sliders in Config; M1+ music layers pending ([`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md)) | Medium |
| **Accessibility** | Leaders weak; CE opportunity | No text scale, contrast mode, reduced motion toggle | High — differentiator |
| **Safe area / perf** | Failures cited on notches | `_apply_safe_area()` + 10fps stats throttle—good engineering | Low code / **unverified device** |

**Summary:** Mechanics and nav skeleton are **ahead of** many indies; **presentation and scanability** lag Egg Inc. / polished tycoons; **clutter risk** is moderate from left column + unbadged upgrades + dynamic ad buttons.

---

## 5. Design principles (research-derived)

1. **Economy never scrolls away** — Balance + IPS stay in fixed header on every tab and overlay (except full-screen prestige confirm).
2. **One primary action per screen** — Buildings tab: buy next affordable building; Turf: next capturable district; Stats: view breakdown (read-only).
3. **Affordability is pre-attentive** — Buyable rows get seal/green edge at a glance; unaffordable rows recede to muted ledger grey (no equal-weight buttons).
4. **Progressive disclosure, not hidden depth** — Locked systems show *why* locked (wax stamp + `n/5` progress), not absent tabs.
5. **Bottom nav = verbs, header = nouns** — Tabs name systems; header holds cash, income, rank chip only.
6. **Overlay queue, never stack** — Offline → daily → milestone → event; dim layer single depth; dismiss = one thumb target.
7. **Secondary monetization is opt-in** — Rewarded CTAs sit on relevant surfaces (offline, coin), never intercept tab switches or session start.
8. **Functional clustering + thumb gutter** — Primary taps in bottom 40%; gear/menu top-right reach zone; 48px minimum (P7 met—preserve under textures).
9. **Feedback non-blocking** — Animations and SFX never gate the next tap (StS pattern); milestone modal excepted.
10. **Texture for surfaces, code for state** — MM for paper/leather/brass; heat fill, pulses, badges stay procedural ([`ART_POLICY.md`](ART_POLICY.md) §4).
11. **Audio obeys UI context** — Menu ambient (M1) ducks under overlay stingers; heat ≥60% tension layer without masking error SFX ([`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md) §1 mood table).
12. **If everything is important, nothing is** — Max one pulsing element per viewport (Hades peripheral rule adapted: heat critical *or* goal toast, not both screaming).

---

## 6. Phase architecture — P14 (Touch-First Retention UI)

**Naming:** Use **P14** as the umbrella UX overhaul. [`P13_REPORT.md`](P13_REPORT.md) sub-steps map to **P14.1–P14.7** (visual + chrome). P13 name remains valid as the Material Maker skin track; P14 adds FTUE, accessibility, metrics, and music-layer hooks.

**Dependencies:** P5 parity ✓ · P7 layout structure ✓ · P8 device pass recommended before full texture VRAM · P6 audio wired · P9 pacing ported.

**Parallel rule:** P14.1–P14.3 can start in editor; P14.7 requires Moto G matrix from [`DEVICE_TEST_CHECKLIST.md`](DEVICE_TEST_CHECKLIST.md).

### P14.0 — Research lock & metric baseline

| Field | Content |
|-------|---------|
| **Goal** | Freeze UX north star and baseline funnel before visual churn. |
| **Scope (in)** | This document; screenshot matrix (720×1280, 19.5:9, 16:9); telemetry event list (§9). |
| **Out of scope** | Scene edits. |
| **Deliverables** | `UI_OVERHAUL_ARCHITECTURE.md`; optional `docs/ui/capture_matrix/` before shots. |
| **Exit criteria** | Owner sign-off on principles §5; baseline `tab_open` / `session_start` events defined. |
| **Risks** | Analysis paralysis — timebox 2d. |

### P14.1 — MM pipeline + theme foundation *(P13.0–P13.1)*

| Field | Content |
|-------|---------|
| **Goal** | Swap flat `StyleBoxFlat` for rustic-noir textured theme without breaking soak/VRAM. |
| **Scope (in)** | `godot/assets/ui/material_maker/` graphs; `rustic_noir_theme.tres`; `GameTheme` texture refs; one row spike. |
| **Out of scope** | Screen layout moves; new tabs. |
| **Deliverables** | Theme resource; asset README; rollback to `noir_theme.tres`. |
| **Exit criteria** | Headless soak PASS; VRAM ≤ P13 budget (<1.5 MB UI art); one building row textured. |
| **Integrations** | ART_POLICY §4; keep progress fills code-drawn. |

### P14.2 — Main menu & session entry *(P13.2)*

| Field | Content |
|-------|---------|
| **Goal** | First impression matches in-game ledger fantasy; continue/new/import clarity. |
| **Scope (in)** | `main_menu.tscn` / `main_menu.gd`; save preview typography; subtle grain. |
| **Out of scope** | Store listing art (P11). |
| **Deliverables** | Textured menu; preview shows prestige/influence/playtime hierarchy. |
| **Exit criteria** | F5 menu → game ≤2 taps; import hidden on export builds (already). |
| **Music** | M0 ambient → M1 menu loop crossfade on entry ([MUSIC_ARCHITECTURE.md](MUSIC_ARCHITECTURE.md) M1). |

### P14.3 — Header, economy HUD, buy multiplier *(P13.3 + retention #1–2)*

| Field | Content |
|-------|---------|
| **Goal** | Cash-dominant header; global ×1/×10/Max chip; “next upgrade” affordance chip. |
| **Scope (in)** | Header layout; multiplier control; advice chip (Sticky Pete / Rudy integration). |
| **Out of scope** | New upgrade types. |
| **Deliverables** | Header scene refactor; multiplier persisted in save if needed (default ×1). |
| **Exit criteria** | Balance largest label; IPS second; rank truncates with ellipsis on narrow widths. |

### P14.4 — Bottom nav, Turf subbar, tab badges *(P13.3 + #5–6)*

| Field | Content |
|-------|---------|
| **Goal** | Commercial badge grammar on all actionable tabs. |
| **Scope (in)** | Pill badges on Upgrs/Mgrs/Bldgs; wax-stamp locked subtabs; textured tab strip. |
| **Out of scope** | Sixth bottom tab. |
| **Deliverables** | `_refresh_tab_badges()` extended; MM tab bar PNG. |
| **Exit criteria** | Affordable upgrade count visible on Upgrs; hireable manager dot on Mgrs; Turf ★/• preserved. |

### P14.5 — Row cards & left column *(P13.4 + clutter pass)*

| Field | Content |
|-------|---------|
| **Goal** | Scannable shop rows; collapsible dragon HUD; heat/prestige hierarchy. |
| **Scope (in)** | All `*_row.tscn`; dragon chip collapse (P13 #10); coin/hustle prominence. |
| **Out of scope** | Row content mechanics. |
| **Deliverables** | Card frame textures; affordance tint pipeline in row scripts. |
| **Exit criteria** | One-hand thumb reach on coin + hustle; dragon panel ≤1 line when inactive. |

### P14.6 — Stats, Config, prestige tree *(P13.5 + a11y)*

| Field | Content |
|-------|---------|
| **Goal** | Tiered stats dashboard readable on phone; Config store section polished; prestige tree perk text always visible. |
| **Scope (in)** | `stats_dashboard.gd`; Config IAP rows styled; `prestige_tree_overlay`; text scale toggle. |
| **Out of scope** | New perks/branches. |
| **Deliverables** | Collapsible stat tiers; Config section headers textured; 100%/125% text scale. |
| **Exit criteria** | Prestige tree perks readable without hover ([DEVICE_TEST_CHECKLIST.md](DEVICE_TEST_CHECKLIST.md) B). |

### P14.7 — Overlays, onboarding, motion *(P13.6 + FTUE)*

| Field | Content |
|-------|---------|
| **Goal** | Ledger modals for offline/daily/milestone/event/elim; tutorial banner coexists with queue. |
| **Scope (in)** | OverlayLayer panels; bracket + vignette; overlay queue helper; reduced-motion flag. |
| **Out of scope** | New event types. |
| **Deliverables** | Modal frame MM asset; single-flight overlay manager; tutorial highlight rects. |
| **Exit criteria** | Return session shows offline then daily sequentially; no double-dim; milestone ≠ event collision. |
| **Music** | Overlay stingers on SFX bus; ambient duck −6 dB ([MUSIC_ARCHITECTURE.md](MUSIC_ARCHITECTURE.md) §6). |

### P14.8 — Atmosphere, music layers, device pass *(P13.7 + M1–M2)*

| Field | Content |
|-------|---------|
| **Goal** | Grain/vignette + rank/heat reactive music layers; zero P8 regression. |
| **Scope (in)** | Film grain tile; M1 ambient loop; heat tension layer stub; Moto G capture matrix. |
| **Out of scope** | M3+ district motifs until post-soft-launch. |
| **Deliverables** | Grain overlay; music state machine hooks in `audio_manager.gd`; device screenshots. |
| **Exit criteria** | `memory_soak.gd` 120s PASS; Compatibility renderer parity; notch/header test PASS. |

### P14.9 — Telemetry validation & FTUE funnel

| Field | Content |
|-------|---------|
| **Goal** | Prove UI changes move retention proxies without new systems. |
| **Scope (in)** | Event instrumentation (§9); D1 funnel review; optional A/B flags via remote config seam. |
| **Out of scope** | Live ops experiments. |
| **Deliverables** | `P14_REPORT.md`; funnel table tutorial step → drop-off. |
| **Exit criteria** | ≥5 UI events firing in mock telemetry; owner review of first-prestige path. |
| **Dependencies** | P9 telemetry consent UI (Config toggle exists). |

---

## 7. Screen-by-screen overhaul map

| Surface | Current state | P14 target | Key files |
|---------|---------------|------------|-----------|
| **main_menu** | Flat VBox; continue/new/import; text preview | Ledger hero + textured panel; prestige/influence lead preview | `scenes/main_menu.tscn`, `main_menu.gd` |
| **game_screen — header** | Balance, IPS, Rank, Menu, Gear | Cash 1.4× rank; multiplier chip; next-upgrade chip; gear only | `game_screen.tscn`, `game_screen.gd` |
| **game_screen — left column** | Coin, hustle, heat, prestige, dragon HUD, buff | Coin/hustle top; heat bar textured track; dragon collapsed chip; prestige de-emphasized until eligible | `game_screen.gd`, `game_theme.gd` |
| **Tab: Bldgs** | Scroll list building rows | Card frames; wax seal buy; ×mult applies | `building_row.tscn`, `building_row.gd` |
| **Tab: Upgrs** | Upgrade rows | Badge on tab; best-value highlight (Sticky Pete) | `upgrade_row.tscn` |
| **Tab: Mgrs** | Manager rows | Hireable dot badge; row seal when affordable | `manager_row.tscn` |
| **Tab: Turf** | Subbar: Territory/Rivals/Crew/Ops | Textured subbar; wax locked Crew/Ops | `game_screen.gd` Turf subbar |
| **Tab: Turf → Territory** | Header bonus/milestone/control + rows | Compact header; scroll list priority | `territory_row.tscn` |
| **Tab: Turf → Rivals** | Impact + activity + rows | Rival elimination routes to overlay (P5 ✓) | `rival_row.tscn` |
| **Tab: Turf → Crew/Ops** | Lock labels + rows | Progress stamp on lock; ops ready `*` preserved | `crew_row`, `operation_row` |
| **Tab: Stats** | `StatsDashboard` + achievements panel | Tier collapse; textured section headers | `stats_dashboard.gd` |
| **Tab: Config (gear)** | Dynamic VBox: audio, display, retention, store, data | Section cards; styled IAP; cloud sign-in row | `game_screen.gd` `_build_config_tab` |
| **Overlay: offline/daily** | Panel + continue + watch ad | Ledger modal; daily streak line styled | `OverlayLayer/OfflinePanel` |
| **Overlay: milestone** | Title/body/dismiss | Brackets + vignette; gold title | `OverlayLayer/MilestonePanel` |
| **Overlay: syndicate event** | 3-choice panel | Same frame as milestone; choice buttons sealed | `OverlayLayer/EventPanel` |
| **Overlay: rival elim** | Epitaph panel | Full-screen dramatic frame | `OverlayLayer/ElimPanel` |
| **Overlay: prestige tree** | CanvasLayer scroll tree | Perk labels visible; branch texture headers | `prestige_tree_overlay.tscn` |
| **Overlay: dragon patron** | Full overlay | Mirror prestige frame language | `dragon_patron_overlay.tscn` |
| **Toast: notification** | Top notif label | Tiered duration/font (goals vs generic)—keep | `game_screen.gd` `_on_notification` |
| **Tutorial** | Banner label | Single banner; pointer to tab badge targets | `tutorial_banner`, `tutorial_system.gd` |

---

## 8. Retention hooks from UI (existing mechanics only)

| UI choice | Retention mechanic wired | How |
|-----------|-------------------------|-----|
| Persistent balance + IPS | Return session recognition | Player instantly sees offline progress context |
| Offline ledger modal | D1/D7 return | Cash summary + rival lines + daily streak ([P9](ROADMAP.md)) |
| Tab badges (Upgrs/Mgrs/Turf) | Session depth | Surfaces collectable ops / affordable upgrades without hunting |
| ×1/×10/Max chip | Session length | Power buyers spend stock faster → prestige loop |
| Next-upgrade header chip | Goal clarity | Reduces “what now?” drop-off mid-session |
| Wax-seal affordance | Purchase dopamine | Pre-attentive buyable rows increase click-through |
| Heat bar textured + pulse | Tension / return | Heat ≥60% visual + M2 tension layer → check-in |
| Milestone bracket overlay | Achievement chase | Milestone queue already drives re-engagement |
| Prestige tree readability | Prestige conversion | First-prestige funnel (P9) needs perk trust |
| Dragon collapsed chip | Late-game retention | Reduces early clutter; expands for patron requests |
| Config notification toggle | Push opt-in (P9) | UI consent before scheduling |
| Rewarded ad on offline only | Ethical monetization | Boost return payout without blocking loop ([SHIP_ARCHITECTURE.md](SHIP_ARCHITECTURE.md)) |
| Reduced motion toggle | Accessibility retention | Prevents motion-sensitive churn |

---

## 9. Metrics / validation

Use existing `Telemetry` autoload (mock → remote). No new gameplay systems.

| Event | When | Hypothesis |
|-------|------|------------|
| `ui_session_start` | `game_screen._ready` | Baseline sessions/day |
| `ui_tab_open` | `_set_tab` | Turf/Upgrs depth correlates with D1 |
| `ui_overlay_shown` | offline/milestone/event/elim | Queue discipline; time-to-dismiss |
| `ui_overlay_dismiss_ms` | dismiss handlers | Friction if median >8s on offline |
| `ui_buy_mult_changed` | multiplier chip | Power users ↑ session length |
| `ui_badge_click` | tab press while badge active | Badges drive intended tab switches |
| `ui_prestige_tree_open` | tree overlay | Prestige funnel engagement |
| `ui_config_open` | gear press | Support burden proxy |
| `ui_first_building_buy_ms` | first purchase | FTUE regression guard |
| `ui_tutorial_step` | `tutorial_advanced` signal | Step drop-off table |

**A/B candidates (post-P14.9, remote config):**

- Multiplier chip default ×1 vs ×10 for returning players.
- Dragon HUD collapsed vs expanded by default pre-patron.
- Offline modal: single CTA vs CTA + ad row placement.

**Manual gates:** [`DEVICE_TEST_CHECKLIST.md`](DEVICE_TEST_CHECKLIST.md) §A–B; `sim_godot_soak.py` after each P14 sub-phase.

---

## 10. Risks

| Risk | Mitigation |
|------|------------|
| **Clutter regression** | Chrome budget: max 3 persistent regions (header, left, bottom). No floating promo column. Overlay queue enforced in P14.7. |
| **Perf / VRAM** | MM budget <1.5 MB; atlas shared 9-slices; keep `_STATS_UI_INTERVAL` 0.1s; particle toggle in Config. |
| **Safe-area / notch** | Re-run `_apply_safe_area()` on `size_changed`; test punch-hole + home bar; balance never in top corner alone. |
| **Thumb reach** | Left column scroll or collapse on short aspect; bottom bar 56px preserved. |
| **Texture readability** | WCAG contrast check on muted text over paper tile; high-contrast mode flattens to `StyleBoxFlat` fallback. |
| **Music/SFX clash** | Duck rules in M1; milestone SFX priority over ambient ([MUSIC_ARCHITECTURE.md](MUSIC_ARCHITECTURE.md)). |
| **Scope creep** | P14 out of scope: new tabs, currencies, live-ops icons ([ROADMAP.md](ROADMAP.md) operating principles). |
| **Rollback** | Keep `noir_theme.tres` one-click; feature flag `GameConfig.UI_RUSTIC_THEME`. |

---

## Appendix — P13 ↔ P14 mapping

| P13 step ([P13_REPORT.md](P13_REPORT.md)) | P14 step |
|-------------------------------------------|----------|
| P13.0 Pipeline spike | P14.1 |
| P13.1 Theme | P14.1 |
| P13.2 Main menu | P14.2 |
| P13.3 Header/nav/badges | P14.3 + P14.4 |
| P13.4 Rows | P14.5 |
| P13.5 Stats | P14.6 |
| P13.6 Overlays | P14.7 |
| P13.7 Grain/device | P14.8 |
| — | P14.0 research, P14.9 metrics |

---

## References (external)

- [Ballmann — Idle Miner Tycoon UX case study](https://www.ballmann.design/idle-miner)
- [DesignTheGame — Crafting Compelling Idle Games](https://www.designthegame.com/learning/tutorial/crafting-compelling-idle-games)
- [Appnality — Mobile Game UI/UX Guide](https://www.appnality.com/blog/guide-to-mobile-game-ui-ux-design/)
- [Draco Arts — Visual Hierarchy in Mobile HUD](https://dracoarts.com/blogs/master-the-hud-the-science-of-visual-hierarchy-in-mobile-game-ui)
- [SEELE — Clicker Game UI patterns](https://www.seeles.ai/resources/blogs/scratch-clicker-game-ui)
- [Egg Inc. — App Store listing](https://apps.apple.com/us/app/egg-inc/id993492744)
- [Melvor Idle — GitHub mobile UI issues #4165, #4641](https://github.com/MelvorIdle/melvoridle.github.io/issues/4165)
- [Hades — Responsive Underworld UI (Medium)](https://medium.com/@Nat.Rowley/how-hades-creates-a-responsive-underworld-915715a7c2a)
- [Slay the Spire UI — Cloudfall Studios](https://www.cloudfallstudios.com/blog/2018/2/20/flash-thoughts-slay-the-spires-ui)
