#!/usr/bin/env python3
"""Turn art/wallpaper.webp into the starter plate: the whole sheet, by day
and as a cyanotype by night.

    python3 tools/import_wallpaper.py [image]

The source is, in order: the image given, your own wallpaper kept outside the
theme (~/.config/archive/wallpaper.*, set by archive-wallpaper, so updates
never replace it), or the theme's art/wallpaper.webp.

The wallpaper is used as drawn, with its own typed header, labels, stamp and
tape, so the shell types nothing over it (meta.json "sheet": true).

  sheet-day.jpg    the sheet, sized to cover the screen and toned to the
                   desk's grey paper
  sheet-night.jpg  the same sheet printed as a cyanotype: Prussian-blue paper,
                   the drawing and type in pale cream, the paper's own
                   mottling and specks kept
  meta.json        names and the plate number, for the shell's other cards

The screen crops the sheet to fill (the G14 is 16:10, the art 16:9): a little
of each side goes, never the plant. Requires: python3, numpy, pillow.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
THEME_SRC = os.path.join(HERE, "..", "art", "wallpaper.webp")
USER_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "archive")


def source():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if args:
        return args[0]
    for ext in ("png", "jpg", "jpeg", "webp"):
        mine = os.path.join(USER_DIR, "wallpaper." + ext)
        if os.path.exists(mine):
            return mine
    return THEME_SRC
THEME_OUT = os.path.join(HERE, "..", "dotfiles", ".local", "share", "archive", "plates")
# where the shell reads plates from; your own wallpaper is written straight
# there (real files, not links into the theme), so nothing can stand between
DATA_OUT = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "archive", "plates")
PLATE = "0001-geranium-pratense"
# other themes' sheets (python3 tools/import_wallpaper.py --plate night-service):
# made from their own art, kept out of the herbarium's daily round (they are
# not added to index.json); the theme names its plate (theme.json "flavour")
OTHER_PLATES = {
    "night-service": {
        # (the keepsakes spread over the desk, laid out by
        # tools/compose_night_service.py from the 4K plate wallpaper.webp)
        "src": os.path.join(HERE, "..", "art", "night-service", "composed.webp"),
        "plate": "0101-night-service",
        # its colour and contrast as drawn: only the paper is matched to the desk
        "quieten": False,
        "meta": {"number": "0019", "region": "COMPARTMENT 19", "latin": "Vienna – Venice",
                 "authority": "Night train, 14–15 June 1931.", "family": "Carriage 4",
                 "common": "Compartment 19, lower berth."},
    },
}
# the sheet is sized to cover the G14's 2880 x 1800 panel (a 16:9 sheet:
# 3200 x 1800), up or down from whatever the source is
COVER = (2880, 1800)

# the desk's paper (Theme.paperBase is c9c7c3; the reference desk reads about
# cbc9c5 around the plate) and the night sheet's colours (Theme.nite)
DAY_PAPER = np.array([203, 201, 197], np.float32)
NIGHT_PAPER = np.array([0x1c, 0x2f, 0x4d], np.float32)
NIGHT_INK = np.array([0xe6, 0xe1, 0xd6], np.float32)
# the paper's own texture, quietened to the desk's calm grey sheet: how much
# of the colour of its flecks and fibres stays (the blue stamp keeps all of
# its own), and how much of its grain (the drawing and type are untouched)
FLECK_COLOUR = 0.35
PAPER_GRAIN = 0.5
# the drawing in soft pencil grey, never black: the darkest ink (all but
# the darkest half percent) lifted to this if a picture draws darker; and
# the stamp's blue, a little quieter than printed
INK_FLOOR = 92.0
STAMP_COLOUR = 0.8
STAMP_LIFT = 0.22      # the stamp's ink a little toward the paper, faded as an old stamp is


def quieten(big):
    """The paper's flecks greyed and its grain softened; ink, type and the
    blue stamp as drawn."""
    rgb = np.asarray(big, np.float32)
    lum = rgb.mean(axis=2, keepdims=True)
    # colour: pulled toward grey, except blues (the stamp, any blue ink)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    blue = np.clip((b - np.maximum(r, g)) / 40.0, 0, 1)[..., None]
    keep = FLECK_COLOUR + (1 - FLECK_COLOUR) * blue
    rgb = lum + (rgb - lum) * keep
    # grain: the paper's small ups and downs eased toward its smooth level;
    # ink (well below the paper) is left alone
    gray = Image.fromarray(np.clip(rgb.mean(axis=2), 0, 255).astype(np.uint8))
    level = np.asarray(gray.filter(ImageFilter.MedianFilter(9)).filter(ImageFilter.GaussianBlur(3)), np.float32)[..., None]
    smooth = np.asarray(Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)), np.float32)
    depth = np.clip((level - rgb.mean(axis=2, keepdims=True)) / 28.0, 0, 1)   # 0 paper .. 1 ink
    paper = (1 - depth) * (1 - PAPER_GRAIN)
    rgb = rgb * (1 - paper) + smooth * paper
    # ink: grey pencil lines lifted toward the paper so the darkest is
    # INK_FLOOR (a picture drawn that light already is left as it is)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    blue = np.clip((b - np.maximum(r, g)) / 40.0, 0, 1)[..., None]
    paper_rgb = np.median(rgb.reshape(-1, 3), axis=0)
    lum = rgb.mean(axis=2)
    darkest = np.percentile(lum[blue[..., 0] < 0.5], 0.5)
    paper_l = float(paper_rgb.mean())
    if darkest < INK_FLOOR < paper_l:
        k = (paper_l - INK_FLOOR) / (paper_l - darkest)
        lifted = paper_rgb + (rgb - paper_rgb) * k
        rgb = rgb * blue + lifted * (1 - blue)          # the stamp keeps its depth
    # the stamp: its blue a little quieter, and faded a little
    lum = rgb.mean(axis=2, keepdims=True)
    stamp = lum + (rgb - lum) * STAMP_COLOUR
    stamp = stamp + (paper_rgb - stamp) * STAMP_LIFT
    rgb = rgb * (1 - blue) + stamp * blue
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))


def is_theme_copy():
    """Is your wallpaper (~/.config/archive/wallpaper.*) just a copy of the
    theme's own sheet, this one or an earlier version of it? Compared small
    and grey: the same drawing reads alike, a picture of your own does not."""
    mine = source()
    if mine == THEME_SRC or not os.path.exists(THEME_SRC):
        return False
    def small(path):
        im = Image.open(path).convert("L")
        w, h = im.size
        s = min(w / 16, h / 9)
        im = im.crop(((w - 16 * s) / 2, (h - 9 * s) / 2, (w + 16 * s) / 2, (h + 9 * s) / 2)).resize((96, 54), Image.LANCZOS)
        a = np.asarray(im, np.float32)
        return (a - a.mean()) / (a.std() + 1e-3)
    try:
        return float(np.abs(small(mine) - small(THEME_SRC)).mean()) < 0.35
    except OSError:
        return False


def retitle(src, t):
    """The sheet's heading typed again: its box covered with the sheet's own
    blank paper, the new words typed in a typewriter face, dark as the rest."""
    from PIL import ImageFont
    k = src.width / 3840
    x0, y0, x1, y1 = (round(v * k) for v in t["box"])
    px, py = (round(v * k) for v in t["paper"])
    src = src.copy()
    src.paste(src.crop((px, py, px + x1 - x0, py + y1 - y0)), (x0, y0))
    font = ImageFont.truetype(os.path.join(HERE, "..", "dotfiles", ".local", "share", "fonts", "archive", "CourierPrime-Regular.ttf"), round(t["size"] * k))
    d = ImageDraw.Draw(src)
    x, y = (round(v * k) for v in t["at"])
    step = font.getlength("M") * (1 + t["tracking"])
    for ch in t["text"]:
        d.text((x, y), ch, font=font, fill=(34, 33, 36), stroke_width=max(1, round(0.6 * k)), stroke_fill=(52, 50, 54))
        x += step
    return src


def refit(src, fit):
    """The art laid smaller at (cx, cy) of a sheet of its own paper: a blank
    strip of it (fit["paper"]) mirrored across, the art feathered into it."""
    W, H = src.size
    px0, py0, px1, py1 = (round(v * (W if i % 2 == 0 else H)) for i, v in enumerate(fit["paper"]))
    strip = src.crop((px0, py0, px1, py1))
    paper = Image.new("RGB", (W, H))
    x, flip = 0, False
    while x < W:
        piece = strip.transpose(Image.FLIP_LEFT_RIGHT) if flip else strip
        paper.paste(piece.resize((piece.width, H)), (x, 0))
        x += piece.width
        flip = not flip
    k = fit["scale"]
    art = src.resize((round(W * k), round(H * k)), Image.LANCZOS)
    mask = Image.new("L", art.size, 0)
    # (a narrow feather: the art's own edge is blank paper, and its heading
    # sits close to the top)
    m = round(6 * W / 2000)
    ImageDraw.Draw(mask).rectangle([0, 0, art.width, art.height], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(m))
    paper.paste(art, (round(W * fit["cx"] - art.width / 2), round(H * fit["cy"] - art.height / 2)), mask)
    return paper


def main():
    global PLATE
    if "--is-theme-copy" in sys.argv:
        sys.exit(0 if is_theme_copy() else 1)
    other = None
    if "--plate" in sys.argv:
        other = OTHER_PLATES[sys.argv[sys.argv.index("--plate") + 1]]
        PLATE = other["plate"]
        path, out = other["src"], THEME_OUT
    else:
        path = source()
        out = THEME_OUT if path == THEME_SRC else DATA_OUT
    src = Image.open(path).convert("RGB")
    if other and other.get("retitle"):
        src = retitle(src, other["retitle"])
    if other and other.get("fit"):
        src = refit(src, other["fit"])
    print("wallpaper:", path, "(%d x %d)" % src.size)
    scale = max(COVER[0] / src.width, COVER[1] / src.height)
    big = src.resize((round(src.width * scale), round(src.height * scale)), Image.LANCZOS)
    if scale > 1.05:   # enlarged: bring the pencil lines back a little
        big = big.filter(ImageFilter.UnsharpMask(radius=1.4, percent=55, threshold=2))
    if not other or other.get("quieten", True):
        big = quieten(big)
    rgb = np.asarray(big, np.float32)

    # the paper's own colour, everywhere (the ink lifted out of it)
    gray = big.convert("L")
    paper_l = np.asarray(gray.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(24)), np.float32)
    paper_rgb = np.median(rgb.reshape(-1, 3), axis=0)

    # ---- day: tone the sheet so its paper matches the desk
    gain = DAY_PAPER / paper_rgb
    day = np.clip(rgb * gain, 0, 255).astype(np.uint8)

    # ---- night: a cyanotype print of the same sheet
    lum = rgb.mean(axis=2)
    paper_l = np.maximum(paper_l, lum)
    ink = np.clip((paper_l - lum) / np.maximum(paper_l, 1), 0, 1)       # 0 paper .. 1 solid ink
    ink = np.clip(ink * 1.25, 0, 1) ** 0.85
    # the paper's mottling, carried over as a faint unevenness of the blue
    mottle = (paper_l - paper_l.mean()) / 255.0
    base = NIGHT_PAPER[None, None, :] * (1 + 0.9 * mottle[..., None])
    night = base * (1 - ink[..., None]) + NIGHT_INK[None, None, :] * ink[..., None]
    night = np.clip(night, 0, 255).astype(np.uint8)

    folder = os.path.join(out, PLATE)
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):
        if name.endswith(".png") or name.startswith("sheet-"):
            os.remove(os.path.join(folder, name))
    Image.fromarray(day).save(os.path.join(folder, "sheet-day.jpg"), quality=90, optimize=True, progressive=True)
    Image.fromarray(night).save(os.path.join(folder, "sheet-night.jpg"), quality=90, optimize=True, progressive=True)

    meta = {
        "number": "0001",
        "region": "FLORA EUROPAEA",
        "latin": "Geranium pratense",
        "authority": "Linnaeus, 1753.",
        "family": "Geraniaceae",
        "common": "European meadow cranesbill.",
        # the whole sheet is the wallpaper: the shell types no labels over it
        "sheet": True,
        "day": "sheet-day.jpg",
        "night": "sheet-night.jpg",
    }
    if other:
        meta.update(other["meta"])
    meta_path = os.path.join(folder, "meta.json")
    if os.path.islink(meta_path):
        os.remove(meta_path)   # a real file of its own, not the theme's through a link
    with open(meta_path, "w") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")

    if other:
        print("sheet written:", folder, "(%d x %d)" % (day.shape[1], day.shape[0]))
        return
    index_path = os.path.join(out, "index.json")
    index = json.load(open(index_path)) if os.path.exists(index_path) else []
    if os.path.islink(index_path):
        os.remove(index_path)
    if PLATE not in index:
        index.append(PLATE)
    with open(index_path, "w") as f:
        json.dump(sorted(index), f, indent=2)
        f.write("\n")
    print("sheet written:", folder, "(%d x %d)" % (day.shape[1], day.shape[0]))


if __name__ == "__main__":
    main()
