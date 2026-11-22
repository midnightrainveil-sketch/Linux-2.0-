#!/usr/bin/env python3
# The picture beside the terminal's greeting (ultra-card): any image drawn
# in quadrant blocks (each text cell split 2 x 2, the terminal draws them
# whole), borderless; ink where the picture is dark, or where it is opaque
# when it has transparency. Without an image, the Arch logo.
#
#   python3 tools/make_card_art.py [picture.png] [rows] \
#       > home/.local/share/ultra/retro-futurism/card-art.txt
#
# rows: how many lines tall (11). The width follows the picture, in the
# terminal's cell proportions (a cell is about 0.42 as wide as it is tall).
# (pip: numpy pillow)
import sys
import numpy as np
from PIL import Image, ImageDraw

CELL = 0.42                      # a terminal cell's width over its height
QUAD = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'

src = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].isdigit() else None
rows = int(next((a for a in sys.argv[1:] if a.isdigit()), 11))


def arch_logo(size=1200):
    """the Arch logo: the peak, and the arch cut out of its foot"""
    im = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(im)
    s = size
    d.polygon([(0.50 * s, 0.00 * s), (0.97 * s, 1.00 * s), (0.03 * s, 1.00 * s)], fill=255)
    # the arch: a rounded opening in its foot
    d.polygon([(0.50 * s, 0.50 * s), (0.71 * s, 1.00 * s), (0.29 * s, 1.00 * s)], fill=0)
    d.ellipse([0.36 * s, 0.50 * s, 0.64 * s, 0.82 * s], fill=0)
    d.polygon([(0.36 * s, 0.68 * s), (0.64 * s, 0.68 * s), (0.71 * s, 1.0 * s), (0.29 * s, 1.0 * s)], fill=0)
    # its feet, a touch swept out
    d.polygon([(0.03 * s, 1.0 * s), (0.17 * s, 0.86 * s), (0.20 * s, 1.0 * s)], fill=255)
    d.polygon([(0.97 * s, 1.0 * s), (0.83 * s, 0.86 * s), (0.80 * s, 1.0 * s)], fill=255)
    return im


if src:
    im = Image.open(src)
    if im.mode in ('RGBA', 'LA') or 'transparency' in im.info:
        ink = im.convert('RGBA').split()[3]                       # opaque = ink
    else:
        ink = Image.eval(im.convert('L'), lambda v: 255 - v)      # dark = ink
    bbox = ink.point(lambda v: 255 if v > 40 else 0).getbbox()
    if bbox: ink = ink.crop(bbox)
else:
    ink = arch_logo()

w, h = ink.size
cols = max(1, round(w / h * rows / CELL))
a = np.asarray(ink.convert('L').resize((cols * 2, rows * 2), Image.BOX)).astype(float) / 255
lines = []
for r in range(rows):
    s = ''
    for c in range(cols):
        q = a[2 * r:2 * r + 2, 2 * c:2 * c + 2] > 0.5
        s += QUAD[q[0, 0] * 1 + q[0, 1] * 2 + q[1, 0] * 4 + q[1, 1] * 8]
    lines.append(s.rstrip())
print('\n'.join(lines))
