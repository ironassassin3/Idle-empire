---
name: godot-design
description: Claude Design for this Godot game — prompt-driven UI design with a live render loop. Builds Control scenes from the project's real theme tokens, fonts, and components, screenshots them with design_preview.ps1, then iterates on the pixels. Use when asked to design, mock up, prototype, or restyle a game screen, overlay, card, or HUD element.
---

# /godot-design — design loop for Criminal Empire's Godot UI

You are the design agent. The renderer is the real game engine, the component
library is the project's own theme/components, and your eyes are the PNGs the
harness produces. Never judge a design you haven't rendered.

## Inputs

`/godot-design <what to design>` — e.g. "a starter-pack offer card",
"redesign the prestige confirm overlay", "a compact heat warning banner".
`/godot-design explore <thing>` — off-kit exploration (see Explore mode).

## Workflow

### 1. Load the design system
Read `godot/design/DESIGN_KIT.md` (tokens, fonts, icons, components, rules).
If the request touches an existing screen, also read that scene/script
(e.g. `godot/scenes/game_screen.tscn`, `godot/scripts/ui/game_screen.gd`) so
the design matches its integration point.

### 2. Commit to a design intent — before any nodes
Two sentences, stated in your response before building:
- **Purpose & moment**: what decision or feeling does this serve, and when
  does the player see it (idle glance, purchase decision, ceremony, warning)?
- **The one memorable thing**: the single element someone would describe
  later. A screen where everything is polished equally is furniture.

The kit fixes the palette and fonts — it does not fix the composition. The
same tokens can produce a cramped settings list or a wax-sealed ledger page;
intent is what separates them. Pick where this design sits on each axis and
execute it deliberately:
- **Density**: generous negative space (ceremonies, offers) ↔ controlled
  density (stats, row lists). Never accidental middle.
- **Symmetry**: centered/formal (overlays, ranks) ↔ asymmetric/editorial
  (banners, cards — let the seal, medallion, or number break the grid).
- **Gold budget**: gold is loud because it's scarce. One focal use
  (`GOLD_BRIGHT` on the hero number/CTA), thin structural uses (`GoldRule`
  dividers, borders), muted everything else. If gold is everywhere it's
  nowhere.
- **Atmosphere**: flat noir panels ↔ `ink_*` parchment pass ↔ scrim/grain
  (`MastheadScrim`, `film_grain_overlay.gd`). Depth comes from layered
  panels (BG → BG_PANEL → BG_CARD) and the chunky-bevel button language,
  not from drop shadows invented per-scene.

### 3. Build
Write `godot/design/<name>.tscn` (+ `<name>.gd` attached to the root when
StyleBox/font API calls are needed — GameTheme/GameFonts/GameIcons are
class_names, available directly). Compose from kit components and tokens.
Full-screen designs: root Control, anchors full rect, ColorRect BG underneath.
Component designs: still render on a full-rect BG so the PNG shows context.

**Preview against the real screen, not a stub.** A component that only ever
renders over a hand-faked backdrop is judged against a fiction. Instance the
shipped scenes read-only around your design — e.g. `scenes/ui/city_view.tscn`
and the real masthead (`scripts/ui/shell/hud_masthead.gd`) — so the PNG shows
your work sitting in the screen it has to survive. Fake only the state
(cash, heat, owned counts), never the surroundings. This is what proves a
banner doesn't cover the balance or fight the skyline behind it.

**Motion**: the render is static, but the design should declare its motion.
If the moment warrants it (ceremony, reveal, buff activation), script the
entrance in the design `.gd` with Tweens — one orchestrated beat (staggered
fades/slides on the key elements) beats scattered micro-motion — and render
with `-Frames 45`+ so the settled state is captured. Note in the port notes
what animates and what stays still; a heat warning pulses, a stats grid
never should.

### 4. Render
```
powershell -File design_preview.ps1 -Scene godot\design\<name>.tscn
```
Options: `-Sizes 720x1280,1080x1920` (multi-res), `-Cash 50000` (affordance
states), `-Frames 45` (animated content needs longer settle), `-Out <path>`.
A Godot window flashes briefly per size — expected (viewport readback can't
run headless). Output: `godot/design/shots/<name>_<WxH>.png`.

Fast path — `ui_capture.ps1` (see DESIGN_KIT.md "ui_capture") when you need
more than one mock render: batch specs (tabs × sizes × seeds in one engine
launch), exact-pixel SubViewport capture (no OS window clamping at
1080×1920), `-DebugRects` (outlines every Control + writes `.rects.json` —
use FIRST when a layout looks wrong), input playback, and shipped-screen
capture via `-Shell -Tab N`.

### 5. Look, critique, iterate — minimum 2 rounds
Read the PNG. Check, in order:
1. Renders at all (no missing-node/script errors in harness output).
2. Kit compliance — token colors, Cinzel headings / Cormorant body / Space
   Mono numbers, gold accent discipline, ≥44px touch targets.
3. Layout at 720×1280 — no clipping, no overlap, breathing room (the repo's
   past bugs are all fixed-offset overlaps; use containers, not offsets).
   If anything looks collapsed or misplaced, re-render via `ui_capture.ps1
   -DebugRects` before guessing.
4. Hierarchy — one focal point; balance/CTA reads first; muted metadata.
5. Copy — every label and button honest (see Words). A render cannot catch a
   button that goes nowhere; only you can. Grep before you ship it.
