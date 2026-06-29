VERSION = "v1.0"

SCREEN_WIDTH = 900
SCREEN_HEIGHT = 720
FPS = 60
TITLE = "Criminal Empire"

# Design resolution — all scaling math references these values.
BASE_WIDTH  = 900
BASE_HEIGHT = 720

# Live scale factors — updated by ui.reinit_layout() on every resize.
# At the default 900×720 these are all 1.0 so nothing changes.
SCALE_X  = 1.0   # current_w / BASE_WIDTH
SCALE_Y  = 1.0   # current_h / BASE_HEIGHT
UI_SCALE = 1.0   # min(SCALE_X, SCALE_Y) — for uniform geometry (radii, border widths)

# Minimum playable size
MIN_WIDTH  = 480
MIN_HEIGHT = 480

# Colors
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GRAY = (128, 128, 128)
RED = (220, 50, 50)
GREEN = (50, 200, 50)
BLUE = (50, 100, 220)

GRADIENT_TOP = (15, 15, 25)
GRADIENT_BOT = (5, 5, 10)

MUSIC_VOLUME = 0.5
SHOW_PARTICLES = True

# ── Global UI spacing constants (Phase 90) ────────────────────────────────────
# Design-space pixel values; wrap with scale.sd() at the use site so they scale
# with resolution. Never hardcode new spacing offsets in menu/modal layout code —
# compose from these so sections can never overlap (see _settings_layout).
SECTION_GAP   = 20   # between major logical sections
GROUP_GAP     = 16   # between grouped/stacked controls
LABEL_GAP     = 8    # between a label and the control it describes
BUTTON_GAP    = 12   # between adjacent buttons
BOTTOM_MARGIN = 20   # minimum space between last content and a panel's bottom edge

# ── Shared in-game UI layout constants (Phase 89) ─────────────────────────────
# Design-space px; wrap with scale.sd() at the use site. Screens should inherit
# these instead of inventing new spacing values, so layout stays consistent.
UI_SECTION_GAP     = 16   # vertical gap between major sections inside a panel
UI_LINE_GAP        = 8    # vertical gap between stacked text lines
UI_CARD_PADDING    = 10   # inner padding inside a card
UI_CARD_MIN_HEIGHT = 64   # minimum height a content card may collapse to
UI_TAB_PADDING     = 8    # horizontal padding inside a tab, each side
UI_TAB_GAP         = 4    # horizontal gap between adjacent tabs
UI_MODAL_PADDING   = 20   # inner padding for modal/popup panels

# ── Prestige climax (Phase 101) ───────────────────────────────────────────────
# Duration of the run-ending ceremony overlay shown between "prestige confirmed"
# and the fresh run. Short and skippable — emotion, not spectacle.
PRESTIGE_CLIMAX_DURATION = 3.0

# ── Territory economy scaling ───────────────────────────────────────────────────
# Turf income/click bonuses scale with empire-route progress toward next prestige.
# Cubic curve + cap keeps early captures from snowballing first-prestige pacing.
TERRITORY_ECONOMY_SCALE_EXPONENT = 3.0
TERRITORY_ECONOMY_SCALE_MAX = 0.30
TERRITORY_INCOME_BONUS_CAP = 0.18

# ── Active play (Phase 94) ────────────────────────────────────────────────────
# Keeps manual clicking relevant for the whole game WITHOUT making it required.
# Idle stays the primary income source; these only add a supplemental active layer.
CLICK_IPS_FRACTION    = 0.055  # each click pays this fraction of 1s income (Phase 104:
                               # scales active layer with empire so late-game clicks stay
                               # ~15–30% cumulative without early dealer flat bonus)
CLICK_CRIT_CHANCE     = 0.05  # base probability a click is critical
CLICK_CRIT_MIN        = 2.0   # critical clicks pay MIN..MAX × the click value
CLICK_CRIT_MAX        = 8.0
CLICK_HUSTLE_WINDOW   = 2.0   # seconds — sustained-clicking detection window
CLICK_HUSTLE_CLICKS   = 8     # clicks within the window to trigger the Hustle buff
CLICK_HUSTLE_DURATION = 6.0   # seconds Hustle lasts (refreshes while you keep clicking)
CLICK_HUSTLE_MULT     = 2.35  # click-value multiplier while Hustle is active
# Phase 104 — per-dealer flat click bonus. Phase 103 measured 1.0/dealer as 78-93% of
# early click value. Lowered so crit/Hustle/VFX carry the feel while idle income leads.
CLICK_DEALER_BONUS    = 0.10  # cash/click per Corner Dealer owned (was 1.0 → 0.20)

# Phase 104 — set True to accumulate per-source money totals (debug print only).
DEBUG_MONEY_SOURCES   = False

# ── Click feedback / juice (Phase 95) ─────────────────────────────────────────
# Feel only — these touch presentation (floating text, particles), never payouts.
CLICK_POPUP_DURATION  = 0.85  # normal floating "+value" lifetime (s); quick, low-spam
CRIT_POPUP_DURATION   = 1.30  # crit "CRIT +value" lingers longer so it's read
CLICK_POPUP_RISE      = 64.0  # px a normal popup floats up over its lifetime
CRIT_POPUP_RISE       = 96.0  # crit popup floats higher (more presence)
CRIT_SPARK_COUNT      = 9     # spark dots that burst from a crit (visual only)
CRIT_SPARK_DURATION   = 0.55  # crit spark lifetime (s)

# ── Automation timing (Phase 106) ─────────────────────────────────────────────
# No constant lives here — manager costs are defined in src/managers.py — but the
# re-tune is recorded for traceability. Phase 105 measured the first manager at
# 33-50 min and The Accountant's auto-buy NEVER reached (its $60M cost sat above
# the $20M prestige gate). Phase 106 lowered the early-to-mid manager ladder so
# the first hire lands early and the auto-buy Accountant ($1.5M, was $60M) is
# reachable BEFORE first prestige (~8-11 min ahead of it with the hire-nudge).
# Cost alone can't land auto-buy in the early-mid run — building reinvestment
# out-ROIs managers until near prestige. See src/managers.py + _measure_p106.py.

# Manager purchase automation (Accountant, Mechanic, Talent Scout perk) — post-P1.
MANAGER_AUTOBUY_REQUIRES_PRESTIGE = True
MANAGER_AUTOBUY_MIN_PRESTIGE_COUNT = 1
