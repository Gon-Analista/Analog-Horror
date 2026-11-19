"""Generates what the living-room TV shows: ¡Te estoy viendo!, a 1989
local-TV children's programme recorded on a worn VHS tape.

Not a clean cartoon: a man in a cheap mascot costume (Vecinito: matted
mustard fur, plastic googly eyes, a stitched smile, felt bow tie, white
gloves) on a studio set that is this same living room (the house's own
wallpaper and sofa). He plays peekaboo and hide-and-seek with the children
watching: "close your eyes and count with me", "ready or not, here I come",
"where are you?". Everything is a little too long, too close, too still.
Then the wrong frames: the costume staring straight at you, the set gone
dark, an extreme close-up of the stitched mouth where a human eye looks out
from inside, the empty set with the gloves left on the sofa, and a broadcast
intrusion (the costume head swaying in front of a turning corrugated metal
sheet, after the 1987 Max Headroom hijacking). References: Local 58
(ordinary-to-wrong escalation, authority), Candle Cove (a kids' show that
should not exist), Gemini Home Entertainment / Mandela Catalogue (too-still
figures, faces that are almost right).

Every frame is drawn at 640x480 with soft studio lighting, felt and fur,
then "recorded": blur, chroma bleed and lag, lifted blacks, generation
noise, head-switching noise at the bottom; it ends 320x240.

Output (frame order: game/scripts/world/tv_show.gd):
  game/assets/textures/tv_show.png   one row of 320x240 frames
  game/assets/textures/tv_seal.png   the emergency seal, normal and corrupted (2 x 96x96)

    python tools/gen_tv.py [preview.png]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import distance_transform_edt, maximum_filter, gaussian_filter, shift as nd_shift

ROOT = Path(__file__).resolve().parent.parent
TEX = ROOT / "game" / "assets" / "textures"
OUT = TEX / "tv_show.png"
SEAL_OUT = TEX / "tv_seal.png"
W0, H0 = 640, 480       # drawing size
W, H = 320, 240         # frame size
SS = 2                  # supersampling of shape masks
YY, XX = np.mgrid[0:H0, 0:W0].astype(np.float32)
RNG = np.random.default_rng(1989)

FONT_KID = "C:/Windows/Fonts/comicbd.ttf"
FONT_TV = str(ROOT / "game" / "assets" / "fonts" / "VT323-Regular.ttf")

FUR = np.array([0.64, 0.47, 0.22])
FUR_LIGHT = np.array([0.8, 0.7, 0.5])
SKIN = np.array([0.6, 0.44, 0.36])
GLOVE = np.array([0.92, 0.9, 0.84])
BOW = np.array([0.62, 0.08, 0.1])
EAR_IN = np.array([0.7, 0.42, 0.36])

# Frame order (keep in step with tv_show.gd).
FRAMES = (["cover_a", "cover_b", "part", "open_a", "open_b", "lean", "static_a", "static_b"]
          + ["count_%d" % n for n in range(1, 11)]
          + ["ready", "seek_a", "seek_b", "stare", "stare_dark", "close", "empty",
             "intrude_a", "intrude_b", "intrude_c", "intrude_d", "bars"])


# --- noise and textures -------------------------------------------------------------

def fbm(scale: float, octaves: int = 4, seed: int = 0) -> np.ndarray:
    rng = np.random.default_rng(seed)
    out = np.zeros((H0, W0), np.float32)
    amp = 1.0
    for o in range(octaves):
        out += gaussian_filter(rng.standard_normal((H0, W0)).astype(np.float32), scale / (2 ** o)) * amp * (2 ** o) ** 0.5
        amp *= 0.55
    return out / (np.abs(out).max() + 1e-6)


FELT = fbm(2.0, 3, 1)
FUR_TEX = gaussian_filter(RNG.standard_normal((H0, W0)).astype(np.float32), (2.2, 0.6))  # matted, vertical tufts
FUR_TEX /= np.abs(FUR_TEX).max()
CLUMPS = fbm(9.0, 3, 2)
GRIME = fbm(40.0, 3, 3)
STAINS = np.clip(fbm(14.0, 3, 4) * 1.6 - 0.35, 0, 1)  # matted, dirty patches


def furry(m: np.ndarray, amount: float = 1.0) -> np.ndarray:
    """A fur silhouette: the clean edge broken into tufts."""
    soft = gaussian_filter(m, 2.2)
    return np.clip((soft - 0.5 + FUR_TEX * 0.22 * amount) * 4.0 + 0.5, 0.0, 1.0) * (soft > 0.02)


def tile_texture(name: str, scale: int, blur: float) -> np.ndarray:
    im = Image.open(TEX / name).convert("RGB")
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    a = np.asarray(im, np.float32) / 255.0
    reps = (H0 // a.shape[0] + 2, W0 // a.shape[1] + 2, 1)
    big = np.tile(a, reps)[:H0, :W0]
    return gaussian_filter(big, (blur, blur, 0))


WALLPAPER = tile_texture("wallpaper.png", 3, 1.2)
FLOOR = tile_texture("floor_wood.png", 4, 1.0)
WOOD = tile_texture("wood_dark.png", 4, 1.0)
SOFA_TEX = tile_texture("sofa.png", 6, 1.5)


# --- shapes ---------------------------------------------------------------------------

def mask(draw_fn) -> np.ndarray:
    im = Image.new("L", (W0 * SS, H0 * SS), 0)
    draw_fn(ImageDraw.Draw(im), SS)
    return np.asarray(im.resize((W0, H0), Image.BOX), np.float32) / 255.0


def ell_pts(cx, cy, rx, ry, rot=0.0, n=72):
    c, s = math.cos(rot), math.sin(rot)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def ellipse_mask(cx, cy, rx, ry, rot=0.0):
    pts = ell_pts(cx, cy, rx, ry, rot)
    return mask(lambda d, k: d.polygon([(x * k, y * k) for x, y in pts], fill=255))


def poly_mask(pts):
    return mask(lambda d, k: d.polygon([(x * k, y * k) for x, y in pts], fill=255))


def capsule_mask(p0, p1, r):
    def fn(d, k):
        d.line([(p0[0] * k, p0[1] * k), (p1[0] * k, p1[1] * k)], fill=255, width=int(2 * r * k))
        for p in (p0, p1):
            d.ellipse([(p[0] - r) * k, (p[1] - r) * k, (p[0] + r) * k, (p[1] + r) * k], fill=255)
    return mask(fn)


def sphere_normal(cx, cy, rx, ry):
    nx = (XX - cx) / rx
    ny = (YY - cy) / ry
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
    return nx, ny, nz


def capsule_normal(p0, p1, r):
    ax, ay = p1[0] - p0[0], p1[1] - p0[1]
    ln = ax * ax + ay * ay + 1e-6
    t = np.clip(((XX - p0[0]) * ax + (YY - p0[1]) * ay) / ln, 0, 1)
    dx = (XX - (p0[0] + ax * t)) / r
    dy = (YY - (p0[1] + ay * t)) / r
    nz = np.sqrt(np.clip(1.0 - dx * dx - dy * dy, 0.0, 1.0))
    return dx, dy, nz


class Light:
    def __init__(self, direction=(-0.45, -0.55, 0.7), key=0.95, ambient=0.28, color=(1.0, 0.94, 0.84)):
        v = np.array(direction, np.float32)
        self.d = v / np.linalg.norm(v)
        self.key = key
        self.ambient = ambient
        self.color = np.array(color)


def shade(normal, light: Light, gloss=0.0, rim=0.15):
    nx, ny, nz = normal
    lam = np.clip(nx * light.d[0] + ny * light.d[1] + nz * light.d[2], 0.0, 1.0)
    out = light.ambient + light.key * lam
    out = out + rim * np.clip(1.0 - nz, 0, 1) ** 3  # a little rim from the bounce
    spec = 0.0
    if gloss > 0:
        # Reflected half-vector towards the viewer (0,0,1).
        hx, hy, hz = light.d[0], light.d[1], light.d[2] + 1.0
        hl = math.sqrt(hx * hx + hy * hy + hz * hz)
        spec = np.clip((nx * hx + ny * hy + nz * hz) / hl, 0, 1) ** 40 * gloss
    return out, spec


def paint(canvas, m, color, light_term=None, spec=0.0, texture=None, tex_amt=0.0, alpha=None):
    col = np.broadcast_to(np.asarray(color, np.float32), canvas.shape).copy()
    if texture is not None:
        col *= (1.0 + texture[..., None] * tex_amt)
    if light_term is not None:
        col = col * light_term[..., None]
    if not np.isscalar(spec):
        col = col + spec[..., None]
    m3 = m[..., None]
    canvas[:] = canvas * (1 - m3) + col * m3
    if alpha is not None:
        np.maximum(alpha, m, out=alpha)


# --- the set --------------------------------------------------------------------------

def studio_falloff(cx=320, cy=250, r=300, floor=0.35):
    return floor + (1 - floor) * np.exp(-((XX - cx) ** 2 + ((YY - cy) * 1.2) ** 2) / (2 * r * r))


SOFA_TOP = 236


def draw_sofa(c, lit=True):
    """The set's sofa (the house's own fabric). `lit`: with the studio
    light already on it (when it is drawn over something afterwards)."""
    s_l, s_r, s_t = 96, 544, SOFA_TOP
    back = poly_mask([(s_l, s_t + 16), (s_l + 20, s_t), (s_r - 20, s_t), (s_r, s_t + 16), (s_r, 352), (s_l, 352)])
    nrm = (np.zeros_like(XX), np.clip((YY - 300) / 80, -1, 1) * 0.6, np.ones_like(XX) * 0.8)
    term, _ = shade(nrm, Light((0, -0.6, 0.8), 0.7, 0.35))
    before = c.copy()
    paint(c, back, (0.8, 0.8, 0.8), term, texture=None)
    c = c * (1 - back[..., None]) + c * back[..., None] * (SOFA_TEX * 1.1)
    # The seat and its skirt, down to the floor (nothing shows under it).
    seat = poly_mask([(s_l, 340), (s_r, 340), (s_r - 6, 404), (s_l + 6, 404)])
    paint(c, seat, SOFA_TEX[380, 320] * 0.8, studio_falloff(320, 360, 200, 0.55))
    back = np.maximum(back, seat)
    arms = np.zeros_like(back)
    for ax in (s_l + 10, s_r - 10):
        arm = ellipse_mask(ax, 330, 34, 60)
        paint(c, arm, SOFA_TEX[330, int(ax)] * 1.2, studio_falloff(ax, 300, 90, 0.5))
        arms = np.maximum(arms, arm)
    if lit:
        m = np.maximum(back, arms)[..., None]
        c = before * (1 - m) + c * m * studio_falloff()[..., None]
    return c


def room_set(dark=False, sofa=True, lamp=True, tilt=0.0) -> np.ndarray:
    """This living room as a studio set: the wallpaper, wainscot, floor,
    the sofa behind the host, a floor lamp, a framed photo."""
    c = np.zeros((H0, W0, 3), np.float32)
    wall_end = 318 + tilt * (XX - 320)
    wall = (YY < wall_end).astype(np.float32)
    c[:] = WALLPAPER * 0.9
    wain = ((YY >= wall_end) & (YY < wall_end + 46)).astype(np.float32)
    c = c * (1 - wain[..., None]) + WOOD * 0.85 * wain[..., None]
    rail = ((YY >= wall_end - 4) & (YY < wall_end)).astype(np.float32)
    c = c * (1 - rail[..., None]) + np.array([0.3, 0.2, 0.12]) * rail[..., None]
    flo = (YY >= wall_end + 46).astype(np.float32)
    c = c * (1 - flo[..., None]) + FLOOR * 0.75 * flo[..., None]
    # Water stains and grime on the wallpaper.
    c *= (1.0 - 0.18 * np.clip(GRIME, 0, 1) * wall)[..., None]
    # A framed photo: the family, faces too small to make out.
    fx, fy = 470, 120
    frame = poly_mask([(fx, fy), (fx + 84, fy), (fx + 84, fy + 104), (fx, fy + 104)])
    paint(c, frame, (0.22, 0.14, 0.08))
    inner = poly_mask([(fx + 9, fy + 9), (fx + 75, fy + 9), (fx + 75, fy + 95), (fx + 9, fy + 95)])
    paint(c, inner, (0.55, 0.5, 0.42), texture=FELT, tex_amt=0.15)
    for i, px in enumerate((fx + 26, fx + 44, fx + 60)):
        paint(c, ellipse_mask(px, fy + 50, 8, 9), (0.3, 0.24, 0.2))
        paint(c, poly_mask([(px - 11, fy + 92), (px + 11, fy + 92), (px + 9, fy + 62), (px - 9, fy + 62)]), (0.28, 0.25, 0.3))
    if lamp:
        # Floor lamp on the left, its shade glowing.
        paint(c, poly_mask([(88, 150), (92, 150), (94, 380), (86, 380)]), (0.15, 0.12, 0.1))
        shade_m = poly_mask([(56, 150), (124, 150), (110, 100), (70, 100)])
        paint(c, shade_m, (1.0, 0.82, 0.55))
    if sofa:
        c = draw_sofa(c, lit=False)
    light = studio_falloff()
    if lamp:
        light = light + 0.55 * np.exp(-((XX - 90) ** 2 + (YY - 140) ** 2) / (2 * 110 ** 2))
    c *= light[..., None]
    if dark:
        c *= 0.12
    return c


# --- the costume ------------------------------------------------------------------------

def draw_glove(c, hand, wrist_from, toward, R, light, alpha=None, curl=0.0, flat=False):
    """A cartoon costume glove, drawn as ONE puffy shape (not a bunch of
    tubes): a round padded palm, three chunky fingers and a thumb that grow
    out of it, all inflated together like a stuffed glove, a thin dark
    outline, short creases between the fingers, three sewn lines on the
    back and a rolled cuff at the wrist. It points the way the forearm
    points (from `wrist_from` through `hand`); the thumb turns towards
    `toward`. `curl` (0..1) bends the fingers in (gripping); `flat` lays
    it down (on the sofa): wider, flatter shading."""
    dx, dy = hand[0] - wrist_from[0], hand[1] - wrist_from[1]
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln              # along the forearm
    px, py = -uy, ux                       # across it
    if (toward[0] - hand[0]) * px + (toward[1] - hand[1]) * py < 0:
        px, py = -px, -py                  # the thumb side faces `toward`
    ang = math.atan2(uy, ux)
    palm = (hand[0] + ux * 0.22 * R, hand[1] + uy * 0.22 * R)

    def at(o, along, across):
        return (o[0] + ux * along * R + px * across * R, o[1] + uy * along * R + py * across * R)

    def finger_poly(base, a, length, w0, w1, bend):
        # A tapered finger with a round tip, bending at the middle knuckle.
        pts_l, pts_r = [], []
        x, y = base
        seg = 8
        for i in range(seg + 1):
            t = i / seg
            aa = a + bend * max(0.0, t - 0.4) * 1.6
            w = (w0 + (w1 - w0) * t) * R
            nx, ny = -math.sin(aa), math.cos(aa)
            pts_l.append((x + nx * w, y + ny * w))
            pts_r.append((x - nx * w, y - ny * w))
            if i < seg:
                x += math.cos(aa) * length * R / seg
                y += math.sin(aa) * length * R / seg
        tip = []
        aa = a + bend * 0.96
        for i in range(1, 9):
            q = math.pi * i / 9
            tip.append((x + (-math.sin(aa) * math.cos(q) + math.cos(aa) * math.sin(q)) * w1 * R,
                        y + (math.cos(aa) * math.cos(q) + math.sin(aa) * math.sin(q)) * w1 * R))
        return pts_l + tip + pts_r[::-1]

    # Which way "across" turns for the finger fan (the thumb is on +p).
    fan = 1.0 if (px * math.cos(ang + 1.0) + py * math.sin(ang + 1.0)) > 0 else -1.0
    shapes = []
    valleys = []
    fingers = ((-0.34, 0.4), (0.0, 0.46), (0.33, 0.4))  # (spread, length) away from the thumb
    for k, (spread, length) in enumerate(fingers):
        a = ang - spread * fan * 0.9 - 0.15 * fan
        base = at(palm, 0.12, -0.02 - spread * 0.32)
        shapes.append(finger_poly(base, a, length * (1.0 - 0.35 * curl), 0.105, 0.088, curl * 1.4 * fan))
        if k < 2:
            valleys.append(at(palm, 0.24, -0.02 - (spread + 0.17) * 0.32))
    thumb_base = at(palm, -0.02, 0.17)
    thumb_a = ang + fan * 1.05
    shapes.append(finger_poly(thumb_base, thumb_a, 0.26, 0.1, 0.082, -0.5 * fan))
    palm_pts = ell_pts(palm[0], palm[1], (0.3 if flat else 0.27) * R, 0.25 * R, ang)

    def draw_all(d, k):
        d.polygon([(x * k, y * k) for x, y in palm_pts], fill=255)
        for poly in shapes:
            d.polygon([(x * k, y * k) for x, y in poly], fill=255)
    m = mask(draw_all)
    # Inflate it: the height grows with the distance to the edge, so the
    # whole glove reads as one stuffed shape, with soft valleys between
    # the fingers.
    inside = m > 0.5
    dist = distance_transform_edt(inside)
    puff = (0.07 if flat else 0.1) * R
    hgt = np.sqrt(np.clip(dist / puff, 0, 1)) * puff
    gy_, gx_ = np.gradient(gaussian_filter(hgt, 1.0))
    nz = np.ones_like(hgt)
    nl = np.sqrt(gx_ ** 2 + gy_ ** 2 + nz ** 2)
    t, _ = shade((gx_ / nl, gy_ / nl, nz / nl), light, rim=0.25)
    edge = np.clip(maximum_filter(m, 3) - m, 0, 1)
    paint(c, edge, GLOVE * 0.22, alpha=alpha)
    paint(c, m, GLOVE, t, texture=FELT, tex_amt=0.1, alpha=alpha)
    # Creases between the fingers, and the three sewn lines on the back.
    lines = []
    for v in valleys:
        lines.append(((v[0] - ux * 0.13 * R, v[1] - uy * 0.13 * R), v, 0.022))
    for off in (-0.08, 0.0, 0.08):
        lines.append((at(palm, -0.08, off), at(palm, 0.08, off), 0.016))
    for a0, a1, wd in lines:
        lm = mask(lambda d, k, a0=a0, a1=a1, wd=wd: d.line([(a0[0] * k, a0[1] * k), (a1[0] * k, a1[1] * k)], fill=255, width=max(1, int(wd * R * k))))
        paint(c, lm * m, GLOVE * 0.45)
    # The rolled cuff: a band across the wrist, round like a tube.
    cuff = at(hand, -0.02, 0.0)
    cm = ellipse_mask(cuff[0], cuff[1], 0.12 * R, 0.29 * R, ang)
    paint(c, np.clip(maximum_filter(cm, 3) - cm, 0, 1), GLOVE * 0.2, alpha=alpha)
    tc, _ = shade(capsule_normal(at(cuff, 0, -0.29), at(cuff, 0, 0.29), 0.12 * R), light, rim=0.2)
    paint(c, cm, GLOVE * 0.9, tc, texture=FELT, tex_amt=0.12, alpha=alpha)
    rim_line = mask(lambda d, k: d.line([(at(cuff, 0.06, -0.26)[0] * k, at(cuff, 0.06, -0.26)[1] * k),
                                         (at(cuff, 0.06, 0.26)[0] * k, at(cuff, 0.06, 0.26)[1] * k)], fill=255, width=max(1, int(0.014 * R * k))))
    paint(c, rim_line * cm, GLOVE * 0.55)


def mascot(c, cx, cy, s, pose, light: Light, pupils=(0.0, 0.0, 0.0, 0.0), dark_eyes=False,
           alpha=None, head_only=False, body=True, cracked=False, eye_in_mouth=False, tilt=0.0, torn=False,
           gloves=True, only_gloves=False):
    """Vecinito: a costume, lit like one. s = head radius in pixels.
    pupils: (lx, ly, rx, ry) offsets of the loose googly pupils, in eye radii."""
    R = s
    fur_t = FUR_TEX * 0.6 + CLUMPS * 0.5
    if body and not head_only and not only_gloves:
        # The costume neck gap: a dark ring, and in it, skin.
        gap = ellipse_mask(cx, cy + 0.86 * R, 0.5 * R, 0.16 * R)
        paint(c, gap, (0.03, 0.02, 0.02), alpha=alpha)
        paint(c, ellipse_mask(cx + 0.06 * R, cy + 0.88 * R, 0.16 * R, 0.05 * R) * gap, SKIN * 0.6)
        bc = (cx, cy + 1.3 * R)
        m = furry(ellipse_mask(bc[0], bc[1], 0.98 * R, 1.12 * R))
        t, _ = shade(sphere_normal(bc[0], bc[1], 0.98 * R, 1.12 * R), light)
        paint(c, m, FUR, t * (1.0 - 0.35 * STAINS), texture=fur_t, tex_amt=0.35, alpha=alpha)
        # Belly patch.
        m = ellipse_mask(cx, cy + 1.42 * R, 0.55 * R, 0.62 * R)
        paint(c, m, FUR_LIGHT, t, texture=FELT, tex_amt=0.2, alpha=alpha)

    # Arms and gloves by pose.
    sh_l, sh_r = (cx - 0.82 * R, cy + 0.8 * R), (cx + 0.82 * R, cy + 0.8 * R)
    if pose in ("cover", "part"):
        # The cuffs low on the cheeks: the gloves reach up over the eyes.
        spread = 0.0 if pose == "cover" else 0.3 * R
        hands = [(cx - 0.42 * R - spread, cy + 0.12 * R), (cx + 0.42 * R + spread, cy + 0.12 * R)]
    elif pose == "open":
        hands = [(cx - 1.32 * R, cy - 0.35 * R), (cx + 1.32 * R, cy - 0.35 * R)]
    elif pose == "down":
        hands = [(cx - 1.05 * R, cy + 1.75 * R), (cx + 1.05 * R, cy + 1.75 * R)]
    elif pose == "peek":
        hands = [(cx - 0.95 * R, cy + 0.2 * R), None]
    elif pose == "over":  # hiding behind the sofa, gripping the backrest
        hands = [(cx - 0.78 * R, SOFA_TOP + 0.06 * R), (cx + 0.78 * R, SOFA_TOP + 0.06 * R)]
    else:
        hands = [None, None]
    over_face = pose in ("cover", "part")

    def arm(sh, hand):
        m = furry(capsule_mask(sh, hand, 0.27 * R))
        t, _ = shade(capsule_normal(sh, hand, 0.27 * R), light)
        paint(c, m, FUR * 0.95, t * (1.0 - 0.35 * STAINS), texture=fur_t, tex_amt=0.35, alpha=alpha)

    def glove(hand, wrist_from, toward, curl=0.0):
        draw_glove(c, hand, wrist_from, toward, R, light, alpha, curl)

    if only_gloves:
        for n, hand in enumerate(hands):
            if hand is not None:
                # Gripping an edge: the fingers hang down over it.
                glove(hand, (hand[0] + (0.15 * R if n == 0 else -0.15 * R), hand[1] - 0.5 * R), (cx, hand[1]), curl=0.6)
        return
    if not head_only:
        for sh, hand in zip((sh_l, sh_r), hands):
            if hand is not None and not over_face:
                arm(sh, hand)
        if body:
            # Felt bow tie.
            by = cy + 0.86 * R
            for sgn in (-1, 1):
                wing = poly_mask([(cx, by), (cx + sgn * 0.42 * R, by - 0.2 * R), (cx + sgn * 0.42 * R, by + 0.2 * R)])
                paint(c, wing, BOW, studio_falloff(cx, by, R, 0.6) * light.key, texture=FELT, tex_amt=0.3, alpha=alpha)
            paint(c, ellipse_mask(cx, by, 0.1 * R, 0.1 * R), BOW * 0.8, texture=FELT, tex_amt=0.3, alpha=alpha)

    if tilt != 0.0:
        layer = np.zeros_like(c)
        a = np.zeros((H0, W0), np.float32)
        _head(layer, cx, cy, R, light, pupils, dark_eyes, a, cracked, eye_in_mouth, torn)
        rgba = np.dstack([np.clip(layer, 0, 1.5) / 1.5, a])
        im = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").rotate(tilt, center=(cx, cy + 0.8 * R), resample=Image.BICUBIC)
        h = np.asarray(im, np.float32) / 255.0
        c[:] = c * (1 - h[..., 3:]) + h[..., :3] * 1.5 * h[..., 3:]
        if alpha is not None:
            np.maximum(alpha, h[..., 3], out=alpha)
    else:
        _head(c, cx, cy, R, light, pupils, dark_eyes, alpha, cracked, eye_in_mouth, torn)
    if not head_only:
        if over_face:
            for sh, hand in zip((sh_l, sh_r), hands):
                elbow = _cover_elbow(sh, hand, cx, R)
                for a, b, r in ((sh, elbow, 0.27 * R), (elbow, hand, 0.21 * R)):
                    m = furry(capsule_mask(a, b, r))
                    t, _ = shade(capsule_normal(a, b, r), light)
                    paint(c, m, FUR * 0.95, t * (1.0 - 0.35 * STAINS), texture=FUR_TEX * 0.6 + CLUMPS * 0.5, tex_amt=0.35, alpha=alpha)
        for n, (sh, hand) in enumerate(zip((sh_l, sh_r), hands)):
            if hand is None or not gloves:
                continue
            # Where the forearm comes from: the elbow when the hands cover
            # the face, the shoulder otherwise.
            frm = sh
            if over_face:
                frm = _cover_elbow(sh, hand, cx, R)
            glove(hand, frm, (cx, hand[1]))


def _cover_elbow(sh, hand, cx, R):
    """Hands over the eyes: the elbow out to the side and low, so the
    forearm (and the glove after it) points up, a little inwards."""
    side = 1 if hand[0] > cx else -1
    return (hand[0] + side * 0.22 * R, hand[1] + 0.62 * R)


def _head(c, cx, cy, R, light, pupils, dark_eyes, alpha, cracked, eye_in_mouth, torn=False):
    fur_t = FUR_TEX * 0.6 + CLUMPS * 0.5
    # Head, ears.
    for sgn in (-1, 1):
        ex, ey = cx + sgn * 0.78 * R, cy - 0.74 * R
        m = furry(ellipse_mask(ex, ey, 0.34 * R, 0.32 * R))
        t, _ = shade(sphere_normal(ex, ey, 0.34 * R, 0.32 * R), light)
        paint(c, m, FUR, t * (1.0 - 0.35 * STAINS), texture=fur_t, tex_amt=0.35, alpha=alpha)
        m = ellipse_mask(ex, ey + 0.02 * R, 0.18 * R, 0.17 * R)
        paint(c, m, EAR_IN, t * 0.9, texture=FELT, tex_amt=0.2, alpha=alpha)
    # A little lopsided, as a worn costume head is.
    m = furry(poly_mask(ell_pts(cx, cy, R, 0.93 * R, 0.06)))
    t, _ = shade(sphere_normal(cx, cy, R, 0.93 * R), light)
    paint(c, m, FUR, t, texture=fur_t, tex_amt=0.38, alpha=alpha)
    # Muzzle, a lighter felt oval.
    mz = (cx + 0.03 * R, cy + 0.38 * R)
    m = ellipse_mask(mz[0], mz[1], 0.5 * R, 0.37 * R, 0.08)
    t, _ = shade(sphere_normal(mz[0], mz[1], 0.5 * R, 0.37 * R), light)
    paint(c, m, FUR_LIGHT, t, texture=FELT, tex_amt=0.25, alpha=alpha)
    # The mouth: a stitched smile... or a mesh slit with someone inside.
    if torn:
        rip = poly_mask([(cx - 0.32 * R + 0.64 * R * i / 12, cy + 0.44 * R + math.sin(math.pi * i / 12) * 0.16 * R
                          + (0.05 * R if i % 2 else -0.04 * R)) for i in range(13)]
                        + [(cx + 0.3 * R - 0.6 * R * i / 12, cy + 0.5 * R + math.sin(math.pi * i / 12) * 0.05 * R) for i in range(13)])
        paint(c, rip, (0.03, 0.01, 0.01), alpha=alpha)
        for k in range(9):  # teeth, human, too many
            tx = cx - 0.24 * R + k * 0.06 * R
            tooth = poly_mask([(tx, cy + 0.5 * R), (tx + 0.045 * R, cy + 0.5 * R), (tx + 0.04 * R, cy + 0.58 * R), (tx + 0.006 * R, cy + 0.58 * R)])
            paint(c, tooth * rip, (0.78, 0.72, 0.52))
    elif eye_in_mouth:
        slit = ellipse_mask(cx, cy + 0.5 * R, 0.36 * R, 0.13 * R)
        paint(c, slit, (0.02, 0.015, 0.012), alpha=alpha)
        # Skin, close behind the fabric, and an eye.
        skin = ellipse_mask(cx + 0.03 * R, cy + 0.5 * R, 0.3 * R, 0.11 * R) * slit
        paint(c, skin, SKIN * 0.7, studio_falloff(cx + 0.03 * R, cy + 0.5 * R, 0.12 * R, 0.15), texture=FELT, tex_amt=0.2)
        human_eye(c, cx + 0.05 * R, cy + 0.5 * R, 0.085 * R, slit)
        step = max(3, int(R * 0.018))
        mesh = (((XX % step) < 1) | ((YY % step) < 1)).astype(np.float32) * slit * 0.55
        paint(c, mesh, (0.04, 0.03, 0.02))
    else:
        pts = [(cx - 0.3 * R + 0.6 * R * i / 20, cy + 0.42 * R + math.sin(math.pi * i / 20) * 0.13 * R) for i in range(21)]
        line = mask(lambda d, k: d.line([(x * k, y * k) for x, y in pts], fill=255, width=max(2, int(0.035 * R * k))))
        paint(c, line, (0.12, 0.05, 0.04), alpha=alpha)
        for i in range(2, 20, 3):  # stitches across the thread
            x, y = pts[i]
            st = mask(lambda d, k, x=x, y=y: d.line([(x * k, (y - 0.05 * R) * k), (x * k, (y + 0.05 * R) * k)], fill=255, width=max(1, int(0.02 * R * k))))
            paint(c, st, (0.12, 0.05, 0.04), alpha=alpha)
    # Plastic nose.
    nz = (cx, cy + 0.2 * R)
    m = ellipse_mask(nz[0], nz[1], 0.16 * R, 0.11 * R)
    t, sp = shade(sphere_normal(nz[0], nz[1], 0.16 * R, 0.11 * R), light, gloss=1.4)
    paint(c, m, (0.05, 0.04, 0.04), t, sp, alpha=alpha)
    # Googly eyes.
    for i, sgn in enumerate((-1, 1)):
        ex, ey, er = cx + sgn * 0.35 * R, cy - 0.12 * R + (0.02 * R if sgn > 0 else 0.0), 0.21 * R
        m = ellipse_mask(ex, ey, er, er)
        t, sp = shade(sphere_normal(ex, ey, er, er), light, gloss=1.8, rim=0.05)
        if torn and sgn == 1:
            hole = furry(ellipse_mask(ex, ey, er * 1.1, er), 2.0)
            paint(c, hole, (0.02, 0.01, 0.01), alpha=alpha)
            continue
        if dark_eyes:
            paint(c, m, (0.02, 0.02, 0.02), t, sp, alpha=alpha)
        else:
            paint(c, m, (0.86, 0.83, 0.7), t, sp * 0.6, texture=GRIME, tex_amt=0.15, alpha=alpha)
            px = ex + pupils[i * 2] * er * 0.5
            py = ey + pupils[i * 2 + 1] * er * 0.5
            pm = ellipse_mask(px, py, 0.4 * er, 0.4 * er) * m
            paint(c, pm, (0.03, 0.03, 0.03), alpha=alpha)
            # The dome's highlight sits on top of the pupil.
            hl = ellipse_mask(ex - 0.35 * er, ey - 0.4 * er, 0.16 * er, 0.12 * er) * m
            paint(c, hl, (1.0, 1.0, 1.0))
        if cracked and sgn == 1:
            crack = mask(lambda d, k: d.line([((ex - er * 0.7) * k, (ey - er * 0.2) * k), ((ex + er * 0.1) * k, (ey + er * 0.1) * k),
                                               ((ex + er * 0.6) * k, (ey + er * 0.7) * k)], fill=255, width=2 * k))
            paint(c, crack * m, (0.1, 0.1, 0.1))


def human_eye(c, cx, cy, r, clip):
    """A real eye, wet, looking out through the costume's mouth."""
    sclera = ellipse_mask(cx, cy, r * 1.9, r * 0.8) * clip
    paint(c, sclera, (0.78, 0.72, 0.62), studio_falloff(cx, cy, r * 1.6, 0.4))
    veins = mask(lambda d, k: [d.line([((cx - r * 1.8 + RNG.uniform(0, r * 0.5)) * k, (cy + RNG.uniform(-r * 0.5, r * 0.5)) * k),
                                        ((cx - r * 0.7) * k, (cy + RNG.uniform(-r * 0.3, r * 0.3)) * k)], fill=255, width=1) for _ in range(4)])
    paint(c, veins * sclera, (0.6, 0.12, 0.1))
    iris = ellipse_mask(cx, cy, r * 0.62, r * 0.62) * clip
    rr = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2) / (r * 0.62)
    iris_col = np.stack([0.32 - 0.12 * rr, 0.22 - 0.1 * rr, 0.12 - 0.05 * rr], -1)
    c[:] = c * (1 - iris[..., None]) + np.clip(iris_col, 0, 1) * iris[..., None]
    paint(c, ellipse_mask(cx, cy, r * 0.27, r * 0.27) * clip, (0.01, 0.01, 0.01))
    paint(c, ellipse_mask(cx - r * 0.25, cy - r * 0.25, r * 0.12, r * 0.09) * clip, (1.0, 1.0, 0.96))


