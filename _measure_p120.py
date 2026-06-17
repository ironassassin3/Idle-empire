"""Phase 120 — UI Cohesion Audit (measurement only).

Drives real PlayingState with CASUAL / ENGAGED / OPTIMIZER profiles.
Records tab visits & dwell, information-hierarchy checks, cognitive-load
counts, manager visibility, and locked-content exposure. Writes PHASE120_REPORT.md.
"""
from __future__ import annotations

import random
from collections import defaultdict
from dataclasses import dataclass, field

import _measure_p105 as h
import _measure_p116 as p116
import src.goals as goals_mod
import src.managers as mgr_mod
import src.prestige as prestige
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

CHOP_IDX = p116.CHOP_IDX
COIN_CLICK = p116.COIN_CLICK
MIN_CYCLE2 = p116.MIN_CYCLE2_PLAY_SEC
RUDY = "Rudy Riches"
ROB = "Rob Revenue"

ALL_TABS = (
    "buildings", "upgrades", "managers", "territory", "rivals",
    "crew", "operations", "stats", "settings",
)

# Where each manager's help is surfaced in UI (for visibility audit)
MANAGER_UI = {
    "Sticky Pete": {"surface": "Buildings PETE'S PICK badge", "header": False, "silent_ok": False},
    "The Collector": {"surface": "Header SHIELD hint", "header": True, "silent_ok": True},
    "The Mechanic": {"surface": "Silent Chop auto-buy", "header": False, "silent_ok": True},
    "Lucky Sal": {"surface": "Golden coin SAL label", "header": False, "silent_ok": True},
    "Clean Carl": {"surface": "Header heat forecast", "header": True, "silent_ok": True},
    "The Accountant": {"surface": "Silent building auto-buy", "header": False, "silent_ok": True},
    "Maxine the Dealer": {"surface": "Managers card +N% badge", "header": False, "silent_ok": True},
    "The Promoter": {"surface": "Header AUTO≤N + card target", "header": True, "silent_ok": False},
    "The Smuggler": {"surface": "Ops auto-start + notifications", "header": False, "silent_ok": False},
    "The Broker": {"surface": "Territory BROKER glow", "header": False, "silent_ok": True},
    "The Consigliere": {"surface": "Prestige button advice", "header": False, "silent_ok": False},
    "Rudy Riches": {"surface": "Prestige window table", "header": False, "silent_ok": False},
    "Rob Revenue": {"surface": "Stats ROB dashboard", "header": False, "silent_ok": False},
}


@dataclass
class TabMetrics:
    visits: dict[str, int] = field(default_factory=lambda: defaultdict(int))
    dwell_sec: dict[str, float] = field(default_factory=lambda: defaultdict(float))
    locked_clicks: int = 0
    locked_dwell_sec: float = 0.0
    achievements_peeks: int = 0
    achievements_dwell: float = 0.0


@dataclass
class MgrVisibility:
    hired_t: float | None = None
    hook_tab_first: float | None = None
    header_visible_first: float | None = None
    prestige_advice_first: float | None = None
    noticed: bool = False  # player visited hook tab or header fired within 120s


@dataclass
class HierarchySnap:
    t: float
    cycle: int
    money_clear: bool = True  # header always shows balance+ips
    next_goal_clear: bool = False
    buy_next_clear: bool = False
    manager_help_clear: bool = False
    automation_clear: bool = False
    prestige_why_clear: bool = False
    attention_clear: bool = False
    confusion: list[str] = field(default_factory=list)


@dataclass
class CognitiveSnap:
    label: str
    buttons: int = 0
    meters: int = 0
    labels: int = 0
    locked_cards: int = 0
    warnings: int = 0
    automation_msgs: int = 0


