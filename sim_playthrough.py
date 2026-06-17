"""
Session 2 — EXPERIENTIAL playthrough of the REAL game.

Drives the actual PlayingState through: fresh save -> first prestige ->
continue -> second prestige. Captures the *experience timeline*: every
notification/toast/rank-up/milestone (the "wow moment" candidates), what
unlocks when, income at each beat, and the critical before/after-prestige feel.

This is the boredom detector. sim_harness.py finds balance problems; this finds
emotional dead zones.
"""
from __future__ import annotations
import os, sys, io
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
# Force UTF-8 stdout so notification arrows/symbols don't crash on Windows cp1252
try:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
except Exception:
    pass
import pygame
pygame.init()
pygame.display.set_mode((900, 720))

import config
import src.ui as ui
import src.theme as theme
import src.prestige as prestige
import src.buildings as bld
from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import delete_save

# ─── Capture all notifications with timestamps ──────────────────────────────────
EVENT_LOG: list[tuple[float, str]] = []
_now = {'t': 0.0}
_orig_push = ui.push_notification

def _capturing_push(text, color=None):
    EVENT_LOG.append((_now['t'], text))
    return _orig_push(text, color)

ui.push_notification = _capturing_push


def fmt_t(s):
    return f"{int(s//60)}m{int(s%60):02d}s"

def fmt_money(n):
    return theme.format_number(n)


class Player:
    """A simple AI player driving the real PlayingState via its real methods.

    Buys the best-value building it can afford at a human-ish cadence, buys
    affordable upgrades, hires affordable managers, assigns crew, and captures
    territory / does one rival action when sensible — using the SAME code paths
    the UI click handlers use.
    """
    def __init__(self, ps, clicks_per_sec=1.0, buys_per_sec=0.5):
        self.ps = ps
        self.cps = clicks_per_sec
        self.bps = buys_per_sec
        self._click_acc = 0.0
        self._buy_acc = 0.0
        self._did_rival = False

    def act(self, dt, t, active):
        ps = self.ps
        # clicks (the real click value path)
        if active:
            self._click_acc += self.cps * dt
            while self._click_acc >= 1.0:
                cv = ps.click_value
                ps.balance += cv
                ps.lifetime_earnings += cv
                ps._click_count += 1
                self._click_acc -= 1.0
        # buys
        self._buy_acc += self.bps * dt
        while self._buy_acc >= 1.0:
            self._buy_acc -= 1.0
            b = self._best_building()
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1
        # upgrades (real apply path)
        for u in ps.upgrades:
            if not u.purchased:
                import src.upgrades as upg
                cost = upg._effective_cost(u, ps)
                if ps.balance >= cost:
                    ps.balance -= cost
                    u.purchased = True
                    u.apply(ps)
        # managers
        for m in ps.managers:
            if not m.hired and ps.balance >= m.cost:
                ps.balance -= m.cost
                m.hired = True
                ui.push_notification(f"Hired {m.name}", theme.GREEN)
        # crew -> collection
        total_crew = sum(b.owned for b in ps.buildings)
        ps.crew.collection = total_crew
        # territory: capture next available (real perform_action via negotiate)
        import src.territory as terr_mod
        if sum(b.owned for b in ps.buildings) >= 15:
            for idx, terr in enumerate(ps.territories):
                if not terr.unlocked and ps.prestige_tokens >= terr.unlock_cost:
                    out = terr_mod.perform_action(ps, idx, 'negotiate')
                    ui.push_notification(out[:36], theme.TEXT_GOLD)
                    break
        # one rival interaction once we have spare cash (real path)
        if not self._did_rival and ps.balance > 50_000 and getattr(ps, 'rivals', None):
            import src.rivals as riv
            out = riv.perform_action(ps, 0, 'attack')
            ui.push_notification(f"Rival: {out[:30]}", theme.RED)
            self._did_rival = True

    def _best_building(self):
        best, br = None, 0.0
        for b in self.ps.buildings:
            c = b.current_cost
            if c <= 0 or self.ps.balance < c:
                continue
            r = (b.base_income * b.income_multiplier) / c
            if r > br:
                br, best = r, b
        return best


