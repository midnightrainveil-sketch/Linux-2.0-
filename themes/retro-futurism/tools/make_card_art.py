#!/usr/bin/env python3
# The picture beside the terminal's greeting (ultra-card), from any drawing:
#
#   picture.png    the drawing in the terminal's ink on a clear ground, for
#                  terminals that show real pictures (Ghostty, kitty): the
#                  card places it, any size, over the cells it keeps free
#   blocks-N.txt   the same drawn in quadrant blocks, N lines tall (3..16),
#                  for every other terminal (and over SSH, in tmux)
#   ratio          its width over its height
#
#   python3 tools/make_card_art.py art/Card-Cat.webp \
#       home/.local/share/ultra/retro-futurism/card-art
#
# Dark is ink (or, in a picture with transparency, opaque is ink). Without a
# picture, a smiling face. (pip: numpy pillow)
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

INK = (0x2a, 0x2b, 0x2a)                 # ghostty's foreground
CELL = 0.42                              # a terminal cell's width over its height
QUAD = ' ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█'

args = sys.argv[1:]
src = args[0] if len(args) > 1 else None
out = args[-1]
os.makedirs(out, exist_ok=True)


def smile(size=1200):
    im = Image.new('L', (size, size), 0); d = ImageDraw.Draw(im); s = size
    d.ellipse([0.02 * s, 0.02 * s, 0.98 * s, 0.98 * s], fill=255)
    d.ellipse([0.12 * s, 0.12 * s, 0.88 * s, 0.88 * s], fill=0)
    for x in (0.36, 0.64):
        d.ellipse([(x - 0.065) * s, 0.30 * s, (x + 0.065) * s, 0.47 * s], fill=255)
    d.arc([0.27 * s, 0.30 * s, 0.73 * s, 0.74 * s], 25, 155, fill=255, width=int(0.085 * s))
    return im


# ---- how much ink each point has
if src:
    im = Image.open(src)
    if im.mode in ('RGBA', 'LA') or 'transparency' in im.info:
        ink = im.convert('RGBA').split()[3]
    else:
        g = np.asarray(im.convert('L')).astype(float)
        # paper (its own light grey) to nothing, the darkest lines to full
        paper = np.percentile(g, 90)
        ink = Image.fromarray(np.clip((paper - g) / max(paper - g.min(), 1) * 1.15, 0, 1).__mul__(255).astype('uint8'))
else:
    ink = smile()
bbox = ink.point(lambda v: 255 if v > 30 else 0).getbbox()
if bbox:
    pad = int(max(ink.size) * 0.01)
    ink = ink.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(ink.width, bbox[2] + pad), min(ink.height, bbox[3] + pad)))
w, h = ink.size

# ---- the picture: ink on a clear ground, at most 720 px tall
k = min(1.0, 720 / h)
small = ink.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
rgba = Image.new('RGBA', small.size, INK + (0,)); rgba.putalpha(small)
rgba.save(os.path.join(out, 'picture.png'), optimize=True)
open(os.path.join(out, 'ratio'), 'w').write('%.4f\n' % (w / h))

# ---- blocks, at each height: the ink thickened a little first, so fine
# lines still make a shape
soft = ink.filter(ImageFilter.GaussianBlur(max(w, h) / 120))
for rows in range(3, 17):
    cols = max(1, round(w / h * rows / CELL))
    a = np.asarray(soft.resize((cols * 2, rows * 2), Image.BOX)).astype(float) / 255
    lines = []
    for r in range(rows):
        s = ''
        for c in range(cols):
            q = a[2 * r:2 * r + 2, 2 * c:2 * c + 2] > 0.26
            s += QUAD[q[0, 0] * 1 + q[0, 1] * 2 + q[1, 0] * 4 + q[1, 1] * 8]
        lines.append(s)
    open(os.path.join(out, 'blocks-%d.txt' % rows), 'w').write('\n'.join(lines) + '\n')
print('ratio %.3f, picture %dx%d' % (w / h, *small.size))
