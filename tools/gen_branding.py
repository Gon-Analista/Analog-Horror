"""Game icon and boot splash: an old TV showing Vecinito, one eye already
gone wrong. Writes game/assets/branding/icon.png (256), icon.ico (Windows
executable) and splash.png (boot screen).

    python tools/gen_branding.py    (after tools/gen_tv.py)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

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
    im = Image.new("RGB", (w, h), (4, 4, 6))
    d = ImageDraw.Draw(im)
    big = ImageFont.truetype(str(FONT), 110)
    small = ImageFont.truetype(str(FONT), 34)
    title = "¡HOLA, VECINITOS!"
    tw = d.textlength(title, font=big)
    d.text(((w - tw) / 2 + 4, 250 + 4), title, font=big, fill=(60, 10, 8))
    d.text(((w - tw) / 2, 250), title, font=big, fill=(255, 210, 80))
    sub = "UNIDAD DE RECUPERACIÓN · CANAL 9 · 1989"
    d.text(((w - d.textlength(sub, font=small)) / 2, 380), sub, font=small, fill=(140, 140, 135))
    note = "Cargando cinta..."
    d.text(((w - d.textlength(note, font=small)) / 2, 600), note, font=small, fill=(90, 90, 88))
    return scanlines(im, 0.25)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ic = icon()
    ic.resize((256, 256), Image.LANCZOS).save(OUT / "icon.png")
    ic.resize((256, 256), Image.LANCZOS).save(OUT / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    splash().save(OUT / "splash.png")
    print("branding ->", OUT)


if __name__ == "__main__":
    main()
