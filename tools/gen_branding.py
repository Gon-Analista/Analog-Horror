"""Game icon and boot splash: an old TV showing Vecinito, one eye already
gone wrong. Writes game/assets/branding/icon.png (256), icon.ico (Windows
executable) and splash.png (boot screen).

    python tools/gen_branding.py    (after tools/gen_tv.py)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "branding"
TV = ROOT / "game" / "assets" / "textures" / "tv_show.png"
FONT = ROOT / "game" / "assets" / "fonts" / "VT323-Regular.ttf"


def tv_picture(size: tuple[int, int], frame: int, crop_face: bool) -> Image.Image:
    sheet = Image.open(TV).convert("RGB")
    pic = sheet.crop((frame * 320, 0, frame * 320 + 320, 240))
    if crop_face:
        pic = pic.crop((88, 38, 232, 146))  # the face
    return pic.resize(size, Image.LANCZOS)


def scanlines(im: Image.Image, strength: float = 0.18) -> Image.Image:
    a = np.array(im).astype(float)
    a[::2] *= 1 - strength
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def icon() -> Image.Image:
    s = 1024
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((40, 150, 984, 900), 90, fill=(86, 52, 30), outline=(30, 18, 10), width=24)   # cabinet
    d.rounded_rectangle((110, 215, 914, 835), 110, fill=(14, 14, 14))                                  # bezel
    face = tv_picture((700, 525), 0, True)
    # One eye has already gone hollow.
    hollow = tv_picture((700, 525), 9, True)
    mask = Image.new("L", face.size, 0)
    ImageDraw.Draw(mask).rectangle((350, 0, 700, 525), fill=255)
    face.paste(hollow, (0, 0), mask)
    face = scanlines(face, 0.12)
    screen_mask = Image.new("L", face.size, 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle((0, 0, 700, 525), 80, fill=255)
    im.paste(face, (162, 262), screen_mask)
    d.line((300, 150, 200, 20), fill=(30, 18, 10), width=22)   # antennas
    d.line((724, 150, 824, 20), fill=(30, 18, 10), width=22)
    d.ellipse((800, 860, 860, 920), fill=(40, 30, 24))
    return im


def splash() -> Image.Image:
    w, h = 1280, 720
    im = Image.new("RGB", (w, h), (4, 4, 6)).convert("RGBA")
    lg = logo()
    lg = lg.resize((960, int(lg.size[1] * 960 / lg.size[0])), Image.LANCZOS)
    im.alpha_composite(lg, ((w - lg.size[0]) // 2, (h - lg.size[1]) // 2 - 20))
    return scanlines(im.convert("RGB"), 0.25)


def logo() -> Image.Image:
    """The title: LOST SIGNAL as a tape that is going: the letters split into
    red and cyan, slices of them torn sideways, scanlines through them, a
    tracking band of snow, an amber glow; under it ANALOG HORROR, spaced
    out, after a red REC dot. Transparent, about 4:1."""
    rng = np.random.default_rng(1989)
    w, h = 1400, 330
    big = ImageFont.truetype(str(FONT), 250)
    small = ImageFont.truetype(str(FONT), 58)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    title = "LOST SIGNAL"
    tw = md.textlength(title, font=big)
    x0 = (w - tw) / 2
    md.text((x0, -20), title, font=big, fill=255)
    m = np.asarray(mask).astype(float) / 255
    # Worn: specks missing from the letters.
    m *= (rng.random(m.shape) > 0.025)
    # Torn slices: some bands of rows pushed sideways.
    for y, hh, dx in ((58, 9, 16), (104, 6, -11), (186, 12, 20)):
        m[y:y + hh] = np.roll(m[y:y + hh], dx, axis=1)

    def shift(a, dx):
        return np.roll(a, dx, axis=1)

    red, cyan = shift(m, -9), shift(m, 9)
    rgb = np.zeros((h, w, 3))
    alpha = np.zeros((h, w))
    rgb += red[..., None] * np.array([1.0, 0.12, 0.1]) * 0.9
    rgb += cyan[..., None] * np.array([0.1, 0.85, 1.0]) * 0.75
    alpha = np.maximum(alpha, np.maximum(red, cyan) * 0.8)
    amber = np.array([1.0, 0.8, 0.28])
    rgb = rgb * (1 - m[..., None]) + amber * m[..., None]
    alpha = np.maximum(alpha, m)
    # A tracking band of snow across the letters.
    band = slice(120, 134)
    snow = rng.random((14, w))
    rgb[band] = rgb[band] * 0.5 + snow[..., None] * 0.5 * alpha[band][..., None]
    # Scanlines.
    alpha[::4] *= 0.45
    alpha[1::4] *= 0.8
    # The glow.
    glow = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))
    g = np.asarray(glow).astype(float) / 255 * 0.55
    out_rgb = rgb * alpha[..., None] + amber * 0.9 * g[..., None] * (1 - alpha[..., None])
    out_a = np.clip(alpha + g * (1 - alpha), 0, 1)
    rgb_final = np.where(out_a[..., None] > 0, out_rgb / np.maximum(out_a[..., None], 1e-4), 0)
    im = Image.fromarray(np.dstack([np.clip(rgb_final, 0, 1) * 255, out_a * 255]).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(im)
    tag = "A N A L O G   H O R R O R"
    tl = d.textlength(tag, font=small)
    tx = (w - tl) / 2 + 30
    d.ellipse((tx - 52, 262, tx - 26, 288), fill=(235, 40, 30, 255))
    d.text((tx, 240), tag, font=small, fill=(200, 196, 186, 235))
    d.line((x0 + 10, 232, x0 + tw - 10, 232), fill=(200, 196, 186, 90), width=3)
    return im.crop(im.getbbox())  # tight: it lines up with the menu's column


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ic = icon()
    ic.resize((256, 256), Image.LANCZOS).save(OUT / "icon.png")
    ic.resize((256, 256), Image.LANCZOS).save(OUT / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    logo().save(OUT / "title.png")
    splash().save(OUT / "splash.png")
    print("branding ->", OUT)


if __name__ == "__main__":
    main()
