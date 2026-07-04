# ADR-002 — Top-of-screen read-only policy

**Status:** Accepted (owner decision D2, 2026-07-03)
**Context:** Thumb-zone research (Smashing Magazine et al.): in one-handed
portrait grip, the top corners are the red zone — reaching them forces a grip
change. Our masthead hosted three interactive chips (gear, Luck Wheel, dragon).

**Options considered:**
1. Dock up-sheet — long-press the nav dock opens a bottom sheet with the three
   actions; masthead chips remain as tappable *mirrors* (owner-chosen).
2. Mirror chips into the content-sheet header (competes with the buy control).
3. Status quo (violates the policy ~3 taps/session).

**Decision:** Option 1. Primary path for gear/wheel/dragon is the dock
up-sheet (`shell/boss_sheet.gd`); masthead chips stay as mirrors so nothing is
lost for players who learned them. New interactive chrome above the audit line
is forbidden unless it is a mirror of a reachable control.

**Audit line (V5):** the spec's raw "55% of height" line would flag the
content sheet's own header (measured 43% at REST), which sits attached to the
reachable sheet in the acceptable stretch (yellow) zone. The enforced rule
follows the thumb-map literature's red boundary: **no non-exempt interactive
control's centroid above 40% of screen height**; exempt paths: `Masthead/*`
(mirrors) and `AttentionRail/*` (attention surface, not a required control).
All interactive targets ≥48px on their smaller axis (rule 9 floor; was 44 in
places).

**Consequences:** 44px chips/rail/segmented/cycle buttons bumped to 48px.
`ui_validators.ps1` gains V5 (parses the newest `--debug-rects` JSON). Future
top-chrome additions must be mirrors or fail CI.