# --- recording ---------------------------------------------------------------------------

def tape(c: np.ndarray, seed: int, grade="warm", noise=0.04, zoom=1.0, center=(320, 240)) -> Image.Image:
    """The picture through a studio camera and a worn VHS tape."""
    rng = np.random.default_rng(seed)
    img = np.clip(c, 0, 1.4)
    if zoom != 1.0:
        im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        w, h = W0 / zoom, H0 / zoom
        box = (center[0] - w / 2, center[1] - h / 2, center[0] + w / 2, center[1] + h / 2)
        img = np.asarray(im.resize((W0, H0), Image.BICUBIC, box=box), np.float32) / 255.0
    img = gaussian_filter(img, (1.1, 1.3, 0))
    # Bloom on the brights.
    bright = np.clip(img - 0.75, 0, 1)
    img = img + gaussian_filter(bright, (8, 8, 0)) * 0.6
    img = np.asarray(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).resize((W, H), Image.BOX), np.float32) / 255.0
    # YIQ: luma sharp-ish, chroma smeared sideways and late.
    y = img @ np.array([0.299, 0.587, 0.114])
    i = img @ np.array([0.596, -0.274, -0.322])
    q = img @ np.array([0.211, -0.523, 0.312])
    i = nd_shift(gaussian_filter(i, (0.6, 3.0)), (0, 2.0), mode="nearest")
    q = nd_shift(gaussian_filter(q, (0.6, 3.5)), (0, 2.5), mode="nearest")
    if grade == "warm":
        i *= 0.85
        q *= 0.7
        y = 0.06 + np.clip(y, 0, 1) ** 0.9 * 0.92
    elif grade == "cold":
        i *= 0.35
        q *= 0.35
        y = 0.03 + y * 0.95
    elif grade == "grey":
        i *= 0.08
        q *= 0.08
    y = y + gaussian_filter(rng.standard_normal((H, W)), (0.4, 0.9)) * noise
    # Vignette of the studio lens.
    yy, xx = np.mgrid[0:H, 0:W]
    y *= 1.0 - 0.35 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) * 0.6
    rgb = np.stack([y + 0.956 * i + 0.621 * q, y - 0.272 * i - 0.647 * q, y - 1.106 * i + 1.703 * q], -1)
    # Head-switching noise in the bottom lines.
    for row in range(H - 6, H):
        k = (row - (H - 6)) + 1
        rgb[row] = np.roll(rgb[row], int(k * 2 + rng.integers(0, 3)), axis=0)
        rgb[row] += rng.standard_normal((W, 1)) * 0.05 * k
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))


