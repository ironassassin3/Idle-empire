# Handoff — Multiplayer Pivot, Phase 1 (Networking Foundation)

**Paste the section below into a fresh session to continue.** Context, the seam audit result, and the exact build order are all included so the next session does not repeat discovery work.

---

## Prompt for next session

You are an expert game systems architect and Godot multiplayer engineer working on **`D:\2d_game\turf_autobattler`** (Godot 4.3, GL Compatibility). We are pivoting a 2D autobattler from single-player PvE (scripted `RivalDirector` comps) to a **live 8-player PvP TFT-style game with an authoritative server**, reusing the existing headless sim and deterministic combat resolver.

The full architecture plan is in [`MULTIPLAYER_AUTOBATTLER_ROADMAP.md`](MULTIPLAYER_AUTOBATTLER_ROADMAP.md) — read it first. **Phase 1 (Networking Foundation) must be completed before any gameplay feature.** Your job is to begin implementing Phase 1.

### Already verified (do not re-audit — confirmed in the prior session)

- **The sim/presentation seam is clean.** `sim/**` has zero `Node` coupling: no `extends Node`, `get_tree`, `get_node`, `preload`, `Input/OS/Engine`, or `res://presentation` references. Moving `RunDirector` server-side is a refactor, not a rewrite.
- **`EventLog.emit(type, payload)`** is a plain `RefCounted` data-log method (NOT a Godot signal). It is the serializable replication artifact for combat. No `signal` declarations exist in `sim/`.
- **Data registries are static `RefCounted` classes, not autoloads** (`UnitRegistry`, `TraitRegistry`, `RivalCompRegistry`) — the server calls them directly, no bootstrapping needed.
- **The only autoloads are presentation-side** (`RunBridge`, `AudioDirector`, `SaveStore` in `presentation/autoload/`). `RunBridge` is the one we convert into a network façade.

### Key existing classes you will build on

- [`sim/run/run_director.gd`](sim/run/run_director.gd) — `submit_intent(PlayerIntent) -> RejectReason`. The single state-mutation choke point. This becomes the server's per-player authority object.
- [`sim/run/intent_validator.gd`](sim/run/intent_validator.gd) — pure validation, returns `SimConstants.RejectReason`. **This is the anti-cheat boundary.** Every new capability = new intent + new validator rule + new reject reason.
- [`sim/run/player_intent.gd`](sim/run/player_intent.gd) — `{type: String, params: Dictionary}`. Already trivially serializable → the wire format for client→server.
- [`sim/run/run_state.gd`](sim/run/run_state.gd) — per-player state with `duplicate_state()` (snapshot/rollback ready). **Note:** `shop_pool` must be lifted out to a shared server-owned pool (Phase 2), so design `RunState` ownership accordingly now.
- [`sim/economy/shop_pool.gd`](sim/economy/shop_pool.gd) — shared-pool target. Roll is now TFT tier-weighted (`TIER_ODDS_BY_LEVEL`), deterministic (sorted keys + single `rng.next_int`).
- [`sim/core/rng.gd`](sim/core/rng.gd) — integer LCG with `get_state`/`set_state`. Derive per-player RNG as `match_seed XOR player_id`.
- [`presentation/autoload/run_bridge.gd`](presentation/autoload/run_bridge.gd) — owns the `RunDirector` and all DTO builders (`get_run_dto`, `get_shop_dto`, `get_bench_dto`, `get_board_dto`, `get_trait_dto`). Reuse these DTOs as the replication payload; convert this file into a network façade preserving its existing signals (`state_changed`, `phase_changed`, `combat_event`, `run_ended`).
- [`tools/headless_main.gd`](tools/headless_main.gd) — existing headless harness + `_test_golden_replays()` (hashes the combat `EventLog`). Extend, don't replace.

### Phase 1 build order (strictly ordered)

1. **`server/lobby_state.gd`** — lifecycle state machine (`LOBBY_WAITING → LOBBY_LOCKED → MATCH_RUNNING → MATCH_ENDED`) + `match_seed` derivation. Pure sim (`RefCounted`), snapshot-able, headless-unit-tested. No transport yet.
2. **`server/match_server.gd`** — headless `SceneTree` (launch like `tools/headless_main.tscn`). Owns `Dictionary<peer_id, RunDirector>` + shared singletons (shop pool placeholder, round clock, RNG). `ENetMultiplayerPeer` dedicated-server mode; server is authority (peer 1), clients 2–9.
3. **Wire DTOs + RPC surface** — `submit_intent_rpc(type, params)` (`@rpc("any_peer","call_remote","reliable")`); `replicate_private_state` (per-player DTOs); `replicate_lobby_state` (`LobbyStateDTO`: round, phase, timer, HP ladder, alive set, per-tier pool `remaining`).
4. **Peer-ownership validation** — add `RejectReason.NOT_YOUR_BOARD`; an intent is only valid for the `RunDirector` owned by the sending peer.
5. **Convert `run_bridge.gd` to a network façade** — same signals; `submit_intent()` sends the RPC and applies received DTOs instead of calling a local `RunDirector`. Single-player becomes "loopback server with one peer."
6. **Loopback 8-bot headless harness** — spin up `match_server.gd` + 8 scripted bot clients (reuse `_auto_buy_and_place()` AI) over in-process loopback. Assert an 8-bot match runs to completion deterministically for a fixed match seed.
7. **Cross-process determinism test** — same seed in two headless processes → identical final `LobbyStateDTO` + per-player board hashes. Wire golden replays + loopback determinism into a **CI gate**.

### Non-negotiable invariants (verify after every step)

- **Clients send intents, never results.** All authority is server-side via `submit_intent` + `IntentValidator`.
- **No floats in deterministic paths.** RNG is integer-LCG; combat tie-breaks by `instance_id`. Any new ordering must be integer/ID-deterministic.
- **`EventLog` is the network unit for combat** — replicate the log, not frames.
- **Everything stays snapshot-able** — extend `duplicate_*()` for any new state.
- **Golden replays must stay green** (`_test_golden_replays()` hash-stable) throughout. Do not change combat math in Phase 1.
- Keep `RivalDirector` working as a pluggable PvE/ghost enemy source (needed in Phase 3, useful for solo testing now).

### Exit criteria for Phase 1

8 bot clients complete a full match over ENet loopback, deterministically, with all state authoritative on the server and the existing UI driven only by replicated DTOs. Then the first playable milestone is **Phase 1 + 2 + 3** (8 real players, shared contested economy, synchronized paired rounds) on the existing resolve-then-replay combat — no spells/items/terrain yet.

**Start with step 1 (`server/lobby_state.gd`).** Implement and headless-test it before moving on.
