extends Node
## Mirrors config.py — tuning constants for the GDScript port.

const VERSION := "v1.0.0"
const DESIGN_WIDTH := 900
const DESIGN_HEIGHT := 720
const FPS := 60

const CLICK_IPS_FRACTION := 0.055
const CLICK_DEALER_BONUS := 0.10
const CLICK_CRIT_CHANCE := 0.05
const CLICK_CRIT_MIN := 2.0
const CLICK_CRIT_MAX := 8.0
const CLICK_HUSTLE_WINDOW := 2.0
const CLICK_HUSTLE_CLICKS := 8
const CLICK_HUSTLE_DURATION := 6.0
const CLICK_HUSTLE_MULT := 2.35

# Prestige pacing (2026-07-28 lab pass): P1 ~40–60m engaged in pygame sims;
# device pass saw ~19m at 50M / soft POST rebuild — raise earnings, kill the
# POST discount, scale rebuild with prestige_count, and IPS-floor the next gate
# (see Prestige.next_earnings_gate / post_building_required).
const FIRST_PRESTIGE_EARNINGS := 120_000_000.0
const FIRST_PRESTIGE_DEALERS := 25
const FIRST_PRESTIGE_RACKETS := 10
const FIRST_PRESTIGE_CHOPS := 5
const FIRST_PRESTIGE_RANK := "Made Man"
# Base rebuild counts (no longer discounted vs first). Scaled up per cycle in Prestige.
const POST_PRESTIGE_DEALERS := 25
const POST_PRESTIGE_RACKETS := 10
const POST_PRESTIGE_CHOPS := 5
const PRESTIGE_EARNINGS_GROWTH := 12.0
# next_gate = max(prev * GROWTH, ips * PACING_SECS * income_mult * SNOWBALL_PAD)
const PRESTIGE_PACING_SECS := 1500.0  # 25 min at prestige-time IPS
const PRESTIGE_SNOWBALL_PAD := 6.0  # climb IPS grows far past prestige-time IPS
const PRESTIGE_REBUILD_SCALE_PER := 0.5  # need = FIRST * (1 + scale * prestige_count)

# Turf bonuses ramp with empire-route progress; cubic + cap slows turf snowball.
const TERRITORY_ECONOMY_SCALE_EXPONENT := 3.0
const TERRITORY_ECONOMY_SCALE_MAX := 0.30
const TERRITORY_INCOME_BONUS_CAP := 0.18

const MANAGER_INCOME_MULT := 1.5
# Manager purchase orders (Accountant, Mechanic) unlock after first prestige.
# Full silent auto-buy remains a prestige perk choice (Talent Scout / Monopoly).
const MANAGER_AUTOBUY_REQUIRES_PRESTIGE := true
const MANAGER_AUTOBUY_MIN_PRESTIGE_COUNT := 1
const AUTOSAVE_INTERVAL := 30.0
const OFFLINE_CAP_HOURS := 12.0
const OFFLINE_EFFICIENCY := 0.6
const SHOW_PARTICLES := true

# Gambling (Luck Wheel) — skill/timing minigame; daily-spin engagement hook.
# All tuning knobs live in scripts/systems/gambling_system.gd (single source of
# truth; mirrored in sim_gambling.py). This flag gates the whole feature.
const GAMBLING_ENABLED := true

# P14 rustic noir — procedural bake at startup; set false to force flat StyleBoxFlat UI.
const UI_RUSTIC_THEME := false
# P15 city-first layout — skyline viewport replaces left column stack.
const UI_CITY_V2 := true
# P15.7 rollback — false hides CityViewport and restores compact status strip (dev-only P14 fallback).
const UI_CITY_VIEW := true
# Stage & Ledger overhaul (docs/ui/UI_OVERHAUL_ARCHITECTURE.md) — full-bleed city
# stage, single content sheet, attention rail, 2-band chrome (game_shell.tscn).
# False = legacy strip shell (game_screen.tscn).
const UI_SHELL_V3 := true
