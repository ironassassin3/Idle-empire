# Store listing draft — Criminal Empire

**Written:** 2026-09-10 · **Updated:** 2026-09-11 · Covers [`../PUBLISH_CHECKLIST.md`](../PUBLISH_CHECKLIST.md) **Gate G**.
Copy below is ready to paste into Play Console. Everything is checked against the shipped content —
11 businesses, 13 ranks, 20 districts, 5 rival factions — so it promises nothing the build doesn't do.

Google rejects listings for keyword stuffing, fake urgency, and unsupported "#1 / best" claims, and
for screenshots that aren't real gameplay. This draft avoids all four.

---

## Title (30 char limit)

```
Criminal Empire: Idle Tycoon
```
27 characters. `Criminal Empire` alone is cleaner but likely collides on Play search; the subtitle
earns the "idle" query without stuffing. Alternate if you want the shorter name: `Criminal Empire`.

## Short description (80 char limit)

```
Build a crime empire from one corner dealer. Idle income, turf wars, prestige.
```
77 characters. Leads with the fantasy, names the genre, lists the three systems that differentiate it.

## Full description (4000 char limit)

```
Start with one corner dealer and a handful of cash. Finish running the city.

Criminal Empire is an idle tycoon game about compounding — every dollar you earn buys
something that earns more, until a street operation becomes a syndicate that runs itself.

BUILD THE OPERATION
Eleven businesses, each unlocking the next tier of the underworld: corner dealers,
protection rackets, chop shops, betting rings, pawn shops, loan sharks, underground
casinos, nightclubs, dock smuggling, arms brokers, and finally your own syndicate
headquarters. Upgrades multiply what you already own. Managers automate it so the money
keeps moving while you're gone.

TAKE THE CITY
Twenty districts, contested by five rival factions with their own territory, wealth, and
grudges — the Crimson Kings, Silver Hand, Iron Union, The Network, and the Blackwater Mob.
Attack, bribe, negotiate, or sabotage. Rivals fight each other while you're away, so the
map you come back to is never the one you left.

KEEP THE HEAT DOWN
Every illegal dollar draws attention. Let the heat meter climb and the police raid you.
Assign crew to protection, collection, smuggling, and heat control, and decide how much
risk your income is worth.

RETIRE AND COME BACK BIGGER
When you've built enough, walk away and prestige. You trade the empire for Influence and
a permanent multiplier, then climb the ladder again — thirteen ranks from Street Hustler
to Shadow Government. Each run, commit to one of four paths: Kingpin, Warlord, Cartel, or
Consigliere. They lock you out of each other for that cycle, so no two runs play the same.

IDLE MEANS IDLE
Your empire earns while the app is closed and reports what it made when you return. No
timers built to interrupt you, no energy bar, no stamina.

A FAIR DEAL
Ads are rewarded only — you choose to watch one, and the reward is stated before it plays.
No pop-up ads, no full-screen ads between actions, no ad-gated offline progress. Purchases
are optional and permanent. Play offline, with no account and no sign-in.

Contains simulated gambling played with in-game currency only. You cannot stake real money
and nothing can be cashed out.
```
~1,950 characters — comfortably inside the limit, no keyword stuffing, no unsupported claims.

## Category & tags

| Field | Value |
|---|---|
| Developer name | **Actually Creative** |
| App or game | **Game** |
| Category | **Simulation** *(Play's "Idle" tag lives under Simulation; Strategy is the alternative but under-sells the idle loop)* |
| Tags (up to 5) | Idle · Tycoon · Simulation · Strategy · Incremental |
| Contact email | **actuallycreativesupport@gmail.com** |
| Website | Optional — the privacy policy URL is fine |
| Privacy policy URL | *(owner — see [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md))* |

## Graphic assets

Everything below must be **code-drawn or captured from the real build** — see
[`../ART_POLICY.md`](../ART_POLICY.md). No generative AI, including for the feature graphic.

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG | Done — code-drawn crown (`store/icon_512.png`) |
| Phone screenshots | min 2, max 8 · 9:16 · ≥1080px on the short side | **Blocked on Gate A** — capture from the signed build, not the harness |
| Feature graphic | 1024×500 PNG, no transparency | Done — deterministic code-drawn skyline (`../store/feature_graphic_1024x500.png`) |

### Screenshot plan (capture in this order)

The first two are what most people ever see, so they carry the pitch:

1. **The city at full tilt** — main screen, high building count, income ticking, skyline lit.
2. **The ledger** — buildings sheet mid-game, several tiers owned, a BUY affordable.
3. **Turf map** — districts held, a rival faction contesting.
4. **Prestige ceremony** — the ascension overlay mid-gain.
5. **Rivals** — faction cards with their symbols and standings.

Capture on-device at 1080×1920 from the release build. Do not use `screenshot.gd` output for the
store — harness renders seed synthetic state and can show placeholder values.

> Play permits text overlays on screenshots. If you add any, keep it to 3–4 words and never fake UI
> that doesn't exist in the build.

### Feature graphic

1024×500, and it gets cropped hard on some surfaces — keep the title clear of the outer 10%.
The completed graphic follows the shipped look: violet-hero neon skyline over dark ground, title in
the game's own display face, and no character art. Its deterministic pygame source is
[`../tools/generate_feature_graphic.py`](../tools/generate_feature_graphic.py), so it can be rebuilt
without external or generated art.

---

## Pre-submission checks

- [ ] Title, short, and full description pasted; character counts re-verified in Console
- [ ] No "best / #1 / top" claims, no competitor names, no emoji spam in the title
- [ ] Screenshots are from the signed release build (Gate C), not the design harness
- [x] Feature graphic is code-drawn (`ART_POLICY.md`)
- [x] Contact email is monitored — **actuallycreativesupport@gmail.com**; Play shows it publicly
- [ ] Privacy policy URL is live and matches [`PLAY_DATA_SAFETY.md`](PLAY_DATA_SAFETY.md)
- [ ] Simulated-gambling line in the full description matches the IARC answers
