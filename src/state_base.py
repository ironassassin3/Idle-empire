"""GameState ABC and StateManager — import from here to avoid circular deps."""
from __future__ import annotations
import abc


class GameState(abc.ABC):
    """Base class for all game states."""

    def __init__(self, state_manager):
        self.state_manager = state_manager

    @abc.abstractmethod
    def handle_events(self, events): pass

    @abc.abstractmethod
    def update(self, dt): pass

    @abc.abstractmethod
    def draw(self, surface): pass

    def on_enter(self): pass
    def on_exit(self): pass


class StateManager:
    """Manages a stack of GameState instances."""

    def __init__(self):
        self._stack = []

    @property
    def current(self):
        return self._stack[-1] if self._stack else None

    def push(self, state):
        if self.current:
            self.current.on_exit()
        self._stack.append(state)
        state.on_enter()

    def pop(self):
        if not self._stack:
            return
        self._stack.pop().on_exit()
        if self.current:
            self.current.on_enter()

    def replace(self, state):
        if self._stack:
            self._stack.pop().on_exit()
        self._stack.append(state)
        state.on_enter()

    def handle_events(self, events):
        if self.current:
            self.current.handle_events(events)

    def update(self, dt):
        if self.current:
            self.current.update(dt)

    def draw(self, surface):
        if self.current:
            self.current.draw(surface)
