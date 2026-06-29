# Turf Autobattler — AI Handoff Document

**Purpose:** Single source of truth for an AI agent (or human) implementing a **2.5D criminal turf autobattler** in the lineage of Teamfight Tactics / Dota Auto Chess / Super Auto Pets.

**Status:** Architecture and design **only** — no game code exists yet. Do not confuse with the shipped Criminal Empire idle game in `godot/`.

**Last updated:** 2026-06-27

---

## Contents

- [Prompt block (paste into a new agent session)](#prompt-block-paste-into-a-new-agent-session)
- [1. Relationship to Criminal Empire (parent repo)](#1-relationship-to-criminal-empire-parent-repo)
- [2. Product vision](#2-product-vision)
- [3. Engine choice (locked)](#3-engine-choice-locked)
- [4. Layer architecture](#4-layer-architecture)
- [5. Project layout (target tree)](#5-project-layout-target-tree)
- [6. Run phase state machine](#6-run-phase-state-machine)
- [7. Data definitions (authoring schema)](#7-data-definitions-authoring-schema)
- [8. Runtime state objects (sim)](#8-runtime-state-objects-sim)
- [9. Player intent API](#9-player-intent-api)
- [10. Combat resolver](#10-combat-resolver)
- [11. EventLog catalog (combat + run)](#11-eventlog-catalog-combat--run)
- [12. Economy rules (v1 defaults)](#12-economy-rules-v1-defaults--tune-in-balance)
- [13. PvE AI (v1)](#13-pve-ai-v1)
- [14. Presentation architecture](#14-presentation-architecture)
- [15. 2.5D coordinate contract](#15-25d-coordinate-contract)
- [16. Metagame (cross-run)](#16-metagame-cross-run)
- [17. Save format](#17-save-format)
- [18. Audio (presentation only)](#18-audio-presentation-only)
- [19. Tools and CI](#19-tools-and-ci)
- [20. Performance budgets](#20-performance-budgets)
- [21. Open decisions (agent: ask user if blocked)](#21-open-decisions-agent-ask-user-if-blocked)
- [22. Implementation order (when user approves coding)](#22-implementation-order-when-user-approves-coding)
- [23. Agent conventions (mandatory)](#23-agent-conventions-mandatory)
- [24. Reference links (research basis)](#24-reference-links-research-basis)
- [25. Glossary](#25-glossary)
- [26. Document history](#26-document-history)

> **Reading order for a fresh agent:** Prompt block → §1–§4 (context + rules) → §21 (open decisions — resolve with user) → §22 (build order). Skim §7–§11 when you reach the sim implementation steps.

---

## Prompt block (paste into a new agent session)

```
You are implementing Turf Autobattler — a 2.5D auto-battler spin-off / sibling to Criminal Empire.

READ FIRST (in order):
1. TURF_AUTOBATTLER_HANDOFF.md  ← this file (source of truth)
2. ART_POLICY.md                 ← mandatory before any visual/audio work
3. CLAUDE.md                     ← repo conventions (Godot = ship target for CE; same rules apply here)

PRODUCT:
- Grid-based auto-battler: shop → place crew on turf → auto-resolve combat → repeat
- 2.5D presentation (isometric 2D OR 3D board + 2D billboards) — NOT full 3D character rigs
- PvE ladder v1; async ghost PvP v2; live 8-player deferred
- Criminal-empire fantasy: turf zones, crew roles, rival syndicates, optional heat

ENGINE: Godot 4.3+ (4.6.x in parent repo is fine)

CRITICAL ARCHITECTURE RULES:
- sim/ layer: NO extends Node, NO presentation imports — pure GDScript, headless-testable
- Combat resolves instantly in sim, then plays back from EventLog (never tie outcome to animation)
- All player actions = PlayerIntent commands validated by RunDirector — UI never mutates sim state
- Seeded RNG, fixed iteration order, combat snapshot isolated from planning state

DO NOT:
- Implement inside godot/ Criminal Empire scenes without explicit user request to merge modes
- Use generative-AI assets (ART_POLICY.md)
- Use physics/NavigationAgent for combat resolution
- Build live multiplayer in v1

WHEN IMPLEMENTING:
- Start with sim/ + headless runner before presentation polish
- Golden replay tests for combat regression
- Mobile renderer if using 3D board props; pure 2D iso needs no Forward+

OPEN DECISIONS (ask user if blocked): §21 at bottom of handoff
```

---

## 1. Relationship to Criminal Empire (parent repo)

| Aspect | Criminal Empire (`godot/`) | Turf Autobattler (this project) |
|--------|---------------------------|----------------------------------|
| Genre | Idle / incremental | Round-based auto-battler |
| Core loop | Buy buildings → IPS → prestige | Shop crew → board placement → combat rounds |
| Ship status | 1.0 product in active ship | **Greenfield — not started** |
| Shared IP | Territories, crew roles, rivals, heat | Optional thematic reuse |
| Shared code | None required at runtime | Optional: copy *data shapes* (trait names, territory ids) |
| Balance lab | `src/`, `sim_pacing.py` | Own headless sim in `sim/` + optional Python mirror |

**Default assumption:** Standalone Godot project (separate folder), e.g. `turf_autobattler/` at repo root OR sibling repo. Metagame *may* grant cross-game currency later — design hook only, not v1.

**Thematic vocabulary to reuse (data only, not code coupling):**

| CE system | Autobattler mapping |
|-----------|---------------------|
| Territories (20 districts) | Named **turf tiles** on board; home-turf buff |
| Crew roles (Protection, Collection, Smuggling, Territory, Heat) | Unit **tags** / traits |
| Rivals (5 factions) | Enemy **comps** + faction synergies |
| Heat | Optional run debuff (high illegal stack → raid event) |
| Prestige / Influence | Metagame unlock currency between runs |

---

## 2. Product vision

### One-line pitch

**Syndicate Skirmish:** Draft crew onto contested turf, watch automated firefights, eliminate rival syndicates over ~20–35 minutes — TFT pacing with criminal-empire fantasy.

### Player fantasy

- You are a fixer assembling street crews for block-by-block warfare
- Planning is the skill expression; combat is spectacle
- Turf control matters: units on home ground hit harder; contested lanes flip with momentum

### v1 scope (MVP)

| In | Out (defer) |
|----|-------------|
| PvE ladder (~10–15 rounds vs scaling rival comps) | Live 8-player Versus |
| Shop, bench, board (4×4 or 4×7 — see §21) | 50+ unique units |
| 8–12 unit types, 3–4 traits | Full item system |
| 2.5D board + silhouette units | Skeletal 3D characters |
| Resolve-then-playback combat | Real-time PvP netcode |
| Run end → metagame currency | Cross-app CE integration |
| Headless balance runner | Store / ads / IAP |

### Success criteria for v1 vertical slice

1. Complete one run: shop → fight → HP loss → win or eliminate in ≤15 rounds
2. Combat outcome identical when replaying same seed + board snapshot (deterministic)
3. `godot --headless` runs 1000 fights without display server
4. Runs at 60 FPS on mid-range Android in planning phase; playback skippable

---

## 3. Engine choice (locked)

**Godot 4.3+** — 2.5D presentation, strict sim/presentation split.

| Alternative considered | Why not default |
|------------------------|-----------------|
| Unity | Better live-ops SDKs; overkill for PvE v1; CE team already on Godot |
| Unreal | TFT uses it at AAA scale; wrong cost for indie 2.5D |
| Pure Python sim + web UI | Valid for lab; Godot chosen for mobile ship |

**2.5D presentation modes** (pick one at project start; both share same sim):

| Mode | Description | Godot nodes |
|------|-------------|-------------|
| `ISOMETRIC_2D` | TileMap + Y-sorted sprite units | `Node2D`, `TileMapLayer` |
| `BOARD_3D_BILLBOARD` | Flat 3D lot + `Sprite3D` crew facing camera | `Node3D`, `Sprite3D`, Mobile renderer |

Sim grid is always **2D integer `(col, row)`**. Depth is presentation-only via `GridToWorld()` + sort key.

---

## 4. Layer architecture

```
┌─────────────────────────────────────────────────────────┐
│  METAGAME LAYER (persistent across runs)                │
│  unlocks, cosmetics, account stats, run history         │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│  RUN LAYER (one match)                                  │
│  RunDirector → phase FSM → round loop                     │
└──────────────────────────┬──────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ ECONOMY SIM   │  │ COMBAT SIM    │  │ AI / RIVAL    │
│ shop, bench,  │  │ tick resolver │  │ comp builder  │
│ board, traits │  │ (pure data)   │  │               │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  EVENT BUS / EventLog (typed, serializable, replay-safe)│
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│  PRESENTATION (Godot scenes, 2.5D, audio, UI)           │
│  reads sim via RunBridge; emits PlayerIntent only       │
└─────────────────────────────────────────────────────────┘
```

### Hard rules

1. **`sim/` never `extends Node`** and never imports `presentation/`
2. **Presentation never writes** shop/board/combat state except via `RunBridge.submit_intent()`
3. **Combat outcome decided before playback** — animations are cosmetic
4. **Combat uses snapshot** — deep copy of boards at lock; planning state cannot mutate mid-fight
5. **All randomness** flows through seeded `sim/core/rng.gd` — no unseeded `randf()` in sim

---

## 5. Project layout (target tree)

Create as new Godot project when implementation begins:

```
turf_autobattler/
├── project.godot
├── data/                          # Passive Resources — no logic
│   ├── units/                     # UnitDef .tres
│   ├── traits/                    # TraitDef .tres
│   ├── items/                     # ItemDef .tres (v2)
│   ├── territories/               # TurfDef .tres
│   ├── abilities/                 # AbilityDef .tres
│   ├── rival_comps/               # Scripted enemy lineups by round
│   └── balance/                   # Pool weights, interest caps, damage formulas
│
├── sim/                           # Headless-testable; zero Node deps
│   ├── core/
│   │   ├── rng.gd
│   │   ├── grid.gd
│   │   ├── fixed_timestep.gd
│   │   └── event_log.gd
│   ├── economy/
│   │   ├── shop_pool.gd
│   │   ├── shop_state.gd
│   │   ├── bench_state.gd
│   │   ├── board_state.gd
│   │   └── economy_rules.gd
│   ├── combat/
│   │   ├── combat_state.gd
│   │   ├── combat_resolver.gd
│   │   ├── targeting.gd
│   │   ├── ability_executor.gd
│   │   ├── trait_calculator.gd
│   │   └── damage_pipeline.gd
│   ├── run/
│   │   ├── run_state.gd
│   │   ├── run_director.gd
│   │   └── intent_validator.gd
│   └── ai/
│       ├── rival_brain.gd
│       └── ghost_player.gd          # v2
│
├── presentation/
│   ├── autoload/
│   │   ├── game_app.gd
│   │   ├── run_bridge.gd
│   │   └── audio_director.gd
│   ├── scenes/
│   │   ├── boot/
│   │   ├── main_menu/
│   │   ├── run/
│   │   │   ├── run_shell.tscn
│   │   │   ├── board_view/
│   │   │   ├── shop_panel/
│   │   │   └── combat_overlay/
│   │   └── metagame/
│   └── components/
│
├── tools/
│   ├── headless_runner.gd
│   ├── balance_report.gd
│   └── replay_viewer.gd
│
└── tests/
    ├── sim/                       # GUT or custom asserts on sim/
    └── golden_replays/            # seed + intents → event hash
```

---

## 6. Run phase state machine

```
                    ┌─────────────┐
                    │  RUN_INIT   │
                    └──────┬──────┘
                           ▼
              ┌────────────────────────┐
         ┌───►│      PLANNING_PHASE      │◄───┐
         │    │  shop, bench, board      │    │
         │    └───────────┬────────────┘    │
         │                │ LOCK_BOARD      │ next round
         │                ▼                 │
         │    ┌────────────────────────┐    │
         │    │    COMBAT_RESOLVE      │    │
         │    │  (sync sim, EventLog)  │    │
         │    └───────────┬────────────┘    │
         │                ▼                 │
         │    ┌────────────────────────┐    │
         │    │   COMBAT_PLAYBACK      │    │
         │    │  (presentation only)   │    │
         │    └───────────┬────────────┘    │
         │                ▼                 │
         │    ┌────────────────────────┐    │
         └───►│      ROUND_RESOLVE     │────┘
              │  HP, gold, streak, XP   │
              └───────────┬────────────┘
                          │ eliminated or champion?
                          ▼
              ┌────────────────────────┐
              │ RUN_END → METAGAME     │
              └────────────────────────┘
```

| Phase | Sim | Presentation |
|-------|-----|--------------|
| `PLANNING` | Accept intents; mutate RunState | Drag-drop, shop UI, trait panel |
| `COMBAT_RESOLVE` | `combat_resolver.resolve()` → fills EventLog | Loading / "Fighting…" optional |
| `COMBAT_PLAYBACK` | Frozen | `CombatPlaybackDirector` consumes EventLog |
| `ROUND_RESOLVE` | Apply HP damage, payouts, streak, round++ | Result toast, damage to player HP bar |
| `RUN_END` | Finalize RunResult | Summary screen → metagame rewards |

**Skip playback:** `SKIP_PLAYBACK` intent jumps to `ROUND_RESOLVE`; outcome unchanged.

---

## 7. Data definitions (authoring schema)

Store as Godot Resources (`*.tres`) or exported JSON consumed at boot. Sim copies numeric values into instances at creation time.

### UnitDef

```
id: String                    # "corner_boy"
display_name: String
tier: int                      # 1–5 shop tier
cost: int
tags: Array[String]           # ["enforcer", "street"]
base_stats: {
  max_hp: int
  attack: int
  attack_speed: float          # attacks per tick interval or seconds — pick one system-wide
  armor: int
  range: int                   # grid cells; 1 = melee
}
ability_id: String | null
sell_value: int
pool_count: int                # copies in shared shop pool
```

### TraitDef

```
id: String                     # "enforcer"
display_name: String
tag_filter: String             # matches UnitDef.tags
breakpoints: Array[{
  count: int
  effects: Array[{ effect_id: String, params: Dictionary }]
}]
```

Example trait families (thematic):

| Trait | Tag | Breakpoints fantasy |
|-------|-----|---------------------|
| Enforcer | `enforcer` | 2/4/6 — armor, taunt |
| Fixer | `fixer` | 2/4 — heal, cleanse |
| Smuggler | `smuggler` | 2/3 — backline dash, evasion |
| Accountant | `accountant` | 1/2 — interest, shop odds |
| Faction: Bratva | `bratva` | 2/4 — faction bonus |

### TurfDef / TurfCell

```
TurfCellType: HOME | CONTESTED | NEUTRAL
TurfDef:
  id: String
  home_bonus: Dictionary       # e.g. { attack_pct: 10 }
  contested_rules: Dictionary # v2: flip on win
```

### AbilityDef

```
id: String
trigger: ON_COMBAT_START | ON_ATTACK | ON_HIT | ON_DEATH | PASSIVE
target_rule: SELF | LOWEST_HP_ENEMY | FRONTMOST_ENEMY | ADJACENT_ALLIES | ...
effect_id: String
params: Dictionary
```

### RivalComp (PvE)

```
round_min: int
round_max: int
units: Array[{ def_id: String, stars: int, grid_pos: Vector2i }]
optional_items: Array          # v2
```

---

## 8. Runtime state objects (sim)

### RunState

```
seed: int
round: int
phase: enum RunPhase
player_hp: int                 # syndicate reputation; 0 = eliminate
gold: int
level: int                     # player level → shop odds + board cap
xp: int
win_streak: int
loss_streak: int
shop: ShopState
bench: BenchState              # fixed slots (default 9)
board: BoardState
traits_cache: Array[ActiveTrait]  # invalidated on board change
rng: SeededRNG state
```

### UnitInstance

```
instance_id: int               # unique per run; monotonic
def_id: String
stars: int                     # 1–3 (merge tier); v1 may defer merges
items: Array[ItemInstance]      # v2
bench_slot: int | null
grid_pos: Vector2i | null
# Combat snapshot fields copied at fight start:
current_hp, max_hp, attack, armor, ...
```

### BoardState

```
width: int
height: int
slots: Dictionary              # Vector2i → instance_id | null
turf_map: Array[Array[TurfCellType]]
max_units: int                 # from player level
```

### ShopState

```
offers: Array[String | null]   # def_ids, length 5 typical
frozen: bool                   # optional v2
```

### ShopPool

```
remaining: Dictionary         # def_id → count
roll(player_level, rng) -> Array[def_id]
buy(def_id) -> bool
return_unit(def_id)            # on sell
```

### CombatState (snapshot at lock)

```
tick: int
units: Array[CombatUnit]       # flat; team_id, grid_pos, stats, alive
event_log: EventLog
rng: SeededRNG
outcome: PENDING | PLAYER | ENEMY | DRAW
```

---

## 9. Player intent API

All UI actions are commands:

| Intent | Phase | Description |
|--------|-------|-------------|
| `BUY_FROM_SHOP(index)` | PLANNING | Spend gold; unit → bench if space |
| `SELL(instance_id)` | PLANNING | Remove unit; refund sell_value |
| `REROLL_SHOP()` | PLANNING | Pay reroll cost; new offers |
| `BUY_XP()` | PLANNING | Pay 4 gold → +4 XP; level up if threshold |
| `MOVE_TO_BENCH(id, slot)` | PLANNING | From board or bench reorder |
| `MOVE_TO_BOARD(id, grid_pos)` | PLANNING | Valid empty slot, respect max_units |
| `SWAP_ON_BOARD(a, b)` | PLANNING | Swap two occupied cells |
| `LOCK_BOARD()` | PLANNING | End planning → combat |
| `PICK_AUGMENT(index)` | ROUND_RESOLVE | Optional between-round draft |
| `SKIP_PLAYBACK()` | COMBAT_PLAYBACK | Presentation + director only |

### Validation flow

```
UI → RunBridge.submit_intent(intent)
  → RunDirector.current_phase check
  → IntentValidator.validate(intent, RunState) → OK | RejectReason
  → if OK: mutate RunState, emit RunEvent, refresh trait cache if board changed
  → RunBridge emits state_changed(DTO)
```

**Validation always runs in the sim**, never in the UI — the UI may *grey out* an illegal action for feel, but the sim is the only authority and must re-check. A rejected intent mutates nothing and returns a typed reason:

| RejectReason | Cause |
|--------------|-------|
| `WRONG_PHASE` | Intent not legal in `current_phase` (see [§6](#6-run-phase-state-machine)) |
| `NOT_ENOUGH_GOLD` | Buy / reroll / XP cost exceeds `gold` |
| `BENCH_FULL` | `BUY_FROM_SHOP` with no free bench slot |
| `BOARD_FULL` | `MOVE_TO_BOARD` would exceed `board.max_units` |
| `INVALID_SLOT` | Target cell out of bounds / occupied (when occupancy required) |
| `UNKNOWN_INSTANCE` | `instance_id` not owned by player |
| `EMPTY_SHOP_SLOT` | `BUY_FROM_SHOP(index)` points at a sold/empty offer |
| `ALREADY_MAX_LEVEL` | `BUY_XP` at level cap |

Rejections are surfaced to the UI (toast / shake) but are **not** written to the replayable EventLog — only successful state mutations are.

---

## 10. Combat resolver

### Design

- **Tick-based**, not physics. A *tick* is the fixed-step heartbeat of the sim, **not** an attack. The tick rate is a sim constant (e.g. `TICKS_PER_SECOND = 10`); presentation maps ticks → wall time during playback.
- **Iteration order:** sort alive units by `(attack_speed desc, instance_id asc)` each tick — document and never change without golden test update.
- **Max ticks:** 600 default → force DRAW if exceeded.
- **Targeting:** default frontmost living enemy in same row, then nearest; abilities override via `target_rule`.
- **Movement (optional v1):** record `UNIT_STEP` events; sim-only grid positions update.

### Attack cadence (how `attack_speed` gates attacks)

Units do **not** attack every tick. Each unit carries an `attack_progress: float` accumulator. Standardize on one model and document it in `combat_resolver.gd`:

```
# attack_speed is "attacks per second"; TICKS_PER_SECOND is the sim constant.
unit.attack_progress += unit.attack_speed / TICKS_PER_SECOND   # each tick
# Unit may attack when progress >= 1.0; it can fire multiple times if buffed past 1.0.
while unit.attack_progress >= 1.0 and unit.can_act():
    unit.attack_progress -= 1.0
    do_attack(unit)
```

This keeps `attack_speed` a single global unit (attacks/sec), makes haste/slow effects trivial multipliers, and stays fully deterministic. Resolves the "pick one system-wide" note in [§7 UnitDef](#7-data-definitions-authoring-schema).

### Determinism contract

- **No true simultaneity.** Within a tick, units act sequentially in act-order; damage and deaths apply *immediately*. A faster (or lower `instance_id`) unit can kill its target before that target acts this tick — this is intended, not a bug.
- **Ties** are always broken by `instance_id asc`. Never sort on float-only keys.
- All randomness draws from `combat_state.rng` in act-order. Adding/removing an RNG draw changes every downstream fight — bump golden replays deliberately ([§19](#19-tools-and-ci)).

### Pseudocode

```
func resolve(combat_state: CombatState) -> CombatState:
  event_log.emit(COMBAT_START)
  while not terminal and tick < MAX_TICKS:
    for unit in get_act_order(combat_state):       # sorted (atk_spd desc, id asc)
      if not unit.alive: continue
      unit.attack_progress += unit.attack_speed / TICKS_PER_SECOND
      while unit.attack_progress >= 1.0 and unit.can_act():
        unit.attack_progress -= 1.0
        target = targeting.pick(unit, combat_state)
        if target == null: break
        result = damage_pipeline.apply(unit, target, combat_state.rng)
        event_log.emit_from(result)
        if target.hp <= 0:
          target.alive = false
          event_log.emit(UNIT_DIED, target.id)
    tick += 1
  outcome = determine_outcome(combat_state)
  event_log.emit(COMBAT_END, outcome)
  return combat_state
```

### Damage pipeline (ordered modifiers)

1. Base damage from attack stat
2. Armor reduction (formula in `balance/damage.gd` — document here when tuned)
3. Trait breakpoints active in snapshot
4. Turf HOME bonus if standing on home cell
5. Item modifiers (v2)
6. Clamp ≥ 0; apply to `current_hp`

---

## 11. EventLog catalog (combat + run)

All events must be **JSON-serializable** (ints, strings, bools, arrays only — no object refs).

**Schema version:** every serialized EventLog carries a `log_version: int` header. Golden replays ([§19](#19-tools-and-ci)) hash against a fixed `log_version`; bump it whenever an event's payload shape changes and regenerate the golden hashes in the same commit. The playback director ([§14](#14-presentation-architecture)) must tolerate unknown event types (skip, don't crash) so newer logs degrade gracefully on older presentation builds.

### Combat events

| type | payload fields |
|------|----------------|
| `COMBAT_START` | `player_units[]`, `enemy_units[]` summaries |
| `COMBAT_END` | `outcome`, `tick` |
| `UNIT_STEP` | `instance_id`, `from`, `to` |
| `ATTACK_START` | `attacker_id`, `target_id` |
| `DAMAGE` | `source_id`, `target_id`, `amount`, `remaining_hp` |
| `HEAL` | `source_id`, `target_id`, `amount` |
| `ABILITY_CAST` | `caster_id`, `ability_id`, `targets[]` |
| `UNIT_DIED` | `instance_id`, `team` |
| `TILE_CONTESTED` | `pos`, `new_owner` (v2) |

### Run events (metagame / UI)

| type | payload |
|------|---------|
| `PHASE_CHANGED` | `from`, `to` |
| `GOLD_CHANGED` | `delta`, `reason` |
| `HP_CHANGED` | `delta`, `reason` |
| `SHOP_ROLLED` | `offers[]` |
| `TRAIT_UPDATED` | `active_traits[]` |
| `ROUND_STARTED` | `round` |
| `RUN_ENDED` | `result`, `rounds_survived` |

### Playback contract

`CombatPlaybackDirector` iterates EventLog in order:

```
for event in log.combat_events:
  match event.type:
    ATTACK_START → unit_views[attacker].play_attack()
    DAMAGE → spawn float text; unit_views[target].flash()
    UNIT_DIED → unit_views[id].play_death()
  await timer(event_duration / speed_multiplier)
```

Pool all VFX nodes; no `instantiate()` per damage number in tight loops.

---

## 12. Economy rules (v1 defaults — tune in balance/)

| Rule | Default | Notes |
|------|---------|-------|
| Starting HP | 100 | |
| Starting gold | 0 + round 1 payout | |
| Base gold per round | 5 | |
| Win streak bonus | +1 per win, cap +3 | |
| Loss streak | no gold bonus | |
| Interest | +1 per 10 gold saved, cap +5 | Optional v1 |
| Reroll cost | 2 | |
| XP buy | 4 gold → 4 XP | |
| Level thresholds | `[0,2,6,10,20,36,56,80,100]` | Match TFT-like curve or simplify |
| Board size cap | level → max units on board | e.g. L1=1 … L8=8 |
| HP loss on defeat | `base + survivors*2 + star_bonus` | Tune via sim |
| Shop pool | shared finite pool per def_id | SAP/TFT model |

---

## 13. PvE AI (v1)

**RivalDirector** selects `RivalComp` by current `round` from `data/rival_comps/`.

- v1: **fully scripted** boards — no AI shopping
- v2: **RivalBrain** uses same ShopPool + greedy trait targeting
- Scaling: multiply enemy stats by `1 + round * 0.05` or discrete tiers

Enemy board enters `COMBAT_RESOLVE` as team `ENEMY`; player as `PLAYER`.

---

## 14. Presentation architecture

### RunBridge (autoload façade)

```
class RunBridge:
  var run_director: RunDirector

  func start_run(config: RunConfig) -> void
  func submit_intent(intent: PlayerIntent) -> void
  func get_run_dto() -> RunViewModel
  func get_shop_dto() -> ShopViewModel
  func get_board_dto() -> BoardViewModel
  func get_trait_dto() -> Array[TraitViewModel]
  func skip_playback() -> void

  signal state_changed
  signal phase_changed(new_phase)
  signal combat_event(event: Dictionary)   # during playback
  signal run_ended(result: RunResult)
```

View models contain **no sim object references** — plain dictionaries or typed structs.

### Scene hierarchy

```
RunShell (Control)
├── BoardViewport
│   ├── TurfBoardView          # tiles, turf tint, props
│   ├── UnitLayer              # Y-sorted; sync from BoardViewModel
│   └── FxLayer
├── ShopPanel
├── BenchPanel
├── HudLayer                   # HP, gold, round, traits
├── CombatPlaybackDirector
└── InputRouter                # drag-drop → intents
```

### IBoardPresenter interface

Abstraction for 2.5D mode swap:

```
grid_to_world(col, row) -> Vector2 | Vector3
depth_sort_key(col, row) -> float
place_unit_view(view, col, row) -> void
highlight_cells(cells[], style) -> void
clear_highlights() -> void
```

Implementations: `IsoBoardPresenter`, `BillboardBoardPresenter`.

### Unit view pool

- Key: `instance_id`
- On `state_changed`: diff view models → spawn/despawn/tween position
- Silhouette + team color + star pips (art policy friendly)

---

## 15. 2.5D coordinate contract

| Concern | Owner |
|---------|--------|
| Grid occupancy | `BoardState` (sim) |
| Valid placement | `IntentValidator` |
| Home turf combat bonus | `TraitCalculator` + `TurfCell` |
| World position | `IBoardPresenter.grid_to_world` |
| Draw order | `depth_sort_key` — typically `row * width + col` |
| Shadow sprite | presentation offset beneath feet |

**Sim origin:** pick bottom-left OR top-left for `(0,0)` — document in `sim/core/grid.gd` and never mix.

---

## 16. Metagame (cross-run)

```
MetagameState {
  currency: int                 # "Street Cred" or reuse "Influence" if CE-linked
  unlocks: Array[String]       # unit skins, starting bonuses
  stats: { runs, wins, best_round }
}
```

```
RunResult {
  won: bool
  round_reached: int
  damage_dealt: int
  traits_used: Array[String]
  rewards: Dictionary
}
```

`MetagameRules.apply(RunResult) → MetagameState` — pure function in `sim/metagame/`.

---

## 17. Save format

```
SaveRoot {
  version: int
  metagame: MetagameState
  active_run: RunState | null
  settings: { sfx, music, playback_speed }
}
```

- **Mid-run resume:** save at `PLANNING` phase only (simplest)
- **Mid-playback resume:** optional — replay from EventLog or rewind to planning
- **Migration:** default missing fields in loader; bump `version`

---

## 18. Audio (presentation only)

`AudioDirector` listens to `RunBridge` + `CombatPlaybackDirector`:

| Trigger | Cue |
|---------|-----|
| PLANNING phase | low tension loop |
| LOCK_BOARD | lock SFX |
| COMBAT_PLAYBACK | combat loop |
| ATTACK event | procedural gunshot / punch via sfxr pattern (see CE `godot/scripts/audio/`) |
| RUN_END | stinger |

**No audio in `sim/`.** Follow `ART_POLICY.md` — procedural/code-built only.

---

## 19. Tools and CI

### HeadlessRunner (`tools/headless_runner.gd`)

```bash
godot --headless --script tools/headless_runner.gd -- \
  --seed=12345 --iterations=1000 --player_comp=comps/aggressive.json
```

Outputs: win rate, avg combat ticks, TTK histogram CSV.

### Golden replays (`tests/golden_replays/`)

```
{ seed, player_board, enemy_board } → sha256(combat_event_types + final outcome)
```

CI runs headless; fails on hash mismatch.

### Optional Python mirror

Export `data/balance/*.json` from same source as `.tres` for `sim_branch_validation.py`-style lab in parent repo — **optional**, not blocking.

---

## 20. Performance budgets

| Metric | Target |
|--------|--------|
| Combat resolve (sim) | < 50 ms per fight on mid phone |
| Combat playback | 15–40 s wall time; skippable |
| Planning UI | 60 FPS |
| Draw calls (2.5D) | < 150 |
| Allocations during combat ticks | 0 new UnitInstance |

Godot renderer if 3D props: **Mobile** renderer, not Forward+. Cap `Engine.max_fps = 60`.

---

## 21. Open decisions (agent: ask user if blocked)

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Grid size | 4×4 vs 4×7 | 4×7 for TFT feel; 4×4 for faster MVP |
| 2 | Project location | `turf_autobattler/` vs inside `godot/` as mode | Separate folder |
| 3 | Unit merges (3-copy) | v1 yes / defer | Defer to v1.1 |
| 4 | Heat system | sim debuff / cosmetic / skip | Skip v1 |
| 5 | Default 2.5D mode | ISOMETRIC_2D vs BOARD_3D_BILLBOARD | ISOMETRIC_2D for MVP |
| 6 | Starting HP / rounds | 100 HP, 15 rounds | Tune via headless |
| 7 | CE metagame link | standalone / shared currency | Standalone v1 |

---

## 22. Implementation order (when user approves coding)

1. **`sim/core`** — rng, grid, event_log
2. **`sim/economy`** — shop, bench, board, economy_rules
3. **`sim/combat`** — resolver, targeting, damage (no abilities first)
4. **`sim/run`** — RunDirector FSM + intents
5. **`data/`** — 8 units, 3 traits, 10 rival comps
6. **`tools/headless_runner`** + 3 golden replays
7. **`presentation/run_bridge`** + placeholder rectangles
8. **Board + shop UI** — intents wired
9. **CombatPlaybackDirector** — event playback
10. **Metagame shell** — run end rewards
11. **2.5D polish** — iso tiles, shadows, juice
12. **AudioDirector** — procedural SFX

Do **not** start at step 11. Sim + headless gate everything.

---

## 23. Agent conventions (mandatory)

1. Read **`ART_POLICY.md`** before any visual or audio work — no generative-AI assets
2. **`sim/`** must run without scene tree — unit-testable
3. Never tie combat outcome to animation completion
4. Player actions = **intents only**
5. Seeded RNG in sim; document seed in save for replay debug
6. Prefer **minimal diff** — no scope creep into CE idle game unless asked
7. Do not commit `.godot/` cache (see `godot/.gitignore` pattern)
8. After code changes in parent repo CE work: `python -m graphify update .` — optional for isolated `turf_autobattler/` project

---

## 24. Reference links (research basis)

| Topic | Reference |
|-------|-----------|
| Godot autobattler course | GodotGameLab YouTube (S1/S2 AutoBattler) |
| Open 2D autobattler demo | github.com/R055LE/horror-battler |
| Godot balance sim framework | github.com/applesnort/godot-autosim |
| TFT engine migration context | Riot Hextech → Unreal (Set 18, 2026) — scale tooling, not genre requirement |
| Super Auto Pets stack | Unity (commercial live-ops reference) |
| Parent repo ship conventions | `SHIP_ARCHITECTURE.md`, `godot/P2_HANDOFF.md` |

---

## 25. Glossary

| Term | Meaning |
|------|---------|
| Auto-battler | Shop/plan phase + automated combat resolution |
| 2.5D | 2D gameplay/sim with depth cues (iso or billboards) |
| Resolve-then-playback | Sim computes full fight instantly; UI animates EventLog |
| Intent | Validated player command mutating RunState |
| Comp | Enemy team composition for a round |
| Trait | Synergy from shared unit tags at breakpoints |
| Turf | Board cell with HOME/CONTESTED/NEUTRAL semantics |
| EventLog | Append-only serializable combat/run events |
| RunBridge | Presentation façade to sim |
| Golden replay | Fixed seed+boards → expected event hash for CI |

---

## 26. Document history

| Date | Change |
|------|--------|
| 2026-06-27 | Initial architecture handoff — design only, no implementation |
| 2026-06-27 | Added table of contents + reading order; specified attack-cadence (accumulator) model, determinism/tie-break contract, and updated resolver pseudocode (§10); added EventLog schema versioning (§11); enumerated intent reject reasons (§9) |

---

*End of handoff. Implementation agents: start with §22 order only after explicit user request to build.*
