#!/usr/bin/env python3
"""Turn the artwork in art/ into the shell's assets.

    python3 tools/import_art.py

art/sprig.webp     -> assets/sprig-wash.png          (the Time Record's twig)
art/icons.webp     -> assets/icons/<name>.png        (a row of 10 icons, left to right)
art/weather.webp   -> assets/weather/<name>.png      (a 3 x 3 grid, row by row)
art/wallpaper.webp -> the plate (see tools/import_wallpaper.py)

The source art is ink on a white (not transparent) ground. Each image becomes
black ink with alpha, so the shell can tint it graphite by day and pale at
night. Requires: python3, numpy, pillow.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "art")
ASSETS = os.path.join(HERE, "..", "dotfiles", ".config", "quickshell", "assets")

ICONS = ["seedling", "screen", "screen-night", "speaker", "speaker-loud", "speaker-muted",
         "wifi", "wifi-none", "wifi-off", "record"]
WEATHER = ["overcast", "clear", "clear-night",
           "partly", "partly-night", "fog",
           "rain", "snow", "storm"]


def ink_alpha(img, floor=0.04, gamma=0.9):
    """Darkness relative to the local paper white, as 0..1 alpha."""
    g = np.asarray(img.convert("L"), np.float32) / 255
    paper = np.asarray(img.convert("L").filter(ImageFilter.MaxFilter(31)).filter(ImageFilter.GaussianBlur(20)), np.float32) / 255
    paper = np.maximum(paper, g)
    a = np.clip((paper - g) / np.maximum(paper, 0.2), 0, 1)
    a = np.clip((a - floor) / (1 - floor), 0, 1) ** gamma
    return a


def save_alpha(a, path, size=None, pad=0.06, square=True, box=None):
    """Crop to the ink (or to `box`), pad, optionally square, write black + alpha."""
    if box is None:
        ys, xs = np.nonzero(a > 0.05)
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    x0, y0, x1, y1 = box
    a = a[y0:y1, x0:x1]
    h, w = a.shape
    side_w, side_h = (max(w, h), max(w, h)) if square else (w, h)
    pw, ph = int(side_w * (1 + 2 * pad)), int(side_h * (1 + 2 * pad))
    canvas = np.zeros((ph, pw), np.float32)
    ox, oy = (pw - w) // 2, (ph - h) // 2
    canvas[oy:oy + h, ox:ox + w] = a
    img = Image.fromarray((canvas * 255).astype(np.uint8))
    if size:
        img = img.resize(size, Image.LANCZOS)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.putalpha(img)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, optimize=True)


def runs(mask_1d, min_gap):
    """Spans of True separated by gaps of at least `min_gap`."""
    idx = np.nonzero(mask_1d)[0]
    if len(idx) == 0:
        return []
    spans, start, prev = [], idx[0], idx[0]
    for i in idx[1:]:
        if i - prev > min_gap:
            spans.append((start, prev + 1))
            start = i
        prev = i
    spans.append((start, prev + 1))
    return spans


def main():
    # ---- the twig
    # the drawing is finer than the reference twig, so its wash is deepened
    a = ink_alpha(Image.open(os.path.join(ART, "sprig.webp")), floor=0.03, gamma=0.8)
    a = np.clip(a * 1.9, 0, 1)
    save_alpha(a, os.path.join(ASSETS, "sprig-wash.png"), square=False, pad=0.02)
    print("sprig-wash.png")

    # ---- icons: one row, cut at the wide gaps between them
    a = ink_alpha(Image.open(os.path.join(ART, "icons.webp")), floor=0.05)
    # icons are shown at about a seventh of their drawn size: thicken the
    # strokes first so they survive as a firm pencil line at 20 px
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)), np.float32) / 255
    cols = runs((a > 0.15).any(axis=0), min_gap=25)
    if len(cols) != len(ICONS):
        raise SystemExit(f"icons: found {len(cols)} icons, expected {len(ICONS)}")
    boxes = []
    for x0, x1 in cols:
        sub = a[:, x0:x1] > 0.15
        ys = np.nonzero(sub.any(axis=1))[0]
        boxes.append((x0, ys.min(), x1, ys.max() + 1))
    # one common square, so every icon keeps the same stroke weight and scale
    side = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes)
    for name, (x0, y0, x1, y1) in zip(ICONS, boxes):
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        half = side // 2 + 6
        save_alpha(a, os.path.join(ASSETS, "icons", name + ".png"), size=(96, 96), pad=0.0,
                   box=(max(0, cx - half), max(0, cy - half), cx + half, cy + half))
    print("icons:", ", ".join(ICONS))

    # ---- weather: a 3 x 3 grid
    a = ink_alpha(Image.open(os.path.join(ART, "weather.webp")), floor=0.06)
    rows = runs((a > 0.12).any(axis=1), min_gap=40)
    if len(rows) != 3:
        raise SystemExit(f"weather: found {len(rows)} rows, expected 3")
    cells = []
    for y0, y1 in rows:
        cols = runs((a[y0:y1] > 0.12).any(axis=0), min_gap=40)
        if len(cols) != 3:
            raise SystemExit(f"weather: a row has {len(cols)} sketches, expected 3")
        cells += [(x0, y0, x1, y1) for x0, x1 in cols]
    side = max(max(c[2] - c[0], c[3] - c[1]) for c in cells)
    for name, (x0, y0, x1, y1) in zip(WEATHER, cells):
        sub = a[y0:y1, x0:x1] > 0.12
        ys, xs = np.nonzero(sub)
        bx0, by0, bx1, by1 = x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1
        cx, cy = (bx0 + bx1) // 2, (by0 + by1) // 2
        half = side // 2 + 8
        save_alpha(a, os.path.join(ASSETS, "weather", name + ".png"), size=(256, 256), pad=0.0,
                   box=(max(0, cx - half), max(0, cy - half), min(a.shape[1], cx + half), min(a.shape[0], cy + half)))
    print("weather:", ", ".join(WEATHER))


if __name__ == "__main__":
    main()
