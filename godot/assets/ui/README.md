# UI assets — Criminal Empire (Godot)

## Layout

```
assets/ui/
  material_maker/    # Source .mmat graphs (commit with exports)
  textures/        # Exported PNGs → Godot import (optional MM upgrade)
```

## Texture sources (priority order)

1. **Material Maker PNG** — drop exports into `textures/` (see [`MATERIAL_MAKER_SPEC.md`](MATERIAL_MAKER_SPEC.md)).
2. **Ink procedural bake** — `InkTextureBaker` + `scripts/tools/bake_ink_ui_textures.gd` (P15 city v2; committed PNGs until MM graphs replace them).
3. **Rustic procedural bake** — `RusticTextureBaker` when `GameConfig.UI_RUSTIC_THEME` is true.

| File | Use |
|------|-----|
| `textures/panel_9slice.png` | Panels, scroll wraps, header (city v2 + rustic) |
| `textures/card_frame.png` | Row cards, config/stats (city v2) |
| `textures/tab_bar.png` | Bottom nav strip (city v2) |
| `textures/modal_frame.png` | Overlays, menu ledger (city v2) |
| `textures/film_grain.png` | Atmosphere tile (`film_grain_overlay.gd`) |
| `textures/wax_seal.png` | Buyable row affordance (`draw_row_wax_seal`) |

Rebake ink placeholders:

```powershell
godot --path godot --headless -s res://scripts/tools/bake_ink_ui_textures.gd
```

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

- `StyleBoxTexture` via `GameTheme._mm_slice_style()` (city v2) and `apply_rustic_theme()` (rustic)
- Shared baked/MM textures cached on `GameTheme` — no per-frame alloc
- Progress bar **fills** stay code-drawn; only **tracks** use textures when MM track PNG exists

## Policy

See repo root [`ART_POLICY.md`](../../../ART_POLICY.md) §4.  
Plan: [`P13_REPORT.md`](../../../P13_REPORT.md) · Ship path: [`P14_REPORT.md`](../../../P14_REPORT.md).
