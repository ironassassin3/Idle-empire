"""Economy curve analysis: payback time per building tier, and whether
the cost/income curves keep tiers relevant."""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy"); os.environ.setdefault("SDL_AUDIODRIVER","dummy")
import pygame; pygame.init(); pygame.display.set_mode((900,720))
import src.buildings as bld
import src.theme as theme

def f(n): return theme.format_number(n)

builds = bld.make_buildings()
print(f"{'Building':22s}{'base_cost':>12}{'base_inc':>10}{'scale':>7}{'payback@1':>11}{'inc/cost':>10}")
print("-"*82)
for b in builds:
    payback = b.base_cost / b.base_income if b.base_income else float('inf')  # seconds to recoup first unit
    ratio = b.base_income / b.base_cost
    print(f"{b.name:22s}{f(b.base_cost):>12}{f(b.base_income):>10}{b.cost_scale:>7.2f}"
          f"{payback:>10.0f}s{ratio:>10.5f}")

print()
print("Cost to own 25 of each (from 0):")
for b in builds:
    print(f"  {b.name:22s}: {f(b.cost_for_n(25))}  -> income {f(b.base_income*25)}/s")

print()
print("Income-per-dollar ranking (higher = better value at equal owned):")
ranked = sorted(builds, key=lambda b: b.base_income/b.base_cost, reverse=True)
for b in ranked:
    print(f"  {b.name:22s}: {b.base_income/b.base_cost:.6f} inc/$")
