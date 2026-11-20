"""Generates the Visita's soot textures into game/assets/textures
(deterministic, placeholders to find the look, like the rest of tools/gen_*):

    soot_foot.png    a print of its long, narrow foot: the sole, four long
                     toes ending in scratches, the heel dragged (decal)
    soot_hand.png    a print of its hand, bigger than its head: the palm and
                     five long jointed fingers with claw marks (decal; when it
                     goes on all fours)
    soot_scorch.png  where it came apart under the flash: a burnt splash (decal)
    soot_pool.png    the shadow it spreads on the floor under it (decal, only
                     through the camcorder)
    soot_noise.png   tileable smoke noise for its aura (entity_soot.gdshader)

    python tools/gen_soot.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures"
rng = np.random.default_rng(1983)
SOOT = np.array([0.045, 0.036, 0.032])  # not pure black: old, warm soot


def tileable_noise(n: int, falloff: float = 1.6, seed: int = 0) -> np.ndarray:
    """Tileable fractal noise in [0, 1]: white noise filtered by 1/f**falloff."""
    r = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    spec = np.fft.fft2(r.standard_normal((n, n))) / k ** falloff
    spec[0, 0] = 0.0
    v = np.real(np.fft.ifft2(spec))
    v -= v.min()
    return v / v.max()


def grid(h: int, w: int):
    y, x = np.mgrid[0:h, 0:w].astype(float)
    return y, x


def ellipse(y, x, cy, cx, ry, rx, soft=0.25):
    d = np.sqrt(((y - cy) / ry) ** 2 + ((x - cx) / rx) ** 2)
    return np.clip((1.0 - d) / soft, 0.0, 1.0)


def stroke(y, x, p0, p1, r0, r1):
    """A tapered stroke from p0 (radius r0) to p1 (radius r1), in pixels."""
    p0, p1 = np.array(p0, float), np.array(p1, float)
    d = p1 - p0
    t = np.clip(((y - p0[0]) * d[0] + (x - p0[1]) * d[1]) / max((d * d).sum(), 1e-6), 0.0, 1.0)
    py, px = p0[0] + d[0] * t, p0[1] + d[1] * t
    dist = np.sqrt((y - py) ** 2 + (x - px) ** 2)
    r = r0 + (r1 - r0) * t
    return np.clip((r - dist) / np.maximum(r * 0.45, 0.6), 0.0, 1.0)


def grain(h: int, w: int, amount: float, seed: int) -> np.ndarray:
    """Soot is never even: blotches, gaps where the floor shows through, specks."""
    n = tileable_noise(max(h, w), 1.2, seed)[:h, :w]
    fine = np.random.default_rng(seed + 7).random((h, w))
    return np.clip(0.82 + (n - 0.5) * 1.2 * amount - (fine < 0.03) * 0.25 * amount, 0.0, 1.0)


def specks(h: int, w: int, mask: np.ndarray, count: int, reach: float, seed: int) -> np.ndarray:
    """Loose soot fallen around a print."""
    r = np.random.default_rng(seed)
    out = np.zeros((h, w))
    ys, xs = np.nonzero(mask > 0.5)
    if len(ys) == 0:
        return out
    for _ in range(count):
        i = r.integers(len(ys))
        a = r.random() * np.pi * 2
        d = r.random() ** 2 * reach
        py, px = int(ys[i] + np.sin(a) * d), int(xs[i] + np.cos(a) * d)
        if 0 <= py < h and 0 <= px < w:
            out[py, px] = max(out[py, px], r.uniform(0.35, 0.9))
            if r.random() < 0.3 and px + 1 < w:
                out[py, px + 1] = max(out[py, px + 1], r.uniform(0.2, 0.6))
    return out


def with_dust(shape: np.ndarray, sigma: float, amount: float) -> np.ndarray:
    """A print is never clean: a haze of soot dust round it (reads from afar)."""
    return np.maximum(shape, np.clip(gaussian_filter(shape, sigma) * 1.6, 0.0, 1.0) * amount)


def save(name: str, alpha: np.ndarray, tint: np.ndarray | None = None) -> None:
    h, w = alpha.shape
    rgb = np.broadcast_to(SOOT, (h, w, 3)).copy() if tint is None else tint
    # Opaque where there is soot: the decal blends by alpha in linear space,
    # and a half-transparent print reads as a grey shadow, not as soot.
    img = np.dstack([rgb, np.clip(alpha * 1.3, 0.0, 1.0) ** 0.45])
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(OUT / f"{name}.png")
    print("  ", name, (w, h))


def tinted(h: int, w: int, seed: int) -> np.ndarray:
    """Soot colour with a little variation (thicker = blacker, edges browner)."""
    n = tileable_noise(max(h, w), 1.4, seed)[:h, :w, None]
    return np.clip(SOOT * (0.7 + n * 0.9), 0.0, 1.0)


def foot() -> None:
    # 96 x 144 px for 0.3 x 0.45 m; the toes point up (forward).
    h, w = 144, 96
    y, x = grid(h, w)
    cx = w * 0.5
    sole = ellipse(y, x, 86, cx, 38, 13, 0.35)          # long and narrow
    ball = ellipse(y, x, 56, cx + 2, 15, 17, 0.4)        # wider where the toes start
    heel = stroke(y, x, (112, cx - 1), (136, cx - 4), 9, 3)  # dragged back
    toes = np.zeros((h, w))
    for i, (dx, length, ang) in enumerate([(-11, 30, -0.32), (-3.5, 38, -0.1), (4, 36, 0.12), (11, 27, 0.36)]):
        p0 = (50, cx + dx)
        p1 = (50 - np.cos(ang) * length, cx + dx + np.sin(ang) * length)
        toes = np.maximum(toes, stroke(y, x, p0, p1, 6.0, 2.6))
        # the claw: a thin scratch past the tip, dragged
        tip = (p1[0] - np.cos(ang) * 9, p1[1] + np.sin(ang) * 9)
        toes = np.maximum(toes, stroke(y, x, p1, tip, 1.2, 0.5) * 0.8)
    shape = with_dust(np.maximum.reduce([sole, ball * 0.9, heel * 0.75, toes]), 6, 0.4)
    alpha = np.clip(shape * 1.3, 0, 1) * grain(h, w, 0.6, 11)
    # the middle of the sole presses harder; the edges are smeared
    alpha = np.maximum(alpha, specks(h, w, shape, 160, 16, 12) * 0.6)
    save("soot_foot", alpha, tinted(h, w, 13))


def hand() -> None:
    # 128 x 160 px for 0.5 x 0.62 m: a hand bigger than its head, fingers up.
    h, w = 160, 128
    y, x = grid(h, w)
    cx = w * 0.5
    palm = ellipse(y, x, 112, cx, 26, 22, 0.35)
    fingers = np.zeros((h, w))
    for i in range(4):
        ang = (-0.42 + i * 0.28)
        base = np.array([90.0, cx - 15 + i * 10])
        a = ang
        p = base
        for seg, length in enumerate([24, 20, 16]):
            a = a + (0.16 if ang >= 0 else -0.16) * seg + rng.uniform(-0.06, 0.06)  # the joints splay out
            q = p + np.array([-np.cos(a) * length, np.sin(a) * length])
            fingers = np.maximum(fingers, stroke(y, x, p, q, 5.5 - seg * 1.0, 4.6 - seg * 1.0))
            fingers = np.maximum(fingers, ellipse(y, x, q[0], q[1], 3.2 - seg * 0.6, 3.2 - seg * 0.6, 0.5))  # knuckle
            p = q
        claw = p + np.array([-np.cos(a) * 11, np.sin(a) * 11])
        fingers = np.maximum(fingers, stroke(y, x, p, claw, 1.3, 0.4) * 0.85)
    thumb_a = 1.15
    p = np.array([108.0, cx + 20])
    for seg, length in enumerate([18, 14]):
        q = p + np.array([-np.cos(thumb_a) * length, np.sin(thumb_a) * length])
        fingers = np.maximum(fingers, stroke(y, x, p, q, 4.0 - seg, 3.0 - seg))
        p = q
        thumb_a += 0.25
    smear = stroke(y, x, (134, cx - 4), (156, cx - 10), 14, 4) * 0.55  # dragged as it lifts
    shape = with_dust(np.maximum.reduce([palm, fingers, smear]), 7, 0.4)
    alpha = np.clip(shape * 1.3, 0, 1) * grain(h, w, 0.6, 21)
    alpha = np.maximum(alpha, specks(h, w, shape, 220, 18, 22) * 0.55)
    # mirror for the other hand is done by the decal (negative scale is
    # not allowed): Entity flips it by rotating 180 degrees and mirroring
    # the thumb side does not matter at this size.
    save("soot_hand", alpha, tinted(h, w, 23))


def scorch() -> None:
    n = 160
    y, x = grid(n, n)
    c = n * 0.5
    dy, dx = y - c, x - c
    r = np.sqrt(dx * dx + dy * dy) / c
    a = np.arctan2(dy, dx)
    # spikes thrown outwards, uneven
    rays = np.zeros(n)
    rr = np.random.default_rng(31)
    spikes = 0.45 + 0.25 * np.sin(a * 5 + 1.3) + 0.15 * np.sin(a * 11 + 0.4) + 0.1 * np.sin(a * 23 + 2.0)
    body = np.clip((spikes - r) / 0.18, 0.0, 1.0)
    streaks = np.zeros((n, n))
    for _ in range(26):
        ang = rr.random() * np.pi * 2
        l0, l1 = rr.uniform(0.25, 0.4), rr.uniform(0.6, 0.98)
        p0 = (c + np.sin(ang) * l0 * c, c + np.cos(ang) * l0 * c)
        p1 = (c + np.sin(ang) * l1 * c, c + np.cos(ang) * l1 * c)
        streaks = np.maximum(streaks, stroke(y, x, p0, p1, rr.uniform(2.5, 5.0), 0.6))
    core = np.clip((0.25 - r) / 0.2, 0.0, 1.0)
    shape = with_dust(np.maximum.reduce([body * 0.9, streaks * 0.8, core]), 9, 0.5)
    alpha = shape * grain(n, n, 1.1, 32)
    alpha = np.maximum(alpha, specks(n, n, shape, 400, 26, 33) * 0.6)
    save("soot_scorch", alpha, tinted(n, n, 34))
    del rays


def pool() -> None:
    n = 128
    y, x = grid(n, n)
    c = n * 0.5
    dy, dx = y - c, x - c
    r = np.sqrt(dx * dx + dy * dy) / c
    a = np.arctan2(dy, dx)
    noise = tileable_noise(n, 1.5, 41)
    # a dark middle that thins out in fingers of shadow reaching outwards
    reach = 0.72 + 0.07 * np.sin(a * 5 + 0.7) + 0.05 * np.sin(a * 9 + 2.1) + (noise - 0.5) * 0.3
    alpha = np.clip((reach - r) / 0.6, 0.0, 1.0) ** 1.6
    alpha *= 0.8 + (noise - 0.5) * 0.5
    save("soot_pool", np.clip(alpha, 0, 0.85), np.zeros((n, n, 3)) + SOOT * 0.6)


def smoke_noise() -> None:
    n = 128
    a = tileable_noise(n, 1.35, 51)
    b = tileable_noise(n, 1.9, 52)
    c = tileable_noise(n, 1.1, 53)
    img = np.dstack([a, b, c])
    Image.fromarray((img * 255).astype(np.uint8), "RGB").save(OUT / "soot_noise.png")
    print("   soot_noise", (n, n))


if __name__ == "__main__":
    foot()
    hand()
    scorch()
    pool()
    smoke_noise()
