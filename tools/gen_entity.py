"""Generates the entity's sprite sheet: Vecinito drawn as an ink cartoon
(scratchy lines, a pale mask with hollow eyes, a mouth that keeps going
down into the body, rubber-hose arms ending in long pale hands). Every
pose is drawn 3 times with different jitter: played in a loop it "boils"
like hand-drawn animation.

Output: game/assets/textures/entity_sheet.png (3 columns = boil frames,
one row per pose, 128x224 px per frame; feet at the bottom edge).

    python tools/gen_entity.py [preview.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures" / "entity_sheet.png"
SCALE = 4
FW, FH = 128, 224
CW, CH = FW * SCALE, FH * SCALE
BOIL = 3

INK = (20, 7, 7, 255)
INK2 = (48, 14, 12, 255)
SKIN = (158, 112, 96, 255)
SKIN_DARK = (92, 46, 40, 255)
SKIN_LIGHT = (196, 150, 128, 255)
EYE = (205, 190, 168, 255)
RED = (125, 18, 14, 255)
TOOTH = (214, 200, 160, 255)

# Pose name -> skeleton in canvas pixels (512x896), head tilt (degrees),
# head scale, hand scales, finger spread and whether the hands go in
# front of the head. Tall and thin: the head is small for the body, the
# neck long, the arms reach below the knees.
POSES = [
    ("stand", dict(head=(256, 165), neck=(256, 330), sh=((206, 352), (306, 352)), hip=((228, 610), (284, 610)),
                   elb=((178, 545), (334, 545)), hand=((170, 765), (342, 765)), knee=((234, 752), (280, 752)),
                   foot=((228, 884), (286, 884)), tilt=-8, hs=0.85, gs=(1.0, 1.0), spread=(0.8, 0.8), front=False)),
    ("reach", dict(head=(250, 178), neck=(256, 335), sh=((206, 356), (306, 356)), hip=((228, 612), (284, 612)),
                   elb=((178, 548), (336, 470)), hand=((170, 768), (292, 515)), knee=((234, 754), (280, 754)),
                   foot=((228, 884), (286, 884)), tilt=7, hs=0.85, gs=(1.0, 1.8), spread=(0.8, 2.6), front=True)),
    ("tilt", dict(head=(326, 225), neck=(262, 335), sh=((206, 356), (306, 356)), hip=((228, 612), (284, 612)),
                  elb=((176, 548), (336, 548)), hand=((166, 770), (346, 770)), knee=((234, 754), (280, 754)),
                  foot=((228, 884), (286, 884)), tilt=-78, hs=0.85, gs=(1.0, 1.0), spread=(0.8, 0.8), front=False, hole=165)),
    ("peek", dict(head=(256, 170), neck=(256, 332), sh=((206, 354), (306, 354)), hip=((228, 611), (284, 611)),
                  elb=((168, 430), (344, 430)), hand=((222, 222), (292, 226)), knee=((234, 753), (280, 753)),
                  foot=((228, 884), (286, 884)), tilt=4, hs=0.85, gs=(1.05, 1.05), spread=(0.7, 0.7), front=True)),
    ("crouch", dict(head=(256, 462), neck=(256, 562), sh=((200, 582), (312, 582)), hip=((230, 732), (282, 732)),
                    elb=((150, 690), (362, 690)), hand=((150, 858), (362, 858)), knee=((182, 792), (330, 792)),
                    foot=((212, 886), (300, 886)), tilt=-4, hs=0.85, gs=(1.1, 1.1), spread=(1.1, 1.1), front=False)),
    ("lunge", dict(head=(256, 330), neck=(256, 470), sh=((170, 520), (342, 520)), hip=((220, 760), (292, 760)),
                   elb=((110, 560), (402, 560)), hand=((80, 410), (432, 410)), knee=((234, 830), (280, 830)),
                   foot=((228, 890), (286, 890)), tilt=0, hs=1.5, gs=(1.6, 1.6), spread=(1.4, 1.4), front=True)),
]


def subdivide(pts, step=14.0):
    out = []
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / step))
        for i in range(n):
            t = i / n
            out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    out.append(pts[-1])
    return out


def jitter(pts, rng, amount):
    return [(x + rng.normal(0, amount), y + rng.normal(0, amount)) for x, y in pts]


def sketch(d, pts, width, color, rng, passes=2, amount=2.5):
    """A line drawn several times by an unsteady hand."""
    base = subdivide(pts)
    for k in range(passes):
        q = jitter(base, rng, amount * (1 + 0.5 * k))
        d.line(q, fill=color, width=max(1, int(width * (1 - 0.3 * k))), joint="curve")


def curve(a, b, bend):
    """Rubber-hose limb: a quadratic curve from a to b bowed sideways."""
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    dx, dy = b[0] - a[0], b[1] - a[1]
    c = (mx - dy * bend, my + dx * bend)
    return [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t ** 2 * b[0],
             (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t ** 2 * b[1]) for t in np.linspace(0, 1, 12)]


def ellipse_pts(cx, cy, rx, ry, n=28, rot=0.0):
    pts = []
    for i in range(n + 1):
        a = i / n * math.tau
        x, y = math.cos(a) * rx, math.sin(a) * ry
        pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return pts


def hand(d, at, elbow, scale, spread, struct, boil):
    """A long pale hand: a small palm and five thin fingers, too long, bent
    at the joints, with dark tips. Fingers continue the forearm's direction."""
    x, y = at
    s = scale
    ang = math.atan2(y - elbow[1], x - elbow[0])
    palm = jitter(ellipse_pts(x, y, 15 * s, 11 * s, 14, ang), boil, 1.0)
    d.polygon(palm, fill=SKIN)
    sketch(d, palm, 4 * s, INK, boil, 1, 1.0)
    for i in range(5):
        a = ang + (i - 2) / 4 * spread + struct.normal(0, 0.05)
        length = struct.uniform(80, 110) * s * (0.6 if i == 0 else 1.0)
        start = (x + math.cos(a) * 12 * s, y + math.sin(a) * 12 * s)
        knuckle = (start[0] + math.cos(a) * length * 0.5, start[1] + math.sin(a) * length * 0.5)
        a2 = a + struct.normal(0, 0.3)
        tip = (knuckle[0] + math.cos(a2) * length * 0.5, knuckle[1] + math.sin(a2) * length * 0.5)
        sketch(d, [start, knuckle, tip], 9 * s, INK, boil, 1, 1.0)
        sketch(d, [start, knuckle, tip], 4 * s, SKIN, boil, 1, 0.6)
        r = 3.5 * s
        d.ellipse([tip[0] - r, tip[1] - r, tip[0] + r, tip[1] + r], fill=INK)


