# Changelog — Syndicate Skirmish (Turf Autobattler)

## Unreleased — autobattler balance, content & metagame pass (2026-06-28)

A self-paced session that took the vertical slice from "technically runnable but
**unwinnable** (win_rate 0.00, brain-dead baseline)" to a **winnable, balanced,
feature-complete v1** (competent-baseline win_rate ~0.76, snappy combat, full
trait coverage, shop odds, streak econ, 11 units, and a working meta-progression
loop). Every change was gated through `tools/publish_pass.ps1 smoke` (golden
replays + sim soak) and validated with the headless runner.

### Combat & balance (`sim/combat/`, `sim/`)
- **Stalemate tiebreak** (`combat_resolver.gd`): tick-cap fights now resolve by
  survivors → total remaining HP instead of a flat draw-as-loss. Fixed fights the
  player was winning being counted as losses.
- **Enemy scale cap** (`combat_resolver.gd`, `MAX_ENEMY_SCALE = 1.45`): the
  per-round enemy stat ramp (`1 + 0.05·(round−1)`) is capped so a strong end-game
  board can actually win the final rounds. Uncapped, round 15 hit ×1.70 and even
  an over-leveled board lost 100%.
- **Stall-resolve** (`combat_resolver.gd`, `STALL_RESOLVE_TICK = 300`): grindy
  fights resolve at tick 300 via the tiebreak instead of dragging to 600 — late
  combat playback dropped from ~488 to ~293 ticks (~49s → ~29s) with no draws.

### Content — units & traits (`data/`)
- **New Street trait** (`trait_registry.gd` + `trait_calculator.gd`
  `max_hp_bonus`): the most common tag (`street`, 4+ units) previously had no
  synergy. Now all four tags map to a distinct trait — Enforcer (armor), Fixer
  (heal), Smuggler (attack speed), Street (toughness).
- **Three new units** (`unit_registry.gd`, roster 8 → 11): **Dealer** (T1
  Smuggler), **Thug** (T1 Enforcer/Street), **Lawyer** (T1 Fixer). Every trait now
  has a tier-1 entry, so any synergy can be started early; completes the Smuggler
  3-piece (previously unreachable).
- **Softened opening** (`rival_comp_registry.gd`): rounds 1–2 eased into a
  1 → 2 → 3 unit ramp so the opening isn't unwinnable by construction.
- **Final-comp fix** (`rival_comp_registry.gd`): the round-14+ comp's 6th unit is
  a Runner, not a 4th enforcer-tag — removes an unintended Enforcer 4-piece
  (+60 armor) spike that made the finale unbreakable.

### Economy (`sim/economy/`)
- **Shop odds by level** (`shop_pool.gd`): TFT-style per-level tier-rarity table —
  leveling now shifts the roll toward stronger units (tier-3 10%→55% across
  levels), not just board cap. Makes "level for power" a real decision.
- **Loss-streak gold** (`economy_rules.gd`): cold streaks now pay a comeback bonus
  mirroring the win-streak bonus (capped +3/round).

### Metagame (`sim/metagame/`, `sim/run/`, `presentation/`)
- **Meta-unlock sink** (`metagame_rules.gd`): Street Cred was earn-only with a
  dead `unlocks` array. Added a catalog of permanent perks (War Chest +3 gold,
  Old Connections +4 XP, Kingpin Seed +6 gold) with `can_purchase` / `purchase` /
  `starting_bonuses`. Run-start bonuses applied via `RunDirector.start_run`
  (optional param, default no-op) and threaded through `RunBridge`.
- **Meta-shop UI** (`main_menu.tscn` / `main_menu.gd`): a "Hideout Upgrades"
  section generating a purchase button per unlock, with cost/owned/affordability
  states, persisted on buy via `SaveStore`.

### Tooling (`tools/`)
- **Headless runner upgrades** (`headless_main.gd`): added `avg_round` /
  `max_round` and a `--per-round` diagnostics table (win%, level, board vs enemy
  size, gold, draws). Upgraded the auto-player from a brain-dead baseline to a
  **competent player** (TFT-style leveling incl. level-for-odds, reroll/tier-greedy
  buying, sell-surplus, keep-best row-spread placement) so win-rate numbers
  reflect real play.

### Tests
- Regenerated two golden hashes (`tests/golden_replays/cases.json`) for
  intentional combat changes: `enforcer_fixer_vs_two_boys` (Street trait on the
  enemy 2-corner-boy comp) and `heavy_vs_medic_runner` (now resolves at the stall
  point). Each was predicted and verified; the third fixture is unchanged.

### Known gaps / not verified autonomously
- **Meta-shop UI** is compile- and scene-load-clean, but visual layout and click
  behavior were **not** verified (no headless way to drive the real UI) — needs a
  hands-on check.
- **Version control**: `turf_autobattler/` is still entirely untracked in git.
  This whole body of work is uncommitted.
- Unchanged from prior state: Android export still blocked; store/compliance and
  step-11+ presentation polish still outstanding.
