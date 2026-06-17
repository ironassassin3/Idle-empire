"""PlayingState — main game loop."""
from __future__ import annotations
import math
import random
from dataclasses import dataclass

import pygame
import config
import src.buildings as bld
import src.upgrades as upg
import src.prestige as prestige
import src.theme as theme
import src.ui as ui
import src.sound as sound
import src.managers as mgr_mod
import src.tutorial as tut
import src.heat as heat_mod
import src.territory as territory_mod
import src.events as events_mod
import src.rivals as rivals_mod
import src.crew as crew_mod
import src.operations as ops_mod
import src.prestige_tree as ptree
import src.dragon as dragon_mod
from src.state_base import GameState, StateManager  # noqa: F401
from src.achievements import make_achievements, check_and_earn, draw_toasts
from src.buildings import make_buildings
from src.upgrades import make_upgrades
from src.save_load import save_game, load_game
import src.goals as goals_mod
import src.money_debug as money_debug

_AUTOSAVE_INTERVAL = 30.0


@dataclass
class _Particle:
    """A floating click-feedback element. Two flavours share one list:
    - text particles carry a captured value string ("+1.2K" / "CRIT +9K") that
      is fixed at spawn time, so the number shown is the *actual* payout of that
      click, not the live click_value at draw time.
    - spark particles (text == "") are the small dots that burst from a crit.
    Each particle owns its lifetime/rise so crits can linger and float higher
    than normal clicks without a second code path."""
    x: float
    y: float
    lifetime: float = 0.0
    dur: float = 0.6          # total lifetime (s)
    rise: float = 80.0        # px floated up over the lifetime
    vx: float = 0.0           # horizontal drift (sparks fan out)
    text: str = ""            # "" → spark dot; else floating value/label
    crit: bool = False        # crit styling (bigger font / hot colour)
    # Back-compat aliases for any external reader of the old class constants.
    DURATION = 0.6
    RISE = 80.0


