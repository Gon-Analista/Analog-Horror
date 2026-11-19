"""Images for the itch.io page (itch_page/assets/): cover, banner, page
background, screenshots and the GIFs for the description, all from the
game's own screenshots (English HUD) and branding.

    godot --path game -- --shots <dir> --seed 7 --lang en
    godot --path game -- --smoke --lang en --pilot-shot <dir>
    python tools/gen_itch_page.py <dir>

and the page mock: itch_page/preview.html = preview_template.html with
description.html inside (also done after the images):

    python tools/gen_itch_page.py --pages
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "itch_page" / "assets"
TITLE = ROOT / "game" / "assets" / "branding" / "title.png"
FONT = ROOT / "game" / "assets" / "fonts" / "VT323-Regular.ttf"
RED = (226, 44, 36)

# The page's screenshots, in order: what a stranger needs to get it in five.
SCREENSHOTS = [
    ("25_lurk_camcorder", "01_only_the_camera"),
    ("03_tv_show", "02_the_show"),
    ("04_tv_alert", "03_the_notice"),
    ("42_crew_camcorder", "04_the_crew"),
    ("33_ceiling_camcorder", "05_ceiling"),
    ("27_peek_bed_camcorder", "06_hiding"),
    ("10_camcorder_close", "07_up_close"),
    ("pilot_heat", "08_play_as_the_visitor"),
    ("21_win", "09_tape_recovered"),
]


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT), size)


def scanlines(im: Image.Image, strength: float = 0.22, step: int = 3) -> Image.Image:
    a = np.array(im.convert("RGB")).astype(float)
    a[::step] *= 1 - strength
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def vignette(im: Image.Image, power: float = 0.75) -> Image.Image:
    w, h = im.size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2) / 1.42
    k = (1 - power * d ** 1.6).clip(0, 1)[..., None]
    a = np.array(im.convert("RGB")).astype(float) * k
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def bottom_fade(im: Image.Image, start: float, end_alpha: float = 0.97) -> Image.Image:
    w, h = im.size
    t = ((np.arange(h) / h - start) / (1 - start)).clip(0, 1) ** 1.3
    k = (1 - t * end_alpha)[:, None, None]
    a = np.array(im.convert("RGB")).astype(float) * k
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def corners(d: ImageDraw.ImageDraw, box: tuple, length: int, width: int, color) -> None:
    x0, y0, x1, y1 = box
    for (x, y, sx, sy) in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
        d.line([(x, y + sy * length), (x, y), (x + sx * length, y)], fill=color, width=width)


def title_image(width: int) -> Image.Image:
    t = Image.open(TITLE).convert("RGBA")
    return t.resize((width, round(t.height * width / t.width)), Image.LANCZOS)


def cover(shots: Path) -> None:
    """630x500 (and 2x): the Visitor in the viewfinder, the title under it."""
    W, H = 1260, 1000
    src = Image.open(shots / "25_lurk_camcorder.png").convert("RGB")
    hud = ImageDraw.Draw(src)
    for box in [(1190, 640, 1345, 700), (630, 700, 810, 800)]:  # (FLASH and the toolbar: under the title anyway)
        hud.rectangle(box, fill=(8, 8, 8))
    crop = src.crop((290, 0, 290 + 1018, 810)).resize((W, round(810 * W / 1018)), Image.LANCZOS).crop((0, 0, W, H))
    im = bottom_fade(vignette(crop, 0.55), 0.5)
    im = scanlines(im, 0.18, 4)
    d = ImageDraw.Draw(im)
    corners(d, (36, 36, W - 36, H - 36), 70, 5, (235, 235, 228))
    d.ellipse((78, 82, 112, 116), fill=RED)
    d.text((128, 66), "REC", font=font(64), fill=(240, 240, 232))
    d.text((W - 300, 66), "CO-OP 1-4", font=font(52), fill=(240, 240, 232))
    t = title_image(1120)
    im.paste(t, ((W - t.width) // 2, 668), t)
    im.save(OUT / "cover_1260x1000.png")
    im.resize((630, 500), Image.LANCZOS).save(OUT / "cover_630x500.png")


def banner() -> None:
    """960 wide (itch's widest), transparent: it replaces the page's title."""
    W, H = 960, 250
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = title_image(880)
    im.paste(t, ((W - t.width) // 2, (H - t.height) // 2 + 4), t)
    im.save(OUT / "banner_960.png")


def background(shots: Path) -> None:
    """The page behind the column: the hallway, almost gone to black."""
    W, H = 2560, 1440
    src = Image.open(shots / "01_hallway.png").convert("RGB").crop((90, 0, 1350, 700))  # (no HUD)
    im = src.resize((W, H), Image.NEAREST).filter(ImageFilter.GaussianBlur(3))
    a = np.array(im).astype(float) * 0.42
    gray = a.mean(axis=2, keepdims=True)
    a = gray + (a - gray) * 0.55  # (the colour drained)
    im = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    im = scanlines(vignette(im, 0.95), 0.35, 4)
    im.save(OUT / "background_2560x1440.jpg", quality=88)


def noise_frame(size: tuple, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    w, h = size
    n = rng.integers(0, 200, (h // 2, w // 2), dtype=np.uint8)
    rows = rng.integers(0, 60, (h // 2, 1), dtype=np.uint8)
    n = np.clip(n.astype(int) + rows, 0, 255).astype(np.uint8)
    return Image.fromarray(n, "L").resize(size, Image.NEAREST).convert("RGB")


def gif(shots: Path, name: str, frames: list) -> None:
    size = (640, 360)
    ims, durs = [], []
    for i, (f, ms) in enumerate(frames):
        im = noise_frame(size, i) if f == "noise" else Image.open(shots / (f + ".png")).convert("RGB").resize(size, Image.LANCZOS)
        ims.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
        durs.append(ms)
    ims[0].save(OUT / "gifs" / (name + ".gif"), save_all=True, append_images=ims[1:], duration=durs, loop=0, optimize=True)


def pages() -> None:
    page = ROOT / "itch_page"
    desc = (page / "description.html").read_text(encoding="utf-8")
    body = desc.split("<!-- DESCRIPTION START -->")[1].split("<!-- DESCRIPTION END -->")[0].strip()
    html = (page / "preview_template.html").read_text(encoding="utf-8").replace("{{DESCRIPTION}}", body)
    (page / "preview.html").write_text(html, encoding="utf-8")
    print("written itch_page/preview.html")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    if sys.argv[1] == "--pages":
        pages()
        return
    shots = Path(sys.argv[1])
    for sub in ["", "screenshots", "gifs"]:
        (OUT / sub).mkdir(parents=True, exist_ok=True)
    cover(shots)
    banner()
    background(shots)
    for src, dst in SCREENSHOTS:
        shutil.copyfile(shots / (src + ".png"), OUT / "screenshots" / (dst + ".png"))
    gif(shots, "only_the_camera", [("08_naked_eye", 1300), ("noise", 70), ("09_camcorder", 1700), ("noise", 70)])
    gif(shots, "the_show_goes_wrong", [("03_tv_show", 1400), ("03b_tv_stare", 800), ("03c_tv_live", 600),
                                        ("03d_tv_dark", 600), ("03e_tv_live_close", 600), ("03f_tv_live_runs", 700),
                                        ("noise", 80), ("noise", 80), ("04_tv_alert", 2600)])
    for p in sorted(OUT.rglob("*.*")):
        print("%-48s %7.0f KB" % (p.relative_to(OUT), p.stat().st_size / 1024))
    pages()


if __name__ == "__main__":
    main()
