# Device pass — 15-minute gate

One pass closes P7/P8/P15 ship smoke. **Desktop F5** or **Moto G APK** — same script, tick boxes in order.

```powershell
cd d:\2d_game
.\device_pass.ps1 check    # once — all green before device
.\device_pass.ps1 smoke    # automated — run before every pass
.\device_pass.ps1 run      # device only: export + install + launch
```

The pass installs the **debug APK** (`Android Debug` preset). `.\device_pass.ps1 aab` builds the Play Console bundle from the `Android` preset — adb cannot install that.

**Godot:** `E:\Downloads\Godot_v4.6.3-stable_win64.exe` (or `$env:GODOT_BIN`).  
**Full setup:** [`ANDROID_SETUP.md`](ANDROID_SETUP.md). **Deep reference:** [§Extended](#extended-reference) below.

---

## Before you start (2 min)

- [ ] `.\device_pass.ps1 smoke` → **Smoke PASS**
- [ ] **New Game** (not Continue) — old saves may have bad prestige progress
- [ ] Device only: USB debugging on, phone unlocked, `adb devices` shows one device
- [ ] Config → **Show FPS → ON** (device pass; optional on desktop)

**Fail fast:** If smoke fails, fix before rendering. If Continue shows prestige bar already half full on a “fresh” run, delete save and New Game.

---

## 0:00–0:15 — Silent fantasy (P15 taste)

Watch the game screen **without reading numbers**.

- [ ] Reads as **noir city under syndicate control**, not a spreadsheet
- [ ] Skyline strip visible at top; grows denser after a few building buys
- [ ] Gold/ink palette; **landing fonts** visible (Limelight menu title, Space Mono balance)

**Fail:** Blank city bar, ledger/parchment chrome, or default system font only.

---

## 0:15–3:00 — Core loop + prestige sanity (P15 + balance)

- [ ] Main menu: ink background `#0c0c14`, no ledger corner brackets
- [ ] **Hustle band** on city street taps; `+$` floats on glass (no duplicate HUSTLE button)
- [ ] Buy **3–5 buildings** — skyline tier changes
- [ ] **City keeps growing** (not frozen at 3): buy more of one business → its **tower grows taller**; buy new types → **more facades** appear (up to 5). Distant skyscrapers fill the sky even at the start
- [ ] **Row medallions show glyphs, not letters** — each business a distinct mark (dealer diamond, racket shield, betting die, pawn 3-balls, casino spade, dock anchor, arms crosshair, HQ crown…); disc tint matches its tower's colour
- [ ] Header: balance in **mono**, rank in **Cinzel**
- [ ] Tap prestige gate / tree entry → progress shows **route earnings near $0**, not ~$50M
- [ ] Bottom tabs switch: **Bldgs → Upgrs → Turf → Stats** (no crash, no clip)
- [ ] **Tutorial hint** floats **above** the building list — never covers a row or its BUY button (check at the phone's aspect / short screens)
- [ ] **Portrait lock** (device, regression): rotate the phone to landscape → app **stays portrait**. The orientation setting was exported as landscape until `f3726fa`; verify on hardware, not desktop

**Fail:** Prestige bar starts near gate max, tabs overlap notch/home bar, hustle dead, city stops changing after building 3, medallions show duplicate letters, tutorial pill sits on top of rows.

---

## 3:00–7:00 — Turf + one overlay (P7 nav)

- [ ] Turf → Territory; negotiate or view one district row
- [ ] Turf subtabs show **Crew/Ops** lock state (`n/5` · `n/2`) until unlocked
- [ ] Trigger **one** overlay (any):
  - Milestone (play until one fires), **or**
  - Prestige tree modal (tap gate), **or**
  - Offline: quit → edit `save.json` `save_timestamp` −4h → relaunch
- [ ] Overlay: city **still visible** behind dim scrim; ink panel (not parchment ledger)

**Fail:** Overlay hides city entirely, ledger brackets on modal, overlay stuck open.

---

## 7:00–9:00 — Audio + config (P6/P8)

- [ ] Config → raise **SFX**: hear click + at least one buy/milestone cue
- [ ] Raise **Music**: menu waltz on title; in-game loop, no loud seam pop
- [ ] Mute-all silences everything; sliders respond live
- [ ] **Device:** FPS overlay **green ≥30** while scrolling Stats + one overlay
- [ ] **Device:** One-handed tap on bottom tabs and hustle — no systematic misses

**Fail:** FPS red sustained during normal play, audio stuck, targets under thumb unreachable.

---

## 9:00–11:00 — Luck Wheel (gambling — timing feel)

The whole mechanic is **timing skill**, so it lives or dies on touch latency + sweep readability on real hardware. `GAMBLING_ENABLED = true`.

- [ ] Header **🎯 chip** visible with banked-spin **badge**; badge count matches Spins in overlay
- [ ] Daily/offline return overlay shows **"🎰 Spin now"** CTA when spins were granted; it opens the wheel
- [ ] Open wheel → **SPIN** sweeps the marker; button flips to **STOP**; STOP freezes exactly under the needle (WYSIWYG — no drift, no snap-back)
- [ ] Segment under needle at stop = the multiplier paid (watch one payout notification match)
- [ ] Jackpot band (10×) lands only on precise stops; **rankup SFX + gold "JACKPOT ×10"** fires
- [ ] Spends decrement **Spins**; at 0 the CTA disables and **"Watch ad +1 spin"** shows (hidden if remove_ads owned or at cap 5)
- [ ] Tap **Watch ad +1 spin** → mock/real rewarded flow banks **+1** (capped at 5); "SPIN AGAIN" goes live
- [ ] Close/reopen mid-round is free (no spin lost); panel centred, never clipped at notch/home bar

**Fail:** Marker drifts past where you tapped, badge count wrong, ad button grants past cap, spin consumed on close, panel clips.

---

## Golden coin (city reward — regression-checked this build)

The ★ coin is a diegetic city object; tap latency + z-order behave differently under real touch than a mouse (this was the fix — coin taps were being eaten as hustle clicks / the button's `pressed` never fired).

- [ ] ★ coin appears in the city stage (right side), pulses/glints
- [ ] **Tap the coin → powerup fires** (frenzy / lucky / click-storm notification) — **every** tap, not just sometimes
- [ ] Tapping the coin does **not** just do a hustle click (no stray `+$` float where the coin is; income clicking doesn't "stall" on the coin)
- [ ] After collecting, the coin **stays gone** (~30–60s) — does not instantly re-pop
- [ ] "Watch an ad" coin → **real rewarded ad** plays on device → grants a golden coin to collect

**Fail:** Tap does nothing / only hustles, coin instantly recycles after collect, coin blocks the income tap.

---

## Living city (reactive city — new this build)

- [ ] Buy a business → **that** business's tower lights up in the skyline (not a flash over the whole screen), and **its** row medallion flares at the same moment
- [ ] Buy a different type → a **different** tower lights. Two purchases must never look identical
- [ ] Watch the skyline idle → the biggest earner visibly works hardest (windows breathe strongest on the facade carrying the most income/sec)
- [ ] Raise heat to ≥60% → a **patrol cruiser** (red/blue roof bar) appears on the street; ≥85% → police **searchlights sweep** the sky
- [ ] Trigger a police raid → a **street-level red siren surge** (below the skyline), NOT a red wash over your balance
- [ ] Capture a district → **that block flashes gold** in the strip. A rival claiming an unclaimed district → **that block flashes red**
- [ ] BUY press → button visibly **sinks and springs back**; a gold ring ripples from the button
- [ ] Purchase → **1–3 coins fall from the balance INTO the bought row's medallion** (never into the ledger — a purchase is a spend)
- [ ] Config → Reduced motion ON → all of the above go still, nothing flickers
- [ ] FPS overlay stays **green ≥30** through a burst of purchases and a 20cps click storm (manager purchase orders + spark trails fire rapidly)

**Fail:** any reaction that covers the whole screen, two different purchases looking the same, FPS dip during a purchase burst, or motion continuing with reduced-motion ON.

---

## Neon Noir (whole-app cool retint — new this build)

- [ ] Whole app reads **cool Neon Noir**, not warm gilded — on a real OLED the near-black ground looks deep blue-black, **not muddy or crushed to pure black**
- [ ] Skyline shows **teal rooftop neon signs** (bloom + bright core) and faint **wet-street neon streaks** below them — legible at arm's length, not lost in the haze
- [ ] Business rows are **gradient cards** (lit top → dark base) with a **per-business accent bar**; two different businesses are distinguishable at a glance by colour (dealer amber, betting/dock blue, casino magenta, club violet…)
- [ ] Buyable row's accent frame is **brighter** than a locked row's; BUY button + wax seal stay legible on top of the gradient
- [ ] Pop **each overlay** (dragon patron, gambling wheel, an event) → panel chrome reads **cool** against the city, no **warm brown** panel fighting the ground; all body text legible
- [ ] Gold is **demoted, not gone** — BUY buttons and the balance still read gold; gold no longer dominates the whole screen

**Fail:** ground muddy/warm on device, neon signs invisible, rows indistinguishable by business, any overlay panel reading warm-brown against the cool city, or unreadable text on the retinted ground.

---

## 11:00–14:00 — Stress skim (P8 regression)

- [ ] Stats tab scrolls to bottom without freeze
- [ ] Buy-mult chip + advice chip visible in header row
- [ ] Heat bar visible; crimson shift when heat rises (buy buildings / turf action)
- [ ] Resize window narrow (desktop) **or** rotate/second aspect (device) — header + nav usable

**Fail:** Hard crash, permanent FPS drop after scroll, safe-area clip on header.

---

## 14:00–15:00 — Sign-off

| Result | Notes |
|--------|-------|
| **PASS** / **FAIL** | Device model + Godot version |
| Blocker(s) | One line each |
| Prestige gate @ load | Route $ at first game screen: ______ |
| Luck Wheel | STOP lands on-needle / drifts · best mult seen: ______ |
| FPS | Avg feel: ≥30 / &lt;30 |
| Fantasy 15s | City / spreadsheet / mixed |

---

## Pass criteria (all must be true)

1. Smoke PASS (automated)
2. New-game prestige **route** starts ~$0
3. City + hustle + ink theme read correctly in 15s test
4. No P0 crash, clip, or dead touch on critical path
5. Device: FPS ≥30 in normal play

---

## Extended reference

<details>
<summary>P15 detail (desktop + device)</summary>

- Film grain on when Particles ON (P14.8)
- Prestige tree: ink chips, perk labels readable without hover
- Config/Stats: ink row cards, not warm `BG_CARD` parchment
- Owner taste script: [`P15_REPORT.md`](P15_REPORT.md)

</details>

<details>
<summary>P7/P8 detail (renderer, layout, soak)</summary>

- Renderer: `gl_compatibility` — revert to Forward+ in `project.godot` only if visual break
- Particles OFF = reduced motion + grain off
- Gear opens Config; dragon chip when patron active
- Multi-hour soak:
  `"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path godot --headless -s res://scripts/tools/memory_soak.gd -- --seconds 7200`

</details>

<details>
<summary>P9 not built yet</summary>

- Local lapse push notifications — not implemented
- Daily/offline: full rival-line copy optional in 15-min pass; use timestamp cheat above

</details>

<details>
<summary>Report mapping</summary>

| Gate | Phase |
|------|-------|
| City, hustle, ink, fonts, prestige sanity | P15 |
| Portrait, tabs, touch, safe area | P7 |
| FPS, audio buses, performance skim | P8 |
| Offline overlay cheat | P9 |
| Store/signing/crash reporting | P11 |

</details>
