"""Phase 30 Part 4 — Prestige Mastery interaction with the new soft cap, plus
Part 7 numeric safety checks."""
import math
import src.prestige as prestige

NEW = prestige.income_mult
PM = lambda t: 1.0 + t * 0.10   # states.py:223 — Prestige Mastery, if purchased

print("PART 4 — Prestige Mastery (PM) on top of the new soft cap")
print(f"{'tok':>6} | {'base':>9} | {'PM factor':>10} | {'base*PM':>12} | {'PM/base':>8}")
for t in [25, 50, 100, 250, 500, 1000, 2000, 5000]:
    b = NEW(t)
    pm = PM(t)
    print(f"{t:>6} | {b:>9.2f} | {pm:>10.1f} | {b*pm:>12.1f} | {pm/b:>8.2f}")

# Effective growth exponent of base*PM:  t^0.9 * t^1 ~ t^1.9 (near-quadratic)
print("\nEffective combined growth (base*PM) vs pure base:")
for t in [100, 1000]:
    print(f"  t={t}: base alpha~0.9 ; base*PM behaves ~ t^1.9 (near-quadratic, super-linear)")

print("\nPART 7 — numeric safety")
checks = []
checks.append(("mult(0) == 1.0", abs(NEW(0) - 1.0) < 1e-12))
checks.append(("mult(-5) == 1.0 (clamped, no NaN)", abs(NEW(-5) - 1.0) < 1e-12 and not math.isnan(NEW(-5))))
checks.append(("monotonic 0..5000", all(NEW(t) <= NEW(t+1) for t in range(0, 5000))))
big = NEW(10_000_000)
checks.append(("no overflow at 10M tokens", math.isfinite(big)))
checks.append(("positive everywhere", all(NEW(t) > 0 for t in [0, 1, 10, 100, 10000, 10_000_000])))
checks.append(("no NaN at extreme", math.isfinite(NEW(2_000_000_000))))
for name, ok in checks:
    print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
print(f"  value at 10,000,000 tokens: {big:,.1f}x (finite, no overflow)")
