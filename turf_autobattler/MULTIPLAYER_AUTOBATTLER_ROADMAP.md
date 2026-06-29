# Multiplayer Autobattler Roadmap

**From single-player PvE (`RivalDirector` scripted comps) → authoritative 8-player PvP (Teamfight-Tactics-style).**

This document is an **architecture and networking plan only**. No implementation code is written here. It is grounded in the current `turf_autobattler/` codebase as it exists today.

---

## 0. Why our current architecture is already 80% of the way there

Before planning changes, the single most important fact: **this sim was built for authoritative netcode without knowing it.** Five existing properties make the pivot a refactor rather than a rewrite.

| Existing property | File | Why it matters for server-authority |
|---|---|---|
| **Single-entry command pattern.** All state mutation flows through one method, gated by a pure validator. | [`sim/run/run_director.gd`](sim/run/run_director.gd) `submit_intent()` + [`sim/run/intent_validator.gd`](sim/run/intent_validator.gd) | The server already has exactly one choke point to authorize. A client never mutates state directly — it submits a `PlayerIntent`, the server validates, then applies. This *is* the authoritative model. |
| **Fully snapshot-able per-player state.** | [`sim/run/run_state.gd`](sim/run/run_state.gd) `duplicate_state()` | Server can snapshot, roll back, and diff any player's `RunState` deterministically. Enables rollback netcode, save/restore, and per-tick delta replication. |
| **Serializable deterministic RNG (LCG).** | [`sim/core/rng.gd`](sim/core/rng.gd) — `get_state()` / `set_state()` | The entire game's randomness is a single 31-bit integer. The server can ship RNG state to clients (or withhold it) and reproduce any roll. Determinism across machines is already guaranteed by the integer LCG (no floats in the RNG path). |
| **Combat resolves synchronously into a replayable event stream.** Combat is *computed instantly*, then *played back* visually. | [`sim/combat/combat_resolver.gd`](sim/combat/combat_resolver.gd) `resolve()` → [`sim/core/event_log.gd`](sim/core/event_log.gd) | The server resolves a fight in one call and produces a complete `EventLog`. It replicates the log; clients replay it. There is no per-frame combat netcode to write — the network unit is the event log, not the frame. |
| **Hash-based golden replay harness already exists.** | [`tools/headless_main.gd`](tools/headless_main.gd) `_test_golden_replays()` + [`tests/golden_replays/cases.json`](tests/golden_replays/cases.json) | We already assert that combat is bit-identical given `(seed, player units, enemy units)`. This is the cross-machine determinism test we need — it just needs to be promoted to a CI gate and extended to multi-grid cases. |

**The corollary that shapes everything below:** combat is currently **not** a real-time, clock-driven simulation. `RunDirector._lock_board()` calls `CombatResolver.resolve()` which runs the *entire* fight in a `while` loop to completion (`MAX_COMBAT_TICKS = 600`, `TICKS_PER_SECOND = 10`), then sets phase to `COMBAT_PLAYBACK`. The presentation layer ([`presentation/autoload/run_bridge.gd`](presentation/autoload/run_bridge.gd) → `combat_playback_director`) animates the already-decided log.

This has a **major consequence for Feature 2 (Commander Spells)**: there is currently *no mid-combat input channel at all*. Real-time spellcasting requires changing combat from "resolve-then-replay" to "tick-streamed-and-interruptible." That is the single largest architectural change in this roadmap, and it is deliberately gated behind the networking foundation.

---

## Phase ordering (global)

**Phase 1 is the Networking Foundation and nothing else.** No gameplay feature begins until lobbies, the authoritative loop, and state replication are proven against the headless harness. The five features are then layered in dependency order:

```
Phase 1  Networking Foundation ........ lobby, authoritative server, intent transport, state replication
Phase 2  Shared Economy ............... single shared ShopPool, contested unit pool
Phase 3  Turn Sync + Pairing .......... global round clock, prep phase, opponent-snapshot pairing
Phase 4  Dynamic Environments ......... server-authored per-grid hazards / destructibles
Phase 5  Asymmetric Comps ............. multi-hex occupancy, pathfinding, hitboxes
Phase 6  Modular Items (Sockets) ...... server-validated equip/socket
Phase 7  Commander Spells (real-time) .. tick-streamed interruptible combat, input buffering, conflict resolution
```

Note the deliberate reordering vs. the brief: **Commander Spells move to last.** They require the tick-streamed combat model, which is risky and should sit on top of a fully proven foundation, shared economy, and pairing. Everything before it can ship on the existing resolve-then-replay combat.

