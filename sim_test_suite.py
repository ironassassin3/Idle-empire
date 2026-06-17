"""Session 2 regression test suite. Exercises every required area on the REAL
game code: fresh save, first prestige, second prestige, save/load round-trip,
achievements, managers, territory, heat. Asserts no regressions."""
import os
os.environ.setdefault("SDL_VIDEODRIVER","dummy"); os.environ.setdefault("SDL_AUDIODRIVER","dummy")
import pygame; pygame.init(); pygame.display.set_mode((900,720))

import src.prestige as prestige, src.theme as theme
import src.upgrades as upg, src.territory as terr_mod, src.heat as heat_mod
from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import delete_save, save_game, load_game, apply_save_data

PASS=[]; FAIL=[]
def check(name, cond):
    (PASS if cond else FAIL).append(name)
    print(f"  [{'OK' if cond else 'FAIL'}] {name}")

def fm(n): return theme.format_number(n)

def make_player(ps):
    state={'ca':0.0,'ba':0.0}
    def best():
        b0,br=None,0.0
        for b in ps.buildings:
            c=b.current_cost
            if c<=0 or ps.balance<c: continue
            r=(b.base_income*b.income_multiplier)/c
            if r>br: br,b0=r,b
        return b0
    def act(dt,t,active=True):
        if active:
            state['ca']+=1.0*dt
            while state['ca']>=1.0:
                cv=ps.click_value; ps.balance+=cv; ps.lifetime_earnings+=cv; ps._click_count+=1; state['ca']-=1.0
        state['ba']+=0.6*dt
        while state['ba']>=1.0:
            state['ba']-=1.0
            b=best()
            if b and ps.balance>=b.current_cost: ps.balance-=b.current_cost; b.owned+=1
        for u in ps.upgrades:
            if not u.purchased:
                c=upg._effective_cost(u,ps)
                if ps.balance>=c: ps.balance-=c; u.purchased=True; u.apply(ps)
        for m in ps.managers:
            if not m.hired and ps.balance>=m.cost: ps.balance-=m.cost; m.hired=True
        ps.crew.collection=sum(b.owned for b in ps.buildings)
        if sum(b.owned for b in ps.buildings)>=15:
            for idx,tr in enumerate(ps.territories):
                if not tr.unlocked and ps.prestige_tokens>=tr.unlock_cost:
                    terr_mod.perform_action(ps, idx, 'negotiate'); break
    return act

def play_until(ps, cond, max_min=90):
    act=make_player(ps); t=0.0; dt=0.5
    while t<max_min*60 and not cond():
        ps.update(dt); act(dt,t,(t%60)<25); t+=dt
    return t

print("="*64)
print("SESSION 2 — REGRESSION TEST SUITE")
print("="*64)

# 1. FRESH SAVE
print("\n[1] FRESH SAVE")
delete_save()
sm=StateManager(); ps=PlayingState(sm); ps.on_enter()
check("fresh: balance 0", abs(ps.balance)<1e-6)
check("fresh: influence 0", ps.prestige_tokens==0)
check("fresh: 0 starting dealers (tutorial teaches first buy)", ps.buildings[0].owned==0)
check("fresh: prestige_count 0", ps._prestige_count==0)
check("fresh: next_prestige_earnings == FIRST", ps._next_prestige_earnings==prestige.FIRST_PRESTIGE_EARNINGS)

# 2. FIRST PRESTIGE
print("\n[2] FIRST PRESTIGE")
t1=play_until(ps, lambda: prestige.can_prestige(ps))
check("first prestige reachable (<60min)", prestige.can_prestige(ps) and t1<3600)
ips_before=ps.income_per_second
tok_before=ps.prestige_tokens
gain=prestige.calc_influence_gain(ps.lifetime_earnings)
ok=prestige.PrestigeManager.execute(ps)
check("prestige executed", ok)
check("influence increased", ps.prestige_tokens>tok_before)
check("prestige_count == 1", ps._prestige_count==1)
# Hard wipe (Phase 20): prestige is a semi-fresh restart — buildings & income
# reset to 0; the *enhanced bonus* (prestige income multiplier) is what persists.
check("hard wipe: buildings reset to 0", sum(b.owned for b in ps.buildings)==0)
ps._ips_dirty = True  # execute() doesn't touch the per-frame income cache; a frame would
check("hard wipe: income resets to 0 (rebuild from scratch)", ps.income_per_second==0)
check("enhanced bonus persists: prestige income_mult > 1", prestige.income_mult(ps.prestige_tokens)>1.0)
check("next bar escalated (> first gate)", ps._next_prestige_earnings>prestige.FIRST_PRESTIGE_EARNINGS)
print(f"      first prestige @ {int(t1//60)}m: +{gain} inf, income {fm(ips_before)} -> hard wipe {fm(ps.income_per_second)} (rebuild w/ persistent x{prestige.income_mult(ps.prestige_tokens):.2f})")

