# Android setup — Criminal Empire (§5)

Step-by-step guide to export a debug APK to a physical device (e.g. Moto G) from Godot **4.6.3**.  
Prerequisite: mock-first autoloads are already in the repo (`Monetization`, `Notifications`, `CloudSave`).

**Toolchain check (2026-06-19 on this machine):**

| Component | Status |
|-----------|--------|
| Godot 4.6.3 on PATH | ❌ Not found |
| Export templates (`%APPDATA%\Godot\export_templates\4.6.3.stable\`) | ❌ Not found |
| Android SDK (`%LOCALAPPDATA%\Android\Sdk`) | ❌ Not found |
| JDK (`java` on PATH) | ❌ Not found |
| `adb` on PATH | ❌ Not found |

Until the rows above are green, CLI export will fail. Editor export has the same requirements.

---

## 1. Install Godot 4.6.3

1. Download [Godot 4.6.3](https://godotengine.org/download/archive/4.6.3-stable/) (Windows x86_64, **.NET not required**).
2. Extract or install; add the folder to PATH (optional):

```powershell
$godotDir = "C:\Tools\Godot_4.6.3"   # adjust
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$godotDir", "User")
```

3. Verify:

```powershell
godot --version
# Expected: 4.6.3.stable.official...
```

---

## 2. Install Android export templates

**In editor (recommended):**

1. Open `d:\2d_game\godot\project.godot`.
2. **Editor → Manage Export Templates… → Download and Install** (match 4.6.3).

**Or manual:**

1. Download [export templates](https://godotengine.org/download/archive/4.6.3-stable/) → `Godot_v4.6.3-stable_export_templates.tpz`.
2. Rename `.tpz` → `.zip`, extract.
3. Copy contents to:

```
%APPDATA%\Godot\export_templates\4.6.3.stable\
```

Verify folder contains `android_debug.apk`, `android_release.apk`, etc.

---

## 3. Install JDK 17

Godot 4.6 Gradle builds require **JDK 17** (not 21+ for all Gradle plugin combos).

**winget:**

```powershell
winget install Microsoft.OpenJDK.17
```

**Or Temurin:**

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```

Close and reopen the terminal, then:

```powershell
java -version
# openjdk version "17.x"
```

**Godot Editor Settings** (after install):

| Setting | Typical path |
|---------|----------------|
| **Editor → Editor Settings → Export → Android → Java SDK Path** | `C:\Program Files\Microsoft\jdk-17.x.x` or `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot` |

---

## 4. Install Android SDK

**Android Studio (recommended):**

1. `winget install Google.AndroidStudio`
2. Open Android Studio → **SDK Manager**:
   - **Android SDK Platform 34** (or latest stable)
   - **Android SDK Build-Tools** (latest)
   - **Android SDK Platform-Tools** (includes `adb`)
   - **NDK** — Godot template bundles NDK version; install if export complains.

Default SDK root:

```
%LOCALAPPDATA%\Android\Sdk
```

**Godot Editor Settings:**

| Setting | Value |
|---------|--------|
| **Export → Android → Android SDK Path** | `%LOCALAPPDATA%\Android\Sdk` |
| **Export → Android → Debug Keystore** | Leave default (auto-generated on first export) |

**Add platform-tools to PATH (for Moto G):**

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$sdk\platform-tools", "User")
adb version
```

---

## 5. Install Android build template (project)

Gradle build is already enabled in `godot/export_presets.cfg` (`gradle_build/use_gradle_build=true`).

1. In Godot: **Project → Install Android Build Template…**
2. Confirm `godot/android/build/` was created (gitignored — regenerated per machine).
3. See [`godot/android/README.md`](godot/android/README.md).

---

## 6. Install native plugins

Follow [`godot/addons/PLUGINS.md`](godot/addons/PLUGINS.md). Summary:

| Plugin | Source | Install |
|--------|--------|---------|
| **Poing AdMob** v4.3.1 | [Releases](https://github.com/Poing-Studios/godot-admob-plugin/releases) or AssetLib `poing.studios` | `poing-godot-admob-v4.3.1.zip` → `godot/addons/` |
| **Play Billing** 3.2.0 | [Releases](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases) | `GodotGooglePlayBilling.zip` → `godot/addons/` |
| **Play Games** v3.2.0 | [Releases](https://github.com/godot-sdk-integrations/godot-play-game-services/releases) | `addons.zip` → `godot/` (creates `addons/GodotPlayGameServices/`) |
| **Local Notification** | [kyoz releases](https://github.com/kyoz/godot-local-notification/releases) (Godot 4) | Native zip → `godot/android/plugins/`; copy `autoload/` script → register as `LocalNotification` autoload |

**After each install:**

1. **Project → Project Settings → Plugins** — enable all four.
2. **Project → Export → Android** — scroll to **Plugins** — enable each plugin checkbox.
3. Poing AdMob: set **AdMob App ID** in export options when you have a real ID (test ID OK for debug).

**Backend singleton names** (already wired in `scripts/*/android_backend.gd`):

| Service | Detection |
|---------|-----------|
| Ads | `Engine.get_singleton("MobileAds")` |
| IAP | `ClassDB.instantiate("BillingClient")` |
| Notifications | Autoload `/root/LocalNotification` |
| Cloud save | Autoload `/root/GodotPlayGamesServices` |

---

## 7. Godot editor steps (numbered checklist)

1. Open `d:\2d_game\godot\project.godot` in Godot 4.6.3.
2. **Editor → Manage Export Templates** — install 4.6.3 templates.
3. **Editor → Editor Settings → Export → Android** — set **Java SDK Path** and **Android SDK Path**.
4. **Project → Install Android Build Template**.
5. Install plugins per §6; enable in **Project Settings → Plugins**.
6. **Project → Export** — select preset **Android** — confirm no red errors.
7. Under **Plugins** in the export preset, enable AdMob, Billing, Play Games, LocalNotification.
8. Connect Moto G via USB; enable **Developer options → USB debugging**.
9. Run `adb devices` — device must show `device` (not `unauthorized`).
10. In Export dialog: **Export & Run** (debug) — installs `godot/build/criminal-empire.apk`.

**Release AAB (later):** In export preset set `gradle_build/export_format=1`, create release keystore (gitignored `*.keystore`), export AAB for Play Console.

---

## 8. CLI export (after toolchain is installed)

```powershell
cd d:\2d_game

# Smoke load (must pass before/after plugin work)
godot --headless --quit --path godot

# Debug APK export
godot --path godot --headless --export-debug Android

# Parity soak
python sim_godot_soak.py --godot "C:\Path\To\Godot_v4.6.3-stable_win64.exe"
```

Expected failure **today** (no SDK/JDK/Godot on PATH):

```
ERROR: Android SDK path not found
# or
'godot' is not recognized
```

---

## 9. Moto G device notes

- USB mode: **File transfer / MTP**; accept RSA fingerprint on phone when `adb` first connects.
- If `adb devices` shows `unauthorized`, revoke USB debugging authorizations on the phone and replug.
- Arm64 only: `export_presets.cfg` has `architectures/arm64-v8a=true` (Moto G compatible).
- First launch: grant **notification** permission when prompted (Android 13+); toggle in-game Config tab also gates scheduling.

---

## 10. Play Console / credentials (device testing with cloud + IAP)

Not required for a local debug APK, but needed before real ads/IAP/cloud save work:

- **AdMob:** app ID + rewarded/interstitial unit IDs in Poing export settings.
- **Play Billing:** app in Play Console → license testers; product IDs must match `Monetization.PRODUCT_IDS` (`remove_ads`, `starter_pack`, `income_x2`).
- **Play Games:** Game ID in plugin dock; OAuth client with package `com.ironassassin.criminalempire` + debug keystore SHA-1.

---

## 11. Verification gates

After any script change:

```powershell
godot --headless --quit --path godot
python sim_godot_soak.py --godot "<path-to-godot.exe>"
```

Both must stay **PASS**. Mock backends keep editor F5 working without plugins.

---

## Related files

| File | Purpose |
|------|---------|
| [`godot/export_presets.cfg`](godot/export_presets.cfg) | Gradle build, arm64, min SDK 23, permissions |
| [`godot/addons/PLUGINS.md`](godot/addons/PLUGINS.md) | Plugin versions + install URLs |
| [`godot/android/README.md`](godot/android/README.md) | Build template + `android/plugins/` |
| [`SHIP_ARCHITECTURE.md`](SHIP_ARCHITECTURE.md) §5 | Architecture source of truth |
