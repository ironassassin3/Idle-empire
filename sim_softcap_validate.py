"""Phase 30 — validation harness for the token->income soft cap.

Pulls the LIVE income_mult from src.prestige (so it reports the real shipped
curve), then computes:
  * Part 5: old vs new multiplier table + Consigliere / Jade / combined advantage
  * Part 6: per-system contribution share at 100/250/500/1000 tokens
"""
import math
import src.prestige as prestige
import src.prestige_tree as ptree
import src.dragon as dragon

OLD = lambda t: 1.02 ** t
NEW = prestige.income_mult

CHECKPOINTS = [0, 25, 50, 100, 165, 250, 500, 1000, 2000]

print("=" * 72)
print("PART 5 — OLD vs NEW token->income multiplier")
print("=" * 72)
print(f"{'tokens':>7} | {'OLD 1.02^t':>16} | {'NEW':>12} | {'NEW/OLD':>10}")
for t in CHECKPOINTS:
    o, n = OLD(t), NEW(t)
    os = f"{o:,.2f}" if o < 1e7 else f"{o:.3e}"
    ratio = f"{n/o:.4f}" if o > 0 else "-"
    print(f"{t:>7} | {os:>16} | {n:>12.3f} | {ratio:>10}")

# ── Consigliere / Jade advantage ────────────────────────────────────────────
# Both boost the TOKENS earned per prestige. The income advantage they confer is
# income_mult(tokens_with_bonus) / income_mult(tokens_without). Under the old
# exponential this ratio was 1.02^(extra_tokens) and GREW without bound across a
# run; under the new curve it shrinks as the token base grows.
#
# Consigliere capstone path: cs_tongue x1.25 * cs_puppet x1.50 = x1.875 influence.
# Jade dragon: x1.30 influence (x1.625 at Ancient stage; we use base x1.30).
CONSIG = 1.875
JADE = 1.30
COMBINED = CONSIG * JADE   # 2.4375x token gain

def advantage(curve, base_tokens, gain_mult):
    """Income advantage from earning `gain_mult`x more tokens at a given base."""
    boosted = base_tokens * gain_mult
    return curve(boosted) / curve(base_tokens)

print()
print("=" * 72)
print("PART 5 — Consigliere / Jade / Combined INCOME advantage")
print("(ratio of income vs a neutral build at the same token base)")
print("=" * 72)
print(f"{'base tok':>8} | {'sys':>9} | {'OLD adv':>14} | {'NEW adv':>10}")
for base in [50, 100, 250, 500, 1000]:
    for name, gm in [("Consig", CONSIG), ("Jade", JADE), ("Both", COMBINED)]:
        oa = advantage(OLD, base, gm)
        na = advantage(NEW, base, gm)
        oas = f"{oa:,.2f}" if oa < 1e7 else f"{oa:.3e}"
        print(f"{base:>8} | {name:>9} | {oas:>14} | {na:>10.3f}")
    print("  " + "-" * 44)

# ── Part 6: system relevance / contribution share ───────────────────────────
# Approximate each system's multiplicative contribution at favourable-but-
# realistic settings, then express the prestige multiplier's share of the
# product so we can see whether other systems still matter.
print()
print("=" * 72)
print("PART 6 — System contribution share under the NEW curve")
print("=" * 72)

# Representative 'other system' multipliers (each at a strong-but-attainable level)
SYSTEMS = {
    "Respect (cap +50%)":      1.50,                       # prestige.respect cap
    "Rank income (+15% max)":  1.15,                       # cumulative rank perks
    "Territory (20 distr 2%)": 1.40,                       # +2%/district * 20
    "Heat (risk band)":        1.25,                       # heat_income_mult sweet spot
    "Dragon (rival/ops)":      1.20,                       # red/black income side
    "Branch income perk":      1.15,                       # e.g. Kingpin Cash Flow
}
other_product = 1.0
for v in SYSTEMS.values():
    other_product *= v

for t in [100, 250, 500, 1000]:
    pm = NEW(t)
    total = pm * other_product
    print(f"\nAt {t} tokens  (prestige mult = x{pm:.2f}):")
    print(f"  {'system':<26} {'mult':>7} {'share of total log-power':>26}")
    log_total = math.log(total)
    # prestige share
    print(f"  {'Prestige tokens':<26} {pm:>7.2f} {math.log(pm)/log_total*100:>23.1f} %")
    for name, v in SYSTEMS.items():
        print(f"  {name:<26} {v:>7.2f} {math.log(v)/log_total*100:>23.1f} %")
    # naive linear share too
    print(f"  >> prestige is x{pm:.1f} of a x{total:,.0f} stack "
          f"({pm/total*100:.1f}% if read multiplicatively-flat)")