class PlayingState(GameState):
    _CLICK_VALUE_BASE = 1.0
    _CLICK_SCALE_MIN = 0.92
    _CLICK_SCALE_RATE = (1.0 - 0.92) / 0.15
    _COIN_LIFETIME = 8.0

    # Layout driven by ui.py constants — kept as properties for backward compat
    _CLICK_RECT        = ui.CLICK_RECT
    _PRESTIGE_BTN_RECT = ui.PRESTIGE_RECT
    # TAB_RECTS / CONTENT_RECT no longer used for click dispatch — ui.py handles it
    _CONTENT_RECT = ui.get_content_rect('buildings')

    def __init__(self, state_manager):
        super().__init__(state_manager)
        self.balance = 0.0
        self.lifetime_earnings = 0.0
        self.prestige_tokens = 0
        self.influence = 0
        self._click_count = 0
        self.buy_count = 1
        self._tab = 'buildings'
        self.buildings = make_buildings()
        self.upgrades = make_upgrades()
        self.achievements = make_achievements()
        self.managers = mgr_mod.make_managers()
        self._toasts: list = []
        self._particles: list = []
        self._buffs: list = []
        self._recent_clicks: list = []   # Phase 94 — Hustle burst detection (timestamps)
        self._idle_particles: list = []
        self._click_scale = 1.0
        self._idle_particle_timer = 0.0
        self._coin: dict | None = None
        self._coin_timer = random.uniform(30.0, 60.0)
        self._ticker_x = float(config.SCREEN_WIDTH)
        self._ticker_idx = 0
        self._bld_scroll = 0
        self._upg_scroll = 0
        self._mgr_scroll = 0
        self._mgr_late_collapsed = True
        self._stats_scroll = 0
        self._rivals_scroll = 0
        self._loaded = False
        self._time = 0.0
        self._play_time = 0.0
        self._offline_gain = 0.0
        self._offline_secs_away = 0.0
        self._offline_capped = False
        self._offline_rival_events: list = []
        self._show_offline_overlay = False
        self._show_daily_overlay = False
        self._perk_click_mult = 1.0
        self._perk_income_mult = 1.0
        self._perk_bld_mults: list = []
        # Session 9: committed prestige branch for the current cycle (None = unchosen).
        self.prestige_branch = None
        # Dragon Patron: persists across all runs. None until first prestige + selection.
        self.dragon_patron: str | None = None
        self.dragon_xp: int = 0
        self.dragon_ability_cooldowns: dict = {}
        self._dragon_red_elim_count: int = 0
        self._dragon_black_last_op_time: float | None = None
        # Dragon lifecycle state (not saved — resets gracefully on load)
        self._dragon_request_key: str | None = None
        self._dragon_req_snapshot: dict = {}
        self._dragon_request_cooldown: float = 15.0
        self._dragon_recent_requests: list = []
        self._dragon_mood_timer: float = 0.0
        self._dragon_rage_timer: float = 0.0
        self._dragon_logistics_timer: float = 0.0
        self._dragon_guaranteed_territory: bool = False
        self._dragon_ability_btn_rects: dict = {}
        self._daily_streak = 1
        self._daily_reward = 0.0
        self._coins_caught = 0
        self._coins_expired = 0
        self._coins_manual = 0
        self._coins_auto_sal = 0
        self._pete_followed_buys = 0
        self._pete_other_buys = 0
        self._prestige_count = 0
        self._next_prestige_earnings = prestige.FIRST_PRESTIGE_EARNINGS
        self._sfx_volume = sound.get_volume()
        self._fps_cap = config.FPS
        self._fonts = theme.make_fonts(config.SCREEN_HEIGHT)
        self._bg = ui.make_bg_surface()
        self.perks_purchased: list = []
        self._tutorial_step = 0
        self._tutorial_age = 0.0
        self._tutorial_age_step4 = 0.0
        self._shown_milestones: set = set()
        self._milestone_queue: list = []
        self._milestone_timer = 0.0
        self._peak_income = 0.0
        self._longest_streak = 1
        self._autosave_timer = _AUTOSAVE_INTERVAL
        self._show_prestige_locked = False
        self._post_prestige_notif = False
        self._last_rank = prestige.get_rank(self.prestige_tokens)
        # income_per_second cache — invalidated once per update() tick
        self._ips_dirty: bool = True
        self._ips_cached: float = 0.0
        # achievement check throttle
        self._ach_check_timer: float = 0.0
        # Heat system
        self.heat = 0.0
        # Territory system
        self.territories = territory_mod.make_territories()
        # Syndicate events
        self._event_timer: float | None = None
        self._pending_event: dict | None = None
        self._event_outcome: str | None = None
        self._event_outcome_timer: float = 0.0
        # Rivals
        self.rivals = rivals_mod.make_rivals()
        territory_mod.assign_rival_territories(self.territories, self.rivals)
        self._rival_outcome: str | None = None
        self._rival_outcome_timer: float = 0.0
        # Crew assignments
        self.crew = crew_mod.CrewAssignment()
        # Operations
        self.operations = ops_mod.make_operations()
        # Territory outcome popup
        self._territory_outcome: str | None = None
        self._territory_outcome_timer: float = 0.0
        # Territory panel scroll (item offset)
        self._terr_scroll: int = 0
        # Goals
        self.goals = goals_mod.make_goals()
        # Rival elimination overlay
        self._elim_overlay: str | None = None
        self._elim_overlay_timer: float = 0.0
        self._elim_rewards: str = ""
        # Prestige climax overlay (Phase 101) — runtime-only, not persisted
        self._prestige_climax_timer: float = 0.0
        self._prestige_climax_tokens: int = 0
        self._prestige_climax_count: int = 0
        self._prestige_climax_rank: str = ""
        # Audio settings
        self._music_volume: float = 0.5
        self._master_volume: float = 1.0
        self._mute_all: bool = False
        # ── Lifetime statistics (persist across prestiges) ──────────────────
        self._total_buildings_purchased: int = 0
        self._total_territories_captured: int = 0
        self._total_rivals_defeated: int = 0
        self._total_ops_completed: int = 0
        self._total_heat_generated: float = 0.0
        self._total_respect_earned: int = 0
        self._total_influence_earned: int = 0
        self._highest_cash_held: float = 0.0
        self._highest_city_control: float = 0.0
        self._city_control_milestones: set = set()
        # Influence intro — fires once at 50% of first prestige threshold
        self._shown_influence_intro: bool = False
        # Return summary (populated by apply_save_data on load; safe defaults for fresh saves)
        self._return_ops_ready: int = 0
        self._return_territory_player: int = 0
        self._return_territory_total: int = 0
        self._return_rival_active: int = 0
        self._return_rival_at_war: int = 0
        money_debug.reset(self)

    def on_enter(self):
        if not self._loaded:
            self._loaded = True
            data = load_game()
            if data:
                self._load(data)
            import src.analytics as analytics
            analytics.start_session(self)
            # Funnel: offline/daily events captured here so they appear per-return.
            if getattr(self, '_offline_gain', 0.0) > 0:
                analytics.offline_return(self._offline_gain,
                                         getattr(self, '_offline_secs_away', 0.0),
                                         getattr(self, '_offline_capped', False))
            if getattr(self, '_daily_reward', 0.0) > 0:
                analytics.daily_reward(getattr(self, '_daily_streak', 1), self._daily_reward)

    def on_exit(self):
        import src.analytics as analytics
        analytics.end_session(self)
        save_game(self)

    @property
    def income_per_second(self) -> float:
        if not self._ips_dirty:
            return self._ips_cached
        base = mgr_mod.compute_base_income(self)
        mult = prestige.income_mult(self.prestige_tokens)
        if any(u.purchased and u.effect_key == 'prestige_boost' for u in self.upgrades):
            mult *= prestige.prestige_mastery_mult(self.prestige_tokens)
        if self._has_buff('frenzy'):
            mult *= 7.0
        mult *= getattr(self, '_perk_income_mult', 1.0)
        # Branch income perks: Warlord turf intimidation, Cartel district income.
        mult *= ptree.turf_intimidation_income_mult(self)
        mult *= ptree.district_income_mult(self)
        # Heat bonus
        mult *= heat_mod.heat_income_mult(getattr(self, 'heat', 0.0))
        # Territory: per-district strategic bonuses (income_bonus fields)
        territories = getattr(self, 'territories', [])
        mult *= territory_mod.territory_income_mult(territories)
        # Territory: global count bonus (2% per district controlled — Phase 10)
        mult *= 1.0 + territory_mod.territory_district_count_bonus(territories)
        # Territory: 100% city-control milestone (+50% income)
        mult *= territory_mod.milestone_income_mult(self)
        # Syndicate income buffs
        for b in getattr(self, '_buffs', []):
            if b.get('name') == 'syndicate_income':
                mult *= b.get('mult', 1.0)
        # Crew collection bonus (Black Dragon amplifies collection efficiency)
        crew = getattr(self, 'crew', None)
        if crew:
            mult *= crew_mod.collection_income_mult(crew, self)
        # Rank perk: cumulative income bonus per rank tier reached.
        mult *= 1.0 + prestige.rank_income_bonus(self.prestige_tokens)
        # Respect (street reputation): capped passive global income bonus.
        # Consigliere Favors Owed amplifies the Respect bonus.
        mult *= 1.0 + prestige.respect_income_bonus(getattr(self, 'influence', 0)) \
            * ptree.respect_income_mult(self)
        # Dragon Patron income effects.
        mult *= dragon_mod.rival_presence_income_mult(self)
        mult *= dragon_mod.eliminated_rival_income_mult(self)
        mult *= 1.0 + dragon_mod.active_ops_income_bonus(self)
        self._ips_cached = base * mult
        self._ips_dirty = False
        return self._ips_cached

    @property
    def click_value(self) -> float:
        mult = prestige.income_mult(self.prestige_tokens)
        if any(u.purchased and u.effect_key == 'double_click' for u in self.upgrades):
            mult *= 2.0
        if any(u.purchased and u.effect_key == 'quad_click' for u in self.upgrades):
            mult *= 4.0
        if any(u.purchased and u.effect_key == 'octo_click' for u in self.upgrades):
            mult *= 8.0
        if any(u.purchased and u.effect_key == 'hex_click' for u in self.upgrades):
            mult *= 16.0
        mult *= 1.0 + sum(1 for a in self.achievements if a.earned) * 0.01
        if self._has_buff('click_storm'):
            mult *= 10.0
        mult *= getattr(self, '_perk_click_mult', 1.0)
        # Heat click bonus
        mult *= heat_mod.heat_click_bonus(getattr(self, 'heat', 0.0))
        # Territory click bonus
        territories = getattr(self, 'territories', [])
        mult *= territory_mod.territory_click_mult(territories)
        # Dealer click bonus (flat addition per dealer owned, treated as multiplier on base)
        dealer_bonus = bld.dealer_click_bonus(self.buildings)
        # Phase 94 — progression-linked term: each click also pays a small fraction
        # of one second of passive income. Without this, click power is built only
        # from capped multipliers while IPS grows unbounded, so manual play decays
        # to 0% (see Phase 93). k is small, so idle remains the primary source and
        # early game (IPS≈0) is unchanged.
        ips_term = config.CLICK_IPS_FRACTION * self.income_per_second
        value = self._CLICK_VALUE_BASE * mult + dealer_bonus + ips_term
        # Hustle: temporary burst reward for sustained active clicking. Scales the
        # whole click (incl. the income-linked term) so bursts feel good late game.
        if self._has_buff('hustle'):
            value *= config.CLICK_HUSTLE_MULT
        return value

    # ─── Overlay dismiss (click/key/space/enter) ───────────────────────────────
    def _dismiss_overlay(self) -> bool:
        """Try to dismiss any blocking overlay. Returns True if something was dismissed."""
        if self._prestige_climax_timer > 0:
            self._prestige_climax_timer = 0.0
            return True
        if self._elim_overlay and self._elim_overlay_timer > 0:
            self._elim_overlay = None
            self._elim_overlay_timer = 0.0
            return True
        if self._show_offline_overlay:
            self._show_offline_overlay = False
            if self._daily_reward > 0:
                self._show_daily_overlay = True
            return True
        if self._show_daily_overlay:
            self._show_daily_overlay = False
            return True
        if self._milestone_queue and self._milestone_timer > 0:
            # Pop the current milestone immediately (player dismissed)
            self._milestone_queue.pop(0) if self._milestone_queue else None
            self._milestone_timer = tut._MILESTONE_AUTO_DISMISS if self._milestone_queue else 0.0
            return True
        return False

    # ─── Event handling ────────────────────────────────────────────────────────
    def handle_events(self, events):
        for ev in events:
            if ev.type == pygame.QUIT:
                import src.analytics as analytics
                analytics.end_session(self)
                save_game(self)
            elif ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER):
                    if self._dismiss_overlay():
                        return
                if ev.key == pygame.K_ESCAPE:
                    from src.pause import PauseState
                    self.state_manager.push(PauseState(self.state_manager, self))
                    return
            elif ev.type == pygame.MOUSEWHEEL:
                cr = ui.get_content_rect(self._tab)
                if cr.collidepoint(pygame.mouse.get_pos()):
                    if self._tab == 'buildings':
                        max_s = max(0, len(self.buildings) - 5)
                        self._bld_scroll = max(0, min(self._bld_scroll - ev.y, max_s))
                    elif self._tab == 'upgrades':
                        max_s = max(0, len(self.upgrades) - 6)
                        self._upg_scroll = max(0, min(self._upg_scroll - ev.y, max_s))
                    elif self._tab == 'managers':
                        max_s = mgr_mod.manager_panel_scroll_max(self)
                        self._mgr_scroll = max(0, min(self._mgr_scroll - ev.y, max_s))
                    elif self._tab == 'territory':
                        max_s = max(0, len(self.territories) - 3)
                        self._terr_scroll = max(0, min(self._terr_scroll - ev.y, max_s))
                    elif self._tab == 'rivals':
                        self._rivals_scroll = max(0, self._rivals_scroll - ev.y * 40)
                    elif self._tab == 'stats':
                        self._stats_scroll = max(0, self._stats_scroll - ev.y * 20)
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                if self._dismiss_overlay():
                    return
                self._handle_click(ev.pos)

    def _handle_click(self, pos):
        # panel_top matches draw_right_panel logic
        panel_top = (ui.PRESTIGE_RECT.bottom + 6) if ui._PORTRAIT else ui.HEADER_H

        # ── Tab bar click detection ──
        # Settings gear
        gear_r = getattr(self, '_gear_rect', pygame.Rect(config.SCREEN_WIDTH - 36, panel_top + 4, 28, 26))
        if gear_r.collidepoint(pos):
            self._tab = 'settings'
            return

        # Main tab bar — geometry shared with ui.draw_right_panel (Phase 89) so
        # text-width tabs hit-test exactly where they're drawn.
        for tr, label, key in ui.main_tab_rects(self, self._fonts):
            if tr.collidepoint(pos):
                if key == 'turf':
                    # Land on Territory by default; keep current Turf sub-tab if
                    # the player is already inside the group.
                    if not ui._is_turf_subtab(self._tab):
                        self._tab = 'territory'
                else:
                    if self._tab != key:
                        self._bld_scroll = 0
                        self._upg_scroll = 0
                    self._tab = key
                # Upgrades/Managers are top-level tabs now — advance the tutorial
                # straight from the main bar.
                if self._tutorial_step == 2 and self._tab == 'upgrades':
                    tut.advance_tutorial(self, save_game)
                elif self._tutorial_step == 3 and self._tab == 'managers':
                    tut.advance_tutorial(self, save_game)
                return

        # Turf sub-tab bar
        if ui._is_turf_subtab(self._tab):
            for sr2, slabel, skey, slocked, sreq in ui.subtab_rects(self, self._fonts):
                if sr2.collidepoint(pos):
                    if slocked:
                        # Don't switch — tell the player exactly how to unlock it.
                        ui.push_notification(f"{slabel} locked — {sreq}", theme.TEXT_MUTED)
                        return
                    self._tab = skey
                    if skey == 'operations' and not getattr(self, '_shown_ops_tutorial', False):
                        self._shown_ops_tutorial = True
                        self._milestone_queue.insert(0,
                            "OPERATIONS\n"
                            "Timed missions that pay big — but cost Crew and raise Heat.\n"
                            "Assign Crew first, then launch an operation and collect when done.\n"
                            "Higher-tier ops pay more but take longer."
                        )
                        if self._milestone_timer <= 0:
                            self._milestone_timer = 7.0
                    if skey == 'crew' and not getattr(self, '_shown_crew_tutorial', False):
                        self._shown_crew_tutorial = True
                        self._milestone_queue.insert(0,
                            "CREW\n"
                            "Your crew are the workforce behind every building you own.\n"
                            "Assign them to roles — Protection, Collection, Smuggling, Territory, Heat.\n"
                            "Where you commit them is what makes your empire yours."
                        )
                        if self._milestone_timer <= 0:
                            self._milestone_timer = 7.0
                    if skey == 'territory' and not getattr(self, '_shown_territory_tutorial', False):
                        self._shown_territory_tutorial = True
                        self._milestone_queue.insert(0,
                            "TERRITORY\n"
                            "Districts you control grant permanent bonuses and unlock operations.\n"
                            "Take them with Attack, Bribe, Negotiate, or Sabotage.\n"
                            "Control more of the city to reach milestone rewards."
                        )
                        if self._milestone_timer <= 0:
                            self._milestone_timer = 7.0
                    if skey == 'rivals' and not getattr(self, '_shown_rivals_tutorial', False):
                        self._shown_rivals_tutorial = True
                        self._milestone_queue.insert(0,
                            "RIVALS\n"
                            "Five syndicates compete with you — they raid your cash and grab turf.\n"
                            "Weaken or eliminate them with Attack, Bribe, Negotiate, or Sabotage.\n"
                            "Beating a rival frees their districts for you to take."
                        )
                        if self._milestone_timer <= 0:
                            self._milestone_timer = 7.0
                    return

        # Tutorial skip hint — clicking it completes all tutorial steps at once
        if self._tutorial_step < len(tut._STEPS):
            skip_r = tut.get_skip_rect()
            if skip_r and skip_r.collidepoint(pos):
                tut.skip_tutorial(self, save_game)
                return

        if ui.CLICK_RECT.collidepoint(pos):
            pre_crit = self.click_value
            had_hustle = self._has_buff('hustle')
            # Phase 94 — critical clicks: rare, reuse the existing click path.
            crit = random.random() < config.CLICK_CRIT_CHANCE
            if crit:
                cv = pre_crit * random.uniform(config.CLICK_CRIT_MIN, config.CLICK_CRIT_MAX)
            else:
                cv = pre_crit
            self.balance += cv
            self.lifetime_earnings += cv
            money_debug.credit_click(self, cv, pre_crit=pre_crit,
                                     had_crit=crit, had_hustle=had_hustle)
            self._click_count += 1
            self._register_active_click()   # Hustle burst tracking
            self._click_scale = self._CLICK_SCALE_MIN
            self._spawn_click_feedback(pos, cv, crit)
            sound.play('crit' if crit else 'click')
            if self._tutorial_step == 0:
                tut.advance_tutorial(self, save_game)
            return

        if ui.PRESTIGE_RECT.collidepoint(pos):
            if self._tutorial_step == 4:
                tut.advance_tutorial(self, save_game)
            from src.prestige_tree import PrestigeTreeState
            self.state_manager.push(PrestigeTreeState(self.state_manager, self))
            return

        # Dragon HUD ability buttons
        for ab_key, ab_rect in getattr(self, '_dragon_ability_btn_rects', {}).items():
            if ab_rect.collidepoint(pos):
                try:
                    dragon_mod.activate_ability(self, ab_key)
                except Exception:
                    pass
                return

        if self._coin:
            cx, cy = self._coin['x'], self._coin['y']
            if (not mgr_mod.manager_active(self, "Lucky Sal")
                    and math.hypot(pos[0] - cx, pos[1] - cy) <= 22):
                sound.play('coin')
                self._collect_coin(manual=True)
                return

        # Syndicate event overlay intercepts clicks first
        if events_mod.handle_event_click(self, pos):
            return

        # Stats tab: "View Achievements" button (fixed overlay, hit-test first)
        if self._tab == 'stats':
            ach_btn = getattr(self, '_ach_btn_rect', None)
            if ach_btn and ach_btn.collidepoint(pos):
                from src.achievements_panel import AchievementsState
                sound.play('click')
                self.state_manager.push(AchievementsState(self.state_manager, self))
                return

        cr = ui.get_content_rect(self._tab)
        if self._tab == 'buildings':
            prev_total = sum(b.owned for b in self.buildings)
            bld.handle_click(self, pos, cr, self._bld_scroll)
            if self._tutorial_step == 1 and sum(b.owned for b in self.buildings) > prev_total:
                tut.advance_tutorial(self, save_game)
        elif self._tab == 'upgrades':
            upg.handle_click(self, pos, cr, self._upg_scroll)
        elif self._tab == 'settings':
            ui.handle_settings_click(self, pos, cr)
        elif self._tab == 'managers':
            mgr_mod.handle_click(self, pos, cr)
        elif self._tab == 'territory':
            territory_mod.handle_click(self, pos, cr)
        elif self._tab == 'rivals':
            rivals_mod.handle_click(self, pos, cr)
        elif self._tab == 'crew':
            crew_mod.handle_click(self, pos, cr)
        elif self._tab == 'operations':
            ops_mod.handle_click(self, pos, cr)

    # ─── Update ────────────────────────────────────────────────────────────────
    def update(self, dt):
        self._time += dt
        self._play_time += dt
        self._ips_dirty = True  # invalidate income cache once per frame

        _tokens_before   = self.prestige_tokens
        _influence_before = self.influence

        passive = self.income_per_second * dt
        # Guard against inf/nan from extreme late-game multiplier stacking.
        if passive != passive or passive == float('inf'):
            passive = 0.0
        self.balance += passive
        if self.balance != self.balance or self.balance == float('inf'):
            self.balance = min(self.balance, 1e36)
        self.lifetime_earnings += passive
        money_debug.credit(self, passive, 'money_from_buildings')
        if self.lifetime_earnings != self.lifetime_earnings or self.lifetime_earnings == float('inf'):
            self.lifetime_earnings = min(self.lifetime_earnings, 1e36)

        ui.update_notifications(dt)

        ips = self.income_per_second
        if ips > self._peak_income:
            self._peak_income = ips
        if self.balance > self._highest_cash_held:
            self._highest_cash_held = self.balance

        # City control milestones
        _territories = getattr(self, 'territories', [])
        _total_t = len(_territories)
        if _total_t > 0:
            _player_t = sum(1 for t in _territories if t.unlocked)
            _ctrl_pct = _player_t / _total_t
            if _ctrl_pct > self._highest_city_control:
                self._highest_city_control = _ctrl_pct
            for _thresh in (0.25, 0.50, 0.75, 1.0):
                _key = str(int(_thresh * 100))
                if _ctrl_pct >= _thresh and _key not in self._city_control_milestones:
                    self._city_control_milestones.add(_key)
                    _pct_label = int(_thresh * 100)
                    _ctrl_msgs = {
                        25:  ("CITY QUARTER\n"
                              "You control 25% of the city!\n"
                              "REWARD: +10% Influence Gain — permanent."),
                        50:  ("HALF THE CITY\n"
                              "You control half of the city!\n"
                              "REWARD: +25% Respect Gain — permanent."),
                        75:  ("DOMINANT FORCE\n"
                              "You control 75% of the city!\n"
                              "REWARD: -15% Heat Generation — permanent."),
                        100: ("TOTAL DOMINATION\n"
                              "You control the ENTIRE CITY!\n"
                              "REWARD: +50% Global Income — permanent."),
                    }
                    _msg = _ctrl_msgs.get(_pct_label, f"CITY CONTROL: {_pct_label}%")
                    self._milestone_queue.append(_msg)
                    if self._milestone_timer <= 0:
                        self._milestone_timer = 6.0

        # Click scale animation
        if self._click_scale < 1.0:
            self._click_scale = min(1.0, self._click_scale + self._CLICK_SCALE_RATE * dt)

        # Particles — each owns its lifetime (crit popups linger longer)
        if getattr(config, 'SHOW_PARTICLES', True):
            for p in self._particles:
                p.lifetime += dt
            self._particles = [p for p in self._particles
                               if p.lifetime < getattr(p, 'dur', _Particle.DURATION)]
        else:
            self._particles.clear()

        # Buffs
        for b in self._buffs:
            b['remaining'] -= dt
        self._buffs = [b for b in self._buffs if b['remaining'] > 0]

        # Idle particles
        if ips > 0 and getattr(config, 'SHOW_PARTICLES', True):
            self._idle_particle_timer -= dt
            if self._idle_particle_timer <= 0:
                self._idle_particle_timer = 0.5
                self._idle_particles.append(
                    {'x': 65 + random.uniform(-8, 8), 'y': 55.0, 'age': 0.0})
        for p in self._idle_particles:
            p['age'] += dt
        self._idle_particles = [p for p in self._idle_particles if p['age'] < 0.8]

        # News ticker
        self._ticker_x -= ui._TICKER_SPEED * dt
        new_idx = max(0, int(-(self._ticker_x - config.SCREEN_WIDTH) / 2400))
        if new_idx > self._ticker_idx:
            self._ticker_idx = new_idx

        # Golden coin
        self._coin_timer -= dt
        if self._coin_timer <= 0 and not self._coin:
            self._spawn_coin()
        if self._coin:
            self._coin['lifetime'] += dt
            self._coin['pulse_t'] += dt
            if mgr_mod.manager_active(self, "Lucky Sal"):
                # Phase 109: Sal auto-collects — brief flash then grab
                if self._coin['lifetime'] >= mgr_mod.sal_autocollect_delay(self):
                    self._collect_coin(auto=True)
            elif self._coin['lifetime'] >= self._COIN_LIFETIME:
                self._coins_expired += 1
                self._coin = None
                self._coin_timer = self._next_coin_timer()

        # Building special abilities
        bld.update_building_specials(self, dt)

        # Unique manager effects (automation, active heat lever)
        mgr_mod.tick_manager_effects(self, dt)

        # Permanent prestige-perk automation (Talent Scout / The Machine)
        from src.prestige_tree import tick_perk_effects
        tick_perk_effects(self, dt)

        # Heat system (track total heat generated)
        _heat_before = self.heat
        heat_events = heat_mod.update_heat(self, dt)
        _heat_after = self.heat
        if getattr(self, '_carl_emergency_fired', 0) > 0:
            fired = getattr(self, '_carl_emergency_fired', 0)
            prev = getattr(self, '_carl_emergency_notified', 0)
            if fired > prev:
                self._carl_emergency_notified = fired
                ui.push_notification("Carl dumped heat — raid averted", theme.GREEN)
                self._milestone_queue.insert(0,
                    "THE LAWYER FIXED IT\n"
                    "Clean Carl triggered your free emergency heat dump.\n"
                    "You dropped below the raid threshold — once per run.")
                if self._milestone_timer <= 0:
                    self._milestone_timer = 7.0
        if _heat_after > _heat_before:
            self._total_heat_generated += _heat_after - _heat_before
        for ev in heat_events:
            if ev.startswith('raid:'):
                parts = ev.split(':')
                if len(parts) >= 3 and parts[2] == 'absorbed':
                    ui.push_notification("Collector handled the police raid", theme.GREEN)
                else:
                    penalty_str = parts[1]
                    ui.push_notification(f"POLICE RAID! -{penalty_str} seized", theme.RED)
                sound.play('purchase')  # reuse existing sfx
                if not getattr(self, '_shown_raid_tutorial', False):
                    self._shown_raid_tutorial = True
                    self._milestone_queue.insert(0,
                        "POLICE RAID!\n"
                        "Heat above 60 triggers raids that seize your cash.\n"
                        "Lower Heat: hire Clean Carl, assign Crew to Heat Reduction,\n"
                        "or run Political Bribery operations."
                    )
                    if self._milestone_timer <= 0:
                        self._milestone_timer = 8.0

        # First-heat-danger tutorial — warn the player BEFORE raids start (heat 60).
        # Fires once when heat first crosses 45 so they can act in time.
        if self.heat >= 45.0 and not getattr(self, '_shown_heat_warning', False):
            self._shown_heat_warning = True
            self._milestone_queue.insert(0,
                "HEAT RISING\n"
                "Your Heat is climbing. At 60% the police start RAIDING and seizing cash.\n"
                "Lower it: hire Clean Carl, buy Nightclubs, assign Crew to Heat Reduction,\n"
                "or run a Political Bribery operation."
            )
            if self._milestone_timer <= 0:
                self._milestone_timer = 7.0

        # Syndicate events
        events_mod.update_events(self, dt)

        # Rival syndicates AI tick
        rival_events = rivals_mod.update_rivals(self, dt)
        for msg in rival_events:
            if 'RAID' in msg:
                col = (255, 120, 40)   # orange — rival attack, distinct from police (red)
            elif 'ELIMINATED' in msg:
                col = theme.RED
            else:
                col = theme.TEXT_MUTED
            ui.push_notification(msg, col)

        # Rival outcome timer
        if self._rival_outcome_timer > 0:
            self._rival_outcome_timer -= dt

        # Territory outcome timer
        if self._territory_outcome_timer > 0:
            self._territory_outcome_timer -= dt

        # Crew heat reduction (passive)
        crew = getattr(self, 'crew', None)
        if crew:
            heat_decay = crew_mod.heat_reduction_per_sec(crew) * dt
            self.heat = max(0.0, self.heat - heat_decay)

        # Rank-up detection
        current_rank = prestige.get_rank(self.prestige_tokens)
        last_rank = getattr(self, '_last_rank', current_rank)
        if current_rank != last_rank:
            self._last_rank = current_rank
            unlock_desc = prestige.RANK_UNLOCKS.get(current_rank, '')
            self._toasts.append({
                'name': f"Rank Up: {current_rank}",
                'desc': unlock_desc,
                'category': 'prestige',
                'lifetime': 0.0
            })
            ui.push_notification(f"Rank Up → {current_rank}", theme.PRESTIGE_LABEL)
            sound.play('rankup')  # celebratory; distinct from ordinary achievements
            # Queue as milestone too — identity (flavor) leads, mechanics follow.
            rank_flavor = prestige.RANK_FLAVOR.get(current_rank, '')
            self._milestone_queue.append(
                f"RANK UP\n{current_rank}\n{rank_flavor}\n{unlock_desc}")
            if self._milestone_timer <= 0:
                self._milestone_timer = 6.0
            import src.analytics as analytics
            analytics.rank_up(current_rank, self.prestige_tokens)

        # Influence introduction — explain Influence BEFORE the player earns it.
        # Fires at 50% of the first-prestige earnings threshold so they arrive
        # at the prestige button already knowing what they'll receive.
        if (not getattr(self, '_prestige_count', 0)
                and not getattr(self, '_shown_influence_intro', False)):
            _need_inf = prestige.prestige_earnings_required(self)
            if _need_inf > 0 and self.lifetime_earnings >= _need_inf * 0.5:
                self._shown_influence_intro = True
                self._milestone_queue.insert(0,
                    "INFLUENCE\n"
                    "Prestige earns you Influence — a permanent currency.\n"
                    "Spend it in the Prestige Tree for lasting bonuses\n"
                    "that survive every reset and compound across runs."
                )
                if self._milestone_timer <= 0:
                    self._milestone_timer = 7.0

        # Near-prestige notifications: build anticipation before the gate opens.
        # 80% fires first as a heads-up; 90% fires the analytics push-notification.
        # Both flags reset on prestige so they fire again each run.
        try:
            need = prestige.prestige_earnings_required(self)
            if need > 0:
                ratio = self.lifetime_earnings / need
                if ratio >= 0.80 and not getattr(self, '_notif_near_prestige_80', False):
                    self._notif_near_prestige_80 = True
                    ui.push_notification("Prestige approaching — 80% there!", theme.PRESTIGE_LABEL)
                if ratio >= 0.90 and not getattr(self, '_push_near_prestige_fired', False):
                    import src.analytics as _anl
                    _anl.push_near_prestige(self.lifetime_earnings, need)
                    self._push_near_prestige_fired = True
                    ui.push_notification("Almost ready to PRESTIGE! — 90%", theme.PRESTIGE_LABEL)
        except Exception:
            pass

        # First-respect tutorial — fires the moment Respect (influence field) > 0
        if self.influence > 0 and not getattr(self, '_shown_influence_tutorial', False):
            self._shown_influence_tutorial = True
            self._milestone_queue.insert(0,
                "RESPECT EARNED\n"
                "Respect is your street reputation: every 25 Respect adds +1%\n"
                "global income (up to +50%), and it never resets.\n"
                "Earn it from operations, territory captures, and rivals."
            )
            if self._milestone_timer <= 0:
                self._milestone_timer = 7.0

        # Phase 111 — manager unlock milestones (replaces Phase 106 cash nudges).
        mgr_mod.tick_unlock_milestones(self)

        # Achievements — checked every 0.5s instead of every frame
        self._ach_check_timer -= dt
        newly_earned = []
        if self._ach_check_timer <= 0:
            self._ach_check_timer = 0.5
            newly_earned = check_and_earn(self)
        for name in newly_earned:
            ach = next((a for a in self.achievements if a.name == name), None)
            desc = ach.description if ach else ''
            cat  = ach.category if ach else 'money'
            self._toasts.append({'name': name, 'desc': desc, 'category': cat, 'lifetime': 0.0})
        if newly_earned:
            sound.play('achievement')
        for t in self._toasts:
            t['lifetime'] += dt
        self._toasts = [t for t in self._toasts if t['lifetime'] < 3.3]

        # Goals check
        goal_msgs = goals_mod.check_goals(self)
        for msg in goal_msgs:
            ui.push_notification(msg, theme.TEXT_GOLD)
            sound.play('achievement')

        # Phase 102: if the active Turf sub-tab became locked (e.g. a prestige
        # reset wiped the buildings that unlocked Crew), fall back to Territory so
        # the player never sits on now-locked content.
        if self._tab in ('crew', 'operations'):
            for _l, _k, _locked, _r in prestige.visible_turf_subtabs(self):
                if _k == self._tab and _locked:
                    self._tab = 'territory'
                    break

        # Rival elimination overlay timer
        if self._elim_overlay_timer > 0:
            self._elim_overlay_timer -= dt
            if self._elim_overlay_timer <= 0:
                self._elim_overlay = None

        # Prestige climax countdown (Phase 101)
        if self._prestige_climax_timer > 0:
            self._prestige_climax_timer -= dt

        # Tutorial + milestone overlays
        tut.update_overlays(self, dt, save_game)

        # Post-prestige rebuild reminder — fires once, after the celebration overlay clears
        if (getattr(self, '_post_prestige_notif', False)
                and self._prestige_climax_timer <= 0
                and not self._milestone_queue and self._milestone_timer <= 0):
            ui.push_notification("Build Corner Dealers to restart your income.", theme.TEXT_MUTED)
            self._post_prestige_notif = False

        # Track influence/respect earned this tick
        _tokens_delta = max(0, self.prestige_tokens - _tokens_before)
        _influence_delta = max(0, self.influence - _influence_before)
        if _tokens_delta > 0:
            was_first_influence = self._total_influence_earned == 0
            self._total_influence_earned += _tokens_delta
            if was_first_influence:
                try:
                    import src.analytics as analytics
                    analytics.first_influence(self.prestige_tokens)
                except Exception:
                    pass
        if _influence_delta > 0:
            self._total_respect_earned += _influence_delta

        # Dragon Patron lifecycle (requests, cooldowns, ability timers)
        try:
            dragon_mod.dragon_update(self, dt)
        except Exception:
            pass

        # Autosave
        self._autosave_timer -= dt
        if self._autosave_timer <= 0:
            self._autosave_timer = _AUTOSAVE_INTERVAL
            save_game(self)

    # ─── Draw ─────────────────────────────────────────────────────────────────
    def draw(self, surface):
        ui.clear_tooltip()
        ui.draw_background(surface, self)
        ui.draw_stats(surface, self, self._fonts)        # includes heat bar + ticker
        ui.draw_news_ticker(surface, self, self._fonts)
        total_bld = sum(b.owned for b in self.buildings)
        ui.draw_left_empire_frame(surface)
        if dragon_mod.active_dragon(self):
            ui.draw_dragon_hud(surface, self, self._fonts)
        else:
            ui.draw_scene(surface, total_bld, self._time, self)
        ui.draw_click_zone(surface, self, self._fonts)
        ui.draw_prestige_btn(surface, self, self._fonts)
        ui.draw_objectives(surface, self, self._fonts)
        ui.draw_stat_cluster(surface, self, self._fonts)
        ui.draw_panel_divider(surface, self)
        ui.draw_right_panel(surface, self, self._fonts)
        ui.draw_golden_coin(surface, self, self._fonts)
        ui.draw_particles(surface, self, self._fonts)
        ui.draw_idle_particles(surface, self, self._fonts)
        draw_toasts(surface, self._toasts, self._fonts)
        ui.draw_notifications(surface, self._fonts)
        ui.draw_event_outcome(surface, self, self._fonts)
        # Overlays (only one at a time). Prestige climax outranks all — it is the
        # largest event in the game and briefly hides the wipe underneath it.
        if self._prestige_climax_timer > 0:
            ui.draw_prestige_climax_overlay(surface, self, self._fonts)
        elif self._pending_event:
            events_mod.draw_event_overlay(surface, self, self._fonts)
        elif self._show_offline_overlay:
            ui.draw_offline_overlay(surface, self, self._fonts)
        elif self._show_daily_overlay:
            ui.draw_daily_reward_overlay(surface, self, self._fonts)
        elif self._elim_overlay and self._elim_overlay_timer > 0:
            ui.draw_elimination_overlay(surface, self, self._fonts)
        elif self._milestone_queue and self._milestone_timer > 0:
            ui.draw_milestone_overlay(surface, self, self._fonts, self._milestone_queue[0])
        elif self._tutorial_step < 5:
            tut.draw_tutorial(surface, self, self._fonts)
        ui.draw_tooltip(surface, self._fonts)

    # ─── Helpers ──────────────────────────────────────────────────────────────
    def _spawn_coin(self):
        self._coin = {'x': random.uniform(60, config.SCREEN_WIDTH - 60),
                      'y': random.uniform(145, config.SCREEN_HEIGHT - 60),
                      'lifetime': 0.0, 'pulse_t': 0.0}

    def _next_coin_timer(self) -> float:
        lo, hi = 30.0, 60.0
        return random.uniform(lo, hi)

    def _collect_coin(self, *, manual: bool = False, auto: bool = False):
        self._coin = None
        self._coin_timer = self._next_coin_timer()
        self._coins_caught += 1
        if auto:
            self._coins_auto_sal += 1
            ui.push_notification("Sal caught a golden coin!", theme.TEXT_GOLD)
        elif manual:
            self._coins_manual += 1
        effect = random.choice(['frenzy', 'lucky', 'click_storm'])
        if effect == 'frenzy':
            self._add_buff('frenzy', 15.0)
        elif effect == 'lucky':
            gain = min(self.income_per_second * 60, max(self.balance * 0.15, 1.0))
            self.balance += gain
            self.lifetime_earnings += gain
            money_debug.credit(self, gain, 'money_from_other')
            ui.push_notification(f"Lucky! +{theme.format_number(gain)}", theme.GREEN)
        else:
            self._add_buff('click_storm', 20.0)

    def _has_buff(self, name: str) -> bool:
        return any(b['name'] == name for b in self._buffs)

    def _add_buff(self, name: str, duration: float) -> None:
        self._buffs = [b for b in self._buffs if b['name'] != name]
        self._buffs.append({'name': name, 'remaining': duration, 'total': duration})

    def _spawn_click_feedback(self, pos, cv: float, crit: bool) -> None:
        """Phase 95 — floating feedback for a single click. Normal clicks stay
        quiet (one small rising number); crits get a bigger hot-coloured
        "CRIT +value" number plus a short spark burst. The value is captured
        here so the popup shows this click's real payout, never the live
        click_value (which changes with buffs/crit between frames)."""
        if not getattr(config, 'SHOW_PARTICLES', True):
            return
        x, y = float(pos[0]), float(pos[1])
        if crit:
            self._particles.append(_Particle(
                x, y, dur=config.CRIT_POPUP_DURATION, rise=config.CRIT_POPUP_RISE,
                text=f"CRIT +{theme.format_number(cv)}", crit=True))
            for _ in range(config.CRIT_SPARK_COUNT):
                self._particles.append(_Particle(
                    x + random.uniform(-14, 14), y + random.uniform(-10, 10),
                    dur=config.CRIT_SPARK_DURATION, rise=random.uniform(40, 90),
                    vx=random.uniform(-70, 70), crit=True))
        else:
            # Slight horizontal jitter so rapid-fire popups don't stack into one
            # unreadable blob during spam-clicking.
            self._particles.append(_Particle(
                x, y, dur=config.CLICK_POPUP_DURATION, rise=config.CLICK_POPUP_RISE,
                vx=random.uniform(-22, 22),
                text=f"+{theme.format_number(cv)}", crit=False))

    def _register_active_click(self) -> None:
        """Phase 94 — Hustle burst: enough clicks within a short window grants a
        temporary click-power buff. It only boosts clicks (never idle income) and
        decays once you stop, so AFK players are unaffected and clicking is never
        required. Refreshes while you keep clicking."""
        now = self._time
        win = config.CLICK_HUSTLE_WINDOW
        self._recent_clicks.append(now)
        self._recent_clicks = [t for t in self._recent_clicks if now - t <= win]
        if len(self._recent_clicks) >= config.CLICK_HUSTLE_CLICKS:
            # Phase 95 — fire activation feedback only on the transition into
            # Hustle, not on every click that keeps it refreshed, so the player
            # clearly feels their own clicking caused it.
            was_active = self._has_buff('hustle')
            self._add_buff('hustle', config.CLICK_HUSTLE_DURATION)
            if not was_active:
                sound.play('buff')
                ui.push_notification(
                    f"HUSTLE ACTIVE  ×{config.CLICK_HUSTLE_MULT:g} clicks",
                    theme.TEXT_GOLD)

    def _load(self, data: dict) -> None:
        from src.save_load import apply_save_data, BACKUP_PATH, SAVE_PATH
        import traceback
        try:
            apply_save_data(self, data)
        except Exception:
            # Corrupt save: log the error and continue with default state.
            # The backup will be used on the next load attempt via load_game().
            traceback.print_exc()
            print("[WARN] Save data corrupt — starting fresh. Backup preserved.")
            # Rename broken save so the backup can surface next time.
            import os
            try:
                if os.path.exists(SAVE_PATH):
                    os.rename(SAVE_PATH, SAVE_PATH + ".corrupt")
            except OSError:
                pass
