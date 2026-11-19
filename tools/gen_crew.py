"""Generates the recovery crew's heads: four people from Canal 9 sent into
the evacuated street in 1989, each with a face of their own, painted like
the rest of the game (soft, worn, a little grimy) and reduced to pixels.

  0  the camera operator: orange jacket, a knit cap, stubble, tired eyes
  1  the sound technician: teal jacket, black hair in a ponytail, round
     glasses, headphones round the neck (the headphones are a mesh)
  2  the reporter: red jacket, side-parted hair, a moustache, freckles
  3  the intern: yellow jacket, a cap on backwards, short curly hair,
     big nervous eyes

Each head is a 128x64 texture for a SphereMesh (u = around the head, the
face centred at u=0.5, which faces -Z; v = top to bottom), in four
expressions: worried, terrified, blinking, talking.

Output: game/assets/textures/crew_heads.png (4 rows = people, 4 columns =
expressions, 128x64 each) and crew_patch.png (the CANAL 9 patch on the
back of every jacket).

    python tools/gen_crew.py [preview.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "game" / "assets" / "textures"
FONT = ROOT / "game" / "assets" / "fonts" / "VT323-Regular.ttf"
W, H = 128, 64
S = 4
CW, CH = W * S, H * S
EXPR = ["worried", "terrified", "blink", "talk", "blank"]

PEOPLE = [
    dict(skin=(214, 172, 140), hair=(70, 46, 30), hairline=0.34, back=0.62, brows=(52, 34, 24), brow_w=1.3,
         iris=(70, 90, 110), stubble=True, bags=True),
    dict(skin=(176, 124, 92), hair=(18, 14, 14), hairline=0.3, back=0.72, brows=(20, 14, 12), brow_w=0.9,
         iris=(60, 40, 26), glasses=True),
    dict(skin=(226, 186, 160), hair=(150, 104, 62), hairline=0.3, back=0.6, brows=(120, 80, 48), brow_w=1.0,
         iris=(84, 110, 70), moustache=True, freckles=True, part=True),
    dict(skin=(128, 88, 64), hair=(24, 18, 16), hairline=0.36, back=0.58, brows=(28, 20, 16), brow_w=1.1,
         iris=(48, 30, 20), curly=True, big_eyes=True),
]


def P(u, v):
    """Head UV (u around, 0.5 = the face; v top..bottom) to canvas pixels."""
    return (u * CW, v * CH)


def head(person, expr, rng):
    img = Image.new("RGB", (CW, CH), person["skin"])
    d = ImageDraw.Draw(img)
    sk = np.array(person["skin"], np.float32)

    # Soft shading painted in: a little darker round the back and the jaw,
    # warm on the cheeks and nose.
    arr = np.asarray(img).astype(np.float32)
    yy, xx = np.mgrid[0:CH, 0:CW].astype(np.float32)
    u = xx / CW
    v = yy / CH
    around = np.cos((u - 0.5) * math.tau)          # 1 at the face, -1 at the back
    shade = 0.82 + 0.18 * np.clip(around, 0, 1) - 0.12 * np.clip(v - 0.7, 0, 1) * 3
    arr *= shade[..., None]
    for cx in (0.43, 0.57):
        blush = np.exp(-(((u - cx) / 0.035) ** 2 + ((v - 0.58) / 0.06) ** 2))
        arr += blush[..., None] * np.array([28, 6, 4])
    grain = gaussian_filter(rng.standard_normal((CH, CW)).astype(np.float32), 1.2) * 6
    arr += grain[..., None]
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)

    # Ears on the sides.
    for eu in (0.25, 0.75):
        d.ellipse([*P(eu - 0.025, 0.42), *P(eu + 0.025, 0.62)], fill=tuple(int(c * 0.88) for c in person["skin"]))
        d.ellipse([*P(eu - 0.012, 0.47), *P(eu + 0.012, 0.57)], fill=tuple(int(c * 0.7) for c in person["skin"]))

    # Hair: the top, the back, the hairline at the front.
    hair = person["hair"]
    pts = []
    for i in range(65):
        uu = i / 64
        front = math.exp(-((uu - 0.5) / 0.24) ** 4)
        line = person["back"] - (person["back"] - person["hairline"]) * front
        if person.get("part") and 0.42 < uu < 0.5:
            line -= 0.04
        pts.append(P(uu, line + rng.normal(0, 0.006)))
    d.polygon([P(0, 0)] + pts + [P(1, 0)], fill=hair)
    for _ in range(140):  # strands
        uu = rng.random()
        v0 = rng.uniform(0.0, 0.25)
        k = rng.uniform(0.6, 1.5)  # one shade per strand
        d.line([P(uu, v0), P(uu + rng.normal(0, 0.01), v0 + rng.uniform(0.05, 0.2))],
               fill=tuple(int(min(255, c * k)) for c in hair), width=S)
    if person.get("curly"):
        for _ in range(220):
            uu, vv = rng.random(), rng.uniform(0, person["back"] - 0.04)
            r = rng.uniform(1.0, 2.2) * S
            x, y = P(uu, vv)
            d.ellipse([x - r, y - r, x + r, y + r], outline=tuple(int(c * 1.8) for c in hair), width=1)
    if person.get("stubble"):
        for _ in range(500):
            uu = rng.uniform(0.38, 0.62)
            vv = rng.uniform(0.62, 0.8)
            if abs(uu - 0.5) < 0.04 and vv < 0.66:
                continue
            x, y = P(uu, vv)
            d.point((x, y), fill=tuple(int(c * 0.7) for c in person["skin"]))
    if person.get("freckles"):
        for _ in range(26):
            x, y = P(rng.uniform(0.41, 0.59), rng.uniform(0.5, 0.6))
            d.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=(170, 110, 80))

    # The nose: a soft shadow down one side and under it.
    d.polygon([P(0.497, 0.47), P(0.503, 0.47), P(0.515, 0.585), P(0.49, 0.59)], fill=tuple(int(c * 0.86) for c in person["skin"]))
    d.ellipse([*P(0.488, 0.585), *P(0.512, 0.6)], fill=tuple(int(c * 0.72) for c in person["skin"]))

    if expr == "blank":
        # Only the head: the eyes, brows and mouth are separate parts in
        # the game (PlayerAvatar) so they can move.
        if person.get("moustache"):
            d.polygon([P(0.465, 0.64), P(0.5, 0.622), P(0.535, 0.64), P(0.53, 0.652), P(0.5, 0.638), P(0.47, 0.652)], fill=person["hair"])
        img = img.resize((W, H), Image.LANCZOS)
        a = np.round(np.asarray(img).astype(np.float32) / 255 * 31) / 31 * 255
        return Image.fromarray(a.astype(np.uint8))
    # Eyes.
    big = 1.25 if person.get("big_eyes") else 1.0
    scared = expr == "terrified"
    ew = 0.03 * big * (1.15 if scared else 1.0)
    eh = 0.055 * big * (1.3 if scared else 1.0)
    for ex in (0.455, 0.545):
        if person.get("bags"):
            d.arc([*P(ex - ew * 1.1, 0.47), *P(ex + ew * 1.1, 0.56)], 10, 170, fill=tuple(int(c * 0.72) for c in person["skin"]), width=S)
        if expr == "blink":
            d.arc([*P(ex - ew, 0.46), *P(ex + ew, 0.52)], 20, 160, fill=(40, 26, 20), width=int(1.3 * S))
            continue
        d.ellipse([*P(ex - ew, 0.49 - eh / 2), *P(ex + ew, 0.49 + eh / 2)], fill=(236, 232, 222))
        ir = ew * (0.42 if scared else 0.62)
        look = 0.004 * (1 if ex < 0.5 else 1)
        d.ellipse([*P(ex - ir + look, 0.49 - ir * 2), *P(ex + ir + look, 0.49 + ir * 2)], fill=person["iris"])
        pr = ir * 0.5
        d.ellipse([*P(ex - pr + look, 0.49 - pr * 2), *P(ex + pr + look, 0.49 + pr * 2)], fill=(10, 8, 8))
        d.ellipse([*P(ex - pr + look, 0.49 - pr * 2.2), *P(ex + look, 0.49 - pr * 0.8)], fill=(255, 255, 255))
        d.arc([*P(ex - ew, 0.49 - eh / 2), *P(ex + ew, 0.49 + eh / 2)], 190, 350, fill=(40, 26, 20), width=int(1.2 * S))
    # Brows: worried (inner ends up), arched high in terror.
    for ex, side in ((0.455, -1), (0.545, 1)):
        lift = 0.05 if scared else 0.025
        inner = (ex - side * 0.03, 0.43 - lift)
        outer = (ex + side * 0.035, 0.43 - (0.03 if scared else 0.0))
        d.line([P(*inner), P(*outer)], fill=person["brows"], width=int(person["brow_w"] * 2.4 * S))
    if person.get("glasses"):
        for ex in (0.455, 0.545):
            d.ellipse([*P(ex - 0.038, 0.445), *P(ex + 0.038, 0.535)], outline=(30, 26, 24), width=int(1.1 * S))
        d.line([P(0.493, 0.485), P(0.507, 0.485)], fill=(30, 26, 24), width=S)
        d.line([P(0.417, 0.48), P(0.3, 0.47)], fill=(30, 26, 24), width=S)
        d.line([P(0.583, 0.48), P(0.7, 0.47)], fill=(30, 26, 24), width=S)
    # The mouth.
    lip = tuple(int(c * 0.66) for c in person["skin"])
    if scared:
        d.ellipse([*P(0.477, 0.635), *P(0.523, 0.725)], fill=(52, 14, 14))
        d.rectangle([*P(0.484, 0.64), *P(0.516, 0.655)], fill=(230, 224, 210))
        d.ellipse([*P(0.477, 0.635), *P(0.523, 0.725)], outline=lip, width=S)
        for sx in (0.37, 0.63):  # sweat
            d.ellipse([*P(sx - 0.006, 0.4), *P(sx + 0.006, 0.45)], fill=(200, 220, 230))
    elif expr == "talk":
        d.ellipse([*P(0.474, 0.645), *P(0.526, 0.69)], fill=(60, 18, 18))
        d.ellipse([*P(0.474, 0.645), *P(0.526, 0.69)], outline=lip, width=S)
    else:
        mouth = [P(0.47 + 0.06 * t, 0.665 - 0.012 * math.sin(math.pi * t) + 0.004 * math.sin(7 * t)) for t in np.linspace(0, 1, 10)]
        d.line(mouth, fill=lip, width=int(1.4 * S), joint="curve")
    if person.get("moustache"):
        d.polygon([P(0.465, 0.64), P(0.5, 0.622), P(0.535, 0.64), P(0.53, 0.652), P(0.5, 0.638), P(0.47, 0.652)], fill=person["hair"])
    img = img.resize((W, H), Image.LANCZOS)
    a = np.asarray(img).astype(np.float32)
    a = np.round(a / 255 * 31) / 31 * 255
    return Image.fromarray(a.astype(np.uint8))


def patch():
    img = Image.new("RGB", (64 * S, 32 * S), (26, 30, 52))
    d = ImageDraw.Draw(img)
    d.rectangle([2 * S, 2 * S, 62 * S - 1, 30 * S - 1], outline=(220, 200, 120), width=S)
    font = ImageFont.truetype(str(FONT), 15 * S)
    d.text((32 * S, 16 * S), "CANAL 9", font=font, fill=(240, 205, 90), anchor="mm")
    return img.resize((64, 32), Image.LANCZOS)


def main() -> None:
    sheet = Image.new("RGB", (W * len(EXPR), H * len(PEOPLE)))
    for r, person in enumerate(PEOPLE):
        for c, expr in enumerate(EXPR):
            sheet.paste(head(person, expr, np.random.default_rng(10 + r)), (c * W, r * H))
    sheet.save(TEX / "crew_heads.png")
    patch().save(TEX / "crew_patch.png")
    print("crew_heads.png, crew_patch.png")
    if len(sys.argv) > 1:
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