def kid_text(c, text, cx, cy, size, colours, seed=0, max_width=240):
    """Crayon letters on a card: wobbly, each letter its own colour, never
    wider than `max_width`."""
    rng = np.random.default_rng(seed)
    im = Image.new("L", (W0 * SS, H0 * SS), 0)
    d = ImageDraw.Draw(im)
    while True:
        font = ImageFont.truetype(FONT_KID, size * SS)
        total = d.textlength(text, font=font)
        if total <= max_width * SS or size <= 20:
            break
        size -= 4
    x = cx * SS - total / 2
    letters = []
    for ch in text:
        w = d.textlength(ch, font=font)
        letters.append((ch, x))
        x += w
    for n, (ch, lx) in enumerate(letters):
        im_l = Image.new("L", (W0 * SS, H0 * SS), 0)
        dl = ImageDraw.Draw(im_l)
        jy = rng.uniform(-size * 0.08, size * 0.08) * SS
        dl.text((lx, cy * SS - size * SS * 0.6 + jy), ch, font=font, fill=255)
        im_l = im_l.rotate(rng.uniform(-8, 8), center=(lx + 10, cy * SS))
        m = np.asarray(im_l.resize((W0, H0), Image.BOX), np.float32) / 255.0
        m *= 0.75 + 0.25 * (FELT > rng.uniform(-0.5, 0.2))  # crayon grain
        paint(c, m, colours[n % len(colours)])


