"""Phase 31 — Prestige Mastery redesign candidates vs current, against the LIVE
Phase 30 soft cap (src.prestige.income_mult)."""
import math
import src.prestige as prestige

BASE = prestige.income_mult            # (1 + t/14) ** 0.90  (live)
D, A = prestige.TOKEN_SOFTCAP_D, prestige.TOKEN_SOFTCAP_A

# ── PM factor candidates (multiplier applied on top of BASE) ────────────────
def pm_current(t):                      # current: linear, unbounded
    return 1.0 + t * 0.10

def pm_A_exponent(t):                   # A: exponent bump 0.90 -> 0.96, expressed as a factor
    return (1.0 + t / D) ** 0.06        # so BASE*pm_A = (1+t/14)**0.96

def pm_B_asymptote(t, M=1.5, S=120.0):  # B: asymptotic, approaches 1+M (here ->2.5x)
    return 1.0 + M * (1.0 - 1.0 / (1.0 + t / S))

def pm_C_log(t, k=0.5, s=10.0):         # C: logarithmic, slow & uncapped
    return 1.0 + k * math.log(1.0 + t / s)

CANDS = [("CURRENT", pm_current), ("A exp+0.06", pm_A_exponent),
         ("B asym->2.5", pm_B_asymptote), ("C log", pm_C_log)]

TOKENS = [0, 25, 50, 100, 250, 500, 1000, 2000, 5000]

for name, pm in CANDS:
    print("=" * 78)
    print(f"{name}")
    print(f"{'tok':>6} | {'base':>9} | {'PM factor':>10} | {'final':>12} | {'PM share%':>9}")
    for t in TOKENS:
        b = BASE(t); f = pm(t); fin = b * f
        share = (math.log(f) / math.log(fin) * 100) if fin > 1 else 0.0
        print(f"{t:>6} | {b:>9.2f} | {f:>10.3f} | {fin:>12.1f} | {share:>8.1f}%")

# ── Relevance of OTHER systems: prestige+PM share of total log-power ────────
# Other-system stack from Phase 30 Part 6 (Respect 1.5, rank 1.15, territory 1.4,
# heat 1.25, dragon 1.2, branch 1.15) = product ~4.17x  (fixed, token-independent)
OTHER = 1.5 * 1.15 * 1.4 * 1.25 * 1.2 * 1.15
print("\n" + "=" * 78)
print(f"OTHER-SYSTEM RELEVANCE  (other stack = x{OTHER:.2f}, token-independent)")
print("share = OTHER's % of total income log-power; higher = systems matter more")
print(f"{'tok':>6} | " + " | ".join(f"{n:>11}" for n, _ in CANDS))
for t in [100, 500, 1000, 2000]:
    cells = []
    for _, pm in CANDS:
        total = BASE(t) * pm(t) * OTHER
        other_share = math.log(OTHER) / math.log(total) * 100
        cells.append(f"{other_share:>10.1f}%")
    print(f"{t:>6} | " + " | ".join(cells))

# ── Growth-class diagnostic: combined exponent d(log mult)/d(log t) near t=1000
print("\n" + "=" * 78)
print("LOCAL GROWTH EXPONENT of (base*PM) near t=1000  (base alone ~0.90)")
def local_exp(fn, t=1000.0, h=1.0):
    return (math.log(fn(t+h)) - math.log(fn(t-h))) / (math.log(t+h) - math.log(t-h))
for name, pm in CANDS:
    g = local_exp(lambda x: BASE(x) * pm(x))
    print(f"  {name:>12}: combined exponent ~ {g:.3f}")

# ── Relative advantage of buying PM vs not, at each token level ─────────────
print("\n" + "=" * 78)
print("PM 'must-buy' pressure = final/base (how much you lose by skipping PM)")
print(f"{'tok':>6} | " + " | ".join(f"{n:>11}" for n, _ in CANDS))
for t in [100, 500, 1000, 2000, 5000]:
    cells = [f"{pm(t):>10.2f}x" for _, pm in CANDS]
    print(f"{t:>6} | " + " | ".join(cells))
