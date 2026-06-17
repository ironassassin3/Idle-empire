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

## What's ported (hybrid P1–P4)

| System | Status |
|--------|--------|
| Core economy + 9 tabs (Cfg added P4) | ✅ |
| Territory / rivals / crew / ops | ✅ P2 |
| Stats + achievements + peak IPS | ✅ P3 |
| Prestige perk tree (4 branches + overlay) | ✅ P3 |
| Rival AI parity + manager ops (Smuggler/Broker) | ✅ P4 |
| Events / goals / tutorial / offline return | ✅ P4 |
| Dragon patron / golden coin / Pete·Sal·Promoter·Rudy·Rob | P5 next |

See **`P2_HANDOFF.md`** for the full handoff prompt and P5 plan.

Architecture map: **`../graphify-out/port/graph.html`** (pygame↔Godot layout, save schema, income pipeline).

## Save compatibility

Godot writes `user://save.json` with the same core keys as Python (`balance`, `buildings[]`, `prestige_tokens`, etc.). Use **Import pygame save.json** on the title screen to copy a desktop save from the parent repo folder.

Python and Godot saves are **not** auto-synced — pick one runtime as source of truth per play session.

## Project layout

```
godot/
  project.godot
  P2_HANDOFF.md      ← paste prompt block for next agent session
  scenes/            main_menu, game_screen, prestige_tree_overlay, *_row
  scripts/
    autoload/      GameConfig, GameState, SaveManager, FormatUtil
    data/          Building, Upgrade, Manager defs
    systems/       territory, rivals, crew, ops, heat, prestige, prestige_tree, achievements
    ui/            screens, row prefabs, GameTheme
  theme/noir_theme.tres
```

## Mobile (later)

1. **Project → Export** → add Android / iOS templates.
2. Set handheld orientation in `project.godot` (already portrait-friendly).
3. Touch: HUSTLE button + building buy buttons are already Control-based.

The pygame version remains at repo root (`python main.py`) until feature parity is reached.