CRAYON = [(0.85, 0.15, 0.12), (0.12, 0.35, 0.8), (0.1, 0.6, 0.2), (0.95, 0.6, 0.05), (0.55, 0.2, 0.65)]
NUMBERS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]


def card_frame(text: str, seed: int) -> np.ndarray:
    c = room_set()
    light = Light()
    # The host counting at the side, eyes covered.
    mascot(c, 535, 250, 86, "cover", light)
    # A cardboard card on an easel.
    paint(c, poly_mask([(196, 420), (206, 420), (236, 300), (228, 300)]), (0.3, 0.2, 0.12))
    paint(c, poly_mask([(394, 420), (384, 420), (354, 300), (362, 300)]), (0.3, 0.2, 0.12))
    card = poly_mask([(150, 92), (442, 98), (438, 322), (154, 318)])
    paint(c, card, (0.9, 0.85, 0.72), studio_falloff(296, 210, 200, 0.75), texture=FELT, tex_amt=0.08)
    words = text.split(" ")
    if len(words) == 1:
        kid_text(c, text, 296, 205, 150, CRAYON, seed, max_width=236)
    else:  # one word per line, big, as a child would letter it
        for n, w in enumerate(words):
            kid_text(c, w, 296, 165 + n * 88, 96, CRAYON[n * 2:] + CRAYON, seed + n, max_width=236)
    return c


