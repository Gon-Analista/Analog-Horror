"""What the player who is the Visita sees and hears of itself: the icons
of what it can do (game/assets/textures/pilot_icons.png, one 32x32 cell
each, in the order of PilotHud.ICONS: grab, speak, ceiling, sense, look)
drawn like the inventory's (big, reduced, a dark outline), in bone and
dried blood; and its own sounds into game/assets/audio: its heart (a low
double beat), feeling for them (a breath drawn in backwards, a choir of
whispers) and the thump of hitting the floor from the ceiling.

    python tools/gen_pilot.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import gen_audio as A

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures" / "pilot_icons.png"
S = 32
B = S * 4
ORDER = ["grab", "speak", "ceiling", "sense", "look"]
BONE = (226, 208, 186, 255)
BLOOD = (150, 22, 18, 255)
DARK = (40, 6, 6, 255)


def icon(name: str) -> Image.Image:
    im = Image.new("RGBA", (B, B), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if name == "grab":  # a long-fingered hand reaching down, hooked claws; scratches
        d.rounded_rectangle((26, 8, 92, 44), 14, fill=BONE)
        for i, x in enumerate((32, 50, 68, 86)):
            bottom = 92 - abs(i - 1.5) * 8
            d.line([(x, 36), (x + 4, bottom - 20), (x + 12, bottom)], fill=BONE, width=9, joint="curve")
            d.polygon([(x + 8, bottom - 4), (x + 18, bottom - 2), (x + 20, bottom + 14)], fill=BONE)
        d.line([(92, 30), (112, 58)], fill=BONE, width=9)
        for k in range(3):
            d.line([(30 + k * 22, 112), (52 + k * 22, 100)], fill=BLOOD, width=5)
    elif name == "speak":  # a mouth open too wide, teeth, dark inside
        d.ellipse((14, 30, 114, 100), fill=BONE)
        d.ellipse((24, 40, 104, 92), fill=DARK)
        for x in range(30, 100, 12):
            d.polygon([(x, 44), (x + 10, 44), (x + 5, 58)], fill=BONE)
            d.polygon([(x + 4, 88), (x + 14, 88), (x + 9, 76)], fill=BONE)
        d.ellipse((50, 62, 78, 82), fill=BLOOD)
    elif name == "ceiling":  # flat against the ceiling, limbs gripping it; an arrow up
        d.rectangle((6, 6, 122, 18), fill=BONE)
        d.ellipse((90, 26, 112, 46), fill=BONE)
        d.rounded_rectangle((26, 30, 92, 42), 6, fill=BONE)
        for x, k in ((30, -1), (46, 1), (70, -1), (86, 1)):
            d.line([(x, 34), (x + k * 10, 52), (x + k * 16, 18)], fill=BONE, width=6, joint="curve")
        d.polygon([(64, 64), (40, 92), (56, 92), (56, 120), (72, 120), (72, 92), (88, 92)], fill=BLOOD)
    elif name == "sense":  # a wide eye, veined, the pupil a slit; rings
        for r, a in ((60, 70), (50, 110)):
            d.ellipse((64 - r, 64 - r, 64 + r, 64 + r), outline=(150, 22, 18, a), width=4)
        d.ellipse((14, 40, 114, 88), fill=BONE)
        for k in range(6):
            x0 = 20 + k * 3 if k < 3 else 108 - (k - 3) * 3
            d.line([(x0, 64 + (k % 3 - 1) * 8), (40 if k < 3 else 88, 64 + (k % 3 - 1) * 4)], fill=BLOOD, width=2)
        d.ellipse((44, 42, 84, 86), fill=BLOOD)
        d.ellipse((58, 44, 70, 84), fill=DARK)
    elif name == "look":  # a crack of a door, an eye in it
        d.rectangle((16, 10, 70, 118), fill=(92, 60, 44, 255))
        d.rectangle((70, 10, 112, 118), fill=DARK)
        d.line([(70, 10), (70, 118)], fill=BONE, width=4)
        d.ellipse((74, 50, 106, 70), fill=BONE)
        d.ellipse((84, 52, 96, 68), fill=BLOOD)
        d.ellipse((88, 56, 92, 64), fill=DARK)
    small = im.resize((S, S), Image.BOX)
    a = small.split()[3].point(lambda v: 255 if v > 40 else 0)
    ring = a.filter(ImageFilter.MaxFilter(3))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste((6, 2, 2, 230), (0, 0), ring)
    out.alpha_composite(small)
    return out


def sounds() -> None:
    # Its heart: lub-dub, low and soft, felt more than heard.
    t = A.t_axis(0.7)
    beat = np.zeros_like(t)
    for at, amp, f in ((0.0, 1.0, 52.0), (0.2, 0.7, 46.0)):
        tt = np.clip(t - at, 0, None)
        env = (t >= at) * np.exp(-tt * 18.0) * (1 - np.exp(-tt * 300.0))
        beat += np.sin(2 * np.pi * f * tt) * env * amp
    beat += A.lowpass(A.noise(0.7), 0.02) * np.exp(-t * 9.0) * 0.3
    A.write("pilot_heart", A.fade(A.normalize(beat, 0.7), 4))
    # Feeling for them: a long breath drawn in, backwards, under a choir of
    # whispers that swells and is cut off.
    sec = 1.6
    t = A.t_axis(sec)
    swell = (t / sec) ** 2.2
    air = A.lowpass(A.noise(sec), 0.09) * swell
    whisper = np.zeros_like(t)
    rng = np.random.default_rng(77)
    for k in range(6):
        f = rng.uniform(1800, 3800)
        whisper += np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * A.lowpass(A.noise(sec), 0.3) * 0.25
    whisper = (whisper - A.lowpass(whisper, 0.2)) * swell
    low = np.sin(2 * np.pi * (40 + 30 * t / sec) * t) * swell * 0.5
    cut = np.where(t > sec - 0.06, np.clip((sec - t) / 0.06, 0, 1), 1.0)
    A.write("pilot_sense", A.normalize((air * 0.8 + whisper + low) * cut, 0.6))
    # Landing from the ceiling (its own ears): a heavy, close thud.
    t = A.t_axis(0.4)
    thud = np.sin(2 * np.pi * 60 * t) * np.exp(-t * 14) + A.lowpass(A.noise(0.4), 0.1) * np.exp(-t * 25) * 0.8
    A.write("pilot_land", A.fade(A.normalize(thud, 0.7), 4))


def main() -> None:
    sheet = Image.new("RGBA", (S * len(ORDER), S), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        sheet.paste(icon(name), (i * S, 0))
    sheet.save(OUT)
    print("pilot_icons.png:", ", ".join(ORDER))
    sounds()


if __name__ == "__main__":
    main()
