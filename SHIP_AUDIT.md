# Ship readiness audit — Criminal Empire (Godot / Android)

**Audit date:** 2026-07-30 (revised after the 2026-07-30 re-pass)  
**Device evidence:** [`DEVICE_PASS_RESULTS.md`](DEVICE_PASS_RESULTS.md) — baseline 2026-07-27, **re-pass 2026-07-30** (moto g, `ZA223JN722`)  
**Plan sources:** [`ROADMAP.md`](ROADMAP.md) P5–P12 · [`SHIP_ARCHITECTURE.md`](SHIP_ARCHITECTURE.md) · [`DEVICE_TEST_CHECKLIST.md`](DEVICE_TEST_CHECKLIST.md)

**Verdict:** **Not publish-ready** — but the blocking set has changed. The three
07-27 P0s have all moved: FPS measures **40–48 idle** (was 12–20), the prestige
CTA shipped, and the gate went 50M → 120M. What is still missing is *verification
by a player* (pacing and discoverability were fixed but never re-played) and the
entire store/compliance track, which remains untouched.

---

## Current posture

| Layer | Status |
|-------|--------|
| Core gameplay / P5 parity | Done (sims + soak) |
| Ship seams (ads/IAP/notifs/cloud/telemetry) | Mock-first code present; live backends partial |
| Android toolchain | **Green** (`.\device_pass.ps1 check`) |
| On-device playtest | **FAIL** — see P0s below |
| Store package / compliance (P11) | Not started |
| Soft launch (P12) | Blocked |

Live check (2026-07-30): Godot 4.6.3 · export templates · JDK 17 · SDK · adb · Gradle build template · APK+AAB presets · device `ZA223JN722`. Package `com.ironassassin.criminalempire` · v1.0.0 · arm64 · portrait.

> `ANDROID_SETUP.md`’s status table may be stale — trust `.\device_pass.ps1 check`.

---

## Device pass summary

**Device:** moto g (2026) · Dimensity 6300 / Mali-G57 · Android 16 · debug APK · `gl_compatibility`  
**Smoke:** PASS (deck bounds, soak, income parity)  
**Verdict:** FAIL

### What passed
Noir city fantasy · per-business facade reaction · golden coin (+ ad grant) · audio/sliders · list scroll unblocked · cash wager feels like pure RNG

### P0 — status after the 2026-07-30 re-pass

| # | 07-27 finding | Now |
|---|---|---|
| 1 | FPS 12–20, never ≥30 | **40–48 idle** measured; `shell_ms` 0.1 of a 23ms frame, so remaining cost is renderer-side. Stress case (burst / 20cps storm) **still unmeasured** — `adb input` can't produce a trustworthy number |
| 2 | Prestige undiscoverable | PRESTIGE chip + rail priority shipped (`4769cb3`); **not re-played by a human** |
| 3 | First prestige 19 min / 0 upgrades | gate 50M → **120M** (`b34b8cb`); **not re-played** |

Fixes 2 and 3 are code-complete but evidence-free: nobody has played a fresh run
since. That is the gap now, not the original defects.

### P1 / P2
Sheet drag feel · finnicky scroll · skyline overflow · tutorial no-replay · free-spin not skill-readable · body text small · few rows visible  

Full detail + re-test list: [`DEVICE_PASS_RESULTS.md`](DEVICE_PASS_RESULTS.md).

---

## Gap matrix (ship systems)

| # | Item | State | Blocks |
|---|------|--------|--------|
| 1 | Device pass P0s | **Open** | Soft launch confidence |
| 2 | Release keystore + signed AAB | Missing | Play upload |
| 3 | Privacy policy (hosted URL) | Missing | Ads/analytics / Data Safety |
| 4 | Play Console listing + IARC + Data Safety | Not started | Closed testing |
| 5 | AdMob + Billing on device | Code + plugins enabled; verify after FPS fix | Monetized build |
| 6 | IAP SKUs in Play Console | Not created | Revenue |
| 7 | Local notifications plugin | `android/plugins/` empty (`.gitkeep` only) | P9 nudges |
| 8 | Play Games cloud save | Addon on disk, **not** enabled; SnapshotClient stub | Cross-device save |
| 9 | Crash reporting | None | P11 |
| 10 | Telemetry remote (`REMOTE_ENDPOINT=""`) | Local file only | Soft-launch KPIs |
| 11 | Interstitials | Stub | Optional revenue |
| 12 | Store screenshots / feature graphic | No store package | Listing |
| 13 | iOS | Out of scope | Later |

