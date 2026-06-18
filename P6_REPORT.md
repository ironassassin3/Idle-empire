# P6 — Audio & Feel Report

**Started:** 2026-06-17  
**Status:** Code complete — manual audio playtest open (`DEVICE_TEST_CHECKLIST.md` §A)

## Delivered this session

### Audio (`audio_manager.gd` autoload)
- Procedural SFX port of `src/sound.py` — click, purchase, achievement, coin, crit, buff, manager, territory, rival, rankup, prestige, error
- 8-player pool (no per-frame allocation)
- Volume wiring: master × sfx / music, mute-all — synced from Config tab + save load
- **Headless guard:** `is_enabled() == false` when `--headless` (verified in `sim_godot_soak.py`)

### Sound hooks
| Event | Cue |
|-------|-----|
| Building buy | `purchase` |
| Upgrade / perk / op start / autobuy | `purchase` |
| Manager hire | `manager` (via notification) |
| Territory capture | `territory` |
| Rival elimination overlay | `rival` |
| First op collect | `manager` |
| Later op collect | `achievement` |
| Click / crit | `click` / `crit` |
| Golden coin | `coin` |
| Hustle / frenzy / storm | `buff` |
| Rank up | `rankup` |
| Prestige | `prestige` |
| Goals / achievements | `achievement` |
| Failures | `error` |

### Motion (Phase 128 lite)
- Collector shield + heat bar pulse (existing)
- Hustle / coin pulse (existing)
- **Click squash** on HUSTLE button
- **Goal + autobuy** toast styling (larger, longer, gold)
- **Prestige confirm dialog** gold pulse
- **Floating click-value popups** — `+$X` (green) / `CRIT +$X` (gold, larger) drift up
  and fade from the HUSTLE button; capped at 24 concurrent; headless-skipped
  (`_spawn_click_float` in `game_screen.gd`)

### Music
- **Ambient drone loop** on the Music bus — procedural A2/E3/A3 pad with slow swell,
  seamless loop (whole-cycle freqs, no boundary click); `_ambient()` in `audio_manager.gd`
- Auto-starts on load; Music slider + mute drive its volume live (was half-wired —
  `ambient` stream was referenced but never built or played)

## Verify

```bash
# Full gate — 60s soak (zero script errors) + income parity (P5 no-regression)
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
# → PASS: soak 60.00s zero SCRIPT ERROR; income parity 3/3 fixtures (2026-06-17)

# Manual — Config tab sliders change SFX + music loudness live; click to see floats
```

## P6 exit criteria

- [x] Subtle music loop on Music bus — ambient drone, slider-driven
- [x] Motion: floating click-value popups
- [ ] Manual playtest — every milestone tier audible in a real session (owner: user; run F5)