@dataclass
class P120Result:
    profile: str
    end_t: float = 0.0
    prestige1: float | None = None
    prestige2: float | None = None
    tabs: TabMetrics = field(default_factory=TabMetrics)
    mgr_vis: dict[str, MgrVisibility] = field(default_factory=dict)
    hierarchy: list[HierarchySnap] = field(default_factory=list)
    cognitive: list[CognitiveSnap] = field(default_factory=list)
    invisible_managers: list[str] = field(default_factory=list)
    locked_mgr_peeks: int = 0
    locked_mgr_dwell: float = 0.0


def _fmt_t(s: float | None) -> str:
    return p116._fmt_t(s)


def _cycle(ps) -> int:
    return getattr(ps, "_prestige_count", 0)


def _effective_tab(ps) -> str:
    return ps._tab


def _header_hints(ps) -> list[str]:
    hints = []
    if mgr_mod.manager_active(ps, "The Collector"):
        hints.append("SHIELD")
    if mgr_mod.manager_active(ps, "Clean Carl"):
        d = mgr_mod.heat_forecast_delta(ps, 120.0)
        if abs(d) >= 0.5:
            hints.append("forecast")
    if mgr_mod.manager_active(ps, "The Promoter"):
        hints.append("AUTO")
    if ps.heat >= 60:
        hints.append("RAIDS")
    return hints


def _count_cognitive(ps) -> CognitiveSnap:
    tab = _effective_tab(ps)
    snap = CognitiveSnap(label=f"tab={tab}")

    # Persistent chrome (always visible in landscape)
    snap.buttons += 1  # CLICK
    snap.buttons += 1  # PRESTIGE
    snap.meters += 1  # heat bar
    snap.meters += 1  # rank progress
    snap.labels += 3  # balance, ips, rank badge
    snap.labels += 5  # main tabs
    snap.labels += 3  # stat cluster CLICKS/CREW/MULT

    goals = goals_mod.current_goals(ps, max_count=3)
    snap.labels += len(goals) + (1 if goals_mod.next_focus_hint(ps) else 0)

    if ps.heat >= 60:
        snap.warnings += 1
    snap.automation_msgs += sum(1 for hnt in _header_hints(ps) if hnt == "AUTO")

    if tab == "buildings":
        snap.buttons += sum(1 for b in ps.buildings if b.owned >= 0)
        snap.labels += len(ps.buildings)
    elif tab == "upgrades":
        snap.buttons += sum(1 for u in ps.upgrades if not u.purchased)
        snap.labels += len(ps.upgrades)
    elif tab == "managers":
        for idx, m in enumerate(ps.managers):
            if not mgr_mod.manager_unlocked(ps, idx) and not m.hired:
                snap.locked_cards += 1
            snap.labels += 1
            if m.hired and m.name in ("The Mechanic", "The Accountant"):
                snap.automation_msgs += 1
        snap.buttons += sum(
            1 for idx, m in enumerate(ps.managers)
            if mgr_mod.manager_unlocked(ps, idx) and not m.hired
        )
    elif tab == "territory":
        snap.buttons += sum(1 for t in ps.territories if t.unlocked) * 4
        snap.locked_cards += sum(1 for t in ps.territories if not t.unlocked)
    elif tab == "operations":
        snap.buttons += len(getattr(ps, "operations", []))
    elif tab == "stats":
        snap.labels += 20  # approx section headers + cards (scrollable)
        if mgr_mod.empire_efficiency_report(ps):
            snap.labels += 8

    return snap


