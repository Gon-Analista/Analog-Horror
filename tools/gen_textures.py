"""Generates the house's pixel-art textures (64 px per metre) into
game/assets/textures. Deterministic (same seed, same output): they exist to
find the art style and will be replaced by hand-made art once it is set.

    python tools/gen_textures.py              (all)
    python tools/gen_textures.py books ...    (only these, of the later ones)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import zoom

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures"
rng = np.random.default_rng(1989)


def save(name: str, arr: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray((np.clip(arr, 0.0, 1.0) * 255).astype(np.uint8))
    img.save(OUT / f"{name}.png")
    print("  ", name, img.size)


def grid(h: int, w: int):
    y, x = np.mgrid[0:h, 0:w]
    return y.astype(float), x.astype(float)


def seamless(h: int, w: int, octaves: int = 4, max_freq: int = 4) -> np.ndarray:
    """Tileable blotchy noise in [0, 1] (sum of integer-frequency waves)."""
    y, x = grid(h, w)
    v = np.zeros((h, w))
    for _ in range(octaves):
        fx, fy = rng.integers(1, max_freq + 1, 2)
        ph = rng.random() * np.pi * 2
        v += np.sin(2 * np.pi * (fx * x / w + fy * y / h) + ph) / (fx + fy)
    v -= v.min()
    return v / max(v.max(), 1e-6)


def grain(h: int, w: int, amount: float) -> np.ndarray:
    return (rng.random((h, w)) - 0.5) * amount


def rgb(c, h: int, w: int) -> np.ndarray:
    return np.ones((h, w, 3)) * np.array(c, dtype=float)


def posterize(arr: np.ndarray, levels: int = 14) -> np.ndarray:
    return np.round(np.clip(arr, 0, 1) * (levels - 1)) / (levels - 1)


def shade(arr: np.ndarray, m: np.ndarray) -> np.ndarray:
    return arr * m[..., None]


# 64 px per metre (was 32): the game now renders at 960x540, so the house
# carries twice the detail. Every surface tiles seamlessly.
K = 2            # detail factor over the original 32 px/m layouts
PPM = 32 * K     # pixels per metre


def fbm(h: int, w: int, cells: int = 4, octaves: int = 4, gain: float = 0.5) -> np.ndarray:
    """Tileable fractal value noise in [0, 1]: random lattices, smoothly
    interpolated with wrap-around, octave over octave."""
    v = np.zeros((h, w))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gy = max(1, int(cells * h / max(h, w)) * (2 ** o))
        gx = max(1, int(cells * w / max(h, w)) * (2 ** o))
        lattice = rng.random((gy, gx))
        v += amp * zoom(lattice, (h / gy, w / gx), order=3, mode="grid-wrap")[:h, :w]
        total += amp
        amp *= gain
    v /= total
    v -= v.min()
    return v / max(v.max(), 1e-6)


def wrap_d(a: np.ndarray, c: float, n: int) -> np.ndarray:
    """Distance along a wrapping axis of length n."""
    return np.abs(((a - c + n / 2) % n) - n / 2)


def aged_wall(img: np.ndarray, skirting: bool = True) -> np.ndarray:
    """Shared ageing for 2.6 m tall wall textures: blotches, water streaks
    running down from the ceiling (with a darker tide line), peeling patches
    showing the plaster, hairline cracks, damp at the bottom, soot at the
    top, scuffs, and a skirting board with its own grain and dents."""
    h, w = img.shape[:2]
    y, x = grid(h, w)
    img = shade(img, 0.78 + 0.3 * fbm(h, w, 3, 5))
    img = shade(img, 0.94 + 0.08 * fbm(h, w, 12, 2))  # fine mottling
    for _ in range(max(1, w // (13 * K))):  # water streaks, wavering, fading
        sx = rng.integers(0, w)
        length = rng.integers(20 * K, 66 * K)
        width = rng.uniform(0.8, 2.6) * K
        wobble = np.sin(y / (6 * K) + rng.random() * 6) * K
        dist = wrap_d(x + wobble, sx, w)
        fade = np.clip(1 - y / length, 0, 1)
        streak = np.clip(1 - dist / width, 0, 1) * fade
        img = img * (1 - streak[..., None] * 0.3) + np.array([0.28, 0.22, 0.12]) * streak[..., None] * 0.3
        tide = (np.abs(y - length * 0.98) < K * 0.8) & (dist < width * 1.3)
        img[tide] *= 0.78
    for _ in range(max(1, w // (26 * K))):  # peeling: the plaster shows through
        cx, cy = rng.integers(0, w), rng.integers(8 * K, 70 * K)
        r = rng.uniform(3, 7) * K
        n = fbm(h, w, 10, 2) * r * 0.5
        d = np.hypot(wrap_d(x, cx, w), (y - cy) * 1.3) + n
        patch = d < r
        plaster = np.array([0.55, 0.52, 0.44]) * (0.85 + 0.15 * fbm(h, w, 16, 1)[patch])[..., None]
        img[patch] = img[patch] * 0.45 + plaster * 0.55
        img[(d >= r) & (d < r + 1.0 * K)] *= 0.8
        img[(d >= r + 1.0 * K) & (d < r + 1.8 * K)] *= 1.06  # the lifted edge catches light
    for _ in range(rng.integers(0, 2)):  # hairline cracks
        px, py = float(rng.integers(0, w)), float(rng.integers(10 * K, 60 * K))
        ang = rng.uniform(0.9, 2.2)
        for _ in range(rng.integers(30, 70) * K):
            ix, iy = int(px) % w, int(py)
            if 0 <= iy < h:
                img[iy, ix] *= 0.8
            ang += rng.normal(0, 0.35)
            px += np.cos(ang) * 0.8
            py += np.sin(ang) * 0.8
    damp = np.clip((y - 60 * K + 8 * K * fbm(h, w, 4, 3)) / (18 * K), 0, 1)
    img = img * (1 - damp[..., None] * 0.5) + np.array([0.20, 0.17, 0.10]) * damp[..., None] * 0.5
    img = shade(img, 1.0 - np.clip((16 * K - y) / (16 * K), 0, 1) * 0.4 * (0.7 + 0.6 * fbm(h, w, 4, 2)))
    for _ in range(rng.integers(3, 7)):  # scuffs at hand and hip height
        cx, cy = rng.integers(0, w), rng.integers(40 * K, 74 * K)
        scuff = (wrap_d(x, cx, w) < rng.uniform(2, 6) * K) & (np.abs(y - cy) < rng.uniform(0.5, 1.5) * K)
        img[scuff] *= 0.9
    img += grain(h, w, 0.045)[..., None]
    if skirting:
        top = 78 * K
        board = rgb((0.20, 0.13, 0.08), h - top, w)
        by, bx = grid(h - top, w)
        board = shade(board, 0.85 + 0.2 * np.sin(bx * 0.35 / K + np.sin(by * 0.9) * 1.5) * 0.5 + 0.1 * fbm(h - top, w, 6, 3))
        img[top:, :] = board + grain(h - top, w, 0.035)[..., None]
        img[top:top + K, :] = [0.34, 0.23, 0.14]  # the lit top edge
        img[h - K:, :] *= 0.55
        for _ in range(rng.integers(2, 5)):  # dents
            dx = rng.integers(0, w)
            img[top + rng.integers(K, 4 * K), dx:dx + rng.integers(K, 3 * K)] *= 0.6
    return img


def wallpaper(base=(0.34, 0.40, 0.31), motif=(0.56, 0.50, 0.30), kind: str = "damask") -> np.ndarray:
    """2 m wide x 2.6 m tall at 64 px/m."""
    h, w = 84 * K, 64 * K
    y, x = grid(h, w)
    img = rgb(base, h, w)
    if kind == "damask":  # stripes + an ornate lozenge with a fleur, staggered
        img = shade(img, 1.0 + 0.06 * ((x // (4 * K)) % 2))
        col = (x // (16 * K)).astype(int)
        my = (y + (col % 2) * 8 * K) % (16 * K) - 8 * K
        mx = x % (16 * K) - 8 * K
        dx, dy = np.abs(mx), np.abs(my)
        s = dx + dy
        ring = (s <= 4.5 * K) & (s >= 3.2 * K)
        cross = ((dx < 0.6 * K) & (dy <= 6.5 * K)) | ((dy < 0.6 * K) & (dx <= 5.5 * K))
        petals = np.hypot(dx - 2.2 * K, dy - 2.2 * K) < 1.1 * K
        dot = np.hypot(dx, dy) < 1.0 * K
        orn = ring | cross | petals | dot
        img[orn] = img[orn] * 0.42 + np.array(motif) * 0.58
        hi = np.roll(orn, -1, axis=0) & ~orn  # a printed edge, offset a touch
        img[hi] *= 0.86
    elif kind == "stars":  # a child's room: stars (five points), a cloud band, a moon now and then
        for _ in range(48):
            cx, cy = rng.integers(0, w), rng.integers(0, 76 * K)
            dxs, dys = wrap_d(x, cx, w), y - cy
            r = np.hypot(dxs, dys)
            a = np.arctan2(dys, dxs)
            size = rng.uniform(1.3, 2.4) * K
            star = r < size * (0.55 + 0.45 * np.cos(5 * a) ** 2)
            img[star] = np.array(motif) * (0.9 + 0.2 * rng.random())
        band = (y > 50 * K) & (y < 56 * K)
        cloud = band | ((np.abs(y - 50 * K) < 2.5 * K) & (np.sin(x / (3 * K)) > 0.2))
        img[cloud] = img[cloud] * 0.55 + np.array([0.80, 0.78, 0.76]) * 0.45
        for _ in range(2):
            cx, cy = rng.integers(0, w), rng.integers(10 * K, 40 * K)
            moon = (np.hypot(wrap_d(x, cx, w), y - cy) < 3 * K) & ~(np.hypot(wrap_d(x, cx + 1.4 * K, w), y - cy + 0.6 * K) < 2.6 * K)
            img[moon] = [0.88, 0.82, 0.55]
    elif kind == "stripes":  # bedroom: wide faded stripes with a pinstripe and a printed texture
        img = shade(img, np.where((x // (8 * K)) % 2 == 0, 1.0, 0.82))
        img = shade(img, 0.96 + 0.06 * (np.sin(y * 1.3) * np.sin(x * 0.9) > 0.3))
        pin = (x % (16 * K)) == 4 * K
        img[pin] = img[pin] * 0.5 + np.array(motif) * 0.5
    return posterize(aged_wall(img), 20)


def window() -> np.ndarray:
    """1 m wide x 2.6 m tall wall face with a window: dark night glass with a
    reflection, a cross frame, torn curtains in folds, a sill. Wall around it."""
    h, w = 84 * K, 32 * K
    y, x = grid(h, w)
    img = aged_wall(rgb((0.50, 0.46, 0.38), h, w))
    glass = (x >= 6 * K) & (x < 26 * K) & (y >= 22 * K) & (y < 54 * K)
    sky = np.array([0.06, 0.08, 0.14]) + 0.05 * (1 - (y - 22 * K) / (32 * K))[..., None]
    img[glass] = sky[glass]
    img[glass & (rng.random((h, w)) < 0.006)] = [0.5, 0.55, 0.7]  # far lights
    streak = glass & (np.abs((x - 8 * K) - (y - 24 * K) * 0.5) < 1.2 * K)  # a pale reflection
    img[streak] = img[streak] * 0.7 + 0.3 * np.array([0.35, 0.38, 0.45])
    grime = glass & (fbm(h, w, 8, 3) > 0.62)
    img[grime] = img[grime] * 0.8 + 0.2 * np.array([0.3, 0.28, 0.22])
    frame = glass & (((x >= 15 * K) & (x < 17 * K)) | ((y >= 37 * K) & (y < 39 * K)))
    img[frame] = [0.38, 0.33, 0.26]
    border = ((x >= 4 * K) & (x < 28 * K) & (y >= 20 * K) & (y < 56 * K)) & ~glass
    img[border] = np.array([0.42, 0.37, 0.29]) * (0.9 + 0.15 * fbm(h, w, 10, 2)[border])[..., None]
    img[(y >= 56 * K) & (y < 58 * K) & (x >= 3 * K) & (x < 29 * K)] = [0.46, 0.40, 0.31]
    img[(y == 58 * K) & (x >= 3 * K) & (x < 29 * K)] *= 0.5  # the sill's shadow
    for cx0, cx1 in ((3 * K, 9 * K), (23 * K, 29 * K)):  # curtains in folds, torn at the bottom
        hem = 60 * K + ((x // K) % 3) * 2 * K - ((x // K) % 5) * K
        cur = (x >= cx0) & (x < cx1) & (y >= 16 * K) & (y < hem)
        fold = 0.7 + 0.3 * np.sin(x[cur] * 1.7 / K)
        img[cur] = np.array([0.36, 0.16, 0.14]) * fold[..., None] * (0.92 + 0.12 * fbm(h, w, 12, 2)[cur])[..., None]
    img[14 * K:16 * K, 2 * K:30 * K] = [0.25, 0.20, 0.15]  # rail
    img[14 * K, 2 * K:30 * K] = [0.36, 0.30, 0.22]
    return posterize(img, 20)


def wall_tile() -> np.ndarray:
    """Kitchen / bathroom: white tiles up to 1.3 m (bevelled, a few cracked,
    dirty grout), yellowed paint above."""
    h, w = 84 * K, 64 * K
    y, x = grid(h, w)
    img = rgb((0.62, 0.57, 0.40), h, w)
    img = shade(img, 0.8 + 0.25 * fbm(h, w, 3, 5))
    tiles = y >= 42 * K
    t = rgb((0.78, 0.78, 0.72), h, w)
    t = shade(t, 0.92 + 0.1 * fbm(h, w, 6, 3))
    tx, ty = x % (8 * K), (y - 42 * K) % (8 * K)
    t = shade(t, 1.0 + 0.08 * (tx < K) + 0.08 * (ty < K) - 0.1 * (tx >= 7 * K - 1) - 0.1 * (ty >= 7 * K - 1))  # bevel
    cell = (x // (8 * K)) * 31 + ((y - 42 * K) // (8 * K)) * 17
    t = shade(t, 0.96 + 0.06 * np.sin(cell * 12.9898) )  # each tile its own shade
    grout = (tx < 1) | (ty < 1)
    t[grout] = np.array([0.42, 0.42, 0.38]) * (0.75 + 0.3 * fbm(h, w, 16, 2)[grout])[..., None]
    for _ in range(3):  # cracked tiles
        px, py = float(rng.integers(0, w)), float(rng.integers(44 * K, 82 * K))
        ang = rng.uniform(0, 6.28)
        for _ in range(10 * K):
            ix, iy = int(px) % w, int(py)
            if 42 * K <= iy < h:
                t[iy, ix] = [0.45, 0.45, 0.42]
            ang += rng.normal(0, 0.4)
            px += np.cos(ang)
            py += np.sin(ang)
    img[tiles] = t[tiles]
    img[41 * K:43 * K, :] = [0.30, 0.42, 0.38]  # trim row
    img[41 * K, :] = [0.40, 0.52, 0.47]
    grime = np.clip((y - 70 * K) / (14 * K), 0, 1) * 0.3 * (0.6 + 0.8 * fbm(h, w, 6, 3))
    img = shade(img, 1 - grime)
    img = shade(img, 1.0 - np.clip((14 * K - y) / (14 * K), 0, 1) * 0.3)
    img += grain(h, w, 0.035)[..., None]
    return posterize(img, 20)


def floor_wood() -> np.ndarray:
    """1 m of floorboards: four planks with their own grain, knots, worn
    paths, dark gaps and nail heads."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = np.zeros((h, w, 3))
    plank = 8 * K
    warp = fbm(h, w, 6, 3)
    for p in range(4):
        base = np.array([0.36, 0.23, 0.13]) * (0.82 + 0.3 * rng.random())
        rows = slice(p * plank, (p + 1) * plank)
        ph = rng.random() * 6
        grain_lines = np.sin((y[rows] - p * plank) * 1.4 / K + warp[rows] * 9 + ph + x[rows] * 0.02)
        fine = np.sin((y[rows] - p * plank) * 3.1 / K + warp[rows] * 14 + ph * 2)
        g = 0.88 + 0.1 * grain_lines + 0.06 * (fine > 0.6) + 0.04 * np.sin(x[rows] * 0.7 / K + ph)
        img[rows] = base * g[..., None]
        for _ in range(rng.integers(0, 2)):  # a knot
            kx, ky = rng.integers(0, w), p * plank + rng.integers(2 * K, 6 * K)
            kd = np.hypot(wrap_d(x[rows], kx, w) * 0.6, y[rows] - ky)
            img[rows][...] = img[rows] * (1 - 0.35 * np.clip(1 - kd / (2.2 * K), 0, 1))[..., None]
        joint = rng.integers(0, w)
        img[rows, joint:joint + max(1, K // 2)] *= 0.5
        for nx in (joint + 2 * K, joint - 2 * K):  # nail heads by the joint
            for ny in (p * plank + 2 * K, p * plank + 6 * K):
                img[ny % h, nx % w] = [0.18, 0.17, 0.16]
    img[(y % plank) >= plank - K] *= 0.42  # the gaps
    img[(y % plank) == 0] *= 1.12
    wear = fbm(h, w, 3, 3)
    img = shade(img, 0.82 + 0.24 * wear)
    img += grain(h, w, 0.03)[..., None]
    return posterize(img, 20)


def floor_tile() -> np.ndarray:
    """Checkered lino tiles, 0.5 m: worn in the middle, chipped corners,
    grime in the joints."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    s = 16 * K
    checker = ((x // s) + (y // s)) % 2 == 0
    img = np.where(checker[..., None], np.array([0.70, 0.66, 0.55]), np.array([0.38, 0.42, 0.38]))
    img = shade(img, 0.9 + 0.12 * fbm(h, w, 10, 2))
    tx, ty = x % s, y % s
    img = shade(img, 1.0 + 0.06 * ((tx < K) | (ty < K)) - 0.08 * ((tx >= s - K) | (ty >= s - K)))
    grout = (tx < 1) | (ty < 1)
    img[grout] = np.array([0.25, 0.24, 0.22]) * (0.8 + 0.3 * fbm(h, w, 16, 1)[grout])[..., None]
    pits = rng.random((h, w)) > 0.995
    img[pits] *= 0.6  # little chips and pits
    img = shade(img, 0.8 + 0.25 * fbm(h, w, 3, 4))
    img += grain(h, w, 0.04)[..., None]
    return posterize(img, 20)


def ceiling() -> np.ndarray:
    """Plaster ceiling: a fine stipple, water stains with rings, a crack."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.50, 0.48, 0.45), h, w)
    img = shade(img, 0.85 + 0.2 * fbm(h, w, 3, 4))
    img = shade(img, 0.95 + 0.08 * fbm(h, w, 24, 1))  # stipple
    stain = fbm(h, w, 2, 4)
    ring = (np.abs(stain - 0.72) < 0.012)
    img = img * (1 - np.clip((stain - 0.7) * 3, 0, 0.3))[..., None] + np.array([0.3, 0.24, 0.12]) * np.clip((stain - 0.7) * 3, 0, 0.3)[..., None]
    img[ring] *= 0.8
    img += grain(h, w, 0.06)[..., None]
    return posterize(img, 16)


def small(base, pattern: str) -> np.ndarray:
    """Furniture and clothes: 1 m of material at 64 px per metre."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb(base, h, w)
    if pattern == "grain":
        img = shade(img, 0.85 + 0.15 * np.sin(y * 1.1 / K + np.sin(x * 0.2 / K) * 0.8 + fbm(h, w, 4, 2) * 2.5))
    elif pattern == "checks":
        img = shade(img, np.where(((x // (4 * K)) + (y // (4 * K))) % 2 == 0, 1.0, 0.8))
        img = shade(img, 0.94 + 0.08 * ((x + y) % 2))  # the weave
    elif pattern == "cord":  # worn corduroy upholstery: soft ribs, rubbed shiny in places, stains
        img = shade(img, 0.86 + 0.14 * (0.5 + 0.5 * np.sin(x * np.pi / (1.5 * K))))
        img = shade(img, 0.9 + 0.12 * fbm(h, w, 5, 3))
        rub = fbm(h, w, 2, 3)
        img = img * (1 + np.clip(rub - 0.6, 0, 1)[..., None] * 0.5)
        stain = fbm(h, w, 3, 4) > 0.78
        img[stain] *= 0.78
    elif pattern == "stripes":
        img = shade(img, np.where((x // (3 * K)) % 2 == 0, 1.0, 0.85))
        img = shade(img, 0.95 + 0.07 * ((y // K) % 2))
    elif pattern == "speckle":
        img = shade(img, 1.0 - (rng.random((h, w)) > 0.9) * 0.22)
    img = shade(img, 0.9 + 0.15 * fbm(h, w, 3, 2))
    img += grain(h, w, 0.04)[..., None]
    return posterize(img, 20)


def door_exit() -> np.ndarray:
    """The front door: two raised panels with mouldings, a small window onto
    the night, a brass knob and keyhole, scratches at the bottom."""
    h, w = 84 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.30, 0.19, 0.11), h, w)
    img = shade(img, 0.9 + 0.08 * np.sin(y * 0.3 / K + x * 0.05 + fbm(h, w, 4, 3) * 6))
    for (y0, y1) in ((8 * K, 30 * K), (36 * K, 74 * K)):
        panel = (y >= y0) & (y <= y1) & (x >= 5 * K) & (x <= 26 * K)
        img[panel] *= 0.84
        img[(np.abs(y - y0) < K) & (x >= 5 * K) & (x <= 26 * K)] *= 1.35
        img[(np.abs(y - y1) < K) & (x >= 5 * K) & (x <= 26 * K)] *= 0.6
        img[(np.abs(x - 5 * K) < K) & (y >= y0) & (y <= y1)] *= 1.25
        img[(np.abs(x - 26 * K) < K) & (y >= y0) & (y <= y1)] *= 0.65
    win = (y >= 12 * K) & (y < 22 * K) & (x >= 10 * K) & (x < 22 * K)
    img[win] = np.array([0.18, 0.22, 0.29]) * (0.85 + 0.2 * fbm(h, w, 6, 2)[win])[..., None]
    img[(y >= 16 * K) & (y < 17 * K) & (x >= 10 * K) & (x < 22 * K)] = [0.25, 0.17, 0.10]
    knob = np.hypot(x - 26.5 * K, y - 49.5 * K) < 1.8 * K
    img[knob] = [0.65, 0.55, 0.25]
    img[np.hypot(x - 26 * K, y - 49 * K) < 0.7 * K] = [0.85, 0.78, 0.45]
    img[(np.abs(x - 26.5 * K) < 0.5 * K) & (y >= 53 * K) & (y < 55 * K)] = [0.08, 0.06, 0.05]
    for _ in range(14):  # scratches near the floor
        sx, sy = rng.integers(4 * K, 28 * K), rng.integers(74 * K, 83 * K)
        img[sy, sx:sx + rng.integers(2, 4 * K)] *= 1.3
    img[:, :2 * K] = [0.16, 0.10, 0.06]
    img[:, -2 * K:] = [0.16, 0.10, 0.06]
    img += grain(h, w, 0.035)[..., None]
    return posterize(img, 20)


def cardboard() -> np.ndarray:
    h, w = 16 * K, 16 * K
    y, x = grid(h, w)
    img = rgb((0.52, 0.40, 0.25), h, w)
    img = shade(img, 0.9 + 0.1 * np.sin(y * 2.2 / K))
    img = shade(img, 0.88 + 0.18 * fbm(h, w, 4, 3))
    img[7 * K:9 * K, :] = [0.62, 0.55, 0.40]  # packing tape
    img[7 * K, :] *= 1.1
    img += grain(h, w, 0.04)[..., None]
    return posterize(img, 20)


def rug() -> np.ndarray:
    """A worn Persian-ish rug: diamonds, a border, threadbare patches."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.40, 0.10, 0.08), h, w)
    d = np.abs(x - 16 * K) + np.abs(y - 16 * K)
    img[(d % (8 * K)) < 2 * K] = [0.62, 0.45, 0.22]
    img[((d % (8 * K)) >= 3 * K) & ((d % (8 * K)) < 3.6 * K)] = [0.18, 0.22, 0.35]
    img[((x % (16 * K)) < 2 * K) | ((y % (16 * K)) < 2 * K)] = [0.15, 0.10, 0.12]
    img = shade(img, 0.92 + 0.1 * ((x + y) % 2))  # the pile
    bare = fbm(h, w, 3, 4)
    img = img * (1 - np.clip((bare - 0.6) * 2, 0, 0.5))[..., None] + np.array([0.45, 0.38, 0.30]) * np.clip((bare - 0.6) * 2, 0, 0.5)[..., None]
    img = shade(img, 0.78 + 0.28 * fbm(h, w, 4, 2))
    img += grain(h, w, 0.05)[..., None]
    return posterize(img, 20)


def paper() -> np.ndarray:
    h, w = 16 * K, 16 * K
    img = rgb((0.72, 0.70, 0.62), h, w)
    for yy in range(3 * K, 14 * K, 2 * K):
        img[yy, 2 * K:2 * K + rng.integers(6 * K, 13 * K)] = [0.35, 0.33, 0.35]
    img = shade(img, 0.85 + 0.15 * fbm(h, w, 2, 3))
    return posterize(img, 20)


def tape_label() -> np.ndarray:
    h, w = 16, 32
    im = Image.new("RGB", (w, h), (214, 208, 188))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, h - 1), outline=(150, 40, 40))
    for row, y in enumerate((4, 8, 11)):
        pts = [(3 + i * 2, y + int(rng.integers(-1, 2))) for i in range(13 - row * 3)]
        d.line(pts, fill=(170, 30, 30))
    return np.array(im).astype(float) / 255