---

# Feature 1 — Multiplayer Foundation & Shared Lobby Architecture

### Architectural Strategy

**1.1 Headless runner → Authoritative Server.**
Today [`tools/headless_main.gd`](tools/headless_main.gd) constructs one `RunDirector` per simulated run in a loop. The server is the same idea, made concurrent and connected:

- New autoload/scene `server/match_server.gd` (Godot `SceneTree` headless, launched the same way as `tools/headless_main.tscn`). It owns **N `RunDirector` instances — one per connected player** — plus shared singletons (`ShopPool`, round clock, RNG).
- Transport: Godot **`ENetMultiplayerPeer`** in dedicated-server mode (`create_server`). The server is `multiplayer_authority = 1`; clients are peers `2..9`.
- The client's `run_bridge.gd` is split: the **sim half** (`RunDirector`) moves server-side; the **presentation half** (DTOs, playback director, signals) stays client-side. `run_bridge.gd` becomes a *network façade* that sends intents and receives state, preserving its existing signal API (`state_changed`, `phase_changed`, `combat_event`, `run_ended`) so UI code does not change.

**1.2 Intent transport (the key reuse).**
`PlayerIntent` ([`sim/run/player_intent.gd`](sim/run/player_intent.gd)) is already a `{type: String, params: Dictionary}` — trivially serializable. The wire protocol is:

- Client → Server RPC: `submit_intent_rpc(type, params)` (`@rpc("any_peer", "call_remote", "reliable")`).
- Server resolves the calling peer → its `RunDirector`, calls `IntentValidator.validate()`, then `submit_intent()`. **The validator is already the anti-cheat boundary** — every illegal action returns a `RejectReason`. We add one rule: an intent is only valid for the `RunDirector` owned by the peer that sent it (peer-ownership check), preventing player A from acting on player B's board.
- Server → Client: validated result + state delta (see 1.3). Rejections return the `RejectReason` to the originating client only.

