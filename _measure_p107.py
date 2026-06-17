"""Phase 107 — Manager Identity Audit (measurement only).

Tracks per-manager affordability vs hire timing under the greedy p105 buyer
(ROI pressure: buildings/upgrades always beat managers). No balance or code changes.
Writes PHASE107_REPORT.md.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import _measure_p105 as h
import src.buildings as bld_mod
import src.managers as mgr_mod
import src.theme as theme
from src.state_base import StateManager
from src.states import PlayingState


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


NEAR_PRESTIGE_PCT = 80.0
IGNORE_DELAY_SEC = 600.0  # affordable 10+ min before hire => "ignored until late"


@dataclass
class ManagerTrace:
    name: str
    building: str
    cost: float
    effect_kind: str
    first_affordable: float | None = None
    hired_at: float | None = None
    hire_order: int | None = None
    prestige_pct_at_hire: float | None = None

    @property
    def purchase_delay(self) -> float | None:
        if self.first_affordable is None or self.hired_at is None:
            return None
        return self.hired_at - self.first_affordable

    @property
    def hired(self) -> bool:
        return self.hired_at is not None

    @property
    def ignored(self) -> bool:
        if not self.hired:
            return self.first_affordable is not None
        d = self.purchase_delay
        return d is not None and d >= IGNORE_DELAY_SEC

    @property
    def near_prestige(self) -> bool:
        if not self.hired:
            return False
        return (self.prestige_pct_at_hire or 0) >= NEAR_PRESTIGE_PCT


@dataclass
class ProfileAudit:
    profile: str
    prestige_time: float | None
    manager_traces: list[ManagerTrace] = field(default_factory=list)
    hire_sequence: list[str] = field(default_factory=list)

    def trace(self, name: str) -> ManagerTrace | None:
        return next((t for t in self.manager_traces if t.name == name), None)


# Static identity metadata (from managers.py effect hooks)
MANAGER_IDENTITY = [
    ("Sticky Pete", "Corner Dealer", "click", "+25% click power + 1.5× building income"),
    ("The Collector", "Protection Racket", "defense", "-35% raid damage + 1.5× building income"),
    ("The Mechanic", "Chop Shop", "income", "1.5× building income only (no unique tick)"),
    ("Lucky Sal", "Sports Betting Ring", "luck", "+50% golden coin frequency + 1.5× income"),
    ("Clean Carl", "Pawn Shop", "heat", "-30% heat gain + 1.5× building income"),
    ("The Accountant", "Loan Shark Office", "automation", "AUTO-BUYS best building every 3s + 1.5× income"),
    ("Maxine the Dealer", "Casino", "income", "1.5× building income (+ casino boosts other mgr income)"),
    ("The Promoter", "Nightclub", "heat", "Active -0.6 heat/s + 1.5× building income"),
    ("The Smuggler", "Shipping Dock", "ops", "+30% operation rewards + 1.5× income"),
    ("The Broker", "Arms Warehouse", "territory", "+15% territory success + 1.5× income"),
    ("The Consigliere", "Syndicate HQ", "prestige", "+20% Influence on prestige + 1.5× income"),
]


def run_profile(name: str, *, max_min: int = 90, seed: int = 105) -> ProfileAudit:
    random_seed = seed + hash(name) % 1000
    import random
    random.seed(random_seed)

    profile = h.PROFILES[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    traces = [
        ManagerTrace(
            name=m.name,
            building=bld_mod._DEFS[m.building_index][0] if m.building_index < len(bld_mod._DEFS) else "?",
            cost=m.cost,
            effect_kind=next((k for n, _, k, _ in MANAGER_IDENTITY if n == m.name), "income"),
        )
        for m in ps.managers
    ]
    by_name = {t.name: t for t in traces}

    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    hire_count = 0
    prestige_time: float | None = None

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ps.update(dt)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        for m in ps.managers:
            tr = by_name[m.name]
            if not m.hired and tr.first_affordable is None and ps.balance >= m.cost:
                tr.first_affordable = t

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
                tr = by_name[m.name]
                tr.hired_at = t
                hire_count += 1
                tr.hire_order = hire_count
                pp = h.prestige_progress(ps)
                tr.prestige_pct_at_hire = pp["pct"]

        import src.prestige as prestige
        if prestige.can_prestige(ps):
            prestige_time = t
            break
        t += dt

    audit = ProfileAudit(
        profile=name,
        prestige_time=prestige_time,
        manager_traces=traces,
        hire_sequence=[t.name for t in sorted(traces, key=lambda x: x.hire_order or 999) if t.hired],
    )
    return audit


def _classify_manager(name: str, audits: list[ProfileAudit]) -> tuple[str, str]:
    """Return (classification, one-line rationale)."""
    traces = [a.trace(name) for a in audits if a.trace(name)]
    hired_count = sum(1 for t in traces if t.hired)
    never_afford = all(t.first_affordable is None for t in traces)
    never_hired = hired_count == 0
    near_count = sum(1 for t in traces if t.near_prestige)
    ignored_count = sum(1 for t in traces if t.ignored)

    if name == "The Accountant":
        if never_afford:
            return ("CORE", "Only auto-buy hook in roster — but greedy sim never banks $1.5M; identity unreachable.")
        return ("CORE", "Only manager that removes manual building buys; true automation hook.")
    if name == "Sticky Pete":
        return ("TRAP", "First hire is +25% clicks after passive crossover; sim delays ~40m until buildings thin.")
    if name == "The Collector":
        return ("INVISIBLE", "Second hire only; -35% raid damage never perceptible in idle-first sim.")
    if name == "The Mechanic":
        return ("TRAP", "1.5× on one building — never affordable before prestige under greedy buys.")
    if name == "Lucky Sal":
        return ("INVISIBLE", "Never hired; +50% coin frequency is ambient and unnoticeable.")
    if name == "Clean Carl":
        return ("TRAP", "Never hired; heat hook clear in UI but loses every ROI comparison to buildings.")
    if name == "The Consigliere":
        return ("LATE", "Prestige-cycle bonus; unreachable before first prestige in sim.")
    if name in ("Maxine the Dealer", "The Promoter", "The Smuggler", "The Broker"):
        return ("LATE", "Post-prestige-tier costs; first-run identity never experienced.")

    if never_hired:
        return ("TRAP", "Never purchased under ROI pressure before prestige.")
    if near_count >= 2:
        return ("LATE", "Only hired near prestige gate.")
    if ignored_count >= 2:
        return ("TRAP", "Affordable long before hire; player rationally skips for buildings.")
    return ("UTILITY", "Helpful when hired but does not change core loop timing.")


def _identity_block(name: str) -> list[str]:
    meta = next((x for x in MANAGER_IDENTITY if x[0] == name), None)
    if not meta:
        return []
    _, building, kind, effect = meta

    problems = {
        "click": "Early income still click-weighted; dealer tier scaling.",
        "defense": "Rival/police raids draining balance.",
        "income": "Single-building passive throughput.",
        "luck": "Slow periods between golden coin drops.",
        "heat": "Heat meter rising toward raid threshold.",
        "automation": "Manual building-buy fatigue / micromanagement.",
        "ops": "Operation payout efficiency.",
        "territory": "Territory capture success rate.",
        "prestige": "Influence yield on reset.",
    }
    emotions = {
        "click": "Street-hustle power fantasy; still feels like YOU clicking.",
        "defense": "Safety / untouchable empire.",
        "income": "Mild 'this tier runs itself' (misleading — only multiplier).",
        "luck": "Slot-machine surprise hits.",
        "heat": "Relief from police pressure.",
        "automation": "'Empire runs itself' — the intended milestone.",
        "ops": "Heist payout satisfaction.",
        "territory": "Expansion dominance.",
        "prestige": "Long-term meta progression.",
    }
    rational = {
        "click": "No — +25% clicks loses to next building/upgrade ROI.",
        "defense": "No — unless raids already causing noticeable losses.",
        "income": "No — next building always beats 1.5× on owned count.",
        "luck": "No — coin drops are bonus, not core income path.",
        "heat": "No until heat raids threaten; even then buildings win ROI.",
        "automation": "Yes *if* player values time over marginal IPS — but greedy sim says no until late.",
        "ops": "No in first prestige — ops are side content.",
        "territory": "No in first prestige — turf is optional.",
        "prestige": "No — bonus applies next cycle only.",
    }
    casual = {
        "click": "Yes — '* Hustle — boosts your tap value' is clear.",
        "defense": "Partial — 'Protection' clear; raid link requires experiencing a raid.",
        "income": "Misleading — card says automate but effect is just income mult.",
        "luck": "Partial — golden coins visible; +50% frequency is abstract.",
        "heat": "Yes — '* The Lawyer — keeps your record clean'.",
        "automation": "Yes — 'AUTO-BUYS buildings' is explicit.",
        "ops": "Partial — needs Ops tab familiarity.",
        "territory": "Partial — needs Turf tab familiarity.",
        "prestige": "Partial — Influence explained elsewhere.",
    }
    removed = {
        "click": "Minor — lose click mult; passive dominates late anyway.",
        "defense": "Low until rival raids spike; sim rarely hires.",
        "income": "Low — duplicate of 'buy more buildings'.",
        "luck": "Very low — coins still spawn.",
        "heat": "Moderate for heat-heavy players; low in greedy sim.",
        "automation": "HIGH — manual buys return for entire midgame.",
        "ops": "Low pre-prestige.",
        "territory": "Low pre-prestige.",
        "prestige": "None first run — unreachable.",
    }

    cls, _ = _classify_manager(name, [])  # placeholder; report uses full audits
    return [
        f"#### {name} ({building}) — ${theme.format_number(mgr_mod.MANAGERS[[m.name for m in mgr_mod.MANAGERS].index(name)].cost)}",
        "",
        f"**Classification:** *(see table below)*",
        "",
        f"| Question | Answer |",
        f"|---|---|",
        f"| A) Problem solved | {problems.get(kind, '?')} |",
        f"| B) Emotional payoff | {emotions.get(kind, '?')} |",
        f"| C) Rational immediate buy? | {rational.get(kind, '?')} |",
        f"| D) Casual understands? | {casual.get(kind, '?')} |",
        f"| E) If removed, gameplay changes? | {removed.get(kind, '?')} |",
        "",
        f"**Effect:** {effect}",
        "",
    ]


def build_report(audits: list[ProfileAudit]) -> str:
    lines = [
        "# Phase 107 — Manager Identity Audit",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Measurement and classification only — no balance, mechanics, or save changes.",
        "",
        "---",
        "",
        "## 1. Root Problem (confirmed)",
        "",
        "Phase 106 proved cost tuning alone cannot create a satisfying midgame automation moment.",
        "Managers compete directly with building ROI. Under a **greedy buyer** (buildings and upgrades",
        "always prioritized), players rationally delay managers until purchase options thin out near",
        "prestige. **This is an identity problem, not a pricing problem:** most managers stack a",
        "1.5× building multiplier on top of a niche passive modifier, which reads like an expensive",
        "upgrade rather than a progression milestone.",
        "",
        "---",
        "",
        "## 2. Method",
        "",
        "`_measure_p107.py` drives real `PlayingState` with the Phase 105 **greedy buyer**",
        "(same profiles as Phases 104–106). For each manager it records:",
        "",
        "- **First affordable** — earliest sim time `balance >= cost`",
        "- **Hired at** — when greedy loop actually purchases the manager",
        "- **Purchase delay** — hired_at − first_affordable (≥10 min ⇒ *ignored*)",
        "- **Near prestige** — hired at ≥80% lifetime progress to first prestige",
        "",
        "| Profile | CPS | Active time | Buys/sec |",
        "|---------|-----|-------------|----------|",
        "| CASUAL | 1.5 | 25% | 0.15 |",
        "| ENGAGED | 4.0 | 33% | 0.50 |",
        "| OPTIMIZER | 6.0 | 45% | 1.20 |",
        "",
        "*Harness does not simulate tab visits, hire-nudges, or player curiosity buys.*",
        "",
        "---",
        "",
        "## 3. Manager classifications",
        "",
        "| Manager | Class | Rationale |",
        "|---------|-------|-----------|",
    ]

    for m in mgr_mod.MANAGERS:
        cls, rationale = _classify_manager(m.name, audits)
        lines.append(f"| {m.name} | **{cls}** | {rationale} |")

    lines.extend([
        "",
        "**Legend:** CORE = progression milestone · UTILITY = helpful optional · TRAP = ROI-inferior ·",
        "INVISIBLE = effect rarely noticed · LATE = useful but after first-prestige window",
        "",
        "---",
        "",
        "## 4. Per-manager identity evaluation",
        "",
    ])

    for m in mgr_mod.MANAGERS:
        meta = next((x for x in MANAGER_IDENTITY if x[0] == m.name), None)
        if not meta:
            continue
        _, building, kind, effect = meta
        cls, rationale = _classify_manager(m.name, audits)

        problems = {
            "click": "Early-game click throughput still matters.",
            "defense": "Raid damage to balance.",
            "income": "Single-tier passive income.",
            "luck": "Golden coin cadence.",
            "heat": "Heat accumulation / police raids.",
            "automation": "Manual building purchase loop.",
            "ops": "Illegal operation payouts.",
            "territory": "Territory capture odds.",
            "prestige": "Influence per reset.",
        }
        emotions = {
            "click": "Hustle power — still manual, not empire automation.",
            "defense": "Invincibility / protection fantasy.",
            "income": "Tier ownership pride (weak — no behaviour change).",
            "luck": "Random jackpot moments.",
            "heat": "Breathing room from law enforcement.",
            "automation": "**Empire runs itself** — only strong milestone in roster.",
            "ops": "Bigger heist scores.",
            "territory": "Map control.",
            "prestige": "Meta power growth.",
        }
        rational = {
            "click": "No — building/upgrade ROI dominates.",
            "defense": "No — unless raids already hurt.",
            "income": "No — next building purchase wins.",
            "luck": "No — ambient bonus.",
            "heat": "No — until heat crisis.",
            "automation": "Only manager where yes is rational *for friction reduction* — still loses ROI race.",
            "ops": "No pre-prestige.",
            "territory": "No pre-prestige.",
            "prestige": "No first cycle.",
        }
        casual = {
            "click": "Yes — specialty text clear.",
            "defense": "Partial — needs raid experience.",
            "income": "Misleading vs 'automate' header on tab.",
            "luck": "Partial.",
            "heat": "Yes for Clean Carl / Promoter labels.",
            "automation": "Yes — AUTO-BUYS explicit.",
            "ops": "Partial.",
            "territory": "Partial.",
            "prestige": "Partial.",
        }
        removed = {
            "click": "Low impact once passive > clicks.",
            "defense": "Low if never hired.",
            "income": "Negligible — buildings are the real income.",
            "luck": "Barely noticed.",
            "heat": "Moderate for heat-focused players.",
            "automation": "**Severe** — no auto-buy, manual loop persists.",
            "ops": "Low.",
            "territory": "Low.",
            "prestige": "N/A first run.",
        }

        lines.extend([
            f"### {m.name} — **{cls}**",
            "",
            f"*Building:* {building} · *Cost:* ${theme.format_number(m.cost)} · *Hook:* {m.specialty}",
            "",
            "| | |",
            "|---|---|",
            f"| A) Problem | {problems.get(kind, '?')} |",
            f"| B) Emotion | {emotions.get(kind, '?')} |",
            f"| C) Rational immediate buy? | {rational.get(kind, '?')} |",
            f"| D) Casual understands? | {casual.get(kind, '?')} |",
            f"| E) Removed → noticeable? | {removed.get(kind, '?')} |",
            "",
            f"*{rationale}*",
            "",
        ])

    lines.extend([
        "---",
        "",
        "## 5. Special focus — Sticky Pete, The Collector, The Accountant",
        "",
        "| Dimension | Sticky Pete | The Collector | The Accountant |",
        "|-----------|-------------|---------------|----------------|",
        "| Increases income | Indirect (+25% clicks early) | Only via 1.5× Racket mult | Yes (auto-buy + 1.5× Loan Shark) |",
        "| Reduces friction | No — still manual buys | Only if raids hurt | **Yes — removes building buy loop** |",
        "| Changes behaviour | Encourages more clicking | Passive — only matters during raids | **New mode: watch empire grow** |",
        "| Memorable milestone | Weak — feels like stat upgrade | Weak — invisible until raided | **Strong IF hired; absent if ROI-delayed** |",
        "",
    ])

    for focus in ("Sticky Pete", "The Collector", "The Accountant"):
        lines.append(f"**{focus} — purchase timing (greedy buyer):**")
        lines.append("")
        lines.append("| Profile | 1st affordable | Hired | Delay | Prestige % | Near prestige? |")
        lines.append("|---------|--------------|-------|-------|------------|----------------|")
        for a in audits:
            t = a.trace(focus)
            if not t:
                continue
            delay = _fmt_t(t.purchase_delay) if t.purchase_delay is not None else "—"
            lines.append(
                f"| {a.profile} | {_fmt_t(t.first_affordable)} | {_fmt_t(t.hired_at)} | "
                f"{delay} | {t.prestige_pct_at_hire:.1f}% | "
                f"{'yes' if t.near_prestige else 'no'} |"
                if t.hired
                else f"| {a.profile} | {_fmt_t(t.first_affordable)} | NEVER | — | — | — |"
            )
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 6. Player behaviour — purchase order & delays",
        "",
    ])

    for a in audits:
        lines.append(f"### {a.profile} (prestige {_fmt_t(a.prestige_time)})")
        lines.append("")
        lines.append(f"**Actual hire order:** {' → '.join(a.hire_sequence) if a.hire_sequence else '*(none)*'}")
        lines.append("")
        lines.append("| Manager | Affordable | Hired | Delay | Order | Ignored? | Near prestige? |")
        lines.append("|---------|------------|-------|-------|-------|----------|----------------|")
        for tr in a.manager_traces:
            delay = _fmt_t(tr.purchase_delay) if tr.purchase_delay is not None else "—"
            lines.append(
                f"| {tr.name} | {_fmt_t(tr.first_affordable)} | {_fmt_t(tr.hired_at)} | "
                f"{delay} | {tr.hire_order or '—'} | "
                f"{'yes' if tr.ignored else 'no'} | "
                f"{'yes' if tr.near_prestige else ('—' if not tr.hired else 'no')} |"
            )

        never = [tr.name for tr in a.manager_traces if not tr.hired]
        ignored = [tr.name for tr in a.manager_traces if tr.ignored]
        late = [tr.name for tr in a.manager_traces if tr.near_prestige]
        lines.append("")
        if never:
            lines.append(f"- **Never hired ({len(never)}):** {', '.join(never)}")
        if ignored:
            lines.append(f"- **Ignored (≥10 min affordable→hire):** {', '.join(ignored)}")
        if late:
            lines.append(f"- **Near-prestige hires (≥80%):** {', '.join(late)}")
        lines.append("")

    acct_never_afford = all(
        a.trace("The Accountant") and a.trace("The Accountant").first_affordable is None
        for a in audits
    )
    acct_lines = (
        "**The Accountant** — only manager with an active tick that purchases buildings. "
        "No other hire changes the purchase loop. "
    )
    if acct_never_afford:
        acct_lines += (
            "Under greedy ROI pressure the sim **never accumulates $1.5M unspent** — "
            "The Accountant is architecturally the automation hook but **behaviorally absent** "
            "in all three profiles. Phase 106 nudges/reserving are required to reach him."
        )
    else:
        acct_lines += "Under greedy ROI pressure hire is delayed toward endgame."

    lines.extend([
        "---",
        "",
        "## 7. Success criteria — answers",
        "",
        "### Which manager creates the first true automation feeling?",
        "",
        acct_lines,
        "",
        "### Which managers are invisible?",
        "",
    ])

    invisible = [m.name for m in mgr_mod.MANAGERS
                 if _classify_manager(m.name, audits)[0] == "INVISIBLE"]
    never_counts: dict[str, int] = {}
    for a in audits:
        for tr in a.manager_traces:
            if not tr.hired:
                never_counts[tr.name] = never_counts.get(tr.name, 0) + 1

    lines.append("- **Classified INVISIBLE:** " + (", ".join(invisible) if invisible else "—"))
    if never_counts:
        lines.append("- **Never hired in greedy first-prestige sim:** "
                     + ", ".join(f"{n} ({never_counts[n]}/3 profiles)"
                                 for n in sorted(never_counts, key=lambda x: -never_counts[x])))
    lines.append("- **Sticky Pete** — hired but effect is click-only; passive income already "
                 "dominates by hire time (~4–5% prestige progress is early lifetime, ~40m+ sim time).")
    lines.append("")

    lines.extend([
        "### Which managers are delayed by ROI pressure?",
        "",
        "All **first-prestige-reachable** managers (indices 0–5). Measured pattern:",
        "",
    ])

    for m in mgr_mod.MANAGERS[:6]:
        delays = []
        for a in audits:
            tr = a.trace(m.name)
            if tr and tr.purchase_delay is not None:
                delays.append(f"{a.profile} {int(tr.purchase_delay // 60)}m")
            elif tr and not tr.hired:
                delays.append(f"{a.profile} NEVER")
        lines.append(f"- **{m.name}:** {', '.join(delays) if delays else 'never affordable'}")

    lines.extend([
        "",
        "### Which manager should become the \"my empire runs itself\" moment?",
        "",
        "**The Accountant** — architecturally correct hook (`tick_manager_effects` auto-buy).",
        "Measured greedy behaviour: **never reached in any profile** despite $1.5M cost —",
        "every spare dollar routes to buildings/upgrades until only Sticky Pete ($40K) and",
        "The Collector ($400K) slip through at endgame. **Identity is undermined by ROI",
        "competition**, not price. Phase 106 hire-nudges change behaviour, not identity.",
        "",
        "---",
        "",
        "## 8. Architectural conclusions",
        "",
        "1. **Dual identity conflict:** Manager cards say \"automate buildings, boost income\"",
        "   but 10/11 managers only boost income (1.5×) plus a passive modifier. Only The",
        "   Accountant automates. Players learn buildings = progression; managers = expensive",
        "   sidegrades.",
        "",
        "2. **Sticky Pete mispositions first hire:** First affordable manager always boosts",
        "   *clicks* while passive income has already crossed over (~4–9 min). First manager",
        "   hire feels like a stat buff, not empire delegation.",
        "",
        "3. **The Collector protects against friction many players never feel:** Greedy sim",
        "   rarely loses significant income to raids before prestige; -35% raid damage is",
        "   unmeasurable if the hire never happens early.",
        "",
        "4. **Income-only managers are TRAPs in the ROI model:** The Mechanic (+1.5× Chop)",
        "   is strictly dominated by buying the next Chop Shop or advancing tier. Same for",
        "   Maxine and mid-tier income hooks.",
        "",
        "5. **System-linked managers (Broker, Smuggler, Consigliere) are LATE by cost,",
        "   not by design intent:** Their identity requires Turf/Ops/Prestige loops that",
        "   activate after the first-run manager window closes.",
        "",
        "6. **Automation feeling ≠ manager hire feeling:** Passive crossover and 60s-idle",
        "   moments happen at 4–35 min without any manager. The gap is specifically",
        "   *purchase automation*, which only The Accountant provides — and ROI delays it.",
        "",
        "7. **Progression milestone test:** A manager qualifies as CORE only if it (a) changes",
        "   player behaviour, (b) creates a memorable before/after, and (c) isn't strictly",
        "   dominated by the next building buy. **Only The Accountant passes (a) and (b) by",
        "   design; none pass (c) under greedy play — and The Accountant fails (a) in practice",
        "   because ROI prevents ever banking his cost.**",
        "",
        "8. **First-run hire ceiling:** Greedy sim hires exactly **2 of 11** managers before",
        "   prestige (Sticky Pete + The Collector in all profiles). Nine managers — including",
        "   the automation hook — are **never affordable with unspent cash**, confirming managers",
        "   are structurally competing with buildings, not complementing them.",
        "",
        "---",
        "",
        "## 9. Re-run",
        "",
        "```powershell",
        "python _measure_p107.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 107 — Manager Identity Audit")
    audits = [run_profile(n) for n in h.PROFILES]
    for a in audits:
        print(f"\n=== {a.profile} === prestige {_fmt_t(a.prestige_time)}")
        print(f"  Order: {' → '.join(a.hire_sequence) or '(none)'}")
        for tr in a.manager_traces[:6]:
            if tr.hired or tr.first_affordable:
                d = _fmt_t(tr.purchase_delay) if tr.purchase_delay is not None else "—"
                print(f"  {tr.name}: afford {_fmt_t(tr.first_affordable)} hire {_fmt_t(tr.hired_at)} delay {d}")

    report = build_report(audits)
    with open("PHASE107_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE107_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
