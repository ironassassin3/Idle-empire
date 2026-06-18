# P8 — Performance & Device Matrix

**Started:** 2026-06-17  
**Status:** Headless complete — Moto G 2026 FPS/thermal pass open
**Dependency:** P7 (final layout) — done.

## Audit (evidence)

- **Renderer:** was Forward+ (`config/features … "Forward Plus"`), no explicit `rendering_method`.
  Overkill for a 2D `canvas_items` UI; Compatibility (GLES) is the mobile-appropriate target.
- **Per-frame allocations:** none in the hot path. Row `instantiate()` calls are one-time
  populate; `Button.new()`/`Label.new()` are event/config-driven; click floats are capped at 24
  and freed on tween completion (and skipped entirely in headless).
- **Tick cadence:** sim `_process` is clean (all rates × delta; achievements throttled 0.5s,
  goals 1.0s, autosave on interval).
- **Hot spot found:** `GameState.stats_changed.emit()` fires **every frame**, and the UI connected
  `_refresh_all` directly to it → ~15 label rebuilds + tab badges + prestige-advice recomputed at
  60fps. pygame throttles its stats surface to ~5fps (CLAUDE.md perf rules); the port did not.

## Delivered

### Renderer switch → Compatibility (`project.godot`)
- `renderer/rendering_method="gl_compatibility"` (+ `.mobile`), `config/features` → "GL Compatibility".
- 2D-only project; Compatibility targets GLES3/mobile and low-tier GPUs.

### Perf fix — throttle header/left-panel refresh (`game_screen.gd`)
- `stats_changed` now just sets a dirty flag; `_process` calls `_refresh_all` at most every 0.1s
  (10fps) when dirty. Decouples UI refresh from the 60fps sim tick.
- 10fps is imperceptible for idle numbers; cuts ~6× the per-frame string/badge work → less mobile
  CPU/battery. Button feedback latency ≤0.1s (still snappy).

### Headless memory/leak soak (`scripts/tools/memory_soak.gd`)
- Loads `game_screen`, runs the live sim, simulates ~10 clicks/sec, samples
  `MEMORY_STATIC` / `OBJECT_COUNT` / `OBJECT_NODE_COUNT` every 10s; flags node growth >50 or
  mem growth >4 MB.

## Verify

```bash
# Memory soak (default 120s; --seconds for longer)
godot --path godot --headless -s res://scripts/tools/memory_soak.gd -- --seconds 120
# Full gate — boot/parity unaffected by renderer + throttle changes
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
```

**Memory soak (120s, ~10 clicks/s) — PASS, 2026-06-17:**
| t | mem | objects | nodes |
|---|---|---|---|
| 10s | 49,164 KB | 2284 | 321 |
| 120s | 49,648 KB | 2287 | **321** |

Nodes flat (no leak); objects +3 (one-time); memory +0.5 MB over 2 min (GC noise).
Full gate: 60s soak clean + income parity 4/4 (renderer/throttle didn't move the economy).

## P8 exit criteria

- [~] **No memory growth over a multi-hour soak** — headless side **done** (120s flat; harness
  supports `--seconds N` for hours). Multi-hour + on-device run still pending.
- [ ] **Holds target FPS on a low-tier reference device** — device-bound; headless has no renderer
  so FPS can't be measured here. **Owner: user** (define reference device + measure).
- [ ] **Compatibility renderer verified — no visual regression vs Forward+** — switch is in;
  **headless ignores the renderer**, so visual confirmation needs a windowed run. **Owner: user**
  (F5, compare noir theme/overlays to prior captures). Low risk for a 2D theme UI; easy to revert
  by flipping `rendering_method` back if anything looks off.

## Known limits / follow-ups

- FPS/battery/thermal are inherently device measurements — can't be done in this environment.
  Belongs to a real device pass (define low-tier reference: e.g., a 2–3 yr-old mid-range Android).
- Draw-call/overdraw audit is best done with the on-device profiler once Compatibility is confirmed.
- `memory_soak.gd` skips the click-float path (headless disables floats) — float cap is verified
  by code review (cap 24 + queue_free) rather than the soak.
