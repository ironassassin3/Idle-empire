# Play Console answer sheet — Data Safety, content rating, ads

**App:** Criminal Empire · `com.ironassassin.criminalempire` · v1.0.0
**Written:** 2026-09-10 · **Companion to** [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) and
[`../PUBLISH_CHECKLIST.md`](../PUBLISH_CHECKLIST.md) Gate D.

Every answer below is traced to the code that makes it true. If you change that code, change the
answer — a Data Safety form that stops matching the binary is grounds for removal, and Google
re-checks it on every update.

Verified by `godot/scripts/tools/consent_probe.gd` (runs inside `.\device_pass.ps1 smoke`).

---

## 1. Data Safety — what to declare

### Data collected and sent off-device

| Data type | Collected? | Answer to give |
|---|---|---|
| **Device or other IDs** (advertising ID) | Yes — by AdMob | Collected and shared per Google's SDK disclosure; verify purposes and required/optional against the resolved release SDK and consent configuration. |
| **Purchase history** | Yes — Google Play Billing | Collected · Not shared · Purpose: **App functionality** (unlocking and restoring purchases) · Required |
| **Our gameplay analytics / diagnostics** | **No off-device collection** | Do not declare our local gameplay log as collected. AdMob's separate SDK disclosures must still be reviewed below. |
| **Dedicated crash-reporting service** | **No** — no provider selected (Gate H) | Do not claim an integrated crash service. Review AdMob's SDK diagnostics separately. |
| **Approximate location / SDK interactions / performance diagnostics** | AdMob disclosure includes these | Reconcile the resolved release SDK's collection/sharing and purposes before submitting. |

### Data NOT collected — answer "No" to all of these

Name · Email · Phone · Address · Precise location · Contacts · Photos/videos ·
Audio · Files/docs · Calendar · Health/fitness · Financial info (card details never reach the app —
Google Play handles payment) · Messages · Web browsing history · Installed apps · SMS/call log.

**Repository permissions:** `INTERNET`, `ACCESS_NETWORK_STATE`, and `VIBRATE` are enabled in
`godot/export_presets.cfg`; notification permission is disabled in both Android presets.
SDKs can infer information such as approximate location from IP without location permission.
The final merged manifest and current AdMob disclosures must be checked before submitting this form.