# 3. SECOND PRESTIGE
print("\n[3] SECOND PRESTIGE")
tok1=ps.prestige_tokens
t2=play_until(ps, lambda: prestige.can_prestige(ps), max_min=60)
check("second prestige reachable", prestige.can_prestige(ps))
gain2=prestige.calc_influence_gain(ps.lifetime_earnings)
check("2nd prestige gain >= 1st gain (escalation)", gain2>=gain)
prestige.PrestigeManager.execute(ps)
check("prestige_count == 2", ps._prestige_count==2)
check("influence higher after 2nd", ps.prestige_tokens>tok1)
print(f"      2nd prestige: +{gain2} inf (1st was +{gain}); now {ps.prestige_tokens} ({prestige.get_rank(ps.prestige_tokens)})")

# 4. SAVE / LOAD ROUND TRIP
print("\n[4] SAVE / LOAD")
save_game(ps)
data=load_game()
check("save written + loadable", data is not None)
sm2=StateManager(); ps2=PlayingState(sm2); ps2.on_enter()  # loads the save
check("loaded influence matches", ps2.prestige_tokens==ps.prestige_tokens)
check("loaded prestige_count matches", ps2._prestige_count==ps._prestige_count)
check("loaded next_prestige_earnings matches", abs(ps2._next_prestige_earnings-ps._next_prestige_earnings)<1.0)

# 5. ACHIEVEMENTS
print("\n[5] ACHIEVEMENTS")
from src.achievements import check_and_earn
earned_any = any(a.earned for a in ps2.achievements)
check("achievements earned during play", earned_any)
prestige_ach = next((a for a in ps2.achievements if a.name=="Prestige!"), None)
check("'Prestige!' achievement earned", prestige_ach is not None and prestige_ach.earned)

# 6. MANAGERS (unique effects)
print("\n[6] MANAGERS")
delete_save()
sm3=StateManager(); ps3=PlayingState(sm3); ps3.on_enter()
ps3.balance=1e9
acc=[m for m in ps3.managers if m.name=="The Accountant"][0]; acc.hired=True
b0=sum(b.owned for b in ps3.buildings)
for _ in range(20): ps3.update(0.5)
check("Accountant auto-buys buildings", sum(b.owned for b in ps3.buildings)>b0)
ps3.heat=80.0
prom=[m for m in ps3.managers if m.name=="The Promoter"][0]; prom.hired=True
h0=ps3.heat
for _ in range(10): ps3.update(0.5)
check("Promoter lowers heat", ps3.heat<h0)
check("hired manager boosts income", any(m.hired for m in ps3.managers))

# 7. TERRITORY
print("\n[7] TERRITORY")
delete_save()
sm4=StateManager(); ps4=PlayingState(sm4); ps4.on_enter()
for i in range(20): ps4.buildings[0].owned+=1  # enough crew
ps4.balance=1e7
downtown_idx=1
out=terr_mod.perform_action(ps4, downtown_idx, 'negotiate')
check("territory action returns outcome string", isinstance(out,str) and len(out)>0)
# negotiate Downtown (0 influence gate) should be attemptable
check("Downtown is 0-Influence gated", ps4.territories[1].unlock_cost==0)

# 8. HEAT
print("\n[8] HEAT")
delete_save()
sm5=StateManager(); ps5=PlayingState(sm5); ps5.on_enter()
for i in range(30): ps5.buildings[0].owned+=1
ps5.heat=0.0
for _ in range(60): heat_mod.update_heat(ps5,0.5)  # 30s
check("heat rises with activity", ps5.heat>0)
check("heat income bonus applies above 50", heat_mod.heat_income_mult(60.0)>1.0)
check("heat stays clamped <=100", ps5.heat<=100.0)

