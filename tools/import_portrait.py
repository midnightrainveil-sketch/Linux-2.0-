#!/usr/bin/env python3
"""The desk terminal's portrait, from the artwork.

    python3 tools/import_portrait.py [art/portrait/meadow.webp]

The picture is drawn on white. The white is taken out as if the drawing
were ink on a clear sheet ("colour to alpha": each pixel keeps the colour
that, laid over white, gives what was drawn, with as much transparency as
the white allowed), so it can be printed onto the terminal's own paper by
day and turned into a cyanotype by night (archive-card does both).

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
    rgba = rgba.resize((round(w * HEIGHT / h), HEIGHT), Image.Resampling.LANCZOS)
    rgba.save(DST, optimize=True)
    print("portrait:", DST.relative_to(ROOT), rgba.size)


if __name__ == "__main__":
    main()
