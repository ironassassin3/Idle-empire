"""Project the lifetime-earnings curve (time to $1M/$10M/$100M/$1B) with and
without upgrades. Originally written to quantify the OLD deadlock-escape time;
the deadlock is fixed (Session 1), so this now serves as a general long-run
economy-pacing check."""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame
pygame.init(); pygame.display.set_mode((900, 720))

from sim_harness import SimState, _best_value_building, _buy_affordable_upgrades, fmt_money
import src.heat as heat_mod
import src.buildings as bld
import src.prestige as prestige


def run(allow_upgrades, label, max_hours=12):
    s = SimState(seed=7)
    t = 0.0; dt = 1.0
    targets = [1e6, 1e7, 1e8, 1e9]
    hit = {}
    while t < max_hours * 3600:
        ips = s.income_per_second
        s.balance += ips * dt; s.lifetime_earnings += ips * dt
        s._time += dt
        # light clicking first 20 min
        if t < 1200:
            for _ in range(3):
                cv = s.click_value; s.balance += cv; s.lifetime_earnings += cv
        heat_mod.update_heat(s, dt); bld.update_building_specials(s, dt)
        for _ in range(300):
            b = _best_value_building(s)
            if not b: break
            c = b.current_cost
            if s.balance < c: break
            s.balance -= c; b.owned += 1
        if allow_upgrades:
            _buy_affordable_upgrades(s)
        for tg in targets:
            if s.lifetime_earnings >= tg and tg not in hit:
                hit[tg] = t
        t += dt
    print(f"\n{label}:")
    for tg in targets:
        ht = hit.get(tg)
        ts = f"{int(ht//3600)}h{int((ht%3600)//60)}m" if ht else "NEVER(>%dh)" % max_hours
        print(f"  ${fmt_money(tg):>6} lifetime: {ts}")
    print(f"  final lifetime @ {max_hours}h: {fmt_money(s.lifetime_earnings)}  "
          f"income/s={fmt_money(s.income_per_second)}  buildings={sum(b.owned for b in s.buildings)}")


print("=" * 60)
print("LONG-RUN LIFETIME-EARNINGS PROJECTION (economy pacing)")
print("Deadlock is fixed; this tracks how fast the curve scales.")
print("=" * 60)
run(True,  "WITH upgrades (upgrades now reachable from the start)")
run(False, "WITHOUT upgrades (passive-only floor)")
