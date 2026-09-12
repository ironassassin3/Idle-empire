# Publish checklist — Criminal Empire (Google Play, v1.0.0)

**Created:** 2026-09-10 · **Owner:** Ayden · **Target track:** Closed testing → soft launch
**Supersedes the "ranked path" in** [`SHIP_AUDIT.md`](SHIP_AUDIT.md) **as the live task list.**
**Interactive tracker (shared, checkable):** https://claude.ai/code/artifact/bb8fc9dc-5581-430f-934d-a2d41e706f48
Evidence files: [`DEVICE_PASS_RESULTS.md`](DEVICE_PASS_RESULTS.md) · [`SHIP_ARCHITECTURE.md`](SHIP_ARCHITECTURE.md) · [`ANDROID_SETUP.md`](ANDROID_SETUP.md)
Compliance drafts: [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md) · [`docs/PLAY_DATA_SAFETY.md`](docs/PLAY_DATA_SAFETY.md) · [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md)
**Last full automated verification:** 2026-09-12 — `.\verify_ship.ps1` **PASS** (deck bounds,
default layout 36/36, consent, display-backed v1 contract, deck gesture, strengthened scroll gesture,
30s soak, income parity 4/4, branch validation 40/40, autobattler determinism). Godot still emitted
RID/texture/ObjectDB/resource cleanup messages at exit; this was not a warning-free run. The earlier
expanded polish matrix was rerun on 2026-09-12 and passed **162/162 layout cases**; it emitted the
same class of exit-time cleanup diagnostics.

**Verdict today:** **Not release-ready.** A signed baseline AAB, store copy, compliance drafts, icon,
and feature graphic exist, but that AAB predates the current polish source and is the **signed baseline**,
not the public-release candidate. The player-facing bar in Gate 0 and the Play-installed/device evidence
in Gates A/B/E must pass before the final build is cut. Automated bounds checks catch measurable
clipping, overflow, and chrome collisions; they do not prove visual consistency, contrast, touch feel,
or complete device usability.

Legend — **[code]** doable in this repo · **[owner]** needs Ayden's accounts / device / hands · **[both]**

---

## Gate 0 — Player-facing polish bar (blocks public release)

**Definition:** a new player can understand, control, enjoy, and trust the game without a developer
explaining it. A feature may be deferred; a visible control that silently does nothing may not.

### First 60 seconds — identity and confidence

- [ ] **[owner]** Record and pass the P15 15-second taste flow on the Play-installed build:
  launch → New Game → hustle → buy one building → open Settings
  - [ ] No blank frame, layout jump, clipped title, placeholder, debug text, missing glyph, or warm/rustic panel
  - [ ] The city is the visual hero immediately; the first profitable action is obvious without coaching
  - [ ] Menu, game, overlays, icon, screenshots, and feature graphic read as one **violet/ink neon-noir** product
- [ ] **[both]** Three uncoached testers can start earning, buy a building, and explain the next goal
  after five minutes; record every hesitation instead of teaching around it

### Touch, navigation, and readability

- [ ] **[both]** Content-sheet handle feels predictable: visible state, deliberate drag threshold,
  stable snap targets, and no bounce/ratchet (`content_deck.gd`)
- [ ] **[both]** Every long list scrolls smoothly under a thumb; a scroll never becomes an accidental
  purchase, and buttons do not steal a drag (`building`, `upgrade`, `turf`, `rivals`, `stats`, Settings)
- [ ] **[owner]** One-handed pass on the moto g: hustle, BUY, tabs, close buttons, and prestige are
  comfortably reachable with no repeated misses
- [ ] **[owner]** Default text is readable at arm's length; 100% / 125% / 150% text scales produce no
  clipping, overlap, hidden price, or unreachable control
- [ ] **[owner]** Android Back unwinds overlay → sheet/tab → press-again-to-exit; rotation remains
  portrait; notch, status bar, and gesture bar never cover UI
