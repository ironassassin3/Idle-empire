# Device / Windowed Test Checklist (P7–P9 close-out)

Everything below was implemented + verified headless, but needs a **rendered** run
(desktop windowed) or a **real phone** to confirm. Grouped by where it's checkable.
Tick items off; each notes which phase criterion it closes.

**Launch (desktop windowed):**
- Godot editor → open `d:\2d_game\godot\project.godot` → F5 (runs `main_menu.tscn`), or
- CLI: `"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path godot`

The window now opens **portrait (720×1280)**. Resize the window to test responsiveness.

**P8 reference device (physical):** Motorola Moto G (2026).

---

## A. Desktop windowed run (F5) — no phone needed
Catches most visual/nav/renderer items.

### Renderer — Compatibility vs Forward+ (closes P8)
- [ ] Game launches with no renderer errors in the Godot output log.
- [ ] Noir theme looks correct: panel backgrounds, borders, fonts, gold/green accents.
- [ ] Overlays render correctly: offline/daily return, syndicate event, milestone, rival
      elimination, prestige tree, dragon patron, prestige climax.
- [ ] Particle/motion cues OK: click floats (`+$X` / `CRIT +$X`), HUSTLE squash, shield/heat
      pulse, coin pulse, prestige-confirm gold pulse.
- _If anything looks wrong:_ revert in `godot/project.godot` →
  `rendering/renderer/rendering_method="forward_plus"` (and `.mobile`), `config/features` "Forward Plus".

### Portrait layout + nav (closes P7)
- [ ] Portrait is playable end-to-end — nothing clipped or off-screen at 720×1280.
- [ ] **Film grain** (P14.8): faint ledger texture over gameplay; off when Particles OFF in Config.
- [ ] Bottom bar: Buildings / Upgrades / Mgrs / Turf / Stats all switch correctly.
- [ ] Turf button shows the subtab bar (Territory / Rivals / Crew / Ops); Crew/Ops show
      `n/5` · `n/2` lock progress until unlocked, then enable.
- [ ] Header gear (⚙) opens Config; Menu still works.
- [ ] Left column (clicker / dragon HUD / heat / prestige) stacks above the tab content, readable.
- [ ] Resize the window narrow/short → content stays usable (scrolls, no overlap).
- [ ] Turf "★"/"•" roll-up badge appears (Broker active / ops ready).

### Audio (closes P6 + P14.8 M1)
- [ ] Config → raise Master + SFX: hear distinct cues (click, purchase, manager, territory,
      rival, rank-up, prestige, error). Each milestone tier sounds different.
- [ ] Raise Music: **menu** famiglia hook on main menu; **in-game** 8-bit waltz ambient (pad +
      bass + lead); loops with no click/pop at the seam.
- [ ] Heat ≥60%: tension grit/stab layer mixes under ambient (stub — no district motifs yet).
- [ ] Music and SFX on separate buses (Godot Audio tab shows Music + SFX under Master).
- [ ] Mute-all silences everything; sliders change loudness live.

### Daily / offline return (closes P9, desktop-checkable)
- [ ] Play briefly, quit, edit `save.json` `save_timestamp` back a few hours (or wait), relaunch →
      offline overlay shows cash earned + "While you were away" rival lines.
- [ ] Edit `last_login_date` to an earlier date → relaunch → "★ Daily reward — day N streak" line
      appears in the return overlay; dismiss clears it.

---

## B. Real device (Android first) — needs export
Requires export templates + a connected device or APK install.

### Performance / FPS (closes P8)
- [ ] **Reference device:** Motorola **Moto G (2026)** — record exact variant if multiple SKUs.
- [ ] Holds target FPS through a full session (early game → mid → many buildings + overlays).
- [ ] Battery/thermal sanity over ~15–20 min — no excessive drain/heat.
- [ ] On-device profiler: draw calls + overdraw within budget (note baselines for future regressions).

### Touch ergonomics + safe area (closes P7)
- [ ] All targets tappable one-handed: bottom tabs (56px), Turf subtabs (48px), crew ± steppers
      (48px), op/manager action buttons (48px), gear (44px). No fat-finger misses.
- [ ] Notch / punch-hole device: header isn't occluded; bottom bar clears the home-bar gesture
      area (confirms the `_apply_safe_area()` screen→viewport scaling).
- [ ] Test ≥2 aspect ratios (e.g., 19.5:9 tall and ~16:9 short) — no clipping; left column not
      crowded on the short one.
- [ ] No reliance on hover anywhere. Prestige-tree perk detail shows as **visible label text** under
      each perk (fixed in `prestige_tree_overlay.gd`) — confirm readable on small screens.

### Notifications (P9 — not yet built)
- [ ] Local lapse-nudge notifications are **not implemented** (platform APIs). When built: opt-in
      prompt, fires after inactivity, respects OS permission + a gentle cadence.

---

## C. Extended / automated
- [ ] Multi-hour memory soak (headless was 120s flat). Run longer:
      `"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path godot --headless -s res://scripts/tools/memory_soak.gd -- --seconds 7200`
      Pass = node count flat, static memory stable.
- [ ] On-device extended session (1–2h) — watch for slowdown/leak the headless run can't surface
      (renderer/texture memory).

---

## Closes these report criteria
| Item | Report |
|---|---|
| Compatibility renderer = no visual regression | P8 |
| Holds FPS on low-tier device; battery/thermal; draw-call audit | P8 |
| Multi-hour / on-device memory soak | P8 |
| Playable in portrait; safe-area; touch targets on device | P7 |
| Audio playtest (all tiers + music loop) | P6 |
| Daily/offline loop on device; push-notification consent | P9 |

## Not in scope here (tracked elsewhere)
- FTUE telemetry instrumentation — deferred until mobile analytics is scoped (P9 follow-up).
- `click_value += 0.01×IPS` late-game runaway — separate balance question (P9 follow-up).
- Store readiness / signing / crash reporting — **P11**.
