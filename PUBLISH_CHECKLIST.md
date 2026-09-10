# Publish checklist — Criminal Empire (Google Play, v1.0.0)

**Created:** 2026-09-10 · **Owner:** Ayden · **Target track:** Closed testing → soft launch
**Supersedes the "ranked path" in** [`SHIP_AUDIT.md`](SHIP_AUDIT.md) **as the live task list.**
**Interactive tracker (shared, checkable):** https://claude.ai/code/artifact/bb8fc9dc-5581-430f-934d-a2d41e706f48
Evidence files: [`DEVICE_PASS_RESULTS.md`](DEVICE_PASS_RESULTS.md) · [`SHIP_ARCHITECTURE.md`](SHIP_ARCHITECTURE.md) · [`ANDROID_SETUP.md`](ANDROID_SETUP.md)

**Verdict today:** Not publish-ready. Code side is close; the store/compliance track is untouched
and the on-device fixes from July were never re-played by a human.

Legend — **[code]** doable in this repo · **[owner]** needs Ayden's accounts / device / hands · **[both]**

---

## Gate A — On-device playtest (blocks everything)

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
  - Codex's 2026-09 pass reported this now passes; the 2026-07-30 pass said the Java `onBackPressed`
    path still killed the app. **Re-confirm on the current build** — if it still quits, needs an
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
- [x] **[code]** Export presets — Android (gradle, arm64, portrait, `com.ironassassin.criminalempire`, v1.0.0)
- [ ] **[owner]** Create the **release upload keystore**, store it **outside the repo**, back it up
  (losing it = can never update the listing). `export_presets.cfg` has `package/signed=true` but no
  release keystore path.
- [ ] **[owner]** Wire the keystore (env vars or preset) and produce a signed AAB: `.\device_pass.ps1 aab`
- [ ] **[owner]** Install that exact AAB via Play internal testing and smoke it on device
- [ ] **[code]** Bump `version/code` per upload (currently `1`)

## Gate D — Play Console & compliance

- [ ] **[owner]** Play Console app created, `com.ironassassin.criminalempire` reserved
- [ ] **[owner]** **Privacy policy** written and hosted at a stable URL (required by ads + analytics + Data Safety).
  No privacy doc exists in the repo yet.
- [ ] **[owner]** Data Safety form — declare telemetry, ad ID, purchase history; match what `Telemetry` / AdMob / Billing actually collect
- [ ] **[owner]** Content rating (IARC) questionnaire — declare **simulated gambling** (Luck Wheel + cash wager, virtual currency only) and the crime theme. Answer honestly.
- [ ] **[owner]** Target API level meets Play's current minimum for new apps
- [ ] **[owner]** App access — if any content is gated, give Play reviewers a path; otherwise declare all open
- [ ] **[owner]** Ads declaration = yes; set up the AdMob ↔ Play app link
- [ ] **[code]** Confirm `GAMBLING_ENABLED` / gambling copy match the rating answers and the Fair Play section in `config_screen.gd`

## Gate E — Monetization live-verify (before any paid/monetized soft launch)

- [x] **[code]** Rewarded ads real (`admob_rewarded.gd`, warm-slot, test unit in debug / real in release)
- [x] **[code]** UMP / GDPR consent gate before `MobileAds.initialize()`
- [x] **[code]** Billing wired with acknowledgement (`play_billing.gd`)
- [x] **[code]** Ad + billing failures now surface to the player (`monetization.gd`, commit `43e115b`); interstitials removed to match Fair Play (`monetization_probe.gd` guards it)
- [ ] **[owner]** Create IAP products in Play Console matching `Monetization.PRODUCT_IDS` (starter pack, 2× income)
- [ ] **[owner]** Licensed-tester run on a Play-installed build: rewarded ad shows/rewards/dismisses, purchase + **restore** both work, real product prices fetch
- [ ] **[owner]** Rewarded ad + UMP prompt verified on device (not mock backend)

## Gate F — Retention infrastructure

- [ ] **[owner]** Provision an analytics endpoint; set `REMOTE_ENDPOINT` in `telemetry.gd` (currently `""` — local file only)
- [ ] **[code]** Consent defaults for remote telemetry correct on first launch
- [ ] **[both]** Local notifications — `godot/android/plugins/` is empty (`.gitkeep` only); install the kyoz plugin + Android 13 `POST_NOTIFICATIONS` permission flow, or ship v1.0 with nudges disabled and note it
- [ ] **[both]** *(later)* Play Games Services + real `SnapshotClient` for cloud save — addon on disk, not enabled; stub today

## Gate G — Store listing assets (code-drawn only — see `ART_POLICY.md`)

- [ ] **[owner]** App title, short + full description
- [ ] **[both]** Phone screenshots (min 2, 16:9 or 9:16) — capture from the real build
- [ ] **[both]** Feature graphic 1024×500 — code-drawn / procedural, no AI art
- [x] **[code]** App icon — code-drawn crown (`icon.svg` / `icon_192.png`)
- [ ] **[owner]** Category, contact email, tags

## Gate H — Crash reporting & stability

- [ ] **[owner]** Pick a crash service (Sentry vs Crashlytics) — note: Crashlytics pulls in Firebase
- [ ] **[code]** Integrate the SDK, symbolicate a test crash
- [ ] **[code]** `verify_ship.ps1` + full smoke (`layout_invariants`, `deck_bounds_smoke`, soak, income parity) green on the release build

---

## Known issues carried into v1.0 (not release-blocking — triage before widening)

| # | Item | Source |
|---|------|--------|
| P1 | Content sheet drag handle feel — snap targets / threshold / state read | `content_deck.gd` |
| P1 | Touch scroll still finnicky — deceleration / drag threshold | — |
| P1 | Free spin doesn't feel skill-based (also a Gate-A check) | `sim_gambling.py` design |
| P2 | Base text ~150% larger for arm's-length reading | — |
| P2 | Only ~4 businesses visible in portrait — dilutes reactive-city payoff | `city_view.gd` |
| — | Rebalance flagged wanted 2026-07-18; watch mid-game (prestige 3–6) cadence via telemetry | memory |

---

## Definition of "ready to widen" (from `ROADMAP.md` launch gate)

- [x] P5 parity
- [ ] P8 perf on low-tier device — stress FPS unverified
- [ ] P9 retention loop tuned & instrumented — pacing unplayed, notifs/telemetry pending
- [ ] P10 monetization seams + consent — code yes, live no
- [ ] P11 signed / compliant build + crash reporting
- [ ] P12 soft-launch KPIs meet pre-set thresholds
