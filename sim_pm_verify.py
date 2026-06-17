"""Phase 31 — verify the SHIPPED prestige_mastery_mult and safety."""
import math
import src.prestige as prestige

PM = prestige.prestige_mastery_mult
BASE = prestige.income_mult

print("SHIPPED Prestige Mastery (B: asymptotic, live from src.prestige):")
print(f"{'tok':>6} | {'base':>9} | {'PM':>8} | {'base*PM':>10} | {'PM share%':>9}")
for t in [0, 25, 50, 100, 250, 500, 1000, 2000, 5000]:
    b, f = BASE(t), PM(t)
    fin = b * f
    share = (math.log(f) / math.log(fin) * 100) if fin > 1 else 0.0
    print(f"{t:>6} | {b:>9.2f} | {f:>8.3f} | {fin:>10.1f} | {share:>8.1f}%")

print("\nSafety:")
for name, ok in [
    ("PM(0)==1.0", abs(PM(0)-1.0) < 1e-12),
    ("PM(-9)==1.0 clamp, no NaN", abs(PM(-9)-1.0) < 1e-12 and math.isfinite(PM(-9))),
    ("monotonic 0..5000", all(PM(t) <= PM(t+1) for t in range(0, 5000))),
    ("bounded < 2.5 always", all(PM(t) < 2.5 for t in [0, 1, 100, 10**6, 10**9])),
    ("finite at 2e9", math.isfinite(PM(2_000_000_000))),
    ("combined finite at 10M", math.isfinite(BASE(10_000_000) * PM(10_000_000))),
]:
    print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
g = (math.log(BASE(1001)*PM(1001)) - math.log(BASE(999)*PM(999))) / (math.log(1001)-math.log(999))
print(f"  combined growth exponent near t=1000: {g:.3f} (base alone ~0.90; old PM was ~1.88)")
print(f"  PM at infinity approaches: {1+prestige.PRESTIGE_MASTERY_MAX:.2f}x (never reached)")
