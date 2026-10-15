#!/usr/bin/env python3
"""The desk terminal's portrait, from the artwork.

    python3 tools/import_portrait.py [art/portrait/meadow.webp]

The picture is drawn on white. The white is taken out as if the drawing
were ink on a clear sheet ("colour to alpha": each pixel keeps the colour
that, laid over white, gives what was drawn, with as much transparency as
the white allowed), so it can be printed onto the terminal's own paper by
day and turned into a cyanotype by night (archive-card does both).

Then it is trimmed into the meadow's edge (TRIM), the cut feathered.

Writes dotfiles/.config/fastfetch/portrait.png (RGBA, 600 px tall).
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "portrait" / "meadow.webp"
DST = ROOT / "dotfiles" / ".config" / "fastfetch" / "portrait.png"
HEIGHT = 600
# then trimmed in from each side (fractions of the drawing: left, top, right,
# bottom), into the meadow's ragged edge, so the girl fills more of the
# card; the cut is feathered, the grass fading out like ink run dry
TRIM = (0.06, 0.02, 0.06, 0.0)
FEATHER = 0.12         # how far in from the cut the grass starts fading
ROUND = 3.2            # the cut's shape: 2 an ellipse, higher squarer


def colour_to_alpha(rgb):
    c = rgb.astype(np.float32) / 255.0
    # how far from white: the most any channel had to be darkened
    a = np.clip((1.0 - c).max(axis=2), 0, 1)
    # the paper's own speckle and the faintest wash are not ink
    a = np.clip((a - 0.035) / (1 - 0.035), 0, 1)
    safe = np.maximum(a, 1e-4)[..., None]
    col = np.clip(1.0 - (1.0 - c) / safe, 0, 1)
    return np.dstack([col * 255, a * 255]).astype(np.uint8)


def main():
    src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else SRC
    im = Image.open(src).convert("RGB")
    rgba = Image.fromarray(colour_to_alpha(np.asarray(im)), "RGBA")
    # trimmed to the drawing, with a hair of room
    box = rgba.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    rgba = rgba.crop(box)
    w, h = rgba.size
    l, t, r, b = TRIM
    rgba = rgba.crop((round(w * l), round(h * t), round(w * (1 - r)), round(h * (1 - b))))
    w, h = rgba.size
    # the cut follows a rounded oblong (a superellipse), wavering like the
    # meadow's own edge, and fades out over its last stretch
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = (xs + 0.5) / w * 2 - 1, (ys + 0.5) / h * 2 - 1
    d = (np.abs(u) ** ROUND + np.abs(v) ** ROUND) ** (1 / ROUND)
    ang = np.arctan2(v, u)
    rng = np.random.default_rng(7)
    waver = sum(rng.uniform(0.004, 0.012) * np.sin(k * ang + rng.uniform(0, 6.3)) for k in (5, 9, 14, 23, 37))
    fade = np.clip((1.0 + waver - d) / FEATHER, 0, 1) ** 1.4
    px = np.asarray(rgba).astype(np.float32)
    px[..., 3] *= fade
    rgba = Image.fromarray(px.round().astype(np.uint8), "RGBA")
    rgba = rgba.resize((round(w * HEIGHT / h), HEIGHT), Image.Resampling.LANCZOS)
    rgba.save(DST, optimize=True)
    print("portrait:", DST.relative_to(ROOT), rgba.size)


if __name__ == "__main__":
    main()
