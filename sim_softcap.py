"""Phase 30 — token->income soft-cap curve fitting & validation (temporary tool).

Searches the family  mult = (1 + t/d) ** a  for parameters that land every
Phase 30 checkpoint inside its target range, then prints the comparison table.
"""
import math

# checkpoint: (tokens, lo, hi)  — target ranges from the Phase 30 brief
TARGETS = [
    (0,    1.0,  1.0),
    (25,   1.5,  2.0),
    (50,   2.5,  4.0),
    (100,  5.0,  8.0),
    (250, 12.0, 25.0),
    (500, 20.0, 40.0),
    (1000,35.0, 75.0),
    (2000,50.0,120.0),
]
MID = [(t, math.sqrt(lo*hi) if t else 1.0) for (t, lo, hi) in TARGETS]


def old_mult(t):
    return 1.02 ** t


def cand(t, a, d):
    return (1.0 + t / d) ** a


def fits(a, d):
    for (t, lo, hi) in TARGETS:
        m = cand(t, a, d)
        if not (lo - 1e-9 <= m <= hi + 1e-9):
            return False
    return True


def logerr(a, d):
    e = 0.0
    for (t, target) in MID:
        if t == 0:
            continue
        e += (math.log(cand(t, a, d)) - math.log(target)) ** 2
    return e


# Grid search
best = None
feasible = []
a = 0.60
while a <= 1.001:
    d = 3.0
    while d <= 60.0:
        if fits(a, d):
            feasible.append((logerr(a, d), a, d))
        e = logerr(a, d)
        if best is None or e < best[0]:
            best = (e, a, d)
        d += 0.5
    a += 0.005

feasible.sort()
print("=== Feasible (a,d) inside ALL ranges, best fit first ===")
if feasible:
    for e, a, d in feasible[:8]:
        print(f"  a={a:.3f}  d={d:.1f}   logerr={e:.4f}")
else:
    print("  (none strictly inside every range)")

print(f"\n=== Best least-log-error overall: a={best[1]:.3f} d={best[2]:.1f} (logerr={best[0]:.4f}) ===")

# Pick: prefer a clean feasible point near best fit; fall back to best.
if feasible:
    _, A, D = feasible[0]
else:
    _, A, D = best

# Round to tidy values and re-test
def show(A, D):
    print(f"\n=== Curve: mult = (1 + t/{D}) ** {A} ===")
    print(f"{'tokens':>7} | {'OLD 1.02^t':>14} | {'NEW':>10} | {'target lo-hi':>14} | in-range")
    for (t, lo, hi) in TARGETS:
        o = old_mult(t)
        n = cand(t, A, D)
        ok = "yes" if lo - 1e-9 <= n <= hi + 1e-9 else "NO"
        os = f"{o:.2f}" if o < 1e6 else f"{o:.3e}"
        print(f"{t:>7} | {os:>14} | {n:>10.3f} | {lo:>5.1f}-{hi:<7.1f} | {ok}")
    # monotonic check
    mono = all(cand(t, A, D) <= cand(t+1, A, D) for t in range(0, 3000))
    print(f"monotonic 0..3000: {mono}")
    print(f"value at 5000 tokens: {cand(5000, A, D):.1f}x   at 10000: {cand(10000, A, D):.1f}x")

show(A, D)

# Also show a couple of tidy rounded candidates for human choice
for (A2, D2) in [(0.80, 10.0), (0.85, 12.0), (0.88, 12.0), (0.90, 14.0)]:
    inside = fits(A2, D2)
    print(f"\n-- tidy candidate a={A2} d={D2}  fitsAll={inside}")
    for (t, lo, hi) in TARGETS:
        n = cand(t, A2, D2)
        ok = "ok" if lo-1e-9 <= n <= hi+1e-9 else "X"
        print(f"   t={t:<5} new={n:8.3f}  ({lo}-{hi}) {ok}")