def draw_head(struct, boil, hs, open_mouth, hole_len=290):
    """The head on its own canvas (rotated later); centre at (300, 300)."""
    size = 600
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = 300, 300

    def p(x, y):
        return (cx + x * hs, cy + y * hs)

    # A long mask, a little crooked: almost a face.
    outline = [p(-96, -136), p(-30, -146), p(40, -140), p(98, -132), p(108, -40), p(102, 50),
               p(80, 132), p(14, 158), p(-46, 150), p(-88, 120), p(-106, 40), p(-104, -60), p(-96, -136)]
    # Hair: long scratchy spikes behind the head.
    for _ in range(34):
        i = struct.integers(0, len(outline) - 1)
        t = struct.random()
        a, b = outline[i], outline[i + 1]
        sx, sy = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        ang = math.atan2(sy - cy, sx - cx) + struct.normal(0, 0.3)
        length = struct.uniform(50, 175) * hs
        ex, ey = sx + math.cos(ang) * length, sy + math.sin(ang) * length
        mid = ((sx + ex) / 2 + struct.normal(0, 9), (sy + ey) / 2 + struct.normal(0, 9))
        sketch(d, [(sx, sy), mid, (ex, ey)], 3 * hs + 1, INK, boil, 1, 1.5)
    # What is left of the mascot ears: two small torn nubs.
    for ex, r in ((-78, 22), (82, 17)):
        ear = jitter(ellipse_pts(*p(ex, -146), r * hs, r * 0.8 * hs, 16), boil, 2.5)
        d.polygon(ear, fill=INK)

    # The mask: pale, desaturated, shaded by hatching (clipped to it).
    face = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fd = ImageDraw.Draw(face)
    shape = jitter(subdivide(outline, 10), boil, 1.8)
    fd.polygon(shape, fill=SKIN)
    for (ex, ey, rx, ry) in ((-44, -26, 34, 42), (46, -20, 29, 37)):  # sunken sockets, smudged
        fd.polygon(jitter(ellipse_pts(*p(ex, ey + 8), rx * hs, ry * hs, 18), struct, 5.0), fill=(78, 36, 30, 255))
        for k in range(8):
            a = struct.uniform(0, math.tau)
            x0, y0 = ex + math.cos(a) * rx, ey + 8 + math.sin(a) * ry
            sketch(fd, [p(x0, y0), p(x0 + struct.normal(0, 6), y0 + struct.uniform(8, 24))], 2 * hs, SKIN_DARK, boil, 1, 1.0)
    for _ in range(90):  # scratchy shading, heavier towards the edges and under the eyes
        x, y = struct.uniform(-105, 105), struct.uniform(-140, 150)
        if abs(x) < 50 and -60 < y < 20 and struct.random() < 0.7:
            continue
        ln = struct.uniform(10, 34)
        sketch(fd, [p(x, y), p(x + struct.normal(0, 4), y + ln)], 2 * hs, SKIN_DARK, boil, 1, 1.0)
    for x in (-52, 52):  # cheek hollows
        for k in range(5):
            sketch(fd, [p(x + k * 4, 30), p(x + k * 4 - 6, 95)], 2 * hs, SKIN_DARK, boil, 1, 1.0)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(shape, fill=255)
    face.putalpha(ImageChops.multiply(face.getchannel("A"), mask))
    img.alpha_composite(face)
    sketch(d, shape, 6 * hs, INK, boil, 2, 1.6)

    # The mouth: the jaw has come unhinged. A wide hole torn at the corners
    # up into the cheeks, a crowded row of small human teeth on dark gums
    # above, and the lower teeth hanging far below, at the chin, where a
    # jaw should not be. The hole keeps going down into the body.
    o = 1.3 if open_mouth else 1.0
    hw = 52 * o
    upper = [p(-hw, 40), p(-hw * 0.5, 32), p(0, 30), p(hw * 0.5, 32), p(hw, 40)]
    jaw_y = min(150 * o, hole_len - 30)
    hole = upper + [p(hw * 1.05, jaw_y - 30), p(hw * 0.8, jaw_y + 10), p(hw * 0.35, hole_len),
                    p(-hw * 0.35, hole_len), p(-hw * 0.8, jaw_y + 10), p(-hw * 1.05, jaw_y - 30)]
    d.polygon(jitter(subdivide(hole, 10), boil, 2.0), fill=INK)
    for side in (-1, 1):  # the corners, torn up towards the ears
        tear = [p(side * hw, 40), p(side * (hw + 18), 22), p(side * (hw + 34), 0), p(side * (hw + 40), -14)]
        sketch(d, tear, 5 * hs, INK, boil, 1, 1.0)
        sketch(d, tear[:3], 2 * hs, RED, boil, 1, 0.8)
        for k in range(4):  # skin stretched around the hole
            y0 = 60 + k * 22
            sketch(d, [p(side * (hw + 6), y0), p(side * (hw + 16), y0 + 18)], 2 * hs, SKIN_DARK, boil, 1, 1.0)
    gum = (78, 20, 18, 255)
    d.polygon(jitter([p(-hw * 0.95, 38), p(0, 28), p(hw * 0.95, 38), p(hw * 0.9, 46), p(0, 38), p(-hw * 0.9, 46)], boil, 1.0), fill=gum)
    count = 8
    for i in range(count):  # upper teeth: square, yellowed, some missing
        if struct.random() < 0.18:
            continue
        t = (i + 0.5) / count
        x = -hw * 0.88 + hw * 1.76 * t
        y = 34 + 8 * abs(t - 0.5) * 2 + 4
        w = struct.uniform(3.0, 3.8) * o
        h = struct.uniform(12, 20) * o * (0.8 if abs(t - 0.5) > 0.4 else 1.0)
        tooth = [p(x - w, y), p(x + w, y), p(x + w * 0.9, y + h), p(x - w * 0.9, y + h)]
        shade = TOOTH if struct.random() < 0.75 else (176, 160, 110, 255)
        d.polygon(jitter(tooth, boil, 0.6), fill=shade)
    d.polygon(jitter([p(-hw * 0.75, jaw_y + 6), p(0, jaw_y + 14), p(hw * 0.75, jaw_y + 6),
                      p(hw * 0.7, jaw_y + 16), p(0, jaw_y + 24), p(-hw * 0.7, jaw_y + 16)], boil, 1.0), fill=gum)
    for i in range(7):  # lower teeth, pointing up from the dropped jaw
        if struct.random() < 0.2:
            continue
        t = (i + 0.5) / 7
        x = -hw * 0.68 + hw * 1.36 * t
        y = jaw_y + 8 + 6 * abs(t - 0.5) * 2
        w = struct.uniform(2.8, 3.6) * o
        h = struct.uniform(10, 16) * o
        tooth = [p(x - w, y), p(x + w, y), p(x + w * 0.85, y - h), p(x - w * 0.85, y - h)]
        d.polygon(jitter(tooth, boil, 0.6), fill=TOOTH if struct.random() < 0.7 else (176, 160, 110, 255))
    for _ in range(4):  # drips from the gums
        x = struct.uniform(-hw * 0.7, hw * 0.7)
        y0 = 46 + struct.uniform(0, 6)
        sketch(d, [p(x, y0), p(x + struct.normal(0, 2), y0 + struct.uniform(30, 90))], 2.5 * hs, RED, boil, 1, 0.8)

    # Eyes: black holes, uneven, with a pinprick of light that looks at you.
    for (ex, ey, r) in ((-44, -26, 19), (46, -20, 15)):
        e = jitter(ellipse_pts(*p(ex, ey), r * hs, r * 1.15 * hs, 22), boil, 1.2)
        d.polygon(e, fill=INK)
        px, py = p(ex + 1, ey - 2)
        pr = 2.6 * hs
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=EYE)
        sketch(d, e, 5 * hs, INK, boil, 1, 1.2)
    # Strands across the face.
    for _ in range(9):
        sx, sy = p(struct.uniform(-100, 100), -140)
        sketch(d, [(sx, sy), (sx + struct.normal(0, 22), sy + struct.uniform(80, 200) * hs)], 2, INK, boil, 1, 1.5)
    return img


