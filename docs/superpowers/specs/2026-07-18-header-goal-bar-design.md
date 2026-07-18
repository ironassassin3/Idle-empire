# Header / Goal-Bar Polish — Design

**Date:** 2026-07-18
**Status:** Approved for implementation (audit queue after gold-remnant)
**Scope:** Masthead income cue + Attention rail goal honesty. No save/balance changes.

## Problem (from stills)

The Z3 attention rail currently publishes soft coaching from
`GoalSystem.next_focus_hint` / `next_purchase_hint` under the label
`▸ GOAL — …`. That is dishonest: those strings are not Phase-55 goals, and real
goals (`GoalSystem.current_goals` + `progress_for`) never appear on the rail —
only in Stats. The stage_ledger mock already showed the intended form: short
label + mono `current/target` on the right.

Masthead IPS is a flat `+ $X / SEC` with no directional cue (premium study used
`▲`).

## Decisions

1. **Rail ambient priority for goals:** if `current_goals(state, 1)` has an entry,
   publish that as `kind: "goal"` with `text = label` and
   `value = formatted progress` (e.g. `$5K/$1M` or `3/50`). Soft hints demote to
   `kind: "hint"` / `"afford"` and lose the fake `GOAL —` prefix (and the
   redundant `▸` — the left accent bar is the attention mark).
2. **Progress underbar:** when a rail item carries `progress: 0..1`, draw a 2px
   `UiPrims.MiniBar` along the rail bottom (same language as afford underbars /
   prestige filament).
3. **Masthead IPS:** prefix `▲  ` when income > 0; keep green mono.
4. **Out of scope:** toast placement, narrative goal variants, retiring masthead
   chips (ADR-002), renaming `GOLD` tokens, design-mock retints.

## Verification

- Early-game still ($5K, few buildings): rail shows a real goal label + fraction,
  not `GOAL — Open Upgrades…`.
- Mid still ($5M): completed early goals gone; next incomplete goal or a soft
  `hint` without fake GOAL branding.
- `shell_smoke` PASS. Prestige filament / ADR-001 ticker untouched.