def flashlight_cookie() -> np.ndarray:
    s = 64
    y, x = grid(s, s)
    r = np.hypot(x - s / 2 + 0.5, y - s / 2 + 0.5) / (s / 2)
    v = np.clip(1.0 - r, 0, 1) ** 0.6
    v += 0.12 * np.exp(-((r - 0.62) / 0.08) ** 2)          # reflector ring
    v *= 0.88 + 0.12 * seamless(s, s, 4, 3)                # dirty lens
    v *= np.clip((0.95 - r) / 0.2, 0, 1)                   # soft edge, no hard rim
    v = np.clip(v, 0, 1)
    return np.stack([v, v, v], axis=-1)


def photos() -> np.ndarray:
    """2x2 atlas of family photos. The faces have been scratched out."""
    s = 32
    im = Image.new("RGB", (s * 2, s * 2))
    d = ImageDraw.Draw(im)
    for i in range(4):
        ox, oy = (i % 2) * s, (i // 2) * s
        d.rectangle((ox, oy, ox + s - 1, oy + s - 1), fill=(118, 98, 72))
        d.rectangle((ox + 3, oy + 3, ox + s - 4, oy + s - 4), fill=(60 + i * 8, 70, 80 - i * 6))
        people = 1 + i % 3
        for k in range(people):
            px = ox + 8 + k * (18 // people) + (6 if people == 1 else 0)
            d.rectangle((px - 3, oy + 16, px + 3, oy + 28), fill=(40, 34, 30))
            d.ellipse((px - 3, oy + 9, px + 3, oy + 16), fill=(170, 140, 115))
            for _ in range(5):  # scratches over the face
                x0, y0 = px + int(rng.integers(-4, 4)), oy + 8 + int(rng.integers(0, 3))
                d.line((x0, y0, x0 + int(rng.integers(-4, 5)), y0 + int(rng.integers(5, 9))), fill=(200, 196, 180))
    a = np.array(im).astype(float) / 255
    return posterize(a + grain(s * 2, s * 2, 0.04)[..., None])


def drawing(scribbled: bool) -> np.ndarray:
    """A child's crayon drawing of Vecinito, the show's friendly bear. One
    copy has been scribbled over in black."""
    w, h = 32, 40
    im = Image.new("RGB", (w * 4, h * 4), (222, 216, 196))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w * 4 - 1, h * 4 - 1), outline=(160, 150, 130), width=3)
    d.ellipse((24, 20, 48, 44), outline=(210, 160, 30), width=6)        # ears
    d.ellipse((80, 20, 104, 44), outline=(210, 160, 30), width=6)
    d.ellipse((30, 30, 98, 96), outline=(210, 160, 30), width=6)        # head
    d.ellipse((48, 50, 58, 62), fill=(30, 30, 30))                        # eyes
    d.ellipse((70, 50, 80, 62), fill=(30, 30, 30))
    d.arc((46, 56, 82, 86), 20, 160, fill=(200, 40, 40), width=5)       # smile
    d.line((64, 96, 64, 140), fill=(210, 160, 30), width=6)             # body
    d.line((64, 110, 34, 96), fill=(210, 160, 30), width=5)
    d.line((64, 110, 96, 92), fill=(210, 160, 30), width=5)
    d.line((14, 150, 114, 150), fill=(60, 150, 60), width=6)            # grass
    if scribbled:
        for _ in range(60):
            x0, y0 = int(rng.integers(20, 108)), int(rng.integers(20, 110))
            d.line((x0, y0, x0 + int(rng.integers(-30, 30)), y0 + int(rng.integers(-30, 30))), fill=(15, 12, 12), width=4)
    small_im = im.resize((w * K, h * K), Image.BOX)
    return posterize(np.array(small_im).astype(float) / 255, 12)


