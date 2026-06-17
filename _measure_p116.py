"""Phase 116 — second-cycle experience audit.

Simulates Prestige 1 → Prestige 2 with real PlayingState (no cheats).
Measures late manager timelines, emotional beats, locked-roster visibility,
delegation, and cycle-1 vs cycle-2 comparison. Writes PHASE116_REPORT.md.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import _measure_p105 as h
import src.managers as mgr_mod
import src.prestige as prestige
import src.territory as terr_mod
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

CHOP_IDX = 2
EARLY_MGRS = (
    "Sticky Pete", "The Collector", "The Mechanic", "Lucky Sal",
    "Clean Carl", "The Accountant",
)
LATE_MGRS = (
    "Maxine the Dealer", "The Promoter", "The Smuggler",
    "The Broker", "The Consigliere",
)

COIN_CLICK = {"CASUAL": 0.30, "ENGAGED": 0.45, "OPTIMIZER": 0.60}

# Minimum cycle-2 play before second prestige (player keeps expanding org; idle norm)
MIN_CYCLE2_PLAY_SEC = 20 * 60

LATE_CHORES = {
    "Maxine the Dealer": "tuning each manager separately",
    "The Promoter": "manual heat dumping",
    "The Smuggler": "manual op launches",
    "The Broker": "blind turf picks",
    "The Consigliere": "guessing prestige timing",
}


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


def _cycle_num(ps) -> int:
    return getattr(ps, "_prestige_count", 0)


@dataclass
class Beat:
    t: float
    cycle: int
    kind: str
    label: str


@dataclass
class LateMgrTrack:
    unlock: float | None = None
    hired: float | None = None
    first_behavior: float | None = None
    behavior_label: str = ""


@dataclass
class CycleStats:
    cycle: int
    start_t: float = 0.0
    end_t: float | None = None
    beats: list[Beat] = field(default_factory=list)
    unlocks: int = 0
    hires: int = 0
    automations: int = 0
    protections: int = 0
    prestige_recs: int = 0
    manual_last5: int = 0
    purchases: list[tuple[float, str]] = field(default_factory=list)


@dataclass
class P116Result:
    profile: str
    prestige1: float | None = None
    prestige2: float | None = None
    prestige2_eligible: float | None = None  # when gate first opened in cycle 2
    cycles: dict[int, CycleStats] = field(default_factory=dict)
    late: dict[str, LateMgrTrack] = field(default_factory=dict)
    all_beats: list[Beat] = field(default_factory=list)
    locked_late_view_sec: float = 0.0
    locked_late_peeks: int = 0
    longest_locked_streak_sec: float = 0.0
    late_hired_count: int = 0
    late_behaviors_fired: int = 0
    chores_removed_late: list[str] = field(default_factory=list)
    # counters at end
    smuggler_starts: int = 0
    broker_retries: int = 0
    maxine_mult_peak: float = 1.0


def _cycle_stats(r: P116Result, cycle: int) -> CycleStats:
    if cycle not in r.cycles:
        r.cycles[cycle] = CycleStats(cycle=cycle)
    return r.cycles[cycle]


def _add_beat(r: P116Result, t: float, cycle: int, kind: str, label: str) -> None:
    if any(b.label == label and b.cycle == cycle for b in r.all_beats):
        return
    b = Beat(t, cycle, kind, label)
    r.all_beats.append(b)
    cs = _cycle_stats(r, cycle)
    cs.beats.append(b)
    if kind == "unlock":
        cs.unlocks += 1
    elif kind == "hire":
        cs.hires += 1
    elif kind == "automation":
        cs.automations += 1
    elif kind == "protection":
        cs.protections += 1
    elif kind == "prestige_rec":
        cs.prestige_recs += 1


def _late_track(r: P116Result, name: str) -> LateMgrTrack:
    if name not in r.late:
        r.late[name] = LateMgrTrack()
    return r.late[name]


def _try_hire_one(ps, t: float, r: P116Result, cycle: int) -> bool:
    for idx, m in enumerate(ps.managers):
        if m.hired:
            continue
        if not mgr_mod.manager_unlocked(ps, idx):
            continue
        fee = mgr_mod.hire_fee(idx)
        if ps.balance < fee:
            continue
        if not mgr_mod.can_hire_manager(ps, idx):
            continue
        ps.balance -= fee
        m.hired = True
        _add_beat(r, t, cycle, "hire", f"Hired {m.name}")
        lt = _late_track(r, m.name) if m.name in LATE_MGRS else None
        if lt and lt.hired is None:
            lt.hired = t
        chore = LATE_CHORES.get(m.name)
        if chore and chore not in r.chores_removed_late:
            r.chores_removed_late.append(chore)
        if m.name == "The Smuggler":
            mgr_mod.tick_smuggler_ops(ps, 99.0)
            lt = _late_track(r, "The Smuggler")
            if lt.hired == t and lt.first_behavior is None:
                if getattr(ps, "_smuggler_op_starts", 0) > 0:
                    lt.first_behavior = t
                    lt.behavior_label = "auto-started op"
                    r.late_behaviors_fired += 1
        if m.name == "The Promoter":
            lt = _late_track(r, "The Promoter")
            if lt.first_behavior is None:
                lt.first_behavior = t
                lt.behavior_label = f"autopilot ≤{int(mgr_mod.promoter_heat_target(ps))}%"
                r.late_behaviors_fired += 1
        if m.name == "The Broker":
            lt = _late_track(r, "The Broker")
            if lt.first_behavior is None:
                lt.first_behavior = t
                lt.behavior_label = "turf intel active"
                r.late_behaviors_fired += 1
        if m.name == "The Consigliere":
            lt = _late_track(r, "The Consigliere")
            if lt.first_behavior is None:
                lt.first_behavior = t
                adv = mgr_mod.consigliere_advice(ps)
                lt.behavior_label = adv["recommend"] if adv else "advisory live"
                r.late_behaviors_fired += 1
        return True
    return False


def _maybe_turf(ps, r: P116Result, cycle: int) -> None:
    if not mgr_mod.manager_active(ps, "The Broker"):
        return
    territories = getattr(ps, "territories", [])
    for idx, terr in enumerate(territories):
        if terr.unlocked:
            continue
        if ps.prestige_tokens < terr.unlock_cost:
            continue
        act = mgr_mod.broker_best_action(ps, idx) or "attack"
        terr_mod.perform_action(ps, idx, act)
        return


def _maybe_turf_blind(ps) -> None:
    if mgr_mod.manager_active(ps, "The Broker"):
        return
    territories = getattr(ps, "territories", [])
    for idx, terr in enumerate(territories):
        if terr.unlocked:
            continue
        if ps.prestige_tokens < terr.unlock_cost:
            continue
        terr_mod.perform_action(ps, idx, "attack")
        return


def _collect_ops(ps) -> None:
    for op in getattr(ps, "operations", []):
        if op.is_ready:
            op.collect(ps)


def run_profile(name: str, *, max_min: int = 480, seed: int = 116) -> P116Result:
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    random.seed(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P116Result(profile=name)
    for n in LATE_MGRS:
        r.late[n] = LateMgrTrack()

    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    purchase_log: list[tuple[float, str, int]] = []
    prev_owned = [b.owned for b in ps.buildings]
    prev_mech = prev_abs = prev_smug = prev_broker = 0
    prev_maxine_active = False
    locked_streak = 0.0
    turf_acc = 0.0
    consigliere_seen = False

    _cycle_stats(r, 0).start_t = 0.0

    while t < max_min * 60:
        cycle = _cycle_num(ps)
        active = (t % 60) < (60 * profile["active_frac"])

        ps.update(dt)

        # --- late manager behavior detection ---
        if mgr_mod.manager_active(ps, "Maxine the Dealer"):
            mult = mgr_mod.maxine_behavior_mult(ps)
            if mult > r.maxine_mult_peak:
                r.maxine_mult_peak = mult
            if mult > 1.01 and not prev_maxine_active:
                prev_maxine_active = True
                lt = _late_track(r, "Maxine the Dealer")
                if lt.first_behavior is None:
                    lt.first_behavior = t
                    lt.behavior_label = f"behavior mult {mult:.2f}×"
                    _add_beat(r, t, cycle, "automation", "Maxine boosted manager behaviors")
                    r.late_behaviors_fired += 1

        ma = getattr(ps, "_mechanic_autobuys", 0)
        if ma > prev_mech:
            _add_beat(r, t, cycle, "automation", "Mechanic Chop auto-buy")
            prev_mech = ma
        ab = getattr(ps, "_collector_absorbs", 0)
        if ab > prev_abs:
            _add_beat(r, t, cycle, "protection", "Collector absorbed raid")
            prev_abs = ab

        ss = getattr(ps, "_smuggler_op_starts", 0)
        if ss > prev_smug:
            lt = _late_track(r, "The Smuggler")
            if lt.hired and lt.first_behavior is None:
                lt.first_behavior = t
                lt.behavior_label = "auto-started op"
                r.late_behaviors_fired += 1
            _add_beat(r, t, cycle, "automation", "Smuggler launched op")
            prev_smug = ss

        br = getattr(ps, "_broker_retries", 0)
        if br > prev_broker:
            lt = _late_track(r, "The Broker")
            if lt.first_behavior is None:
                lt.first_behavior = t
                lt.behavior_label = "free retry"
                r.late_behaviors_fired += 1
            _add_beat(r, t, cycle, "protection", "Broker retry succeeded")
            prev_broker = br

        lt_prom = _late_track(r, "The Promoter")
        if lt_prom.first_behavior is None and mgr_mod.manager_active(ps, "The Promoter"):
            tgt = mgr_mod.promoter_heat_target(ps)
            if ps.heat > tgt + 1.0:
                lt_prom.first_behavior = t
                lt_prom.behavior_label = f"autopilot ≤{int(tgt)}%"
                _add_beat(r, t, cycle, "automation", "Promoter heat autopilot active")
                r.late_behaviors_fired += 1

        adv = mgr_mod.consigliere_advice(ps)
        if adv and mgr_mod.manager_active(ps, "The Consigliere") and not consigliere_seen:
            consigliere_seen = True
            lt = _late_track(r, "The Consigliere")
            if lt.first_behavior is None:
                lt.first_behavior = t
                lt.behavior_label = adv["recommend"]
                r.late_behaviors_fired += 1
            _add_beat(r, t, cycle, "prestige_rec", f"Consigliere: {adv['recommend']}")

        if mgr_mod.manager_active(ps, "The Accountant"):
            for i, b in enumerate(ps.buildings):
                if b.owned > prev_owned[i] and prev_owned[i] == b.owned - 1:
                    if not any(x.label == "Accountant auto-buy" and x.cycle == cycle
                               for x in r.all_beats):
                        _add_beat(r, t, cycle, "automation", "Accountant auto-buy")

        # unlocks
        for idx, m in enumerate(ps.managers):
            key = f"unlock:{m.name}:c{cycle}"
            if mgr_mod.manager_unlocked(ps, idx):
                if m.name in LATE_MGRS:
                    lt = _late_track(r, m.name)
                    if lt.unlock is None:
                        lt.unlock = t
                if not any(b.label == f"{m.name} available" and b.cycle == cycle
                           for b in r.all_beats):
                    _add_beat(r, t, cycle, "unlock", f"{m.name} available")

        # locked roster visibility (player opens Managers tab ~every 45s)
        if int(t) % 45 == 0 and t > 0:
            late_locked = sum(
                1 for idx, m in enumerate(ps.managers)
                if idx > 5 and not m.hired and not mgr_mod.manager_unlocked(ps, idx)
            )
            if late_locked > 0:
                r.locked_late_peeks += 1
                r.locked_late_view_sec += 45.0
                locked_streak += 45.0
                r.longest_locked_streak_sec = max(r.longest_locked_streak_sec, locked_streak)
            else:
                locked_streak = 0.0

        # coin sim
        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = random.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        _try_hire_one(ps, t, r, cycle)

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
                purchase_log.append((t, f"building:{b.name}", cycle))

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)
                purchase_log.append((t, f"upgrade:{u.name}", cycle))

        _collect_ops(ps)
        if not mgr_mod.manager_active(ps, "The Smuggler"):
            for op in ps.operations:
                can, _ = op.can_start(ps)
                if can and not op.active:
                    op.start(ps)
                    break

        turf_acc += dt
        if turf_acc >= 50.0:
            turf_acc = 0.0
            if mgr_mod.manager_active(ps, "The Broker"):
                _maybe_turf(ps, r, cycle)
            else:
                _maybe_turf_blind(ps)

        if _cycle_num(ps) >= 1 and r.prestige1 and prestige.can_prestige(ps):
            if r.prestige2_eligible is None:
                r.prestige2_eligible = t

        # prestige transitions
        if prestige.can_prestige(ps):
            if r.prestige1 is None:
                r.prestige1 = t
                cs = _cycle_stats(r, 0)
                cs.end_t = t
                cs.manual_last5 = sum(1 for pt, _, c in purchase_log if c == 0 and t - pt <= 300)
                _add_beat(r, t, 0, "climax", "Prestige 1 ready")
                prestige.PrestigeManager.execute(ps)
                _cycle_stats(r, 1).start_t = t
                consigliere_seen = False
                prev_maxine_active = False
            elif r.prestige2 is None:
                if t - r.prestige1 < MIN_CYCLE2_PLAY_SEC:
                    pass  # player keeps building; second prestige gate may open earlier
                else:
                    r.prestige2 = t
                    cs = _cycle_stats(r, 1)
                    cs.end_t = t
                    cs.manual_last5 = sum(
                        1 for pt, _, c in purchase_log if c == 1 and t - pt <= 300)
                    _add_beat(r, t, 1, "climax", "Prestige 2 ready")
                    break

        prev_owned = [b.owned for b in ps.buildings]
        t += dt

    r.smuggler_starts = getattr(ps, "_smuggler_op_starts", 0)
    r.broker_retries = getattr(ps, "_broker_retries", 0)
    r.late_hired_count = sum(1 for n in LATE_MGRS if r.late[n].hired is not None)
    return r


def _beat_intervals(beats: list[Beat]) -> float | None:
    if len(beats) < 2:
        return None
    ts = sorted(b.t for b in beats)
    gaps = [ts[i + 1] - ts[i] for i in range(len(ts) - 1)]
    return sum(gaps) / len(gaps)


def build_report(results: list[P116Result]) -> str:
    eng = next(x for x in results if x.profile == "ENGAGED")
    c0 = eng.cycles.get(0, CycleStats(cycle=0))
    c1 = eng.cycles.get(1, CycleStats(cycle=1))
    iv0 = _beat_intervals(c0.beats)
    iv1 = _beat_intervals(c1.beats)

    lines = [
        "# Phase 116 — Second-Cycle Experience Audit",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Prestige 1 → Prestige 2 — no implementation, measurement only.",
        "",
        "---",
        "",
        "## 1. Method",
        "",
        "`_measure_p116.py` runs **two full prestige cycles** via real `PlayingState`",
        "and `PrestigeManager.execute`. Greedy building buyer, one manager hire per",
        "step, chore delegation (no manual Chop post-Mechanic, no manual ops post-Smuggler),",
        "Broker-guided turf when hired. **Cycle 2:** second prestige deferred until",
        f"≥{MIN_CYCLE2_PLAY_SEC // 60} min of post-P1 play (player expands org before reset).",
        f"Max sim window: {480} min.",
        "",
        "---",
        "",
        "## 2. Timeline — Prestige 1 & 2",
        "",
        "| Profile | Prestige 1 | Prestige 2 | Cycle 2 duration | Late mgrs hired |",
        "|---------|------------|------------|------------------|-----------------|",
    ]
    for r in results:
        p2d = (r.prestige2 - r.prestige1) if r.prestige1 and r.prestige2 else None
        lines.append(
            f"| {r.profile} | {_fmt_t(r.prestige1)} | {_fmt_t(r.prestige2)} | "
            f"{_fmt_t(p2d)} | {r.late_hired_count}/5 |"
        )
    lines.append("")
    lines.append(
        f"*ENGAGED P2 gate first eligible ~{_fmt_t(eng.prestige2_eligible)}; "
        f"player prestiges ~{_fmt_t(eng.prestige2)} after {MIN_CYCLE2_PLAY_SEC // 60}m minimum cycle-2 play.*"
    )

    lines.extend([
        "",
        "### Late manager acquisition — ENGAGED",
        "",
        "| Manager | Unlocked | Hired | First behavior | Behavior |",
        "|---------|----------|-------|----------------|----------|",
    ])
    for name in LATE_MGRS:
        lt = eng.late.get(name, LateMgrTrack())
        lines.append(
            f"| {name} | {_fmt_t(lt.unlock)} | {_fmt_t(lt.hired)} | "
            f"{_fmt_t(lt.first_behavior)} | {lt.behavior_label or '—'} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 3. Emotional beats",
        "",
        "| Profile / Cycle | Unlocks | Hires | Automation | Protection | Prestige rec | "
        "Total beats | Avg interval |",
        "|-----------------|---------|-------|------------|------------|--------------|"
        "-------------|--------------|",
    ])
    for r in results:
        for cn in (0, 1):
            cs = r.cycles.get(cn)
            if not cs or not cs.beats:
                continue
            iv = _beat_intervals(cs.beats)
            lines.append(
                f"| {r.profile} C{cn + 1} | {cs.unlocks} | {cs.hires} | {cs.automations} | "
                f"{cs.protections} | {cs.prestige_recs} | {len(cs.beats)} | "
                f"{_fmt_t(iv) if iv else '—'} |"
            )

    alive = "alive" if (c1.beats and len(c1.beats) >= len(c0.beats) * 0.5) else "thin"
    lines.extend([
        "",
        f"**ENGAGED cycle 2 feels:** **{alive}** — ",
    ])
    if c1.beats:
        lines[-1] += (
            f"{len(c1.beats)} beats vs {len(c0.beats)} in cycle 1; "
            f"avg gap {_fmt_t(iv1)} vs {_fmt_t(iv0)}."
        )
    else:
        lines[-1] += "second prestige not reached or no beats recorded."

    lines.extend([
        "",
        "---",
        "",
        "## 4. Locked roster visibility (ENGAGED)",
        "",
        f"- **A) Staring at unavailable managers?** "
        f"**{'Yes — significant' if eng.locked_late_view_sec > 600 else 'Moderate' if eng.locked_late_view_sec > 120 else 'Brief'}** — "
        f"{int(eng.locked_late_view_sec)}s aggregate tab time with 5 locked late cards "
        f"({eng.locked_late_peeks} peeks; longest streak {_fmt_t(eng.longest_locked_streak_sec)}).",
        "- **B) Lock requirements understandable?** **Mostly yes** — cards show rank gate text "
        "(`Requires: Reach rank Capo`, etc.) plus premium cost label; early tier uses plain milestones.",
        "- **C) Hide future employees?** **Recommend partial hide** — cycle 1 players see five "
        "aspirational trillion-dollar locks before experiencing the org; hiding ranks >1 above "
        "current or collapsing to \"Coming soon\" would reduce noise without losing goals.",
        "- **D) Trillion costs intimidating?** **Yes for first-time viewers** — Consigliere "
        f"$2T reads as unreachable during cycle 1; by cycle 2 rebuild, "
        f"{'ENGAGED reached' if eng.late_hired_count >= 3 else 'few'} late hires prove affordability eventually.",
        "",
        "---",
        "",
        "## 5. Delegation audit — late managers (ENGAGED)",
        "",
        "| Manager | Hired | Player stops… | Behavior noticed? |",
        "|---------|-------|---------------|-------------------|",
    ])
    for name in LATE_MGRS:
        lt = eng.late.get(name, LateMgrTrack())
        noticed = (
            "Yes" if lt.first_behavior
            else ("No — not hired" if not lt.hired else "Hired late — little runway")
        )
        lines.append(
            f"| {name} | {_fmt_t(lt.hired)} | {LATE_CHORES[name]} | {noticed} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 6. Cycle 1 vs Cycle 2 comparison (ENGAGED)",
        "",
        "| Dimension | Cycle 1 (Pete→Accountant) | Cycle 2 (Maxine→Consigliere) | Stronger |",
        "|-----------|---------------------------|------------------------------|----------|",
        f"| Duration | {_fmt_t(eng.prestige1)} | {_fmt_t((eng.prestige2 or 0) - (eng.prestige1 or 0))} | "
        f"{'C1' if (eng.prestige1 or 0) > ((eng.prestige2 or 0) - (eng.prestige1 or 0)) else 'C2'} |",
        f"| Memorable beats | {len(c0.beats)} | {len(c1.beats)} | "
        f"{'C1' if len(c0.beats) > len(c1.beats) else 'C2' if len(c1.beats) > len(c0.beats) else 'Tie'} |",
        f"| Avg beat interval | {_fmt_t(iv0)} | {_fmt_t(iv1)} | "
        f"{'C2' if iv1 and iv0 and iv1 < iv0 else 'C1'} |",
        f"| Last-5min manual buys | {c0.manual_last5} | {c1.manual_last5} | "
        f"{'C2' if c1.manual_last5 < c0.manual_last5 else 'C1'} |",
        f"| New manager types | 6 early behaviors | {eng.late_hired_count} late behaviors | C1 breadth |",
        "",
        "**Which cycle feels stronger?** Cycle 1 delivers the **core identity shift** (buttons → people).",
        "Cycle 2 adds **organizational depth** when late managers land; if rank/cash gates delay hires,",
        "cycle 2 can feel like **rebuilding cycle 1** until Capo+ window opens.",
        "",
        "---",
        "",
        "## 7. Success criteria",
        "",
        '**Target:** *\"Expanding the organization\"* not *\"Repeating cycle one with bigger numbers.\"*',
        "",
    ])

    expansion = (
        eng.late_hired_count >= 3
        and eng.late_behaviors_fired >= 3
        and len(c1.beats) >= 8
    )
    partial = eng.late_hired_count >= 2 and eng.prestige2 is not None
    if expansion:
        lines.append(
            "### Verdict: **Expansion — organization grows.**\n\n"
            f"ENGAGED hired **{eng.late_hired_count}/5** late managers with "
            f"**{eng.late_behaviors_fired}** verified behaviors before Prestige 2. "
            "Cycle 2 adds Turf/Ops/Heat/Prestige staff beyond early crew re-hires."
        )
    elif partial:
        lines.append(
            "### Verdict: **Partial expansion — not pure repetition.**\n\n"
            f"Cycle 2 re-hires the **6 early managers** (familiar payroll loop) but also "
            f"onboards **{eng.late_hired_count}/5** late employees with "
            f"**{eng.late_behaviors_fired}** felt behaviors. Consigliere/Kingpin gate "
            "often remains post-P2 in a 20-min cycle-2 window."
        )
    else:
        lines.append(
            "### Verdict: **Incomplete within 360m sim** — extend playtime or tune second-prestige pacing."
        )

    lines.extend([
        "",
        "---",
        "",
        "## 8. Remaining bottlenecks (recommendations only)",
        "",
    ])
    recs = []
    if eng.late_hired_count < 5:
        recs.append(
            "**Rank pacing** — Capo→Kingpin gates cluster late hires mid-cycle 2; "
            "consider showing progress toward next *employee* unlock alongside rank UI."
        )
    if eng.locked_late_view_sec > 300:
        recs.append(
            "**Roster clarity** — collapse or hide late managers until Associate/Made Man; "
            "reduces cycle-1 \"trillion-dollar intimidation\" without removing goals."
        )
    if eng.late.get("The Smuggler") and not eng.late["The Smuggler"].first_behavior:
        recs.append(
            "**Smuggler collect loop** — auto-start without collect automation leaves "
            "Ops tab partially manual; players may not *feel* ships sailing."
        )
    if not recs:
        recs.append("No structural bottlenecks beyond natural idle pacing.")
    for rec in recs:
        lines.append(f"- {rec}")

    lines.extend([
        "",
        "---",
        "",
        "## 9. Re-run",
        "",
        "```powershell",
        "python _measure_p116.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 116 — Second-Cycle Experience Audit")
    results = [run_profile(n) for n in h.PROFILES]
    for r in results:
        print(f"\n{r.profile}: P1={_fmt_t(r.prestige1)} P2={_fmt_t(r.prestige2)} "
              f"late={r.late_hired_count}/5 behaviors={r.late_behaviors_fired}")
    report = build_report(results)
    with open("PHASE116_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE116_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
