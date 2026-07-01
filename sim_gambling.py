"""
Luck Wheel EV validation — balance lab for the active gambling feature.

The gambling feature ships in Godot (scripts/systems/gambling_system.gd). Its
payoff math is pure, so we mirror the constants here and answer:

  1. Per-spin EV by player skill (random vs skilled vs bot).
  2. Daily-income contribution vs offline cap and daily login reward.
  3. Guardrail PASS/FAIL for login (2 spins) and login+ad (3 spins) scenarios.

Skill model: the segments are drawn statically and the needle sweeps, so a
skilled player can *aim* at the gold 10x band. The only thing stopping a lock is
timing jitter. We model the stop as: aim at the best segment's center, add
Gaussian timing error (ms) -> position error = SWEEP_SPEED * error. A pure random
tapper (no aim) gets a uniform stop.

KEEP IN SYNC with gambling_system.gd if the ring or tuning changes.
No balance is changed here — measurement only.
"""
from __future__ import annotations
import argparse
import random
import statistics

# --- Mirror of gambling_system.gd ------------------------------------------
SEGMENT_MULTS = [
    0.0, 0.5, 1.5, 0.0, 1.0, 0.5, 2.0, 0.0,
    1.0, 0.5, 1.5, 0.0, 1.0, 0.5, 2.0, 10.0,
]
JACKPOT_MULT = 10.0
BASE_INCOME_SECONDS = 90.0
BASE_MIN_ABSOLUTE = 50.0
SWEEP_SPEED = 1.85
DAILY_FREE_SPINS = 1
STREAK_BONUS_THRESHOLD = 7
STREAK_BONUS_SPINS = 1
FREE_SPIN_CAP = 5
WELCOME_FREE_SPINS = 1

# GameState._apply_daily_reward: max(cheapest*3, income * 300s * streak)
DAILY_REWARD_INCOME_SECONDS = 300.0

OFFLINE_CAP_HOURS = 12.0
GUARDRAIL_FRACTION = 0.05

SKILL_PROFILES = [
    ("random tap (no aim)", None),
    ("aim · 250ms jitter (casual)", 250.0),
    ("aim · 150ms jitter (decent)", 150.0),
    ("aim · 100ms jitter (skilled)", 100.0),
    ("aim ·  60ms jitter (expert)", 60.0),
    ("aim ·   0ms jitter (bot)", 0.0),
]

DAILY_SCENARIOS = [
    ("login max streak (2 spins/day, no ad)", DAILY_FREE_SPINS + STREAK_BONUS_SPINS),
    ("login sub-max + ad (2 spins/day)", DAILY_FREE_SPINS + 1),
]


def simulate_spin(rng: random.Random, jitter_ms: float | None,
                  sweep_speed: float = SWEEP_SPEED) -> float:
    """Return the multiplier won for one spin."""
    n = len(SEGMENT_MULTS)
    segs = SEGMENT_MULTS[:]
    rng.shuffle(segs)
    if jitter_ms is None:
        idx = rng.randrange(n)
        return segs[idx]
    best_idx = max(range(n), key=lambda i: segs[i])
    target = (best_idx + 0.5) / n
    pos_err = sweep_speed * (jitter_ms / 1000.0)
    stop = (target + rng.gauss(0.0, pos_err)) % 1.0
    idx = min(int(stop * n), n - 1)
    return segs[idx]


def run_profile(label: str, jitter_ms: float | None, spins: int,
                sweep_speed: float, seed: int) -> dict:
    rng = random.Random(seed)
    mults = [simulate_spin(rng, jitter_ms, sweep_speed) for _ in range(spins)]
    ev = statistics.fmean(mults)
    return {
        "label": label,
        "ev": ev,
        "median": statistics.median(mults),
        "p_jackpot": sum(1 for m in mults if m >= JACKPOT_MULT) / spins,
        "p_bust": sum(1 for m in mults if m <= 0.0) / spins,
        "income_seconds": ev * BASE_INCOME_SECONDS,
    }


def _guardrail_verdict(worst_frac: float) -> str:
    if worst_frac < GUARDRAIL_FRACTION:
        return "PASS"
    return "FAIL"


