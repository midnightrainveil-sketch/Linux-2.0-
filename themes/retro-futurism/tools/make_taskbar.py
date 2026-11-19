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
erase(228, 345, 684, 390)         # the workspace numbers and dots (inside the plate)
erase(744, 365, 1302, 373)        # the band's red line (inside the band)
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
    bx0, by0, bx1, by1 = 79, 345, 169, 379            # the bezel round the slot, centred on the plate
    # let into the plate: shade above, a light lip below
    sh = layer(); rr(sh, (bx0 - 1.5, by0 - 1.5, bx1 + 1.5, by1 + 0.5), 6, (70, 52, 30, 120))
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(1.6 * Z)))
    lip = layer(); rr(lip, (bx0 - 1, by0 + 1, bx1 + 1, by1 + 1.6), 6, (255, 250, 238, 200))
    base.alpha_composite(lip.filter(ImageFilter.GaussianBlur(0.5 * Z)))
    # the steel bezel
    base.alpha_composite(vgrad((bx0 - 0.5, by0 - 0.5, bx1 + 0.5, by1 + 0.5), [(0, (60, 56, 50, 255)), (1, (60, 56, 50, 255))], 5.5))
    base.alpha_composite(vgrad((bx0, by0, bx1, by1), [(0, (238, 236, 230, 255)), (0.18, (196, 192, 184, 255)),
        (0.55, (150, 145, 136, 255)), (0.85, (206, 202, 195, 255)), (1, (120, 115, 106, 255))], 5))
    br = layer(); bd = ImageDraw.Draw(br); rng2 = np.random.default_rng(9)
    for i in range(150):
        y = rng2.uniform(by0 * Z, by1 * Z) - Y0 * Z; x = rng2.uniform(0, w)
        bd.line([(x, y), (x + rng2.uniform(30, 160), y)], fill=(255, 255, 255, int(rng2.uniform(8, 26))), width=1)
    bm = layer(); rr(bm, (bx0, by0, bx1, by1), 5, (0, 0, 0, 255))
    br.putalpha(Image.fromarray(np.minimum(np.asarray(br)[..., 3], np.asarray(bm)[..., 3])))
    base.alpha_composite(br)
    # the mouth, and the inside: its top wall in light, the floor deep
    cx0, cy0, cx1, cy1 = bx0 + 4, by0 + 4, bx1 - 4, by1 - 4
    base.alpha_composite(vgrad((cx0 - 0.6, cy0 - 0.6, cx1 + 0.6, cy1 + 0.6), [(0, (40, 38, 34, 255)), (1, (225, 222, 215, 255))], 2.8))
    base.alpha_composite(vgrad((cx0, cy0, cx1, cy1), [(0, (92, 88, 80, 255)), (0.22, (58, 56, 51, 255)),
        (0.3, (20, 19, 17, 255)), (1, (44, 42, 38, 255))], 2.4))
    # the four contacts, as on the cartridges: wide gold pads in a dark seat
    pw, ph, pg = 13.5, 11.5, 6.0
    tot = 4 * pw + 3 * pg; px0 = (cx0 + cx1) / 2 - tot / 2; py0 = cy1 - 2.4 - ph
    base.alpha_composite(vgrad((px0 - 3, py0 - 2.2, px0 + tot + 3, cy1 - 1), [(0, (30, 29, 27, 255)), (1, (52, 50, 46, 255))], 1.6))
    for i in range(4):
        x = px0 + i * (pw + pg)
        base.alpha_composite(vgrad((x - 0.5, py0 - 0.5, x + pw + 0.5, py0 + ph + 0.5), [(0, (90, 68, 26, 255)), (1, (60, 44, 16, 255))], 1.6))
        base.alpha_composite(vgrad((x, py0, x + pw, py0 + ph), [(0, (250, 226, 160, 255)), (0.3, (222, 184, 104, 255)),
            (0.75, (188, 148, 72, 255)), (1, (150, 112, 48, 255))], 1.4))
        g = layer(); ImageDraw.Draw(g).rounded_rectangle([*P(x + 1.2, py0 + 1.0), *P(x + pw - 1.2, py0 + 2.2)], Z, fill=(255, 248, 220, 160))
        base.alpha_composite(g.filter(ImageFilter.GaussianBlur(0.35 * Z)))
    # the light along the bezel's upper edge
    hl = layer(); ImageDraw.Draw(hl).rounded_rectangle([*P(bx0 + 3, by0 + 0.6), *P(bx1 - 3, by0 + 1.4)], Z, fill=(255, 255, 255, 150))
    base.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.4 * Z)))
    # the indicator under the slot, as on the launcher (the shell lights it)
    ix0, iy0, ix1, iy1 = 111, 384, 137, 389.5
    base.alpha_composite(vgrad((ix0 - 0.8, iy0 - 0.8, ix1 + 0.8, iy1 + 0.8), [(0, (120, 100, 78, 255)), (1, (250, 244, 230, 255))], 2.4))
    base.alpha_composite(vgrad((ix0, iy0, ix1, iy1), [(0, (214, 98, 60, 255)), (1, (160, 64, 36, 255))], 2))
    # the grip: ribs pressed into the plate, either side of the slot
    for x in (59, 64, 69, 175, 180, 185):
        base.alpha_composite(vgrad((x, 352, x + 2, 386), [(0, (150, 132, 104, 255)), (1, (196, 182, 160, 255))], 1))
        hl2 = layer(); ImageDraw.Draw(hl2).rounded_rectangle([*P(x + 2, 352), *P(x + 2.8, 386)], int(0.4 * Z), fill=(255, 250, 236, 170))
        base.alpha_composite(hl2)
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
