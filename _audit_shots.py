"""Phase 84 responsive-audit screenshot harness (diagnosis only, no game changes).

Renders PlayingState at several resolutions/tabs to PNGs under _audit/.
Headless via SDL dummy driver. Does NOT touch the real save file.
"""
import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import pygame
import config
import src.ui as ui
import src.theme as theme

OUT = os.path.join(os.path.dirname(__file__), "_audit")
os.makedirs(OUT, exist_ok=True)

pygame.init()
try:
    import src.sound as sound
    sound.init()
except Exception:
    pass


def apply_layout(w, h):
    """Mirror Engine._apply_layout without needing the Engine/run loop."""
    w = max(w, config.MIN_WIDTH)
    h = max(h, config.MIN_HEIGHT)
    config.SCREEN_WIDTH = w
    config.SCREEN_HEIGHT = h
    ui.reinit_layout(w, h)
    ui._GLOW_SURFS = None
    ui._CLICK_GLOW_SURF = None
    ui._CLICK_GLOW_HOVER = None
    ui._COIN_GLOW_SURF = None
    return theme.make_fonts(h)


def make_state():
    from src.states import StateManager, PlayingState
    sm = StateManager()
    st = PlayingState(sm)
    # ---- progress the state so every tab unlocks and has content ----
    st.balance = 5.0e9
    st.lifetime_earnings = 8.5e10
    st._highest_cash_held = 6.0e9
    st.prestige_tokens = 60
    st.influence = 60
    st._prestige_count = 4
    st._play_time = 12345.0
    st.heat = 42.0
    # buildings: own a spread (first tiers high) -> unlocks Crew (>=5)
    for i, b in enumerate(st.buildings):
        b.owned = max(0, 40 - i * 4)
    # territories: claim several -> unlocks Operations (>=2)
    claimed = 0
    for t in st.territories:
        if claimed < 7:
            t.owner = "player"
            t.unlocked = True
            claimed += 1
    # crew assignments
    st.crew.protection = 30
    st.crew.collection = 40
    st.crew.smuggling = 20
    st.crew.territory = 15
    st.crew.heat = 10
    # operations: start them; force one ready to collect
    try:
        for i, op in enumerate(st.operations):
            op.active = True
            op.collected = False
            op.elapsed = op._eff_duration + 1 if i == 0 else op._eff_duration * 0.4
    except Exception as e:
        print("ops setup warn:", e)
    # lifetime stats for Stats tab
    st._total_buildings_purchased = 312
    st._total_territories_captured = 19
    st._total_rivals_defeated = 3
    st._total_ops_completed = 88
    st._total_respect_earned = 14000
    st._total_influence_earned = 220
    st._peak_income = 1.2e8
    st._tutorial_step = 5  # past tutorial
    st._loaded = True
    st._ips_dirty = True
    # suppress full-screen overlays so the underlying layout is visible
    st._milestone_queue = []
    st._milestone_timer = 0.0
    st._shown_milestones = set(["__all__"])
    st._pending_event = None
    st._show_offline_overlay = False
    st._show_daily_overlay = False
    st._elim_overlay = None
    st._elim_overlay_timer = 0.0
    st._show_prestige_locked = False
    return st


TABS = ["buildings", "upgrades", "territory", "rivals", "crew",
        "operations", "managers", "stats", "settings"]

RESOLUTIONS = {
    "480x480": (480, 480),
    "580x500": (580, 500),
    "900x720": (900, 720),
    "1280x800": (1280, 800),
    "1920x1080": (1920, 1080),
    "2560x1440": (2560, 1440),
}


def render(res_name, tabs):
    w, h = RESOLUTIONS[res_name]
    fonts = apply_layout(w, h)
    screen = pygame.display.set_mode((w, h))
    st = make_state()
    st._fonts = fonts
    st._bg = ui.make_bg_surface()
    # one update tick so caches/income settle
    try:
        st.update(0.016)
    except Exception as e:
        print(f"[{res_name}] update warn:", e)
    for tab in tabs:
        st._tab = tab
        st._fonts = fonts
        # re-suppress overlays that update() may have re-queued
        st._milestone_queue = []
        st._milestone_timer = 0.0
        st._pending_event = None
        st._show_offline_overlay = False
        st._show_daily_overlay = False
        st._elim_overlay = None
        st._toasts = []
        ui._notification_stack[:] = []
        surf = pygame.Surface((w, h))
        surf.fill((0, 0, 0))
        try:
            st.draw(surf)
        except Exception as e:
            import traceback
            print(f"[{res_name}/{tab}] DRAW ERROR: {e}")
            traceback.print_exc()
            continue
        path = os.path.join(OUT, f"{res_name}_{tab}.png")
        pygame.image.save(surf, path)
        print("saved", path)


if __name__ == "__main__":
    sel = sys.argv[1] if len(sys.argv) > 1 else "all"
    if sel == "all":
        for r in RESOLUTIONS:
            render(r, TABS)
    else:
        # e.g. python _audit_shots.py 480x480 buildings,stats
        tabs = sys.argv[2].split(",") if len(sys.argv) > 2 else TABS
        render(sel, tabs)
    print("DONE")
