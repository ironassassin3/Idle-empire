"""Phase 110 — manager acquisition audit helpers (measurement only).

Estimates when milestone-based unlocks would fire vs when greedy play
first affords each manager in cash. Writes timing table to stdout;
PHASE110_REPORT.md is authored from these numbers + design analysis.
"""
from __future__ import annotations

import _measure_p105 as h
import src.managers as mgr_mod
import src.prestige as prestige
from src.state_base import StateManager
from src.states import PlayingState


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


# Proposed unlock conditions (audit candidates — not implemented)
UNLOCK_CHECKS = [
    ("Sticky Pete",      lambda s: s.lifetime_earnings >= 25_000),
    ("Lucky Sal",        lambda s: getattr(s, '_coins_caught', 0) >= 1),
    ("The Collector",    lambda s: s.buildings[1].owned >= 3 if len(s.buildings) > 1 else False),
    ("The Mechanic",     lambda s: s.buildings[2].owned >= 2 if len(s.buildings) > 2 else False),
    ("The Accountant",   lambda s: sum(b.owned > 0 for b in s.buildings) >= 4),
    ("Clean Carl",       lambda s: getattr(s, 'heat', 0) >= 40.0),
]


def run_profile(name: str, *, max_min: int = 90, seed: int = 110) -> dict:
    import random
    random.seed(seed + hash(name) % 1000)
    profile = h.PROFILES[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    unlock_times: dict[str, float | None] = {n: None for n, _ in UNLOCK_CHECKS}
    afford_times: dict[str, float | None] = {n: None for n, _ in UNLOCK_CHECKS}
    hire_times: dict[str, float | None] = {n: None for n, _ in UNLOCK_CHECKS}

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ps.update(dt)
        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        for mname, check in UNLOCK_CHECKS:
            if unlock_times[mname] is None and check(ps):
                unlock_times[mname] = t

        for m in ps.managers:
            if m.name not in afford_times:
                continue
            if afford_times[m.name] is None and ps.balance >= m.cost:
                afford_times[m.name] = t
            if hire_times[m.name] is None and m.hired:
                hire_times[m.name] = t

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1
        import src.upgrades as upg
        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)
        for m in ps.managers:
            if not m.hired and ps.balance >= m.cost:
                ps.balance -= m.cost
                m.hired = True
                if m.name in hire_times and hire_times[m.name] is None:
                    hire_times[m.name] = t

        if prestige.can_prestige(ps):
            break
        t += dt

    return {
        "profile": name,
        "prestige": t,
        "unlock": unlock_times,
        "afford": afford_times,
        "hire": hire_times,
    }


def main() -> None:
    print("Phase 110 — milestone vs cash timing (greedy buyer)\n")
    print(f"{'Manager':<18} | {'Profile':<9} | {'Unlock':>8} | {'Afford$':>8} | {'Hired':>8}")
    print("-" * 60)
    for pname in h.PROFILES:
        r = run_profile(pname)
        for mname, _ in UNLOCK_CHECKS:
            print(
                f"{mname:<18} | {pname:<9} | "
                f"{_fmt_t(r['unlock'][mname]):>8} | "
                f"{_fmt_t(r['afford'].get(mname)):>8} | "
                f"{_fmt_t(r['hire'].get(mname)):>8}"
            )
        print()


if __name__ == "__main__":
    main()
