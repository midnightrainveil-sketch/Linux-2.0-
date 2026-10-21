#!/usr/bin/env python3
"""The month's pressed specimen, from a sheet of twelve drawings.

    python3 tools/import_specimens.py art/specimens/sheet.png

The sheet is four drawings across and three down, January to December in
reading order (the prompt in art/specimens/README.md). Each drawing is cut
out along the white gaps between them (a plain grid if the gaps cannot be
found), its white taken out as if it were ink on a clear sheet (like the
portrait, tools/import_portrait.py), its colour faded to a century-old
pressing, trimmed to the drawing and made at most 480 px tall. Writes dotfiles/.config/quickshell/assets/specimens/01.png
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
SATURATION = 0.42      # how much of the drawing's colour a pressing keeps


def colour_to_alpha(rgb):
    c = rgb.astype(np.float32) / 255.0
    a = np.clip((1.0 - c).max(axis=2), 0, 1)
    a = np.clip((a - 0.04) / (1 - 0.04), 0, 1)     # paper speckle is not ink
    safe = np.maximum(a, 1e-4)[..., None]
    col = np.clip(1.0 - (1.0 - c) / safe, 0, 1)
    grey = (col * [0.299, 0.587, 0.114]).sum(axis=2, keepdims=True)
    col = grey + (col - grey) * SATURATION
    return np.dstack([col * 255, a * 255]).astype(np.uint8)


def bands(ink, n, min_gap):
    """n runs of ink along one axis, split at the n-1 widest blank gaps."""
    idx = np.flatnonzero(ink)
    if idx.size == 0:
        return None
    gaps = [(idx[i + 1] - idx[i], i) for i in range(idx.size - 1) if idx[i + 1] - idx[i] > min_gap]
    if len(gaps) < n - 1:
        return None
    cuts = sorted(i for _, i in sorted(gaps, reverse=True)[:n - 1])
    out, start = [], idx[0]
    for i in cuts:
        out.append((start, idx[i] + 1))
        start = idx[i + 1]
    out.append((start, idx[-1] + 1))
    return out


def cells(rgb):
    """The twelve boxes, January first: along the white gaps, else a grid."""
    H, W = rgb.shape[:2]
    ink = (255 - rgb.min(axis=2)) > 28
    rows = bands(ink.sum(axis=1) > 2, ROWS, 4)
    boxes = []
    for r in rows or []:
        cols = bands(ink[r[0]:r[1]].sum(axis=0) > 1, COLS, 4)
        if not cols:
            break
        boxes += [(c[0], r[0], c[1], r[1]) for c in cols]
    if len(boxes) == COLS * ROWS:
        return [(max(0, x0 - 6), max(0, y0 - 6), min(W, x1 + 6), min(H, y1 + 6)) for x0, y0, x1, y1 in boxes]
    print("(no clear gaps between the drawings: cutting a plain grid)")
    mx, my = W / COLS * 0.03, H / ROWS * 0.03
    return [(round(cx * W / COLS + mx), round(cy * H / ROWS + my),
             round((cx + 1) * W / COLS - mx), round((cy + 1) * H / ROWS - my))
            for cy in range(ROWS) for cx in range(COLS)]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sheet = Image.open(sys.argv[1]).convert("RGB")
    DST.mkdir(parents=True, exist_ok=True)
    for i, box in enumerate(cells(np.asarray(sheet))):
        rgba = Image.fromarray(colour_to_alpha(np.asarray(sheet.crop(box))), "RGBA")
        bbox = rgba.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
        if not bbox:
            print("cell %d is empty" % (i + 1))
            continue
        rgba = rgba.crop(bbox)
        w, h = rgba.size
        if h > HEIGHT:
            rgba = rgba.resize((max(1, round(w * HEIGHT / h)), HEIGHT), Image.Resampling.LANCZOS)
        out = DST / ("%02d.png" % (i + 1))
        rgba.save(out, optimize=True)
        print("specimen:", out.relative_to(ROOT), rgba.size)


if __name__ == "__main__":
    main()