- [ ] **[owner]** Reduced motion disables pulses, grain, coins, and skyline motion without removing
  state feedback; important states are not communicated by colour alone

### Game feel and presentation consistency

- [ ] **[owner]** Hustle, BUY, unlock, collect, failure, reward, and prestige each have immediate and
  distinct visual/audio feedback; no input feels ignored and no toast/audio burst stacks into noise
- [ ] **[owner]** Ten-minute audio pass: menu/game loop transitions have no pop or loud seam, cues do
  not become irritating, mute works, and volume changes apply immediately
- [ ] **[owner]** Free-spin STOP is readable as timing skill: marker stops where pressed and the segment
  under the needle matches the reward; cash wager remains visibly pure RNG
- [ ] **[both]** Visual consistency sweep across every tab and overlay: no obsolete gold/rustic surface,
  text-only wall that is hard to scan, mismatched button state, stale tutorial pill, or low-contrast lock
- [ ] **[owner]** Late-game density still reads at 1,000+ buildings: skyline stays framed, the active
  business reaction is visible, and rows remain distinguishable without hunting

### Pacing, comprehension, and trust

- [ ] **[owner]** Fresh-save first prestige takes roughly **40–60 engaged minutes**, requires meaningful
  purchases/upgrades, and is discovered without being told where Prestige lives
- [ ] **[owner]** Continue through the next cycle: P1→P2 feels meaningfully faster but not disposable
  (target **25–40 minutes**); no single turf payout or purchase skips the run's decisions
- [ ] **[owner]** Every locked system says what unlocks it and shows progress; every spend states its
  cost; displayed income, offline gain, wheel/card result, and granted reward match the balance
- [ ] **[owner]** Tutorial teaches only what is needed, never covers the action it describes, can be
  replayed, and does not keep interrupting once the player demonstrates the action
- [ ] **[both]** No dead promises in Settings. Before the release candidate, choose one for each:
  - [x] **Notifications:** removed — switch gone, autoload disabled, `post_notifications` off in both presets
  - [x] **Cloud backup:** removed — "Sign in (cloud backup)" gone, `CloudSave` disabled, no backup claim in v1
  - [x] **Shared Analytics:** exposes only `OFF` / `DEVICE`; nothing leaves the device, revoke purges the queue
  - Machine-verified by `v1_contract_probe.gd` (UI text, autoload state, and both export presets) and
    `consent_probe.gd`, both inside `.\device_pass.ps1 smoke`; the v1 service check runs display-backed
    so headless self-disabling cannot mask initialization drift. Owner still confirms the *screen reads*
    right on device; the dead controls themselves can no longer come back unnoticed.
- [ ] **[owner]** Background/resume pass: three pause/resume cycles, one force-stop/reopen, and one real
  offline gap restore the correct screen/save and show one clean offline-return summary
- [ ] **[both]** No unresolved issue reported independently by two testers; no known crash, save-loss,
  purchase-loss, forced exit, unreadable screen, or silent control is waived as “good enough”

### Explicitly not required for v1 polish

- 60 FPS on the moto g if the game holds a stable ≥30 FPS under the real stress pass
- Material Maker surfaces, faction crests, a full icon pack, or extra content
- Notifications, cloud save, or remote analytics if their controls/copy/permissions are cleanly removed
- Reworking a subjective screen that passes comprehension, readability, input, and consistency checks

### Polish execution order

1. ~~Remove or finish the three dead Settings promises (notifications, cloud backup, shared analytics).~~
   **Done 2026-09-11** — all three removed and locked behind `v1_contract_probe.gd`.
2. Fix only the touch/readability issues reproduced on the current moto g build.
   Code half landed for the two reproduced ones (sheet handle, list scrolling); both now have probes.
   **Still needs a thumb on the moto g** — a probe proves a drag is not a tap, not that it feels right.
3. Run the uncoached first-prestige + second-cycle pacing pass and tune from observed evidence.
4. Run real ads/IAP, background/resume, late-save, and stress checks on a Play-installed build.
5. Resolve repeated tester confusion, freeze code/content, then cut and hash the release candidate.

