# Gold-Remnant Theme Cleanup — Design

**Date:** 2026-07-18
**Status:** Approved for implementation (queued after identity medallions)
**Scope:** Replace warm amber/brass chrome literals left after the violet hero retheme
(`83cde69`) so product UI reads as one neon-violet system. ART_POLICY: tokens only.

## Context

`GameTheme.GOLD` / `GOLD_BRIGHT` are already violet (`#8a5cff` / `#b18cff`). City chrome
(`city_view.gd` `INK_GOLD*`) was retinted in that commit. Warm amber still lives in:

| Location | Remnant | Role |
|----------|---------|------|
| `hustle_band.gd` | `INK_GOLD*` amber floats | Hustle CTA chrome |
| `ink_texture_baker.gd` | `GOLD`/`GOLD_BRIGHT` `#c8a35a`/`#ecca7d` | Procedural 9-slice bake |
| Row/menu `.tscn` editor defaults | `Color(0.925, 0.792, 0.49)` etc. | Scene fallback labels |
| `building_neon("hq")` | same amber | **Keep** — business signature, not chrome |

## Decisions

1. **Product scripts + scenes only.** Design-workspace mocks (`godot/design/*`) stay as
   historical studies — not player-facing.
2. **Hustle band** mirrors `city_view`: local `INK_GOLD*` derived from `GameTheme.GOLD` /
   `GOLD_BRIGHT` (same float recipe city already uses).
3. **Ink baker** retints bake constants to violet; re-run bake so committed PNGs match.
4. **Scene theme overrides** that are warm amber → violet equivalents matching
   `GOLD` / `GOLD_BRIGHT` / muted violet. Runtime script overrides still win; this cleans
   editor defaults and first-frame flash.
5. **HQ neon stays amber** — identity color for that business, not theme chrome.

## Out of scope

Header/goal-bar polish, achievement toast placement, rooftop-sign identity, casino/
dragon/prestige surfaces, renaming `GOLD` identifiers, design-mock retints.

## Verification

- `shell_smoke.gd` PASS.
- Still captures (tabs 0 + menu) show no warm brass on hustle band, row titles, or
  baked panel edges — violet accent only.
- `building_neon("hq")` still returns the amber signature.
