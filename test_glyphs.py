"""Phase 64 glyph coverage test — run headless to audit symbol rendering."""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import pygame
pygame.font.init()  # font module only — no display needed for metrics()

import src.theme as theme
fonts = theme.make_fonts(720)

SYMBOLS = [
    # Faction symbols (rivals.py)
    ("♦",  "U+2666 BLACK DIAMOND SUIT",         "Crimson Kings"),
    ("❖",  "U+2756 BLACK DIAMOND MINUS WHITE X", "Silver Hand"),
    ("⚙",  "U+2699 GEAR",                        "Iron Union"),
    ("◎",  "U+25CE BULLSEYE",                    "Network"),
    ("⚓",  "U+2693 ANCHOR",                      "Blackwater"),
    # Other UI symbols
    ("▶",  "U+25B6 BLACK RIGHT-POINTING TRIANGLE","Dragon HUD / hint arrow"),
    ("►",  "U+25BA BLACK RIGHT-POINTING POINTER", "Alt arrow (Consolas)"),
    ("★",  "U+2605 BLACK STAR",                   "Achievements / managers"),
    ("✦",  "U+2726 BLACK FOUR POINTED STAR",      "Prestige button"),
    ("✓",  "U+2713 CHECK MARK",                   "Territory / objectives"),
    ("○",  "U+25CB WHITE CIRCLE",                 "Locked item"),
    ("◆",  "U+25C6 BLACK DIAMOND",               "Default rival symbol"),
    ("▲",  "U+25B2 BLACK UP-POINTING TRIANGLE",   "Income arrow / territory scroll"),
    ("▼",  "U+25BC BLACK DOWN-POINTING TRIANGLE", "Territory scroll down"),
    ("→",  "U+2192 RIGHTWARDS ARROW",             "Various labels"),
    # Candidate replacements
    ("*",  "U+002A ASTERISK",                     "ASCII fallback"),
    ("#",  "U+0023 NUMBER SIGN",                  "ASCII fallback"),
    ("@",  "U+0040 COMMERCIAL AT",               "ASCII fallback @ for ◎"),
    ("+",  "U+002B PLUS SIGN",                    "ASCII fallback"),
    ("x",  "U+0078 LATIN SMALL LETTER X",         "ASCII fallback"),
    ("^",  "U+005E CIRCUMFLEX ACCENT",            "ASCII fallback"),
    ("~",  "U+007E TILDE",                        "ASCII fallback"),
    ("◇",  "U+25C7 WHITE DIAMOND",               "Candidate for ❖"),
    ("◈",  "U+25C8 WHITE DIAMOND CONTAINING BLACK SMALL DIAMOND", "Candidate for ❖"),
    ("⊕",  "U+2295 CIRCLED PLUS",               "Candidate for ◎"),
    ("⊙",  "U+2299 CIRCLED DOT OPERATOR",       "Candidate for ◎"),
    ("⊗",  "U+2297 CIRCLED TIMES",              "Candidate for ◎"),
    ("⊘",  "U+2298 CIRCLED DIVISION SLASH",     "Candidate"),
    ("⊚",  "U+229A CIRCLED RING OPERATOR",      "Candidate for ◎"),
    ("·",  "U+00B7 MIDDLE DOT",                  "ASCII-range fallback"),
    ("×",  "U+00D7 MULTIPLICATION SIGN",         "Latin-1 - always available"),
    ("°",  "U+00B0 DEGREE SIGN",                 "Latin-1 - always available"),
    ("¤",  "U+00A4 CURRENCY SIGN",              "Latin-1 - always available"),
]

f = fonts['xs']

print("=" * 70)
print(f"Font path: {pygame.font.match_font('consolas') or 'SysFont(monospace)'}")
print("=" * 70)
print(f"{'CHAR':<5} {'RENDERS':<10} {'ADV_W':<8} {'CODEPOINT':<10} {'CONTEXT'}")
print("-" * 70)

for char, codepoint, context in SYMBOLS:
    # metrics() returns list of (min_x, max_x, min_y, max_y, horizontal_advance_x)
    # If the char is not in the font, returns [(None, None, None, None, None)]
    m = f.metrics(char)
    if not m or m[0][0] is None:
        renders = "MISSING"
        adv = 0
    else:
        adv = m[0][4]  # horizontal advance width
        renders = "OK"

    flag = " <-- TOFU" if renders == "MISSING" else ""
    print(f"{char!s:<5} {renders:<10} {adv:<8} {codepoint:<10} {context}{flag}")

print("=" * 70)

# Also print the actual font being used
path = pygame.font.match_font("consolas")
print(f"\nConsolas path: {path}")
path2 = pygame.font.match_font("couriernew")
print(f"Courier New path: {path2}")
path3 = pygame.font.match_font("courier")
print(f"Courier path: {path3}")

# Check candidate replacement fonts
for fname in ["segoeui", "segoeuisymbol", "segoe ui symbol", "arialunicode", "arial unicode ms",
              "noto sans", "dejavusans", "freesans"]:
    p = pygame.font.match_font(fname)
    print(f"  {fname}: {p or 'NOT FOUND'}")

