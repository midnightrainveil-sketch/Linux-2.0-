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

# ---- the cartridge port, painted into the left plate (x 52-195, y 339-397):
# a slot in a steel bezel let into the plate, an edge connector with gold
# fingers at the back, the red insert mark over it, and the lamp's lens
from PIL import ImageFilter
def paint_port():
    X0, Y0, X1, Y1 = 52, 339, 195, 397
    Z = 6                                              # drawn large, then brought down
    w, h = (X1 - X0) * Z, (Y1 - Y0) * Z
    base = Image.fromarray(np.clip(a[Y0:Y1, X0:X1], 0, 255).astype('uint8')).resize((w, h), Image.BICUBIC).convert('RGBA')
    P = lambda x, y: (round((x - X0) * Z), round((y - Y0) * Z))
    def layer(): return Image.new('RGBA', (w, h), (0, 0, 0, 0))
    def rr(img, box, r, fill):
        d = ImageDraw.Draw(img); d.rounded_rectangle([*P(box[0], box[1]), *P(box[2], box[3])], r * Z, fill=fill)
    def vgrad(box, stops, r):
        g = layer(); x0, y0 = P(box[0], box[1]); x1, y1 = P(box[2], box[3])
        gr = Image.new('RGBA', (x1 - x0, y1 - y0)); gd = ImageDraw.Draw(gr)
        for yy in range(y1 - y0):
            t = yy / max(1, y1 - y0 - 1)
            for i in range(len(stops) - 1):
                if stops[i][0] <= t <= stops[i + 1][0]:
                    k = (t - stops[i][0]) / max(1e-6, stops[i + 1][0] - stops[i][0])
                    c = tuple(round(stops[i][1][j] * (1 - k) + stops[i + 1][1][j] * k) for j in range(4)); break
            gd.line([(0, yy), (x1 - x0, yy)], fill=c)
        m = Image.new('L', gr.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, gr.size[0] - 1, gr.size[1] - 1], r * Z, fill=255)
        g.paste(gr, (x0, y0), m); return g
    bx0, by0, bx1, by1 = 63, 351, 163, 387            # the bezel
    # let into the plate: shade above, a light lip below
    sh = layer(); rr(sh, (bx0 - 1.5, by0 - 1.5, bx1 + 1.5, by1 + 0.5), 7, (70, 52, 30, 120))
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(1.6 * Z)))
    lip = layer(); rr(lip, (bx0 - 1, by0 + 1, bx1 + 1, by1 + 1.6), 7, (255, 250, 238, 200))
    base.alpha_composite(lip.filter(ImageFilter.GaussianBlur(0.5 * Z)))
    # the steel bezel
    base.alpha_composite(vgrad((bx0 - 0.5, by0 - 0.5, bx1 + 0.5, by1 + 0.5), [(0, (60, 56, 50, 255)), (1, (60, 56, 50, 255))], 6.5))
    base.alpha_composite(vgrad((bx0, by0, bx1, by1), [(0, (238, 236, 230, 255)), (0.18, (196, 192, 184, 255)),
        (0.55, (150, 145, 136, 255)), (0.85, (206, 202, 195, 255)), (1, (120, 115, 106, 255))], 6))
    # brushed lines across the steel
    br = layer(); bd = ImageDraw.Draw(br); rng2 = np.random.default_rng(9)
    for i in range(160):
        y = rng2.uniform(by0 * Z, by1 * Z) - Y0 * Z; x = rng2.uniform(0, w)
        bd.line([(x, y), (x + rng2.uniform(30, 160), y)], fill=(255, 255, 255, int(rng2.uniform(8, 26))), width=1)
    bm = layer(); rr(bm, (bx0, by0, bx1, by1), 6, (0, 0, 0, 255))
    br.putalpha(Image.fromarray(np.minimum(np.asarray(br)[..., 3], np.asarray(bm)[..., 3])))
    base.alpha_composite(br)
    # the mouth: deep, darkest at the top where the lip shades it
    cx0, cy0, cx1, cy1 = bx0 + 4.5, by0 + 4.5, bx1 - 4.5, by1 - 4.5
    base.alpha_composite(vgrad((cx0 - 0.6, cy0 - 0.6, cx1 + 0.6, cy1 + 0.6), [(0, (40, 38, 34, 255)), (1, (225, 222, 215, 255))], 3.2))
    base.alpha_composite(vgrad((cx0, cy0, cx1, cy1), [(0, (3, 3, 3, 255)), (0.45, (12, 11, 10, 255)), (1, (34, 31, 27, 255))], 2.8))
    # guide rails inside, either side
    for gx in (cx0 + 2.2, cx1 - 3.4):
        base.alpha_composite(vgrad((gx, cy0 + 2, gx + 1.2, cy1 - 1.5), [(0, (70, 66, 60, 200)), (1, (110, 104, 95, 220))], 0.5))
    # the edge connector at the back: a dark block, gold fingers on it
    kx0, ky0, kx1, ky1 = cx0 + 6, cy0 + 12.5, cx1 - 6, cy1 - 2.2
    base.alpha_composite(vgrad((kx0, ky0, kx1, ky1), [(0, (52, 48, 40, 255)), (1, (24, 22, 19, 255))], 1))
    n = 14; gap = 1.25; fw = (kx1 - kx0 - 4 - gap * (n - 1)) / n
    for i in range(n):
        if i == 9: continue                                 # the key
        fx = kx0 + 2 + i * (fw + gap)
        base.alpha_composite(vgrad((fx, ky0 + 1.2, fx + fw, ky1 - 1.0), [(0, (255, 236, 168, 255)), (0.25, (226, 182, 88, 255)),
            (0.7, (170, 124, 44, 255)), (1, (110, 78, 26, 255))], 0.35))
    # the light along the bezel's upper edge
    hl = layer(); hd = ImageDraw.Draw(hl)
    hd.rounded_rectangle([*P(bx0 + 3, by0 + 0.6), *P(bx1 - 3, by0 + 1.4)], Z, fill=(255, 255, 255, 150))
    base.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.4 * Z)))
    # the insert mark, printed on the plate above
    mk = layer(); ImageDraw.Draw(mk).polygon([P(109, 342.3), P(119, 342.3), P(114, 347.6)], fill=(178, 81, 47, 255))
    base.alpha_composite(mk.filter(ImageFilter.GaussianBlur(0.15 * Z)))
    # the lamp: a small lens in a dark ring (the shell lights it)
    lx, ly, lr = 179, 369, 4.6
    ring = layer(); ImageDraw.Draw(ring).ellipse([*P(lx - lr - 1.2, ly - lr - 1.2), *P(lx + lr + 1.2, ly + lr + 1.2)], fill=(70, 60, 46, 255))
    base.alpha_composite(ring)
    base.alpha_composite(vgrad((lx - lr, ly - lr, lx + lr, ly + lr), [(0, (150, 120, 70, 255)), (0.5, (96, 74, 40, 255)), (1, (70, 54, 30, 255))], lr))
    gl = layer(); ImageDraw.Draw(gl).ellipse([*P(lx - 2.6, ly - 3.6), *P(lx - 0.2, ly - 1.6)], fill=(255, 255, 240, 170))
    base.alpha_composite(gl.filter(ImageFilter.GaussianBlur(0.3 * Z)))
    small = np.asarray(base.convert('RGB').resize((X1 - X0, Y1 - Y0), Image.LANCZOS)).astype(float)
    a[Y0:Y1, X0:X1] = small
paint_port()

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
