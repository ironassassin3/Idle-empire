"""Achievement system — 50+ achievements across money, buildings, prestige, managers, time, secret."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Callable, List
import pygame
import config
import src.theme as theme

_TOAST_DURATION = 3.0
_TOAST_SLIDE_H = 40

# Category colors
_CAT_COLORS = {
    'money':      (255, 200, 50),
    'clicks':     (80, 180, 255),
    'building':   (60, 200, 120),
    'prestige':   (180, 80, 255),
    'manager':    (255, 130, 50),
    'time':       (130, 200, 255),
    'secret':     (255, 80, 140),
    'territory':  (60, 160, 200),
    'rival':      (220, 80, 60),
    'operations': (160, 100, 220),
}


@dataclass
class Achievement:
    name: str
    description: str
    condition: Callable = field(repr=False)
    earned: bool = False
    category: str = 'money'

    def check(self, state) -> bool:
        if self.earned:
            return False
        try:
            if self.condition(state):
                self.earned = True
                return True
        except Exception:
            pass
        return False


def _total_owned(s):
    return sum(b.owned for b in s.buildings)

def _bld(s, idx):
    return s.buildings[idx].owned if idx < len(s.buildings) else 0

def _mgr_count(s):
    return sum(1 for m in s.managers if m.hired)

def _upg_count(s):
    return sum(1 for u in s.upgrades if u.purchased)

def _player_control_pct(s):
    territories = getattr(s, 'territories', [])
    total = len(territories)
    if total == 0:
        return 0.0
    owned = sum(1 for t in territories if t.unlocked)
    return owned / total

def _rivals_defeated(s):
    return getattr(s, '_total_rivals_defeated', 0)

def _ops_completed(s):
    return getattr(s, '_total_ops_completed', 0)

def _territories_captured(s):
    return getattr(s, '_total_territories_captured', 0)


def make_achievements() -> List[Achievement]:
    A = Achievement
    return [
        # ── MONEY ───────────────────────────────────────────────────────────────
        A("First Dollar",       "Earn your first dollar",
          lambda s: s.lifetime_earnings >= 1,            category='money'),
        A("Pocket Change",      "Reach $1,000 balance",
          lambda s: s.balance >= 1_000,                  category='money'),
        A("Street Money",       "Earn $10,000 lifetime",
          lambda s: s.lifetime_earnings >= 10_000,       category='money'),
        A("Small Timer",        "Earn $100,000 lifetime",
          lambda s: s.lifetime_earnings >= 100_000,      category='money'),
        A("Millionaire",        "Earn $1M lifetime",
          lambda s: s.lifetime_earnings >= 1_000_000,    category='money'),
        A("Ten-Million Club",   "Earn $10M lifetime",
          lambda s: s.lifetime_earnings >= 10_000_000,   category='money'),
        A("Hundred-Mil Boss",   "Earn $100M lifetime",
          lambda s: s.lifetime_earnings >= 100_000_000,  category='money'),
        A("Billionaire",        "Earn $1B lifetime",
          lambda s: s.lifetime_earnings >= 1_000_000_000, category='money'),
        A("Oligarch",           "Earn $10B lifetime",
          lambda s: s.lifetime_earnings >= 10_000_000_000, category='money'),
        A("Trillionaire",       "Earn $1T lifetime",
          lambda s: s.lifetime_earnings >= 1_000_000_000_000, category='money'),
        A("Quadrillionaire",    "Earn $1Q lifetime",
          lambda s: s.lifetime_earnings >= 1_000_000_000_000_000, category='money'),
        A("High Roller",        "Have $1M in the bank at once",
          lambda s: s.balance >= 1_000_000,              category='money'),
        A("Vault",              "Have $1B in the bank at once",
          lambda s: s.balance >= 1_000_000_000,          category='money'),

        # ── CLICKS ──────────────────────────────────────────────────────────────
        A("First Click",        "Click once",
          lambda s: s._click_count >= 1,                 category='clicks'),
        A("Two-Finger Typist",  "Click 50 times",
          lambda s: s._click_count >= 50,                category='clicks'),
        A("Clicker",            "Click 100 times",
          lambda s: s._click_count >= 100,               category='clicks'),
        A("Click Addict",       "Click 500 times",
          lambda s: s._click_count >= 500,               category='clicks'),
        A("Click Machine",      "Click 1,000 times",
          lambda s: s._click_count >= 1_000,             category='clicks'),
        A("Click Enthusiast",   "Click 5,000 times",
          lambda s: s._click_count >= 5_000,             category='clicks'),
        A("Click God",          "Click 10,000 times",
          lambda s: s._click_count >= 10_000,            category='clicks'),
        A("Carpal Tunnel",      "Click 50,000 times",
          lambda s: s._click_count >= 50_000,            category='clicks'),
        A("One Hundred K",      "Click 100,000 times",
          lambda s: s._click_count >= 100_000,           category='clicks'),

        # ── BUILDINGS ───────────────────────────────────────────────────────────
        A("First Hire",         "Own your first building",
          lambda s: _total_owned(s) >= 1,                category='building'),
        A("Small Crew",         "Own 10 buildings total",
          lambda s: _total_owned(s) >= 10,               category='building'),
        A("Expanding Fast",     "Own 25 buildings total",
          lambda s: _total_owned(s) >= 25,               category='building'),
        A("Industrial Scale",   "Own 50 buildings total",
          lambda s: _total_owned(s) >= 50,               category='building'),
        A("Empire Builder",     "Own 100 buildings total",
          lambda s: _total_owned(s) >= 100,              category='building'),
        A("Big Spender",        "Own 200 buildings total",
          lambda s: _total_owned(s) >= 200,              category='building'),
        A("Megacorp",           "Own 500 buildings total",
          lambda s: _total_owned(s) >= 500,              category='building'),
        A("Corner King",        "Own 25 Corner Dealers",
          lambda s: _bld(s, 0) >= 25,                    category='building'),
        A("Protection Mogul",   "Own 25 Protection Rackets",
          lambda s: _bld(s, 1) >= 25,                    category='building'),
        A("Chop King",          "Own 25 Chop Shops",
          lambda s: _bld(s, 2) >= 25,                    category='building'),
        A("High Stakes",        "Own 10 Betting Rings",
          lambda s: _bld(s, 3) >= 10,                    category='building'),
        A("Pawnbroker",         "Own 10 Pawn Shops",
          lambda s: _bld(s, 4) >= 10,                    category='building'),
        A("Loan Baron",         "Own 5 Loan Shark Offices",
          lambda s: _bld(s, 5) >= 5,                     category='building'),
        A("House Always Wins",  "Own a Casino",
          lambda s: _bld(s, 6) >= 1,                     category='building'),
        A("Made Man",           "Own a Crime Syndicate HQ",
          lambda s: _bld(s, 10) >= 1,                    category='building'),
        A("Diversified",        "Own at least 1 of every building",
          lambda s: len(s.buildings) >= 11 and all(_bld(s, i) >= 1 for i in range(11)),
          category='building'),

        # ── PRESTIGE ────────────────────────────────────────────────────────────
        A("Prestige!",          "Complete your first prestige",
          lambda s: getattr(s, '_prestige_count', 0) >= 1, category='prestige'),
        A("Second Wind",        "Prestige twice",
          lambda s: getattr(s, '_prestige_count', 0) >= 2, category='prestige'),
        A("Prestiged Pro",      "Prestige 5 times",
          lambda s: getattr(s, '_prestige_count', 0) >= 5, category='prestige'),
        A("Prestige Legend",    "Prestige 10 times",
          lambda s: getattr(s, '_prestige_count', 0) >= 10, category='prestige'),
        A("Infinite Loop",      "Prestige 25 times",
          lambda s: getattr(s, '_prestige_count', 0) >= 25, category='prestige'),
        A("Perk Collector",     "Buy 3 prestige perks",
          lambda s: len(getattr(s, 'perks_purchased', [])) >= 3, category='prestige'),
        A("Full Perk Tree",     "Buy all 10 prestige perks",
          lambda s: len(getattr(s, 'perks_purchased', [])) >= 10, category='prestige'),
        A("Influential",        "Earn 20 influence",
          lambda s: s.prestige_tokens >= 20,             category='prestige'),

        # ── MANAGERS ────────────────────────────────────────────────────────────
        A("First Manager",      "Hire your first manager",
          lambda s: _mgr_count(s) >= 1,                  category='manager'),
        A("Full Staff",         "Hire 5 managers",
          lambda s: _mgr_count(s) >= 5,                  category='manager'),
        A("Fully Automated",    "Hire all 13 managers",
          lambda s: _mgr_count(s) >= 13,                 category='manager'),

        # ── UPGRADES ────────────────────────────────────────────────────────────
        A("Upgrade Rookie",     "Purchase 3 upgrades",
          lambda s: _upg_count(s) >= 3,                  category='building'),
        A("Upgrade Hoarder",    "Purchase 10 upgrades",
          lambda s: _upg_count(s) >= 10,                 category='building'),
        A("Max Research",       "Purchase 20 upgrades",
          lambda s: _upg_count(s) >= 20,                 category='building'),

        # ── TIME ────────────────────────────────────────────────────────────────
        A("Just Starting",      "Play for 5 minutes",
          lambda s: getattr(s, '_play_time', 0) >= 300,  category='time'),
        A("Committed",          "Play for 30 minutes",
          lambda s: getattr(s, '_play_time', 0) >= 1800, category='time'),
        A("Veteran Boss",       "Play for 2 hours",
          lambda s: getattr(s, '_play_time', 0) >= 7200, category='time'),
        A("Golden Coin Finder", "Catch a golden coin",
          lambda s: getattr(s, '_coins_caught', 0) >= 1, category='time'),
        A("Coin Collector",     "Catch 10 golden coins",
          lambda s: getattr(s, '_coins_caught', 0) >= 10, category='time'),

        # ── SECRET ──────────────────────────────────────────────────────────────
        A("Whale",              "Have $1T in the bank at once",
          lambda s: s.balance >= 1_000_000_000_000,      category='secret'),
        A("Speed Runner",       "Prestige within 10 minutes",
          lambda s: (getattr(s, '_prestige_count', 0) >= 1
                     and getattr(s, '_play_time', 9999) < 600), category='secret'),
        A("No Manager Run",     "Reach $1B with no managers hired",
          lambda s: (s.lifetime_earnings >= 1_000_000_000
                     and _mgr_count(s) == 0),             category='secret'),
        A("The Phantom",        "Earn $1M while offline",
          lambda s: getattr(s, '_offline_gain', 0) >= 1_000_000, category='secret'),
        A("Night Owl",          "Buy the Night Shift prestige perk",
          lambda s: 'offline_1' in getattr(s, 'perks_purchased', []), category='secret'),

        # ── TERRITORY ───────────────────────────────────────────────────────────
        A("First District",     "Capture your first district",
          lambda s: _territories_captured(s) >= 1,             category='territory'),
        A("Expanding Turf",     "Capture 5 territories",
          lambda s: _territories_captured(s) >= 5,             category='territory'),
        A("City Spreader",      "Control half the city",
          lambda s: _player_control_pct(s) >= 0.5,             category='territory'),
        A("City Dominator",     "Control the entire city",
          lambda s: _player_control_pct(s) >= 1.0,             category='territory'),

        # ── RIVALS ──────────────────────────────────────────────────────────────
        A("First Blood",        "Defeat your first rival syndicate",
          lambda s: _rivals_defeated(s) >= 1,                  category='rival'),
        A("Rival Slayer",       "Defeat 3 rival syndicates",
          lambda s: _rivals_defeated(s) >= 3,                  category='rival'),
        A("Apex Predator",      "Defeat 10 rival syndicates",
          lambda s: _rivals_defeated(s) >= 10,                 category='rival'),
        A("Untouchable Boss",   "Defeat all active rivals in one run",
          lambda s: (len(getattr(s, 'rivals', [])) > 0 and
                     all(r.status == 'Eliminated'
                         for r in getattr(s, 'rivals', []) if r)),
          category='rival'),

        # ── OPERATIONS ──────────────────────────────────────────────────────────
        A("First Op",           "Complete your first operation",
          lambda s: _ops_completed(s) >= 1,                    category='operations'),
        A("Street Operative",   "Complete 10 operations",
          lambda s: _ops_completed(s) >= 10,                   category='operations'),
        A("Ghost Operative",    "Complete 25 operations",
          lambda s: _ops_completed(s) >= 25,                   category='operations'),
        A("Veteran Operative",  "Complete 100 operations",
          lambda s: _ops_completed(s) >= 100,                  category='operations'),
    ]


def check_and_earn(state) -> List[str]:
    """Returns names of newly earned achievements this frame."""
    return [a.name for a in state.achievements if a.check(state)]


# ─── Toast rendering ───────────────────────────────────────────────────────────

_TOAST_W = 300
_TOAST_H  = 80
_SLIDE_DUR  = 0.28
_SIT_DUR    = 2.6
_FADE_DUR   = 0.45
_TOTAL_DUR  = _SLIDE_DUR + _SIT_DUR + _FADE_DUR


def draw_toasts(surface: pygame.Surface, toasts: list, fonts: dict) -> None:
    x_base  = config.SCREEN_WIDTH - _TOAST_W - 18
    anchor_y = config.SCREEN_HEIGHT - 90

    for stack_i, toast in enumerate(reversed(toasts)):
        lt = toast['lifetime']

        if lt < _SLIDE_DUR:
            ease    = (lt / _SLIDE_DUR) ** 0.5
            slide_y = int(anchor_y + _TOAST_H * (1.0 - ease))
        else:
            slide_y = anchor_y

        y = slide_y - stack_i * (_TOAST_H + 10)

        fade_start = _SLIDE_DUR + _SIT_DUR
        if lt > fade_start:
            alpha = max(0, int(255 * (1.0 - (lt - fade_start) / _FADE_DUR)))
        else:
            alpha = 255

        cat = toast.get('category', 'money')
        cat_col = _CAT_COLORS.get(cat, theme.ACCENT)

        card = pygame.Surface((_TOAST_W, _TOAST_H), pygame.SRCALPHA)

        # Background
        pygame.draw.rect(card, (*theme.BG_PANEL, 250), card.get_rect(), border_radius=10)
        # Left color bar
        pygame.draw.rect(card, (*cat_col, 255), pygame.Rect(0, 6, 4, _TOAST_H - 12), border_radius=2)
        # Border
        pygame.draw.rect(card, (*cat_col, 120), card.get_rect(), border_radius=10, width=1)

        # Star icon (category colored)
        star = fonts['md'].render("*", True, cat_col)
        card.blit(star, (12, 10))

        # Achievement name
        name_s = fonts['sm'].render(toast['name'], True, theme.TEXT_GOLD)
        card.blit(name_s, (44, 10))

        # Category label
        cat_s = fonts['xs'].render(cat.upper(), True, cat_col)
        card.blit(cat_s, (44, 36))

        # Description
        desc   = toast.get('desc', '')
        if desc:
            desc_s = fonts['xs'].render(desc, True, theme.TEXT_MUTED)
            card.blit(desc_s, (44, 56))

        # Progress bar
        ratio  = max(0.0, 1.0 - lt / _TOTAL_DUR)
        bar_bw = _TOAST_W - 12
        bar_fw = max(0, int(bar_bw * ratio))
        pygame.draw.rect(card, (*theme.BG_CARD, 180),
                         pygame.Rect(6, _TOAST_H - 7, bar_bw, 4), border_radius=2)
        if bar_fw > 0:
            pygame.draw.rect(card, (*cat_col, 200),
                             pygame.Rect(6, _TOAST_H - 7, bar_fw, 4), border_radius=2)

        card.set_alpha(alpha)
        surface.blit(card, (x_base, y))
