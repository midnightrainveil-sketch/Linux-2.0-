#!/usr/bin/env python3
# The taskbar's pictures, from the mock-up itself (art/TaskbarEg.png): the
# bar cut out of its white ground (its shadow kept), what it shows erased
# (the shell draws those live), and cut in three: the left end, a slice of
# the band that repeats to fill the screen's width, and the right end.
#   python3 tools/make_taskbar.py art/TaskbarEg.png home/.config/quickshell/assets/taskbar
import sys, os
from PIL import Image, ImageDraw
import numpy as np
src, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
a = np.asarray(Image.open(src).convert('RGB')).astype(float)
rng = np.random.default_rng(5)

def erase(x0, y0, x1, y1, grain=1.2):
    """fill each column from the plate just above and below"""
    left, right = a[y0:y1, x0 - 1].copy(), a[y0:y1, x1].copy()
    top, bot = a[y0 - 1, x0:x1].copy(), a[y1, x0:x1].copy()
    n = y1 - y0
    for i in range(n):
        f = (i + 1) / (n + 1)
        a[y0 + i, x0:x1] = top * (1 - f) + bot * f
    # then each row eased into the plate either side, so no seam shows
    t = np.linspace(0, 1, x1 - x0)[None, :, None]
    dl = (left - a[y0:y1, x0])[:, None, :]
    dr = (right - a[y0:y1, x1 - 1])[:, None, :]
    a[y0:y1, x0:x1] += dl * (1 - t) + dr * t
    a[y0:y1, x0:x1] += rng.normal(0, grain, (n, x1 - x0, 1))

erase(75, 348, 178, 389)          # the port plate's /// logo
erase(228, 345, 703, 390)         # the workspace numbers and dots
erase(735, 364, 1302, 374)        # the band's red line
erase(1306, 347, 1628, 389)       # /// CYPHERUM | A
erase(1682, 344, 2078, 392)       # Wi-Fi, volume, battery, the time

# the bar's own shape, and its shadow on the white below
X0, Y0, X1, Y1 = 20, 312, 2152, 440
S = 4
m = Image.new('L', ((X1 - X0) * S, (Y1 - Y0) * S), 0)
ImageDraw.Draw(m).rounded_rectangle([(35 - X0) * S, (320 - Y0) * S, (2139 - X0) * S, (418 - Y0) * S], 49 * S, fill=255)
m = np.asarray(m.resize((X1 - X0, Y1 - Y0), Image.LANCZOS)).astype(float) / 255
crop = a[Y0:Y1, X0:X1]
lum = crop.mean(2)
shadow = np.clip((250 - lum) / 250, 0, 1) * 1.15
yy = np.arange(Y0, Y1)[:, None] + 0 * lum
shadow = np.where(yy >= 405, shadow, 0)          # only below the bar
alpha = np.maximum(m, shadow * (1 - m))
rgb = crop * m[..., None] + 0 * (1 - m[..., None])  # outside: black, for the shadow
out = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype('uint8')
bar = Image.fromarray(out, 'RGBA')
if len(sys.argv) > 3: bar.save(sys.argv[3])     # the whole bar too, to look at
# the three pieces (x in the mock-up): left 20-800, slice 800-900, right 900-2152
cut = lambda x0, x1: bar.crop((x0 - X0, 0, x1 - X0, Y1 - Y0))
cut(20, 800).save(os.path.join(outdir, 'left.png'), optimize=True)
cut(800, 900).save(os.path.join(outdir, 'fill.png'), optimize=True)
cut(900, 2152).save(os.path.join(outdir, 'right.png'), optimize=True)
print('pieces', (780, Y1 - Y0), (100, Y1 - Y0), (1252, Y1 - Y0))
