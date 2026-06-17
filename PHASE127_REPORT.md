# Phase 127 — Noir Theme Pass

**Date:** 2026-06-15  
**Scope:** Presentation only — palette, typography, atmosphere, dossier chrome, building cards, title screen. No gameplay, balance, or save changes. **No generative AI assets** — all code-drawn.

---

## 1. Objective

Shift from “polished idle dashboard” to **organized-crime ledger**: noir palette, case-file tabs, front-business cards, and title screen aligned with the landing page — without changing mechanics.

---

## 2. Success question (15-second test)

| Before (post-124) | After (Phase 127) |
|-------------------|-------------------|
| Header/city noir; right panel still generic navy idle | **Full frame** reads noir — ink, bone, gold, crimson |
| Flat tab underlines | **CASE FILE** tabs — display caps + gold rule |
| Building rows = tycoon cards | **Front-business dossiers** + wax-seal buy buttons |
| Menu: “IDLE EMPIRE” bright gold | **CRIMINAL EMPIRE** serif wordmark + corner frame |
| Flat grid background | **Grain + vignette + heat smoke wash** |

**Verdict:** Game chrome now matches the criminal syndicate fantasy; landing page and in-game identity are aligned.

---

## 3. Palette (`src/theme.py`)

Legacy neutral UI constants now route through noir (semantic colors unchanged):

| Legacy | Phase 127 source |
|--------|------------------|
| `BG_DARK` / `BG_PANEL` / `BG_CARD` | `NOIR_INK` / `NOIR_SMOKE` / `NOIR_CARD` |
| `ACCENT` / `TEXT_*` | `NOIR_GOLD_*` / `NOIR_BONE*` |
| `GREEN`, `PURPLE_*`, heat colors | Unchanged — system semantics preserved |

Added: `NOIR_INK_2`, `NOIR_CARD_HOVER`, `NOIR_CRIMSON_DIM`, `disp_lg` display font tier.

---

## 4. Atmosphere (`src/ui.py`)

| Layer | Implementation |
|-------|----------------|
| Background | Ink + smoke gradient + faint ledger lines (`make_bg_surface`) |
| Grain | Procedural sparse pixels (cached per resolution) |
| Vignette | Edge darkening bands (cached) |
| Heat wash | Crimson overlay scales with `state.heat` |
| Invalidation | `invalidate_atmosphere_cache()` on resize (`engine.py`) |

---

## 5. Dossier chrome

### Right panel
- `_draw_dossier_panel_bg()` — ink panel, gold hairline, corner brackets
- `_draw_dossier_tab()` — display uppercase labels, glass active tab, gold bottom rule
- Turf sub-tabs use same styling; locked tabs stay dim

### Left column (unchanged layout from 124)
- Stat cluster → glass mini-cards with display labels
- Prestige → glass + purple tint when ready; gold ledger bar when locked

---

## 6. Front businesses (`src/buildings.py`)

| Element | Treatment |
|---------|-------------|
| Card | `_draw_front_card()` — glass/dim veil, gold border |
| Name | `disp_sm` serif |
| Buy | `_draw_seal_button()` — gold wax seal when affordable |
| Toggle | Noir gold active state |
| Pete pick | Gold pulse border |

---

## 7. Title screen (`main.py`)

- **CRIMINAL EMPIRE** display title + “BUILD YOUR SYNDICATE”
- Hero corner frame (landing-page brackets)
- Glass menu buttons; gold pulse on primary
- Confirm/credits/settings overlays → noir panels + corners
- Window title: `config.TITLE = "Criminal Empire"`

---

## 8. Files changed

| File | Changes |
|------|---------|
| `src/theme.py` | Noir palette aliases, `disp_lg` |
| `src/ui.py` | Atmosphere, dossier helpers, panel/tabs, stat cluster, prestige glass |
| `src/buildings.py` | Front-business cards, seal buttons, noir toggle |
| `src/engine.py` | Atmosphere cache invalidation on resize |
| `main.py` | Noir title screen + overlays |
| `config.py` | Window title → Criminal Empire |

### Preserve checklist

- [x] No mechanic changes  
- [x] Save fields untouched  
- [x] Tab structure unchanged  
- [x] No generative AI assets  
- [x] Performance: grain/vignette cached; no per-frame full-screen alloc  

---

## 9. Screenshots

```powershell
python phase127_capture.py
```

→ `phase127_screenshots/`

| File | Scene |
|------|-------|
| `01_title_noir.png` | Title screen |
| `02_buildings_dossier.png` | Building cards + case-file tabs |
| `03_managers_roster.png` | Employee roster on noir panel |
| `04_late_empire_atmosphere.png` | City + heat wash + grain |

---

## 10. Next steps

| Phase | Focus |
|-------|-------|
| **125** | Turf sub-tab badges (ops ready, broker) |
| 126 | Stats tiering + achievement entry |
| 128 | Motion P0 (shield pulse, auto-buy toasts) |

---

## 11. Re-run captures

```powershell
python phase127_capture.py
```
