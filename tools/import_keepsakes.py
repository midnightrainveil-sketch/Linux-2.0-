#!/usr/bin/env python3
"""Night Service's keepsakes on the desk, from art/night-service/.

    python3 tools/import_keepsakes.py

  key.webp       the brass key No. 19, hanging from its ring: the clock
                 card's picture (clock-art.png)
  label.webp     the Wagons-Lits luggage label (label.png)
  postcard.webp  the postcard of Venice (postcard.png)

Each is lifted off its white (only the white that reaches the picture's
edge: the cream of the label and the postcard's border stay), trimmed, and
written to dotfiles/.config/quickshell/assets/flavours/night-service/ at
about twice the size it is shown. Requires: numpy, pillow.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_train import lift  # noqa: E402  (the same flood from the edge)

SRC = os.path.join(HERE, "..", "art", "night-service")
DST = os.path.join(HERE, "..", "dotfiles", ".config", "quickshell", "assets", "flavours", "night-service")
# name: (source, output, its longest side in px, its colour: 1 as drawn)
ITEMS = {
    "key": ("key.webp", "clock-art.png", 320, 1.0),
    "label": ("label.webp", "label.png", 720, 0.8),
    "postcard": ("postcard.webp", "postcard.png", 900, 0.8),
}


def cut(src, longest, colour=1.0):
    import numpy as np
    im = Image.open(src).convert("RGB")
    if colour != 1.0:
        from PIL import ImageEnhance
        im = ImageEnhance.Color(im).enhance(colour)
    s = 900 / max(im.size)
    small = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    alpha = lift(np.asarray(small))
    alpha = alpha.resize(im.size, Image.LANCZOS)
    out = im.convert("RGBA")
    out.putalpha(alpha)
    out = out.crop(alpha.point(lambda v: 255 if v > 24 else 0).getbbox())
    k = longest / max(out.size)
    return out.resize((round(out.width * k), round(out.height * k)), Image.LANCZOS)


def main():
    os.makedirs(DST, exist_ok=True)
    for name, (src, dst, longest, colour) in ITEMS.items():
        img = cut(os.path.join(SRC, src), longest, colour)
        img.save(os.path.join(DST, dst), optimize=True)
        print("keepsake:", name, "->", dst, img.size)


if __name__ == "__main__":
    main()
