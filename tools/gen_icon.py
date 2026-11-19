"""Generates the game's icon (window, taskbar, export): a small wooden TV
of the time showing the first frame of the show, in pixel art, scaled up
with nearest filtering. Needs tools/gen_tv.py's output (tv_show.png).

    python tools/gen_icon.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "game" / "assets"
SIZE = 32
SCALE = 8


def main() -> None:
    show = Image.open(ROOT / "textures" / "tv_show.png").convert("RGBA").crop((0, 0, 320, 240))
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    wood, wood_dark, bezel = (92, 58, 32, 255), (52, 32, 18, 255), (18, 18, 18, 255)
    for y in range(4, 29):           # cabinet
        for x in range(1, 31):
            px[x, y] = wood_dark if x in (1, 30) or y in (4, 28) else wood
    for i in range(4):               # rabbit-ear antennae
        px[13 - i, 3 - i] = wood_dark
        px[18 + i, 3 - i] = wood_dark
    for y in range(6, 25):           # bezel
        for x in range(3, 25):
            px[x, y] = bezel
    screen = show.resize((20, 17), Image.LANCZOS)
    img.paste(screen, (4, 7))
    for y in range(8, 24, 4):        # knobs and speaker
        px[27, y] = (180, 160, 120, 255)
        px[28, y] = (120, 100, 80, 255)
    for x in (4, 23):                # rounded screen corners
        for y in (7, 23):
            px[x, y] = bezel
    px[22, 9] = (235, 40, 30, 255)   # the REC dot: it is evidence
    img.resize((SIZE * SCALE, SIZE * SCALE), Image.NEAREST).save(ROOT / "icon.png")
    print("   icon.png", SIZE * SCALE)


if __name__ == "__main__":
    main()
