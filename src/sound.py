"""Sound manager — procedural PCM, no numpy required."""
from __future__ import annotations
import array
import math
import random
import pygame

_SOUNDS: dict = {}
_VOL_SFX = 0.5
_SAMPLE_RATE = 22050


def _make_buffer(samples_l: list) -> bytes:
    """Convert list of int16 mono samples to stereo 16-bit LE bytes."""
    buf = array.array('h')
    for s in samples_l:
        s = max(-32767, min(32767, s))
        buf.append(s)
        buf.append(s)
    return buf.tobytes()


def _sine(freq: float, dur_ms: int, vol: float = 0.4, fade_ms: int = 10) -> pygame.mixer.Sound:
    n   = int(_SAMPLE_RATE * dur_ms / 1000)
    fn  = int(_SAMPLE_RATE * fade_ms / 1000)
    amp = int(32767 * vol)
    samples = []
    for i in range(n):
        envelope = min(1.0, (n - i) / fn) if fn and i >= n - fn else 1.0
        samples.append(int(amp * envelope * math.sin(2 * math.pi * freq * i / _SAMPLE_RATE)))
    return pygame.mixer.Sound(buffer=_make_buffer(samples))


def _two_tone(f1: float, f2: float, d1_ms: int, d2_ms: int, vol: float = 0.35) -> pygame.mixer.Sound:
    n1, n2 = int(_SAMPLE_RATE * d1_ms / 1000), int(_SAMPLE_RATE * d2_ms / 1000)
    amp = int(32767 * vol)
    samples = []
    for i in range(n1):
        fade = (n1 - i) / n1
        samples.append(int(amp * fade * math.sin(2 * math.pi * f1 * i / _SAMPLE_RATE)))
    for i in range(n2):
        fade = (n2 - i) / n2
        samples.append(int(amp * fade * math.sin(2 * math.pi * f2 * i / _SAMPLE_RATE)))
    return pygame.mixer.Sound(buffer=_make_buffer(samples))


def _arpeggio(notes: list, vol: float = 0.42) -> pygame.mixer.Sound:
    """Sequence of (freq_hz, dur_ms) tones rendered as one phrase.

    Reuses the same int16 buffer path as the other generators — this is the
    only new primitive Phase 99 adds. A rising note sequence reads as an
    "event" (a milestone happened), not a flat button press; more notes, a
    higher peak, and louder volume make one phrase feel bigger than another,
    which is what builds the audible tier hierarchy.
    """
    amp = int(32767 * vol)
    samples = []
    for freq, dur_ms in notes:
        n = int(_SAMPLE_RATE * dur_ms / 1000)
        for i in range(n):
            fade = (n - i) / n  # per-note decay so the steps read as distinct
            samples.append(int(amp * fade * math.sin(2 * math.pi * freq * i / _SAMPLE_RATE)))
    return pygame.mixer.Sound(buffer=_make_buffer(samples))


def _noise(dur_ms: int, vol: float = 0.2) -> pygame.mixer.Sound:
    n = int(_SAMPLE_RATE * dur_ms / 1000)
    amp = int(32767 * vol)
    samples = []
    for i in range(n):
        fade = (n - i) / n
        samples.append(int(amp * fade * (random.random() * 2 - 1)))
    return pygame.mixer.Sound(buffer=_make_buffer(samples))


def init() -> bool:
    global _SOUNDS
    try:
        pygame.mixer.pre_init(_SAMPLE_RATE, -16, 2, 512)
        pygame.mixer.init()
        _SOUNDS = {
            'click':       _sine(440, 40, vol=0.28, fade_ms=20),
            'purchase':    _two_tone(520, 660, 60, 80, vol=0.38),
            'achievement': _two_tone(660, 880, 80, 120, vol=0.42),
            'coin':        _two_tone(880, 1100, 60, 100, vol=0.38),
            # Crit: rising octave snap, louder + brighter than 'click' so a big
            # hit is instantly audible. Distinct from 'coin' (golden coin pickup).
            'crit':        _two_tone(660, 1320, 45, 120, vol=0.52),
            # Buff/Hustle activation: a perfect-fifth swell, lower & rounder than
            # crit/coin so it reads as "a state turned on", not a hit.
            'buff':        _two_tone(523, 784, 90, 150, vol=0.46),

            # --- Phase 99 milestone hierarchy ---
            # Tier 2 — milestones. Each is a short rising arpeggio so it lands
            # as an "event", not a 'purchase' blip. Ordered so they're rankable
            # by ear: manager < territory < rival (more notes / higher peak /
            # louder = bigger). All sit clearly above 'purchase' and below
            # 'prestige'.
            #
            # Manager hire / first operation: "system online" power-up that
            # resolves upward — automation, not another building bought.
            'manager':     _arpeggio([(392, 70), (523, 70), (659, 130)], vol=0.42),
            # Territory capture: a clean C-major triad fanfare — victorious.
            'territory':   _arpeggio([(523, 70), (659, 70), (784, 150)], vol=0.46),
            # Rival defeat: same climb pushed up to C6 with a 4th note and more
            # volume — unmistakably stronger than a territory win.
            'rival':       _arpeggio([(523, 70), (659, 70), (784, 70), (1047, 190)], vol=0.52),
            # Rank promotion: a bright high-register flourish (E5-G5-B5-E6),
            # celebratory and distinct in timbre from the rival war-horn.
            'rankup':      _arpeggio([(659, 60), (784, 60), (988, 60), (1319, 200)], vol=0.50),

            # Tier 3 — run-ending. The longest, fullest, loudest cue in the
            # game: a five-note ascending fanfare resolving on a sustained high
            # A5. A whole run just ended — it must never sound like a button.
            'prestige':    _arpeggio([(330, 110), (440, 110), (523, 120),
                                      (659, 140), (880, 320)], vol=0.55),
            'error':       _noise(60, vol=0.18),
        }
        set_volume(_VOL_SFX)
        return True
    except Exception:
        return False


def play(name: str) -> None:
    snd = _SOUNDS.get(name)
    if snd:
        snd.play()


def set_volume(vol: float) -> None:
    global _VOL_SFX
    _VOL_SFX = max(0.0, min(1.0, vol))
    for snd in _SOUNDS.values():
        snd.set_volume(_VOL_SFX)


def get_volume() -> float:
    return _VOL_SFX


def is_available() -> bool:
    return bool(_SOUNDS)
