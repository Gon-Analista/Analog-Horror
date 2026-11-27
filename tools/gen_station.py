"""Textures of the second night: Canal 9's studios (the station) and The
Husk (the empty Vecinito costume), in the same pixel-art style and density
as the house (128 px per metre, tools/gen_textures.py, whose helpers this
uses). Deterministic: each texture from its own seed.

    python tools/gen_station.py              (all)
    python tools/gen_station.py husk_fur ... (only these)
"""
import sys

import numpy as np

import gen_textures as gt
from gen_textures import K, fbm, grain, grid, posterize, rgb, shade, stretched_noise, wrap_d


def _rng() -> np.random.Generator:
    return gt.rng


# --- the building -------------------------------------------------------------------------

def wall_block() -> np.ndarray:
    """2 m x 2.6 m of painted concrete block, the way public buildings were
    done: gloss green to 1.1 m, a dark band, cream above; the courses of
    blocks showing through the paint, trolley scrapes at bumper height, a
    black rubber cove base at the floor, damp and nicotine near the top."""
    h, w = 84 * K, 64 * K
    y, x = grid(h, w)
    img = rgb((0.66, 0.62, 0.50), h, w)
    low = y >= 49 * K
    img[low] = (0.27, 0.38, 0.33)
    band = (y >= 47 * K) & (y < 49 * K)
    img[band] = (0.16, 0.22, 0.20)
    # The blocks: 0.4 x 0.2 m, every other course shifted half a block.
    bw, bh = int(12.8 * K), int(6.4 * K)
    row = (y // bh).astype(int)
    bx = (x + (row % 2) * bw // 2) % bw
    by = y % bh
    joint = (bx < K * 0.6) | (by < K * 0.6)
    img = shade(img, 1.0 - 0.13 * joint)
    img = shade(img, 1.0 + 0.04 * (by < 2 * K) - 0.03 * (by > bh - 2 * K))  # the paint pools in the joints
    cell = (x // bw) * 13 + row * 7
    img = shade(img, 0.97 + 0.04 * np.sin(cell * 3.7))
    img = shade(img, 0.86 + 0.2 * fbm(h, w, 3, 4))
    img = shade(img, 0.96 + 0.06 * fbm(h, w, 18, 1))  # the block's own texture through the paint
    # The gloss: a soft sheen on the green.
    img[low] *= (1.0 + 0.06 * np.clip(fbm(h, w, 2, 2)[low] - 0.4, 0, 1))[..., None]
    rng = _rng()
    for _ in range(rng.integers(4, 8)):  # trolley and chair scrapes
        cx, cy = rng.integers(0, w), rng.integers(52 * K, 60 * K)
        ln = rng.integers(4 * K, 16 * K)
        scrape = (wrap_d(x, cx + ln / 2, w) < ln / 2) & (np.abs(y - cy - (x - cx) * rng.uniform(-0.04, 0.04)) < rng.uniform(0.4, 1.0) * K)
        img[scrape] = img[scrape] * 0.55 + np.array([0.55, 0.53, 0.48]) * 0.45
    for _ in range(rng.integers(2, 4)):  # chipped paint showing the grey block
        cx, cy = rng.integers(0, w), rng.integers(10 * K, 76 * K)
        r = rng.uniform(1.0, 2.6) * K
        d = np.hypot(wrap_d(x, cx, w), y - cy) + fbm(h, w, 12, 2) * r * 0.6
        img[d < r] = (0.46, 0.46, 0.44)
        img[(d >= r) & (d < r + 0.6 * K)] *= 0.78
    stain = np.clip((14 * K - y) / (14 * K), 0, 1) * (0.5 + 0.7 * fbm(h, w, 4, 3))
    img = img * (1 - stain[..., None] * 0.35) + np.array([0.42, 0.34, 0.16]) * stain[..., None] * 0.35
    for _ in range(max(1, w // (20 * K))):  # a damp run from the ceiling
        sx = rng.integers(0, w)
        length = rng.integers(16 * K, 50 * K)
        dist = wrap_d(x + np.sin(y / (5 * K)) * K, sx, w)
        streak = np.clip(1 - dist / (1.6 * K), 0, 1) * np.clip(1 - y / length, 0, 1)
        img = img * (1 - streak[..., None] * 0.25) + np.array([0.30, 0.26, 0.14]) * streak[..., None] * 0.25
    img += grain(h, w, 0.035)[..., None]
    # The cove base: black rubber, 10 cm, scuffed grey.
    top = 81 * K
    img[top:, :] = np.array([0.07, 0.07, 0.07]) * (0.85 + 0.4 * fbm(h - top, w, 10, 2))[..., None]
    img[top:top + max(1, K // 2), :] = (0.16, 0.16, 0.15)
    return posterize(img, 22)


def wall_studio() -> np.ndarray:
    """2 m x 2.6 m of studio wall: black paint over plaster, rows of
    perforated acoustic panels from 0.6 m up, gaffer tape holding a cable
    run, scuffs from the scenery being pushed against it."""
    h, w = 84 * K, 64 * K
    y, x = grid(h, w)
    img = rgb((0.075, 0.072, 0.07), h, w)
    img = shade(img, 0.8 + 0.35 * fbm(h, w, 3, 4))
    ps = 15 * K  # panels 0.47 m square with a gap
    px, py = x % (16 * K), (y - 4 * K) % (16 * K)
    panel = (px < ps) & (py < ps) & (y >= 4 * K) & (y < 68 * K)
    holes = panel & (px % (2 * K) == K) & (py % (2 * K) == K)
    img[panel] = img[panel] * 1.35 + 0.015
    img[holes] *= 0.35
    edge = panel & ((px < K // 2 + 1) | (py < K // 2 + 1))
    img[edge] *= 1.5
    rng = _rng()
    cy = int(72 * K)
    img[cy:cy + K, :] = (0.035, 0.035, 0.035)  # a cable along the wall
    for tx in range(rng.integers(0, 8 * K), w, 22 * K):
        img[cy - K:cy + 2 * K, tx:tx + 2 * K] = (0.17, 0.17, 0.16)  # gaffer tape over it
    for _ in range(rng.integers(5, 9)):  # scuffs where the flats were pushed
        sx, sy = rng.integers(0, w), rng.integers(60 * K, 82 * K)
        img[sy:sy + rng.integers(1, K + 1), sx:sx + rng.integers(2 * K, 9 * K)] *= 2.2
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 24)


def floor_lino() -> np.ndarray:
    """1 m of vinyl tiles (VCT), 0.25 m squares in two greys and a beige,
    speckled through, wax built up yellow at the edges, black heel marks."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    s = 8 * K
    rng = _rng()
    tones = [np.array([0.62, 0.60, 0.54]), np.array([0.55, 0.54, 0.50]), np.array([0.66, 0.60, 0.48])]
    img = np.zeros((h, w, 3))
    for ty in range(4):
        for tx in range(4):
            img[ty * s:(ty + 1) * s, tx * s:(tx + 1) * s] = tones[(tx + ty * 2 + int(rng.integers(0, 2))) % 3]
    fleck = rng.random((h, w))
    img[fleck > 0.93] *= 0.72
    img[fleck < 0.03] *= 1.18
    tx, ty = x % s, y % s
    joint = (tx < 1) | (ty < 1)
    img[joint] *= 0.62
    wax = np.clip(1 - np.minimum(np.minimum(tx, s - tx), np.minimum(ty, s - ty)) / (1.5 * K), 0, 1)
    img = img * (1 - wax[..., None] * 0.18) + np.array([0.52, 0.44, 0.24]) * wax[..., None] * 0.18
    img = shade(img, 0.82 + 0.24 * fbm(h, w, 3, 4))
    for _ in range(rng.integers(5, 10)):  # heel marks
        cx, cy = rng.integers(0, w), rng.integers(0, h)
        a = rng.uniform(0, np.pi)
        ln = rng.uniform(1.0, 3.5) * K
        d = np.abs((wrap_d(x, cx, w)) * np.sin(a) - (wrap_d(y, cy, h)) * np.cos(a))
        along = np.hypot(wrap_d(x, cx, w), wrap_d(y, cy, h))
        mark = (d < 0.5 * K) & (along < ln)
        img[mark] *= 0.45
    img += grain(h, w, 0.03)[..., None]
    return posterize(img, 22)


def floor_studio() -> np.ndarray:
    """1 m of studio floor: black-painted concrete gone grey where the
    pedestals rolled, a cable track, a coloured spike mark now and then."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.10, 0.10, 0.10), h, w)
    worn = fbm(h, w, 2, 4)
    img = img * (1 + np.clip(worn - 0.45, 0, 1)[..., None] * 1.6)
    img = shade(img, 0.88 + 0.2 * fbm(h, w, 14, 2))
    rng = _rng()
    for _ in range(3):  # wheel tracks of the camera pedestals
        cy = rng.integers(0, h)
        track = wrap_d(y + np.sin(x / (7 * K)) * 2 * K, cy, h) < 0.6 * K
        img[track] *= 1.35
    cx, cy = rng.integers(4 * K, w - 4 * K), rng.integers(4 * K, h - 4 * K)
    col = [(0.75, 0.62, 0.12), (0.18, 0.45, 0.70), (0.70, 0.20, 0.18)][int(rng.integers(0, 3))]
    img[cy:cy + K, cx - 2 * K:cx + 2 * K] = col  # a spike mark: a T of tape
    img[cy:cy + 3 * K, cx - K // 2:cx + K // 2 + 1] = col
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 20)


def carpet() -> np.ndarray:
    """Office carpet tiles: grey-blue loop pile, the seams, a coffee stain,
    a path worn pale from the door."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.26, 0.29, 0.34), h, w)
    img = shade(img, 0.82 + 0.3 * (rng.random((h, w)) > 0.5) * (0.5 + 0.5 * np.sin(x * 1.7 + y * 2.3)))
    img = shade(img, 0.92 + 0.1 * ((x // 2 + y // 2) % 2))
    seam = ((x % (16 * K)) < 1) | ((y % (16 * K)) < 1)
    img[seam] *= 0.7
    wear = fbm(h, w, 2, 3)
    img = img * (1 + np.clip(wear - 0.55, 0, 1)[..., None] * 0.7)
    cx, cy = rng.integers(0, w), rng.integers(0, h)
    d = np.hypot(wrap_d(x, cx, w), wrap_d(y, cy, h)) + fbm(h, w, 8, 2) * 2 * K
    img[d < 3.2 * K] = img[d < 3.2 * K] * 0.6 + np.array([0.24, 0.16, 0.08]) * 0.4
    img[np.abs(d - 3.2 * K) < 0.4 * K] *= 0.7
    img += grain(h, w, 0.04)[..., None]
    return posterize(img, 20)


def ceiling_tiles() -> np.ndarray:
    """1 m of suspended ceiling: fissured mineral tiles of 0.5 m in a white
    metal grid, water stains with brown rings, one tile sagging darker."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.62, 0.61, 0.56), h, w)
    fiss = fbm(h, w, 20, 2)
    img = shade(img, 0.9 + 0.12 * fiss)
    pits = rng.random((h, w)) > 0.97
    img[pits] *= 0.75
    worm = np.abs(np.sin(x * 0.9 / K + fbm(h, w, 6, 3) * 9)) < 0.08  # the fissures
    img[worm] *= 0.82
    s = 16 * K
    tx, ty = x % s, y % s
    grid_bar = (tx < K) | (ty < K)
    img[grid_bar] = (0.74, 0.73, 0.69)
    img[(tx == K) | (ty == K)] *= 0.7  # the bar's shadow on the tile
    stain = fbm(h, w, 2, 4)
    st = np.clip((stain - 0.66) * 3, 0, 0.45)
    img = img * (1 - st[..., None]) + np.array([0.42, 0.32, 0.16]) * st[..., None]
    img[np.abs(stain - 0.7) < 0.01] *= 0.75
    q = int(rng.integers(0, 4))
    sag = ((x // s) == q % 2) & ((y // s) == q // 2) & ~grid_bar
    img[sag] *= 0.82
    img += grain(h, w, 0.035)[..., None]
    return posterize(img, 18)


def tapes_shelf() -> np.ndarray:
    """1 m of the archive's shelves at 64 x 96 px (three rows of a third of
    a metre, like books.png): the spines of tape boxes, black U-matic cases
    and white VHS sleeves, a coloured dot or a blank label on each, gaps
    where some are missing, one lying flat."""
    h, w = 96, 64
    rng = _rng()
    img = rgb((0.035, 0.033, 0.03), h, w)
    for row in range(3):
        bottom = (row + 1) * 32 - 1
        x = 0
        while x < w:
            umatic = rng.random() < 0.55
            bw = int(rng.integers(4, 6)) if umatic else int(rng.integers(3, 4))
            if x + bw > w:
                bw = w - x
            if rng.random() < 0.08 and x + bw < w - 2:
                x += bw + int(rng.integers(1, 4))
                continue
            bh = int(rng.integers(21, 25)) if umatic else int(rng.integers(17, 20))
            top = bottom - bh
            col = np.array([0.10, 0.10, 0.11]) if umatic else np.array([0.66, 0.64, 0.58])
            col = col * rng.uniform(0.85, 1.1)
            img[top:bottom + 1, x:x + bw] = col
            img[top:bottom + 1, x] *= 0.6
            ly = top + int(rng.integers(3, 6))
            lab = (0.78, 0.76, 0.66) if umatic else (0.30, 0.30, 0.30)
            img[ly:ly + int(rng.integers(5, 10)), x + 1:x + bw - 1] = lab  # the label (blank: never text)
            if rng.random() < 0.6:
                dot = [(0.75, 0.18, 0.14), (0.85, 0.70, 0.15), (0.20, 0.45, 0.75), (0.25, 0.60, 0.30)][int(rng.integers(0, 4))]
                img[bottom - 4:bottom - 2, x + 1:x + min(3, bw - 1)] = dot
            img[top, x:x + bw] *= 1.3  # dust on the tops
            x += bw
    img = shade(img, 0.86 + 0.18 * fbm(h, w, 3, 2))
    img += grain(h, w, 0.03)[..., None]
    return posterize(img, 20)


def locker() -> np.ndarray:
    """Steel lockers: grey-green stove enamel, louvres, dents, rust where
    the paint is chipped at hand height."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.40, 0.45, 0.42), h, w)
    img = shade(img, 0.9 + 0.12 * stretched_noise(h, w, 10, 12, 2))
    img = shade(img, 0.9 + 0.14 * fbm(h, w, 3, 3))
    for _ in range(4):  # dents: a soft dark-light pair
        cx, cy = rng.integers(0, w), rng.integers(0, h)
        d = np.hypot(wrap_d(x, cx, w), wrap_d(y, cy, h))
        img = shade(img, 1 - 0.18 * np.clip(1 - d / (2.5 * K), 0, 1) * np.sign(np.sin(d / K)))
    rust = fbm(h, w, 6, 4) > 0.8
    img[rust] = img[rust] * 0.4 + np.array([0.40, 0.20, 0.08]) * 0.6
    img += grain(h, w, 0.03)[..., None]
    return posterize(img, 22)


def metal() -> np.ndarray:
    """Dark grey painted steel of the racks and the desks in the control
    room: brushed, scratched pale along the edges, a sticker torn off."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.20, 0.21, 0.22), h, w)
    img = shade(img, 0.85 + 0.25 * stretched_noise(h, w, 16, 18, 2))
    img = shade(img, 0.9 + 0.14 * fbm(h, w, 3, 3))
    for _ in range(18):
        sx, sy = rng.integers(0, w), rng.integers(0, h)
        ln = rng.integers(2 * K, 7 * K)
        a = rng.uniform(-0.3, 0.3)
        for i in range(ln):
            img[int(sy + i * a) % h, (sx + i) % w] *= 1.5
    cx, cy = rng.integers(0, w - 6 * K), rng.integers(0, h - 4 * K)
    img[cy:cy + 4 * K, cx:cx + 6 * K] = img[cy:cy + 4 * K, cx:cx + 6 * K] * 0.5 + 0.3
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 22)


def door_dock() -> np.ndarray:
    """The loading dock's steel door (1 m x 2.6 m, mapped like door_exit):
    grey paint over steel, a wired-glass window high up with the yard light
    behind it, a push bar, a kick plate scuffed bare, rust weeping from
    the hinges."""
    h, w = 84 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.42, 0.43, 0.42), h, w)
    img = shade(img, 0.9 + 0.12 * stretched_noise(h, w, 8, 10, 2))
    img = shade(img, 0.86 + 0.18 * fbm(h, w, 3, 4))
    win = (y >= 10 * K) & (y < 26 * K) & (x >= 10 * K) & (x < 22 * K)
    img[win] = np.array([0.30, 0.30, 0.24]) * (0.8 + 0.4 * fbm(h, w, 5, 2)[win])[..., None]
    wire = win & (((x + y) % (2 * K) == 0) | ((x - y) % (2 * K) == 0))
    img[wire] *= 0.55
    img[(y >= 9 * K) & (y < 10 * K) & (x >= 9 * K) & (x < 23 * K)] = (0.2, 0.2, 0.2)
    img[(y >= 26 * K) & (y < 27 * K) & (x >= 9 * K) & (x < 23 * K)] = (0.55, 0.55, 0.53)
    bar = (y >= 42 * K) & (y < 44 * K) & (x >= 4 * K) & (x < 28 * K)
    img[bar] = (0.62, 0.60, 0.55)
    img[(y == 44 * K) & (x >= 4 * K) & (x < 28 * K)] = (0.12, 0.12, 0.12)
    kick = y >= 74 * K
    img[kick] = np.array([0.55, 0.55, 0.52]) * (0.8 + 0.3 * stretched_noise(h, w, 20, 16, 2)[kick])[..., None]
    for hy in (8 * K, 40 * K, 70 * K):  # rust weeping from the hinges
        run = (x < 3 * K) & (y >= hy) & (y < hy + rng.integers(6, 14) * K)
        img[run] = img[run] * 0.5 + np.array([0.38, 0.18, 0.07]) * 0.5
    img[:, :K] = (0.15, 0.15, 0.15)
    img[:, -K:] = (0.15, 0.15, 0.15)
    img += grain(h, w, 0.03)[..., None]
    return posterize(img, 20)


# --- The Husk: the costume ---------------------------------------------------------------

def husk_fur() -> np.ndarray:
    """The costume's fur: the show's mustard, matted into clumps and gone
    brown-grey with years of hands and damp; bald patches showing the
    backing mesh; dark stains that ran down from the neck."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.58, 0.42, 0.13), h, w)
    clump = fbm(h, w, 10, 3)
    strand = np.sin(x * 1.9 + np.sin(y * 0.7) * 2.0 + clump * 14)
    img = shade(img, 0.72 + 0.3 * (strand > 0.2) + 0.1 * clump)
    tips = rng.random((h, w)) > 0.86
    img[tips] *= 1.25
    roots = rng.random((h, w)) > 0.9
    img[roots] *= 0.6
    grime = fbm(h, w, 3, 4)[..., None]
    img = img * (1 - 0.55 * np.clip(grime - 0.45, 0, 1) * 2) + np.array([0.20, 0.16, 0.10]) * 0.55 * np.clip(grime - 0.45, 0, 1) * 2
    bald = fbm(h, w, 5, 3) > 0.8
    mesh = bald & (((x // 2) + (y // 2)) % 2 == 0)
    img[bald] = (0.30, 0.26, 0.18)
    img[mesh] = (0.16, 0.13, 0.09)
    stain = np.clip(fbm(h, w, 4, 4) - 0.6, 0, 1)[..., None] * 2.0
    img = img * (1 - stain * 0.7) + np.array([0.10, 0.06, 0.04]) * stain * 0.7
    img += grain(h, w, 0.06)[..., None]
    return posterize(np.clip(img, 0, 1), 18)


def husk_muzzle() -> np.ndarray:
    """The snout and the mouth (128 x 64, the front of the snout): pale
    cream fur gone yellow, a wide smile sewn shut with thick black thread
    (cross stitches, a few broken and hanging), the corners pulled up too
    far, and dark seeping from between the stitches."""
    h, w = 64, 128
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.74, 0.66, 0.46), h, w)
    img = shade(img, 0.8 + 0.25 * (rng.random((h, w)) > 0.5) * (0.5 + 0.5 * np.sin(x * 2.3 + y * 1.1)))
    img = shade(img, 0.85 + 0.2 * fbm(h, w, 4, 3))
    # The smile: a curve from corner to corner, pulled up at the ends.
    t = (x - 64) / 52.0
    curve = 30 + 12 * (1 - t * t) - 6 * np.abs(t) ** 3 * 0  # (the low middle)
    curve = 34 + 10 * (1 - t * t) - 14 * np.clip(np.abs(t) - 0.75, 0, 1) * 4
    inside = (np.abs(t) <= 1.0)
    lip = inside & (np.abs(y - curve) < 1.6)
    seep = inside & (y > curve) & (y < curve + 6 + 4 * fbm(h, w, 8, 2) * 4)
    img[seep] = img[seep] * 0.55 + np.array([0.18, 0.10, 0.06]) * 0.45
    img[lip] = (0.10, 0.06, 0.05)
    for k in range(-50, 51, 7):  # the cross stitches
        cx = 64 + k
        cy = 34 + 10 * (1 - (k / 52) ** 2) - 14 * max(0.0, abs(k / 52) - 0.75) * 4
        if rng.random() < 0.15:  # a broken one, the thread hanging
            for i in range(9):
                yy, xx = int(cy + i), int(cx + (i % 3) - 1)
                if 0 <= yy < h and 0 <= xx < w:
                    img[yy, xx] = (0.05, 0.04, 0.04)
            continue
        for i in range(-4, 5):
            for yy, xx in ((int(cy + i), int(cx + i * 0.8)), (int(cy + i), int(cx - i * 0.8))):
                if 0 <= yy < h and 0 <= xx < w:
                    img[yy, xx] = (0.04, 0.03, 0.03)
    img += grain(h, w, 0.04)[..., None]
    return posterize(np.clip(img, 0, 1), 18)


def husk_eye() -> np.ndarray:
    """One of its plastic eyes (64 x 64, the front of a sphere): the white
    gone the yellow of old varnish and crazed with fine cracks, a black
    pupil set off-centre, scratched, a hard highlight painted on."""
    h, w = 64, 64
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.86, 0.80, 0.56), h, w)
    img = shade(img, 0.85 + 0.2 * fbm(h, w, 4, 3))
    cx, cy = 37, 35
    d = np.hypot(x - cx, y - cy)
    img[d < 14] = (0.42, 0.30, 0.10)  # the iris, cheap amber
    img[d < 9] = (0.03, 0.03, 0.03)
    img[(d >= 13) & (d < 14.5)] = (0.12, 0.08, 0.04)
    img[np.hypot(x - cx + 4, y - cy + 4) < 2.5] = (0.95, 0.95, 0.9)
    for _ in range(26):  # crazing
        px, py = float(rng.integers(0, w)), float(rng.integers(0, h))
        a = rng.uniform(0, 6.28)
        for _ in range(int(rng.integers(6, 18))):
            ix, iy = int(px) % w, int(py) % h
            img[iy, ix] *= 0.7
            a += rng.normal(0, 0.6)
            px += np.cos(a)
            py += np.sin(a)
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 20)


def husk_glove() -> np.ndarray:
    """The costume's gloves: white cotton gone grey, black at the fingertips
    and the palms, the seams pulled."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    img = rgb((0.78, 0.76, 0.70), h, w)
    img = shade(img, 0.94 + 0.06 * (((x // 2) + (y // 2)) % 2))
    dirt = fbm(h, w, 3, 4)[..., None]
    img = img * (1 - 0.7 * np.clip(dirt - 0.4, 0, 1) * 2) + np.array([0.22, 0.20, 0.17]) * 0.7 * np.clip(dirt - 0.4, 0, 1) * 2
    seam = (x % (10 * K)) < 1
    img[seam] *= 0.6
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 20)


def husk_felt() -> np.ndarray:
    """The bow tie's red felt, faded and pilled, a burn hole."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.55, 0.10, 0.08), h, w)
    img = shade(img, 0.86 + 0.2 * fbm(h, w, 12, 2))
    pills = rng.random((h, w)) > 0.95
    img[pills] *= 1.3
    fade = fbm(h, w, 2, 3)[..., None]
    img = img * (1 - 0.3 * fade) + np.array([0.45, 0.32, 0.28]) * 0.3 * fade
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 20)


def husk_inside() -> np.ndarray:
    """What is inside the costume, through the open zip and the neck: dark
    lining, tufts of grey stuffing, and something wet and dark."""
    h, w = 32 * K, 32 * K
    y, x = grid(h, w)
    rng = _rng()
    img = rgb((0.04, 0.035, 0.03), h, w)
    tufts = fbm(h, w, 8, 3) > 0.72
    img[tufts] = np.array([0.30, 0.29, 0.27]) * (0.6 + 0.6 * fbm(h, w, 20, 1)[tufts])[..., None]
    wet = fbm(h, w, 5, 3) > 0.75
    img[wet] = (0.09, 0.03, 0.025)
    img += grain(h, w, 0.03)[..., None]
    return posterize(np.clip(img, 0, 1), 16)


TEXTURES = {
    "wall_block": wall_block,
    "wall_studio": wall_studio,
    "floor_lino": floor_lino,
    "floor_studio": floor_studio,
    "carpet": carpet,
    "ceiling_tiles": ceiling_tiles,
    "tapes_shelf": tapes_shelf,
    "locker": locker,
    "metal": metal,
    "door_dock": door_dock,
    "husk_fur": husk_fur,
    "husk_muzzle": husk_muzzle,
    "husk_eye": husk_eye,
    "husk_glove": husk_glove,
    "husk_felt": husk_felt,
    "husk_inside": husk_inside,
}


def main() -> None:
    names = sys.argv[1:]
    print("station textures ->", gt.OUT)
    for i, name in enumerate(TEXTURES):
        if names and name not in names:
            continue
        gt.rng = np.random.default_rng(9100 + i)
        gt.save(name, TEXTURES[name]())


if __name__ == "__main__":
    main()
