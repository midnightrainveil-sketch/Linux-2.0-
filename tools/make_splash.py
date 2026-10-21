#!/usr/bin/env python3
"""The start-up and shut-down page (a Plymouth theme), drawn from the theme.

    python3 tools/make_splash.py

Writes the pictures of system/plymouth/archive/: the paper (a small sheet,
stretched to the screen: only soft light on it, no grain to blur), the
archive's watercolour sprig, the typed heading and the line under it for
each occasion (opening, closing, turning the page), and the passphrase
prompt with its typed x. The script (archive.script) lays them out.
"""
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
DST = ROOT / "system" / "plymouth" / "archive"
FONTS = ROOT / "dotfiles" / ".local" / "share" / "fonts" / "archive"
SPRIG = ROOT / "dotfiles" / ".config" / "quickshell" / "assets" / "sprig-wash.png"

PAPER = (0xC9, 0xC7, 0xC3)
GRAPHITE = (0x1E, 0x1D, 0x22)
SOFT = (0x3E, 0x3D, 0x42)
RULE = (0x4A, 0x49, 0x50)
SPRIG_INK = (0x4F, 0x5A, 0x86)   # the clock card's sprig
SCALE = 1.5                  # drawn for the G14's 1.5 scale; the script fits other screens


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), round(size * SCALE))


def typed(text, f, colour, tracking=0.0):
    """A line of type on a clear ground, letter-spaced like the cards' titles."""
    extra = round(f.size * tracking)
    widths = [f.getlength(ch) for ch in text]
    w = round(sum(widths) + extra * (len(text) - 1)) + 4
    asc, desc = f.getmetrics()
    im = Image.new("RGBA", (w, asc + desc + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = 2
    for ch, cw in zip(text, widths):
        d.text((x, 2), ch, font=f, fill=colour + (255,))
        x += cw + extra
    return im


def paper():
    """The sheet: the shell's paper with Folio's light and vignette (as in
    modules/background/Plate.qml, at its 80 %)."""
    w, h = 960, 600
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    nx, ny = x / w - 0.5, y / h - 0.5
    # the vignette: clear to 0.36 of the way out, 0.144 at 0.72, 0.352 at the rim
    r = np.sqrt((nx / 0.78) ** 2 + (ny / 0.82) ** 2)
    shade = np.interp(r, [0, 0.36, 0.72, 1.0, 2.0], [0, 0, 0.144, 0.352, 0.352])
    # daylight from the top left
    lr = np.sqrt(((nx + 0.28) / 0.75) ** 2 + ((ny + 0.30) / 0.9) ** 2)
    light = np.clip(1 - lr, 0, 1) * 0.128
    base = np.array(PAPER, np.float32) / 255
    ink = np.array((0.12, 0.11, 0.13), np.float32)
    c = base[None, None, :] * (1 - shade[..., None]) + ink * shade[..., None]
    c = c + (1 - c) * light[..., None]
    # dithered a touch, so the stretched gradient does not band
    c = c + (np.random.default_rng(7).random(c.shape, np.float32) - 0.5) / 255
    return Image.fromarray(np.clip(c * 255, 0, 255).astype(np.uint8), "RGB")


def ruled(width, seed):
    """A hand-ruled line, as on the cards: 2 px with a small wobble."""
    rng = np.random.default_rng(seed)
    h = 8
    im = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    big = im.resize((width * 4, h * 4))
    d = ImageDraw.Draw(big)
    pts, y = [], h * 2
    for i in range(15):
        pts.append((i * (width * 4 - 1) / 14, y + rng.uniform(-1.6, 1.6)))
    d.line(pts, fill=RULE + (255,), width=round(2.0 * SCALE * 4 / 1.5), joint="curve")
    return big.resize((width, h), Image.LANCZOS)


def main():
    DST.mkdir(parents=True, exist_ok=True)
    paper().save(DST / "paper.png", optimize=True)

    sprig = Image.open(SPRIG).convert("RGBA")
    sprig = Image.merge("RGBA", [Image.new("L", sprig.size, v) for v in SPRIG_INK] + [sprig.getchannel("A")])
    th = round(250 * SCALE)
    sprig.resize((round(sprig.width * th / sprig.height), th), Image.LANCZOS).save(DST / "sprig.png", optimize=True)

    head = font("CourierPrime-Bold.ttf", 22)
    line = font("CourierPrime-Italic.ttf", 17)
    typed("ROYAL BOTANIC ARCHIVE", head, GRAPHITE, 0.16).save(DST / "heading.png", optimize=True)
    for name, text in (("boot", "Opening the herbarium."),
                       ("shutdown", "Closing the archive."),
                       ("reboot", "Turning the page."),
                       ("updates", "Filing new records.")):
        typed(text, line, SOFT).save(DST / ("line-%s.png" % name), optimize=True)
    ruled(round(300 * SCALE), 11).save(DST / "rule.png", optimize=True)

    # the passphrase (an encrypted disk): the greeter's words and its typed x
    typed("Signature required.", line, SOFT).save(DST / "prompt.png", optimize=True)
    typed("x", font("CourierPrime-Regular.ttf", 18), GRAPHITE).save(DST / "bullet.png", optimize=True)
    for p in sorted(DST.glob("*.png")):
        print("splash:", p.relative_to(ROOT), Image.open(p).size)


if __name__ == "__main__":
    main()
