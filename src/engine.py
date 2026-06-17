import pygame
import config
from src.states import StateManager


class Engine:
    """Core game engine: owns the window, clock, and state manager."""

    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode(
            (config.SCREEN_WIDTH, config.SCREEN_HEIGHT),
            pygame.RESIZABLE,
        )
        pygame.display.set_caption(config.TITLE)
        self.clock = pygame.time.Clock()
        self.running = False
        self.state_manager = StateManager()
        self._apply_layout(config.SCREEN_WIDTH, config.SCREEN_HEIGHT)

    def _apply_layout(self, w: int, h: int) -> None:
        """Recompute layout + fonts for the new window size."""
        import src.ui as ui
        import src.theme as theme

        w = max(w, config.MIN_WIDTH)
        h = max(h, config.MIN_HEIGHT)
        config.SCREEN_WIDTH  = w
        config.SCREEN_HEIGHT = h

        ui.reinit_layout(w, h)
        ui.invalidate_atmosphere_cache()
        ui._GLOW_SURFS = None   # invalidate cached glow surfaces
        ui._CLICK_GLOW_SURF = None
        ui._CLICK_GLOW_HOVER = None
        ui._COIN_GLOW_SURF  = None

        # Re-create fonts scaled to new height; propagate to active state.
        new_fonts = theme.make_fonts(h)
        for state in self.state_manager._stack:
            if hasattr(state, '_fonts'):
                state._fonts = new_fonts
            if hasattr(state, '_bg'):
                state._bg = ui.make_bg_surface()

    def push_state(self, state):
        self.state_manager.push(state)

    def run(self):
        self.running = True
        while self.running:
            dt = self.clock.tick(config.FPS) / 1000.0

            events = pygame.event.get()
            for event in events:
                if event.type == pygame.QUIT:
                    self.running = False
                elif event.type == pygame.VIDEORESIZE:
                    self._apply_layout(event.w, event.h)

            self.state_manager.handle_events(events)
            self.state_manager.update(dt)

            self.screen.fill(config.BLACK)
            self.state_manager.draw(self.screen)
            pygame.display.flip()

        pygame.quit()
