# Ship Architecture & Cursor Handoff — Criminal Empire

**Purpose:** the architecture and task plan to take the Godot build from *feature-complete prototype* to *shipped F2P mobile product*. Hand this to Cursor; it is the source of truth for the remaining systems.

**Scope:** build pipeline, monetization (ads + IAP), retention (notifications, cloud save), the analytics/telemetry pipeline, and store/compliance. **Out of scope:** gameplay and balance — those are done and verified (`sim_godot_soak.py` = PASS; economy audit complete).

**Business model:** F2P + rewarded ads & IAP. **Asset policy:** code-drawn / procedural only — no AI, no licensed art. All new UI (ad buttons, IAP store) is code-drawn. See `ART_POLICY.md`.

---

## 1. Current state (done — do not rebuild)

| Area | State | Where |
|---|---|---|
| Core game | Complete: 11 buildings, prestige + 4-branch tree, territory/rivals/crew/ops, dragons, 74 achievements | `godot/scripts/` |
| Balance | Verified sound; HQ text + dead-perk bugs fixed | committed |
| Android export config | `export_presets.cfg`, icon, dev-button stripped, version 1.0.0 | committed |
| **Telemetry** | Mock-first autoload: LocalFileSink + RemoteSink seam, consent-gated, signal-decoupled, headless-disabled | `scripts/autoload/telemetry.gd`, `scripts/telemetry/` |
| **Monetization** | Mock-first autoload: ads (rewarded + interstitial) + IAP; UI hooks in `game_screen.gd`; save fields migrated | `scripts/autoload/monetization.gd`, `scripts/monetization/` |
| **Notifications** | Mock-first autoload: pause/resume scheduling, `notifications_enabled` save flag | `scripts/autoload/notifications.gd`, `scripts/notifications/` |
| **Cloud save** | Mock-first autoload: SaveManager wrap, throttled push, merge-by-play-time | `scripts/autoload/cloud_save.gd`, `scripts/cloud_save/` |
| **Audio** | sfxr synth port; all SFX procedural | `scripts/audio/sfxr.gd`, `audio_manager.gd` |
| **Repo hygiene (Task 0)** | `/.godot/` + `analytics.jsonl` in `.gitignore`; `git rm --cached` staged | uncommitted |

**Still manual / device-gated (§5–6):** Android build template + native plugins (AdMob, Billing, Play Games, notification scheduler), `AndroidBackend` swap on device, telemetry remote endpoint provisioning, store assets + compliance.

---

## 2. Conventions Cursor MUST follow

These are load-bearing — violating them breaks the sims or the headless tools.

1. **New autoload → register in BOTH places:** `godot/project.godot` `[autoload]` **and** `godot/scripts/tools/soak_autoloads.gd` `AUTOLOADS`. The headless tools install autoloads manually; drift crashes the parity soak.
2. **Decouple via signals.** `GameState` must never hard-depend on a device service. Services *listen* to `GameState` signals (pattern: `telemetry.gd._connect_game_signals`). Existing signals: `prestiged`, `ranked_up`, `run_started`, `tutorial_advanced`, `stats_changed`, `notification`.
3. **Headless / editor disable.** Any autoload that touches a native plugin or audio device must early-return when `DisplayServer.get_name() == "headless"` (see `AudioManager`, `Telemetry`) and use a **mock backend** when the plugin is absent (editor). This keeps sims and in-editor F5 working.
4. **Save migration.** Every new persisted field needs a default in `GameState.apply_save_data` (and `load_game_preview` if title-screen-visible). Old saves must never crash.
5. **No new asset files.** UI is code-drawn; SFX via `sfxr.gd`.
6. **Income pipeline.** Never compute income more than once/frame — respect the `_mark_ips_dirty` / `income_per_second()` cache. New permanent multipliers (e.g. IAP ×2) hook into that pipeline, not ad-hoc.
7. **Verification gate.** After any change: `python sim_godot_soak.py --godot <godot>` must stay **P5 VERIFY PASS**, and `godot --headless --quit --path godot` must load clean.
8. **Commit discipline.** Focused commits; never sweep `.godot/` cache or generated logs into feature commits (see Task 0).

---

## 3. Task 0 — repo hygiene (do first, ~5 min) — **done (uncommitted)**

The working tree is perpetually dirty because Godot's regenerated cache and the sim log are tracked. Stop tracking them.

