# Android native plugins (§5) — install manifest

**Do not commit plugin binaries.** Copy release zips into the paths below, enable each plugin in **Project → Project Settings → Plugins**, then tick the plugin in **Project → Export → Android → Plugins**.

Godot version: **4.6.3** (`godot/project.godot`).

| Service | Plugin | Version | Install path | Runtime API (used by `AndroidBackend`) |
|---------|--------|---------|--------------|----------------------------------------|
| Ads | [Poing AdMob](https://github.com/Poing-Studios/godot-admob-plugin) | v4.3.1 | `godot/addons/` (from `poing-godot-admob-v4.3.1.zip` or AssetLib **poing.studios**) | Singleton `MobileAds` |
| IAP | [Godot Google Play Billing](https://github.com/godot-sdk-integrations/godot-google-play-billing) | 3.2.0 | `godot/addons/GodotGooglePlayBilling/` | Class `BillingClient` |
| Notifications | [kyoz/godot-local-notification](https://github.com/kyoz/godot-local-notification) | Godot 4.x release | Native: `godot/android/plugins/` · Autoload: copy `autoload/` from kyoz repo → register as `LocalNotification` | Autoload `LocalNotification` |
| Cloud save | [Godot Play Game Services](https://github.com/godot-sdk-integrations/godot-play-game-services) | v3.2.0 | `godot/addons/` (from `addons.zip`) | Autoload `GodotPlayGamesServices` + `SnapshotClient` node |

Full step-by-step (SDK, templates, Moto G): [`ANDROID_SETUP.md`](../../ANDROID_SETUP.md) at repo root.

## Quick install commands (PowerShell, from repo root)

```powershell
# Create staging folder
New-Item -ItemType Directory -Force -Path godot\_plugin_staging | Out-Null

# Billing
Invoke-WebRequest -Uri "https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.2.0/GodotGooglePlayBilling.zip" -OutFile godot\_plugin_staging\billing.zip
Expand-Archive godot\_plugin_staging\billing.zip -DestinationPath godot\addons -Force

# Play Games
Invoke-WebRequest -Uri "https://github.com/godot-sdk-integrations/godot-play-game-services/releases/download/v3.2.0/addons.zip" -OutFile godot\_plugin_staging\pgs.zip
Expand-Archive godot\_plugin_staging\pgs.zip -DestinationPath godot -Force

# AdMob (editor addon — also use AssetLib in editor for auto Android lib download)
Invoke-WebRequest -Uri "https://github.com/poingstudios/godot-admob-plugin/releases/download/v4.3.1/poing-godot-admob-v4.3.1.zip" -OutFile godot\_plugin_staging\admob.zip
Expand-Archive godot\_plugin_staging\admob.zip -DestinationPath godot\addons -Force

# Notifications (pick Godot 4.x asset from releases page)
# https://github.com/kyoz/godot-local-notification/releases
```

After extract: open Godot → enable all four plugins → **Install Android Build Template** → Export preset → enable each plugin checkbox.
