# ev1b — Compact Heat / Raid Warning Banner

A 62px alert band that drops across the masthead the moment heat crosses the
60% raid threshold (`HeatSystem.RAID_THRESHOLD`), parks flush on the masthead's
bottom rule, and reads as danger with **zero gold**.

## Files (design-only — nothing under `godot/scenes/` or `godot/scripts/` was touched)

| Path | What |
|---|---|
| `D:\2d_game\godot\design\ev1b_heat_banner.gd` | The banner component (Control, no `class_name`): band, siren stripe, hazard glyph, copy block, alert CTA, live heat track, slide-in/out. |
| `D:\2d_game\godot\design\ev1b_heat.tscn` / `ev1b_heat.gd` | In-context mock at 64% heat — real city stage (`scenes/ui/city_view.tscn`) + the real shipped masthead (`scripts/ui/shell/hud_masthead.gd`) + a stub content sheet. |
| `D:\2d_game\godot\design\ev1b_heat_critical.tscn` | Same scene seeded to 91% heat (critical tier). |
| `D:\2d_game\godot\design\ev1b_heat_states.tscn` / `ev1b_heat_states.gd` | State sheet: entry frames, severity tiers, palette argument. |

## Renders

| Path | Shot |
|---|---|
| `godot\design\shots\ev1b_heat_720x1280.png` (copied to `outputs\`) | In context, WARN tier (64%) — the ship-target canvas. |
| `godot\design\shots\ev1b_heat_critical_720x1280.png` | In context, CRITICAL tier (91%). |
| `godot\design\shots\ev1b_heat_states_720x1280.png` | Entry frames + severity tiers + palette swatches. |
| `godot\design\shots\ev1b_heat_1080x1920.png` | 1080 sanity check (harness renders 1:1, i.e. unstretched; in-game `canvas_items` scales the 720 authoring base). |

Repro: `.\design_preview.ps1 -Scene godot\design\ev1b_heat.tscn -Sizes 720x1280,1080x1920`

## The design

**Anatomy (left to right):** 4px pulsing siren stripe · outline hazard triangle
(shape channel — danger is never colour-only, per the N6 rule the heat pill
already follows) · `RAID RISK · HEAT 64%` in Space Mono bold, the number in
alert red · a sub-line that states the actual stake, taken from the sim
constants: "Police raids seize 8% of your cash above 60%."
(`RAID_BALANCE_PENALTY = 0.08`) · a `COOL OFF` CTA at the 44px touch floor.
The band's bottom edge **is** the heat track: a 4px bar with a white notch at
the 60% raid line (`HeatThresholdTick`'s pattern, recoloured so the notch
survives on top of the fill — RED-on-RED is invisible there).

**Danger without gold.** Gold is the empire's *reward* colour; borrowing it for
a threat would blunt both. `GameTheme.RED` (#9a4a4a) is a *ledger* red — tuned
to sit quietly beside gold, ~2.4:1 on the near-black masthead, it reads "sad",
not "sirens". So the band proposes a four-value alert ramp in RED's hue family
but with siren chroma: `ALERT_EDGE #c43e34` (keyline, stripe, glyph, bar),
`ALERT_HOT #e8623f` (critical), `ALERT_INK #1b0d10` (fill), `ALERT_TEXT
#f2ded7` (message ink), plus `ALERT_PLATE #2c1418` for the CTA. Per DESIGN_KIT
rule 2 these are *marked* non-kit values arguing for a `GameTheme` amendment;
they ship by being promoted, not by porting the scene. The fill stays near-black
so text keeps its contrast, and the danger *mass* comes from a red bleed under
the top keyline — the light the siren throws — rather than from a bright fill.

**Motion.** 0.34s BACK/OUT drop from behind the masthead's top edge; the
overshoot is the "slam" that earns a glance. The stripe then breathes (1.3s
warn / 0.7s critical) — a breath, not a strobe. `play_out()` retracts in 0.22s
CUBIC/IN. All of it respects `GameTheme.ui_reduced_motion()` (particles-off
doubles as reduced motion): the band simply appears at rest.

**Two tiers, one band.** WARN (60–84%): outline glyph, `RAID RISK`, stake copy.
CRITICAL (85%+): glyph fills, `RAID IMMINENT`, copy escalates to "Seizures
escalate every second. Cool down NOW.", and the whole ramp shifts to
`ALERT_HOT` with a faster pulse. No new geometry, no layout change.

**It's an overlay, not a row.** The band is absolutely positioned over the
masthead/stage seam, so nothing below reflows when heat crosses 60 — the
buildings list never jumps under the player's thumb mid-tap.

## Decisions worth arguing with (port notes)

1. **The masthead heat pill retires while the band is up.** Rule 4 says every
   number has one home; the band carries `HEAT %` *and* a bar, so keeping the
   pill is duplicate chrome in a 128px band. In the mock the pill fades out
   (0.18s) as the band lands and would return on retract. At port time that's a
   `_heat_pill.visible` branch in `hud_masthead.refresh()` keyed off the same
   `>= 60` predicate — a one-line change to a file this task was not allowed to
   touch.
2. **Rest position = masthead bottom + 4px.** An earlier pass parked it at
   124px, which sliced the `+ $/SEC` income line. It now slides *across* the
   masthead (z-above) and stops just under it, covering nothing.
3. **CTA target.** `COOL OFF` should route to whatever actually lowers heat for
   that player (Crew → Heat assignment, or the Promoter/Collector manager).
   Wired to nothing here by design (design scenes carry no game logic).
4. **The band is 62px.** That is the ceiling: any taller and it competes with
   the hero balance instead of pointing at it.

## Harness gotchas hit (worth knowing for the next design scene)

- `GameState._ready()` calls `call_deferred("reset_new_game")`, so anything a
  design scene seeds in its own `_ready()` is wiped on the first idle frame.
  Seed from a `call_deferred` (queued after GameState's) — otherwise the shipped
  masthead renders `$0` while the stale-refresh chrome still shows your numbers.
- Never root an absolutely-positioned composite on a `PanelContainer`: it
  stretches *every* child to the full rect (the heat bar became a full-bleed red
  block). Root on `Control`, put the stylebox in a `Panel` child.
- A stepped translucent gradient must use exact, non-overlapping rects;
  `UiPrims.Scrim`'s `+1px` overlap double-blends and stripes the ramp.
