# P13 — Rustic Noir UI Overhaul (Material Maker + Theme)

**Status:** Planned — owner-approved direction (2026-06).  
**Goal:** Commercial idle-game polish while keeping organized-crime ledger identity.  
**Toolchain:** [Material Maker](https://github.com/RodZill4/material-maker) (MIT) → PNG → Godot `StyleBoxTexture`.  
**Policy:** [`ART_POLICY.md`](ART_POLICY.md) §4 — procedural graphs, not generative AI.

---

## Approach — hybrid

| Layer | Method |
|-------|--------|
| Surfaces (paper, leather, brass, wax frames) | Material Maker → 9-slice / tileable PNG |
| Motion, bars, pulses, affordance tint | Code (`game_screen.gd`, `_draw`, `modulate`) |
| Audio | Unchanged — procedural `audio_manager.gd` |

**Texture budget:** ~10–14 unique PNGs, VRAM-compressed, target **<1.5 MB** UI art.

---

## Retention patterns to implement (presentation only)

1. Persistent economy HUD — balance largest; rank demoted
2. Global buy-multiplier chip (×1 / ×10 / Max)
3. Affordability scan — seal texture when buyable, flat grey when not
4. Header “next upgrade” chip when affordable
5. Tab badge pills (Turf ops ready, affordable upgrades, hireable managers)
6. Locked subtabs with visible wax-stamp overlay
7. Ledger-styled offline/daily return modal
8. Textured progress tracks (heat, prestige); fills stay code
9. Milestone/event overlays — corner brackets + vignette (Phase 127 parity)
10. Collapse Dragon HUD to chip until patron active

---

## Asset list (Material Maker)

| Asset | Size | Godot use |
|-------|------|-----------|
| Ledger paper (tile) | 512² | Main/game background |
| Panel 9-slice | 256² | `PanelContainer` theme |
| Card frame | 256² | Row scenes |
| Button normal/hover/pressed | 128×48 | Theme buttons |
| Wax seal (affordable) | 96² | Buy button overlay |
| Tab bar strip | 512×64 | Bottom nav |
| Active tab pill | 128×48 | Active nav state |
| Modal frame | 320² | Overlays |
| Progress track | 256×32 | Heat bar bg |
| Film grain (tile) | 256² | Atmosphere overlay |

Sources: `godot/assets/ui/material_maker/` · Exports: `godot/assets/ui/textures/`

---

## Phase order

| Step | Scope | Est. |
|------|-------|------|
| **P13.0** | Pipeline + policy + one 9-slice spike | 1–2d |
| **P13.1** | `rustic_noir_theme.tres` + `GameTheme` texture refs | 2–3d |
| **P13.2** | Main menu (first impression) | 1d |
| **P13.3** | Header + bottom nav + badges | 2d |
| **P13.4** | Building/upgrade/manager rows | 3–4d |
| **P13.5** | Stats dashboard + left column | 2d |
| **P13.6** | Overlays (milestone, event, offline, prestige) | 2d |
| **P13.7** | Grain/vignette + device pass (P8 regression) | 1–2d |

**Timing:** Can run parallel to P6–P9 device pass if retention uplift is prioritized pre-soft-launch.

---

## Exit criteria

- [ ] All UI surfaces use theme or code — no `StyleBoxFlat`-only flat panels on ship screens
- [ ] Main menu + game header + bottom nav match Phase 127 atmosphere checklist
- [ ] Tab badges visible for actionable states
- [ ] `memory_soak.gd` 120s PASS; no VRAM climb on Moto G reference device
- [ ] `sim_godot_soak.py` PASS (presentation must not move economy)
- [ ] `noir_theme.tres` kept for one-click rollback

---

## References

- Research: [Material Maker UI research](eb506cc3-cca8-41a0-b2f4-2838e64dcd5e)
- Palette: `PHASE127_REPORT.md`, `godot/scripts/ui/game_theme.gd`
- Acceptance: pygame Phase 127 capture checklist (`phase127_capture.py`)