def draw_pose(index, frame):
    name, k = POSES[index]
    struct = np.random.default_rng(100 + index)
    boil = np.random.default_rng(1000 + index * 10 + frame)
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    (sl, sr), (hl, hr) = k["sh"], k["hip"]

    # Legs: thin, slightly bowed, long splayed toes.
    for hip, knee, foot, bend, side in ((hl, k["knee"][0], k["foot"][0], 0.08, -1), (hr, k["knee"][1], k["foot"][1], -0.08, 1)):
        sketch(d, curve(hip, knee, bend) + curve(knee, foot, -bend)[1:], 13, INK, boil, 2, 2.0)
        for t in (-0.5, 0.0, 0.6):
            toe = (foot[0] + side * 20 + t * 30 * side, foot[1] + 8)
            sketch(d, [foot, toe], 5, INK, boil, 1, 1.0)

    # Body: a hunched mass of ink with bristles along the edge.
    nx, ny = k["neck"]
    body = [(nx - 26, ny), sl, (sl[0] - 16, (sl[1] + hl[1]) / 2), (hl[0] - 10, hl[1] + 30),
            ((hl[0] + hr[0]) / 2, hl[1] + 48), (hr[0] + 10, hr[1] + 30), (sr[0] + 16, (sr[1] + hr[1]) / 2), sr, (nx + 26, ny)]
    outline = jitter(subdivide(body, 12), boil, 2.5)
    d.polygon(outline, fill=INK)
    for _ in range(60):
        x = struct.uniform(min(p[0] for p in body), max(p[0] for p in body))
        y = struct.uniform(ny, hl[1] + 30)
        sketch(d, [(x, y), (x + struct.normal(0, 6), y + struct.uniform(10, 30))], 2, INK2, boil, 1, 1.0)
    for a, b in zip(outline[:-1], outline[1:]):
        if struct.random() < 0.55:
            ang = math.atan2(b[1] - a[1], b[0] - a[0]) - math.pi / 2 + struct.normal(0, 0.4)
            ln = struct.uniform(10, 34)
            d.line([a, (a[0] + math.cos(ang) * ln, a[1] + math.sin(ang) * ln)], fill=INK, width=2)

    # Rubber-hose arms, too long.
    for sh, elb, hnd, bend in ((sl, k["elb"][0], k["hand"][0], -0.12), (sr, k["elb"][1], k["hand"][1], 0.12)):
        sketch(d, curve(sh, elb, bend) + curve(elb, hnd, bend)[1:], 12, INK, boil, 2, 2.0)
    if not k["front"]:
        for h, e, gs, sp in zip(k["hand"], k["elb"], k["gs"], k["spread"]):
            hand(d, h, e, gs, sp, struct, boil)

    # Neck and head (drawn apart so it can tilt).
    hx, hy = k["head"]
    sketch(d, curve((nx, ny + 10), (hx, hy + 60), 0.15 if k["tilt"] < -40 else 0.02), 20, INK, boil, 2, 2.0)
    head = draw_head(struct, boil, k["hs"], name == "lunge", k.get("hole", 290)).rotate(k["tilt"], resample=Image.BICUBIC, center=(300, 300))
    img.alpha_composite(head, (int(hx - 300), int(hy - 300)))
    if k["front"]:
        d = ImageDraw.Draw(img)
        for h, e, gs, sp in zip(k["hand"], k["elb"], k["gs"], k["spread"]):
            hand(d, h, e, gs, sp, struct, boil)
    return img


def to_pixels(img: Image.Image) -> Image.Image:
    small = img.resize((FW, FH), Image.BOX)
    a = np.array(small).astype(float)
    alpha = a[..., 3:4] / 255.0
    rgb = np.where(alpha > 0, a[..., :3] / np.maximum(alpha, 1e-6), 0)  # un-premultiply the edge fringe
    rgb = np.round(np.clip(rgb, 0, 255) / 255 * 15) / 15 * 255
    out = np.concatenate([rgb, np.where(alpha > 0.45, 255, 0)], axis=-1)
    return Image.fromarray(out.astype(np.uint8))


def main() -> None:
    sheet = Image.new("RGBA", (FW * BOIL, FH * len(POSES)), (0, 0, 0, 0))
    for i, (name, _) in enumerate(POSES):
        for f in range(BOIL):
            sheet.paste(to_pixels(draw_pose(i, f)), (f * FW, i * FH))
        print("  ", name)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print("entity sheet ->", OUT, sheet.size)
    if len(sys.argv) > 1:
        bg = Image.new("RGBA", sheet.size, (70, 60, 52, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(sys.argv[1])


if __name__ == "__main__":
    main()
