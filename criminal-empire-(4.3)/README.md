# Criminal Empire — Godot 4 Port

GDScript rebuild of the pygame-ce idle game. Open **`godot/`** as the project folder in [Godot 4.3+](https://godotengine.org/).

## Run

1. Install Godot 4.3 or newer.
2. **Project → Import** → select `godot/project.godot`.
3. Press **F5** (main scene: title menu → game).

Or from CLI (if `godot` is on PATH):

```bash
cd godot
godot --path . --quit-after 1   # headless sanity check
godot --path .
```

## What's ported (MVP)

| System | Status |
|--------|--------|
| 11 buildings + buy 1/10/max | ✅ |
| Income pipeline (racket/dealer, dock/HQ mults) | ✅ |
| Click + crit + dealer bonus | ✅ |
| Chop shop ambient proc | ✅ |
| Prestige + Influence ranks | ✅ |
| JSON save (`user://save.json`) | ✅ |
| Import pygame `../save.json` | ✅ (core fields) |

## Not yet ported

Heat, territory, rivals, crew, operations, managers UI, upgrades, perk tree, achievements, syndicate events, noir presentation pass, mobile export presets.

Port order recommendation: managers → upgrades → heat → territory → rivals → crew/ops → UI polish → Android/iOS export.

## Save compatibility

Godot writes `user://save.json` with the same core keys as Python (`balance`, `buildings[]`, `prestige_tokens`, etc.). Use **Import pygame save.json** on the title screen to copy a desktop save from the parent repo folder.

Python and Godot saves are **not** auto-synced — pick one runtime as source of truth per play session.

## Project layout

```
godot/
  project.godot
  scenes/          main_menu, game_screen, building_row
  scripts/
    autoload/      GameConfig, GameState, SaveManager, FormatUtil
    data/          Building, BuildingDefs
    systems/       Prestige
    ui/            screens + GameTheme
```

## Mobile (later)

1. **Project → Export** → add Android / iOS templates.
2. Set handheld orientation in `project.godot` (already portrait-friendly).
3. Touch: HUSTLE button + building buy buttons are already Control-based.

The pygame version remains at repo root (`python main.py`) until feature parity is reached.