---

## Gate A — On-device playtest (core evidence for Gate 0)

The July P0 fixes are code-complete and evidence-free. One clean human run settles most of this.

- [ ] **[owner]** Fresh New Game → first prestige, end to end on the moto g, no `adb` driving
  - [ ] First prestige lands on a deliberate curve — **not** ~19 min / 0 upgrades (gate is now 120M, `game_config.gd:23`)
  - [ ] Prestige is findable at gate-met without being told where — PRESTIGE chip + attention rail
  - [ ] Tutorial hints replay via Settings → "Replay Tutorial Hints" and the toast fires
  - [ ] Skyline stays inside the stage at high building counts
- [ ] **[owner]** Loaded late-game save pass — 1000+ buildings, city still reads, rows still usable
- [ ] **[owner]** Tier-3 items no harness can reach:
  - [ ] Audio — quiet room, real listen, sliders adjust live (SFX base gain now 0.65, `audio_manager.gd`)
  - [ ] Free-spin STOP timing reads as **skill**, distinct from the pure-RNG cash wager
  - [ ] One-handed reach — all primary actions in thumb zone at 720×1604
  - [ ] Golden coin: spawn → tap → powerup → stays gone → ad-grant respawn
  - [ ] Portrait-lock holds through rotation
  - [ ] Offline-return overlay renders correctly after a real time gap
- [ ] **[owner]** Android Back: closes overlays/sheet/tab, then press-again-to-exit — **does not force-quit**
  - A 2026-09 debug-device pass reported this now passes; the 2026-07-30 pass said the Java `onBackPressed`
    path still killed the app. Debug-device evidence does not close this gate. **Re-confirm on the
    Play-installed release candidate** — if it still quits, it needs an
    override in `godot/android/build/` (owner call: managed/regenerated dir). Handler is already
    in `game_shell.gd`, correct and inert until the engine side allows it.

## Gate B — Performance

