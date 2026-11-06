#!/usr/bin/env python3
"""The little train that runs along the bar, from the artwork in art/train/.

    python3 tools/import_train.py

Each vehicle (drawn side on, facing right, on white, standing on a ruled
ground line) is lifted off its paper: the ground line is taken out, the
white round it made clear (only the white that reaches the picture's edge,
so the cream roofs and lit windows stay), and it is cut to its own size at
a common scale: a carriage body as tall as every other one. The steam
sheet is cut into its separate puffs, their soft edges kept.

Writes dotfiles/.config/quickshell/assets/train/<name>.png (drawn at three
times the size they are shown, for a sharp edge at any scale) and
train.json, the order and widths the shell lays them out with.
Requires: numpy, pillow.
"""
import json
import os
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "art", "train")
DST = os.path.join(HERE, "..", "dotfiles", ".config", "quickshell", "assets", "train")
K = 3                      # stored at three times the size shown

# the train, front to back, and each vehicle's height on screen (logical
# px, wheels to roof; the engine and the van stand a little taller)
TRAIN = [("locomotive", 56), ("tender", 42), ("fourgon", 48), ("coach", 44),
         ("coach", 44), ("dining", 44), ("sleeping", 44)]


def drop_ground(a):
    """The ruled ground line under the wheels: the dark rows at the very foot
    of the picture (from the bottom up, past any blank paper, until the
    first row that is not mostly dark). Nothing above it is touched: an
    engine's frame is dark from end to end too."""
    dark = (a.mean(axis=2) < 150).mean(axis=1)
    a = a.copy()
    y = a.shape[0] - 1
    while y > 0 and dark[y] < 0.02:
        y -= 1
    while y > 0 and dark[y] > 0.45:
        a[y] = 255
        y -= 1
    # (and its soft grey edge)
    if y > 0 and dark[y] > 0.2:
        a[y] = 255
    return a


def lift(a):
    """Alpha: clear where white paper reaches the picture's edge."""
    h, w, _ = a.shape
    white = a.min(axis=2) > 232
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white[y, x] and not bg[y, x]:
                bg[y, x] = True; q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if white[y, x] and not bg[y, x]:
                bg[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and white[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; q.append((ny, nx))
    alpha = Image.fromarray(((~bg) * 255).astype(np.uint8))
    # a soft edge: the paper's last light pixels fade out
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    return alpha


def vehicle(name, height):
    src = Image.open(os.path.join(SRC, name + ".webp")).convert("RGB")
    # (flood-filled at a working size: these are large pictures)
    s = 900 / max(src.size)
    small = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
    a = drop_ground(np.asarray(small))
    alpha = lift(a)
    img = Image.fromarray(a).convert("RGBA")
    img.putalpha(alpha)
    img = img.crop(alpha.point(lambda v: 255 if v > 20 else 0).getbbox())
    H = height * K
    img = img.resize((round(img.width * H / img.height), H), Image.LANCZOS)
    return img


def puffs():
    src = Image.open(os.path.join(SRC, "steam.webp")).convert("RGB")
    s = 900 / max(src.size)
    src = src.resize((round(src.width * s), round(src.height * s)), Image.LANCZOS)
    a = np.asarray(src).astype(np.float32)
    lum = a.mean(axis=2)
    alpha = np.clip((250 - lum) / 70, 0, 1)
    cols = np.where(alpha.max(axis=0) > 0.12)[0]
    # the puffs, split where a column of pure paper runs between them
    runs, start = [], cols[0]
    for i in range(1, len(cols)):
        if cols[i] - cols[i - 1] > 2:
            runs.append((start, cols[i - 1])); start = cols[i]
    runs.append((start, cols[-1]))
    out = []
    for x0, x1 in runs:
        piece = np.zeros((a.shape[0], x1 - x0 + 1, 4), np.float32)
        piece[..., :3] = np.clip(a[:, x0:x1 + 1] * 0.92, 0, 255)          # a touch darker than drawn
        piece[..., 3] = alpha[:, x0:x1 + 1] * 255
        img = Image.fromarray(piece.astype(np.uint8), "RGBA")
        img = img.crop(img.split()[3].point(lambda v: 255 if v > 10 else 0).getbbox())
        out.append(img)
    return out


def main():
    os.makedirs(DST, exist_ok=True)
    layout, made = [], {}
    for name, h in TRAIN:
        if name not in made:
            made[name] = vehicle(name, h)
            made[name].save(os.path.join(DST, name + ".png"), optimize=True)
        img = made[name]
        layout.append({"name": name, "w": round(img.width / K, 1), "h": h})
    steam = []
    for i, p in enumerate(puffs()):
        p = p.resize((max(1, round(p.width * 30 * K / max(p.size))), max(1, round(p.height * 30 * K / max(p.size)))), Image.LANCZOS)
        p.save(os.path.join(DST, "steam-%d.png" % i), optimize=True)
        steam.append("steam-%d.png" % i)
    with open(os.path.join(DST, "train.json"), "w") as f:
        json.dump({"vehicles": layout, "steam": steam, "scale": K}, f, indent=2)
        f.write("\n")
    print("train:", " + ".join(v["name"] for v in layout), "=", round(sum(v["w"] for v in layout)), "px;", len(steam), "puffs")


if __name__ == "__main__":
    main()
