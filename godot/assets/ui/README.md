# UI assets — Criminal Empire (Godot)

## Layout

```
assets/ui/
  material_maker/    # Source .mmat graphs (commit with exports)
  textures/        # Exported PNGs → Godot import (optional MM upgrade)
```

## Texture sources (priority order)

1. **Material Maker PNG** — drop exports into `textures/` (see below).
2. **Procedural bake** — `RusticTextureBaker` in `scripts/ui/rustic_texture_baker.gd` runs once at startup via `RusticUi` autoload when `GameConfig.UI_RUSTIC_THEME` is true.

MM files override procedural keys when present on disk (`FileAccess.file_exists`):

| File | Procedural key |
|------|----------------|
| `textures/panel_9slice.png` | panel |
| `textures/card_frame.png` | card |
| `textures/tab_bar.png` | tab_bar_bg |
| `textures/modal_frame.png` | modal |

Other surfaces (tab idle/active, header strip, buttons) stay procedural until MM graphs land.

## Toggle

- **`GameConfig.UI_RUSTIC_THEME`** — rustic bake + ledger wraps; independent from city layout.
- **`GameConfig.UI_CITY_VIEW`** — when `false`, hides city viewport (P14 dev rollback); see `P15_REPORT.md`.
- **`GameConfig.UI_CITY_V2`** — city-first layout + ink theme path (default on).
- Global theme: `city_noir_theme.tres` when city v2; `rustic_noir_theme.tres` when rustic; `noir_theme.tres` project default.

## Export workflow (Material Maker)

1. Author graph in [Material Maker](https://github.com/RodZill4/material-maker) (MIT).
2. Use **2D Preview → Export** → PNG (RGBA, sRGB). Do **not** use 3D SpatialMaterial export for UI.
3. Tileable backgrounds: verify wrap in 2D preview before export.
4. 9-slice panels: design at 256×256 with clear corner margins (~24px).
5. Copy PNG to `textures/`; Godot import: **VRAM Compressed**, mipmaps off for UI chrome.
6. No code changes required — restart game; MM files auto-preferred over bake.

## Godot wiring

- `StyleBoxTexture` via `GameTheme` helpers + runtime patch in `GameTheme.apply_rustic_theme()`
- Shared baked/MM textures cached on `GameTheme` — no per-frame alloc
- Progress bar **fills** stay code-drawn; only **tracks** use textures when MM track PNG exists

## Policy

See repo root [`ART_POLICY.md`](../../../ART_POLICY.md) §4.  
Plan: [`P13_REPORT.md`](../../../P13_REPORT.md) · Ship path: [`P14_REPORT.md`](../../../P14_REPORT.md).
