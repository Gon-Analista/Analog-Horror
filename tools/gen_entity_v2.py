"""Generates the entity's sprite sheet ("nueva"): La Visita redone from
nothing, built from what the analog horror figures the user chose have in
common, flat and cut out rather than lit:

  - an old plaster mask of a bear-child face, almost right (the same one
    the 3D puppet wears, tools/gen_entity_mask.py): cracked, grimy, stained
    where something ran out of the eyes and the mouth, two little ear bumps
    on top (what is left of the bear); its eye holes dark, small real
    teeth in its mouth;
  - a black silhouette under it with almost no detail: a long thin neck, a
    body that is more hair than body, black strings and spikes off every
    edge, very long thin limbs, and black hands bigger than its head;
  - long black hair falling around the mask;
  - the gaping mouth: only when it lunges does the mask give way, flushed
    red, the eyes black and hollow with a pinprick in each, and the mouth
    torn open down past the chin.
Like a paper cut-out or a stop-motion puppet: flat tones, a plaster
texture on the mask, grain, ragged edges. Each pose is drawn 3 times with
small changes (the hair stirs, it sways): played in a loop it "boils".

Output: game/assets/textures/entity_sheet_v2.png (4 columns = boil frames,
or the four steps of a cycle; one row per pose (Entity.Pose: stand, reach,
tilt, peek, crouch, lunge, crawl, walk, gallop), 192x336 px per frame; feet
at the bottom edge).

    python tools/gen_entity_v2.py [preview.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_erosion, gaussian_filter

import gen_entity_mask as M

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures" / "entity_sheet_v2.png"
FW, FH = 192, 336
S = 4                      # drawing at 4x
CW, CH = FW * S, FH * S
BOIL = 4  # columns: boil frames, or the steps of a cycle (walk, gallop)

BLACK = (10, 8, 8, 255)
BLACK_2 = (30, 25, 24, 255)
HAIR = (6, 5, 5, 255)

# Skeletons in frame units (192x336, feet at y=336): head centre and mask
# width, neck base, shoulders, hips, elbows, hands, knees, feet, the head's
# tilt, hand scales and spread, and whether the hands are in front.
POSES = [
    ("stand", dict(head=(96, 40), mw=36, neck=(96, 104), sh=((76, 112), (116, 112)), hip=((86, 214), (106, 214)),
                   elb=((64, 180), (128, 180)), hand=((60, 252), (132, 252)), knee=((86, 272), (106, 272)),
                   foot=((84, 335), (108, 335)), tilt=-6, gs=(1.0, 1.0), spread=(0.55, 0.55), front=False, face="smile")),
    ("reach", dict(head=(92, 42), mw=36, neck=(96, 106), sh=((76, 114), (116, 114)), hip=((86, 214), (106, 214)),
                   elb=((64, 182), (126, 150)), hand=((60, 254), (118, 140)), knee=((86, 272), (106, 272)),
                   foot=((84, 335), (108, 335)), tilt=8, gs=(1.0, 2.1), spread=(0.55, 1.3), front=True, face="happy")),
    ("tilt", dict(head=(122, 64), mw=36, neck=(98, 106), sh=((76, 114), (116, 114)), hip=((86, 214), (106, 214)),
                  elb=((64, 182), (128, 182)), hand=((58, 254), (134, 254)), knee=((86, 272), (106, 272)),
                  foot=((84, 335), (108, 335)), tilt=-80, gs=(1.0, 1.0), spread=(0.55, 0.55), front=False, face="grin")),
    # Leaning round an edge (a corner, the side of your hiding place): the
    # head tipped over, the long fingers gripping the edge on either side,
    # well clear of the face, and the widest toothy smile, at you.
    ("peek", dict(head=(100, 46), mw=46, neck=(96, 106), sh=((76, 114), (116, 114)), hip=((86, 214), (106, 214)),
                  elb=((50, 138), (142, 138)), hand=((40, 78), (152, 80)), knee=((86, 272), (106, 272)),
                  foot=((84, 335), (108, 335)), tilt=16, gs=(1.15, 1.15), spread=(0.9, 0.9), front=True, face="beam")),
    # Bent at the waist, not squatting: the legs straight, the body folded
    # forward over them, the neck hanging, the mask low, looking up at you.
    ("crouch", dict(head=(96, 168), mw=36, neck=(96, 150), sh=((78, 140), (114, 140)), hip=((86, 214), (106, 214)),
                    elb=((66, 200), (126, 200)), hand=((62, 300), (130, 300)), knee=((86, 272), (106, 272)),
                    foot=((84, 335), (108, 335)), tilt=4, gs=(1.0, 1.0), spread=(0.6, 0.6), front=False, folded=True, face="sad")),
    ("lunge", dict(head=(96, 123), mw=72, neck=(96, 190), sh=((70, 200), (122, 200)), hip=((84, 280), (108, 280)),
                   elb=((40, 200), (152, 200)), hand=((28, 120), (164, 120)), knee=((86, 308), (106, 308)),
                   foot=((84, 335), (108, 335)), tilt=0, gs=(1.9, 1.9), spread=(1.0, 1.0), front=True, open=True)),
    # Under the boards: on hands and knees like a person, low, the head
    # forward (no spider legs).
    ("crawl", dict(head=(96, 262), mw=34, neck=(96, 244), sh=((78, 238), (114, 238)), hip=((88, 206), (104, 206)),
                   elb=((68, 282), (124, 282)), hand=((66, 332), (126, 332)), knee=((84, 296), (108, 296)),
                   foot=((86, 318), (106, 318)), tilt=0, gs=(1.0, 1.0), spread=(0.55, 0.55), front=False, face="grin")),
    # Walking: a stiff, too-long stride, the head bobbing, the arms swinging
    # wrong (the same side as the leg). Four steps.
    ("walk", dict(head=(96, 40), mw=36, neck=(96, 104), sh=((76, 112), (116, 112)), hip=((86, 214), (106, 214)),
                  elb=((64, 180), (128, 180)), hand=((60, 252), (132, 252)), knee=((86, 272), (106, 272)),
                  foot=((84, 335), (108, 335)), tilt=-6, gs=(1.0, 1.0), spread=(0.55, 0.55), front=False, face="smile",
                  cycle=[dict(knee=((86, 272), (110, 256)), foot=((84, 335), (112, 318)), hand=((58, 244), (134, 262)), head=(98, 38)),
                         dict(head=(96, 44), neck=(96, 107)),
                         dict(knee=((82, 256), (106, 272)), foot=((80, 318), (108, 335)), hand=((58, 262), (134, 244)), head=(94, 38)),
                         dict(head=(96, 44), neck=(96, 107))])),
    # Scrambling away from the flash on hands and knees, like a person
    # crawling fast: arms under the shoulders, knees under the hips, the
    # hands reaching in turn.
    ("gallop", dict(head=(96, 232), mw=34, neck=(96, 236), sh=((76, 238), (116, 238)), hip=((88, 200), (104, 200)),
                    elb=((66, 284), (126, 284)), hand=((64, 334), (128, 334)), knee=((82, 296), (110, 296)),
                    foot=((84, 320), (108, 320)), tilt=0, gs=(1.0, 1.0), spread=(0.55, 0.55), front=False, face="grin",
                    cycle=[dict(hand=((66, 310), (128, 334)), elb=((68, 268), (126, 284)), head=(97, 228)),
                           dict(head=(96, 236), neck=(96, 240)),
                           dict(hand=((64, 334), (126, 310)), elb=((66, 284), (124, 268)), head=(95, 228)),
                           dict(head=(96, 234), neck=(96, 238))])),
    # Found out, before it runs at you: it stays where it is and its neck
    # grows, long and thin, the head coming at you on it, smiling.
    ("stretch", dict(head=(104, 30), mw=48, neck=(96, 168), sh=((76, 176), (116, 176)), hip=((86, 250), (106, 250)),
                     elb=((62, 228), (130, 228)), hand=((58, 296), (134, 296)), knee=((86, 292), (106, 292)),
                     foot=((84, 335), (108, 335)), tilt=10, gs=(1.0, 1.0), spread=(0.6, 0.6), front=False, face="beam", attach=0.55)),
    # Running at you, upright, screaming: the head thrown forward and
    # tilted, the arms reaching out at you, a long stiff stride.
    ("run", dict(head=(100, 46), mw=42, neck=(96, 108), sh=((76, 116), (116, 116)), hip=((86, 214), (106, 214)),
                 elb=((52, 150), (140, 150)), hand=((44, 104), (148, 100)), knee=((86, 272), (106, 272)),
                 foot=((84, 335), (108, 335)), tilt=-12, gs=(1.25, 1.25), spread=(1.0, 1.0), front=True, face="scream",
                 cycle=[dict(knee=((86, 272), (112, 252)), foot=((84, 335), (116, 312)), hand=((40, 96), (150, 112)), head=(104, 42)),
                        dict(head=(96, 50), neck=(96, 110), hand=((46, 108), (146, 104))),
                        dict(knee=((80, 252), (106, 272)), foot=((76, 312), (108, 335)), hand=((42, 112), (152, 96)), head=(92, 42)),
                        dict(head=(100, 50), neck=(96, 110), hand=((48, 100), (144, 108)))])),
]


def P(pt, boil, wob=0.6):
    return (pt[0] * S + boil.normal(0, wob * S * 0.25), pt[1] * S + boil.normal(0, wob * S * 0.25))


def bezier(a, b, bend, n=14):
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    dx, dy = b[0] - a[0], b[1] - a[1]
    c = (mx - dy * bend, my + dx * bend)
    return [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t ** 2 * b[0],
             (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t ** 2 * b[1]) for t in np.linspace(0, 1, n)]


def tapered(d, pts, w0, w1, color):
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        r = (w0 + (w1 - w0) * i / max(1, n - 1)) / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)
    for i in range(n - 1):
        w = w0 + (w1 - w0) * i / max(1, n - 1)
        d.line([pts[i], pts[i + 1]], fill=color, width=max(1, int(w)))


def strings(d, origin_pts, rng, boil, count, length, width, color, outward=None):
    """Black strings, hair hanging off it, a little stirred each frame."""
    for _ in range(count):
        sx, sy = origin_pts[rng.integers(len(origin_pts))]
        ln = rng.uniform(*length)
        if outward is not None:
            ang = math.atan2(sy - outward[1], sx - outward[0]) + rng.normal(0, 0.35)
        else:
            ang = math.pi / 2 + rng.normal(0, 0.12)
        sway = boil.normal(0, 0.06)
        pts = [(sx, sy)]
        for k in range(1, 6):
            t = k / 5
            a = ang + sway * t + rng.normal(0, 0.05)
            pts.append((pts[-1][0] + math.cos(a) * ln / 5, pts[-1][1] + math.sin(a) * ln / 5))
        tapered(d, pts, width, max(1, width * 0.35), color)


def hand(d, at, elbow, scale, spread, rng, boil):
    """A black hand bigger than its head: a narrow palm, five long thin
    fingers, knuckled, a dull grey edge where the light catches."""
    x, y = at
    s = scale * S
    ang = math.atan2(y - elbow[1], x - elbow[0])
    pal = [(x + math.cos(ang + a) * r * s, y + math.sin(ang + a) * r * s) for a, r in ((0, 9), (1.5, 6), (math.pi, 5), (-1.5, 6))]
    d.polygon(pal, fill=BLACK)
    for i in range(5):
        a = ang + (i - 2) / 4 * spread * 2 + rng.normal(0, 0.04) + boil.normal(0, 0.02)
        length = rng.uniform(26, 34) * s * (0.6 if i in (0, 4) else 1.0)
        base = (x + math.cos(a) * 6 * s, y + math.sin(a) * 6 * s)
        a2 = a + rng.normal(0, 0.25)
        k1 = (base[0] + math.cos(a) * length * 0.55, base[1] + math.sin(a) * length * 0.55)
        tip = (k1[0] + math.cos(a2) * length * 0.45, k1[1] + math.sin(a2) * length * 0.45)
        tapered(d, [base, k1], 3.2 * s, 2.4 * s, BLACK)
        tapered(d, [k1, tip], 2.4 * s, 0.9 * s, BLACK)
        d.line([base, k1], fill=BLACK_2, width=max(1, int(0.6 * s)))


def mask_image(mw, open_mouth, rng, boil, face="smile", frame=0):
    """The mask (and the hair around it) on its own RGBA canvas, centred,
    to be rotated."""
    size = int(mw * S * 4.4)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    u = mw * S / 2  # half the mask's width

    def p(x, y):
        return (c + x * u, c + y * u)

    # Long black hair behind and around it.
    scalp = [p(math.cos(a) * 1.05, -0.35 + math.sin(a) * 1.25) for a in np.linspace(math.pi * 1.05, math.pi * 1.95, 18)]
    strings(d, scalp, rng, boil, 46, (1.6 * u, 3.4 * u), 0.22 * u, HAIR)
    sides = [p(sx * 1.0, y) for sx in (-1, 1) for y in np.linspace(-0.9, 0.6, 6)]
    strings(d, sides, rng, boil, 30, (1.2 * u, 2.6 * u), 0.18 * u, HAIR)
    # The mask: the same old plaster mask as the 3D puppet's
    # (gen_entity_mask.py: cracked, grimy, stained, real teeth), flat-lit
    # from above by its own relief; in its eye holes, nothing
    # (only dark: no eyes, user 2026-10-27; in the lunge, a pinprick of
    # light); the mouth opens onto black.
    return _plaster_mask(img, c, u, "open" if open_mouth else face, frame)


_MASK_CACHE = {}


def _plaster_mask(img, c, u, face, frame):
    key = (face, frame % 2)
    if key not in _MASK_CACHE:
        _MASK_CACHE[key] = M.face_cell(face, frame % 2)
    col, nrm = _MASK_CACHE[key]
    w = int(round((M.X1 - M.X0) * u))
    h = int(round((M.Y1 - M.Y0) * u))
    col = col.resize((w, h), Image.LANCZOS)
    nrm = np.asarray(nrm.resize((w, h), Image.LANCZOS)).astype(np.float32) / 127.5 - 1.0
    a = np.asarray(col).astype(np.float32)
    # Lit from above and a little to the left (its own relief).
    light = np.array([-0.35, 0.55, 0.75])
    light /= np.linalg.norm(light)
    shade = np.clip((nrm * light).sum(axis=2), 0.0, 1.0)
    a[..., :3] *= (0.55 + 0.6 * shade)[..., None]
    # The holes: dark, with an eye far back in each socket.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx = M.X0 + xx / w * (M.X1 - M.X0)
    my = M.Y0 + yy / h * (M.Y1 - M.Y0)
    inside = M.mask_shape(mx, my)
    holes = inside & (a[..., 3] < 128)
    a[holes] = (6, 3, 3, 255)
    base = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(base)
    for ex, ey in M.EYE:
        px = (ex - M.X0) / (M.X1 - M.X0) * w
        py = (ey - M.Y0) / (M.Y1 - M.Y0) * h
        if face == "open":
            r = 0.035 * u
            d.ellipse([px - r, py - r, px + r, py + r], fill=(236, 230, 214, 255))
    # (The pinpricks only inside the holes: the mask over everything else.)
    eyes = np.asarray(base).copy()
    mask_px = np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA"))
    keep = ~holes
    eyes[keep] = mask_px[keep]
    eyes[~inside & (mask_px[..., 3] == 0)] = (0, 0, 0, 0)
    face_img = Image.fromarray(eyes, "RGBA")
    img.alpha_composite(face_img, (int(c + M.X0 * u), int(c + M.Y0 * u)))
    return img


def pose(index, frame):
    name, k = POSES[index]
    if "cycle" in k:
        k = dict(k)
        k.update(k["cycle"][frame % len(k["cycle"])])
    rng = np.random.default_rng(300 + index)      # the same in all 3 frames
    boil = np.random.default_rng(3000 + index * 10 + frame)
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    sway = (0.0, 1.2, -0.8, 0.5)[frame] * S
    sl, sr = P(k["sh"][0], boil), P(k["sh"][1], boil)
    sl = (sl[0], sl[1] + 7 * S)  # one shoulder dropped
    hl, hr = P(k["hip"][0], boil), P(k["hip"][1], boil)
    nx, ny = P(k["neck"], boil)
    nx += sway

    # Legs: long and thin, a little bowed; long splayed toes.
    for hip, knee, foot, bend, side in ((hl, P(k["knee"][0], boil), P(k["foot"][0], boil), 0.06, -1),
                                        (hr, P(k["knee"][1], boil), P(k["foot"][1], boil), -0.06, 1)):
        tapered(d, bezier(hip, knee, bend) + bezier(knee, foot, -bend)[1:], 5.5 * S, 3.0 * S, BLACK)
        for t in (-0.4, 0.2, 0.7):
            toe = (foot[0] + side * (6 + t * 8) * S, foot[1] + 1 * S)
            d.line([foot, toe], fill=BLACK, width=int(1.6 * S))

    # The body: more hair than body, black, strings hanging off every edge.
    folded = k.get("folded", False)
    top_y = min(sl[1], sr[1])
    body = [(nx - 7 * S, ny - 4 * S), sl, (sl[0] - 6 * S, (top_y + hl[1]) / 2), (hl[0] - 4 * S, hl[1] + 6 * S),
            ((hl[0] + hr[0]) / 2, hl[1] + 14 * S), (hr[0] + 4 * S, hr[1] + 6 * S), (sr[0] + 6 * S, (top_y + hr[1]) / 2), sr, (nx + 7 * S, ny - 4 * S)]
    d.polygon(body, fill=BLACK)
    edge_pts = []
    for a, b in zip(body, body[1:] + body[:1]):
        for t in np.linspace(0, 1, 8, endpoint=False):
            edge_pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    strings(d, edge_pts, rng, boil, 70, (8 * S, 34 * S), 1.6 * S, HAIR)
    strings(d, edge_pts, rng, boil, 40, (4 * S, 12 * S), 1.0 * S, HAIR, outward=((hl[0] + hr[0]) / 2, (top_y + hl[1]) / 2))

    # Arms: very long, thin, rubbery.
    arms = []
    for sh, elb, hnd, bend in ((sl, P(k["elb"][0], boil), P(k["hand"][0], boil), -0.1), (sr, P(k["elb"][1], boil), P(k["hand"][1], boil), 0.1)):
        # A second elbow between the elbow and the hand, bent the wrong way.
        mid = ((elb[0] + hnd[0]) / 2 - (hnd[1] - elb[1]) * 0.18 * (1 if bend > 0 else -1),
               (elb[1] + hnd[1]) / 2 + (hnd[0] - elb[0]) * 0.18 * (1 if bend > 0 else -1))
        pts = bezier(sh, elb, bend, 10) + bezier(elb, mid, -bend * 0.5, 6)[1:] + bezier(mid, hnd, bend * 0.5, 6)[1:]
        tapered(d, pts, 5.0 * S, 3.0 * S, BLACK)
        for j in (elb, mid):  # the knots of the joints
            d.ellipse([j[0] - 3.2 * S, j[1] - 3.2 * S, j[0] + 3.2 * S, j[1] + 3.2 * S], fill=BLACK)
        arms.append((hnd, mid))
    if name not in ("lunge", "crawl"):
        # Ribs through the hair, too many, uneven.
        cx_ = (sl[0] + sr[0]) / 2
        for i in range(7):
            y = top_y + (14 + i * 7) * S
            w = (13 - abs(i - 2) * 1.2) * S
            for side in (-1, 1):
                d.line(bezier((cx_ + side * 1.5 * S, y), (cx_ + side * w, y + 5 * S), 0.18 * side, 6), fill=BLACK_2, width=int(1.1 * S))
    if name != "crawl":
        # A second pair of arms, thinner, from low on its ribs: they follow
        # the others a beat behind, smaller, clutching.
        cx_ = (sl[0] + sr[0]) / 2
        for (sh, (hnd, mid)), side in zip(((sl, arms[0]), (sr, arms[1])), (-1, 1)):
            root_ = (cx_ + side * 6 * S, top_y + 30 * S)
            dx, dy = hnd[0] - sh[0], hnd[1] - sh[1]
            el_ = (root_[0] + dx * 0.35 + side * 17 * S, root_[1] + dy * 0.35 + boil.normal(0, 1.5) * S)
            hd_ = (root_[0] + dx * 0.5 + side * 13 * S, root_[1] + dy * 0.62 + boil.normal(0, 1.5) * S)
            tapered(d, bezier(root_, el_, -0.2 * side, 6) + bezier(el_, hd_, 0.25 * side, 6)[1:], 3.4 * S, 2.2 * S, BLACK)
            d.ellipse([el_[0] - 2.4 * S, el_[1] - 2.4 * S, el_[0] + 2.4 * S, el_[1] + 2.4 * S], fill=BLACK)
            hand(d, hd_, el_, 0.55, 0.4, rng, boil)
    if not k["front"]:
        for (hnd, elb), gs, sp in zip(arms, k["gs"], k["spread"]):
            hand(d, hnd, elb, gs, sp, rng, boil)

    # Neck: long and thin; folded over, it hangs down from the shoulders.
    hx, hy = P(k["head"], boil, 0.3)
    hx += sway * (1.6 if not folded else 0.5)
    tilt = k["tilt"] + boil.normal(0, 1.0)
    if abs(k["tilt"]) > 120:
        attach = (hx, hy - k["mw"] * S * 1.1)
    else:
        a = math.radians(tilt)
        under = k.get("attach", 1.2)  # how far under the head's centre the neck meets it
        attach = (hx - math.sin(a) * k["mw"] * S * under, hy + math.cos(a) * k["mw"] * S * under)
    neck_bend = 0.25 if folded else (0.12 if k["tilt"] < -40 else 0.03)
    tapered(d, bezier((nx, ny), attach, neck_bend), 8.0 * S, 6.5 * S, BLACK)
    m = mask_image(k["mw"], k.get("open", False), rng, boil, k.get("face", "smile"), frame).rotate(tilt, resample=Image.BICUBIC, expand=False)
    img.alpha_composite(m, (int(hx - m.width / 2), int(hy - m.height / 2)))
    if k["front"]:
        d = ImageDraw.Draw(img)
        for (hnd, elb), gs, sp in zip(arms, k["gs"], k["spread"]):
            hand(d, hnd, elb, gs, sp, rng, boil)
    return img


def to_pixels(img: Image.Image, frame: int) -> Image.Image:
    a = np.asarray(img).astype(np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    small_rgb = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8)).resize((FW, FH), Image.BOX), np.float32) / 255
    small_a = np.asarray(Image.fromarray((a[..., 3] * 255).astype(np.uint8)).resize((FW, FH), Image.BOX), np.float32) / 255
    col = np.where(small_a[..., None] > 0, small_rgb / np.maximum(small_a[..., None], 1e-4), 0)
    solid = small_a > 0.4
    rng = np.random.default_rng(55 + frame)
    col = col * (1 + rng.standard_normal((FH, FW, 1)) * 0.06)   # grain
    edge = solid & ~binary_erosion(solid)
    col[edge] *= 0.6
    col = np.round(np.clip(col, 0, 1) * 31) / 31
    return Image.fromarray(np.dstack([col * 255, np.where(solid, 255, 0)]).astype(np.uint8), "RGBA")


def main() -> None:
    sheet = Image.new("RGBA", (FW * BOIL, FH * len(POSES)), (0, 0, 0, 0))
    for i, (name, _) in enumerate(POSES):
        for f in range(BOIL):
            sheet.paste(to_pixels(pose(i, f), f), (f * FW, i * FH))
        print("  ", name)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print("entity sheet (nueva) ->", OUT, sheet.size)
    if len(sys.argv) > 1:
        bg = Image.new("RGBA", sheet.size, (150, 120, 96, 255))
        bg.alpha_composite(sheet)
        bg.save(sys.argv[1])


if __name__ == "__main__":
    main()
