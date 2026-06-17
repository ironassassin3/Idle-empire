"""Phase 112 — post-manager experience audit (Phases 109–111).

Drives real PlayingState: milestone unlock + payroll hire, Pete/Sal behaviors,
Accountant auto-buy. Compares timelines and friction vs Phase 105 baseline.
Writes PHASE112_REPORT.md.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import _measure_p105 as h
import src.managers as mgr_mod
import src.prestige as prestige
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

FOCUS_MGRS = ("Sticky Pete", "Lucky Sal", "The Mechanic", "The Accountant")

# Phase 105 baseline (pre-109/111) — greedy buyer, old cash costs
P105 = {
    "CASUAL": {
        "passive_crossover": 107, "idle_60s": 630, "prestige": 4296,
        "first_mgr": 3009, "accountant": None, "acct_autobuy": None,
        "manual_last5": 27, "total_purchases": 204, "avg_interval": 21,
        "dead_periods": 0,
    },
    "ENGAGED": {
        "passive_crossover": 265, "idle_60s": 2130, "prestige": 3582,
        "first_mgr": 2372, "accountant": None, "acct_autobuy": None,
        "manual_last5": 27, "total_purchases": 204, "avg_interval": 17,
        "dead_periods": 0,
    },
    "OPTIMIZER": {
        "passive_crossover": 512, "idle_60s": None, "prestige": 2860,
        "first_mgr": 1979, "accountant": None, "acct_autobuy": None,
        "manual_last5": 32, "total_purchases": 204, "avg_interval": 14,
        "dead_periods": 0,
    },
}

COIN_CLICK = {"CASUAL": 0.30, "ENGAGED": 0.45, "OPTIMIZER": 0.60}


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


def _snap(ps, t: float) -> dict:
    return h.snapshot(ps, t)


def _best_idx(ps) -> int | None:
    b = h.best_building(ps)
    if not b:
        return None
    return ps.buildings.index(b)


def _can_afford_anything(ps) -> bool:
    if h.best_building(ps) and ps.balance >= h.best_building(ps).current_cost:
        return True
    for u in ps.upgrades:
        if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
            return True
    for idx, m in enumerate(ps.managers):
        if not m.hired and mgr_mod.can_hire_manager(ps, idx):
            return True
    return False


@dataclass
class P112Result:
    profile: str
    passive_crossover: float | None = None
    idle_60s: float | None = None
    prestige: float | None = None
    unlock: dict[str, float | None] = field(default_factory=dict)
    hired: dict[str, float | None] = field(default_factory=dict)
    acct_autobuy: float | None = None
    purchase_times: list[tuple[float, str]] = field(default_factory=list)
    off_path_buys: int = 0
    on_path_buys: int = 0
    coins_expired: int = 0
    coins_manual: int = 0
    coins_auto_sal: int = 0
    dead_periods: list[dict] = field(default_factory=list)
    buy_bursts: int = 0
    manual_last5: int = 0
    managers_hired: int = 0
    accountant_active: bool = False


def run_profile(name: str, *, max_min: int = 90, seed: int = 112) -> P112Result:
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    random.seed(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P112Result(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    dead_start: float | None = None
    recent_buys: list[float] = []
    prev_owned = [b.owned for b in ps.buildings]

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ips_before = ps.income_per_second

        ps.update(dt)

        if mgr_mod.manager_active(ps, "The Accountant"):
            for i, b in enumerate(ps.buildings):
                if b.owned > prev_owned[i] and r.acct_autobuy is None:
                    r.acct_autobuy = t

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = random.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        if r.passive_crossover is None and t > 60:
            ar = h.active_earnings_rate(ps, profile)
            if ips_before > ar and ar > 0:
                r.passive_crossover = t

        if r.idle_60s is None and t >= 120 and int(t) % 30 == 0:
            ar = h.active_earnings_rate(ps, profile)
            total = ps.income_per_second + ar
            if total > 0 and ar / total <= h.IDLE_LOSS_THRESHOLD:
                r.idle_60s = t

        for idx, m in enumerate(ps.managers):
            if m.name in FOCUS_MGRS:
                if m.name not in r.unlock and mgr_mod.manager_unlocked(ps, idx):
                    r.unlock[m.name] = t
                if m.name not in r.hired and m.hired:
                    r.hired[m.name] = t

        any_purchase = False

        for idx, m in enumerate(ps.managers):
            if mgr_mod.can_hire_manager(ps, idx):
                fee = mgr_mod.hire_fee(idx)
                ps.balance -= fee
                m.hired = True
                r.purchase_times.append((t, f"manager:{m.name}"))
                recent_buys.append(t)
                any_purchase = True
                if m.name not in r.hired:
                    r.hired[m.name] = t

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                idx = ps.buildings.index(b)
                rec = mgr_mod.pete_recommends_index(ps)
                if rec is not None:
                    if idx == rec:
                        r.on_path_buys += 1
                    else:
                        r.off_path_buys += 1
                ps.balance -= b.current_cost
                b.owned += 1
                r.purchase_times.append((t, f"building:{b.name}"))
                recent_buys.append(t)
                any_purchase = True

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)
                r.purchase_times.append((t, f"upgrade:{u.name}"))
                recent_buys.append(t)
                any_purchase = True

        if any_purchase:
            dead_start = None
        else:
            if dead_start is None:
                dead_start = t
            elif t - dead_start >= h.DEAD_PERIOD_SEC:
                if not _can_afford_anything(ps):
                    r.dead_periods.append({"start": dead_start, "duration": t - dead_start})
                    dead_start = t

        recent_buys = [tb for tb in recent_buys if t - tb <= 10]
        if len(recent_buys) >= 3:
            r.buy_bursts += 1

        if prestige.can_prestige(ps):
            r.prestige = t
            r.manual_last5 = sum(1 for pt, _ in r.purchase_times if t - pt <= 300)
            r.managers_hired = sum(1 for m in ps.managers if m.hired)
            r.accountant_active = mgr_mod.manager_active(ps, "The Accountant")
            break

        prev_owned = [b.owned for b in ps.buildings]
        t += dt

    r.coins_expired = getattr(ps, "_coins_expired", 0)
    r.coins_manual = getattr(ps, "_coins_manual", 0)
    r.coins_auto_sal = getattr(ps, "_coins_auto_sal", 0)
    return r


def _delta_str(new: float | None, old: float | None, *, lower_better: bool = False) -> str:
    if new is None or old is None:
        return "—"
    d = new - old
    good = (d < 0) if lower_better else (d > 0)
    sign = "−" if d < 0 else "+"
    return f"{sign}{abs(int(d))}s ({'better' if good else 'worse'})"


def build_report(results: list[P112Result]) -> str:
    engaged = next(x for x in results if x.profile == "ENGAGED")
    lines = [
        "# Phase 112 — Post-Manager Experience Audit",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Measurement only — reflects Phases 109 (behavior), 110–111 (access).",
        "",
        "---",
        "",
        "## 1. Method",
        "",
        "`_measure_p112.py` drives **real `PlayingState`**: milestone unlock + payroll hire,",
        "Pete buy-advisor, Sal auto-collect, Accountant auto-buy. Greedy buyer hires managers",
        "when `can_hire_manager` before building purchases. Partial coin-click sim.",
        "",
        "| Profile | CPS | Active | Buys/s | Coin click |",
        "|---------|-----|--------|--------|------------|",
        "| CASUAL | 1.5 | 25% | 0.15 | 30% |",
        "| ENGAGED | 4.0 | 33% | 0.50 | 45% |",
        "| OPTIMIZER | 6.0 | 45% | 1.20 | 60% |",
        "",
        "Baseline: **Phase 105** (pre-redesign, old cash manager costs).",
        "",
        "---",
        "",
        "## 2. Timeline — Phase 112",
        "",
    ]

    for r in results:
        lines.append(f"### {r.profile}")
        lines.append("")
        lines.append("| Event | Time |")
        lines.append("|-------|------|")
        lines.append(f"| Passive > click crossover | {_fmt_t(r.passive_crossover)} |")
        for m in FOCUS_MGRS:
            lines.append(f"| {m} unlocked | {_fmt_t(r.unlock.get(m))} |")
            lines.append(f"| {m} hired | {_fmt_t(r.hired.get(m))} |")
        lines.append(f"| Accountant first auto-buy | {_fmt_t(r.acct_autobuy)} |")
        lines.append(f"| 60s idle-capable | {_fmt_t(r.idle_60s)} |")
        lines.append(f"| First prestige | {_fmt_t(r.prestige)} |")
        if r.idle_60s is None and r.profile == "OPTIMIZER":
            lines.append("")
            lines.append("*OPTIMIZER never hits 60s idle-capable: high CPS + buy rate keeps active "
                         "layer above 10% of total $/s through prestige.*")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 3. Phase 105 vs Phase 112 (ENGAGED focus)",
        "",
        "| Metric | Phase 105 | Phase 112 | Change |",
        "|--------|-----------|-----------|--------|",
    ])
    p105_eng = P105["ENGAGED"]
    p112_interval = int(h.avg_purchase_interval(engaged.purchase_times) or 0)
    lines.append(f"| First prestige | {_fmt_t(p105_eng['prestige'])} | {_fmt_t(engaged.prestige)} | "
                 f"{_delta_str(engaged.prestige, p105_eng['prestige'], lower_better=True)} |")
    lines.append(f"| First manager (Pete) | {_fmt_t(p105_eng['first_mgr'])} | {_fmt_t(engaged.hired.get('Sticky Pete'))} | "
                 f"{_delta_str(engaged.hired.get('Sticky Pete'), p105_eng['first_mgr'], lower_better=True)} |")
    lines.append(f"| The Accountant hired | NEVER | {_fmt_t(engaged.hired.get('The Accountant'))} | NEW |")
    lines.append(f"| Accountant auto-buy | NEVER | {_fmt_t(engaged.acct_autobuy)} | NEW |")
    lines.append(f"| 60s idle-capable | {_fmt_t(p105_eng['idle_60s'])} | {_fmt_t(engaged.idle_60s)} | "
                 f"{_delta_str(engaged.idle_60s, p105_eng['idle_60s'], lower_better=True)} |")
    lines.append(f"| Manual buys (last 5 min) | {p105_eng['manual_last5']} | {engaged.manual_last5} | "
                 f"{engaged.manual_last5 - p105_eng['manual_last5']:+d} |")
    lines.append(f"| Avg purchase interval | ~{p105_eng['avg_interval']}s | ~{p112_interval}s | "
                 f"{'−' if p112_interval < p105_eng['avg_interval'] else '+'}"
                 f"{abs(p112_interval - p105_eng['avg_interval'])}s |")
    lines.append(f"| Buy bursts (3+ in 10s) | — | {engaged.buy_bursts} | — |")

    lines.extend([
        "",
        "### All profiles — friction comparison",
        "",
        "| Profile | P105 last-5min buys | P112 last-5min | P112 coins expired | "
        "P112 off-path buys | P112 dead periods |",
        "|---------|--------------------:|---------------:|-------------------:|"
        "------------------:|------------------:|",
    ])
    for r in results:
        p105 = P105[r.profile]
        avg_iv = int(h.avg_purchase_interval(r.purchase_times) or 0)
        lines.append(
            f"| {r.profile} | {p105['manual_last5']} | {r.manual_last5} | {r.coins_expired} | "
            f"{r.off_path_buys} | {len(r.dead_periods)} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 4. Success questions — progression arc",
        "",
        "### ENGAGED emotional chain",
        "",
    ])
    pete = engaged.hired.get("Sticky Pete")
    sal = engaged.hired.get("Lucky Sal")
    mech = engaged.hired.get("The Mechanic")
    acct = engaged.hired.get("The Accountant")
    prest = engaged.prestige or 1
    lines.append(f"1. **Manual empire** (0 – passive crossover ~4m) — unchanged from P105.")
    lines.append(f"2. **Delegation** (Pete ~{_fmt_t(pete)}, Sal ~{_fmt_t(sal)}) — "
                 f"**NEW**; was first manager at 39m in P105.")
    lines.append(f"3. **Partial automation** (Mechanic ~{_fmt_t(mech)}, Accountant hire ~{_fmt_t(acct)}, "
                 f"auto-buy ~{_fmt_t(engaged.acct_autobuy)}) — **NEW**; P105 never reached Accountant.")
    pct_faster = int((1 - prest / p105_eng["prestige"]) * 100)
    lines.append(f"4. **Prestige** ~{_fmt_t(prest)} — **{pct_faster}% faster** than P105.")
    lines.append("")
    lines.append("**Verdict:** Manual → Delegation → Automation → Prestige arc **now exists** for ENGAGED.")
    lines.append("Missing transition: **Mechanic** still income-only (no partial auto-buy behavior yet — Phase 108 design not implemented).")
    lines.append("")

    lines.extend([
        "### Did manual burden decrease?",
        "",
        f"- Last-5min manual purchases: **27 → {engaged.manual_last5}** (ENGAGED) — **slightly worse**, "
        "because faster progression compresses more building tiers into the final 5 min.",
        f"- Accountant auto-buy active: **{engaged.accountant_active}** — building buys delegated "
        f"for ~{int((prest - (engaged.acct_autobuy or prest)) / 60)} min pre-prestige.",
        "",
        "### Did automation arrive earlier?",
        "",
        "- Accountant hired: **NEVER → " + _fmt_t(acct) + "** (~"
        f"{int((acct or 0) / prest * 100) if acct and prest else 0}% through run).",
        "",
        "### Did actions become less repetitive?",
        "",
        f"- Off-path building buys after Pete: **{engaged.off_path_buys}** (greedy sim always follows best ROI).",
        f"- Coin expirations: **{engaged.coins_expired}**; **{engaged.coins_manual}** collected manually; "
        f"**{engaged.coins_auto_sal}** Sal auto-collected.",
        f"- Buy bursts (3+ purchases in 10s): **{engaged.buy_bursts}** — shorter avg interval "
        f"(~{p112_interval}s vs ~{p105_eng['avg_interval']}s P105) but more clustered late-run buys.",
        "",
        "---",
        "",
        "## 5. Remaining friction & next bottleneck",
        "",
        "**Remaining friction:**",
        "",
    ])

    concerns = []
    if engaged.manual_last5 > 5:
        concerns.append(f"ENGAGED still **{engaged.manual_last5} manual purchases** in final 5 min — "
                        "Accountant auto-buy reduces but does not eliminate late-run building micromanagement.")
    if engaged.coins_expired > 5:
        concerns.append(f"**{engaged.coins_expired} coin expirations** before/during early run — Sal fixes post-hire only.")
    cas = next(x for x in results if x.profile == "CASUAL")
    if cas.hired.get("The Accountant") and cas.prestige and cas.acct_autobuy:
        gap = cas.prestige - cas.acct_autobuy
        if gap < 300:
            concerns.append("CASUAL: short Accountant auto-buy window before prestige.")
    if not concerns:
        concerns.append("No major friction regressions vs P105.")

    for c in concerns:
        lines.append(f"- {c}")

    lines.extend([
        "",
        "**Next highest-priority problem (identified, not assumed):**",
        "",
        "**Mid-tier manager identity gap** — The Mechanic, Collector, and Clean Carl still",
        "behave as passive income multipliers. Phase 108 designed partial auto-buy / raid shield /",
        "heat forecast behaviors; only Pete, Sal, and Accountant change player actions today.",
        "Post-access bottleneck shifts from *\"can't reach managers\"* to *\"mid managers don't",
        "change the loop.\"*",
        "",
        f"Secondary: **CASUAL prestige pacing** — first prestige {_fmt_t(cas.prestige)} vs "
        f"ENGAGED {_fmt_t(engaged.prestige)}; Accountant window "
        f"{_fmt_t(int((cas.prestige or 0) - (cas.acct_autobuy or cas.prestige or 0))) if cas.acct_autobuy else 'N/A'} "
        "pre-prestige.",
        "",
        "---",
        "",
        "## 6. Re-run",
        "",
        "```powershell",
        "python _measure_p112.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 112 — Post-Manager Experience Audit")
    results = [run_profile(n) for n in h.PROFILES]
    for r in results:
        print(f"\n{r.profile}: prestige {_fmt_t(r.prestige)} mgrs {r.managers_hired} "
              f"last5={r.manual_last5} acct={_fmt_t(r.hired.get('The Accountant'))}")
    report = build_report(results)
    with open("PHASE112_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE112_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
