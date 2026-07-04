# Material Maker export spec — Criminal Empire (P15 ink)

Author graphs in [Material Maker](https://github.com/RodZill4/material-maker) (MIT). Export PNGs to `godot/assets/ui/textures/`. Godot picks them up automatically — no code changes.

Commit **source `.mmat` + exported PNG`** under `godot/assets/ui/material_maker/` and `textures/`.

---

## Palette (match `game_theme.gd` / landing)

| Token | Hex | Use |
|-------|-----|-----|
| Ink bg | `#08070a` | Panel fill base |
| Ink panel | `#0c0c14` | Elevated surface |
| Ink card | `#121018` | Row interior |
| Gold | `#c8a35a` | Border, brass trim |
| Gold bright | `#ecca7d` | Active/hover edge |
| Bone | `#e8e0d4` | Highlight flecks (subtle) |
| Smoke | `#15121a` | Grain midtone |
| Crimson | `#9d1c22` | Heat accent only (optional) |

**Avoid:** warm parchment `#1a1520` leather look — that's P14 rustic, not P15 city ink.

---

## Priority exports

### 1. `panel_9slice.png` (do first)

| Setting | Value |
|---------|-------|
| Canvas | **256 × 256** |
| Margins | **24 px** all sides (9-slice) |
| Alpha | Straight RGBA, sRGB |
| Look | Dark ink fill, subtle vertical noise, **1 px gold border** at ~35% opacity; corners slightly brighter (`#ecca7d` at 15%) |
| Graph hints | `Color` base `#0c0c14` → `Noise` (low amp) → `Edge Detect` or manual border mask → `Blend` gold rim |

### 2. `card_frame.png`

| Setting | Value |
|---------|-------|
| Canvas | **256 × 256** |
| Margins | **18 px** (list rows use tighter slice in code — panel margin is safer at 18) |
| Look | Thinner frame than panel; inner shadow 2–4 px; no heavy parchment texture |

### 3. `modal_frame.png`

| Setting | Value |
|---------|-------|
| Canvas | **320 × 320** |
| Margins | **24 px** |
| Look | Panel + slightly stronger border (55% gold); optional 4 px outer vignette on alpha |

### 4. `tab_bar.png`

| Setting | Value |
|---------|-------|
| Canvas | **512 × 64** |
| Margins | **8 px** top/bottom, **16 px** left/right |
| Look | Horizontal ink strip; 1 px gold bottom hairline |

### 5. `wax_seal.png` (optional — rustic/buy affordance)

| Setting | Value |
|---------|-------|
| Canvas | **96 × 96** |
| Look | Crimson wax `#9d1c22` + gold edge; used on buy rows when rustic path on |

### 6. `film_grain.png` (optional — overrides code grain)

| Setting | Value |
|---------|-------|
| Canvas | **256 × 256** tile |
| Look | Monochrome noise; **alpha 5–8%** average; must tile seamlessly |

---

## Export workflow

1. **2D Preview → Export → PNG** (not 3D SpatialMaterial).
2. Verify tile wrap in 2D preview for grain/tab strip.
3. Copy to `godot/assets/ui/textures/<filename>.png`.
4. Godot import (first open):
   - **Compress:** VRAM Compressed
   - **Mipmaps:** Off (UI chrome)
   - **Filter:** Linear
5. Restart game or reload — `RusticTextureBaker.load_or_bake()` prefers MM file when `FileAccess.file_exists`.

---

## Godot hooks (`GameTheme`)

| PNG | Constant |
|-----|----------|
| `panel_9slice.png` | `TEX_PANEL` |
| `card_frame.png` | `TEX_CARD` |
| `tab_bar.png` | `TEX_TAB_BAR` |
| `modal_frame.png` | `TEX_MODAL` |
| `wax_seal.png` | `TEX_WAX_SEAL` |

**Active theme:** P15 city v2 uses `StyleBoxFlat` ink today; MM PNGs apply when rustic is on **or** when you extend `apply_city_v2_theme()` to patch `StyleBoxTexture` (future P15.4+).

---

## QA checklist (per asset)

- [ ] Corners clean at 9-slice — no seam in Godot `NinePatchRect` / `StyleBoxTexture`
- [ ] No color banding at mobile gamma
- [ ] File size &lt; 200 KB per 256² PNG (VRAM budget)
- [ ] Source `.mmat` committed beside export
- [ ] Not AI-generated; hand-authored graph per `ART_POLICY.md`
