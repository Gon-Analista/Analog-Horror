"""The TV set of the main menu (game/assets/branding/menu_tv.png): a 1980s
wooden CRT with a rounded screen (left transparent: the show plays behind
it), a glass gloss over it, a control strip with a speaker grille, two
knobs, a channel window and a power light, rabbit-ear antennas and feet.
Drawn at 4x the menu's 480x270 layout, for sharp edges on any screen.

    python tools/gen_menu_tv.py

Layout (menu units): the image covers ORIGIN + SIZE; the screen opening is
menu.gd's TV_RECT (236, 38, 224, 168), corner radius 10.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import zoom

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "branding" / "menu_tv.png"
FONT = Path(__file__).resolve().parent.parent / "game" / "assets" / "fonts" / "VT323-Regular.ttf"
X = 4
ORIGIN = (214, 0)
SIZE = (266, 262)
SCREEN = (236, 38, 224, 168)
rng = np.random.default_rng(1983)


def P(x, y):
    """Menu units -> image pixels."""
    return ((x - ORIGIN[0]) * X, (y - ORIGIN[1]) * X)


def R(x0, y0, x1, y1):
    a, b = P(x0, y0), P(x1, y1)
    return (a[0], a[1], b[0], b[1])


def wood(w, h):
    """Walnut veneer: long wavy grain, darker streaks, a little sheen."""
    y, x = np.mgrid[0:h, 0:w].astype(float)
    warp = zoom(rng.random((6, 10)), (h / 6, w / 10), order=3)[:h, :w]
    grain = np.sin(y / 3.2 + warp * 14 + np.sin(x / 90) * 2)
    fine = np.sin(y / 1.1 + warp * 30)
    v = 0.55 + 0.12 * grain + 0.05 * fine + 0.12 * (zoom(rng.random((3, 5)), (h / 3, w / 5), order=3)[:h, :w] - 0.5)
    base = np.array([0.36, 0.2, 0.1])
    img = np.clip(base[None, None] * v[..., None] * 1.5, 0, 1)
    return Image.fromarray((img * 255).astype(np.uint8)).convert("RGBA")


def main() -> None:
    W, H = SIZE[0] * X, SIZE[1] * X
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sx, sy, sw, sh = SCREEN
    # Antennas: two chrome rods in a V from a little base on top.
    base = (sx + sw * 0.62, sy - 21)
    for tip in ((sx + sw * 0.42, 1.5), (sx + sw * 0.86, 3)):
        d.line([P(*base), P(*tip)], fill=(150, 150, 156, 255), width=int(1.6 * X))
        d.line([P(base[0], base[1] - 0.5), P(tip[0], tip[1] - 0.5)], fill=(220, 220, 226, 255), width=int(0.5 * X))
        d.ellipse(R(tip[0] - 1.6, tip[1] - 1.6, tip[0] + 1.6, tip[1] + 1.6), fill=(190, 190, 196, 255))
    d.rounded_rectangle(R(base[0] - 12, base[1] - 3, base[0] + 12, base[1] + 6), radius=3 * X, fill=(28, 26, 26, 255))
    # Feet.
    for fx in (sx + 6, sx + sw - 18):
        d.rounded_rectangle(R(fx, 248, fx + 14, 258), radius=2 * X, fill=(18, 14, 12, 255))
    # The cabinet: walnut, rounded, with a bevel of light and shade.
    cab = (sx - 18, sy - 18, sx + sw + 14, 250)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle(R(*cab), radius=10 * X, fill=255)
    im.paste(wood(W, H), (0, 0), mask)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(R(*cab), radius=10 * X, outline=(40, 22, 12, 255), width=int(1.2 * X))
    d.rounded_rectangle(R(cab[0] + 1.5, cab[1] + 1.5, cab[2] - 1.5, cab[3] - 1.5), radius=9 * X, outline=(150, 96, 56, 110), width=int(0.6 * X))
    # The bezel: dark plastic around the screen, stepped, with a lip.
    bez = (sx - 9, sy - 9, sx + sw + 9, sy + sh + 9)
    d.rounded_rectangle(R(*bez), radius=16 * X, fill=(24, 23, 24, 255))
    d.rounded_rectangle(R(bez[0] + 3, bez[1] + 3, bez[2] - 3, bez[3] - 3), radius=13 * X, fill=(12, 12, 13, 255))
    d.rounded_rectangle(R(*bez), radius=16 * X, outline=(70, 68, 66, 255), width=int(0.6 * X))
    # The control strip below.
    strip = (sx - 9, sy + sh + 13, sx + sw + 9, 244)
    d.rounded_rectangle(R(*strip), radius=4 * X, fill=(30, 28, 27, 255))
    d.line([P(strip[0] + 3, strip[1] + 0.8), P(strip[2] - 3, strip[1] + 0.8)], fill=(80, 76, 72, 255), width=int(0.5 * X))
    # Speaker grille: slots on the left.
    for i in range(14):
        gx = strip[0] + 8 + i * 4
        d.rounded_rectangle(R(gx, strip[1] + 7, gx + 2, strip[3] - 7), radius=X, fill=(8, 8, 8, 255))
    # Brand plate.
    font = ImageFont.truetype(str(FONT), 8 * X)
    d.text(P(strip[0] + 70, strip[1] + 7), "VISTAVOX", font=font, fill=(190, 170, 120, 255))
    small = ImageFont.truetype(str(FONT), 5 * X)
    d.text(P(strip[0] + 71, strip[1] + 16), "COLOR · 20\"", font=small, fill=(120, 112, 96, 255))
    # Channel window with a red 09.
    cw = (strip[2] - 92, strip[1] + 7, strip[2] - 72, strip[3] - 7)
    d.rounded_rectangle(R(*cw), radius=X, fill=(10, 4, 4, 255), outline=(70, 66, 62, 255), width=X // 2)
    d.text(P(cw[0] + 3.5, cw[1] + 1.5), "09", font=font, fill=(255, 60, 40, 255))
    # Knobs: chrome rims, dark centres, a pointer line.
    for k, kx in enumerate((strip[2] - 56, strip[2] - 32)):
        cy = (strip[1] + strip[3]) / 2
        r = 8.5
        d.ellipse(R(kx - r - 1, cy - r - 1, kx + r + 1, cy + r + 1), fill=(10, 10, 10, 255))
        for j in range(8, 0, -1):  # a soft metallic gradient
            t = j / 8
            c = int(70 + 120 * (1 - t) ** 1.5)
            d.ellipse(R(kx - r * t, cy - r * t - (1 - t) * 1.5, kx + r * t, cy + r * t - (1 - t) * 1.5), fill=(c, c, c + 4, 255))
        d.ellipse(R(kx - 4.5, cy - 4.5, kx + 4.5, cy + 4.5), fill=(28, 28, 30, 255))
        ang = [-0.8, 2.2][k]
        d.line([P(kx, cy), P(kx + np.cos(ang) * 4, cy + np.sin(ang) * 4)], fill=(230, 230, 230, 255), width=X)
    # Power light.
    pl = (strip[2] - 14, (strip[1] + strip[3]) / 2)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(R(pl[0] - 5, pl[1] - 5, pl[0] + 5, pl[1] + 5), fill=(255, 40, 30, 120))
    im = Image.alpha_composite(im, glow.filter(ImageFilter.GaussianBlur(2 * X)))
    d = ImageDraw.Draw(im)
    d.ellipse(R(pl[0] - 1.6, pl[1] - 1.6, pl[0] + 1.6, pl[1] + 1.6), fill=(255, 90, 70, 255))
    # The screen: cut out (rounded), a dark rim of shadow inside it, and the
    # glass gloss over the top left.
    hole = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hole).rounded_rectangle(R(sx, sy, sx + sw, sy + sh), radius=10 * X, fill=255)
    alpha = np.array(im.split()[3])
    alpha[np.array(hole) > 0] = 0
    im.putalpha(Image.fromarray(alpha))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(10):
        a = int(110 * (1 - i / 10) ** 2)
        sd.rounded_rectangle(R(sx + i * 0.8, sy + i * 0.8, sx + sw - i * 0.8, sy + sh - i * 0.8), radius=int((10 - i * 0.5) * X), outline=(0, 0, 0, a), width=int(0.8 * X))
    gloss = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.ellipse(R(sx - sw * 0.25, sy - sh * 0.55, sx + sw * 0.75, sy + sh * 0.45), fill=(255, 255, 255, 22))
    gloss = gloss.filter(ImageFilter.GaussianBlur(6 * X))
    clip = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    clip.paste(Image.alpha_composite(shade, gloss), (0, 0), hole)
    im = Image.alpha_composite(im, clip)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT)
    print("menu_tv.png", im.size)


if __name__ == "__main__":
    main()
