# Privacy Policy — Criminal Empire

**Last updated:** 2026-09-11 · **Applies to:** Criminal Empire (`com.ironassassin.criminalempire`), Android

> **Draft pending final SDK disclosure review.** Then publish at a stable public URL and paste that URL into Play Console
> → Store presence →
> Privacy policy. Google re-checks this link, so it must stay reachable after launch.
> Keep it in sync with [`PLAY_DATA_SAFETY.md`](PLAY_DATA_SAFETY.md), which maps each item here to
> the exact Data Safety answer and the code that backs it.

---

## The short version

Criminal Empire is a single-player idle game. It has no accounts, no login, no chat, and no social
features. We do not ask for your name, email address, phone number, contacts, photos, files, or
location. AdMob may infer general location from your IP address, as described below.

Your save game lives on your own device. **Ads** and **purchases** involve external services,
as described below. No gameplay analytics leave your device in v1.

## What the app stores on your device

- **Your save game** — buildings owned, cash, Influence, prestige progress, settings. Written to the
  app's private storage. Uninstalling the app deletes it.
- **Gameplay diagnostics** — a local log of in-game events (which screen you opened, when you
  prestiged, whether an ad finished) plus the app version, the platform name, and a random session
  number that is regenerated every launch and is never linked to you or your device.

Neither leaves your device. There is no cloud backup or account to attach them to.

## On-device analytics

**Settings → Analytics** has two positions:

| Setting | What happens |
|---|---|
| `OFF` | Nothing is recorded at all. |
| `DEVICE` *(default)* | Diagnostics are written to the app's private storage and never sent anywhere. |

There is no sharing option or remote analytics endpoint in v1. OFF stops new gameplay recording
and discards buffered events. Previously recorded local diagnostics remain on the device until
the app's storage is cleared or the app is uninstalled.

## Ads

The game shows **rewarded ads only** — ads you choose to watch in exchange for an in-game reward,
which is always stated before you start. There are no pop-up or full-screen ads you did not ask for.

Ads are served by **Google AdMob**, which is a separate company acting as its own data controller.
To select and measure ads, AdMob may collect your device's advertising ID, coarse device and network
information, IP address (which can indicate general location), ad interactions, and SDK performance
diagnostics. This is separate from the game's on-device analytics setting. Google's SDK handles
that data under its own policies.

Before AdMob starts, the app shows Google's consent form where required (EEA, UK, and other covered
regions) and honours your answer, including a choice of non-personalised ads. You can reset or
change your advertising ID at any time in **Android Settings → Privacy → Ads**, and buying the
"Remove ads" item stops ads entirely.

- Google's privacy policy: https://policies.google.com/privacy
- How Google uses data from apps that use its services: https://policies.google.com/technologies/partner-sites

## Purchases

In-app purchases are processed by **Google Play Billing**. Payment happens inside Google Play — the
game never sees or stores your card details, billing address, or Google account. We receive only
confirmation of which item you bought, so the game can unlock it and restore it later.

Refunds and payment questions are handled by Google Play.

## Gambling-style features

The Luck Wheel and the alley card game are played with **in-game currency only**. You cannot stake
real money on them, nothing they pay out has real-world value, and nothing can be cashed out or
transferred. They are simulated gambling, and the app is rated accordingly.

## Notifications

V1 does not schedule Android notifications, request notification permission, or collect
notification tokens.

## Permissions the app requests

| Permission | Why |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | Loading rewarded ads and completing purchases |
| `VIBRATE` | Haptic feedback on taps |

The built app also includes advertising ID / Android Ad Services permissions, Google Play billing,
wake-lock and foreground-service permissions, and an app-private receiver permission from its
engine and SDK dependencies. It does not request camera, microphone, contacts, location, or
shared-storage access. No notification permission is included.

## Children

Criminal Empire is not directed at children. Its theme is organised crime and it contains simulated
gambling, so it is rated for a mature audience and should not be used by children.

## How long data is kept

Delete Save removes game progress. Local diagnostics remain until you clear the app's storage
in Android settings or uninstall it. Ad and purchase data are retained by Google under Google's
own policies. We receive no remote gameplay diagnostics or crash reports from v1.

## Your choices

- **Stop gameplay recording:** Settings → Analytics → `OFF`
- **Delete game progress:** Settings → Delete Save
- **Delete all local app data:** clear the app's storage in Android settings, or uninstall it
- **Advertising ID controls:** Android Settings → Privacy → Ads

## Changes

If this policy changes materially, the updated version will be posted at this URL with a new "last
updated" date before the change takes effect.

## Contact

Actually Creative
actuallycreativesupport@gmail.com
