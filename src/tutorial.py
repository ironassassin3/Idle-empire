"""First-run tutorial overlay and milestone/achievement popup queue."""
from __future__ import annotations
import math
import pygame
import config
import src.theme as theme
import src.scale as scale

_W, _H = 220, 52   # design-space base; real box is sized to the text (Phase 92)
_ANIM_DUR = 0.3

# Rect of the "skip" hint from the most recent draw_tutorial() call.
# Checked in states.py _handle_click so players can click it to skip all steps.
_skip_rect: pygame.Rect | None = None


def get_skip_rect() -> pygame.Rect | None:
    return _skip_rect


def skip_tutorial(state, save_fn=None) -> None:
    """Jump directly to tutorial complete (step 5)."""
    state._tutorial_step = len(_STEPS)
    state._tutorial_age = 0.0
    if save_fn:
        save_fn(state)

# (text, arrow_side) — side is 'bottom','left','right','top'
_STEPS = [
    ("Click to earn money",              'bottom'),  # 0 → click button
    ("Buy buildings to earn passively",  'top'),     # 1 → pickpocket card
    ("Upgrades multiply your earnings",  'bottom'),  # 2 → upgrades tab
    ("Hire managers to automate",        'bottom'),  # 3 → managers tab
    ("Prestige for a multiplier boost",  'top'),     # 4 → prestige button
]


