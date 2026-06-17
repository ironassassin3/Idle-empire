"""Find which chars ARE in Consolas by comparing renders to a known-tofu baseline.
All missing chars render as the same box — if a char == the tofu pattern, it's missing."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
import numpy as np

pygame.init()
screen = pygame.display.set_mode((1, 1))

import src.theme as theme
fonts = theme.make_fonts(720)
f = fonts['sm']

def render_arr(ch):
    surf = f.render(ch, True, (255, 255, 255))
    return pygame.surfarray.array3d(surf)

# We KNOW ❖ (U+2756) is a tofu box on Consolas
TOFU_ARR = render_arr("❖")
TOFU_SUM = int(TOFU_ARR.sum())

# Verify our known-good reference ('A') is NOT equal to the tofu
A_ARR = render_arr("A")
A_DIFF = int(np.abs(A_ARR.astype(int) - TOFU_ARR.astype(int)).sum())
print(f"'A' vs TOFU diff: {A_DIFF}  (should be > 0)")

# Verify another known-tofu (⚙) matches TOFU_ARR
gear_arr = render_arr("⚙")
gear_diff = int(np.abs(gear_arr.astype(int) - TOFU_ARR.astype(int)).sum())
print(f"'⚙' vs TOFU diff: {gear_diff}  (should be ~0)")

# Verify known-good geometric shapes
for ch, name in [("♦","diamond"), ("○","circle"), ("▲","triangle"), ("→","arrow")]:
    arr = render_arr(ch)
    diff = int(np.abs(arr.astype(int) - TOFU_ARR.astype(int)).sum())
    print(f"'{ch}' ({name}) vs TOFU diff: {diff}  (should be > 0 if in font)")

print()

def is_in_font(ch):
    """True if ch renders differently from the tofu box."""
    arr = render_arr(ch)
    diff = int(np.abs(arr.astype(int) - TOFU_ARR.astype(int)).sum())
    return diff > 50  # any noticeable difference = real glyph

ranges = [
    ("Geometric Shapes",   0x25A0, 0x25FF),
    ("Misc Symbols",       0x2600, 0x26FF),
    ("Dingbats",           0x2700, 0x27BF),
    ("Math Operators",     0x2200, 0x22FF),
    ("Arrows",             0x2190, 0x21FF),
    ("Latin-1 Supplement", 0x00A0, 0x00FF),
    ("General Punct",      0x2000, 0x206F),
    ("Box Drawing",        0x2500, 0x257F),
    ("Block Elements",     0x2580, 0x259F),
]

results = {}
for block_name, start, end in ranges:
    in_font = []
    for cp in range(start, end + 1):
        try:
            ch = chr(cp)
            if is_in_font(ch):
                in_font.append((cp, ch))
        except Exception:
            pass
    results[block_name] = in_font

with open("consolas_coverage.txt", "w", encoding="utf-8") as fout:
    for block_name, chars in results.items():
        fout.write(f"\n{'='*60}\n{block_name}: {len(chars)} chars\n{'='*60}\n")
        for cp, ch in chars:
            fout.write(f"  U+{cp:04X} {ch}")
        fout.write("\n")

print("Saved consolas_coverage.txt")
print()
for block_name, chars in results.items():
    if chars:
        sample = "  ".join(ch for _, ch in chars[:12])
        print(f"  {block_name} ({len(chars)}): {sample}")
    else:
        print(f"  {block_name}: NONE")

pygame.quit()
