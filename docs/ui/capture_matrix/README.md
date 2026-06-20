# P14 capture matrix

Screenshot baseline for touch-first UI validation. Capture after each P14 sub-phase on:

| Profile | Resolution | Aspect | Device reference |
|---------|------------|--------|------------------|
| Portrait ship | 720×1280 | 9:16 | Godot editor / emulator |
| Tall phone | 1080×2340 | 19.5:9 | Punch-hole safe-area stress |
| Short phone | 720×1280 | 16:9 | Header single-line check |

## Required surfaces (per phase)

- `main_menu` — continue / new / preview hierarchy
- `game_screen` — header economy HUD, buy-mult chip, tab badges
- Each bottom tab (Bldgs, Upgrs, Mgrs, Turf subtabs, Stats, Config)
- Overlay queue: offline → daily → milestone → event (sequential, not stacked)

## P14.8 checklist (atmosphere + device prep)

- [ ] **Film grain** — subtle tile on `game_screen`; absent when Config → Particles OFF (reduced motion) or headless
- [ ] **M1 music** — menu loop on `main_menu`; famiglia ambient in-game; Music/SFX buses in output log
- [ ] **Heat tension** — raise heat ≥60% (cheats or play) → tension grit layer audible under ambient
- [ ] **Notch/header** — tall profile: balance + IPS not occluded by punch-hole (`_apply_safe_area`)
- [ ] **Compatibility renderer** — no visual regression vs Forward+ on grain + overlays
- [ ] **memory_soak.gd** — 120s headless PASS after grain node lands

Store exports under this folder when device pass runs (P14.7/P14.8).