**Gambling:** `GAMBLING_ENABLED = true` (virtual currency). AdMob tags MA / not child-directed. Still need honest Play questionnaire answers (simulated gambling + crime theme).

---

## Ranked path

### Now — a played re-pass, not more code
1. **Play a fresh run on device end to end.** P0-2 and P0-3 are fixed in code and
   unverified in practice; a 20-minute human run settles both, plus the tier-3
   items no harness reaches (audio, free-spin STOP feel, one-handed reach,
   golden coin, rotation). This is the single highest-value hour available.
2. **FPS under stress with a real thumb** — purchase burst + 20cps click storm.
   Idle is fine; the checklist's ≥30 bar applies during bursts, and that is the
   one FPS number still missing.
3. **Android Back force-quit** — needs a Java `onBackPressed()` override in the
   regenerated `godot/android/build/` tree. Owner call: touching that directory
   affects the export toolchain.
4. City draw-call reduction for headroom (40s → 60), guided by `shell_ms` being
   0.4% of frame: the win is in `city_view`, not in script.

### Then — closed testing (content-first OK)
5. Release keystore → `.\device_pass.ps1 aab`  
6. Play Console app + internal/closed track  
7. Privacy policy URL + Data Safety + content rating  
8. Soft-launch mode: content-only (ads/IAP off) **or** monetized (needs live ad/IAP proof)

### Before paid soft launch
9. Rewarded ad + UMP on device  
10. IAP SKUs + licensed tester purchase/restore  
11. Crash reporting  
12. Remote telemetry endpoint + consent defaults  

### Later
13. kyoz notifications + Android 13 permission  
14. Enable Play Games + real SnapshotClient  
15. Interstitials · store art · iOS · P12 KPI dashboards  

---

## Phase map (honest)

| Phase | Code | Device / store |
|-------|------|----------------|
| P5 Parity | ✅ | — |
| P6 Audio | ✅ | ✅ passed on device |
| P7 Mobile UX | ✅ | ~ (scroll/sheet P1) |
| P8 Perf | Headless ✅ | ❌ FPS FAIL |
| P9 Retention | Pacing + daily ✅ | Notifs ❌ · pacing P0 |
| P10 Monetization | Seams ✅ | Live verify pending |
| P11 Store/compliance | — | ❌ not started |
| P12 Soft launch | — | Blocked on P0 + P11 |
| P13–P15 UI | Largely ✅ | Taste OK; perf cost of city is the P0 |

---

## Definition of “ready to widen”

From `ROADMAP.md` launch gate — all required:

- [x] P5 parity  
- [ ] P8 perf on low-tier device (**FAIL today**)  
- [ ] P9 retention loop tuned & instrumented (pacing open; notifs/telemetry pending)  
- [ ] P10 monetization seams + consent (code yes; live no)  
- [ ] P11 signed/compliant build + crash reporting  
- [ ] P12 soft-launch KPIs meet pre-set thresholds  

---

## Related files

- [`DEVICE_PASS_RESULTS.md`](DEVICE_PASS_RESULTS.md) — measured fail evidence  
- [`SHIP_ARCHITECTURE.md`](SHIP_ARCHITECTURE.md) — ads/IAP/cloud/store sequencing  
- [`ANDROID_SETUP.md`](ANDROID_SETUP.md) — export / plugins  
- [`godot/addons/PLUGINS.md`](godot/addons/PLUGINS.md) — AdMob / Billing / Play Games / notifications  
- [`verify_ship.ps1`](verify_ship.ps1) — automated smoke gate (not a substitute for device pass)  
