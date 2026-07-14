# ev1s — Compact Heat Warning Banner (heat >= 60%, raid threshold)

## Deliverables

| Item | Path |
|---|---|
| Design scene | `D:\2d_game\godot\design\ev1s_heat_banner.tscn` |
| Design script | `D:\2d_game\godot\design\ev1s_heat_banner.gd` |
| Render (portrait target) | `D:\2d_game\godot\design\shots\ev1s_heat_banner_720x1280.png` |
| Render (exact-px 1080x1920) | `D:\2d_game\godot\design\shots\ev1s_heat_banner_1080x1920.png` |
| Copies of both PNGs | this `outputs\` directory |

No file under `godot/scenes/` or `godot/scripts/` was touched (verified with `git status`).

Render commands:

```
.\design_preview.ps1 -Scene godot\design\ev1s_heat_banner.tscn -Frames 50 -Cash 154200
.\ui_capture.ps1 -Scene godot\design\ev1s_heat_banner.tscn -Size 1080x1920 -Frames 60 `
  -Cash 154200 -Out D:\2d_game\godot\design\shots\ev1s_heat_banner_1080x1920.png
```
(1080x1920 goes through `ui_capture.ps1` — `design_preview.ps1` gets clamped by the OS
window on a 1080p monitor.)

## Design intent (committed before building)

- **Purpose & moment.** Heat crosses 60% and the raid dice start rolling
  (`HeatSystem`: `RAID_THRESHOLD 60.0`, `RAID_BALANCE_PENALTY 0.08`). The band drops
  over the top of the masthead — where the player's eye already lives — and turns an
  abstract meter into a number with a currency symbol, plus one thing to do about it.
- **The one memorable thing.** The seizure figure: **`$12.3K` CAN BE SEIZED** — 8% of
  the live balance, in hot ember Space Mono, pinned against a code-drawn diagonal
  hazard cap while a siren wash sweeps the band. The gold masthead sits directly
  underneath it, so the band reads as an *intrusion into* the interface, not another
  chip inside it.
- Axes: **controlled density** (one 72px band, four elements), **asymmetric** (hazard
  cap + lamp anchor the left, CTA the right, nothing centered), **gold budget = zero**.

## What carried it

- **Danger without gold.** Everything is `GameTheme.RED`-derived: band fill
  `BG.lerp(RED, 0.22)` (oxblood), CTA `RED.darkened(0.45)` with a 4px bottom bevel
  (the ship button language, minus the gold), and one hot tint —
  `RED.lerp(#ff5933, 0.55)` ~= **`#d2523d`** — carrying the hazard stripes, the number,
  the lamp and the rule. Hue ~14 deg against gold's ~40 deg at much higher saturation:
  it never reads as brand.
- **The heat meter is the band's own baseline.** Instead of stacking a border *and* a
  bar, the band has **no bottom border** — the 5px `UiPrims.MiniBar` at 68% *is* the
  bottom edge, so the frame lights up as heat climbs and stays dark past the fill. The
  shipped `HeatThresholdTick` component draws the 60% raid tick on it.
- **Nothing is hidden.** The band overlays the top of the masthead and the masthead
  body slides down 72px under it, so the rank chip, gear, balance and income all stay
  reachable (an overlay that permanently covers the gear would be a UX regression, not
  a warning). An `UnderShade` gradient falls from the band's bottom edge so it still
  reads as *pressing onto* the masthead rather than stacked beside it.
- **Colorblind shape channel** kept per house rule (`hud_masthead.gd` precedent): the
  triangle glyph rides the kicker, so danger is never color-alone.

## Motion (declared; the render is the settled state)

One orchestrated beat, ~0.38s:

| Element | Motion |
|---|---|
| Band | slides from `y = -90` -> `0`, `TRANS_BACK / EASE_OUT`, 0.38s (the only overshoot) |
| Masthead body | slides `0` -> `+72`, `TRANS_CUBIC / EASE_OUT`, 0.34s (yields under the band) |
| Siren wash | continuous ~1.8s sweep, <=0.20 alpha |
| Siren lamp | 4.2 rad/s pulse |
| Hazard stripes | slow scroll, 9 px/s |
| Hero number, kicker, CTA, heat rule | **never animate** — the number must be readable, not throbbing |

All motion is gated on `GameTheme.ui_reduced_motion()`; with it on, the band is simply
present, still, and correct.

## Port notes

Target: `godot/scripts/ui/shell/hud_masthead.gd` (the live UI is the Shell V3 path —
`stage_layer.gd` / `game_shell.tscn`, **not** `game_screen.gd`).

1. Move `HazardCap`, `SirenWash`, `SirenLamp`, `UnderShade` out of the design script
   into `UiPrims` (`scripts/ui/shell/ui_prims.gd`) — they are code-drawn primitives and
   that is where the masthead's `Scrim` / `MiniBar` / `Filament` already live.
2. Add the band as a sibling of `HudMasthead`'s VBox, anchored `PRESET_TOP_WIDE`,
   `offset_bottom = 72`; on show, tween the band in and the existing masthead VBox down
   by 72; on hide (heat < 60), reverse. The masthead already recomputes
   `custom_minimum_size.y = HEIGHT * text_scale_mult()` in `refresh()` — add the band
   height to that term while it is visible.
3. Bind live: `GameState.heat` -> kicker + rule progress; `GameState.balance *
   HeatSystem.RAID_BALANCE_PENALTY` -> hero number (via `FormatUtil.format_money`).
   Visibility should hysteresis at 60/57 so a heat value hovering on the threshold
   doesn't strobe the band in and out.
4. **`LAY LOW` needs a destination.** There is no lay-low action in the codebase today —
   the real heat sinks are the *Political Bribery* operation (-20 heat) and *The
   Promoter* manager. Wire the CTA to the Turf > Ops route (or a small heat sheet)
   rather than inventing a mechanic; if no sink is unlocked yet, the CTA should be the
   thing that explains that.
5. The heat pill in `_build_heat_pill()` is redundant while the band is up — hide it
   (rule 4: every number has one home).

### New token the port should add to `GameTheme`

```gdscript
const RED_ALARM := Color("d2523d")   # RED.lerp(#ff5933, 0.55)
```

Reason: `GameTheme.RED` (`#9a4a4a`) is the **loss** token — desaturated, it reads as a
red number in a ledger, not as a siren; on the band it looked like a dim maroon strip.
`RED_ALARM` is the *active-threat* tint: the raid figure, hazard stripes, lamp and heat
rule all key off it, and it is unmistakably not gold. It is the only value in the design
that is not already a kit token or a derivation of one.

## Iteration log (renders reviewed, not guessed)

1. **R1** — blank PNG. Parse error: two helper funcs missing. Fixed.
2. **R2** — band renders, but `HazardCap` polygons spilled far past their 12px column
   and covered the hero number; the CTA (light `RED.lerp(alarm)` fill) out-shouted the
   number. Fixed: `clip_contents` on the cap; hero split into big ember number +
   small caption; CTA restyled to dark oxblood bevel.
3. **R3** — hero reads first, but the 2px bottom border and the heat bar doubled into a
   fat red edge, and `SirenWash` slices showed vertical seams. Fixed: dropped the bottom
   border so the heat rule IS the baseline; removed the wash's 1px slice overlap
   (overlapping alpha was double-blending).
4. **R4/R5** — clean at 720x1280 and exact-px 1080x1920. No clipping, no overlap, CTA
   46px (>= 44 touch floor), zero gold in the band.