- [ ] **[owner]** FPS ≥ 30 sustained through **purchase burst + 20 cps click storm** with a real thumb
  (idle is 40–48; `adb input` can't produce a trustworthy stress number)
- [ ] **[owner]** Clean performance-only capture — no ad transitions, no ADB traffic in frame
- [ ] **[code]** *(headroom, not a blocker)* `city_view.gd` draw-call reduction — 184 calls/frame,
  `shell_ms` is 0.4% of frame so the cost is renderer-side. Target 40s idle → 60.

## Gate C — Build & signing

- [x] **[code]** Godot toolchain green — engine `C:\Tools\Godot_4.6.3\`, `GODOT_BIN` set, `.\device_pass.ps1 check`
  - Rechecked 2026-09-12: Godot, templates, JDK 17, Android SDK, adb, build template,
    and synchronized export presets reported ready. The sandboxed adb device listing could not create
    its `.android` directory, so this is toolchain evidence only—not connected-device evidence.
- [x] **[code]** Export presets — Android (gradle, arm64, portrait, `com.ironassassin.criminalempire`, v1.0.0)
- [x] **[owner]** Create the **release upload keystore**, store it **outside the repo**, back it up
  (losing it = can never update the listing). Keep the password out of the repo too.
- [x] **[owner]** Signed baseline AAB built with the cleaned export preset: `.\device_pass.ps1 aab`
  - Artifact: `godot/build/criminal-empire.aab` · 34.2 MB · signature verified · release-content audit passed
  - SHA-256: `CC11B9CC08B74719FAA09F162135570E75FCFB9B2A7E0070C63CFC2847327EA1`
  - Read-only re-audit 2026-09-12: hash unchanged; `jarsigner` exited 0 with `jar verified`;
    forbidden release entries = 0. The verifier also reported a self-signed chain, no timestamp,
    POSIX attributes, and JAR/JarInputStream consistency warnings. This stale baseline is not signed off.
  - Existing debug APK read-only audit: tool-script entries = 0 and `POST_NOTIFICATIONS` entries = 0;
    SHA-256 `B5C20918BB85F4F50140B1904F1B99153FE5AE8D8DCDE248A8FAC403F7F6782A`.
    It is debug evidence only and cannot close any Play-installed gate.
- [ ] **[both]** After all Gate-0 fixes, cut the immutable release-candidate AAB; rerun signature,
  forbidden-content, full smoke, and SHA-256 checks and replace the baseline hash above
- [ ] **[owner]** Install that exact release-candidate AAB via Play internal testing and smoke it on device
- [ ] **[code]** Bump `version/code` only if Play has already consumed the current code (`1`), and keep
  both Android presets in sync (`device_pass.ps1` fails the pass on drift)

## Gate D — Play Console & compliance

- [ ] **[owner]** Finish Play developer verification — personal account created; identity review is
  pending, then complete Android-device and phone-number verification when Console unlocks them
- [x] **[owner]** Public Play Console developer name set to **Actually Creative**
- [ ] **[owner]** Play Console app created, `com.ironassassin.criminalempire` reserved
- [x] **[code]** **Privacy policy** drafted — [`docs/PRIVACY_POLICY.md`](docs/PRIVACY_POLICY.md)
- [x] **[owner]** Public publisher/contact fields filled — Actually Creative · `actuallycreativesupport@gmail.com`
- [ ] **[owner]** Host the privacy policy at a stable public URL and paste it into Play Console
- [x] **[code]** Data Safety + IARC + ads answers derived from the code — [`docs/PLAY_DATA_SAFETY.md`](docs/PLAY_DATA_SAFETY.md)
- [ ] **[owner]** Reconcile the final resolved advertising/billing SDKs, merged release manifest, and
  consent configuration against the providers' current Data Safety disclosures. Unresolved SDK
  answers—including device IDs, approximate location, ad interactions, and performance/crash
  diagnostics—are release blockers.
  - Stale baseline AAB metadata inventory (2026-09-12): Google Mobile Ads `24.9.0`, UMP `3.2.0`,
    Play Billing/Billing KTX `8.3.0`. These versions are evidence inputs, not compliance answers;
    inventory the final release candidate again before completing the form.
- [ ] **[owner]** Submit the Data Safety form from that reviewed sheet. The game's gameplay telemetry
  is local-only and is not off-device analytics; cloud save and a dedicated crash-reporting service
  do not ship. Do not categorically exclude crash logs/diagnostics until the third-party SDK review
  above is complete.
- [ ] **[owner]** Content rating (IARC) questionnaire — answers pre-written in the same sheet: **simulated gambling = yes**, real-money = no, crime theme = yes
- [x] **[code]** Target API level — `target_sdk=36` / `min_sdk=24`; re-confirm against Play's floor at submission (it moves each August)
- [ ] **[owner]** App access — declare **all functionality open** (no login, no code, no gated content)
- [ ] **[owner]** Ads declaration = yes; set up the AdMob ↔ Play app link
- [x] **[code]** `GAMBLING_ENABLED` / gambling copy vs rating answers — Fair Play section now carries an
  explicit virtual-currency-only + no-cash-out + live-RTP disclosure (`config_screen.gd`), so the
  in-app copy backs the IARC answer instead of contradicting it

## Gate E — Monetization live-verify (before any paid/monetized soft launch)

- [x] **[code]** Rewarded ads real (`admob_rewarded.gd`, warm-slot, test unit in debug / real in release)
- [x] **[code]** UMP / GDPR consent gate before `MobileAds.initialize()`
- [x] **[code]** Billing wired with acknowledgement (`play_billing.gd`)
- [x] **[code]** Ad + billing failures now surface to the player (`monetization.gd`, commit `43e115b`); interstitials removed to match Fair Play (`monetization_probe.gd` guards it)
- [ ] **[owner]** Create IAP products in Play Console matching `Monetization.PRODUCT_IDS` — **three**, not two:
  `remove_ads`, `starter_pack`, `income_x2` (a missing `remove_ads` would leave a Buy button that always fails)
- [ ] **[owner]** Licensed-tester run on a Play-installed build: rewarded ad shows/rewards/dismisses, purchase + **restore** both work, real product prices fetch
- [ ] **[owner]** Rewarded ad + UMP prompt verified on device (not mock backend)

## Gate F — Deferred post-v1 retention infrastructure

Notifications, cloud save, and remote analytics are intentionally deferred and are not v1 release
requirements. Their controls, claims, permissions, and backends must remain off for v1. Reopening any
of them is a separate post-v1 project with fresh privacy/Data Safety review and verification.

- [ ] **[post-v1, deferred]** Provision and review a remote analytics endpoint before setting
  `REMOTE_ENDPOINT` in `telemetry.gd` (currently `""` — local file only). Do not provision it for v1.
- [x] **[code]** Consent defaults for remote telemetry correct on first launch — v1 exposes only
  `OFF` / `DEVICE`, because a SHARED control with no endpoint behind it is exactly the dead promise
  Gate 0 forbids. The `telemetry_share` field still exists and defaults **false**, so a save that
  once had sharing on stays off; `set_share_consent()` refuses to enable it without a provisioned
  endpoint and purges the pending retry queue on revoke. Also fixed: the remote sink used to persist
  every event to `telemetry_queue.jsonl` even with no endpoint configured — unbounded disk growth on
  a build that can never send. Guarded by `godot/scripts/tools/consent_probe.gd` (14 assertions) and
  `v1_contract_probe.gd` (asserts no `SHARED` control exists) inside `device_pass.ps1 smoke`.
  - [ ] **[code]** *When* an endpoint is provisioned, re-expose SHARED and re-verify the revoke/delete
    flow before the Data Safety answer changes — the code path is live but has no UI in v1
- [x] **[both]** Local notifications — **deferred for v1.0 with nudges off, not stubbed**: `Notifications`
  autoload is `_enabled = false` (no backend, no permission request), the Settings switch is gone, and
  `permissions/post_notifications=false` on both Android presets so the manifest stops asking for a
  permission the app never uses. Re-open with the kyoz plugin when retention work resumes.
- [x] **[both]** *(deferred)* Play Games Services / `SnapshotClient` cloud save — `CloudSave` autoload is
  `_enabled = false` and the "Sign in (cloud backup)" button is removed, so v1 makes no backup promise
  it cannot keep. Local saves only; the addon stays on disk for a later pass.

## Gate G — Store listing assets (code-drawn only — see `ART_POLICY.md`)

- [x] **[code]** App title, short + full description drafted — [`docs/STORE_LISTING.md`](docs/STORE_LISTING.md) (paste-ready, within char limits)
- [ ] **[both]** Phone screenshots (min 2, 16:9 or 9:16) — capture from the real build
- [x] **[both]** Feature graphic 1024×500 — deterministic code-drawn / procedural, no AI art (`store/feature_graphic_1024x500.png`)
- [x] **[code]** App icon — code-drawn crown (`icon.svg` / `icon_192.png`)
- [ ] **[owner]** Set category and tags in Console — recommendation: Simulation;
  Idle/Tycoon/Simulation/Strategy/Incremental. Public contact email is ready: `actuallycreativesupport@gmail.com`.
- [x] **[code]** App icon at 512×512 for the listing — `store/icon_512.png`, rasterised from `icon.svg`
  by `godot/scripts/tools/export_store_icon.gd` (kept outside `godot/` so it is not swept into the AAB)
  - [ ] **[owner]** *Judgment call:* the icon is still the **gold** crown while the app theme moved to
    violet-hero. It reads fine on its own, but it is the first thing a Play browser sees and it no
    longer matches the first screenshot. Recolour the SVG or keep the contrast deliberately.

## Gate H — Crash reporting & stability

- [ ] **[owner]** Pick a crash service (Sentry vs Crashlytics) — note: Crashlytics pulls in Firebase
- [ ] **[code]** Integrate the SDK, symbolicate a test crash
- [x] **[code]** `verify_ship.ps1` + full smoke green against current source (2026-09-12): deck bounds
  (3 viewports), default layout probe (**18 surfaces × 2
  scales = 36 total cases**), consent probe (14/14), v1 contract probe, deck gesture probe, scroll gesture probe
  (6 screens), 30s soak, income parity (4/4 fixtures), branch validation 40/40, autobattler
  determinism. Godot emitted the known RID/texture/ObjectDB/resource cleanup messages at exit; the
  run passed but was not warning-free. Fixed earlier: `sim_branch_validation.py` read run counters out of a leftover
  `save.json`, so the suite passed or failed depending on whether a save existed — it now pins its
  own fixture and is order-independent.
  - Expanded matrix (**18 surfaces × 3 viewport sizes × 3 text scales = 162 total cases** at 1.6×
    boost, via `layout_invariants.gd --matrix`): **162/162 bounds cases passed on 2026-09-12**;
    existing captures are in `_audit/polish_*.png`. The run emitted the same exit-time cleanup diagnostics.
  - These bounds results do not prove visual consistency, contrast, touch feel, or full device usability.
    Debug-build automation or debug-device testing cannot close the Play-installed Android Back,
    billing, or release-signoff gates.
- [ ] **[code]** Re-run the full automated suite immediately before cutting the release-candidate AAB
- [ ] **[owner]** Play-installed release candidate completes a 30-minute mixed session plus
  background/resume without crash, freeze, save rollback, or Android system warning

---

## Open polish debt — must be closed or explicitly reclassified with device evidence

| # | Item | Source |
|---|------|--------|
| P1 | Content sheet drag handle feel — **code fixed** (10px latched threshold, 28px handle, PEEK/HALF/FULL label, tween-kill on grab, pixel-space snap, cancel/focus-loss recovery; `deck_gesture_probe.gd`). Gate 0 blocker until replayed on device | `content_deck.gd` |
| P1 | Touch scroll finnicky — **code fixed** (recursive `ScreenBase.pass_scroll_input` over every list + the 9 `game_screen` scrollers; `scroll_gesture_probe.gd` proves drag scrolling on 6 screens, with drag/no-activation/exactly-one-tap coverage on the 4 interaction surfaces and explicit scroll-only coverage for turf/stats). Gate 0 blocker until replayed on device | `screen_base.gd` |
| P1 | Free spin doesn't feel skill-based; Gate 0 blocker because it blurs the skill/RNG promise | `sim_gambling.py` design |
| ~~P1~~ | ~~Notifications, cloud backup, and shared analytics expose unavailable backends~~ — **closed 2026-09-11:** all three hidden, autoloads disabled, notification permission dropped from both presets | Settings/autoloads |
| P1 | Android Back previously force-quit from overlays; Gate 0 blocker until Play-build proof | `game_shell.gd` / Android activity |
| P2 | Default body text may need 125–150% for arm's-length reading; decide from real device, then fix default | theme/settings |
| P2 | Only ~4 businesses visible in portrait — accept only if row scan + city reaction still read in late game | `city_view.gd` |
| P2 | Gold crown icon versus violet product palette — keep only as deliberate contrast, not accidental drift | `icon.svg` / store assets |
| — | Rebalance flagged wanted 2026-07-18; watch mid-game (prestige 3–6) cadence via telemetry | memory |

---

## Definition of "ready to widen" (from `ROADMAP.md` launch gate)

- [x] P5 parity
- [ ] P8 perf on low-tier device — stress FPS unverified
- [ ] P9 retention loop tuned & instrumented — pacing unplayed, notifs/telemetry pending
- [ ] P10 monetization seams + consent — code yes, live no
- [ ] P11 signed / compliant build + crash reporting
- [ ] P12 soft-launch KPIs meet pre-set thresholds