# --- frames ---------------------------------------------------------------------------------

def frame(name: str) -> Image.Image:
    light = Light()
    seed = FRAMES.index(name)
    look_off = (0.25, 0.35, 0.45, 0.2)  # googly pupils, loose, not quite at you
    if name in ("cover_a", "cover_b"):
        c = room_set()
        mascot(c, 320 + (4 if name == "cover_b" else -4), 236, 112, "cover", light)
        return tape(c, seed)
    if name == "part":
        c = room_set()
        mascot(c, 320, 236, 112, "part", light, look_off)
        return tape(c, seed)
    if name in ("open_a", "open_b"):
        c = room_set()
        sway = 5 if name == "open_b" else -5
        mascot(c, 320 + sway, 232, 112, "open", light, (0.3, 0.3, 0.5, 0.25) if name == "open_a" else (0.2, 0.4, 0.4, 0.3))
        return tape(c, seed)
    if name == "lean":
        c = room_set()
        mascot(c, 320, 250, 112, "open", light, (0.1, 0.15, 0.15, 0.1))
        return tape(c, seed, zoom=1.35, center=(320, 215))
    if name.startswith("static"):
        rng = np.random.default_rng(seed)
        n = rng.random((H, W))
        n = gaussian_filter(n, (0.3, 1.2))
        roll = ((np.arange(H)[:, None] + (40 if name == "static_b" else 0)) % H) / H
        n = n * (0.6 + 0.4 * np.sin(roll * math.pi * 2) ** 2)
        g = (np.clip((n - n.min()) / (n.max() - n.min()), 0, 1) * 255).astype(np.uint8)
        return Image.fromarray(np.stack([g, g, g], -1))
    if name.startswith("count_"):
        n = int(name.split("_")[1])
        return tape(card_frame(NUMBERS[n - 1], n), seed)
    if name == "ready":
        return tape(card_frame("¡ALLÁ VOY!", 11), seed)
    if name in ("seek_a", "seek_b"):
        c = room_set(sofa=False)
        look_left = name == "seek_a"
        hx = 300 if look_left else 334
        pupils = (-0.7, 0.15, -0.6, 0.15) if look_left else (0.7, 0.1, 0.75, 0.15)
        mascot(c, hx, 196, 96, "over", light, pupils, gloves=False, tilt=0.0 if look_left else -7.0)
        c = draw_sofa(c)
        mascot(c, hx, 196, 96, "over", light, only_gloves=True)
        return tape(c, seed)
    if name == "stare":
        # Stopped. Hands down. Both pupils dead centre: at you.
        cold = Light((0.1, -0.2, 0.95), 0.8, 0.2, (0.85, 0.9, 1.0))
        c = room_set()
        c *= 0.55
        mascot(c, 320, 240, 112, "down", cold, (0.0, 0.0, 0.0, 0.0), tilt=-14.0)
        return tape(c, seed, grade="cold", zoom=1.55, center=(320, 228))
    if name == "stare_dark":
        under = Light((0.0, 0.85, 0.5), 1.0, 0.04, (1.0, 0.8, 0.7))
        c = room_set(dark=True)
        mascot(c, 320, 240, 112, "down", under, dark_eyes=True, tilt=-22.0)
        return tape(c, seed, grade="grey", noise=0.06, zoom=1.8, center=(320, 220))
    if name == "close":
        c = np.zeros((H0, W0, 3), np.float32)
        key = Light((-0.3, -0.4, 0.85), 0.9, 0.18)
        mascot(c, 320, 40, 560, "none", key, eye_in_mouth=True, head_only=True)
        return tape(c, seed, grade="warm", noise=0.05)
    if name == "empty":
        c = room_set(tilt=0.02)
        # Nobody. Only the gloves, left on the sofa.
        lying = Light((-0.3, -0.7, 0.65), 0.75, 0.3)
        for gx, gy, a in ((250, 318, 0.4), (380, 322, -0.6)):
            wrist = (gx - math.cos(a) * 60, gy - math.sin(a) * 30)
            draw_glove(c, (gx, gy), wrist, (gx, gy - 40), 100, lying, curl=0.35, flat=True)
        return tape(c, seed, grade="warm", noise=0.04)
    if name.startswith("intrude"):
        k = "abcd".index(name[-1])
        c = np.zeros((H0, W0, 3), np.float32)
        # Corrugated metal, turning: the bands of light slide across.
        phase = k * 0.9
        band = 0.5 + 0.5 * np.sin(XX / 640 * 26 * math.pi + phase + 3 * np.sin(XX / 300 + phase))
        c[:] = (0.12 + 0.35 * band ** 3)[..., None] * np.array([0.85, 0.88, 0.92])
        c *= (1.0 - 0.3 * np.clip(GRIME, 0, 1))[..., None]
        head = np.zeros_like(c)
        alpha = np.zeros((H0, W0), np.float32)
        harsh = Light((0.6, -0.3, 0.75), 1.15, 0.08, (1.0, 0.95, 0.9))
        mascot(head, 320, 250, 150, "none", harsh, (-0.7, 0.5, 0.8, -0.6), alpha=alpha, head_only=True, torn=True)
        # Dark streaks under the eyes.
        for sgn in (-1, 1):
            streak = capsule_mask((320 + sgn * 55, 255), (320 + sgn * 58, 330), 5) * alpha
            paint(head, streak, (0.12, 0.06, 0.04))
        ang = (-7, 4, 9, -2)[k]
        rgba = np.dstack([np.clip(head, 0, 1), alpha])
        im = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").rotate(ang, center=(320, 260), resample=Image.BICUBIC)
        h = np.asarray(im, np.float32) / 255.0
        c = c * (1 - h[..., 3:]) + h[..., :3] * h[..., 3:]
        return tape(c, seed, grade="cold", noise=0.08)
    if name == "bars":
        c = np.zeros((H0, W0, 3), np.float32)
        cols = [(0.75, 0.75, 0.75), (0.75, 0.75, 0), (0, 0.75, 0.75), (0, 0.75, 0), (0.75, 0, 0.75), (0.75, 0, 0), (0, 0, 0.75)]
        bw = W0 / 7
        for n, col in enumerate(cols):
            c[:320, int(n * bw):int((n + 1) * bw)] = col
            c[320:360, int(n * bw):int((n + 1) * bw)] = cols[6 - n] if n % 2 == 0 else (0.05, 0.05, 0.05)
        c[360:, :] = 0.06
        c[360:, :int(bw * 1.2)] = (0, 0.13, 0.3)
        c[360:, int(bw * 1.2):int(bw * 2.4)] = 0.9
        c[360:, int(bw * 2.4):int(bw * 3.6)] = (0.2, 0, 0.42)
        img = Image.fromarray((c * 255).astype(np.uint8))
        d = ImageDraw.Draw(img)
        font = ImageFont.truetype(FONT_TV, 64)
        d.rectangle([220, 130, 420, 196], fill=(10, 10, 10))
        d.text((320, 162), "CANAL 9", font=font, fill=(235, 235, 230), anchor="mm")
        return tape(np.asarray(img, np.float32) / 255.0, seed, grade="warm", noise=0.02)
    raise ValueError(name)