def window_cookie() -> np.ndarray:
    """Moonlight through a window with a cross frame (spot light projector)."""
    s = 64
    y, x = grid(s, s)
    v = np.ones((s, s)) * 0.9
    v[(np.abs(x - 32) < 3) | (np.abs(y - 32) < 3)] = 0.0
    edge = np.minimum(np.minimum(x, s - 1 - x), np.minimum(y, s - 1 - y))
    v *= np.clip(edge / 8, 0, 1)
    v *= 0.85 + 0.15 * seamless(s, s, 3, 3)
    return np.stack([v, v, v], axis=-1)


def jacket() -> np.ndarray:
    """Work jacket of the recovery crew, light grey so each player's colour
    can tint it, with a reflective band and seams."""
    h, w = 32, 32
    y, x = grid(h, w)
    img = rgb((0.78, 0.78, 0.76), h, w)
    img = shade(img, 0.9 + 0.1 * np.sin(x * 2.1 + y * 0.7))
    img[(y >= 18) & (y < 21)] = [0.95, 0.95, 0.85]       # reflective band
    img[(y == 17) | (y == 21)] = [0.45, 0.45, 0.44]
    img[:, 15:17] *= 0.75                                # zip
    img = shade(img, 0.85 + 0.2 * seamless(h, w, 3, 2))
    img += grain(h, w, 0.04)[..., None]
    return posterize(img)