**Status (2026-06):** `godot/.gitignore` has `/.godot/`; root `.gitignore` has `analytics.jsonl`. `git rm --cached` for both is staged — commit as `chore: stop tracking Godot cache + sim log` before or with the feature commit.

```bash
# 1. Ignore Godot's regenerated cache (whole dir is rebuildable on open)
echo "/.godot/" >> godot/.gitignore
# 2. Ignore the sim output log at repo root
echo "analytics.jsonl" >> .gitignore
# 3. Untrack them (keep on disk)
git rm -r --cached godot/.godot         # ~110 files
git rm --cached analytics.jsonl 2>/dev/null || true
# 4. Verify: git status should now show only real source changes
```

Commit as `chore: stop tracking Godot cache + sim log`. **Do not** touch `CLAUDE.md`, `README.md`, `PROJECT_RULES.md`, `ART_POLICY.md`, `.cursor/` — those are intentional content.

> Note: `.cursor/rules/art-policy.mdc` already exists — leave it tracked.

---

## 4. System architecture

Every service below follows the **autoload + mock-backend + signal** pattern so it is testable in-editor before a device exists.

**Implementation status (2026-06):** §4.1–4.4 mock-first layers are **implemented** (autoloads registered in `project.godot` + `soak_autoloads.gd`; `sim_godot_soak.py` PASS). `AndroidBackend` stubs exist but require §5 plugins. UI integration (offline ad button, IAP rows in Config, income mult) is wired. **Deferred on device:** real ad/IAP serving, Play Games sign-in, local notification delivery, remote telemetry POST.

### 4.1 Monetization (Phase C) — the revenue spine — **mock-first done**

**Godot reality:** Godot 4 has **no built-in AdMob or Play Billing**. Both require Android native plugins, which require the **custom Gradle build** (Project → Install Android Build Template). This gates all of Phase C on §5.

**Plugins (verify latest maintained for Godot 4.6):**
- Ads: a Godot 4 AdMob plugin (rewarded + interstitial).
- IAP: a Godot 4 Google Play Billing plugin.

**New module:** `scripts/autoload/monetization.gd` (autoload `Monetization`) + a backend seam:

```
Monetization (autoload, decoupled)
├── _backend : MonetizationBackend
│     ├── MockBackend     (editor/headless — instant fake rewards, fake purchases)
│     └── AndroidBackend  (wraps the AdMob + Billing plugin singletons)
├── Ads:  load_rewarded(placement); show_rewarded(placement)
│         signals: ad_reward_granted(placement), ad_failed(placement)
│         interstitial: maybe_show_interstitial(trigger)   # capped, suppressed if remove_ads
└── IAP:  query_products(); purchase(product_id); restore()
          signals: purchase_completed(product_id), purchase_failed(product_id)
```

Backend chosen at runtime: `AndroidBackend` if the plugin singleton exists, else `MockBackend`.

**State (new save fields + migration defaults):**
- `remove_ads: bool`
- `entitlements: Array` (owned non-consumable product ids)
- `iap_income_mult: float` (permanent ×2 from IAP → multiplies in the income pipeline)

**Integration points (existing files):**
| Placement | File / hook | Reward |
|---|---|---|
| **2× offline earnings** | `game_screen.gd::_refresh_overlays` offline panel → add "Watch ad" button | double `GameState.offline_gain`, re-grant |
| Free golden coin | coin HUD (`_on_coin`) | grant a coin |
| Time-skip / boost | optional | temp buff via `BuffSystem` |
| Interstitial | on prestige (`do_prestige` → `prestiged` signal listener), capped, off if `remove_ads` |
| IAP remove-ads | hides all ad buttons, suppresses interstitials |
| IAP starter pack | grant cash/influence on `purchase_completed` |
| IAP permanent ×2 | sets `iap_income_mult`, flows through `income_per_second()` |

**Telemetry:** emit `ad_opportunity`, `ad_shown`, `ad_reward`, `iap_purchase` via existing `Telemetry.log_event`.

**Compliance:** ads + IAP require a privacy policy, the Play **Data Safety** form, and an ad-consent flow (UMP/GDPR). See §6.

### 4.2 Notifications (Phase D) — **mock-first done**

**Godot reality:** no built-in local notifications → Android notification-scheduler plugin.

