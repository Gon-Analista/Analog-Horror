"""The Visita's mask for the 3D puppet: not a drawing, a thing. An old
plaster mask of a bear-child face (the two ear bumps are what is left of
the bear), almost right: the features sculpted a little too human, cast
in a mould that was not quite cleaned; cracked, chipped, grey with
grime that has gathered in every hollow, stained brown where something
ran out of the eyes and the mouth. The eyes are holes onto the dark
behind (in the lunge, a pinprick of light), the mouth a hole or a slit,
with small human teeth in it. Each expression is the same mask broken a different way.

Writes, one cell per expression x 2 boil frames (the cracks and stains
shift a hair between them), 256x416 px each, the mask's layout in
EntityModel.MASK (eyes at (+-0.4, -0.3) of the half width, mouth below):

  game/assets/textures/entity3d_faces.png        colour, alpha = the mask
      with its holes
  game/assets/textures/entity3d_faces_normal.png its relief (OpenGL, Y+):
      brow, sockets, nose, cheekbones, lips, cracks

    python tools/gen_entity_mask.py   (also run by gen_entity_3d.py)
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, binary_dilation

TEX = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures"
FACES = ["smile", "happy", "grin", "beam", "sad", "scream", "open"]
CW, CH = 256, 416
K = 2                       # drawn at 2x
W, H = CW * K, CH * K
X0, X1 = -1.15, 1.15        # the cell, in units of the mask's half width
Y0, Y1 = -1.5, 2.2
EYE = ((-0.4, -0.3), (0.4, -0.3))


def grid():
    xs = np.linspace(X0, X1, W)
    ys = np.linspace(Y0, Y1, H)
    return np.meshgrid(xs, ys)


def g2(nx, ny, cx, cy, sx, sy):
    return np.exp(-(((nx - cx) / sx) ** 2 + ((ny - cy) / sy) ** 2))


def mask_shape(nx, ny):
    """The outline: a long oval, the chin narrow, two small ear bumps."""
    width = np.where(ny > 0, 1.0 - 0.28 * np.clip(ny / 1.3, 0, 1) ** 2, 1.0)
    inside = (nx / width) ** 2 + (ny / 1.32) ** 2 <= 1.0
    for ex in (-0.64, 0.64):
        inside |= ((nx - ex) / 0.27) ** 2 + ((ny + 1.2) / 0.25) ** 2 <= 1.0
    return inside


def mouth_hole(face, nx, ny, rng):
    """Where the mouth is open (alpha 0), and the lips' line (for relief and paint)."""
    hole = np.zeros_like(nx, dtype=bool)
    line = np.zeros_like(nx)
    if face in ("smile", "sad"):
        # A slit, closed and stretched a little too wide; a thin dark gap.
        bend = 0.12 if face == "smile" else -0.1
        y = 0.52 + bend * (1 - (nx / 0.46) ** 2)  # (ny grows downwards: + is a smile)
        on = np.abs(nx) < 0.46
        d = np.abs(ny - y)
        hole = on & (d < 0.018 * (1 - (nx / 0.46) ** 2) + 0.004)
        line = np.exp(-(d / 0.03) ** 2) * on
    elif face in ("grin", "happy", "beam"):
        # A crescent, wide open, too many small teeth in it.
        half = 0.56 if face == "beam" else 0.46
        top = 0.5 - 0.16 * (nx / half) ** 2
        bottom = top + (0.2 if face == "beam" else 0.15) * (1 - (nx / half) ** 2)
        on = np.abs(nx) < half
        hole = on & (ny > top) & (ny < bottom)
        line = on * (np.exp(-((ny - top) / 0.03) ** 2) + np.exp(-((ny - bottom) / 0.03) ** 2))
    elif face == "scream":
        # Stretched open, down, the jaw too long.
        hole = ((nx / 0.2) ** 2 + ((ny - 0.66) / 0.36) ** 2) <= 1.0
        line = np.exp(-((np.sqrt((nx / 0.2) ** 2 + ((ny - 0.66) / 0.36) ** 2) - 1.0) / 0.12) ** 2)
    elif face == "open":
        # Torn open from the mouth down past the chin.
        wob = gaussian_filter(rng.standard_normal(nx.shape[0]), 6)[:, None] * 0.05
        half = 0.3 + 0.12 * np.clip((ny - 0.4) / 0.8, 0, 1) + wob
        hole = (np.abs(nx) < half) & (ny > 0.38 - 0.05 * (1 - (nx / 0.4) ** 2)) & (ny < 1.6)
        line = np.exp(-((np.abs(nx) - half) / 0.05) ** 2) * (ny > 0.38) * (ny < 1.6)
    return hole, line


