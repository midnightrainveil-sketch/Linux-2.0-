#!/usr/bin/env python3
"""The clock widget's pictures, from the mock-up itself (art/ClockWidget.png).

    python3 tools/make_clock.py art/ClockWidget.png home/.config/quickshell/widgets/clock

Makes, in the widget's folder:
    clock.png       the clock lifted off its white ground (no shadow, not even
                    the dark one right under its foot),
                    what the widget draws erased: the digits and their glow,
                    the date's dots, the lit lamp (made like the others);
                    the brand made SUISEI (as the lock screen's clock)
    lamp-lit.png    a lamp, lit (from TIME's)
and prints where the clock starts in the mock-up (ORIGIN), which Main.qml
uses: everything there is placed in the mock-up's own pixels.
"""
import os, sys
from collections import deque
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
src0 = np.asarray(Image.open(src).convert('RGB')).astype(float)
img = src0.copy()
H, W, _ = img.shape
rng = np.random.default_rng(3)


def blur(a, r):
    for _ in range(3):
        for ax in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)], mode='edge'), axis=ax)
            a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1) if ax == 0 else (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)
    return a


def fill(mask, r=6, grain=1.0):
    """refill the pixels under mask from the known ones round them, reaching
    further out where there are none near"""
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return
    span = max(xs.max() - xs.min(), ys.max() - ys.min())
    pad = int(min(span, 80) + 8 * r)
    x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
    x1, y1 = min(W, xs.max() + pad), min(H, ys.max() + pad)
    m = mask[y0:y1, x0:x1]
    known = (~m).astype(float)
    part = img[y0:y1, x0:x1]
    est = np.zeros(part.shape); done = np.zeros(m.shape)
    rr = max(2, r // 2)
    while rr < 4 * span + 8 * r and done.min() < 0.999:
        wsum = blur(known, rr)
        e = blur(part * known[..., None], rr) / np.maximum(wsum, 1e-6)[..., None]
        take = np.clip(wsum * 4, 0, 1) * (1 - done)
        est += e * take[..., None]; done += take
        rr *= 2
    est = est / np.maximum(done, 1e-6)[..., None]
    est += rng.normal(0, grain, est.shape[:2])[..., None]
    part[m] = est[m]


def grow(m, n):
    return np.asarray(Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.MaxFilter(2 * n + 1))) > 0


def box(x0, y0, x1, y1):
    m = np.zeros((H, W), bool); m[int(y0):int(y1), int(x0):int(x1)] = True; return m


R, G, B = src0[..., 0], src0[..., 1], src0[..., 2]
amber = (R > 120) & (R - B > 70) & (G > 45)

# ---- the lamps: TIME's, lit, kept; then made like ALARM's (unlit)
lit = src0[333:365, 1222:1254]
lm = Image.new('L', (32 * 4, 32 * 4), 0)
ImageDraw.Draw(lm).rounded_rectangle([0, 0, 32 * 4 - 1, 32 * 4 - 1], 6 * 4, fill=255)
lm = np.asarray(lm.resize((32, 32), Image.LANCZOS))
Image.fromarray(np.dstack([lit, lm]).astype('uint8'), 'RGBA').save(os.path.join(out, 'lamp-lit.png'))
img[333:365, 1222:1254] = src0[377:409, 1222:1254]

def glass(x0, y0, x1, y1, radius, keep=(), deg=2, grain=1.4, dark=30):
    """a surface made anew: a smooth fit (a low polynomial, per channel) of
    its own colour, so nothing drawn on it is left, not even a ghost; kept
    spots (screws) stay; its edge eased into what is round it"""
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    part = img[y0:y1, x0:x1]
    hh, ww = part.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    u, v = xx / ww * 2 - 1, yy / hh * 2 - 1
    terms = [u ** i * v ** j for i in range(deg + 1) for j in range(deg + 1 - i)]
    A = np.stack([t.ravel() for t in terms], 1)
    lum = part.mean(2).ravel()
    use = lum < np.percentile(lum, dark)                    # the glass itself: its darkest, never lit
    fit = np.zeros_like(part)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(A[use], part[..., c].ravel()[use], rcond=None)
        fit[..., c] = (A @ coef).reshape(hh, ww)
    fit += rng.normal(0, grain, (hh, ww, 1))
    m = Image.new('L', (ww * 4, hh * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, ww * 4 - 1, hh * 4 - 1], radius * 4, fill=255)
    for kx, ky, kr in keep:
        ImageDraw.Draw(m).ellipse([(kx - x0 - kr) * 4, (ky - y0 - kr) * 4, (kx - x0 + kr) * 4, (ky - y0 + kr) * 4], fill=0)
    m = np.asarray(m.resize((ww, hh), Image.LANCZOS).filter(ImageFilter.GaussianBlur(2))).astype(float)[..., None] / 255
    part[:] = fit * m + part * (1 - m)