def print_daily_scenarios(results: list[dict], compare_daily_reward: bool) -> None:
    daily_cap_seconds = OFFLINE_CAP_HOURS * 3600.0
    for scenario_label, daily_spins in DAILY_SCENARIOS:
        print("\nDaily-income contribution — %s vs %gh offline cap:"
              % (scenario_label, OFFLINE_CAP_HOURS))
        print("%-30s %12s %10s %8s" % ("profile", "spin income", "% of day", "guard"))
        print("-" * 66)
        worst = 0.0
        for r in results:
            daily = daily_spins * r["income_seconds"]
            frac = daily / daily_cap_seconds
            worst = max(worst, frac)
            print("%-30s %10.0fs %9.2f%% %8s"
                  % (r["label"], daily, frac * 100,
                     _guardrail_verdict(frac) if "bot" in r["label"] else ""))
        verdict = _guardrail_verdict(worst)
        print("  Scenario worst case (bot): %.2f%% — %s (< %g%% guardrail)"
              % (worst * 100, verdict, GUARDRAIL_FRACTION * 100))

    if not compare_daily_reward:
        return

    skilled = next(r for r in results if "skilled" in r["label"])
    random_r = results[0]
    print("\nVs daily login reward (income × %gs × streak, 2 spins/day):"
          % DAILY_REWARD_INCOME_SECONDS)
    print("%-8s %-30s %12s %10s" % ("streak", "profile", "gamble/day", "% of daily"))
    print("-" * 64)
    for streak in (1, 7):
        daily_reward_secs = DAILY_REWARD_INCOME_SECONDS * streak
        for r in (random_r, skilled):
            gamble_secs = (DAILY_FREE_SPINS + STREAK_BONUS_SPINS) * r["income_seconds"]
            frac = gamble_secs / daily_reward_secs if daily_reward_secs > 0 else 0.0
            print("%-8d %-30s %10.0fs %9.1f%%"
                  % (streak, r["label"], gamble_secs, frac * 100))


def main() -> None:
    ap = argparse.ArgumentParser(description="Luck Wheel EV validation")
    ap.add_argument("--spins", type=int, default=500_000,
                    help="spins per skill profile (default 500k)")
    ap.add_argument("--sweep-speed", type=float, default=SWEEP_SPEED,
                    help="needle speed in bars/sec (tuning sensitivity)")
    ap.add_argument("--compare-daily-reward", action="store_true",
                    help="also compare 2-spin/day income vs daily login reward")
    ap.add_argument("--seed", type=int, default=1234)
    args = ap.parse_args()

    print("Luck Wheel EV — ring mean = %.3fx over %d segments (jackpot %gx)"
          % (statistics.fmean(SEGMENT_MULTS), len(SEGMENT_MULTS), JACKPOT_MULT))
    print("base stake = %g s of income/spin · sweep = %.2f bars/s · cap = %d banked"
          % (BASE_INCOME_SECONDS, args.sweep_speed, FREE_SPIN_CAP))
    print("daily grant = %d (+ %d at streak %d+) · welcome = %d (one-time)\n"
          % (DAILY_FREE_SPINS, STREAK_BONUS_SPINS, STREAK_BONUS_THRESHOLD,
             WELCOME_FREE_SPINS))

    print("%-30s %8s %8s %8s %8s %10s"
          % ("profile", "EV(x)", "median", "P(10x)", "P(bust)", "income"))
    print("-" * 78)
    results = []
    for label, jit in SKILL_PROFILES:
        r = run_profile(label, jit, args.spins, args.sweep_speed, args.seed)
        results.append(r)
        print("%-30s %8.2f %8.1f %7.1f%% %7.1f%% %8.0fs"
              % (label, r["ev"], r["median"], r["p_jackpot"] * 100,
                 r["p_bust"] * 100, r["income_seconds"]))

    print_daily_scenarios(results, args.compare_daily_reward)

    print("\nVERDICT")
    bot = next(r for r in results if "bot" in r["label"])
    skilled = next(r for r in results if "skilled" in r["label"])
    print("  • Per-spin EV: random %.2fx, skilled %.2fx, perfect %.2fx."
          % (results[0]["ev"], skilled["ev"], bot["ev"]))
    target_note = "ABOVE" if results[0]["ev"] > 1.15 else "near"
    print("    Random EV is %s the doc's ~1.0x target (ring mean %.2fx)."
          % (target_note, statistics.fmean(SEGMENT_MULTS)))
    daily_cap_seconds = OFFLINE_CAP_HOURS * 3600.0
    spins_login = DAILY_SCENARIOS[0][1]
    spins_ad = DAILY_SCENARIOS[1][1]
    bot_frac_2 = (spins_login * bot["income_seconds"]) / daily_cap_seconds
    bot_frac_3 = (spins_ad * bot["income_seconds"]) / daily_cap_seconds
    if bot_frac_2 < GUARDRAIL_FRACTION:
        print("  • 2-spin login scenario PASSES (bot worst %.2f%% < %g%%)."
              % (bot_frac_2 * 100, GUARDRAIL_FRACTION * 100))
    else:
        print("  • 2-spin login scenario FAILS (bot %.2f%%)." % (bot_frac_2 * 100))
    if bot_frac_3 >= GUARDRAIL_FRACTION:
        print("  • 3-spin (+ad) bot case %.2f%% — should not occur (ad blocked at streak %d+)."
              % (bot_frac_3 * 100, STREAK_BONUS_THRESHOLD))
    else:
        print("  • Sub-max login + ad PASSES (bot %.2f%%)."
              % (bot_frac_3 * 100))
    if skilled["ev"] > 2.5 * results[0]["ev"]:
        print("  • Skill spread is wide (skilled >> random). Raise SWEEP_SPEED to flatten.")


if __name__ == "__main__":
    main()