**New module:** `scripts/autoload/notifications.gd` (autoload `Notifications`, mock in editor).
- On `NOTIFICATION_APPLICATION_PAUSED`: schedule local notifications —
  - "Your empire earned $X" at the offline-cap time (`GameConfig.OFFLINE_CAP_HOURS`).
  - "Daily reward ready" at next local midnight (ties to existing `daily_streak` logic).
- On resume: cancel pending.
- Opt-in prompt (Android 13+ runtime permission). Respect a `notifications_enabled` save flag (Config tab toggle).

### 4.3 Cloud save (Phase D) — **mock-first done**

**Plugin:** Google Play Games Services (Saved Games).

**New seam:** wrap `SaveManager` (don't replace it). Local-first; cloud as backup.
- On sign-in: compare local `user://save.json` vs cloud snapshot; resolve by higher `play_time`/`lifetime_earnings`.
- Hook `SaveManager.save_game` to push a snapshot (throttled); `load_game` to pull on fresh install.
- Must degrade gracefully when signed out (local only).

### 4.4 Telemetry remote sink (Phase D — extends existing) — **mock-first done**

`Telemetry` writes via sink interface in `flush()`:
```
TelemetrySink
├── LocalFileSink   (current behavior)
└── RemoteSink      (HTTP POST batches to GameAnalytics / Firebase / own endpoint)
```
- Batch + retry + **persist unsent** events (offline queue) so kills don't lose data.
- **Consent gating:** a `telemetry_consent` flag disables collection (Data Safety requirement). Default per region policy.
- **Off-device analysis:** small `analyze_telemetry.py` to read exported JSONL → time-to-prestige cadence report (closes the open 8× prestige-cadence balance question).

---

## 5. Build / export pipeline (editor + SDK — manual, gates §4.1) — **not started**

Cannot be scripted from headless; needs the Godot editor + Android SDK. **Next user step** after committing §4 mock layers.
1. Editor → **Manage Export Templates** → install Android templates.
2. Editor Settings → **Export → Android**: set Android SDK + JDK paths; debug keystore auto-generates.
3. Project → **Install Android Build Template** → creates `res://android/build/` (**required** for the ad/IAP/notification plugins).
4. Install plugins into `res://addons/` per each plugin's instructions; enable in Project Settings.
5. Project → **Export** → confirm the "Android" preset (already scaffolded) has no errors → **Export & Run** to device/emulator.
6. Release: create a release keystore (gitignored — `*.keystore` already in `godot/.gitignore`), export **AAB** for Play (`gradle_build/export_format=1`).

CI (optional, later): GitHub Actions with Godot headless export; needs templates + SDK + plugins in the runner image.

---

## 6. Store & compliance (Phase E — not code) — **not started**

- Privacy policy (hosted URL) — mandatory once ads/analytics ship.
- Play **Data Safety** form + content rating (IARC).
- Ad consent flow (UMP).
- Screenshots (from device), short/long description, keywords, feature graphic — **code-drawn / captured only**.
- Closed testing track → open beta → production.

---

## 7. Sequencing (dependencies)

```
Task 0  Repo hygiene ............................. ✅ done (uncommitted)
  │
  ▼
§4.1–4.4 Mock-first autoloads .................... ✅ done (uncommitted)
  │
  ▼
§5  Android build template + plugins ............. ⏳ NEXT — gates AndroidBackend swap
  │
  ├─▼ §4.1 Monetization AndroidBackend (AdMob + Billing plugins)
  ├─▼ §4.2 Notifications AndroidBackend
  ├─▼ §4.3 Cloud save AndroidBackend (Play Games)
  │
  ▼
§4.4 Telemetry remote endpoint ................... optional; set REMOTE_ENDPOINT when backend exists
  │
  ▼
§6  Store + compliance ........................... last; needs privacy policy once ads/analytics live
```

Build §4 services **mock-first** (editor-testable) so progress isn't blocked while §5's device steps are pending. The `AndroidBackend` swap is the only device-gated part.

---

## 8. Verification gates (run after every change)

```bash
# loads clean (no script/parse errors)
godot --headless --quit --path godot
# income parity + 60s soak still pass
python sim_godot_soak.py --godot "<godot.exe>"
```
Both must stay green. New autoloads must appear in `soak_autoloads.gd` or the soak will fail.