def _targets(state) -> list[tuple[int, int]]:
    import src.ui as ui
    r = ui.CLICK_RECT
    cr = ui.get_content_rect('buildings')
    prestige_btn = ui.PRESTIGE_RECT
    # Phase 100: Upgrades and Managers are top-level tabs now, so point at their
    # real centers in the main tab bar (text-width geometry, Phase 89).
    fonts = getattr(state, '_fonts', None)
    tab_centers = {}
    if fonts is not None:
        for tr, _label, key in ui.main_tab_rects(state, fonts):
            tab_centers[key] = tr.center
    tab_y = ui.HEADER_H + ui.TAB_H // 2
    upgrades_c = tab_centers.get('upgrades', (ui.RIGHT_X + 120, tab_y))
    managers_c = tab_centers.get('managers', (ui.RIGHT_X + 200, tab_y))
    return [
        (r.centerx, r.centery),                         # 0: click button
        (cr.x + cr.width // 2, cr.y + 50),              # 1: buildings content
        upgrades_c,                                      # 2: upgrades tab
        managers_c,                                      # 3: managers tab
        (prestige_btn.centerx, prestige_btn.centery),   # 4: prestige button
    ]


def draw_tutorial(surface: pygame.Surface, state, fonts: dict) -> None:
    global _skip_rect
    step = getattr(state, '_tutorial_step', 0)
    if step >= len(_STEPS):
        _skip_rect = None
        return

    text, arrow_side = _STEPS[step]
    targets = _targets(state)
    tx, ty = targets[step]

    tut_age = getattr(state, '_tutorial_age', 0.0)
    alpha = min(255, int(255 * tut_age / _ANIM_DUR))

    # Box sized to the (scaled) text so it never clips at high resolution.
    ts = fonts['xs'].render(text, True, theme.TEXT_PRIMARY)
    pad_x, pad_y = scale.sd(14), scale.sd(8)
    bw = min(ts.get_width() + 2 * pad_x, config.SCREEN_WIDTH - scale.sd(12))
    bh = ts.get_height() + 2 * pad_y

    OFFSET = scale.sd(34)
    if arrow_side == 'bottom':
        bx = tx - bw // 2
        by = ty - bh - OFFSET - scale.sd(10)
    elif arrow_side == 'top':
        bx = tx - bw // 2
        by = ty + OFFSET + scale.sd(10)
    elif arrow_side == 'left':
        bx = tx + OFFSET + scale.sd(10)
        by = ty - bh // 2
    else:
        bx = tx - bw - OFFSET - scale.sd(10)
        by = ty - bh // 2

    bx = max(6, min(bx, config.SCREEN_WIDTH - bw - 6))
    by = max(6, min(by, config.SCREEN_HEIGHT - bh - 6))

    box_surf = pygame.Surface((bw, bh), pygame.SRCALPHA)
    pygame.draw.rect(box_surf, (*theme.BG_PANEL, alpha), box_surf.get_rect(), border_radius=8)
    pygame.draw.rect(box_surf, (*theme.ACCENT, min(255, alpha)), box_surf.get_rect(), border_radius=8, width=1)

    ts.set_alpha(alpha)
    box_surf.blit(ts, ts.get_rect(center=(bw // 2, bh // 2)))
    surface.blit(box_surf, (bx, by))

    tri_alpha = alpha
    tri_col = (*theme.ACCENT, tri_alpha)
    if arrow_side == 'bottom':
        mid_x = max(10, min(bw - 10, tx - bx))
        ax = bx + mid_x; ay = by + bh
        pts = [(ax, ay), (ax - 7, ay + 10), (ax + 7, ay + 10)]
    elif arrow_side == 'top':
        mid_x = max(10, min(bw - 10, tx - bx))
        ax = bx + mid_x; ay = by
        pts = [(ax, ay), (ax - 7, ay - 10), (ax + 7, ay - 10)]
    elif arrow_side == 'left':
        mid_y = max(10, min(bh - 10, ty - by))
        ax = bx; ay = by + mid_y
        pts = [(ax, ay), (ax - 10, ay - 7), (ax - 10, ay + 7)]
    else:
        mid_y = max(10, min(bh - 10, ty - by))
        ax = bx + bw; ay = by + mid_y
        pts = [(ax, ay), (ax + 10, ay - 7), (ax + 10, ay + 7)]

    tri_draw = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
    pygame.draw.polygon(tri_draw, tri_col, pts)
    surface.blit(tri_draw, (0, 0))

    pulse = 0.55 + 0.45 * math.sin(getattr(state, '_time', 0.0) * 2.5)
    hint_surf = fonts['xs'].render("[ skip tutorial ]", True, theme.TEXT_MUTED)
    hint_surf.set_alpha(int(alpha * pulse))
    # Skip must ALWAYS be visible+clickable (Phase 89, release-breaking fix).
    # Below the box by default, but flip above it if that would fall off-screen
    # (the box itself is clamped, but the hint below it previously was not), and
    # clamp horizontally so it never leaves the window.
    hw, hh = hint_surf.get_width(), hint_surf.get_height()
    skip_cy = by + bh + scale.sd(22)
    if skip_cy + hh // 2 > config.SCREEN_HEIGHT - 6:
        skip_cy = by - scale.sd(14)
    skip_cx = bx + bw // 2
    skip_cx = max(hw // 2 + 6, min(skip_cx, config.SCREEN_WIDTH - hw // 2 - 6))
    hint_pos = hint_surf.get_rect(center=(skip_cx, skip_cy))
    surface.blit(hint_surf, hint_pos)
    _skip_rect = hint_pos


def advance_tutorial(state, save_fn=None) -> None:
    step = getattr(state, '_tutorial_step', 0)
    state._tutorial_step = min(step + 1, len(_STEPS))
    state._tutorial_age = 0.0
    if save_fn:
        save_fn(state)


def should_auto_dismiss(state) -> bool:
    step = getattr(state, '_tutorial_step', 0)
    age = getattr(state, '_tutorial_age_step4', 0.0)
    return step == 4 and age >= 6.0


# ─── Milestone thresholds (must match _MILESTONE_DATA in ui.py) ───────────────
_MILESTONE_THRESHOLDS = [1_000, 10_000, 100_000, 1_000_000, 10_000_000,
                         100_000_000, 1_000_000_000]

# Auto-dismiss after this many seconds — fixes the softlock
_MILESTONE_AUTO_DISMISS = 5.0


def update_overlays(state, dt, save_fn) -> None:
    """Update tutorial age/step4 auto-dismiss and milestone queue. Call once per frame."""
    step = getattr(state, '_tutorial_step', 0)
    if step < len(_STEPS):
        state._tutorial_age = min(getattr(state, '_tutorial_age', 0.0) + dt, 1.0)
        if step == 4:
            state._tutorial_age_step4 = getattr(state, '_tutorial_age_step4', 0.0) + dt
            if state._tutorial_age_step4 >= 6.0:
                advance_tutorial(state, save_fn)

    shown = getattr(state, '_shown_milestones', set())
    queue = getattr(state, '_milestone_queue', [])

    # Enqueue newly crossed thresholds
    for thresh in _MILESTONE_THRESHOLDS:
        if state.lifetime_earnings >= thresh and thresh not in shown:
            shown.add(thresh)
            queue.append(thresh)

    # Advance/auto-dismiss the milestone timer
    timer = getattr(state, '_milestone_timer', 0.0)
    if queue:
        if timer <= 0:
            # Start showing the first item in the queue
            state._milestone_timer = _MILESTONE_AUTO_DISMISS
        else:
            state._milestone_timer = timer - dt
            if state._milestone_timer <= 0:
                # Auto-dismiss: pop item, start next if any
                if queue:
                    queue.pop(0)
                state._milestone_timer = _MILESTONE_AUTO_DISMISS if queue else 0.0
    else:
        state._milestone_timer = 0.0