def camcorder_tex() -> np.ndarray:
    """1989 VHS camcorder plastic: dark grey, panel lines, a few labels."""
    h, w = 32, 32
    y, x = grid(h, w)
    img = rgb((0.17, 0.17, 0.18), h, w)
    img[(y % 8) == 0] *= 0.6
    img[4:7, 4:16] = [0.55, 0.55, 0.55]                  # "VHS" label
    img[4:7, 18:22] = [0.75, 0.15, 0.12]                 # red stripe
    img[22:26, 20:28] = [0.10, 0.10, 0.11]               # tape door
    img += grain(h, w, 0.04)[..., None]
    return posterize(img)


def books() -> np.ndarray:
    """1 m of a bookcase's rows at 64 x 96 px (three rows of a third of a
    metre, 32 px each): spines standing on the shelf in faded cloth colours,
    a band or a title block on some, a gap, one leaning on its neighbour."""
    h, w = 96, 64
    img = rgb((0.05, 0.04, 0.035), h, w)  # the dark at the back of the shelf
    palette = np.array([(0.42, 0.12, 0.10), (0.16, 0.28, 0.20), (0.15, 0.20, 0.34), (0.40, 0.30, 0.16),
                        (0.55, 0.47, 0.30), (0.30, 0.16, 0.22), (0.62, 0.58, 0.48), (0.22, 0.20, 0.18)])
    for row in range(3):
        bottom = (row + 1) * 32 - 1
        x = 0
        while x < w:
            bw = int(rng.integers(2, 6))
            if x + bw > w:
                bw = w - x
            if rng.random() < 0.06 and x + bw < w - 2:  # a gap
                x += bw
                continue
            bh = int(rng.integers(17, 29))
            col = palette[rng.integers(0, len(palette))] * rng.uniform(0.75, 1.1)
            top = bottom - bh
            img[top:bottom + 1, x:x + bw] = col
            img[top:bottom + 1, x] *= 0.7  # the shadow between spines
            if bw >= 3 and rng.random() < 0.5:  # a gilt band, or a title block
                by = top + int(rng.integers(3, 8))
                img[by:by + 1, x + 1:x + bw] = (0.70, 0.58, 0.30)
            if bw >= 4 and rng.random() < 0.3:
                ty = top + bh // 2 - 2
                img[ty:ty + 4, x + 1:x + bw - 1] = (0.78, 0.74, 0.62)
            img[top, x:x + bw] *= 1.25  # dust on the tops
            x += bw
    img = shade(img, 0.88 + 0.16 * fbm(h, w, 3, 2))
    img += grain(h, w, 0.03)[..., None]
    return posterize(img, 20)