def seal(corrupt: bool) -> Image.Image:
    """Civil-protection seal: the international sign (a blue triangle in an
    orange disc) inside a ring. Corrupted: the triangle has a face."""
    S2 = 4
    n = 96 * S2
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([4 * S2, 4 * S2, n - 4 * S2, n - 4 * S2], fill=(235, 232, 220, 255))
    d.ellipse([9 * S2, 9 * S2, n - 9 * S2, n - 9 * S2], fill=(232, 112, 20, 255) if not corrupt else (150, 20, 18, 255))
    tri = [(n / 2, 20 * S2), (n - 22 * S2, n - 28 * S2), (22 * S2, n - 28 * S2)]
    d.polygon(tri, fill=(20, 52, 150, 255) if not corrupt else (20, 12, 12, 255))
    if corrupt:
        for sgn in (-1, 1):
            ex, ey, er = n / 2 + sgn * 9 * S2, n * 0.56, 6 * S2
            d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(240, 236, 225, 255))
            d.ellipse([n / 2 - 2.5 * S2 + sgn * 6 * S2, ey - 2.5 * S2, n / 2 + 2.5 * S2 + sgn * 6 * S2, ey + 2.5 * S2], fill=(0, 0, 0, 255))
        d.arc([n / 2 - 12 * S2, n * 0.6, n / 2 + 12 * S2, n * 0.72], 10, 170, fill=(240, 236, 225, 255), width=2 * S2)
    return im.resize((96, 96), Image.LANCZOS)


