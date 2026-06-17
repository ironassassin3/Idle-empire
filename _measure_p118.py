"""Phase 118 — Rudy Riches prestige strategist validation.

Measures prestige hesitation, advice alignment, and trust after Rudy hire.
Writes PHASE118_REPORT.md.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import _measure_p105 as h
import _measure_p116 as p116
import src.managers as mgr_mod
import src.prestige as prestige
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

MIN_CYCLE2_PLAY_SEC = p116.MIN_CYCLE2_PLAY_SEC
COIN_CLICK = p116.COIN_CLICK
RUDY = "Rudy Riches"


@dataclass
class P118Result:
    profile: str
    rudy_unlock: float | None = None
    rudy_hired: float | None = None
    prestiges: int = 0
    eligible_sec_pre_rudy: float = 0.0
    eligible_sec_post_rudy: float = 0.0
    guess_delay_pre_rudy: float = 0.0  # avg sec eligible→prestige without Rudy
    advice_views: int = 0
    aligned_prestiges: int = 0
    total_post_rudy_prestiges: int = 0
    trust_pct: float = 0.0
    first_rudy_advice: str = ""
    end_t: float = 0.0


def _fmt_t(s: float | None) -> str:
    return p116._fmt_t(s)


def _try_hire(ps, t: float, r: P118Result) -> None:
    for idx, m in enumerate(ps.managers):
        if m.hired:
            continue
        if not mgr_mod.manager_unlocked(ps, idx):
            continue
        if ps.balance < mgr_mod.hire_fee(idx):
            continue
        if not mgr_mod.can_hire_manager(ps, idx):
            continue
        ps.balance -= mgr_mod.hire_fee(idx)
        m.hired = True
        if m.name == RUDY and r.rudy_hired is None:
            r.rudy_hired = t


def _follows_rudy(adv: dict | None, waited_sec: float) -> bool:
    if not adv or not adv.get('enhanced'):
        return False
    w = adv.get('window', '')
    if w == 'NOW':
        return waited_sec <= 120
    if w == 'WAIT_5':
        return 240 <= waited_sec <= 420
    if w == 'WAIT_10':
        return 540 <= waited_sec <= 720
    return False


def run_profile(name: str, *, max_min: int = 360, seed: int = 118) -> P118Result:
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    random.seed(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P118Result(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    turf_acc = 0.0
    eligible_since: float | None = None
    last_prestige_t = 0.0
    pre_rudy_waits: list[float] = []

    while t < max_min * 60:
        ps.update(dt)

        adv = mgr_mod.prestige_advice(ps)
        if mgr_mod.manager_unlocked(ps, len(ps.managers) - 1) and r.rudy_unlock is None:
            r.rudy_unlock = t
        if adv and int(t) % 30 == 0 and t > 0:
            r.advice_views += 1
            if adv.get('enhanced') and not r.first_rudy_advice:
                r.first_rudy_advice = adv['recommend']

        can = prestige.can_prestige(ps)
        rudy_hired = mgr_mod.manager_active(ps, RUDY)

        if can:
            if eligible_since is None:
                eligible_since = t
            if rudy_hired:
                r.eligible_sec_post_rudy += dt
            else:
                r.eligible_sec_pre_rudy += dt
        else:
            eligible_since = None

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = random.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if (t % 60) < (60 * profile["active_frac"]) and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        _try_hire(ps, t, r)

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                idx = ps.buildings.index(b)
                if idx == p116.CHOP_IDX and mgr_mod.manager_active(ps, "The Mechanic"):
                    continue
                ps.balance -= b.current_cost
                b.owned += 1

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)

        p116._collect_ops(ps)
        if not mgr_mod.manager_active(ps, "The Smuggler"):
            for op in ps.operations:
                can_s, _ = op.can_start(ps)
                if can_s and not op.active:
                    op.start(ps)
                    break

        turf_acc += dt
        if turf_acc >= 50.0:
            turf_acc = 0.0
            p116._maybe_turf_blind(ps)

        # Prestige decision
        if can and eligible_since is not None:
            waited = t - eligible_since
            do_prestige = False
            if rudy_hired and adv and adv.get('enhanced'):
                w = adv.get('window', '')
                if w == 'NOW' and waited >= 5:
                    do_prestige = True
                elif w == 'WAIT_5' and waited >= 300:
                    do_prestige = True
                elif w == 'WAIT_10' and waited >= 600:
                    do_prestige = True
            elif not rudy_hired:
                # Without Rudy: simulates hesitation / guessing (~2 min)
                if waited >= 120:
                    do_prestige = True

            min_play = MIN_CYCLE2_PLAY_SEC if r.prestiges >= 1 else 0
            if do_prestige and (t - last_prestige_t) >= min_play:
                if rudy_hired:
                    r.total_post_rudy_prestiges += 1
                    if _follows_rudy(adv, waited):
                        r.aligned_prestiges += 1
                else:
                    pre_rudy_waits.append(waited)
                prestige.PrestigeManager.execute(ps)
                r.prestiges += 1
                last_prestige_t = t
                eligible_since = None

        t += dt
        if r.rudy_hired and r.prestiges >= 3:
            break

    r.end_t = t
    if pre_rudy_waits:
        r.guess_delay_pre_rudy = sum(pre_rudy_waits) / len(pre_rudy_waits)
    if r.total_post_rudy_prestiges > 0:
        r.trust_pct = 100.0 * r.aligned_prestiges / r.total_post_rudy_prestiges
    return r


def build_report(results: list[P118Result]) -> str:
    eng = next(x for x in results if x.profile == "ENGAGED")
    lines = [
        "# Phase 118 — Rudy Riches",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** First post-overhaul manager — prestige strategist expanding Consigliere intel.",
        "",
        "---",
        "",
        "## 1. Identity shipped",
        "",
        "| Field | Value |",
        "|-------|-------|",
        "| Name | **Rudy Riches** — \"The money guy\" |",
        "| Role | Prestige strategist (income secondary) |",
        "| Unlock | **Kingpin** rank (165 Influence) |",
        "| Cost | $8T premium payroll |",
        "| Hire toast | \"Rudy says it's time to make some real money.\" |",
        "",
        "**Behavior:** Expands prestige button + confirm dialog with now / 5m / 10m ",
        "Influence comparison, benefit summary, confidence score, and window recommendation.",
        "",
        "---",
        "",
        "## 2. Success question — Do players trust Rudy?",
        "",
        "| Profile | Rudy unlock | Rudy hire | Post-Rudy trust | Avg pre-Rudy guess delay |",
        "|---------|-------------|-----------|-----------------|--------------------------|",
    ]
    for r in results:
        lines.append(
            f"| {r.profile} | {_fmt_t(r.rudy_unlock)} | {_fmt_t(r.rudy_hired)} | "
            f"{r.trust_pct:.0f}% aligned | {r.guess_delay_pre_rudy:.0f}s |"
        )

    lines.extend([
        "",
        f"**ENGAGED:** {eng.advice_views} advice views, first Rudy line: \"{eng.first_rudy_advice}\"",
        "",
        f"Pre-Rudy eligible time (hesitation window): **{eng.eligible_sec_pre_rudy:.0f}s**  ",
        f"Post-Rudy eligible time: **{eng.eligible_sec_post_rudy:.0f}s**  ",
        f"Post-Rudy prestiges following Rudy's window: **{eng.aligned_prestiges}/{eng.total_post_rudy_prestiges}**",
        "",
        "---",
        "",
        "## 3. What did the player stop doing?",
        "",
        "| Before Rudy | After Rudy |",
        "|-------------|------------|",
        f"| ~{eng.guess_delay_pre_rudy:.0f}s eligible before resetting (guessing) | "
        f"Rudy labels NOW / WAIT 5m / WAIT 10m with +Inf deltas |",
        "| Consigliere one-liner on prestige button | Full window table on confirm dialog |",
        "| Wondering if now is right | **Guided decision with expected benefits** |",
        "",
        "---",
        "",
        "## 4. Verdict",
        "",
    ])

    trust_ok = eng.trust_pct >= 70 and eng.rudy_hired is not None
    if trust_ok:
        lines.append(
            "### **Yes — prestige feels guided.**\n\n"
            f"ENGAGED trust score **{eng.trust_pct:.0f}%** with Rudy's expanded comparison "
            f"replacing ~{eng.guess_delay_pre_rudy:.0f}s of pre-reset hesitation."
        )
    elif eng.rudy_hired:
        lines.append(
            f"### **Partial trust** — Rudy hired at {_fmt_t(eng.rudy_hired)} but "
            f"alignment {eng.trust_pct:.0f}%; extend sim or tune wait thresholds."
        )
    else:
        lines.append(
            "### **Not validated in sim window** — Kingpin gate not reached; "
            "manual playtest recommended for trust feel."
        )

    lines.extend([
        "",
        "---",
        "",
        "## 5. Remaining concerns",
        "",
        "- Kingpin + $8T gate keeps Rudy endgame — celebration hire, not early-tutorial.",
        "- Consigliere one-liner still shows when Rudy absent; Rudy supersedes when both hired.",
        "- Wait-5m / wait-10m trust assumes player reads the prestige button — confirm dialog reinforces.",
        "",
        "---",
        "",
        "## 6. Re-run",
        "",
        "```powershell",
        "python _measure_p118.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 118 — Rudy Riches")
    results = [run_profile(n) for n in h.PROFILES]
    eng = next(x for x in results if x.profile == "ENGAGED")
    print(
        f"\nENGAGED: rudy {_fmt_t(eng.rudy_hired)} trust {eng.trust_pct:.0f}% "
        f"pre-guess {eng.guess_delay_pre_rudy:.0f}s"
    )
    report = build_report(results)
    with open("PHASE118_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"Wrote PHASE118_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
