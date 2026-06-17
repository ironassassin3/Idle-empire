"""Zoom in on the post-prestige recovery: does income recover to PRE-prestige
levels quickly (good - 'I'm stronger now') or collapse for a long time (bad -
'I lost everything')? Track income every 30s around the first prestige."""
import os
os.environ.setdefault("SDL_VIDEODRIVER","dummy"); os.environ.setdefault("SDL_AUDIODRIVER","dummy")
import pygame; pygame.init(); pygame.display.set_mode((900,720))
import src.prestige as prestige, src.theme as theme
import src.upgrades as upg, src.territory as terr_mod
from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import delete_save


class Player:
    """Minimal inline player (avoids importing sim_playthrough side effects)."""
    def __init__(self, ps, clicks_per_sec=1.0, buys_per_sec=0.5):
        self.ps=ps; self.cps=clicks_per_sec; self.bps=buys_per_sec
        self._ca=0.0; self._ba=0.0
    def _best(self):
        best,br=None,0.0
        for b in self.ps.buildings:
            c=b.current_cost
            if c<=0 or self.ps.balance<c: continue
            r=(b.base_income*b.income_multiplier)/c
            if r>br: br,best=r,b
        return best
    def act(self, dt, t, active):
        ps=self.ps
        if active:
            self._ca+=self.cps*dt
            while self._ca>=1.0:
                cv=ps.click_value; ps.balance+=cv; ps.lifetime_earnings+=cv; ps._click_count+=1; self._ca-=1.0
        self._ba+=self.bps*dt
        while self._ba>=1.0:
            self._ba-=1.0
            b=self._best()
            if b and ps.balance>=b.current_cost:
                ps.balance-=b.current_cost; b.owned+=1
        for u in ps.upgrades:
            if not u.purchased:
                c=upg._effective_cost(u,ps)
                if ps.balance>=c:
                    ps.balance-=c; u.purchased=True; u.apply(ps)
        for m in ps.managers:
            if not m.hired and ps.balance>=m.cost:
                ps.balance-=m.cost; m.hired=True
        ps.crew.collection=sum(b.owned for b in ps.buildings)
        if sum(b.owned for b in ps.buildings)>=15:
            for idx,terr in enumerate(ps.territories):
                if not terr.unlocked and ps.prestige_tokens>=terr.unlock_cost:
                    terr_mod.perform_action(ps, idx, 'negotiate'); break

def fm(n): return theme.format_number(n)
def ft(s): return f"{int(s//60)}m{int(s%60):02d}s"

delete_save()
sm=StateManager(); ps=PlayingState(sm); ps.on_enter()
pl=Player(ps, clicks_per_sec=1.0, buys_per_sec=0.5)
t=0.0; dt=0.5
prestige_done=False; prestige_t=None; peak_before=0.0; recover_t=None
log=[]
while t < 60*60:
    active=(t%60)<20
    ps.update(dt); pl.act(dt,t,active)
    ips=ps.income_per_second
    if not prestige_done:
        peak_before=max(peak_before, ips)
        if prestige.can_prestige(ps):
            prestige.PrestigeManager.execute(ps)
            prestige_done=True; prestige_t=t
            log.append((t, "PRESTIGE", ips, peak_before))
    else:
        if recover_t is None and ips >= peak_before:
            recover_t=t
    if int(t)%30==0 and abs(t-int(t))<dt:
        log.append((t, "", ips, peak_before))
    if prestige_done and recover_t and t > recover_t+60:
        break
    t+=dt

print(f"HEAD START: buildings right after prestige = "
      f"{sum(b.owned for b in ps.buildings)}, income now = {fm(ps.income_per_second)}/s")
print("INCOME TRAJECTORY ACROSS FIRST PRESTIGE")
print(f"{'time':>7} {'income/s':>12} {'note':>10}")
for (tt,note,ips,pk) in log:
    print(f"{ft(tt):>7} {fm(ips):>12} {note:>10}")
print()
print(f"Peak income BEFORE prestige: {fm(peak_before)}/s")
if recover_t and prestige_t is not None:
    print(f"Time to RECOVER to pre-prestige income after prestige: {ft(recover_t - prestige_t)}")
    verdict = "GOOD (fast recovery = 'I'm stronger')" if (recover_t-prestige_t) < 180 else \
              "BAD (slow recovery = 'I lost everything')"
    print(f"VERDICT: {verdict}")
else:
    print("Income did NOT recover to pre-prestige level within the window — SEVERE collapse.")
delete_save()
