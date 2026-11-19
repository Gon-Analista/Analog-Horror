"""Textures for the Visita in 3D (EntityModel, the game's Visita):

  the mask, its relief and its eyes: gen_entity_mask.py (run from here);
  game/assets/textures/entity3d_hair.png    long black strings of hair and
      ragged black filaments (what bristles off its body), for thin cards.
  game/assets/textures/entity3d_skin.png    its black: tar and soot, a dull
      sheen, grain (tileable).

    python tools/gen_entity_3d.py
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter


TEX = Path(__file__).resolve().parent.parent / "game" / "assets" / "textures"
FACES = ["smile", "happy", "grin", "beam", "sad", "scream", "open"]


def hair() -> Image.Image:
    """64x256: strings of hair hanging from the top edge, ragged, tapering,
    some forked (the left half); bristles and filaments (the right half)."""
    w, h = 64 * 4, 256 * 4
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(31)
    for i in range(44):
        x = rng.uniform(4, w * 0.5 - 4)
        y = 0.0
        width = rng.uniform(7, 16)
        length = rng.uniform(0.55, 1.0) * h
        pts = [(x, y)]
        a = math.pi / 2
        while y < length:
            a += rng.normal(0, 0.06)
            a = min(max(a, math.pi / 2 - 0.25), math.pi / 2 + 0.25)
            x += math.cos(a) * 12
            y += math.sin(a) * 12
            pts.append((x, y))
        for k in range(len(pts) - 1):
            t = k / max(1, len(pts) - 1)
            d.line([pts[k], pts[k + 1]], fill=(8, 6, 6, 255), width=max(1, int(width * (1 - t * 0.85))))
    for i in range(40):
        x = rng.uniform(w * 0.5 + 4, w - 4)
        y0 = rng.uniform(0, h * 0.4)
        length = rng.uniform(0.3, 0.9) * h
        x1 = x + rng.normal(0, 18)
        d.line([(x, y0), ((x + x1) / 2 + rng.normal(0, 10), y0 + length / 2), (x1, y0 + length)], fill=(10, 8, 8, 255),
               width=int(rng.uniform(2, 6)), joint="curve")
    return img.resize((64, 256), Image.LANCZOS)


def skin() -> Image.Image:
    n = 128
    rng = np.random.default_rng(11)
    base = gaussian_filter(rng.standard_normal((n, n)), 3, mode="wrap")
    fine = gaussian_filter(rng.standard_normal((n, n)), 0.8, mode="wrap")
    streak = gaussian_filter(rng.standard_normal((n, n)), (8, 0.8), mode="wrap")
    v = 0.05 + base / np.abs(base).max() * 0.025 + fine / np.abs(fine).max() * 0.02 + streak / np.abs(streak).max() * 0.02
    v = np.clip(v, 0.01, 0.12)
    rgb = np.dstack([v * 1.05, v * 0.92, v * 0.9])
    rgb = np.round(rgb * 63) / 63
    return Image.fromarray((np.dstack([rgb, np.ones((n, n))]) * 255).astype(np.uint8), "RGBA")


def main() -> None:
    # The mask (and the eyes behind it): its own generator now
    # (gen_entity_mask.py; the drawing's cartoon mask looked drawn by a child).
    import gen_entity_mask
    gen_entity_mask.main()
    hair().save(TEX / "entity3d_hair.png")
    skin().save(TEX / "entity3d_skin.png")
    print("entity 3D textures ->", TEX)


if __name__ == "__main__":
    main()