def eye_holes(face, nx, ny):
    """Almond holes for the eyes (none when they are sewn shut)."""
    if face == "happy":
        return np.zeros_like(nx, dtype=bool)
    rx, ry = (0.15, 0.085) if face != "scream" else (0.15, 0.12)
    if face == "open":
        rx, ry = 0.2, 0.16
    hole = np.zeros_like(nx, dtype=bool)
    for ex, ey in EYE:
        # Almond: pointed at the corners.
        u = (nx - ex) / rx
        v = (ny - ey) / ry
        hole |= (np.abs(u) < 1) & (np.abs(v) < (1 - u ** 2) ** 0.8)
    return hole


def crack_map(rng, nx, ny, count, seed_pts=None):
    """Thin cracks wandering across the plaster (a mask image of them)."""
    img = np.zeros((H, W), dtype=np.float32)
    pts = seed_pts or []
    for _ in range(count):
        if pts and rng.random() < 0.7:
            x, y = pts[rng.integers(len(pts))]
        else:
            x, y = rng.uniform(-0.9, 0.9), rng.uniform(-1.2, 1.2)
        a = rng.uniform(0, math.tau)
        for step in range(int(rng.uniform(25, 80))):
            a += rng.normal(0, 0.16)
            x += math.cos(a) * 0.012
            y += math.sin(a) * 0.012
            px = int((x - X0) / (X1 - X0) * W)
            py = int((y - Y0) / (Y1 - Y0) * H)
            if 0 <= px < W and 0 <= py < H:
                img[py, px] = 1.0
            if rng.random() < 0.015:  # a branch
                pts.append((x, y))
    return np.clip(gaussian_filter(img, 0.7) * 2.2, 0, 1)


def drips(rng, nx, ny, sources, length, width):
    """Stains running down from the eyes and the mouth."""
    out = np.zeros((H, W), dtype=np.float32)
    for sx, sy in sources:
        for _ in range(3):
            x = sx + rng.normal(0, 0.05)
            l = rng.uniform(0.4, 1.0) * length
            wv = width * rng.uniform(0.5, 1.2)
            band = np.exp(-((nx - x - 0.03 * np.sin((ny - sy) * 9)) / wv) ** 2) * (ny > sy) * (ny < sy + l)
            fade = np.clip(1 - (ny - sy) / max(l, 0.01), 0, 1) ** 0.6
            out = np.maximum(out, band * fade)
    return out


