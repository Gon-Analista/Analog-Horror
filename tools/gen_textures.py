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


def aged_wall(img: np.ndarray, skirting: bool = True) -> np.ndarray:
    """Shared ageing for 2.6 m tall wall textures: blotches, water streaks
    running down from the ceiling, peeling patches, damp at the bottom,
    soot at the top, a skirting board."""
    h, w = img.shape[:2]
    y, x = grid(h, w)
    img = shade(img, 0.8 + 0.28 * seamless(h, w, 5, 3))
    for _ in range(max(1, w // 13)):  # water streaks
        sx = rng.integers(0, w)
        length = rng.integers(20, 60)
        width = rng.integers(1, 3)
        streak = (np.abs(((x - sx + w / 2) % w) - w / 2) <= width) & (y < length)
        img[streak] = img[streak] * 0.72 + np.array([0.28, 0.22, 0.12]) * 0.28
    for _ in range(max(1, w // 21)):  # peeling: the plaster shows through
        cx, cy = rng.integers(0, w), rng.integers(8, 70)
        r = rng.integers(3, 7)
        d = np.hypot(((x - cx + w / 2) % w) - w / 2, (y - cy) * 1.3)
        patch = d < r
        img[patch] = np.array([0.55, 0.52, 0.44]) * (0.85 + 0.15 * rng.random())
        edge = (d >= r) & (d < r + 1.2)
        img[edge] *= 0.6
    damp = np.clip((y - 60 + 8 * seamless(h, w, 3, 3)) / 18, 0, 1)
    img = img * (1 - damp[..., None] * 0.5) + np.array([0.20, 0.17, 0.10]) * damp[..., None] * 0.5
    img = shade(img, 1.0 - np.clip((16 - y) / 16, 0, 1) * 0.4)
    img += grain(h, w, 0.05)[..., None]
    if skirting:
        img[78:, :] = np.array([0.20, 0.13, 0.08]) + grain(6, w, 0.04)[..., None]
        img[78, :] = [0.33, 0.22, 0.13]
        img[83, :] *= 0.6
    return img


def wallpaper(base=(0.34, 0.40, 0.31), motif=(0.56, 0.50, 0.30), kind: str = "damask") -> np.ndarray:
    """2 m wide x 2.6 m tall at 32 px/m."""
    h, w = 84, 64
    y, x = grid(h, w)
    img = rgb(base, h, w)
    if kind == "damask":  # stripes + an ornate lozenge, staggered
        img = shade(img, 1.0 + 0.07 * ((x // 4) % 2))
        col = (x // 16).astype(int)
        my = (y + (col % 2) * 8) % 16
        mx = x % 16
        dx, dy = np.abs(mx - 8), np.abs(my - 8)
        orn = (((dx + dy) <= 4) & ~((dx + dy) <= 2)) | ((dx == 0) & (dy <= 6)) | ((dy == 0) & (dx <= 5))
        img[orn] = img[orn] * 0.45 + np.array(motif) * 0.55
    elif kind == "stars":  # a child's room: little stars and a cloud band
        for _ in range(40):
            cx, cy = rng.integers(0, w), rng.integers(0, 76)
            star = (np.abs(((x - cx + w / 2) % w) - w / 2) + np.abs(y - cy)) <= 1
            img[star] = motif
        band = (y > 50) & (y < 56)
        img[band] = img[band] * 0.6 + np.array([0.75, 0.72, 0.70]) * 0.4
    elif kind == "stripes":  # bedroom: wide faded stripes with a pinstripe
        img = shade(img, np.where((x // 8) % 2 == 0, 1.0, 0.82))
        pin = (x % 16) == 4
        img[pin] = img[pin] * 0.5 + np.array(motif) * 0.5
    return posterize(aged_wall(img))


def window() -> np.ndarray:
    """1 m wide x 2.6 m tall wall face with a window: dark night glass, a
    cross frame, torn curtains, a sill. Blank wall around it."""
    h, w = 84, 32
    y, x = grid(h, w)
    img = aged_wall(rgb((0.50, 0.46, 0.38), h, w))
    glass = (x >= 6) & (x < 26) & (y >= 22) & (y < 54)
    sky = np.array([0.06, 0.08, 0.14]) + 0.05 * (1 - (y - 22) / 32)[..., None]
    img[glass] = sky[glass]
    img[glass & (rng.random((h, w)) < 0.01)] = [0.5, 0.55, 0.7]  # a far light
    frame = glass & (((x >= 15) & (x <= 16)) | ((y >= 37) & (y <= 38)))
    img[frame] = [0.38, 0.33, 0.26]
    border = ((x >= 4) & (x < 28) & (y >= 20) & (y < 56)) & ~glass
    img[border] = [0.42, 0.37, 0.29]
    img[(y >= 56) & (y < 58) & (x >= 3) & (x < 29)] = [0.46, 0.40, 0.31]
    for cx0, cx1 in ((3, 9), (23, 29)):  # curtains, uneven, torn at the bottom
        cur = (x >= cx0) & (x < cx1) & (y >= 16) & (y < 60 + (x % 3) * 2 - (x % 5))
        img[cur] = np.array([0.36, 0.16, 0.14]) * (0.75 + 0.25 * np.sin(x[cur] * 1.7))[..., None]
    img[14:16, 2:30] = [0.25, 0.20, 0.15]  # rail
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


def cardboard() -> np.ndarray:
    h, w = 16, 16
    y, x = grid(h, w)
    img = rgb((0.52, 0.40, 0.25), h, w)
    img = shade(img, 0.9 + 0.1 * np.sin(y * 2.2))
    img[7:9, :] = [0.62, 0.55, 0.40]  # packing tape
    img += grain(h, w, 0.05)[..., None]
    return posterize(img)


def rug() -> np.ndarray:
    h, w = 32, 32
    y, x = grid(h, w)
    img = rgb((0.40, 0.10, 0.08), h, w)
    d = np.abs(x - 16) + np.abs(y - 16)
    img[(d % 8) < 2] = [0.62, 0.45, 0.22]
    img[((x % 16) < 2) | ((y % 16) < 2)] = [0.15, 0.10, 0.12]
    img = shade(img, 0.75 + 0.3 * seamless(h, w, 4, 2))
    img += grain(h, w, 0.06)[..., None]
    return posterize(img)


def paper() -> np.ndarray:
    h, w = 16, 16
    img = rgb((0.72, 0.70, 0.62), h, w)
    for yy in range(3, 14, 3):
        img[yy, 2:2 + rng.integers(6, 13)] = [0.35, 0.33, 0.35]
    img = shade(img, 0.85 + 0.15 * seamless(h, w, 2, 2))
    return posterize(img)


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
    small_im = im.resize((w, h), Image.BOX)
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


def main() -> None:
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
    save("sofa", small((0.50, 0.27, 0.12), "checks"))
    save("bed", small((0.38, 0.44, 0.52), "stripes"))
    save("counter", small((0.66, 0.60, 0.48), "speckle"))
    save("tape_label", tape_label())
    save("door_exit", door_exit())
    save("flashlight_cookie", flashlight_cookie())


if __name__ == "__main__":
    main()
