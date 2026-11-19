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

# ---- the port's plate made wider and the workspaces' shorter (by D): the
# port takes cartridges as large as the launcher's slot does, and six
# workspaces are plenty. Column strips of the whole bar are moved, so the
# tube runs on unbroken: the port's plate 52-290, a gap, the workspaces'
# plate 304-712.
D = 95
seg = lambda x0, x1: a[:, x0:x1].copy()
mid = seg(110, 140)
filler = np.concatenate([mid] * ((30 + D) // 30 + 1), axis=1)[:, :30 + D]
a[:, 52:712] = np.concatenate([seg(52, 110), filler, seg(140, 240), seg(240, 680 - D), seg(680, 712)], axis=1)

# ---- the cartridge port, painted into the left plate (x 52-290, y 339-397):
# a slot let into the plate, a chamfered steel bezel with two small screws,
# and inside, seen a little from above, its floor and the four gold contacts
# of the cartridges down on its floor
from PIL import ImageFilter
def paint_port(X0=52, X1=290, bx0=104, bx1=238):
    Y0, Y1 = 339, 397
    Z = 8
    w, h = (X1 - X0) * Z, (Y1 - Y0) * Z
    base = Image.fromarray(np.clip(a[Y0:Y1, X0:X1], 0, 255).astype('uint8')).resize((w, h), Image.BICUBIC).convert('RGBA')
    P = lambda x, y: (round((x - X0) * Z), round((y - Y0) * Z))
    L = lambda: Image.new('RGBA', (w, h), (0, 0, 0, 0))
    def shape(box, r, fill, blur=0):
        g = L(); ImageDraw.Draw(g).rounded_rectangle([*P(box[0], box[1]), *P(box[2], box[3])], max(0, round(r * Z)), fill=fill)
        return g.filter(ImageFilter.GaussianBlur(blur * Z)) if blur else g
    def grad(box, stops, r, horiz=False):
        x0, y0 = P(box[0], box[1]); x1, y1 = P(box[2], box[3])
        n = (x1 - x0) if horiz else (y1 - y0)
        t = np.linspace(0, 1, max(n, 1))
        cols = np.zeros((len(t), 4))
        for j in range(4):
            cols[:, j] = np.interp(t, [q[0] for q in stops], [q[1][j] for q in stops])
        arr = np.repeat(cols[None, :, :], y1 - y0, 0) if horiz else np.repeat(cols[:, None, :], x1 - x0, 1)
        gr = Image.fromarray(arr.astype('uint8'), 'RGBA')
        m = Image.new('L', gr.size, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, gr.size[0] - 1, gr.size[1] - 1], max(0, round(r * Z)), fill=255)
        gr.putalpha(Image.fromarray(np.minimum(np.asarray(gr)[..., 3], np.asarray(m)).astype('uint8')))
        g = L(); g.paste(gr, (x0, y0), gr); return g
    def clip(img, mask):
        al = np.minimum(np.asarray(img)[..., 3], np.asarray(mask)[..., 3]).astype('uint8')
        img.putalpha(Image.fromarray(al)); return img
    rng2 = np.random.default_rng(11)
    by0, by1 = 350, 386                                       # the bezel, centred on the plate
    # 1. the cut in the plate: shadow falls in from the top-left, a lit lip below
    base.alpha_composite(shape((bx0 - 2.2, by0 - 2.0, bx1 + 1.6, by1 + 0.6), 7, (60, 40, 18, 110), 1.8))
    base.alpha_composite(shape((bx0 - 0.8, by0 + 1.2, bx1 + 0.8, by1 + 1.8), 6.5, (255, 251, 240, 210), 0.45))
    # 2. the bezel: an outer chamfer (lit above), a flat brushed face, an inner chamfer (lit below)
    base.alpha_composite(shape((bx0 - 0.6, by0 - 0.6, bx1 + 0.6, by1 + 0.6), 6.3, (48, 45, 40, 255)))
    base.alpha_composite(grad((bx0, by0, bx1, by1), [(0, (252, 251, 248, 255)), (0.12, (214, 210, 203, 255)),
        (0.5, (158, 153, 145, 255)), (0.88, (120, 115, 108, 255)), (1, (88, 84, 78, 255))], 5.8))
    face = grad((bx0 + 1.3, by0 + 1.3, bx1 - 1.3, by1 - 1.3), [(0, (226, 223, 217, 255)), (0.45, (190, 186, 179, 255)),
        (0.55, (176, 172, 165, 255)), (1, (206, 202, 196, 255))], 4.8)
    base.alpha_composite(face)
    # brushing on the face, and a soft reflection band across it
    br = L(); bd = ImageDraw.Draw(br)
    for i in range(420):
        y = rng2.uniform(by0 + 1.3, by1 - 1.3); x = rng2.uniform(bx0, bx1); ln = rng2.uniform(4, 22)
        v = int(rng2.uniform(0, 1) > 0.5) * 255
        bd.line([P(x, y), P(x + ln, y)], fill=(v, v, v, int(rng2.uniform(6, 22))), width=1)
    base.alpha_composite(clip(br, face))
    sp = L(); ImageDraw.Draw(sp).polygon([P(bx0 + 22, by0), P(bx0 + 40, by0), P(bx0 + 30, by1), P(bx0 + 12, by1)], fill=(255, 255, 255, 46))
    base.alpha_composite(clip(sp.filter(ImageFilter.GaussianBlur(3 * Z)), face))
    # two small screws on the bezel's ends
    for sx in (bx0 + 5.2, bx1 - 5.2):
        sy = (by0 + by1) / 2; r = 2.3
        base.alpha_composite(shape((sx - r - 0.5, sy - r - 0.3, sx + r + 0.5, sy + r + 0.9), r + 0.5, (70, 66, 60, 150), 0.25))
        base.alpha_composite(grad((sx - r, sy - r, sx + r, sy + r), [(0, (236, 234, 230, 255)), (0.5, (170, 166, 158, 255)), (1, (118, 113, 106, 255))], r))
        sl = L(); ImageDraw.Draw(sl).line([P(sx - 1.5, sy + 1.1), P(sx + 1.5, sy - 1.1)], fill=(64, 60, 54, 230), width=max(1, round(0.55 * Z)))
        ImageDraw.Draw(sl).line([P(sx - 1.4, sy + 1.4), P(sx + 1.6, sy - 0.8)], fill=(255, 255, 255, 90), width=max(1, round(0.3 * Z)))
        base.alpha_composite(sl)
    # 3. the mouth: an inner chamfer, dark above, lit at the bottom edge
    mx0, my0, mx1, my1 = bx0 + 11, by0 + 5, bx1 - 11, by1 - 5
    base.alpha_composite(grad((mx0 - 1.4, my0 - 1.4, mx1 + 1.4, my1 + 1.4), [(0, (58, 55, 50, 255)), (0.6, (120, 116, 110, 255)), (1, (246, 244, 238, 255))], 3.4))
    inside = grad((mx0, my0, mx1, my1), [(0, (0, 0, 0, 255)), (1, (0, 0, 0, 255))], 2.4)
    # the inside, as seen from a little above: the lip's underside (black),
    # the back wall, then the floor coming toward us, catching some light
    cav = grad((mx0, my0, mx1, my1), [(0, (4, 4, 4, 255)), (0.18, (8, 8, 8, 255)), (0.2, (22, 21, 19, 255)),
        (0.62, (30, 29, 27, 255)), (0.64, (46, 44, 40, 255)), (1, (92, 88, 82, 255))], 2.4)
    base.alpha_composite(cav)
    # the side walls, each in its own light
    base.alpha_composite(clip(grad((mx0, my0, mx0 + 3.2, my1), [(0, (70, 67, 62, 200)), (1, (20, 19, 18, 0))], 0, True), inside))
    base.alpha_composite(clip(grad((mx1 - 3.2, my0, mx1, my1), [(0, (10, 10, 10, 0)), (1, (34, 32, 30, 200))], 0, True), inside))
    # 4. the four contacts on the floor: gold pads like the cartridges',
    # each in a dark seat, with a bright edge and a soft glint
    cw, ch, cg = 16.2, 9.0, 8.6                                # (the cartridges' pads, at the slot's size)
    tot = 4 * cw + 3 * cg; cx0 = (mx0 + mx1) / 2 - tot / 2; cy0 = my1 - 2.2 - ch   # down on the floor
    for i in range(4):
        x = cx0 + i * (cw + cg)
        base.alpha_composite(shape((x - 0.7, cy0 - 0.6, x + cw + 0.7, cy0 + ch + 0.9), 1.6, (2, 2, 2, 255)))
        pad = grad((x, cy0, x + cw, cy0 + ch), [(0, (255, 238, 186, 255)), (0.18, (232, 196, 116, 255)),
            (0.55, (196, 152, 70, 255)), (0.82, (150, 108, 40, 255)), (1, (112, 78, 26, 255))], 1.3)
        base.alpha_composite(pad)
        sh = L(); ImageDraw.Draw(sh).rounded_rectangle([*P(x + 0.4, cy0 + ch - 2.2), *P(x + cw - 0.4, cy0 + ch)], round(1.2 * Z), fill=(60, 36, 8, 120))
        base.alpha_composite(clip(sh.filter(ImageFilter.GaussianBlur(0.5 * Z)), pad))
        gl = L(); ImageDraw.Draw(gl).rounded_rectangle([*P(x + 1.1, cy0 + 0.8), *P(x + cw - 1.1, cy0 + 2.0)], round(0.6 * Z), fill=(255, 252, 232, 200))
        base.alpha_composite(clip(gl.filter(ImageFilter.GaussianBlur(0.25 * Z)), pad))
        # pressed spring line down each pad
        ln = L(); ImageDraw.Draw(ln).line([P(x + cw / 2, cy0 + 2.4), P(x + cw / 2, cy0 + ch - 1.6)], fill=(120, 84, 30, 150), width=max(1, round(0.45 * Z)))
        base.alpha_composite(clip(ln, pad))
        rf = grad((x + 0.6, cy0 - 5.5, x + cw - 0.6, cy0 - 0.8), [(0, (200, 158, 80, 0)), (1, (200, 158, 80, 55))], 0.8)
        base.alpha_composite(clip(rf.filter(ImageFilter.GaussianBlur(0.5 * Z)), inside))   # their glow on the back wall
    # 5. ambient occlusion in the mouth's corners, and the lip's light
    ao = L(); ImageDraw.Draw(ao).rounded_rectangle([*P(mx0, my0), *P(mx1, my1)], round(2.4 * Z), outline=(0, 0, 0, 150), width=round(1.0 * Z))
    base.alpha_composite(clip(ao.filter(ImageFilter.GaussianBlur(0.8 * Z)), inside))
    hl = L(); ImageDraw.Draw(hl).rounded_rectangle([*P(bx0 + 3, by0 + 0.5), *P(bx1 - 3, by0 + 1.2)], Z, fill=(255, 255, 255, 190))
    base.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.35 * Z)))
    lo = L(); ImageDraw.Draw(lo).rounded_rectangle([*P(mx0 + 1, my1 + 0.4), *P(mx1 - 1, my1 + 1.0)], Z, fill=(255, 255, 255, 160))
    base.alpha_composite(lo.filter(ImageFilter.GaussianBlur(0.3 * Z)))
    small = np.asarray(base.convert('RGB').resize((X1 - X0, Y1 - Y0), Image.LANCZOS)).astype(float)
    small += rng2.normal(0, 1.4, small.shape[:2])[..., None]           # the grain of a photograph
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
