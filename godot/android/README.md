# Android build template (`res://android/build`)

Gradle custom build is **required** for the v1 AdMob and Play Billing integrations.
Notifications and cloud backup are disabled for v1. The optional notification instructions below
are historical integration notes, not v1 setup steps; do not install or enable that plugin.

## Generate the template (editor only)

1. Open `godot/project.godot` in Godot **4.6.3**.
2. **Project → Install Android Build Template…**
3. Confirm creation of `godot/android/build/` (Gradle project + `AndroidManifest.xml` stubs).

The template is **gitignored** (`godot/.gitignore` → `/android/build/`) because it is engine-version-specific and regenerated locally. Do not commit it.

## Native plugin drop-in (`android/plugins/`)

**kyoz Local Notification** ships a native Android plugin archive — extract the Godot 4.x release into:

```
godot/android/plugins/
```

Then enable **LocalNotification** under **Project → Export → Android → Plugins**.

## Customizations (optional)

| Path | Purpose |
|------|---------|
| `android/build/res/values/notification-color.xml` | Notification accent color (kyoz) |
| `android/build/res/mipmap-*/notification_icon.png` | Small notification icon |

See [`ANDROID_SETUP.md`](../../ANDROID_SETUP.md) for SDK/JDK paths and export steps.
