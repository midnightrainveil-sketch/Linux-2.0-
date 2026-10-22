#!/usr/bin/env python3
"""The lock screen's wax seal, from a photograph-like picture of one.

    python3 tools/import_seal.py art/seal/seal.webp

The picture: one wax seal seen from above on plain white (the prompt in
art/seal/README.md). The wax is told from the paper by its colour (red, not
grey), the highlights inside it kept (whatever the paper does not reach
from the picture's edge is wax), its shadow kept as a soft translucent
shadow, and the seal centred and made 520 px across. Writes
dotfiles/.config/quickshell/assets/seal/seal.png; the lock screen
(modules/lock/WaxSeal.qml) presses it, cracks it and lets the halves fall.
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
DST = ROOT / "dotfiles" / ".config" / "quickshell" / "assets" / "seal" / "seal.png"
SIZE = 520           # the picture, square; the seal itself fills about 86 % of it


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    im = Image.open(sys.argv[1]).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    red = r - np.maximum(g, b)                       # the wax is red; paper and its shadow are grey

    # the wax: red enough, its holes (white highlights) filled: the paper is
    # whatever is reached from the picture's edge without crossing wax
    wax = Image.fromarray(((red > 28) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    paper = wax.copy()
    w, h = paper.size
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if paper.getpixel(seed) == 0:
            ImageDraw.floodfill(paper, seed, 128)
    inside = np.asarray(paper) != 128
    mask = Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))       # a soft, not stepped, edge
    m = np.asarray(mask).astype(np.float32) / 255

    # its shadow on the paper: how much darker than the paper it is
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    ref = np.percentile(lum[~inside], 90)
    shadow = np.clip((ref - lum) / ref * 2.2, 0, 0.55) * (1 - m)

    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., :3] = a * m[..., None]                 # the wax; black under the shadow
    rgba[..., 3] = np.clip(m + shadow, 0, 1) * 255
    out = Image.fromarray(rgba.astype(np.uint8), "RGBA")

    # centred on the wax (the shadow may run off to one side), with room round it
    ys, xs = np.nonzero(m > 0.5)
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    half = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2 / 0.86
    box = tuple(round(v) for v in (cx - half, cy - half, cx + half, cy + half))
    out = out.crop(box).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    DST.parent.mkdir(parents=True, exist_ok=True)
    out.save(DST, optimize=True)
    print("seal:", DST.relative_to(ROOT), out.size)


if __name__ == "__main__":
    main()
