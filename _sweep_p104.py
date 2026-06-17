"""Phase 104 tuning sweep — finds balance knobs closest to targets."""
from __future__ import annotations

import copy
import importlib

import config
import src.buildings as bld_mod

from _measure_p104 import PROFILES, run_profile, score_results, print_report

# Snapshot originals
_ORIG = {
    "CLICK_DEALER_BONUS": config.CLICK_DEALER_BONUS,
    "CLICK_IPS_FRACTION": config.CLICK_IPS_FRACTION,
    "CLICK_HUSTLE_MULT": config.CLICK_HUSTLE_MULT,
    "BUILDING_DEFS": copy.deepcopy(bld_mod._DEFS),
}


def apply_tuning(dealer, ips_frac, hustle_mult, income_scale_early):
    config.CLICK_DEALER_BONUS = dealer
    config.CLICK_IPS_FRACTION = ips_frac
    config.CLICK_HUSTLE_MULT = hustle_mult
    defs = copy.deepcopy(_ORIG["BUILDING_DEFS"])
    for i in range(min(4, len(defs))):
        row = list(defs[i])
        row[2] = row[2] * income_scale_early
        defs[i] = tuple(row)
    bld_mod._DEFS = defs


def restore():
    config.CLICK_DEALER_BONUS = _ORIG["CLICK_DEALER_BONUS"]
    config.CLICK_IPS_FRACTION = _ORIG["CLICK_IPS_FRACTION"]
    config.CLICK_HUSTLE_MULT = _ORIG["CLICK_HUSTLE_MULT"]
    bld_mod._DEFS = copy.deepcopy(_ORIG["BUILDING_DEFS"])
    importlib.reload(bld_mod)


CANDIDATES = [
    (0.20, 0.010, 2.50, 1.00),  # baseline
    (0.12, 0.012, 2.35, 1.10),
    (0.10, 0.015, 2.35, 1.10),
    (0.10, 0.018, 2.35, 1.10),
    (0.10, 0.020, 2.30, 1.10),
    (0.12, 0.016, 2.35, 1.10),
    (0.12, 0.018, 2.35, 1.08),
    (0.10, 0.055, 2.35, 1.10),
    (0.10, 0.050, 2.35, 1.10),
    (0.12, 0.045, 2.35, 1.10),
]


def main():
    best = None
    rows = []
    for cand in CANDIDATES:
        restore()
        apply_tuning(*cand)
        results = [run_profile(n, max_min=75) for n in PROFILES]
        sc = score_results(results)
        engaged = next(r for r in results if r["profile"] == "ENGAGED")
        row = {
            "cand": cand,
            "score": sc,
            "eng_10": engaged["snaps"].get(600, {}).get("click_pct"),
            "eng_20": engaged["snaps"].get(1200, {}).get("click_pct"),
            "eng_prestige_click": engaged["final"]["click_pct"],
            "eng_prestige_t": engaged["first_prestige"],
            "results": results,
        }
        rows.append(row)
        if best is None or sc < best["score"]:
            best = row
        print(
            f"dealer={cand[0]:.2f} ips={cand[1]:.3f} hustle={cand[2]:.2f} "
            f"inc×{cand[3]:.2f}  score={sc:6.1f}  "
            f"eng10={row['eng_10']:.0f}% eng20={row['eng_20']:.0f}% "
            f"prest={row['eng_prestige_click']:.0f}% @{row['eng_prestige_t']//60 if row['eng_prestige_t'] else 0}m"
        )

    restore()
    if best:
        apply_tuning(*best["cand"])
        print_report(best["results"], f"BEST candidate {best['cand']} score={best['score']:.1f}")
    restore()


if __name__ == "__main__":
    main()
