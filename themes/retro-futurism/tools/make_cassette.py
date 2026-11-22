#!/usr/bin/env python3
# The cassette player in the wallpaper, made to play: each reel cut out
# as a disc (its centre found where the reel looks most alike turned a
# quarter, so it spins without a wobble), and each level meter's window with
# its painted bars taken out (the shell lights its own, to the music).
#   python3 tools/make_cassette.py home/.local/share/ultra/retro-futurism
# reads wallpaper.jpg there, writes cassette/*.png and prints where each
# part goes (picture pixels; modules/Backdrop.qml).
# (pip: numpy pillow opencv-python-headless)
import os, sys
import numpy as np, cv2
from PIL import Image

D = sys.argv[1]
out = os.path.join(D, 'cassette'); os.makedirs(out, exist_ok=True)

PARTS = {
    # picture: (reels (rough centre, radius), meter window, its bars' box)
    'home': ('wallpaper.jpg', [((2404, 1518), 22), ((2502, 1523), 22)],
             (2596, 1468, 2676, 1522), (2604, 1479, 2667, 1514)),
}


def centre(g, cx, cy, r):
    """where the reel turns: the point it looks most alike about, a quarter
    turn round (searched to a quarter pixel)"""
    best = None
    R = int(r) + 6
    for dy in np.arange(-4, 4.01, 0.25):
        for dx in np.arange(-4, 4.01, 0.25):
            x, y = cx + dx, cy + dy
            x0, y0 = int(x) - R, int(y) - R
            patch = g[y0:y0 + 2 * R + 1, x0:x0 + 2 * R + 1]
            M = cv2.getRotationMatrix2D((x - x0, y - y0), 90, 1)
            rot = cv2.warpAffine(patch, M, patch.shape[::-1], flags=cv2.INTER_LINEAR)
            yy, xx = np.mgrid[0:patch.shape[0], 0:patch.shape[1]]
            m = np.hypot(xx - (x - x0), yy - (y - y0)) < r * 0.95
            e = float(np.abs(rot - patch)[m].mean())
            if best is None or e < best[0]:
                best = (e, x, y)
    return best[1], best[2]


for name, (file, reels, win, bars) in PARTS.items():
    img = np.asarray(Image.open(os.path.join(D, file)).convert('RGB')).astype(np.float32)
    g = img.mean(2)
    for i, ((cx, cy), r) in enumerate(reels):
        x, y = centre(g, cx, cy, r)
        # the disc, its centre at the sprite's centre exactly; a soft edge
        size = 2 * (r + 3)
        M = np.float32([[1, 0, size / 2 - x], [0, 1, size / 2 - y]])
        disc = cv2.warpAffine(img, M, (size, size), flags=cv2.INTER_CUBIC)
        yy, xx = np.mgrid[0:size, 0:size] + 0.5
        a = np.clip((r + 1.0) - np.hypot(xx - size / 2, yy - size / 2), 0, 1)
        Image.fromarray(np.dstack([np.clip(disc, 0, 255), a * 255]).round().astype('uint8'), 'RGBA') \
            .save(os.path.join(out, f'{name}-reel-{"lr"[i]}.png'))
        print(f'{name} reel {"lr"[i]}: centre {x:.2f}, {y:.2f}  sprite {size}')
    # the meter: its window with the bars taken out (filled from the dark
    # round them)
    x0, y0, x1, y1 = win
    part = img[y0:y1, x0:x1].clip(0, 255).astype(np.uint8)
    m = np.zeros(part.shape[:2], np.uint8)
    bx0, by0, bx1, by1 = bars
    m[by0 - y0:by1 - y0, bx0 - x0:bx1 - x0] = 255
    filled = cv2.inpaint(part, m, 6, cv2.INPAINT_TELEA)
    # a touch darker where the bars were: an unlit meter
    shade = cv2.GaussianBlur(m.astype(np.float32) / 255, (0, 0), 2.0)[..., None]
    filled = (filled * (1 - 0.25 * shade)).clip(0, 255).astype(np.uint8)
    Image.fromarray(filled).save(os.path.join(out, f'{name}-meter.png'))
    print(f'{name} meter: window {win}')