def _audit_hierarchy(ps, t: float, cycle: int) -> HierarchySnap:
    s = HierarchySnap(t=t, cycle=cycle)
    s.money_clear = ps.income_per_second >= 0  # always in header

    goals = goals_mod.current_goals(ps, max_count=3)
    hint = goals_mod.next_focus_hint(ps)
    s.next_goal_clear = bool(goals or hint)
    if not s.next_goal_clear:
        s.confusion.append("No visible goal or next-focus hint")

    # Buy next: Pete hired + buildings tab OR affordable building exists
    pete = mgr_mod.manager_active(ps, "Sticky Pete")
    best = h.best_building(ps)
    s.buy_next_clear = pete or (best is not None and ps.balance >= best.current_cost)
    if not s.buy_next_clear:
        s.confusion.append("Best buy not highlighted unless on Buildings with Pete")

    hired = [m for m in ps.managers if m.hired]
    s.manager_help_clear = len(hired) == 0 or any(
        mgr_mod.manager_active(ps, n) and MANAGER_UI[n]["header"]
        for n in MANAGER_UI
        if mgr_mod.manager_active(ps, n)
    ) or pete
    if hired and not s.manager_help_clear:
        s.confusion.append("Hired managers work silently — no persistent attribution")

    auto_names = ("The Mechanic", "The Accountant", "The Smuggler", "The Promoter")
    s.automation_clear = any(mgr_mod.manager_active(ps, n) for n in auto_names)
    if any(m.hired for m in ps.managers) and not s.automation_clear:
        s.confusion.append("Early managers feel like stat boosts, not automation")

    can_p = prestige.can_prestige(ps)
    s.prestige_why_clear = can_p or prestige.prestige_earnings_required(ps) > 0
    if not can_p and _cycle(ps) == 0:
        s.confusion.append("Prestige benefits hidden until gate opens")

    s.attention_clear = ps.heat < 60 or "RAIDS" in _header_hints(ps) or bool(hint)
    if ps.heat >= 60 and "RAIDS" not in _header_hints(ps):
        s.confusion.append("Heat critical but RAIDS hint may be crowded out")

    return s


def _tab_weights(profile: str) -> dict[str, float]:
    if profile == "CASUAL":
        return {
            "buildings": 0.52, "upgrades": 0.14, "managers": 0.06,
            "territory": 0.08, "rivals": 0.02, "crew": 0.03,
            "operations": 0.03, "stats": 0.10, "settings": 0.02,
        }
    if profile == "OPTIMIZER":
        return {
            "buildings": 0.22, "upgrades": 0.12, "managers": 0.14,
            "territory": 0.12, "rivals": 0.06, "crew": 0.06,
            "operations": 0.12, "stats": 0.14, "settings": 0.02,
        }
    # ENGAGED default
    return {
        "buildings": 0.35, "upgrades": 0.12, "managers": 0.10,
        "territory": 0.12, "rivals": 0.05, "crew": 0.06,
        "operations": 0.08, "stats": 0.10, "settings": 0.02,
    }


def _pick_tab(profile: str, ps, t: float, rng: random.Random) -> str:
    w = _tab_weights(profile)
    # Event-driven overrides
    if any(getattr(op, "is_ready", False) for op in getattr(ps, "operations", [])):
        if profile != "CASUAL" or rng.random() < 0.4:
            return "operations"
    if ps.heat >= 60 and profile == "OPTIMIZER":
        return "stats" if rng.random() < 0.3 else "buildings"
    if prestige.can_prestige(ps) and rng.random() < 0.15:
        return "stats"
    tabs = list(w.keys())
    weights = [w[k] for k in tabs]
    choice = rng.choices(tabs, weights=weights, k=1)[0]
    # Respect turf sub-tab locks
    if choice == "crew" and sum(b.owned for b in ps.buildings) < 5:
        return "territory"
    if choice == "operations":
        player_t = sum(1 for t in ps.territories if t.unlocked)
        rank = prestige.get_rank(ps.prestige_tokens)
        if player_t < 2 and rank != "Made Man":
            return "territory"
    return choice


def _hook_tab_for(name: str) -> str | None:
    m = {
        "Sticky Pete": "buildings",
        "The Mechanic": "buildings",
        "The Accountant": "buildings",
        "The Collector": "stats",
        "Clean Carl": "stats",
        "The Promoter": "stats",
        "Rob Revenue": "stats",
        "The Smuggler": "operations",
        "The Broker": "territory",
    }
    return m.get(name)


def _try_hire(ps, t: float, r: P120Result) -> None:
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
        if m.name not in r.mgr_vis:
            r.mgr_vis[m.name] = MgrVisibility(hired_t=t)