def enamel() -> np.ndarray:
    """White enamel gone yellow: smooth, grime gathered in soft patches, a
    few chips."""
    h, w = 32 * K, 32 * K
    img = rgb((0.80, 0.78, 0.70), h, w)
    img = shade(img, 0.94 + 0.06 * fbm(h, w, 2, 2))
    grime = fbm(h, w, 3, 4)
    img = shade(img, 1.0 - np.clip(grime - 0.6, 0, 1) * 0.7)
    chips = rng.random((h, w)) > 0.9985
    img[chips] = (0.2, 0.2, 0.22)
    img += grain(h, w, 0.015)[..., None]
    return posterize(img, 24)


def dressform() -> np.ndarray:
    """A dress form's cover: worn cream linen, a faint weave, yellowed
    stains and pin marks."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.66, 0.60, 0.50), h, w)
    img = shade(img, 0.95 + 0.05 * ((x + y) % 2))
    stain = fbm(h, w, 3, 3)
    img = shade(img, 1.0 - np.clip(stain - 0.62, 0, 1) * 0.9)
    pins = rng.random((h, w)) > 0.997
    img[pins] = (0.25, 0.24, 0.22)
    img += grain(h, w, 0.025)[..., None]
    return posterize(img, 20)


def plush() -> np.ndarray:
    """The bear's mustard fur: short tufts, matted and greyed where it was
    held."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.70, 0.52, 0.16), h, w)
    img = shade(img, 0.82 + 0.25 * (rng.random((h, w)) > 0.5) * (0.5 + 0.5 * np.sin(x * 2.1 + y * 1.3)))
    matted = fbm(h, w, 3, 3)
    img = img * (1 - np.clip(matted - 0.6, 0, 1)[..., None] * 1.2) + np.clip(matted - 0.6, 0, 1)[..., None] * 0.25
    img += grain(h, w, 0.05)[..., None]
    return posterize(img, 18)


