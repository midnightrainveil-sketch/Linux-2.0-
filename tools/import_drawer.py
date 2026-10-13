#!/usr/bin/env python3
"""Turn the drawer artwork in art/drawer/ into the catalogue's assets.

    python3 tools/import_drawer.py

    art/drawer/front.webp   a square oak drawer front: frame, moulding, panel
    art/drawer/holder.webp  a brass label holder on white (its window white too)
    art/drawer/pull.webp    a brass cup pull on white
    art/drawer/wood.webp    a seamless square of the drawer's inside wood

Writes dotfiles/.config/quickshell/assets/drawer/: front.png (the wide front
the catalogue needs, at 2x: the square's frame stretched along its grain
around a band of its panel, turned so the grain runs lengthwise),
holder.png and pull.png (the white keyed out, cropped), wood.jpg (512 px
tile), and drawer.json (where the holder's window is, as fractions).
"""
import json
import pathlib

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "drawer"
OUT = ROOT / "dotfiles" / ".config" / "quickshell" / "assets" / "drawer"

FRONT_W, FRONT_H = 1520, 360          # the front, 760 x 180 at 2x
FRAME = 0.36                          # the frame's scale in the front
# the square's frame and moulding, before turning: left, top, right, bottom
FRONT_BORDERS = (140, 160, 136, 164)


def front():
    src = Image.open(SRC / "front.webp").convert("RGB")
    # turn it a quarter (clockwise) so the panel's grain runs along the drawer
    src = src.transpose(Image.Transpose.ROTATE_270)
    l0, t0, r0, b0 = FRONT_BORDERS
    # after a clockwise quarter turn: left <- bottom, top <- left, right <- top, bottom <- right
    l, t, r, b = b0, l0, t0, r0
    W, H = src.size
    k = FRAME
    L, T, R, B = (round(v * k) for v in (l, t, r, b))
    out = Image.new("RGB", (FRONT_W, FRONT_H))

    def put(box, size, at):
        out.paste(src.crop(box).resize(size, Image.Resampling.LANCZOS), at)

    # the panel: a band from the middle of the square's, at one scale
    pw, ph = FRONT_W - L - R, FRONT_H - T - B
    s = pw / (W - l - r)
    band = ph / s
    cy = (t + H - b) / 2
    put((l, round(cy - band / 2), W - r, round(cy + band / 2)), (pw, ph), (L, T))
    # the bars: stretched or squeezed along their grain only
    put((l, 0, W - r, t), (pw, T), (L, 0))
    put((l, H - b, W - r, H), (pw, B), (L, FRONT_H - B))
    put((0, t, l, H - b), (L, ph), (0, T))
    put((W - r, t, W, H - b), (R, ph), (FRONT_W - R, T))
    # the mitred corners
    put((0, 0, l, t), (L, T), (0, 0))
    put((W - r, 0, W, t), (R, T), (FRONT_W - R, 0))
    put((0, H - b, l, H), (L, B), (0, FRONT_H - B))
    put((W - r, H - b, W, H), (R, B), (FRONT_W - R, FRONT_H - B))
    out.save(OUT / "front.png", optimize=True)
    print(f"front.png  {out.size}, frame {L}/{T}/{R}/{B} px")


def keyed(name):
    """The brass on white, with the white made transparent and cropped."""
    im = np.asarray(Image.open(SRC / name).convert("RGB")).astype(np.float32)
    # white has every channel high; brass always has a low blue
    lo = im.min(axis=2)
    alpha = np.clip((246 - lo) / 22, 0, 1)
    rgba = np.dstack([im, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    return img.crop(img.getbbox())


def holder():
    img = keyed("holder.webp")
    a = np.asarray(img)[:, :, 3]
    h, w = a.shape
    # the window: the clear region around the middle
    cy, cx = h // 2, w // 2
    row = a[cy, :] < 128
    col = a[:, cx] < 128
    x0 = cx
    while x0 > 0 and row[x0 - 1]:
        x0 -= 1
    x1 = cx
    while x1 < w - 1 and row[x1 + 1]:
        x1 += 1
    y0 = cy
    while y0 > 0 and col[y0 - 1]:
        y0 -= 1
    y1 = cy
    while y1 < h - 1 and col[y1 + 1]:
        y1 += 1
    img = img.resize((720, round(720 * h / w)), Image.Resampling.LANCZOS)
    img.save(OUT / "holder.png", optimize=True)
    window = {"x": x0 / w, "y": y0 / h, "w": (x1 + 1 - x0) / w, "h": (y1 + 1 - y0) / h, "aspect": w / h}
    print(f"holder.png {img.size}, window {window}")
    return window


def pull():
    img = keyed("pull.webp")
    w, h = img.size
    img = img.resize((360, round(360 * h / w)), Image.Resampling.LANCZOS)
    img.save(OUT / "pull.png", optimize=True)
    print(f"pull.png   {img.size}")
    return {"aspect": w / h}


def wood():
    img = Image.open(SRC / "wood.webp").convert("RGB").resize((512, 512), Image.Resampling.LANCZOS)
    img.save(OUT / "wood.jpg", quality=90)
    print("wood.jpg   (512, 512)")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    front()
    meta = {"holder": holder(), "pull": pull()}
    wood()
    (OUT / "drawer.json").write_text(json.dumps(meta, indent=2) + "\n")