6. Intent check — does the render deliver the step-2 commitment? Would a
   player describe the memorable thing, or is it a competent grid of
   correctly-tokened boxes? If the latter, the fix is composition (density,
   asymmetry, the gold budget), not more polish on parts.
Fix and re-render until two consecutive renders would pass review. Then do a
final multi-res render. Take the 1080×1920 final through `ui_capture.ps1`
(SubViewport, exact px) — `design_preview.ps1` renders through an OS window the
desktop can clamp to a shorter height, and a file named `..._1080x1920.png` that
is really 1080×1421 is a silently wrong deliverable. Verify the dimensions.

### 6. Deliver
Report with: final PNG path(s), scene/script paths, a 2–4 bullet design
rationale (the step-2 intent and which tokens/components carried it), and
**port notes** — exactly which nodes/styles move into which real scene, what
animates (tween choreography) vs. stays still, any new token the port should
add to `GameTheme`, and any **unimplemented dependency** the copy assumes (a
CTA whose action does not exist yet — say what would have to be built). Do not
port into game scenes unless asked; design scenes in `godot/design/` are the
deliverable.

## Words

Copy is design material, not filler — and it is the one thing the render loop
is blind to. A button that promises an action the game does not have renders
perfectly.

- **Every CTA must name an action that exists in code.** Before you label a
  button, grep for the thing it promises (a system method, an op, a manager).
  If it doesn't exist, either use a verb that does, or keep the label and
  flag it in the port notes as an **unimplemented dependency** — naming what
  would have to be built. Never let a dead verb ship silently. (A real case:
  a heat banner shipped a `LAY LOW` button; the game has no lay-low action,
  only the Political Bribery op and The Promoter as heat sinks.)
- **One name per action, all the way through.** The button that says COOL OFF
  produces a notification that says cooled off — label, toast, and tooltip use
  the same verb, or the player learns two words for one thing.
- **Say the stake, not the system.** "$12.3K can be seized" beats "heat 68%":
  name what the player controls and loses, in their vocabulary, not the
  simulation's. Numbers pulled from real constants (`HeatSystem`, `GameConfig`)
  beat invented ones — a mock that lies about the rules teaches the wrong feel.
- **Let each element do one job.** A label labels; a value shows the number.
  Nothing quietly does double duty.

## Variations
When the user asks to explore ("try a few directions"), build 2–3 sibling
scenes (`<name>_a.tscn`, `<name>_b.tscn`…) that differ on the step-2 axes
(density, symmetry, atmosphere) — not three spacings of the same layout.
Render all and present the shots side by side with one-line trade-offs.
Recommend one.

## Explore mode — `/godot-design explore <thing>`
The normal loop consumes the kit; explore mode is allowed to challenge it.
Use only when explicitly invoked with `explore` (or the user clearly asks to
go beyond the kit).

What may diverge, in `godot/design/` scenes only:
- **Literal colors** and new StyleBox constructions (mark them — a comment
  block at the top of the `.gd` listing every non-kit value).
- **New type treatments** — weights, sizes, letter-spacing outside the token
  set; proposing a new *licensed* font role follows the Limelight/Phosphor
  precedent (OFL/MIT file + license note, gated on owner approval —
  ART_POLICY bans generated assets, not licensed ones).
- **New component patterns** that don't exist in the kit.

What never diverges: ART_POLICY (code-built only), touch minimums, portrait
720×1280 target, and the game's **fiction** — the guardrail is not the
current token list, it's "criminal empire noir." Art deco, editorial/ledger,
industrial, luxury/refined all live inside that fiction; pastel, toy-like,
and retro-futuristic don't. When picking a direction, name the tone the way
frontend design does (one extreme, executed with precision), then justify it
against the fiction in one sentence.

The deliverable changes: instead of port notes, report **kit amendments** —
for each non-kit value that survived the render loop, the proposed token
name, value, role, and the rendered evidence it earns its place ("this needs
`GOLD_EMBER #d4703a` for warning heat; shot X shows why `RED` reads as loss,
not danger"). Values that didn't earn a token die with the design scene.
Explore scenes are never ported directly; they're arguments for changing
`GameTheme`, and the game keeps one voice.

## Failure notes
- Harness exits non-zero with a load error → the .tscn is malformed or an
  ext_resource path is wrong; fix paths (`res://design/...`) and re-run.
- Blank/black PNG → scene has no visible Controls at 720×1280 or everything
  is behind the clear color; check anchors and add the BG ColorRect.
- Components look dead/empty → they need GameState data; pass `-Cash`, or for
  richer states use `godot/scripts/tools/screenshot.gd`'s seeding flags as a
  reference for what to set in a small design script.
- Everything renders `$0` / empty despite seeding GameState → `GameState._ready()`
  *defers* `reset_new_game()` (game_state.gd), so it wipes state you set during
  your own `_ready()`. Seed from a `call_deferred` (or a frame later), not inline.
- A composite you positioned absolutely comes out stretched → its root is a
  `PanelContainer` (or any Container), which force-resizes every child to the
  full rect. Root free-positioned designs on a plain `Control`/`Panel`.
- A "1080x1920" PNG is actually shorter (e.g. 1080x1421) → `design_preview.ps1`
  renders through a real OS window, which the desktop clamps. Multi-res finals
  must go through `ui_capture.ps1` (SubViewport, exact px). Check the PNG's real
  dimensions before calling it a final — the filename is not evidence.
- Godot not found → `$env:GODOT_BIN = "<path to Godot_v4.6.3 exe>"`.