**1.3 State replication: DTOs, not raw state.**
We never replicate `RunState` objects (they contain `RefCounted` graphs and RNG internals a client must not see — e.g. another player's future shop). Instead we reuse the **DTO methods that already exist** in `run_bridge.gd`: `get_run_dto()`, `get_shop_dto()`, `get_bench_dto()`, `get_board_dto()`, `get_trait_dto()`. These move server-side and become the replication payload:

- After each applied intent, server sends the affected player only *their* private DTOs (`run`, `shop`, `bench`, `board`, `traits`).
- Public/global state (round number, phase, timer, player HP ladder, who's alive) is replicated to **all** peers via a `LobbyStateDTO`.
- Replication is **state-snapshot per intent**, not interpolation. Because the prep phase is turn-based-ish (not twitch), we do not need interpolation here; full small DTO snapshots are simplest and authoritative. Interpolation only becomes relevant for real-time combat playback (Feature 7).

**1.4 Lobby / match lifecycle state machine.**
New `server/lobby_state.gd` (sim-side, `RefCounted`, snapshot-able like everything else):

```
LOBBY_WAITING  → players connect (1..8), ready-up
LOBBY_LOCKED   → 8 reached or host starts; assign player_ids, derive match seed
MATCH_RUNNING  → drives the global round clock (Feature 3)
MATCH_ENDED    → last player standing; emit results, return to LOBBY_WAITING
```

- **One match seed**, broadcast at `LOBBY_LOCKED`, seeds the shared `ShopPool` RNG and every per-player `RunState.rng`. Per-player RNG is derived deterministically (e.g. `match_seed XOR player_id`) so each player's private rolls are reproducible server-side but independent.
- Disconnect handling: a dropped peer's `RunDirector` is flagged `disconnected`; the server keeps simulating it as a "ghost" (frozen board) so combat pairings still resolve, and HP continues to bleed, matching TFT's abandon behavior.

### Simulation & Testing Impact

- **Promote golden replays to a hard CI gate.** `_test_golden_replays()` currently returns a bool used as the headless exit code. Wire it into CI so any non-deterministic change fails the build. This is the foundation guarantee for everything else.
- **New "loopback server" headless mode.** Extend `tools/headless_main.gd` with a mode that spins up `match_server.gd` plus N *scripted* clients (driving the existing `_auto_buy_and_place()` AI as bot players) over an in-process `ENetMultiplayerPeer` loopback. Assert that an 8-bot match runs to completion deterministically given a fixed match seed.
- **Determinism-across-process test.** Run the same match seed in two separate headless processes; assert identical final `LobbyStateDTO` and identical per-player board hashes. This catches platform/float divergence the single-process golden test cannot.
- **Intent-transport fuzz test.** Replay a recorded intent stream through `submit_intent_rpc` and assert the server's resulting board hash equals the local single-player result for the same intents+seed. Proves the network path introduces zero state divergence.

### Step-by-Step Implementation Phase (Phase 1 — Networking Foundation)

1. **Extract the sim/presentation seam cleanly.** Confirm no sim class (`sim/**`) references presentation or `Node` singletons. (Audit only — the code already follows this; `SimConstants` is explicitly "no Node dependencies.")
2. **Add `server/lobby_state.gd`** with the lifecycle state machine and `match_seed` derivation. Snapshot-able. Pure sim, unit-tested headless.
3. **Add `server/match_server.gd`** owning `Dictionary<peer_id, RunDirector>` + shared singletons. Launchable headless like `headless_main.tscn`.
4. **Define the wire DTOs** (`LobbyStateDTO`, plus the existing private DTOs) and the RPC surface: `submit_intent_rpc`, `replicate_private_state`, `replicate_lobby_state`.
5. **Add peer-ownership validation** to the intent path (one new `RejectReason`: `NOT_YOUR_BOARD`).
6. **Convert `run_bridge.gd` into a network façade** — same signals, but `submit_intent()` now sends an RPC and applies received DTOs instead of calling a local `RunDirector`. Single-player becomes "loopback server with one peer."
7. **Stand up the loopback-server headless harness** and the determinism-across-process test (Testing Impact above).
8. **CI gate:** golden replays + loopback 8-bot determinism must pass before any Phase ≥ 2 work merges.

**Exit criteria:** 8 bot clients complete a full match over ENet loopback, deterministically, with all state authoritative on the server and the existing UI driven only by replicated DTOs.

---

# Feature 2 — Shared Economy (Globally Synced Unit Pool)

### Architectural Strategy

Today every player gets a **private** pool: `RunState.shop_pool = ShopPool.create_default()` ([`sim/run/run_state.gd`](sim/run/run_state.gd):16) and rolls from it independently ([`sim/economy/shop_pool.gd`](sim/economy/shop_pool.gd)). For PvP we need **one shared pool** so that when one player buys a unit, it is genuinely removed from everyone's odds — the contesting mechanic that defines TFT economy.

- **Move `ShopPool` ownership from `RunState` to `match_server.gd`** (one instance per match, not per player). Remove `shop_pool` from `RunState` / `duplicate_state()`; replace with a server reference.
- `ShopPool.buy()` / `return_unit()` ([`sim/economy/shop_pool.gd`](sim/economy/shop_pool.gd):15-25) already do atomic decrement/increment on `remaining`. These now mutate the *shared* pool. The only required change is **routing**: `RunDirector._buy_from_shop()` ([`sim/run/run_director.gd`](sim/run/run_director.gd):61) and `_sell_unit()` must call the server-owned pool, not `state.shop_pool`.
- **Rolls become server-serialized.** `ShopPool.roll()` consumes `state.rng`. With a shared pool, two players rolling "simultaneously" must be ordered. The server processes intents on a single thread in arrival order (it already does — one `submit_intent` at a time), so pool reads/writes are naturally serialized. We add an explicit **per-roll pool snapshot in the event log** for audit/replay.
- **Tier-weighted odds amplify contesting.** `_roll_one()` now selects a tier via `TIER_ODDS_BY_LEVEL` (TFT-style probability weights per player level) and only then picks a unit from that tier's *remaining* stock ([`sim/economy/shop_pool.gd`](sim/economy/shop_pool.gd):38-87). In a shared pool this makes scarcity propagate through the odds themselves: when contesting players drain a tier's stock, that tier's effective hit-rate collapses for everyone, not just the count. The roll stays deterministic — tier keys and the per-tier candidate list are both `sort()`-ed before the single `rng.next_int()` draw — so server-side reproduction and golden replays are unaffected. This raises the value of the per-tier `remaining` replication below (clients must surface tier-depletion to make contest decisions legible).
- **Replication:** the pool's `remaining` counts are *semi-public* — TFT shows pool-depletion indirectly via odds. We replicate aggregate `remaining` (or a derived "X of Y left" per unit tier) in `LobbyStateDTO` so clients can show contest pressure, but the server remains the only authority on actual rolls.

### Simulation & Testing Impact

- **New invariant test:** total units in existence is conserved. `sum(pool.remaining[def]) + sum(units owned across all players' RunStates) == initial pool_count[def]` for every `def_id`, asserted after every intent in the headless 8-bot soak. This catches double-spend / dupe bugs that only manifest under concurrency.
- **Contention test:** scripted scenario where 8 bots all chase the same `def_id`; assert the pool empties exactly, no negative counts, and the Nth+1 buyer is correctly rejected (`EMPTY_SHOP_SLOT` / unit absent from rolls).
- Golden replays extend to include shared-pool sequences: a recorded multi-player buy/sell/roll interleaving must reproduce identical pool state by hash.

### Step-by-Step Implementation Phase (Phase 2)

1. Lift `ShopPool` out of `RunState` into `match_server.gd`; delete pool fields from `duplicate_state()`.
2. Route `_buy_from_shop`, `_sell_unit`, `_roll_shop` through the shared pool (server injects the pool reference into `RunDirector`).
3. Add pool-snapshot events to the `EventLog` on each roll/buy/return for replay+audit.
4. Add `remaining`-aggregate to `LobbyStateDTO` replication.
5. Add the conservation invariant + contention tests to the headless soak; make them CI-blocking.

**Depends on:** Phase 1 (server owns shared singletons, intents are serialized server-side).

---

# Feature 3 — Turn Synchronization (Round Clock, Prep Phase, Pairing)

### Architectural Strategy

Today `RunDirector` advances phases **locally and instantly** per player (`PLANNING → COMBAT_RESOLVE → COMBAT_PLAYBACK → ROUND_RESOLVE`, see [`sim/core/sim_constants.gd`](sim/core/sim_constants.gd):30 `RunPhase`). In PvP, all players must share a **global round clock** and be **paired against each other** instead of against `RivalDirector` scripted comps.

- **Global round clock owned by `match_server.gd`.** A monotonic server timer drives prep-phase countdown (e.g. 30s). The server, not the client, decides when `PLANNING` ends. At timeout (or when all players lock early), the server transitions *every* `RunDirector` into combat together. The current per-player `LOCK_BOARD` intent becomes "ready early"; it no longer triggers combat by itself.
- **Pairing replaces `RivalDirector`.** This is the core PvE→PvP swap. Today `RunDirector._lock_board()` ([`sim/run/run_director.gd`](sim/run/run_director.gd):151) calls `RivalDirector.build_enemy_units()` ([`sim/ai/rival_director.gd`](sim/ai/rival_director.gd)). For PvP:
  - At combat start, the server computes a **pairing** (round-robin / TFT-style with ghost rounds when odd). 
  - For each pair `(A, B)`, the server takes a **snapshot of B's board** (`A` fights a *copy* of B's units, and vice versa) and feeds it to the **unchanged** `CombatResolver.build_combat_state(player_entries, enemy_entries, board, rng, round)` ([`sim/combat/combat_resolver.gd`](sim/combat/combat_resolver.gd):4). The enemy-entries array that `RivalDirector` used to produce is now produced from a real opponent's `board.slots` + `units`.
  - **Keep `RivalDirector` alive as a fallback** for ghost/PvE rounds and for solo testing — it already conforms to the `{units, board_entries, next_instance_id}` shape the resolver consumes, so it remains a valid enemy-source plugin.
- **Determinism of paired combat.** Each pairing's combat seed = `derive(match_seed, round, min(playerA_id, playerB_id))` so both directions of a mirror (and any re-simulation) are reproducible. Combat still resolves server-side via the existing synchronous `resolve()`; the resulting `EventLog` is replicated to **both** players in the pair (A sees it from their orientation, B from theirs — we add a board-flip transform in the DTO layer, not the sim).
- **HP/economy resolution stays in `_finish_round()`** ([`sim/run/run_director.gd`](sim/run/run_director.gd):167) but now keyed off the real opponent result, and the server applies it to all players before opening the next prep phase together.

### Simulation & Testing Impact

- **Pairing-symmetry golden test:** for a pair `(A, B)`, resolving "A vs snapshot(B)" and "B vs snapshot(A)" from the shared combat seed must produce consistent, hash-stable, mutually exclusive outcomes (no double-win). Add these as new `cases.json` entries with two boards.
- **Round-clock determinism:** the headless 8-bot harness drives the *server* clock (not wall-clock) in fixed steps so prep-phase timeouts are reproducible; assert all 8 players transition phases on the same server tick.
- Extend `tools/headless_main.gd`'s per-round diagnostics (it already tracks win%, level, board size per round) to a *match-wide* table: 8 players × rounds, asserting exactly one winner and monotonic eliminations.

### Step-by-Step Implementation Phase (Phase 3)

1. Add server-owned round clock + global phase broadcast to `LobbyStateDTO`.
2. Demote `LOCK_BOARD` to "ready"; server controls combat-start transition.
3. Implement pairing algorithm in `match_server.gd` (round-robin + ghost handling).
4. Replace the `RivalDirector` call site in `_lock_board()` with a pluggable **enemy-source**: `OpponentSnapshotSource` (PvP) or `RivalDirector` (PvE/ghost). Same return shape.
5. Add per-pair combat-seed derivation; replicate each pair's `EventLog` to both players with a board-flip DTO transform.
6. Apply `_finish_round()` results server-side for all players, then open the next prep phase synchronously.
7. Pairing-symmetry + round-clock determinism tests → CI gate.

**Depends on:** Phase 1 (server clock + replication), Phase 2 (shared economy feeding the boards being paired).

---

# Feature 4 — Dynamic / Destructible Environments

### Architectural Strategy

The hook **already exists**: `BoardState.turf_map` is a 2D array of `SimConstants.TurfCellType { HOME, CONTESTED, NEUTRAL }` ([`sim/economy/board_state.gd`](sim/economy/board_state.gd):15-22), and `CombatResolver.resolve()` already reads per-cell turf and feeds it into damage: `player_board.get_turf_type(unit.grid_pos)` → `DamagePipeline.apply(unit, target, turf_type)` ([`sim/combat/combat_resolver.gd`](sim/combat/combat_resolver.gd):46-47). Dynamic terrain is an **extension of an existing system**, not a new one.

- **Extend `TurfCellType`** with combat-relevant states: `HAZARD` (DoT/zone), `HIGH_GROUND` (range/damage mod), `OBSTACLE` (impassable, destructible HP), `RUBBLE` (post-destruction). Each cell becomes a small struct `{type, hp, owner_team, mods}` rather than a bare enum, stored in `turf_map`. `duplicate_board()` already deep-copies `turf_map` (`turf_map.duplicate(true)`), so snapshot/rollback keeps working for free.
- **Server-authored generation.** The match seed + round number deterministically generate each grid's terrain server-side (`server/terrain_generator.gd`, pure sim, RNG-driven). Terrain is generated **per pairing's grid** at combat start and is identical for both players in the pair (fairness) — both fight on the same hazard layout, oriented per side.
- **Destruction is an event, not a frame.** Since combat is resolve-then-replay, obstacle destruction is computed inside `resolve()` and emitted to the `EventLog` (`OBSTACLE_DAMAGED`, `OBSTACLE_DESTROYED`, `HAZARD_TICK`). Clients replay these exactly like `DAMAGE`/`UNIT_DIED` events — **no new netcode**, just new event types the playback director knows how to animate. This is the cleanest possible path and a strong reason to keep destructibles on the resolve-then-replay model (i.e., before Feature 7).
- **Replication:** the initial terrain layout for a pair is part of the combat-start payload (alongside the board snapshots). Mid-combat changes ride the existing `EventLog` replication from Feature 3.

### Simulation & Testing Impact

- **Terrain determinism golden test:** same `(match_seed, round, pair)` → identical `turf_map` layout, asserted by hash. Add a third board ("terrain") to the relevant `cases.json` entries.
- **Combat-with-terrain golden replays:** extend existing cases with hazards/obstacles and lock their event-log hashes, exactly as `_combat_hash()` ([`tools/headless_main.gd`](tools/headless_main.gd):238) already does — it hashes the full event stream, so new terrain events are automatically covered once added.
- **Pathfinding interaction** with `OBSTACLE` cells is validated jointly with Feature 5 (occupancy) — obstacles are just permanently-occupied cells from the pather's view.

### Step-by-Step Implementation Phase (Phase 4)

1. Promote `turf_map` cells from enum to `{type, hp, mods}` struct; update `get_turf_type`/`duplicate_board` (the latter already deep-copies).
2. Add new `TurfCellType` values + the `DamagePipeline` modifiers for HAZARD/HIGH_GROUND.
3. Add `server/terrain_generator.gd` (deterministic, RNG-driven, per-pair).
4. Add `OBSTACLE_DAMAGED/DESTROYED`, `HAZARD_TICK` to the `EventLog` inside `resolve()`.
5. Include terrain layout in the combat-start payload; teach the playback director the new events.
6. Terrain-determinism + terrain-combat golden tests → CI gate.

**Depends on:** Phase 3 (per-pair grids exist to place terrain on). Combat model unchanged (still resolve-then-replay).

---

# Feature 5 — Asymmetric Compositions (Behemoth & Horde)

### Architectural Strategy

Today every unit occupies **exactly one cell**: `BoardState.slots` is `Dictionary<"x,y", instance_id>` (one key → one id) and `UnitInstance.grid_pos` is a single `Vector2i` ([`sim/economy/unit_instance.gd`](sim/economy/unit_instance.gd):8). Targeting uses Manhattan/row logic with single-cell positions. Multi-hex units (a 2×2 Behemoth) and Horde swarms (many cheap bodies) break these assumptions. This is the **deepest sim change** and must stay fully deterministic and server-verified.

- **Occupancy model: from `pos` to `footprint`.** Give units a `footprint: Array[Vector2i]` (offsets from an anchor). Single-hex units have `[(0,0)]` (the default — preserves all current behavior). `BoardState.slots` becomes `Dictionary<"x,y", instance_id>` where **multiple keys may map to the same id** (a Behemoth occupies 4 keys). Add `BoardState.cells_occupied_by(id)` and make `set_unit_at`/`get_unit_at` footprint-aware. `count_units()` must count distinct ids, not keys.
- **Placement validation** in `IntentValidator._validate_move_to_board()` ([`sim/run/intent_validator.gd`](sim/run/intent_validator.gd):84) extends to: every footprint cell in-bounds and empty. This keeps anti-cheat at the validator — a client cannot place a Behemoth overlapping another unit because the server rejects it.
- **Pathfinding & collision in combat.** `CombatResolver` currently has no movement (units act in place; targeting is row/range based). Behemoth/Horde require real movement → add deterministic grid pathfinding (A* or BFS over free cells, **integer costs only**, ties broken by `instance_id` exactly as `_get_act_order` already does ([`sim/combat/combat_resolver.gd`](sim/combat/combat_resolver.gd):65-69) to preserve determinism). Multi-hex units reserve their whole footprint when moving; collision = any footprint cell occupied.
- **Hitboxes:** targeting (`CombatTargeting.pick`) becomes footprint-aware — distance is min distance between attacker footprint and target footprint; a Horde of many small units and one Behemoth are both just "sets of cells."
- **Server-verified, deterministic.** All of the above lives in `sim/` and runs on the server. The client only replays the resulting `EventLog` (now including `UNIT_MOVED` events). No client-side pathfinding authority.

### Simulation & Testing Impact

- **This is the highest-risk feature for determinism.** Pathfinding + tie-breaking must be integer-deterministic. Add dedicated golden replays: Behemoth vs Horde, Horde vs Horde (stress collision), Behemoth blocked by obstacle (joins Feature 4). Lock event-log hashes.
- **Occupancy invariant test:** no two distinct ids share a cell; every on-board unit's footprint is fully in-bounds; `count_units()` matches distinct fielded ids. Asserted every intent in the soak.
- **Cross-process determinism** (from Phase 1) becomes critical here — pathfinding is where float/iteration-order divergence usually creeps in. Run Behemoth/Horde combats in two processes and hash-compare.

### Step-by-Step Implementation Phase (Phase 5)

1. Add `footprint` to `UnitInstance` (default single-cell) + def-registry footprint data.
2. Make `BoardState` footprint-aware (multi-key occupancy, distinct-id counting, `cells_occupied_by`).
3. Extend `IntentValidator` placement to validate full footprints.
4. Add deterministic integer pathfinding + footprint collision to combat; emit `UNIT_MOVED`.
5. Make `CombatTargeting`/hitboxes footprint-aware (min-distance between cell sets).
6. Behemoth/Horde golden replays + occupancy invariants + cross-process hash tests → CI gate.

**Depends on:** Phase 3 (paired combat). Interacts with Phase 4 (obstacles as occupied cells). Single-hex default means existing units/tests are unaffected until footprints are assigned.

---

# Feature 6 — Modular Item System (Sockets)

### Architectural Strategy

No item system exists today — `UnitInstance` ([`sim/economy/unit_instance.gd`](sim/economy/unit_instance.gd)) has `instance_id, def_id, stars, bench_slot, grid_pos` and nothing else; combat stats come purely from `def_id` via `UnitRegistry` and `CombatUnit.from_unit_instance`. We add sockets **server-side only** so the client can never spoof stats.

- **Data model:** add `sockets: Array` to `UnitInstance` (each socket holds an `item_instance_id` or null) and an `ItemInstance` (`{item_id, item_def}`) plus an `ItemRegistry` mirroring the existing `UnitRegistry`/`TraitRegistry` pattern. Add to `to_dict`/`from_dict`/`duplicate_unit` so save and snapshot keep working.
- **New intents, validated like every other action:** `EQUIP_ITEM {unit_instance_id, item_instance_id, socket_index}` and `UNEQUIP_ITEM`. Add `IntentValidator._validate_equip()` enforcing: item owned by this player, socket exists and is empty, unit owned by peer, correct phase (PLANNING only), item not already equipped elsewhere. New `RejectReason`s: `SOCKET_OCCUPIED`, `ITEM_NOT_OWNED`, `ITEM_INCOMPATIBLE`.
- **Stats are derived server-side, never sent as values.** The client sends *which item in which socket* — an intent — never a stat delta. The server recomputes combat stats from `def base_stats + Σ(item modifiers)` when building `CombatUnit` (`CombatResolver.build_combat_state`). **This is the anti-spoof guarantee:** the authoritative stat is always recomputed from `(def_id, sockets)` the server holds; a tampered client packet can at most submit an *intent* that the validator rejects. The client's displayed stats are advisory DTO values it cannot use to influence combat.
- **Replication:** equipped items appear in the player's private board/bench DTOs (so UI can render them); item modifiers fold into the stat values shown, but the source of truth is server-side recomputation at combat build time.

### Simulation & Testing Impact

- **Spoof-resistance test:** craft an intent stream that tries to (a) equip an item the player doesn't own, (b) double-equip one item, (c) equip during combat phase, (d) overfill a socket. Assert each is rejected with the right `RejectReason` and server state is unchanged — exactly the pattern `IntentValidator` tests already follow.
- **Stat-derivation golden test:** a unit with a known socket loadout produces a hash-stable `CombatUnit` stat block and a hash-stable combat `EventLog`. Add item-bearing units to `cases.json`.
- **Conservation:** items, like units, are conserved (no dupe on equip/unequip/sell). Extend the Feature 2 conservation invariant to items.

### Step-by-Step Implementation Phase (Phase 6)

1. Add `ItemRegistry` + `ItemInstance`; add `sockets` to `UnitInstance` (+ `to_dict`/`from_dict`/`duplicate_unit`).
2. Add `EQUIP_ITEM`/`UNEQUIP_ITEM` intents + `IntentValidator` rules + new `RejectReason`s.
3. Implement server-side stat recomputation in `build_combat_state` (def + item modifiers).
4. Extend DTOs to carry socket/item display data (advisory only).
5. Spoof-resistance + stat-derivation golden + item-conservation tests → CI gate.

**Depends on:** Phase 1 (validator-as-anti-cheat, server authority). Independent of combat-model changes — works on resolve-then-replay.

---

# Feature 7 — Active Player Intervention: Commander Spells (Real-Time, Mid-Combat)

> **Deliberately last.** This is the only feature that breaks the resolve-then-replay model. Everything above ships on synchronous combat; this feature replaces it with tick-streamed interruptible combat. Do it on a fully proven foundation.

### Architectural Strategy

**The hard truth about the current model:** `CombatResolver.resolve()` runs the *entire* fight to completion in one call ([`sim/combat/combat_resolver.gd`](sim/combat/combat_resolver.gd):32-57) before the client sees anything. There is **no point at which mid-combat input can enter.** Real-time spells require restructuring combat into a **server-stepped tick loop**:

- **Tick-streamed combat.** Refactor `resolve()` into `step(combat, dt)` advancing a bounded number of ticks per server frame (the loop body — act-order, attack-progress, damage — is already per-tick; we just stop running it to completion). The server runs combat for all pairings in lockstep at `TICKS_PER_SECOND = 10`, streaming each tick's `EventLog` slice to the two players in that pair.
- **Spell intents enter the existing intent pipeline.** A spell is a new `PlayerIntent` (`CAST_SPELL {spell_id, target_cell/target_id, cast_tick}`) validated by `IntentValidator` (mana/cooldown/phase=COMBAT, target legality). **Reuse of the command pattern means spells get anti-cheat for free** — the server authoritatively applies the spell's effect into the combat state at a specific tick.
- **Latency & input buffering (the core netcode problem).** Because two players can cast on the same grid "simultaneously":
  - **Server-authoritative tick scheduling.** Each cast is stamped with the server tick at which it *resolves*, not when it arrives. The server buffers incoming casts and applies them at a fixed **input delay** (e.g. resolve 2–3 ticks = 200–300ms after receipt) so all clients have time to receive and display the cast before it takes effect. This is the standard fixed-delay lockstep approach and fits the existing fixed-tick sim perfectly.
  - **Deterministic conflict resolution.** When two casts resolve on the same tick (e.g. A freezes a unit, B repositions it), order them by a deterministic key — `(resolve_tick, caster_player_id, spell_id)` — exactly mirroring the existing `_get_act_order` tie-break by `instance_id` ([`sim/combat/combat_resolver.gd`](sim/combat/combat_resolver.gd):65-69). Same machine, same order, every time. No client ever resolves conflicts locally.
  - **Mispredict handling.** Clients predict their *own* cast visually (instant feedback) but the server's tick-stamped result is authoritative; on mismatch the client snaps to the server event stream (small, because input delay keeps prediction windows short). Opponent casts are *never* predicted — they arrive on the stream.
- **Determinism preserved.** All spell effects mutate `CombatState` through the same RNG and integer math; the per-tick `EventLog` remains the replicated artifact and the golden-replay hash target. A combat with a fixed cast schedule must hash-reproduce.

### Simulation & Testing Impact

- **Cast-schedule golden replays:** encode a fixed list of `(resolve_tick, player, spell, target)` and assert the resulting tick-streamed `EventLog` is hash-stable — the same mechanism as today's golden replays, extended with a cast schedule input.
- **Simultaneous-cast determinism test:** two casts resolving on the same tick must produce identical state regardless of network arrival order (feed the same casts in both arrival orders → identical hash).
- **Headless real-time harness:** drive `step()` with scripted casts in the loopback 8-bot server; assert all pairings stay in lockstep and cross-process hashes match (this is where real-time divergence would surface).
- **Latency simulation:** the loopback harness injects artificial per-peer delay/jitter and asserts the fixed input-delay buffer still yields identical authoritative outcomes (only client-side prediction visuals differ).

### Step-by-Step Implementation Phase (Phase 7)

1. Refactor `CombatResolver.resolve()` into `step(combat, dt)` (extract the loop body; keep a `resolve()` wrapper that calls `step` to completion so **all earlier features and golden tests keep passing unchanged**).
2. Server runs all pairings via `step()` in lockstep at `TICKS_PER_SECOND`; stream per-tick `EventLog` slices.
3. Add `CAST_SPELL` intent + `IntentValidator` rules (mana/cooldown/target/phase) + spell registry.
4. Implement fixed-delay cast buffering + tick-stamped resolution + deterministic conflict ordering.
5. Add client-side prediction for own casts + snap-to-server reconciliation; opponent casts stream-only.
6. Cast-schedule golden + simultaneous-cast + latency-jitter determinism tests → CI gate.

**Depends on:** Phases 1–4 at minimum (foundation, economy, pairing, combat events). Should not start until the resolve-then-replay features are all green, because it changes the combat core they rely on.

---

## Cross-cutting principles (apply to every feature)

1. **The validator is the anti-cheat boundary.** Every new capability is a new `PlayerIntent` + `IntentValidator` rule + `RejectReason`. Clients send *intentions*, never *results*. This single principle covers item-spoofing (F6), illegal placement (F5), and spell legality (F7).
2. **The `EventLog` is the network unit for combat.** New combat behaviors (terrain destruction, movement, spells) are new *event types* replayed by the client, not new netcode. Golden replays hash the event stream, so determinism coverage extends automatically.
3. **Everything stays snapshot-able.** Any new state added to `RunState`/`BoardState`/`UnitInstance`/`CombatState` must extend its `duplicate_*()` method. Snapshotting underpins rollback, save, and replication.
4. **No floats in deterministic paths.** The RNG is integer-LCG; combat tie-breaks are by `instance_id`. Pathfinding (F5) and spell ordering (F7) must follow the same integer/ID-deterministic discipline, verified by the cross-process hash test.
5. **`RivalDirector` is retired from PvP but retained as a plug-in enemy source** for ghost rounds, PvE practice, and deterministic solo testing — it already conforms to the resolver's enemy-entry contract.

## Suggested first milestone

Ship **Phase 1 + Phase 2 + Phase 3** as the "vertical slice": 8 real players, shared contested economy, synchronized rounds, paired PvP combat on the *existing* resolve-then-replay combat with *existing* single-hex units and *no* items/spells/terrain. That is a complete, playable TFT-style core and proves the authoritative foundation before any of the riskier systems (F4–F7) are layered on.