# Textures added later: each from its own seed, so generating only them
# (python tools/gen_textures.py books enamel ...) gives the same result as
# a full run and the older ones never change.
LATER = {
    "books": books,
    "enamel": enamel,
    "plush": plush,
    "dressform": dressform,
    "wallpaper_study": lambda: wallpaper((0.17, 0.25, 0.21), (0.52, 0.44, 0.25), "stripes"),
}


def later(names) -> None:
    global rng
    for i, name in enumerate(LATER):
        if names and name not in names:
            continue
        rng = np.random.default_rng(7000 + i)
        save(name, LATER[name]())


def main() -> None:
    import sys
    if len(sys.argv) > 1:
        later(sys.argv[1:])
        return
    print("textures ->", OUT)
    save("wallpaper", wallpaper())
    save("wallpaper_kid", wallpaper((0.42, 0.50, 0.58), (0.80, 0.72, 0.35), "stars"))
    save("wallpaper_bed", wallpaper((0.42, 0.24, 0.22), (0.62, 0.52, 0.36), "stripes"))
    save("window", window())
    save("cardboard", cardboard())
    save("rug", rug())
    save("paper", paper())
    save("wood_trim", small((0.40, 0.27, 0.16), "grain"))
    save("photos", photos())
    save("drawing", drawing(False))
    save("drawing_scribbled", drawing(True))
    save("window_cookie", window_cookie())
    save("jacket", jacket())
    save("jeans", small((0.20, 0.25, 0.38), "stripes"))
    save("skin", small((0.72, 0.55, 0.45), "speckle"))
    save("knit", small((0.62, 0.62, 0.60), "checks"))
    save("camcorder", camcorder_tex())
    save("wall_tile", wall_tile())
    save("floor_wood", floor_wood())
    save("floor_tile", floor_tile())
    save("ceiling", ceiling())
    save("wood_dark", small((0.22, 0.14, 0.09), "grain"))
    save("sofa", small((0.42, 0.22, 0.12), "cord"))
    save("bed", small((0.38, 0.44, 0.52), "stripes"))
    save("counter", small((0.66, 0.60, 0.48), "speckle"))
    save("linen", small((0.74, 0.72, 0.66), "checks"))
    save("brass", small((0.72, 0.58, 0.28), "speckle"))
    save("plastic", small((0.09, 0.09, 0.1), "speckle"))
    save("tape_label", tape_label())
    save("door_exit", door_exit())
    save("flashlight_cookie", flashlight_cookie())
    later(None)


if __name__ == "__main__":
    main()
