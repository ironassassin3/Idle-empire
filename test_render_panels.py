"""Phase 64 — render specific game panels directly from game modules.
No full game launch needed; creates minimal state and renders to PNG."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
pygame.init()

import src.theme as theme
import config

# Set up screen matching the game dimensions
screen = pygame.display.set_mode((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
pygame.display.set_caption("Phase 64 Panel Test")

fonts = theme.make_fonts(config.SCREEN_HEIGHT)
ui = __import__('src.ui', fromlist=['ui'])
ui.reinit_layout(config.SCREEN_WIDTH, config.SCREEN_HEIGHT)

# ─── Build minimal game state ─────────────────────────────────────────────────
import src.rivals as rivals_mod
import src.prestige as prestige_mod
import src.buildings as bldg_mod
import src.heat as heat_mod
import src.territory as territory_mod

class FakeState:
    def __init__(self):
        self.rivals = rivals_mod.make_rivals()
        self.prestige_tokens = 0
        self.buildings = bldg_mod.make_buildings()
        self.heat = 0.0
        self.balance = 12_345_678
        self.lifetime_earnings = 100_000_000
        self.income_per_second = 45_678
        self.click_value = 1234
        self.managers = []
        self.upgrades = []
        self.prestige_influence = 0
        self.prestige_mastery = 0.0
        self.prestige_respect = 0
        self.respect = 10
        self.total_buildings_owned = 12
        self.crew = None
        self.total_clicks = 500
        self.achievements_earned = 3
        self.territories = territory_mod.make_territories()
        self.total_turf_owned = 3
        self._tab = 'rivals'
        self._rival_scroll = 0
        self._rival_detail = None
        self._activity_log_scroll = 0
        self._bld_scroll = 0
        self._shown_rivals_tutorial = True
        self._rival_action_msg = None
        self._rival_action_timer = 0.0
        self._shown_crew_tutorial = True
        self.prestige_tree_perks = []
        self.perks_purchased = []
        self.dragon_active = False
        self.dragon = None
        self._syndicate_event = None
        self._milestone_queue = []
        self._notif_queue = []
        self._scroll_offset = 0
        self._ops_scroll = 0
        self.operations = []
        self.goals = []
        self.daily_streak = 2
        self._stats_surf = None
        self._stats_dirty = True
        self._gear_rect = None
        self._tab_rects = {}
        self._prestige_pending = False

state = FakeState()

# ─── SCREENSHOT 1: Rivals Tab ─────────────────────────────────────────────────
screen.fill(theme.BG_DARK)
try:
    ui.draw_right_panel(screen, state, fonts)
    rivals_mod.draw_panel(screen, state, fonts)
except Exception as e:
    # Draw error info if something fails
    screen.fill((40, 15, 15))
    s = fonts['sm'].render(f"Error: {e}", True, (255, 80, 80))
    screen.blit(s, (10, 10))
    import traceback; traceback.print_exc()

pygame.display.flip()
pygame.image.save(screen, "panel_rivals.png")
print("Saved panel_rivals.png")

# ─── SCREENSHOT 2: Settings/Gear icon (buildings tab + gear visible) ──────────
state._tab = 'buildings'
screen.fill(theme.BG_DARK)
try:
    ui.draw_right_panel(screen, state, fonts)
    state.buildings[0].owned = 5
    bldg_mod.draw_panel(screen, state, fonts,
                         pygame.Rect(0, 0, ui.RIGHT_X, config.SCREEN_HEIGHT),
                         state._bld_scroll)
except Exception as e:
    s = fonts['sm'].render(f"Error: {e}", True, (255, 80, 80))
    screen.blit(s, (10, 360))
    import traceback; traceback.print_exc()

pygame.display.flip()
pygame.image.save(screen, "panel_buildings_gear.png")
print("Saved panel_buildings_gear.png")

# ─── SCREENSHOT 3: Prestige panel (left side) ────────────────────────────────
state._tab = 'buildings'
screen.fill(theme.BG_DARK)
try:
    ui.draw_stats(screen, state, fonts)
    ui.draw_click_zone(screen, state, fonts)
    ui.draw_right_panel(screen, state, fonts)
except Exception as e:
    s = fonts['sm'].render(f"Error: {e}", True, (255, 80, 80))
    screen.blit(s, (10, 10))
    import traceback; traceback.print_exc()

pygame.display.flip()
pygame.image.save(screen, "panel_prestige.png")
print("Saved panel_prestige.png")

# ─── SCREENSHOT 4: Prestige confirm dialog ───────────────────────────────────
state.lifetime_earnings = 10_000_000_000  # enough to prestige
state.balance = 1_000_000_000
state._prestige_pending = True
screen.fill(theme.BG_DARK)
try:
    ui.draw_stats(screen, state, fonts)
    ui.draw_right_panel(screen, state, fonts)
    ui.draw_prestige_confirm(screen, state, fonts)
except Exception as e:
    s = fonts['sm'].render(f"Error: {e}", True, (255, 80, 80))
    screen.blit(s, (10, 10))
    import traceback; traceback.print_exc()

pygame.display.flip()
pygame.image.save(screen, "panel_prestige_confirm.png")
print("Saved panel_prestige_confirm.png")

pygame.quit()
print("All panels saved.")