## The one frame with words on it (a child's card), per language; the game
## loads tv_show.<lang>.png instead of tv_show.png in that language
## (project.godot, internationalization/locale/translation_remaps).
READY_TEXT = {"en": "HERE I COME!"}


def localized() -> None:
    """tv_show.<lang>.png for each language in READY_TEXT: tv_show.png with
    its card redrawn (run after the full sheet, or alone with --localized)."""
    sheet = Image.open(OUT).convert("RGB")
    k = FRAMES.index("ready")
    for lang, text in READY_TEXT.items():
        out = sheet.copy()
        out.paste(tape(card_frame(text, 11), k), (k * W, 0))
        path = OUT.with_name("tv_show.%s.png" % lang)
        out.save(path)
        print(path.name)


def main() -> None:
    if "--localized" in sys.argv:
        localized()
        return
    sheet = Image.new("RGB", (W * len(FRAMES), H))
    for n, name in enumerate(FRAMES):
        sheet.paste(frame(name), (n * W, 0))
        print("  frame", n, name)
    sheet.save(OUT)
    seals = Image.new("RGBA", (192, 96), (0, 0, 0, 0))
    seals.paste(seal(False), (0, 0))
    seals.paste(seal(True), (96, 0))
    seals.save(SEAL_OUT)
    print("tv_show.png: %d frames" % len(FRAMES))
    localized()
    if len(sys.argv) > 1 and sys.argv[1] != "--localized":
        cols = 6
        rows = (len(FRAMES) + cols - 1) // cols
        prev = Image.new("RGB", (W * cols, H * rows))
        for n in range(len(FRAMES)):
            prev.paste(sheet.crop((n * W, 0, (n + 1) * W, H)), ((n % cols) * W, (n // cols) * H))
        prev.save(sys.argv[1])


if __name__ == "__main__":
    main()