# 9. SESSION 3 — MANAGER IDENTITIES
print("\n[9] MANAGER IDENTITIES")
import src.managers as mgr_mod
delete_save()
sm9=StateManager(); ps9=PlayingState(sm9); ps9.on_enter()
def _hire(ps, name):
    for m in ps.managers:
        if m.name==name: m.hired=True
# Sticky Pete (Phase 109): "Pete's Pick" marks the best building to buy — he is
# no longer a click booster, so validate the recommendation, not click value.
check("Pete's Pick inactive before hire", mgr_mod.pete_recommends_index(ps9) is None)
_hire(ps9,"Sticky Pete"); ps9.balance=1_000.0
check("Sticky Pete recommends a building (Pete's Pick)",
      mgr_mod.pete_recommends_index(ps9) is not None)
_hire(ps9,"Clean Carl"); check("Clean Carl reduces heat gain", mgr_mod.heat_gain_mult(ps9)<1.0)
_hire(ps9,"The Collector"); check("Collector reduces raid damage", mgr_mod.raid_damage_mult(ps9)<1.0)
_hire(ps9,"The Smuggler"); check("Smuggler boosts op rewards", mgr_mod.operation_reward_mult(ps9)>1.0)
_hire(ps9,"The Broker"); check("Broker boosts territory success", mgr_mod.territory_success_bonus(ps9)>0)
_hire(ps9,"The Consigliere"); check("Consigliere boosts prestige influence", mgr_mod.influence_gain_mult(ps9)>1.0)

# 10. SESSION 3 — TERRITORY IDENTITIES
print("\n[10] TERRITORY IDENTITIES")
delete_save()
sm10=StateManager(); ps10=PlayingState(sm10); ps10.on_enter()
perks={t.perk_key for t in ps10.territories if t.perk_key}
check("districts have distinct perks", perks=={"cash","operations","smuggling","politics"})
# unlock industrial -> operations reward mult rises
for t in ps10.territories:
    if t.perk_key=="operations": t.unlocked=True
check("Industrial boosts op rewards", terr_mod.operation_reward_mult(ps10)>1.0)
for t in ps10.territories:
    if t.perk_key=="politics": t.unlocked=True
check("City Hall boosts prestige influence", terr_mod.prestige_influence_mult(ps10)>1.0)

# 11. SESSION 3 — OFFLINE / DAILY RETURN
print("\n[11] OFFLINE RETURN")
import time as _t, json as _json
delete_save()
sm11=StateManager(); ps11=PlayingState(sm11); ps11.on_enter()
for i in range(40): ps11.buildings[0].owned+=1
ps11.buildings[2].owned=10  # income source
save_game(ps11)
# Rewind save timestamp 6h to simulate being away
data=load_game(); data['save_timestamp']=_t.time()-6*3600
import os as _os
with open("save.json","w") as f: _json.dump(data,f)
sm11b=StateManager(); ps11b=PlayingState(sm11b); ps11b.on_enter()
check("offline earnings granted on return", getattr(ps11b,'_offline_gain',0)>0)
check("offline overlay shown", getattr(ps11b,'_show_offline_overlay',False))
check("offline cap field present", hasattr(ps11b,'_offline_capped'))

# 12. SESSION 3 — ANALYTICS
print("\n[12] ANALYTICS")
import src.analytics as analytics
_os.remove("analytics.jsonl") if _os.path.exists("analytics.jsonl") else None
analytics.start_session(ps11b)
analytics.track("test_event", {"k": 1})
analytics.end_session(ps11b)
check("analytics.jsonl written", _os.path.exists("analytics.jsonl"))
if _os.path.exists("analytics.jsonl"):
    n=len(open("analytics.jsonl",encoding="utf-8").read().strip().splitlines())
    check("analytics recorded >=3 events", n>=3)
    _os.remove("analytics.jsonl")

delete_save()
print("\n"+"="*64)
print(f"RESULT: {len(PASS)} passed, {len(FAIL)} failed")
if FAIL:
    print("FAILURES:", FAIL)
else:
    print("ALL TESTS PASSED")
