"""Inventory icons (game/assets/textures/items.png): one 32x32 cell per
item, in the order of Inventory.ICONS. Drawn big and reduced, then given a
dark outline so they read on any background. Also the item sounds (grab,
battery in, tape away) into game/assets/audio.

    python tools/gen_items.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_audio as A

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures" / "items.png"
S = 32          # icon size
B = S * 4       # drawn at 4x
ORDER = ["hand", "flashlight", "camcorder", "battery", "tape"]


def icon(name: str) -> Image.Image:
    im = Image.new("RGBA", (B, B), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if name == "hand":  # an open glove, faint: "empty"
        c = (150, 140, 128, 150)
        d.rounded_rectangle((40, 58, 92, 110), 14, fill=c)
        for i, x in enumerate((42, 55, 68, 81)):
            d.rounded_rectangle((x, 22 + abs(i - 1.5) * 6, x + 10, 70), 5, fill=c)
        d.rounded_rectangle((18, 62, 50, 76), 6, fill=c)
    elif name == "flashlight":  # diagonal, lamp at the top right, a beam
        d.polygon([(84, 30), (124, 6), (124, 54)], fill=(255, 230, 150, 34))
        poly = [(22, 104), (34, 116), (82, 68), (70, 56)]
        d.polygon(poly, fill=(28, 28, 32, 255))
        for k in range(3):
            a = 40 + k * 10
            d.line([(a - 8, 100 - k * 10 + 8), (a + 4, 112 - k * 10 + 8)], fill=(60, 60, 66, 255), width=4)
        d.polygon([(66, 52), (86, 72), (100, 50), (88, 38)], fill=(36, 36, 40, 255))
        d.polygon([(86, 36), (102, 52), (108, 46), (92, 30)], fill=(190, 190, 196, 255))
        d.polygon([(90, 34), (104, 48), (106, 44), (94, 32)], fill=(255, 236, 170, 255))
    elif name == "camcorder":  # side view: body, lens, viewfinder, red light
        d.rounded_rectangle((20, 46, 96, 96), 8, fill=(46, 46, 50, 255))
        d.rectangle((96, 54, 118, 88), fill=(22, 22, 24, 255))
        d.ellipse((108, 58, 124, 84), fill=(70, 90, 120, 255))
        d.rectangle((34, 30, 80, 44), fill=(30, 30, 33, 255))
        d.rectangle((10, 40, 32, 54), fill=(26, 26, 28, 255))
        d.rectangle((30, 56, 62, 62), fill=(150, 150, 150, 255))
        d.rectangle((66, 56, 76, 62), fill=(200, 40, 30, 255))
        d.ellipse((82, 52, 90, 60), fill=(255, 40, 30, 255))
        d.line([(28, 92), (88, 92)], fill=(70, 70, 76, 255), width=3)
    elif name == "battery":  # camcorder pack: grey slab, orange band, contacts
        d.rounded_rectangle((26, 30, 102, 104), 8, fill=(54, 58, 66, 255))
        for y in range(42, 92, 10):
            d.line([(34, y), (94, y)], fill=(70, 74, 84, 255), width=3)
        d.rectangle((26, 58, 102, 76), fill=(220, 130, 40, 255))
        d.rectangle((40, 22, 52, 32), fill=(210, 180, 90, 255))
        d.rectangle((76, 22, 88, 32), fill=(210, 180, 90, 255))
        d.ellipse((86, 86, 96, 96), fill=(90, 240, 120, 255))
    elif name == "tape":  # a VHS cassette from the front: window, two reels, label
        d.rounded_rectangle((8, 30, 120, 100), 6, fill=(24, 24, 26, 255))
        d.rectangle((20, 38, 108, 58), fill=(225, 218, 196, 255))
        for x in (26, 40, 54):
            d.line([(x, 46), (x + 24, 46)], fill=(170, 40, 40, 255), width=3)
        d.rounded_rectangle((30, 66, 98, 92), 6, fill=(60, 60, 66, 255))
        for cx in (46, 82):
            d.ellipse((cx - 10, 69, cx + 10, 89), fill=(220, 220, 220, 255))
            d.ellipse((cx - 4, 75, cx + 4, 83), fill=(40, 40, 44, 255))
    small = im.resize((S, S), Image.BOX)
    # A dark outline: the alpha grown by a pixel, under the icon.
    a = small.split()[3].point(lambda v: 255 if v > 40 else 0)
    ring = a.filter(ImageFilter.MaxFilter(3))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste((8, 6, 6, 220), (0, 0), ring)
    out.alpha_composite(small)
    return out


def sounds() -> None:
    """The hand going down for something and back (cloth, a light knock);
    a battery sliding into the camcorder (plastic, a hard click, a short
    double beep); a tape going into a pocket (plastic, cloth)."""
    t = A.t_axis(0.22)
    swish = A.lowpass(A.noise(0.22), 0.12) * np.sin(np.pi * np.clip(t / 0.22, 0, 1)) ** 2
    knock = np.zeros_like(t)
    i = int(0.11 * A.SR)
    n = A.noise(0.01)
    knock[i:i + len(n)] = (n - A.lowpass(n, 0.25)) * 0.8
    A.write("grab", A.fade(A.normalize(swish * 0.6 + knock, 0.45), 3))

    t = A.t_axis(0.62)
    slide = A.lowpass(A.noise(0.62), 0.3) * np.clip(1 - np.abs(t - 0.14) / 0.12, 0, 1) * 0.5
    click = np.zeros_like(t)
    for at, amp in ((0.27, 1.0), (0.3, 0.6)):
        n = A.noise(0.012)
        j = int(at * A.SR)
        click[j:j + len(n)] += (n - A.lowpass(n, 0.35)) * amp * np.exp(-np.arange(len(n)) / A.SR * 300)
    beep = np.zeros_like(t)
    for at in (0.42, 0.52):
        j = int(at * A.SR)
        bt = A.t_axis(0.06)
        beep[j:j + len(bt)] += np.sin(2 * np.pi * 2600 * bt) * 0.18 * A.fade(np.ones_like(bt), 6)
    A.write("battery_insert", A.fade(A.normalize(slide + click + beep, 0.6), 2))

    t = A.t_axis(0.3)
    rustle = A.lowpass(A.noise(0.3), 0.18) * np.exp(-((t - 0.15) / 0.07) ** 2)
    tap = np.zeros_like(t)
    n = A.noise(0.008)
    j = int(0.05 * A.SR)
    tap[j:j + len(n)] = (n - A.lowpass(n, 0.3)) * 0.6
    A.write("tape_pocket", A.fade(A.normalize(rustle * 0.7 + tap, 0.4), 3))

    # Doors, subtle (user 2026-10-26): a soft click of the latch and a hush
    # of air; closing, the click and a muffled knock of wood. The entity's:
    # the same click, then a long, quiet, low groan of the hinge.
    def soft_click(n_total, at, tone=2400.0, amp=1.0):
        x = np.zeros(n_total)
        j = int(at * A.SR)
        tt = np.arange(int(0.025 * A.SR)) / A.SR
        burst = (np.sin(2 * np.pi * tone * tt) * 0.6 + A.noise(0.025)[:len(tt)] * 0.4) * np.exp(-tt * 260) * amp
        x[j:j + len(burst)] += burst[:len(x[j:j + len(burst)])]
        return A.lowpass(x, 0.45)

    def hush(seconds, peak_at):
        t = A.t_axis(seconds)
        return A.lowpass(A.lowpass(A.noise(seconds), 0.06), 0.06) * np.exp(-((t - peak_at) / (seconds * 0.3)) ** 2)

    t = A.t_axis(0.5)
    op = soft_click(len(t), 0.0) + hush(0.5, 0.22) * 0.5
    A.write("door_open", A.fade(A.normalize(op, 0.28), 6))
    t = A.t_axis(0.5)
    knock = np.zeros_like(t)
    j = int(0.2 * A.SR)
    kt = A.t_axis(0.12)
    knock[j:j + len(kt)] = A.lowpass(A.noise(0.12), 0.05) * np.exp(-kt * 45) * 2.2 + np.sin(2 * np.pi * 85 * kt) * np.exp(-kt * 40) * 0.6
    cl = hush(0.5, 0.12) * 0.4 + knock + soft_click(len(t), 0.21, 2000.0, 0.8)
    A.write("door_close", A.fade(A.normalize(cl, 0.3), 6))
    t = A.t_axis(1.5)
    f = 140 + 40 * (t / 1.5) + 8 * np.sin(2 * np.pi * 1.7 * t)
    groan = np.sin(np.cumsum(f / A.SR) * 2 * np.pi) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t) ** 2)
    groan = A.lowpass(groan, 0.08) * np.sin(np.pi * t / 1.5) ** 1.5
    cr = soft_click(len(t), 0.0) + groan * 0.5
    A.write("door_creak", A.fade(A.normalize(cr, 0.32), 15))
    # A friend's flash in your eyes: a high ringing that fades.
    t = A.t_axis(2.2)
    ring = np.sin(2 * np.pi * 6200 * t) * np.exp(-t * 1.6) * (0.8 + 0.2 * np.sin(2 * np.pi * 5 * t))
    A.write("tinnitus", A.fade(A.normalize(ring, 0.3), 20))


def main() -> None:
    sheet = Image.new("RGBA", (S * len(ORDER), S), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        sheet.paste(icon(name), (i * S, 0))
    sheet.save(OUT)
    print("items.png:", ", ".join(ORDER))
    sounds()


if __name__ == "__main__":
    main()
