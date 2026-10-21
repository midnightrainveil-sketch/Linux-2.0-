#!/usr/bin/env python3
"""The month's pressed specimen, from a sheet of twelve drawings.

    python3 tools/import_specimens.py art/specimens/sheet.png

The sheet is four drawings across and three down, January to December in
reading order (the prompt in art/specimens/README.md). Each drawing is cut
out of its cell, its white taken out as if it were ink on a clear sheet
(like the portrait, tools/import_portrait.py), trimmed to the drawing and
made 480 px tall. Writes dotfiles/.config/quickshell/assets/specimens/01.png
... 12.png; the wallpaper lays the month's in the corner of the sheet, with
its name from specimens.json there.
"""
import pathlib
import sys

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
DST = ROOT / "dotfiles" / ".config" / "quickshell" / "assets" / "specimens"
HEIGHT = 480
COLS, ROWS = 4, 3


def colour_to_alpha(rgb):
    c = rgb.astype(np.float32) / 255.0
    a = np.clip((1.0 - c).max(axis=2), 0, 1)
    a = np.clip((a - 0.04) / (1 - 0.04), 0, 1)     # paper speckle is not ink
    safe = np.maximum(a, 1e-4)[..., None]
    col = np.clip(1.0 - (1.0 - c) / safe, 0, 1)
    return np.dstack([col * 255, a * 255]).astype(np.uint8)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sheet = Image.open(sys.argv[1]).convert("RGB")
    W, H = sheet.size
    DST.mkdir(parents=True, exist_ok=True)
    for i in range(COLS * ROWS):
        cx, cy = i % COLS, i // COLS
        # each cell, less a margin so a neighbour's stray stroke stays out
        mx, my = W / COLS * 0.03, H / ROWS * 0.03
        box = (round(cx * W / COLS + mx), round(cy * H / ROWS + my),
               round((cx + 1) * W / COLS - mx), round((cy + 1) * H / ROWS - my))
        rgba = Image.fromarray(colour_to_alpha(np.asarray(sheet.crop(box))), "RGBA")
        bbox = rgba.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
        if not bbox:
            print("cell %d is empty" % (i + 1))
            continue
        rgba = rgba.crop(bbox)
        w, h = rgba.size
        rgba = rgba.resize((max(1, round(w * HEIGHT / h)), HEIGHT), Image.Resampling.LANCZOS)
        out = DST / ("%02d.png" % (i + 1))
        rgba.save(out, optimize=True)
        print("specimen:", out.relative_to(ROOT), rgba.size)


if __name__ == "__main__":
    main()
