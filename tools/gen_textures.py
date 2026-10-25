"""Generates the prototype's placeholder pixel-art textures into
game/assets/textures. Deterministic (same seed, same output): they exist to
find the art style and will be replaced by hand-made art once it is set.

    python tools/gen_textures.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

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


def wallpaper() -> np.ndarray:
    """2 m wide x 2.6 m tall at 32 px/m: faded green damask with a skirting."""
    h, w = 84, 64
    y, x = grid(h, w)
    img = rgb((0.34, 0.40, 0.31), h, w)
    img = shade(img, 1.0 + 0.06 * ((x // 4) % 2))
    # small diamond motif, staggered
    col = (x // 16).astype(int)
    my = (y + (col % 2) * 6) % 12
    mx = x % 16
    diamond = (np.abs(mx - 8) + np.abs(my - 6)) <= 2
    img[diamond] = img[diamond] * 0.55 + np.array([0.55, 0.50, 0.30]) * 0.45
    # age: blotches, water damage at the bottom, soot at the top
    img = shade(img, 0.82 + 0.25 * seamless(h, w, 5, 3))
    stain = np.clip((y - 58 + 6 * seamless(h, w, 3, 3)) / 20, 0, 1)
    img = img * (1 - stain[..., None] * 0.45) + np.array([0.30, 0.22, 0.12]) * stain[..., None] * 0.45
    img = shade(img, 1.0 - np.clip((14 - y) / 14, 0, 1) * 0.35)
    img += grain(h, w, 0.05)[..., None]
    # skirting board
    img[79:, :] = np.array([0.22, 0.14, 0.08]) + grain(5, w, 0.04)[..., None]
    img[79, :] = [0.34, 0.23, 0.13]
    return posterize(img)


def wall_tile() -> np.ndarray:
    """Kitchen / bathroom: white tiles up to 1.3 m, yellowed paint above."""
    h, w = 84, 64
    y, x = grid(h, w)
    img = rgb((0.62, 0.57, 0.40), h, w)
    img = shade(img, 0.8 + 0.25 * seamless(h, w, 5, 3))
    tiles = y >= 42
    t = rgb((0.78, 0.78, 0.72), h, w)
    t = shade(t, 0.9 + 0.12 * seamless(h, w, 4, 4))
    grout = ((x % 8) == 0) | (((y - 42) % 8) == 0)
    t[grout] = [0.42, 0.42, 0.38]
    img[tiles] = t[tiles]
    img[41:43, :] = [0.30, 0.42, 0.38]  # trim row
    grime = np.clip((y - 70) / 14, 0, 1) * 0.3
    img = shade(img, 1 - grime)
    img = shade(img, 1.0 - np.clip((14 - y) / 14, 0, 1) * 0.3)
    img += grain(h, w, 0.04)[..., None]
    return posterize(img)


def floor_wood() -> np.ndarray:
    h, w = 32, 32
    y, x = grid(h, w)
    img = np.zeros((h, w, 3))
    for p in range(4):
        base = np.array([0.36, 0.23, 0.13]) * (0.85 + 0.3 * rng.random())
        rows = slice(p * 8, p * 8 + 8)
        g = 0.9 + 0.1 * np.sin(x[rows] * 0.9 + y[rows] * 2.3 + rng.random() * 6)
        img[rows] = base * g[..., None]
        joint = rng.integers(0, w)
        img[rows, joint] *= 0.55
    img[(y % 8) == 7] *= 0.5
    img = shade(img, 0.85 + 0.2 * seamless(h, w, 3, 2))
    img += grain(h, w, 0.04)[..., None]
    return posterize(img)


def floor_tile() -> np.ndarray:
    h, w = 32, 32
    y, x = grid(h, w)
    checker = ((x // 16) + (y // 16)) % 2 == 0
    img = np.where(checker[..., None], np.array([0.70, 0.66, 0.55]), np.array([0.38, 0.42, 0.38]))
    grout = ((x % 16) == 0) | ((y % 16) == 0)
    img[grout] = [0.25, 0.24, 0.22]
    img = shade(img, 0.8 + 0.25 * seamless(h, w, 5, 2))
    img += grain(h, w, 0.05)[..., None]
    return posterize(img)


def ceiling() -> np.ndarray:
    h, w = 32, 32
    img = rgb((0.50, 0.48, 0.45), h, w)
    img = shade(img, 0.85 + 0.2 * seamless(h, w, 4, 2))
    img += grain(h, w, 0.08)[..., None]
    return posterize(img, 12)


def small(base, pattern: str) -> np.ndarray:
    h, w = 16, 16
    y, x = grid(h, w)
    img = rgb(base, h, w)
    if pattern == "grain":
        img = shade(img, 0.85 + 0.15 * np.sin(y * 1.7 + np.sin(x * 0.8) * 2))
    elif pattern == "checks":
        img = shade(img, np.where(((x // 4) + (y // 4)) % 2 == 0, 1.0, 0.8))
    elif pattern == "stripes":
        img = shade(img, np.where((x // 3) % 2 == 0, 1.0, 0.85))
    elif pattern == "speckle":
        img = shade(img, 1.0 - (rng.random((h, w)) > 0.9) * 0.25)
    img += grain(h, w, 0.05)[..., None]
    return posterize(img)


def mascot_fur() -> np.ndarray:
    h, w = 32, 32
    img = rgb((0.60, 0.48, 0.20), h, w)
    strands = rng.random((h // 2, w)) - 0.5
    strands = np.repeat(strands, 2, axis=0)
    img = shade(img, 1.0 + strands * 0.35)
    img = shade(img, 0.7 + 0.35 * seamless(h, w, 5, 3))
    return posterize(img, 12)


def mascot_face() -> np.ndarray:
    """Painted felt face: big glossy eyes, pinprick pupils, a smile too wide."""
    s = 64
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    black = (12, 8, 8, 255)
    d.ellipse((3, 26, 61, 62), fill=black)                 # mouth: a crescent
    d.ellipse((7, 18, 57, 49), fill=(0, 0, 0, 0))
    d.ellipse((5, 33, 14, 40), fill=(170, 90, 90, 255))    # cheeks
    d.ellipse((50, 33, 59, 40), fill=(170, 90, 90, 255))
    d.ellipse((13, 6, 28, 29), fill=black)                 # eyes
    d.ellipse((36, 6, 51, 29), fill=black)
    d.rectangle((21, 15, 22, 16), fill=(235, 235, 225, 255))  # pupils
    d.rectangle((42, 15, 43, 16), fill=(235, 235, 225, 255))
    d.ellipse((29, 29, 35, 34), fill=(60, 30, 30, 255))    # nose
    a = np.array(im)
    # teeth along the upper edge of the smile
    for x in range(8, 57):
        col = a[:, x, 3]
        ys = [yy for yy in range(40, s) if col[yy] > 0 and a[yy, x, 0] < 40]
        if ys and (x // 3) % 2 == 0:
            top = ys[0]
            a[top:top + 3, x, :3] = (225, 220, 190)
    return a.astype(float) / 255


def tape_label() -> np.ndarray:
    h, w = 16, 32
    im = Image.new("RGB", (w, h), (214, 208, 188))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, h - 1), outline=(150, 40, 40))
    for row, y in enumerate((4, 8, 11)):
        pts = [(3 + i * 2, y + int(rng.integers(-1, 2))) for i in range(13 - row * 3)]
        d.line(pts, fill=(170, 30, 30))
    return np.array(im).astype(float) / 255


def door_exit() -> np.ndarray:
    h, w = 84, 32
    y, x = grid(h, w)
    img = rgb((0.30, 0.19, 0.11), h, w)
    img = shade(img, 0.9 + 0.1 * np.sin(y * 0.6 + x * 0.1))
    for (y0, y1) in ((8, 30), (36, 74)):
        panel = (y >= y0) & (y <= y1) & (x >= 5) & (x <= 26)
        img[panel] *= 0.82
        img[(y == y0) & (x >= 5) & (x <= 26)] *= 1.3
    img[12:22, 10:22] = [0.20, 0.24, 0.30]   # small window, night outside
    img[48:51, 25:28] = [0.65, 0.55, 0.25]   # knob
    img[:, :2] = [0.16, 0.10, 0.06]
    img[:, -2:] = [0.16, 0.10, 0.06]
    img += grain(h, w, 0.04)[..., None]
    return posterize(img)


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


def main() -> None:
    print("textures ->", OUT)
    save("wallpaper", wallpaper())
    save("wall_tile", wall_tile())
    save("floor_wood", floor_wood())
    save("floor_tile", floor_tile())
    save("ceiling", ceiling())
    save("wood_dark", small((0.22, 0.14, 0.09), "grain"))
    save("sofa", small((0.50, 0.27, 0.12), "checks"))
    save("bed", small((0.38, 0.44, 0.52), "stripes"))
    save("counter", small((0.66, 0.60, 0.48), "speckle"))
    save("mascot_fur", mascot_fur())
    save("mascot_face", mascot_face())
    save("tape_label", tape_label())
    save("door_exit", door_exit())
    save("flashlight_cookie", flashlight_cookie())


if __name__ == "__main__":
    main()
