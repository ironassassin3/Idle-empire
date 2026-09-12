"""Generate Criminal Empire's deterministic, code-drawn Play feature graphic.

Asset source: pygame primitives plus repository fonts. No generative AI or external art.
Run from the repository root with: python tools/generate_feature_graphic.py
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import pygame


WIDTH, HEIGHT = 1024, 500
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "store" / "feature_graphic_1024x500.png"
DISPLAY_FONT = ROOT / "godot" / "assets" / "fonts" / "Limelight-Regular.ttf"
LABEL_FONT = ROOT / "godot" / "assets" / "fonts" / "SpaceMono-Bold.ttf"

INK = pygame.Color("#06070c")
VIOLET = pygame.Color("#8a5cff")
VIOLET_BRIGHT = pygame.Color("#b18cff")
TEAL = pygame.Color("#2fd6c6")
MAGENTA = pygame.Color("#e5457e")
TEXT = pygame.Color("#e8e0d4")
MUTED = pygame.Color("#8a8070")


def mix(a: pygame.Color, b: pygame.Color, amount: float) -> pygame.Color:
    return pygame.Color(*(round(a[i] + (b[i] - a[i]) * amount) for i in range(3)))


def glow_circle(canvas: pygame.Surface, center: tuple[int, int], radius: int, color: pygame.Color) -> None:
    layer = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
    for r in range(radius, 8, -10):
        alpha = round(2 + 18 * (1 - r / radius) ** 2)
        pygame.draw.circle(layer, (*color[:3], alpha), center, r)
    canvas.blit(layer, (0, 0))


def draw_crown(canvas: pygame.Surface, x: int, y: int) -> None:
    shadow = [(x + 3, y + 35), (x + 10, y + 8), (x + 29, y + 27),
              (x + 47, y), (x + 64, y + 27), (x + 84, y + 8), (x + 91, y + 35)]
    points = [(px, py + 4) for px, py in shadow]
    pygame.draw.polygon(canvas, pygame.Color("#25183d"), points)
    points = [(x, y + 35), (x + 7, y + 8), (x + 27, y + 27),
              (x + 45, y), (x + 62, y + 27), (x + 82, y + 8), (x + 89, y + 35)]
    pygame.draw.polygon(canvas, VIOLET, points)
    pygame.draw.line(canvas, VIOLET_BRIGHT, (x, y + 35), (x + 89, y + 35), 4)
    for px, py, color in ((x + 7, y + 8, TEAL), (x + 45, y, VIOLET_BRIGHT), (x + 82, y + 8, MAGENTA)):
        pygame.draw.circle(canvas, color, (px, py), 4)


def draw_city(canvas: pygame.Surface) -> None:
    rng = random.Random(0xC1A0)
    horizon = 388
    buildings: list[tuple[int, int, int, int]] = []
    x = 470
    while x < WIDTH + 20:
        width = rng.randint(38, 76)
        height = rng.randint(90, 238)
        buildings.append((x, horizon - height, width, height))
        x += width + rng.randint(5, 12)

    # Distant silhouettes build depth without competing with the title.
    for bx, by, bw, bh in buildings:
        pygame.draw.rect(canvas, pygame.Color("#0d1020"), (bx - 24, by + 40, bw, bh))

    for index, (bx, by, bw, bh) in enumerate(buildings):
        body = mix(pygame.Color("#101421"), pygame.Color("#201833"), (index % 4) / 5)
        pygame.draw.rect(canvas, body, (bx, by, bw, bh))
        pygame.draw.line(canvas, pygame.Color("#352254"), (bx, by), (bx, horizon), 2)
        pygame.draw.line(canvas, pygame.Color("#171d2b"), (bx + bw, by + 8), (bx + bw, horizon), 2)

        if index in (2, 5):
            pygame.draw.line(canvas, VIOLET, (bx + bw // 2, by), (bx + bw // 2, by - 28), 2)
            pygame.draw.circle(canvas, VIOLET_BRIGHT, (bx + bw // 2, by - 30), 3)

        for wy in range(by + 18, horizon - 10, 20):
            for wx in range(bx + 10, bx + bw - 8, 17):
                if rng.random() < 0.46:
                    color = TEAL if rng.random() < 0.22 else VIOLET_BRIGHT
                    pygame.draw.rect(canvas, color, (wx, wy, 5, 8), border_radius=1)

    # Street plane and neon perspective lines.
    pygame.draw.polygon(canvas, pygame.Color("#090b13"), [(0, horizon), (WIDTH, horizon), (WIDTH, HEIGHT), (0, HEIGHT)])
    pygame.draw.line(canvas, pygame.Color("#39265c"), (0, horizon), (WIDTH, horizon), 2)
    for end_x in range(360, 1200, 120):
        pygame.draw.line(canvas, pygame.Color("#171629"), (700, horizon), (end_x, HEIGHT), 1)
    for y in (414, 445, 478):
        pygame.draw.line(canvas, pygame.Color("#141326"), (0, y), (WIDTH, y), 1)

    # Hero tower and a restrained sign provide a visual anchor.
    tower = pygame.Rect(748, 128, 112, horizon - 128)
    pygame.draw.rect(canvas, pygame.Color("#171329"), tower)
    pygame.draw.line(canvas, VIOLET, tower.topleft, (tower.left, tower.bottom), 3)
    pygame.draw.line(canvas, pygame.Color("#4d3373"), tower.topright, tower.bottomright, 2)
    pygame.draw.polygon(canvas, pygame.Color("#171329"), [(748, 128), (804, 82), (860, 128)])
    pygame.draw.line(canvas, VIOLET_BRIGHT, (804, 82), (804, 54), 2)
    pygame.draw.circle(canvas, MAGENTA, (804, 52), 4)
    for wy in range(154, 354, 27):
        for wx in range(765, 845, 22):
            pygame.draw.rect(canvas, TEAL if (wx + wy) % 3 == 0 else VIOLET_BRIGHT, (wx, wy, 7, 10), border_radius=1)


def draw_text_with_shadow(
    canvas: pygame.Surface,
    text: str,
    font: pygame.font.Font,
    position: tuple[int, int],
    color: pygame.Color,
    shadow_offset: tuple[int, int] = (5, 6),
) -> pygame.Rect:
    shadow = font.render(text, True, pygame.Color("#160f26"))
    rendered = font.render(text, True, color)
    canvas.blit(shadow, (position[0] + shadow_offset[0], position[1] + shadow_offset[1]))
    return canvas.blit(rendered, position)


def main() -> None:
    pygame.init()
    pygame.font.init()
    canvas = pygame.Surface((WIDTH, HEIGHT), depth=24)

    top = pygame.Color("#070811")
    bottom = pygame.Color("#110d1f")
    for y in range(HEIGHT):
        pygame.draw.line(canvas, mix(top, bottom, y / (HEIGHT - 1)), (0, y), (WIDTH, y))

    glow_circle(canvas, (792, 205), 280, VIOLET)
    glow_circle(canvas, (945, 335), 150, TEAL)
    draw_city(canvas)

    # Fine geometric grain: deterministic and subtle enough to survive Play compression.
    rng = random.Random(1001)
    for _ in range(420):
        x, y = rng.randrange(WIDTH), rng.randrange(HEIGHT)
        shade = rng.choice((pygame.Color("#191526"), pygame.Color("#101421"), pygame.Color("#221632")))
        canvas.set_at((x, y), shade)

    draw_crown(canvas, 108, 72)
    title_font = pygame.font.Font(str(DISPLAY_FONT), 72)
    title_large = pygame.font.Font(str(DISPLAY_FONT), 96)
    label_font = pygame.font.Font(str(LABEL_FONT), 17)
    micro_font = pygame.font.Font(str(LABEL_FONT), 12)

    draw_text_with_shadow(canvas, "CRIMINAL", title_font, (104, 135), TEXT)
    draw_text_with_shadow(canvas, "EMPIRE", title_large, (101, 205), VIOLET_BRIGHT, (7, 8))
    pygame.draw.rect(canvas, VIOLET, (106, 324, 272, 3))
    pygame.draw.rect(canvas, TEAL, (378, 324, 56, 3))
    canvas.blit(label_font.render("BUILD  •  CONTROL  •  PRESTIGE", True, TEXT), (106, 344))
    canvas.blit(micro_font.render("AN IDLE TYCOON GAME", True, MUTED), (107, 380))

    # Border is inset so crop-safe content remains comfortably inside the outer 10%.
    pygame.draw.rect(canvas, pygame.Color("#2d2047"), (16, 16, WIDTH - 32, HEIGHT - 32), 2)
    pygame.draw.line(canvas, VIOLET, (16, 16), (206, 16), 3)
    pygame.draw.line(canvas, TEAL, (818, HEIGHT - 16), (WIDTH - 16, HEIGHT - 16), 3)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pygame.image.save(canvas, OUTPUT)
    print(f"Wrote {OUTPUT} ({WIDTH}x{HEIGHT}, code-drawn)")
    pygame.quit()


if __name__ == "__main__":
    main()