**Submission blocker discovered during v1 polish:** the earlier draft marked AdMob IDs
as "Not shared" and omitted approximate location and SDK interactions/performance diagnostics.
Do not paste those historical answers unchanged. Google's current
[Mobile Ads disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
describes collection and sharing of IP-derived general location, ad interactions, identifiers,
and performance diagnostics. It covers the latest SDK; reconcile the resolved release SDK version,
consent configuration, purposes, and required/optional answers before submission. No dedicated
crash-reporting service or remote gameplay analytics service has been added.

Debug manifest inspected during this pass also includes billing, advertising ID / Ad Services,
wake-lock, foreground-service, and app-private receiver permissions. The earlier "only four
permissions" assertion was incorrect; the preset is not the merged manifest.

### Security & handling questions

| Question | Answer | Why |
|---|---|---|
| Is data encrypted in transit? | **Yes** | Ad and billing traffic is Google's own HTTPS. V1 has no remote gameplay analytics. |
| Can users request data deletion? | Verify SDK-specific answer before submission | Delete Save removes progress; OFF stops new gameplay logging. Clear Android app storage or uninstall to remove local diagnostics. Google's services have their own deletion controls. |
| Is the app committed to the Play Families policy? | **No** | Mature theme + simulated gambling. Not directed at children. |
| Has the app been independently validated against a security standard? | **No** | |

### Two traps to avoid

1. **Do not declare cloud save or Play Games Services.** `cloud_save.gd` falls back to
   `MockBackend` because no Play Games plugin is installed, so nothing is uploaded. Declaring it
   would over-claim. Re-answer if that plugin ever ships.
2. **V1 has no notification service.** `notifications.gd` never initializes a backend;
   there is no setting, scheduling, permission request, or collected token.

---

## 2. Telemetry — exactly what our own code records

Source: `godot/scripts/autoload/telemetry.gd`. Every record is `{t, s, ev, …props}`:

- `t` — unix timestamp
- `s` — a random session number regenerated **every launch**. Not a device ID, not stable, not
  linkable to a person.
- `ev` + props — gameplay only: `app_launch` (app version, `OS.get_name()`, debug flag), `run_start`,
  `prestige`, `rank_up`, `ftue_step`, `iap_purchase`, ad placements, and ~25 `ui_*` events (which tab
  was opened, which overlay was dismissed and how fast, buy-multiplier changes).

No name, email, contacts, location, IP, or advertising ID is ever read by our code.

### The two consent states (Settings → Analytics)

| State | Recorded? | Sent off-device? |
|---|---|---|
| `OFF` | No | No |
| `DEVICE` **(default on first launch)** | Yes, to app-private storage | **No** |

`telemetry_share` defaults to `false` in `game_state.gd` and is saved per-player. `_share_ok()`
requires a non-empty `REMOTE_ENDPOINT` **and** that opt-in, so a build with no endpoint provisioned
(which is v1.0 today, `REMOTE_ENDPOINT := ""`) transmits nothing at all. Revoking calls
`Telemetry.set_share_consent(false)`, which purges the pending retry queue so an opt-out cannot leak
on a later launch.

**V1 exposes only OFF/DEVICE.** Attempts to enable sharing are rejected without an endpoint;
old retry files are purged on startup. OFF clears buffered events and stops new recording.
No gameplay analytics leave the device, so do not declare this local log as off-device collection.

---

## 3. Content rating (IARC) — answer honestly

The questionnaire is adaptive; these are the answers that matter for this app.

| Topic | Answer | Backing |
|---|---|---|
| **Simulated gambling** | **Yes** | `GAMBLING_ENABLED = true` (`game_config.gd:56`) and `WAGER_ENABLED = true` (`gambling_system.gd`). The Luck Wheel is a timing minigame; the alley card game is a pure-RNG wager at a fixed 0.90 RTP. |
| **Real-money gambling / cash-out** | **No** | Stakes and payouts are in-game currency only. Nothing converts to money or leaves the game. This is a hard project constraint, not an implementation detail. |
| **Crime / illegal activity theme** | **Yes** | Core premise: building a criminal empire — dealers, rackets, territory warfare, rival factions. Stylised and non-graphic. |
| **Violence** | Mild / non-graphic | Territory and rival conflict resolve as numbers and text outcomes. No depicted violence, no blood, no characters harmed on screen. |
| **Language / sexual content / drug depiction** | None | Crime is abstracted into building names and income, never depicted or instructional. |
| **Users can interact / share content** | **No** | Single-player. No chat, no UGC, no social features, no leaderboards. |
| **Shares location** | **No** | |
| **Digital purchases** | **Yes** | Three consumable/one-time IAPs. |
| **Ads** | **Yes** | Rewarded ads. |

Expect roughly **Teen / PEGI 12+ or higher**, driven by the simulated gambling and crime theme.
Do not soften the gambling answer to chase a lower rating — a mis-rating is a takedown risk, and the
in-app copy (below) now contradicts any denial.

### In-app copy that backs these answers

Settings → **FAIR PLAY** (`config_screen.gd`) states, visible to any reviewer:

> The Luck Wheel and the alley game are played with in-game cash only. You cannot stake real money
> and nothing you win can be cashed out. The alley game is pure chance and pays back 90% of what is
> risked over time — the house keeps the rest.

Alongside the existing ads pledge:

> Ads are always your choice and state the reward up front. No interstitials, countdown offers,
> disguised buttons, or ad-gated offline progress.

The RTP figure is read from `GamblingSystem.WAGER_RTP`, so retuning the house edge updates the
disclosure automatically. If you change it, re-read this section — the number is a promise.

---

## 4. Ads declaration

- **Does your app contain ads?** → **Yes**
- Format: **rewarded only**. No interstitials — `monetization_probe.gd` fails the build if a
  `maybe_show_interstitial` entry point reappears.
- **AdMob ↔ Play link:** do this in AdMob → Apps → link to the Play listing. Required for accurate
  policy attribution.
- **Consent:** UMP runs *before* `MobileAds.initialize()` (`admob_rewarded.gd`), so no ad is ever
  requested pre-consent in a covered region. If the consent lookup fails (e.g. no network), the SDK
  falls back to non-personalised ads.
- **Families policy:** not opted in — mature content.

## 5. App access

All content is reachable from a fresh install with no login, no code, and no purchase. Answer:
**"All functionality is available without special access."** Do not attach reviewer credentials —
there are none to give.

## 6. Target API level

`gradle_build/target_sdk = 36`, `min_sdk = 24` (`export_presets.cfg`). API 36 is Android 16, at or
above Play's minimum for new apps. Confirm against Play's current requirement page at submission
time — the floor moves every August.

---

## When to revisit this document

| Trigger | What to re-answer |
|---|---|
| Crash SDK integrated (Gate H) | Add **Crash logs** to Data Safety; update the privacy policy |
| Remote analytics proposed after v1 | Revisit consent UI, retention/deletion, HTTPS, privacy policy, and Data Safety before enabling |
| Play Games / cloud save enabled | Declare the account identifier and uploaded save |
| Notification plugin installed | Still local-only — but re-check that no token is collected |
| `WAGER_RTP` or `GAMBLING_ENABLED` changed | Re-read the Fair Play copy and the rating answers |
| Any new IAP | Add to Play Console; `Monetization.PRODUCT_IDS` is the source of truth |