def face_cell(face: str, frame: int):
    rng = np.random.default_rng(900 + FACES.index(face))   # the same mask in both frames...
    boil = np.random.default_rng(9000 + FACES.index(face) * 10 + frame)  # ...a hair different
    nx, ny = grid()
    nx = nx + boil.normal(0, 0.004)
    shape = mask_shape(nx, ny)
    eyes = eye_holes(face, nx, ny)
    mouth, lips = mouth_hole(face, nx, ny, rng)
    # Relief: a dome, the brow ridge, deep sockets, the nose, cheekbones,
    # the lips; creases from the nose to the mouth.
    r2 = (nx / 1.0) ** 2 + (ny / 1.32) ** 2
    hgt = np.sqrt(np.clip(1 - r2, 0, 1)) * 0.6
    hgt += 0.18 * g2(nx, ny, 0, -0.55, 0.75, 0.12)
    for ex, ey in EYE:
        hgt -= 0.32 * g2(nx, ny, ex, ey, 0.24, 0.17)
        hgt += 0.1 * g2(nx, ny, ex * 1.15, ey + 0.32, 0.22, 0.1)   # cheekbones
    hgt += 0.22 * g2(nx, ny, 0, -0.08, 0.07, 0.3) + 0.16 * g2(nx, ny, 0, 0.2, 0.12, 0.07)
    hgt -= 0.06 * g2(nx, ny, 0.06, 0.28, 0.04, 0.03) + 0.06 * g2(nx, ny, -0.06, 0.28, 0.04, 0.03)  # nostrils
    hgt += 0.08 * lips
    for side in (-1, 1):
        hgt -= 0.05 * g2(nx, ny, side * 0.33, 0.36, 0.05, 0.16)
    if face == "happy":  # eyes shut: swollen lids
        for ex, ey in EYE:
            hgt += 0.12 * g2(nx, ny, ex, ey, 0.17, 0.08)
    # Cracks: more the more broken the face.
    n_cracks = {"smile": 7, "happy": 8, "grin": 10, "beam": 14, "sad": 9, "scream": 16, "open": 24}[face]
    seeds = [(EYE[0][0], EYE[0][1]), (EYE[1][0], EYE[1][1]), (0.0, 0.55)]
    cracks = crack_map(np.random.default_rng(rng.integers(1 << 30) + frame * 0), nx, ny, n_cracks, list(seeds))
    hgt -= cracks * 0.05
    hgt = gaussian_filter(hgt, 1.2)
    # Colour: old plaster, mottled, grime in the hollows, chips.
    mottle = gaussian_filter(rng.standard_normal((H, W)), 4)
    mottle /= np.abs(mottle).max()
    grit = gaussian_filter(rng.standard_normal((H, W)), 1.0)
    grit /= np.abs(grit).max()
    base = np.array([0.72, 0.69, 0.62])
    col = np.ones((H, W, 3)) * base
    col *= (1 + mottle[..., None] * 0.07 + grit[..., None] * 0.06)
    # Years of dirt: blotches, darker low down and round the edges, a
    # yellowing where hands held it.
    dirt = gaussian_filter(rng.standard_normal((H, W)), 30)
    dirt = np.clip(dirt / np.abs(dirt).max(), 0, 1)
    col *= (1 - dirt[..., None] * 0.25)
    col *= (1 - 0.18 * np.clip((ny - 0.2) / 1.2, 0, 1))[..., None]
    col *= np.array([1.0, 0.97, 0.88])
    cavity = np.clip(gaussian_filter(hgt, 10) - hgt, 0, 1)
    col *= (1 - np.clip(cavity * 2.6, 0, 0.6))[..., None]
    col = col * (1 - 0.45 * np.clip(r2 - 0.45, 0, 1))[..., None]  # darker towards the edges
    chips = (gaussian_filter(rng.standard_normal((H, W)), 5) > 1.9 * 0.3).astype(np.float32)
    chips *= (gaussian_filter(rng.standard_normal((H, W)), 14) > 0.06)
    col = col * (1 - chips[..., None] * 0.22) + chips[..., None] * np.array([0.05, 0.05, 0.06]) * 0.5
    # The sockets: bruised dark grey, soot rubbed round the holes.
    for ex, ey in EYE:
        col *= (1 - 0.45 * g2(nx, ny, ex, ey, 0.25, 0.18))[..., None]
        col += (0.06 * g2(nx, ny, ex, ey + 0.08, 0.2, 0.15))[..., None] * np.array([0.3, 0.05, 0.2])
    # Paint that was meant to make it a child's face: faint pink cheeks,
    # lips painted on a little off the real mouth.
    for side in (-1, 1):
        col += (g2(nx, ny, side * 0.5, 0.25, 0.16, 0.12) * 0.07)[..., None] * np.array([0.6, -0.1, -0.1])
    paint_lips = np.roll(lips, int(0.03 / (Y1 - Y0) * H), axis=0)
    col = col * (1 - paint_lips[..., None] * 0.35) + paint_lips[..., None] * np.array([0.42, 0.1, 0.09]) * 0.35
    # Cracks: dark lines with a lighter lip on one side.
    soft = gaussian_filter(cracks, 1.5)
    col *= (1 - np.clip(soft * 1.6, 0, 0.35))[..., None]
    col *= (1 - cracks[..., None] * 0.55)
    col += np.roll(cracks, 1, axis=1)[..., None] * 0.05
    # Stains running out of the eyes and the mouth.
    stain = drips(rng, nx, ny, [EYE[0], EYE[1]], 0.9 if face in ("sad", "open", "scream") else 0.45, 0.025)
    stain = np.maximum(stain, drips(rng, nx, ny, [(-0.2, 0.6), (0.25, 0.62)], 0.7, 0.02) * (face in ("grin", "beam", "open", "scream")))
    stain_col = np.array([0.22, 0.12, 0.08]) if face != "open" else np.array([0.3, 0.02, 0.02])
    col = col * (1 - stain[..., None] * 0.7) + stain[..., None] * stain_col * 0.7
    if face == "open":
        col = col * np.array([1.0, 0.55, 0.5])  # flushed red, as in the drawing
    # Eyes sewn shut (happy): a seam and stitches across each.
    if face == "happy":
        for ex, ey in EYE:
            seam = np.exp(-((ny - ey - 0.02 * (1 - ((nx - ex) / 0.15) ** 2)) / 0.008) ** 2) * (np.abs(nx - ex) < 0.15)
            col *= (1 - seam[..., None] * 0.85)
            for k in range(5):
                sx = ex - 0.12 + k * 0.06
                st = np.exp(-((nx - sx) / 0.006) ** 2) * (np.abs(ny - ey) < 0.05)
                col = col * (1 - st[..., None] * 0.9) + st[..., None] * np.array([0.1, 0.06, 0.05]) * 0.9
    # Teeth: small, human, yellowed, crowded, a few missing, in the hole.
    teeth = np.zeros((H, W), dtype=bool)
    tooth_col = np.zeros((H, W, 3))
    if face != "smile" and face != "sad":
        rows = []
        if face in ("grin", "happy", "beam"):
            half = 0.56 if face == "beam" else 0.46
            for i in range(17 if face == "beam" else 14):
                t = (i + 0.5) / (17 if face == "beam" else 14)
                x = -half * 0.92 + 2 * half * 0.92 * t
                top = 0.5 - 0.16 * (x / half) ** 2
                bottom = top + (0.2 if face == "beam" else 0.15) * (1 - (x / half) ** 2)
                rows.append((x, top, 1, 0.05 + 0.02 * (1 - abs(t - 0.5) * 2)))
                rows.append((x + 0.02, bottom, -1, 0.035))
        elif face == "scream":
            for i in range(7):
                a = math.pi * (0.15 + 0.7 * (i + 0.5) / 7)
                rows.append((-math.cos(a) * 0.17, 0.66 - math.sin(a) * 0.33, 1, 0.05))
                rows.append((-math.cos(a) * 0.15, 0.66 + math.sin(a) * 0.32, -1, 0.04))
        elif face == "open":
            for i in range(12):
                x = -0.3 + 0.6 * (i + 0.5) / 12
                rows.append((x, 0.4, 1, rng.uniform(0.05, 0.09)))
            for i in range(9):
                x = -0.32 + 0.64 * (i + 0.5) / 9
                rows.append((x, 1.55, -1, rng.uniform(0.05, 0.08)))
        for x, y, d, h in rows:
            if rng.random() < 0.12:
                continue  # a gap
            w = rng.uniform(0.018, 0.026)
            tx = x + rng.normal(0, 0.005)
            rect = (np.abs(nx - tx) < w * (1 - 0.35 * np.clip((ny - y) * d / h, 0, 1))) & ((ny - y) * d > -0.005) & ((ny - y) * d < h)
            shade = np.clip(1 - ((ny - y) * d) / h * 0.4, 0, 1)
            yellow = np.array([0.76, 0.68, 0.5]) * rng.uniform(0.75, 1.0)
            tooth_col[rect] = (yellow[None, :] * shade[rect][:, None]) * (1 - 0.25 * (np.abs(nx[rect] - tx) / w))[:, None]
            teeth |= rect
        gum_band = mouth & ~teeth & binary_dilation(teeth, iterations=3)
        tooth_col[gum_band] = np.array([0.22, 0.05, 0.05])
        teeth |= gum_band
    col = np.where(teeth[..., None], tooth_col, col)
    alpha = shape & ~eyes & (~mouth | teeth)
    col = np.clip(col, 0, 1)
    # Normal map from the relief.
    gy, gx = np.gradient(hgt * 40.0)
    nrm = np.dstack([-gx, gy, np.ones_like(gx)])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    nrm_img = (nrm * 0.5 + 0.5)
    img = Image.fromarray((np.dstack([col, alpha.astype(np.float32)]) * 255).astype(np.uint8), "RGBA").resize((CW, CH), Image.LANCZOS)
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] > 120, 255, 0)
    nimg = Image.fromarray((nrm_img * 255).astype(np.uint8), "RGB").resize((CW, CH), Image.LANCZOS)
    return Image.fromarray(a, "RGBA"), nimg


def main() -> None:
    sheet = Image.new("RGBA", (CW * len(FACES), CH * 2), (0, 0, 0, 0))
    nsheet = Image.new("RGB", (CW * len(FACES), CH * 2), (128, 128, 255))
    for i, f in enumerate(FACES):
        for frame in range(2):
            c, nmap = face_cell(f, frame)
            sheet.paste(c, (i * CW, frame * CH))
            nsheet.paste(nmap, (i * CW, frame * CH))
        print("  mask", f)
    sheet.save(TEX / "entity3d_faces.png")
    nsheet.save(TEX / "entity3d_faces_normal.png")


if __name__ == "__main__":
    main()