def run_playthrough(max_minutes=120, prestige_target=2):
    delete_save()
    sm = StateManager()
    ps = PlayingState(sm)
    ps.on_enter()
    player = Player(ps, clicks_per_sec=1.0, buys_per_sec=0.5)

    t = 0.0
    dt = 0.5
    marks = {}
    prestige_times = []
    last_rank = prestige.get_rank(ps.prestige_tokens)
    last_tabs = set()
    income_at_prestige = []

    def mark(k):
        if k not in marks:
            marks[k] = t

    while t < max_minutes * 60 and len(prestige_times) < prestige_target:
        _now['t'] = t
        active = (t % 60) < 20   # player actively engages ~20s of each minute
        ps.update(dt)
        player.act(dt, t, active)

        # milestone marks
        if any(u.purchased for u in ps.upgrades): mark('first_upgrade')
        if ps.prestige_tokens >= 1: mark('first_influence')
        if any(m.hired for m in ps.managers): mark('first_manager')
        if any(tt.unlocked and tt.name != 'South Side' for tt in ps.territories): mark('first_territory')
        if player._did_rival: mark('first_rival')

        # tab unlocks
        tabs = set(k for _, k in prestige.visible_tabs(ps))
        new_tabs = tabs - last_tabs
        for nt in new_tabs:
            if t > 0:
                EVENT_LOG.append((t, f"[TAB UNLOCKED] {nt}"))
        last_tabs = tabs

        # rank ups
        rank = prestige.get_rank(ps.prestige_tokens)
        if rank != last_rank:
            EVENT_LOG.append((t, f"[RANK UP] {rank}"))
            last_rank = rank

        # prestige when available
        if prestige.can_prestige(ps):
            mark(f'prestige_{len(prestige_times)+1}_eligible')
            ips_before = ps.income_per_second
            tok_before = ps.prestige_tokens
            gain = prestige.calc_influence_gain(ps.lifetime_earnings)
            prestige.PrestigeManager.execute(ps)
            prestige_times.append(t)
            EVENT_LOG.append((t, f"[PRESTIGE #{len(prestige_times)}] +{gain} Influence "
                                 f"(now {ps.prestige_tokens}), income x{prestige.income_mult(ps.prestige_tokens):.2f}"))
            income_at_prestige.append((t, ips_before, gain, ps.prestige_tokens))

        t += dt

    return ps, marks, prestige_times, income_at_prestige, t


if __name__ == "__main__":
    ps, marks, ptimes, inc_p, end_t = run_playthrough()

    print("=" * 72)
    print("SESSION 2 — REAL PLAYTHROUGH (fresh save, 1 click/s, ~33% active)")
    print("=" * 72)

    print("\nFRESH-SAVE MILESTONES:")
    for k, label in [('first_upgrade','first upgrade'), ('first_influence','first Influence'),
                     ('first_territory','first territory'), ('first_manager','first manager'),
                     ('first_rival','first rival interaction'),
                     ('prestige_1_eligible','first prestige eligible')]:
        print(f"  {label:28s}: {fmt_t(marks[k]) if k in marks else 'NEVER'}")

    print("\nPRESTIGE EVENTS:")
    for i,(pt, ips, gain, newtok) in enumerate(inc_p, 1):
        print(f"  Prestige #{i} @ {fmt_t(pt)}: income before = {fmt_money(ips)}/s, "
              f"+{gain} Influence -> {newtok} total ({prestige.get_rank(newtok)}), "
              f"perm income x{prestige.income_mult(newtok):.2f}")

    if len(ptimes) >= 2:
        gap = ptimes[1] - ptimes[0]
        print(f"\n  SECOND PRESTIGE GAP: {fmt_t(gap)} after first")

    print("\nFULL EXPERIENCE TIMELINE (every notification/event):")
    for et, txt in EVENT_LOG:
        tag = ""
        if "[" in txt: tag = "  <<<"
        print(f"  {fmt_t(et):>7}  {txt}{tag}")

    # Dead-zone analysis: gaps between events > 90s
    print("\nDEAD ZONES (>90s with no notification — boredom risk):")
    prev = 0.0
    any_dead = False
    for et, txt in EVENT_LOG:
        if et - prev > 90:
            print(f"  {fmt_t(prev)} -> {fmt_t(et)}  ({int(et-prev)}s of silence)")
            any_dead = True
        prev = et
    if not any_dead:
        print("  (none)")

    delete_save()
