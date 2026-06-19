# UI assets — Criminal Empire (Godot)

## Layout

```
assets/ui/
  material_maker/    # Source .mmat graphs (commit with exports)
  textures/        # Exported PNGs → Godot import
```

## Export workflow (Material Maker)

1. Author graph in [Material Maker](https://github.com/RodZill4/material-maker) (MIT).
2. Use **2D Preview → Export** → PNG (RGBA, sRGB). Do **not** use 3D SpatialMaterial export for UI.
3. Tileable backgrounds: verify wrap in 2D preview before export.
4. 9-slice panels: design at 256×256 with clear corner margins (~24px).
5. Copy PNG to `textures/`; Godot import: **VRAM Compressed**, mipmaps off for UI chrome.

## Godot wiring

- `StyleBoxTexture` in `theme/rustic_noir_theme.tres` (successor to `noir_theme.tres`)
- Shared theme subresources — do not duplicate textures per row
- Progress bar **fills** stay code-drawn; only **tracks** use textures

## Policy

See repo root [`ART_POLICY.md`](../../../ART_POLICY.md) §4.  
Plan: [`P13_REPORT.md`](../../../P13_REPORT.md).
