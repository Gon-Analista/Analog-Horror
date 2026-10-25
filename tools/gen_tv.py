"""Generates the TV's frames of ¡Hola, Vecinitos!: the show as it was
meant to be seen. Vecinito in his normal, friendly form (a round mustard
bear with big shiny eyes, rosy cheeks, a bow tie and white gloves) waving
on a sunny set. The contrast with what walks the house is the point.

Output: game/assets/textures/tv_show.png, a row of 320x240 frames:
0-5 the waving loop, 6-7 static for the interruption, 8-11 the show going
wrong (he stops and stares, the eyes empty, the jaw drops, his face).

    python tools/gen_tv.py [preview.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "textures" / "tv_show.png"
FONT = ROOT / "game" / "assets" / "fonts" / "VT323-Regular.ttf"
W, H = 320, 240          # output frame size
S = 3                    # drawing coordinates are in a 480x360 space...
Q = 2                    # ...rendered at 960x720 and reduced 3x (smooth edges)
BW, BH = 160 * S, 120 * S


class ScaledDraw:
    """ImageDraw in the 480x360 drawing space, on a Q-times larger canvas."""

    def __init__(self, im: Image.Image):
        self.d = ImageDraw.Draw(im)

    @staticmethod
    def _xy(xy):
        return [v * Q for v in xy] if not isinstance(xy[0], (tuple, list)) else [(x * Q, y * Q) for x, y in xy]

    def ellipse(self, xy, fill=None, outline=None, width=1):
        self.d.ellipse(self._xy(xy), fill=fill, outline=outline, width=int(width * Q))

    def rectangle(self, xy, fill=None, outline=None, width=1):
        self.d.rectangle(self._xy(xy), fill=fill, outline=outline, width=int(width * Q))

    def polygon(self, xy, fill=None, outline=None, width=1):
        self.d.polygon(self._xy(xy), fill=fill, outline=outline, width=int(width * Q))

    def line(self, xy, fill=None, width=1):
        self.d.line(self._xy(xy), fill=fill, width=int(width * Q), joint="curve")

    def arc(self, xy, start, end, fill=None, width=1):
        self.d.arc(self._xy(xy), start, end, fill=fill, width=int(width * Q))

    def text(self, xy, text, font, fill):
        self.d.text((xy[0] * Q, xy[1] * Q), text, font=font, fill=fill)

    def textlength(self, text, font):
        return self.d.textlength(text, font=font) / Q
SHOW_FRAMES = 6
rng = np.random.default_rng(87)

FUR = (226, 170, 52)
FUR_DARK = (170, 118, 30)
INK = (40, 26, 20)
GLOVE = (250, 248, 240)
CHEEK = (240, 120, 120)
BOW = (210, 40, 50)


def set_background(d: ScaledDraw) -> None:
    w, h = BW, BH
    for i in range(12):                                                    # sky, lighter at the horizon
        y0 = i * (h - 90) / 12
        c = (int(95 + i * 4), int(175 + i * 3), int(232 + i))
        d.rectangle((0, y0, w, y0 + (h - 90) / 12 + 1), fill=c)
    d.ellipse((w - 118, 12, w - 32, 98), fill=(255, 240, 150))            # sun and its glow
    d.ellipse((w - 110, 20, w - 40, 90), fill=(255, 220, 80), outline=(240, 170, 40), width=3)
    for cx, cy in ((60, 60), (200, 40), (330, 75)):                       # clouds, shaded
        for k in range(3):
            d.ellipse((cx + k * 22 - 20, cy - 10, cx + k * 22 + 22, cy + 22), fill=(205, 220, 240))
            d.ellipse((cx + k * 22 - 20, cy - 14, cx + k * 22 + 22, cy + 16), fill=(252, 252, 252))
    d.rectangle((0, h - 90, w, h), fill=(110, 185, 90))                   # grass
    d.rectangle((0, h - 90, w, h - 84), fill=(90, 160, 75))
    for hx, col in ((30, (230, 120, 100)), (370, (120, 150, 230))):       # little houses
        d.rectangle((hx, h - 160, hx + 80, h - 90), fill=col, outline=INK, width=3)
        d.polygon([(hx - 8, h - 160), (hx + 40, h - 205), (hx + 88, h - 160)], fill=(170, 60, 50), outline=INK)
        d.rectangle((hx + 30, h - 125, hx + 50, h - 90), fill=(120, 80, 50), outline=INK, width=2)
        d.rectangle((hx + 8, h - 150, hx + 24, h - 134), fill=(255, 245, 190), outline=INK, width=2)
        d.rectangle((hx + 56, h - 150, hx + 72, h - 134), fill=(255, 245, 190), outline=INK, width=2)
    for fx in range(0, w, 18):                                             # white picket fence
        d.polygon([(fx + 2, h - 62), (fx + 8, h - 70), (fx + 14, h - 62), (fx + 14, h - 40), (fx + 2, h - 40)],
                  fill=(250, 248, 240), outline=INK)
    d.rectangle((0, h - 58, w, h - 53), fill=(235, 232, 222), outline=INK, width=1)
    for k in range(14):                                                    # flowers
        fx, fy = (k * 37 + 11) % w, h - 30 + (k * 13) % 22
        col = [(240, 90, 110), (250, 220, 70), (255, 255, 255)][k % 3]
        d.ellipse((fx - 5, fy - 5, fx + 5, fy + 5), fill=col, outline=INK, width=1)
        d.ellipse((fx - 2, fy - 2, fx + 2, fy + 2), fill=(250, 200, 40))


def vecinito(d: ScaledDraw, cx: float, cy: float, wave: float, eyes: str = "shiny", mouth: str = "smile") -> None:
    """The mascot, centred at the chest. eyes: shiny | stare | hollow;
    mouth: smile | flat | open. wave None = the arm hangs (it stopped)."""
    def e(x, y, rx, ry, fill, width=4):
        d.ellipse((cx + x - rx, cy + y - ry, cx + x + rx, cy + y + ry), fill=fill, outline=INK, width=width)

    e(-40, 120, 26, 14, (150, 60, 50))                     # shoes
    e(40, 120, 26, 14, (150, 60, 50))
    e(0, 40, 62, 78, FUR)                                  # body
    e(0, 52, 38, 48, (245, 215, 150), 0)                   # belly
    # arms: one resting, one waving
    d.line((cx - 55, cy + 10, cx - 85, cy + 70), fill=INK, width=22)
    d.line((cx - 55, cy + 10, cx - 85, cy + 70), fill=FUR, width=14)
    e(-88, 74, 18, 18, GLOVE)
    a = math.radians(70 if wave is None else -70 + wave)
    hx, hy = cx + 55 + math.cos(a) * 70, cy + math.sin(a) * 70
    d.line((cx + 50, cy + 5, hx, hy), fill=INK, width=22)
    d.line((cx + 50, cy + 5, hx, hy), fill=FUR, width=14)
    d.ellipse((hx - 19, hy - 19, hx + 19, hy + 19), fill=GLOVE, outline=INK, width=4)
    # head
    e(-58, -112, 26, 26, FUR)                              # ears
    e(58, -112, 26, 26, FUR)
    e(-58, -112, 13, 13, FUR_DARK, 0)
    e(58, -112, 13, 13, FUR_DARK, 0)
    e(0, -70, 82, 70, FUR)
    e(0, -48, 40, 28, (245, 215, 150), 0)                  # muzzle
    for x in (-30, 30):
        if eyes == "shiny":                                # big shiny eyes
            e(x, -86, 16, 20, (255, 255, 255), 3)
            e(x + 3, -82, 9, 11, INK, 0)
            e(x + 6, -88, 4, 4, (255, 255, 255), 0)
        elif eyes == "stare":                              # pinprick pupils, looking at you
            e(x, -86, 16, 20, (255, 255, 255), 3)
            e(x, -86, 3, 3, INK, 0)
        else:                                              # empty
            e(x, -86, 17, 22, INK, 3)
            e(x + 1, -88, 2, 2, (230, 220, 200), 0)
    if mouth == "smile":
        e(-56, -50, 13, 9, CHEEK, 0)
        e(56, -50, 13, 9, CHEEK, 0)
    e(0, -60, 10, 7, INK, 0)                               # nose
    if mouth == "smile":
        d.arc((cx - 26, cy - 66, cx + 26, cy - 30), 20, 160, fill=INK, width=5)
    elif mouth == "flat":
        d.line((cx - 22, cy - 40, cx + 22, cy - 40), fill=INK, width=5)
    else:                                                  # the jaw drops
        d.ellipse((cx - 26, cy - 46, cx + 26, cy + 30), fill=INK)
        for k in range(5):
            tx = cx - 18 + k * 9
            d.rectangle((tx, cy - 44, tx + 5, cy - 34), fill=(230, 220, 180))
        d.line((cx - 6, cy - 30, cx - 8, cy + 40), fill=(150, 20, 20), width=4)
    # bow tie
    d.polygon([(cx, cy - 4), (cx - 28, cy - 18), (cx - 28, cy + 10)], fill=BOW, outline=INK)
    d.polygon([(cx, cy - 4), (cx + 28, cy - 18), (cx + 28, cy + 10)], fill=BOW, outline=INK)
    e(0, -4, 8, 8, BOW, 3)


def title(d: ScaledDraw, frame: int) -> None:
    font = ImageFont.truetype(str(FONT), 17 * S * Q)
    text = "¡HOLA, VECINITOS!"
    tw = d.textlength(text, font=font)
    x, y = (BW - tw) / 2, 2
    for ox, oy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
        d.text((x + ox, y + oy), text, font=font, fill=INK)
    colors = [(255, 90, 90), (255, 200, 60), (90, 200, 255), (140, 230, 120)]
    cx = x
    for i, ch in enumerate(text):
        d.text((cx, y + (3 if (i + frame) % 2 else 0)), ch, font=font, fill=colors[(i + frame) % 4])
        cx += d.textlength(ch, font=font)


def show_frame(i: int) -> Image.Image:
    im = Image.new("RGB", (BW * Q, BH * Q))
    d = ScaledDraw(im)
    set_background(d)
    bounce = [0, -6, -10, -6, 0, 3][i]
    wave = [0, 25, 45, 25, 0, -15][i]
    vecinito(d, BW / 2, BH * 0.58 + bounce, wave)
    title(d, i)
    return im.resize((W, H), Image.LANCZOS)


def disturbed_frame(eyes: str, mouth: str, tint: float, close: bool = False) -> Image.Image:
    """The show going wrong: he stops waving and the set loses its colour."""
    im = Image.new("RGB", (BW * Q, BH * Q))
    d = ScaledDraw(im)
    set_background(d)
    cx, cy = BW / 2, BH * 0.58
    vecinito(d, cx, cy, None, eyes, mouth)
    title(d, 0)
    if close:  # the face fills the screen
        box = (int((cx - 95) * Q), int((cy - 160) * Q), int((cx + 95) * Q), int((cy - 160 + 190 * H / W) * Q))
        im = im.crop(box).resize((BW * Q, BH * Q), Image.BICUBIC)
    a = np.array(im).astype(float)
    gray = a.mean(axis=-1, keepdims=True)
    a = a * (1 - tint) + gray * np.array([1.05, 0.7, 0.65]) * tint
    a *= 1 - 0.45 * tint
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)


def static_frame() -> Image.Image:
    v = rng.random((H, W)) * 255
    v[::2] *= 0.7
    return Image.fromarray(np.stack([v, v, v], axis=-1).astype(np.uint8))


def main() -> None:
    frames = [show_frame(i) for i in range(SHOW_FRAMES)] + [static_frame(), static_frame()]
    frames += [disturbed_frame("stare", "smile", 0.25), disturbed_frame("hollow", "flat", 0.55),
               disturbed_frame("hollow", "open", 0.8), disturbed_frame("hollow", "open", 0.95, close=True)]
    sheet = Image.new("RGB", (W * len(frames), H))
    for i, f in enumerate(frames):
        sheet.paste(f, (i * W, 0))
    a = np.array(sheet).astype(float)
    sheet = Image.fromarray((np.round(a / 255 * 31) / 31 * 255).astype(np.uint8))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print("tv frames ->", OUT, sheet.size)
    if len(sys.argv) > 1:
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
