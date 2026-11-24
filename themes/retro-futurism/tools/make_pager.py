#!/usr/bin/env python3
"""The KAZE pager (the notifications), from its mock-up (art/Notification.png).

    python3 tools/make_pager.py art/Notification.png home/.config/quickshell/assets/pager

Makes (all in the mock-up's own pixels; body.png starts at ORIGIN):
    body.png      the pager off its white ground, its e-ink screen blank (the
                  shell writes on it), its lamp off
    key-clear.png, key-all.png, key-prev.png, key-next.png
                  its four keys, to press
(pip: numpy pillow opencv-python-headless)
"""
import os, sys
import numpy as np, cv2
from PIL import Image, ImageDraw
from collections import deque

src, out = sys.argv[1:3]
os.makedirs(out, exist_ok=True)
src0 = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
img = src0.copy()
H, W, _ = img.shape
CROP = (36, 128, 1956, 702)
ORIGIN = CROP[:2]

PAPER = (121, 211, 1689, 535, 18)          # the e-ink screen, inside its glass
LAMP = (935, 602)
KEYS = {'clear': (986, 571, 1192, 631, 15), 'all': (1252, 571, 1459, 631, 15),
        'prev': (1547, 567, 1713, 643, 12), 'next': (1716, 567, 1883, 643, 12)}


def rrect(w, h, r, scale=4):
    m = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], r * scale, fill=255)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def save(rgb, a, name):
    Image.fromarray(np.dstack([rgb, a * 255]).clip(0, 255).astype('uint8'), 'RGBA').save(os.path.join(out, name), optimize=True)


# ---- the keys, cut first
for name, (x0, y0, x1, y1, r) in KEYS.items():
    save(src0[y0:y1, x0:x1], rrect(x1 - x0, y1 - y0, r), f'key-{name}.png')

# ---- the screen blank: its paper as it lies (its light, its grain) where
# nothing is written; under the writing, the paper's light fitted smoothly
# across it, and its grain
x0, y0, x1, y1, r = PAPER
P = src0[y0:y1, x0:x1]
L = P.mean(2)
h, w = L.shape
# (the paper round each point: the light it has where nothing is written,
# its brightest nearby, smoothed; the writing is what is darker)
paper_l = cv2.GaussianBlur(cv2.dilate(L, np.ones((61, 61), np.uint8)), (0, 0), 15)
ink = cv2.dilate((L < paper_l - 12).astype(np.uint8), np.ones((5, 5), np.uint8), iterations=2).astype(bool)
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
u, v = xx / w - 0.5, yy / h - 0.5
basis = np.stack([np.ones_like(u), u, v, u * u, v * v, u * v, u ** 3, v ** 3], -1)
fit = np.zeros_like(P)
ok = ~ink
for c in range(3):
    coef, *_ = np.linalg.lstsq(basis[ok], P[..., c][ok], rcond=None)
    fit[..., c] = basis @ coef
grain = np.random.default_rng(7).normal(0, 1.6, (h, w))[..., None]
blank = np.where(ink[..., None], fit + grain, P)
# (the soft edge of what was written, eased into it)
soft = cv2.GaussianBlur(ink.astype(np.float32), (0, 0), 1.2)[..., None]
blank = blank * (1 - soft) + (fit + grain) * soft
inside = rrect(w, h, r)[..., None]
img[y0:y1, x0:x1] = P * (1 - inside) + blank * inside

# ---- the lamp off: a dark glass bead, its green glow gone from round it
lx, ly = LAMP
R = 30
reg = img[ly - R:ly + R, lx - R:lx + R]
g = src0[ly - R:ly + R, lx - R:lx + R]
green = np.clip((g[..., 1] - g[..., [0, 2]].max(2) - 4) / 30, 0, 1)
yy, xx = np.mgrid[-R:R, -R:R].astype(np.float32)
d = np.hypot(xx, yy)
body = cv2.GaussianBlur(np.where((d > 16)[..., None], g, np.nan_to_num(g * 0) + np.array([56, 59, 62])), (0, 0), 4)
around = np.clip((d - 9) / 4, 0, 1)[..., None] * green[..., None]
reg[:] = reg * (1 - around) + body * around
bead = np.clip(9.5 - d, 0, 1)[..., None]
shade = (0.55 + 0.45 * np.clip(1 - np.hypot(xx + 3, yy + 3) / 10, 0, 1))[..., None]
reg[:] = reg * (1 - bead) + np.array([62, 68, 64]) * shade * bead

# ---- off the white: the pager by its outline (flood from the corners)
lum0, sat0 = src0.mean(2), src0.max(2) - src0.min(2)
ground = (lum0 > 238) & (sat0 < 12)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
# (its shadow on the white below it: a soft dark one, the white gone)
alpha = np.where(bg, np.clip((240 - lum0) / 240 * 1.2, 0, 0.4), 1.0)
alpha = cv2.GaussianBlur(alpha.astype(np.float32), (0, 0), 0.7)
alpha = np.where(bg, alpha, cv2.GaussianBlur(alpha, (0, 0), 0.5))
rgb = np.where(bg[..., None], 0, img)
x0, y0, x1, y1 = CROP
save(rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1], 'body.png')
print('ORIGIN', ORIGIN, 'size', (x1 - x0, y1 - y0))