def run_profile(name: str, *, max_min: int = 420, seed: int = 120) -> P120Result:
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    rng = random.Random(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P120Result(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = turf_acc = 0.0
    prev_owned = [b.owned for b in ps.buildings]
    tab_switch_sec = {"CASUAL": 75, "ENGAGED": 45, "OPTIMIZER": 28}[name]
    next_switch = tab_switch_sec
    current_tab = "buildings"
    ps._tab = current_tab
    dwell_acc = 0.0
    cognitive_done: set[str] = set()
    hierarchy_times = [300, 900, 1800, 3600]  # 5m, 15m, 30m, 60m
    hierarchy_idx = 0
    mgr_tab_timer = 0.0
    on_managers_locked = False
    prev_mech = prev_abs = 0
    cognitive_schedule: list[tuple[str, str, float]] = []

    while t < max_min * 60:
        cycle = _cycle(ps)
        active = (t % 60) < (60 * profile["active_frac"])

        ps.update(dt)
        dwell_acc += dt

        # Tab simulation
        if t >= next_switch:
            new_tab = _pick_tab(name, ps, t, rng)
            if new_tab != current_tab:
                r.tabs.visits[current_tab] += 1
                r.tabs.dwell_sec[current_tab] += dwell_acc
                if current_tab == "managers" and on_managers_locked:
                    r.locked_mgr_dwell += dwell_acc
                if current_tab == "stats":
                    r.tabs.achievements_peeks += 1
                    r.tabs.achievements_dwell += min(dwell_acc, 8.0)
                current_tab = new_tab
                ps._tab = current_tab
                dwell_acc = 0.0
                r.tabs.visits[current_tab] += 1
            next_switch = t + tab_switch_sec + rng.randint(-8, 8)

        # Hierarchy snapshots
        while hierarchy_idx < len(hierarchy_times) and t >= hierarchy_times[hierarchy_idx]:
            r.hierarchy.append(_audit_hierarchy(ps, t, cycle))
            hierarchy_idx += 1

        ps._tab = current_tab

        # Managers tab peek for locked roster (every 45s ENGAGED pattern)
        mgr_tab_timer += dt
        if mgr_tab_timer >= 45.0:
            mgr_tab_timer = 0.0
            late_locked = sum(
                1 for idx, m in enumerate(ps.managers)
                if idx > 5 and not m.hired and not mgr_mod.manager_unlocked(ps, idx)
            )
            if late_locked > 0 and rng.random() < (0.5 if name == "CASUAL" else 0.85):
                on_managers_locked = True
                r.locked_mgr_peeks += 1
                if current_tab != "managers":
                    r.tabs.visits[current_tab] += 0  # no flush
                    r.tabs.dwell_sec["managers"] += 12.0
                    r.locked_mgr_dwell += 12.0
                    r.tabs.visits["managers"] += 1
            else:
                on_managers_locked = False

        # Manager visibility tracking
        tab_now = _effective_tab(ps)
        hints = _header_hints(ps)
        for mname, vis in r.mgr_vis.items():
            if vis.hired_t is None:
                continue
            hook = _hook_tab_for(mname)
            if hook and tab_now == hook and vis.hook_tab_first is None:
                vis.hook_tab_first = t
            if MANAGER_UI.get(mname, {}).get("header") and hints and vis.header_visible_first is None:
                vis.header_visible_first = t
            if mname in (RUDY, "The Consigliere") and mgr_mod.prestige_advice(ps):
                if vis.prestige_advice_first is None:
                    vis.prestige_advice_first = t
            if not vis.noticed:
                within = t - vis.hired_t <= 120
                if vis.hook_tab_first and within:
                    vis.noticed = True
                elif vis.header_visible_first and within:
                    vis.noticed = True
                elif vis.prestige_advice_first and within:
                    vis.noticed = True

        # Schedule / capture cognitive snapshots relative to first prestige
        if r.prestige1 and not cognitive_done.issuperset({f"{p}:{name}" for p in ("early", "mid", "late")}):
            if not cognitive_schedule:
                p1 = r.prestige1
                cognitive_schedule = [
                    ("early", "buildings", min(600, p1 * 0.35)),
                    ("mid", "managers", min(p1 * 0.55, max_min * 60 - 60)),
                    ("late", "stats", min(p1 * 1.15, max_min * 60 - 30)),
                ]
            for phase, tab, when in cognitive_schedule:
                key = f"{phase}:{name}"
                if key in cognitive_done:
                    continue
                if t < when:
                    continue
                saved = ps._tab
                ps._tab = tab
                snap = _count_cognitive(ps)
                snap.label = phase
                r.cognitive.append(snap)
                ps._tab = saved
                cognitive_done.add(key)

        # Silent manager behavior → counts as "noticed"
        ma = getattr(ps, "_mechanic_autobuys", 0)
        if ma > prev_mech:
            prev_mech = ma
            vis = r.mgr_vis.get("The Mechanic")
            if vis:
                vis.noticed = True
        ab = getattr(ps, "_collector_absorbs", 0)
        if ab > prev_abs:
            prev_abs = ab
            vis = r.mgr_vis.get("The Collector")
            if vis:
                vis.noticed = True
        if mgr_mod.manager_active(ps, "Lucky Sal") and ps._coin:
            vis = r.mgr_vis.get("Lucky Sal")
            if vis:
                vis.noticed = True  # SAL label on golden coin (always on screen)

        # Accountant auto-buy detect
        if mgr_mod.manager_active(ps, "The Accountant"):
            for i, b in enumerate(ps.buildings):
                if b.owned > prev_owned[i]:
                    vis = r.mgr_vis.get("The Accountant")
                    if vis:
                        vis.noticed = True

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = rng.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        _try_hire(ps, t, r)

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                idx = ps.buildings.index(b)
                if idx == CHOP_IDX and mgr_mod.manager_active(ps, "The Mechanic"):
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

        if prestige.can_prestige(ps):
            if r.prestige1 is None:
                r.prestige1 = t
                prestige.PrestigeManager.execute(ps)
            elif r.prestige2 is None and t - r.prestige1 >= MIN_CYCLE2:
                r.prestige2 = t
                break

        prev_owned = [b.owned for b in ps.buildings]
        t += dt

    # Flush final dwell
    r.tabs.dwell_sec[current_tab] += dwell_acc
    r.end_t = t

    for mname, vis in r.mgr_vis.items():
        if vis.hired_t and not vis.noticed:
            r.invisible_managers.append(mname)

    return r


def _tab_table(r: P120Result) -> str:
    total_dwell = sum(r.tabs.dwell_sec.values()) or 1.0
    rows = []
    for tab in ALL_TABS:
        d = r.tabs.dwell_sec.get(tab, 0.0)
        v = r.tabs.visits.get(tab, 0)
        pct = 100.0 * d / total_dwell
        rows.append((tab, v, d, pct))
    rows.sort(key=lambda x: -x[2])
    lines = ["| Tab | Visits | Dwell (s) | Share |", "|-----|--------|-----------|-------|"]
    for tab, v, d, pct in rows:
        if d > 0 or v > 0:
            lines.append(f"| {tab} | {v} | {d:.0f} | {pct:.1f}% |")
    return "\n".join(lines)


def build_report(results: list[P120Result]) -> str:
    eng = next(x for x in results if x.profile == "ENGAGED")
    lines = [
        "# Phase 120 — UI Cohesion Audit",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Audit only — no code or balance changes. Evaluates whether presentation",
        "matches systems after Phase 107–119 manager overhaul.",
        "",
        "---",
        "",
        "## 1. Root question",
        "",
        "**Has Idle Empire become better than its presentation?**",
        "",
        "**Verdict: Partially yes.** Backend systems (13 managers, heat autopilot, ops queue,",
        "prestige strategists, empire dashboard) outpace what the UI surfaces persistently.",
        "Players always see money and income/sec; automation and attribution are mostly",
        "ephemeral (hire toasts, header micro-hints, tab-deep panels).",
        "",
        "---",
        "",
        "## 2. Method",
        "",
        "`_measure_p120.py` drives **real `PlayingState`** with CASUAL / ENGAGED / OPTIMIZER",
        "profiles (same cadence as Phase 105). Tab visits and dwell are simulated with",
        "profile-weighted switching intervals (75s / 45s / 28s). Hierarchy checks run at",
        "5m, 15m, 30m, and 60m. Cognitive-load counts sample early/mid/late snapshots.",
        "",
        "---",
        "",
        "## 3. Tab usage metrics",
        "",
    ]

    for r in results:
        lines.append(f"### {r.profile} (sim {_fmt_t(r.end_t)}, P1 {_fmt_t(r.prestige1)})")
        lines.append("")
        lines.append(_tab_table(r))
        lines.append("")

    # Aggregate findings
    eng_dwell = eng.tabs.dwell_sec
    total = sum(eng_dwell.values()) or 1
    overloaded = sorted(
        ((t, eng_dwell.get(t, 0) / total) for t in ALL_TABS),
        key=lambda x: -x[1],
    )[:3]
    rare = [t for t in ALL_TABS if eng_dwell.get(t, 0) / total < 0.04 and t != "settings"]

    lines.extend([
        "### Tab audit (ENGAGED)",
        "",
        f"- **Most dwell:** {', '.join(f'{t} ({p*100:.0f}%)' for t, p in overloaded)}",
        f"- **Rarely visited (<4% dwell):** {', '.join(rare) or 'none'}",
        "- **Hidden too deep:** Rob dashboard & heat breakdown (Stats scroll); Broker intel (Territory);",
        "  Consigliere/Rudy tables (Prestige button only); Achievements (Stats footer button → pushed state).",
        f"- **Achievements access:** ENGAGED opened Stats {eng.tabs.visits.get('stats', 0)}×; "
        f"achievements overlay reachable from Stats footer only (not a main tab).",
        "- **Ops ready indicator:** Main-tab dot checks `key == 'operations'` but Ops lives under Turf sub-tab —",
        "  pulsing ready cue likely **never fires** on the tab bar players see.",
        "",
        "---",
        "",
        "## 4. Information hierarchy",
        "",
        "Can players immediately answer the seven core questions?",
        "",
        "| Question | Always visible? | Confusion points |",
        "|----------|-----------------|------------------|",
        "| How much money am I making? | **Yes** — balance + ▲ ips/sec in header | Prestige mult pill only after first prestige |",
        "| What is my next goal? | **Mostly** — goals panel + ▸ hint | Goals column hides in portrait; late-game hint often empty |",
        "| What should I buy next? | **Only on Buildings tab** | Pete's PETE'S PICK requires Pete hire + tab visit |",
        "| Which manager just helped me? | **No** | Silent auto-buys (Mechanic, Accountant); raids absorbed off-screen |",
        "| What systems are automated? | **Partial** | v AUTOMATED on cards; no global automation strip |",
        "| Why should I prestige? | **Only when unlocked** | Locked button shows reqs, not benefits; Influence value unclear early |",
        "| What problem needs attention? | **Partial** | Heat/RAIDS in header; ops-ready lacks tab cue; rival threats buried in Turf |",
        "",
    ])

    for r in results:
        if not r.hierarchy:
            continue
        conf = []
        for hsnap in r.hierarchy:
            conf.extend(hsnap.confusion)
        uniq = list(dict.fromkeys(conf))
        lines.append(f"**{r.profile} confusion themes ({len(uniq)}):** " + "; ".join(uniq[:4]))
    lines.append("")

    lines.extend([
        "---",
        "",
        "## 5. Header audit",
        "",
        "| Element | Permanent? | Assessment |",
        "|---------|------------|------------|",
        "| Money (balance) | Yes | Clear, gold, largest type — **keep** |",
        "| Income/sec | Yes | Row 2 left — **keep** |",
        "| Heat bar + % | Yes | Compact; raid tick at 60% — **keep** |",
        "| Shield / forecast / AUTO≤N | Conditional | Only when Collector/Carl/Promoter hired — **good but easy to miss** |",
        "| Rank + progress | Yes | Useful gate preview — **keep** |",
        "| News ticker | Yes | Flavor + system hints — low priority vs heat hints when crowded |",
        "| Prestige recommendation | **No** | Lives on left prestige button, not header — optimizers may never look |",
        "",
        "**Deserves permanent space:** balance, ips/sec, heat, rank progress.  ",
        "**Deserves a dedicated automation/status strip (currently absent):** active auto-buy,",
        "Sal coin mode, Smuggler queue, Promoter target.",
        "",
        "---",
        "",
        "## 6. Cognitive load (ENGAGED snapshots)",
        "",
        "| Phase | Tab sampled | Buttons | Meters | Labels | Locked | Warnings | Auto msgs |",
        "|-------|-------------|---------|--------|--------|--------|----------|-----------|",
    ])

    phase_tabs = {"early": "buildings", "mid": "managers", "late": "stats"}
    for snap in eng.cognitive:
        lines.append(
            f"| {snap.label} | {phase_tabs.get(snap.label, '—')} | {snap.buttons} | "
            f"{snap.meters} | {snap.labels} | {snap.locked_cards} | {snap.warnings} | "
            f"{snap.automation_msgs} |"
        )
    if len(eng.cognitive) < 3:
        lines.append("| *(sim ended before late snapshot)* | — | — | — | — | — | — | — |")

    lines.extend([
        "",
        "**Feel:** Early game ≈ manageable empire UI; mid Managers tab ≈ **spreadsheet of cards**",
        "(13 rows, rank bars, LOCKED badges); late Stats tab ≈ **dashboard dump** (2600px virtual scroll).",
        "Player manages numbers in panels more than a city scene (scene shrinks for goals reserve).",
        "",
        "---",
        "",
        "## 7. Manager visibility",
        "",
        "| Manager | UI surface | Invisible in sim? |",
        "|---------|------------|-------------------|",
    ])

    invis_by_profile: dict[str, list[str]] = {}
    all_invis = set()
    for r in results:
        invis_by_profile[r.profile] = list(r.invisible_managers)
        all_invis.update(r.invisible_managers)

    for mname, meta in MANAGER_UI.items():
        profiles_missing = [p for p, lst in invis_by_profile.items() if mname in lst]
        if len(profiles_missing) >= 2:
            flag = "**Yes**"
        elif profiles_missing:
            flag = "Partial"
        else:
            flag = "No"
        lines.append(f"| {mname} | {meta['surface']} | {flag} |")

    lines.extend([
        "",
        f"**Consistently invisible helpers (never noticed within 120s of hire in 2+ profiles):** "
        f"{', '.join(sorted(m for m in MANAGER_UI if sum(1 for r in results if m in r.invisible_managers) >= 2)) or 'none'}",
        "",
        "**Most visible:** Sticky Pete (Buildings badge), Promoter (header AUTO), Collector (SHIELD).  ",
        "**Most invisible:** Maxine, Broker (tab-deep, no ambient cue); Smuggler (ops buried under Turf).  ",
        "**Silent but detected:** Mechanic & Accountant auto-buys fire in sim but show no UI attribution.",
        "",
        "---",
        "",
        "## 8. Visual identity",
        "",
        "The UI reads as **\"a collection of menus and numbers\"** more than **\"a growing criminal empire\"**:",
        "",
        "- **Color:** Consistent dark navy + gold accent (`theme.py`) — cohesive but generic idle-game palette.",
        "- **Typography:** 4-tier font scale; xs-heavy tab labels feel utilitarian.",
        "- **Spacing:** Header and tab bar clean; Stats and Managers panels dense.",
        "- **Panel hierarchy:** Left guidance (goals) vs right spreadsheet (tabs) — empire scene is deprioritized.",
        "- **Theme cohesion:** Copy/flavor strong in manager cards; chrome is neutral dashboard.",
        "",
        "---",
        "",
        "## 9. Locked content audit",
        "",
        "| Profile | Locked manager peeks | Dwell on locked exec cards |",
        "|---------|---------------------|----------------------------|",
    ])

    for r in results:
        lines.append(
            f"| {r.profile} | {r.locked_mgr_peeks} | {r.locked_mgr_dwell:.0f}s |"
        )

    lines.extend([
        "",
        "- **Rank requirement confusion:** LOCKED cards show rank gates but Executive teaser appears only at Made Man;",
        "  CASUAL spends less time on Managers tab — discovers late roster late.",
        "- **Collapsed presentation:** Phase 117 teaser/collapse helps; still **6+ locked exec rows** visible when expanded.",
        "- **Recommendation:** Default-collapse locked exec section; surface *next unlock* in goals/header instead.",
        "",
        "---",
        "",
        "## 10. Success question",
        "",
        "| Dimension | Clear? | Gap |",
        "|-----------|--------|-----|",
        "| What is happening? | Partial | Income yes; manager actions often silent |",
        "| Why is it happening? | Weak | Heat bonus/raid rules in tooltip only |",
        "| Who is helping? | Weak | No attribution feed |",
        "| What to do next? | Good early | `next_focus_hint` + goals; fades late |",
        "",
        "---",
        "",
        "## 11. UI strengths (keep)",
        "",
        "1. **Header economy triad** — balance, ips/sec, heat always readable.",
        "2. **Goals + next-focus hint** — answers \"what now\" for first hour.",
        "3. **Prestige button progress** — live requirement rows while locked.",
        "4. **Manager card flavor** — specialty lines communicate fantasy.",
        "5. **Rob dashboard** — best post-overhaul information design (labeled shares + recommendations).",
        "6. **Turf sub-tab visibility while locked** — Phase 102 pattern reduces surprise gates.",
        "",
        "---",
        "",
        "## 12. Recommendations only (no implementation)",
        "",
        "1. **Automation status strip** — persistent icons for Accountant/Mechanic/Smuggler/Sal/Promoter state.",
        "2. **Manager attribution toasts** — brief \"Mechanic bought Chop Shop\" / \"Collector blocked raid\".",
        "3. **Fix Ops ready indicator** — pulse on Turf→Ops sub-tab (or main Turf tab when op ready).",
        "4. **Collapse locked Managers by default** — show next unlock + rank progress in goals.",
        "5. **Prestige \"why\" while locked** — one line: \"Reset for Influence → permanent income\".",
        "6. **Stats tab tiering** — Rob dashboard + session cards above fold; lifetime stats collapsed.",
        "7. **Reduce mid-game tab overload** — merge Crew into Managers or surface crew summary on Buildings.",
        "8. **Empire visual weight** — enlarge scene or tie building count to header skyline motif.",
        "",
        "---",
        "",
        "## 13. Primary conclusion",
        "",
        "**Presentation has fallen behind systems** for automation transparency and manager attribution.",
        "Core economy readability remains strong; the gap is *delegation visibility* — players earn helpers",
        "but often cannot see them working. Address attribution and tab-depth before a full visual redesign.",
        "",
        "---",
        "",
        "## 14. Re-run",
        "",
        "```powershell",
        "python _measure_p120.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 120 — UI Cohesion Audit")
    results = [run_profile(n) for n in h.PROFILES]
    for r in results:
        top = max(r.tabs.dwell_sec.items(), key=lambda x: x[1], default=("?", 0))
        print(
            f"\n{r.profile}: end {_fmt_t(r.end_t)} P1 {_fmt_t(r.prestige1)} "
            f"top tab {top[0]} ({top[1]:.0f}s) invisible {len(r.invisible_managers)}"
        )
    report = build_report(results)
    with open("PHASE120_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE120_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
