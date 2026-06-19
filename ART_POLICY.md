# Art & Asset Policy — **MANDATORY**

> **Every contributor and AI agent must read this file before adding or changing any game art, UI look, icon, texture, audio, or store/marketing visual.**

This rule is **non-negotiable** for Criminal Empire unless the project owner explicitly overrides it in writing for a specific asset.

---

## Rule (one sentence)

**No generative-AI assets. Build visuals and SFX in code, or use hand-authored files the owner provides — never AI-generated output.**

---

## Forbidden — do not use, import, or commit

Any asset produced or substantially created by **generative AI**, including but not limited to:

| Category | Examples of forbidden sources |
|----------|-------------------------------|
| **Images** | Midjourney, DALL·E, Stable Diffusion, Firefly, Leonardo, Ideogram, ChatGPT image gen, Copilot image gen |
| **Sprites / icons / textures** | AI sprite sheets, AI “game asset” packs, upscaled AI art |
| **UI mockups shipped as art** | AI-generated backgrounds, panels, portraits, logos used in-game |
| **Audio** | Suno, Udio, ElevenLabs voice/music for shipped cues, AI SFX libraries |
| **Marketing** | AI store screenshots, AI feature graphics, AI app icon (unless owner replaces with code-drawn) |

**Also forbidden:** lightly editing AI output and calling it “hand-authored.” If the base image/audio came from a generator, it is still banned.

**Do not** add dependencies whose purpose is to call generative-AI APIs for art or audio.

---

## Allowed — how assets must be built

### 1. Code-drawn (preferred default)

Build everything in-engine with primitives and theme data:

| Runtime | Allowed techniques |
|---------|-------------------|
| **Godot (ship target)** | `Control` / `StyleBoxFlat` / `Theme`, `ColorRect`, `Line2D`, `Polygon2D`, `draw_*` on `_draw()`, typed labels, `icon.svg` edited as **hand-written SVG** (paths/shapes, not AI export) |
| **pygame (lab)** | `pygame.draw.*`, surfaces, palette from `src/theme.py`, typography |

Reference implementations: `godot/scripts/ui/game_theme.gd`, `godot/theme/noir_theme.tres`, `godot/icon.svg`, `godot/scripts/autoload/audio_manager.gd` (procedural SFX).

### 2. Hand-authored by the project owner

Files the **user explicitly provides** (scanned art, their own SVG/PNG, recorded audio) may be used **only when the user supplies them** — not when an agent generates them via AI on the user’s behalf.

### 3. Procedural / mathematical audio

Oscillator-based SFX and loops written in code (see `audio_manager.gd`, `src/sound.py`) are allowed and preferred over external clips.

### 4. Procedural texture authoring (owner-approved tools)

**Approved toolchain:** [Material Maker](https://github.com/RodZill4/material-maker) (MIT) — node-graph procedural textures built by hand, **not** generative AI.

Requirements when using Material Maker (or similar deterministic editors):

- Owner has approved the toolchain (see `P13_REPORT.md`).
- Author graphs manually; commit **source graph + exported PNG** under `godot/assets/ui/`.
- Document Material Maker version in the asset README or PR.
- Export via 2D Preview → PNG; wire in Godot as `StyleBoxTexture` / tiled backgrounds.
- **Do not** download community `.mmat` library assets without verifying license.
- **Do not** upscale or “enhance” exports with AI tools.

Progress fills, pulses, heat color, float text, and motion cues stay **code-drawn** even when panel surfaces use MM textures.

---

## Scope — everything in the product

This policy applies to **all** of the following:

- In-game UI, overlays, tabs, cards, heat bar, prestige tree
- Icons, splash, app icon, adaptive launcher icons
- “Illustrations,” portraits, faction art, dragon patron presentation
- Particles, toasts, milestone overlays
- SFX and music shipped with the build
- Store listing graphics and promotional art

**Balance/sim code** is unaffected. **Do not** use AI to invent gameplay numbers either unless the owner asks — but this document is specifically about **assets**.

---

## Agent workflow (required)

Before creating or modifying anything visual or audible:

1. **Read this file** (`ART_POLICY.md`).
2. **Default to code** — pygame/Godot primitives, theme tokens, procedural audio.
3. If the task needs a **bitmap surface** (panel, button, paper bg), use **Material Maker** per §4 or code — never AI.
4. If the task needs other external art, **stop** and ask the owner to supply hand-authored files.
5. In PR/commit descriptions, note asset source: code-drawn, MM procedural, or owner-provided.

---

## Enforcement

| Doc | Role |
|-----|------|
| **`ART_POLICY.md`** (this file) | Canonical policy |
| **`CLAUDE.md`** | Points here; agents load both |
| **`.cursor/rules/art-policy.mdc`** | Cursor always-on rule |
| **`ROADMAP.md`** | Launch phases assume this policy |

Violations should be reverted and replaced with code-drawn equivalents.

---

## Quick decision tree

```
Need a new visual or sound?
├─ Code-drawn (theme / _draw / StyleBoxFlat)?     → YES → build in code
├─ UI surface texture (panel, brass, paper)?       → YES → Material Maker graph + PNG (§4)
├─ Owner attached their own hand-authored file?    → YES → use it (not AI)
└─ Otherwise                                       → STOP → ask owner; never use AI gen
```