# ---- the display's glass, its digits gone (the four screws stay)
glass(258, 288, 1162, 620, 20, keep=[(292, 311, 16), (1126, 311, 16), (292, 574, 16), (1126, 574, 16)])
# ---- the date strip, its dots gone
glass(390, 676, 898, 733, 6, deg=2, grain=1.0)

# ---- the brand: BOTSYNC out (each column eased from the plate above to
# the plate below), SUISEI in; the /// after it stays
top, bot = img[185, 380:578].copy(), img[229, 380:578].copy()
t = np.linspace(0, 1, 45)[1:-1][:, None, None]
img[186:229, 380:578] = top[None] * (1 - t) + bot[None] * t + rng.normal(0, 2.2, (43, 198, 1))
font = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf', 46 * 4)
layer = Image.new('L', (900, 300), 0)
d = ImageDraw.Draw(layer)
x = 20
for ch in 'SUISEI':
    d.text((x, 20), ch, font=font, fill=255); x += d.textlength(ch, font=font) + 6
layer = layer.crop(layer.getbbox())
# the mock-up's lettering leans forward, about 0.2
sh = 0.2
layer = layer.transform((int(layer.width + sh * layer.height), layer.height), Image.AFFINE,
                        (1, sh, -sh * layer.height, 0, 1, 0), Image.BICUBIC)
h = 31
layer = layer.resize((round(layer.width * h / layer.height), h), Image.LANCZOS)
ink = np.asarray(layer).astype(float) / 255 * 0.95
ox, oy = 572 - layer.width, 192
reg = img[oy:oy + h, ox:ox + layer.width]
reg[:] = reg * (1 - ink[..., None]) + np.array([70, 64, 56]) * ink[..., None]

# ---- off the white: the ground, every patch of it (also inside the
# handles' loops, which the corners cannot reach), and no shadow kept
lum0 = src0.mean(2); sat0 = src0.max(2) - src0.min(2)
ground = (lum0 > 222) & (sat0 < 24)
bg = np.zeros((H, W), bool)
seen = np.zeros((H, W), bool)
for sy in range(0, H, 2):
    for sx in np.nonzero(ground[sy] & ~seen[sy])[0]:
        comp = [(sx, sy)]; seen[sy, sx] = True; q = deque(comp)
        while q:
            px, py = q.popleft()
            for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; q.append((nx, ny)); comp.append((nx, ny))
        if len(comp) > 300:                     # a glint on the metal is far smaller
            xs_, ys_ = zip(*comp); bg[list(ys_), list(xs_)] = True
# the shadow under the clock (soft grey on the ground) goes too: whatever
# below its foot is lighter than its darkest metal
foot = np.zeros((H, W), bool); foot[800:, :] = True
bg |= foot & (lum0 > 150) & (sat0 < 30)
edge = ~bg & grow(bg, 1)
alpha = np.where(bg, 0.0, 1.0)
alpha = np.where(edge, np.clip((255 - lum0) / 70, 0.35, 1), alpha)
rgb = np.where(bg[..., None], 0, img)
ys, xs = np.nonzero(alpha > 0.03)
X0, Y0 = int(xs.min()) - 2, int(ys.min()) - 2
X1, Y1 = int(xs.max()) + 3, int(ys.max()) + 3
# and the dark contact shadow right under its foot (the picture keeps its
# size, so the widget's pixels stay where they are): below the foot's line
# (y 896) only the red corners' paint stays, the rows nearest it softened
fy = 896
below = np.zeros((H, W), bool); below[fy:, :] = True
red = (img[..., 0] > 90) & (img[..., 0] > img[..., 1] + 45)
alpha = np.where(below & ~red, 0.0, alpha)
alpha[fy - 1, :] = np.minimum(alpha[fy - 1, :], np.where(red[fy - 1], 1.0, 0.6))
rgb = np.where((alpha == 0)[..., None], 0, rgb)
Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255])[Y0:Y1, X0:X1].astype('uint8'), 'RGBA') \
    .save(os.path.join(out, 'clock.png'), optimize=True)
print('ORIGIN', (X0, Y0), 'size', (X1 - X0, Y1 - Y0))
