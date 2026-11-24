#!/usr/bin/env python3
"""The organizer (the SHINWA digital planner), from its mock-up (art/Calendar.png).

    python3 tools/make_organizer.py art/Calendar.png home/.config/quickshell/widgets/organizer

Makes (all in the mock-up's own pixels; body.png starts at ORIGIN):
    body.png     the planner off its white ground, its e-ink screen blank (the
                 widget draws everything on it)
    key-*.png    its keys, to press: the four view keys (calendar, agenda,
                 tasks, notes), the rocker's two halves, the round key
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

PAPER = (99, 133, 934, 1311, 16)
KEYS = {   # x0 y0 x1 y1, corner radius
    'calendar': (259, 1389, 348, 1447, 10), 'agenda': (348, 1389, 434, 1447, 3),
    'tasks': (434, 1389, 520, 1447, 3), 'notes': (520, 1389, 607, 1447, 10),
    'prev': (655, 1388, 748, 1446, 26), 'next': (749, 1388, 842, 1446, 26),
    'round': (866, 1378, 940, 1452, 37),
}


def rrect(w, h, r, scale=4):
    m = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], r * scale, fill=255)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def save(rgb, a, name):
    Image.fromarray(np.dstack([rgb, a * 255]).clip(0, 255).astype('uint8'), 'RGBA').save(os.path.join(out, name), optimize=True)


for name, (x0, y0, x1, y1, r) in KEYS.items():
    save(src0[y0:y1, x0:x1], rrect(x1 - x0, y1 - y0, r), f'key-{name}.png')

# ---- the screen blank: the paper's light (fitted smoothly over where nothing
# is written) and its grain, under all that was written
x0, y0, x1, y1, r = PAPER
P = src0[y0:y1, x0:x1]
L = P.mean(2)
h, w = L.shape
paper_l = cv2.GaussianBlur(cv2.dilate(L, np.ones((41, 41), np.uint8)), (0, 0), 12)
ink = cv2.dilate((L < paper_l - 28).astype(np.uint8), np.ones((5, 5), np.uint8), iterations=2).astype(bool)
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
# the paper's light: the paper itself, small, with what was written painted
# out of it from round it, then smoothed and brought back to size
f = 8
small = cv2.resize(P, (w // f, h // f), interpolation=cv2.INTER_AREA)
mask = (cv2.resize(ink.astype(np.float32), (w // f, h // f), interpolation=cv2.INTER_AREA) > 0).astype(np.uint8)
mask = cv2.dilate(mask, np.ones((3, 3), np.uint8))
ey = np.minimum(np.arange(h // f), h // f - 1 - np.arange(h // f))[:, None]
ex = np.minimum(np.arange(w // f), w // f - 1 - np.arange(w // f))[None, :]
mask[(np.minimum(ex, ey) < 2)] = 1                      # (not the glass's dark rim)
light = cv2.inpaint(small.clip(0, 255).astype(np.uint8), mask * 255, 6, cv2.INPAINT_TELEA).astype(np.float32)
light = cv2.GaussianBlur(light, (0, 0), 3)
fit = cv2.resize(light, (w, h), interpolation=cv2.INTER_CUBIC)
grain = np.random.default_rng(9).normal(0, 1.5, (h, w))[..., None]
grain += cv2.GaussianBlur(np.random.default_rng(10).normal(0, 2.2, (h, w)).astype(np.float32), (0, 0), 2.5)[..., None]
blank = fit + grain
# the glass's rim kept as it is (its inner shadow), the paper inside it new
inner = np.clip((edge - 6) / 5, 0, 1)[..., None]
inside = rrect(w, h, r)[..., None]
img[y0:y1, x0:x1] = P * (1 - inside * inner) + blank * inside * inner

# ---- off the white: the planner by its outline (flood from the corners)
lum0, sat0 = src0.mean(2), src0.max(2) - src0.min(2)
ground = (lum0 > 244) & (sat0 < 10)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
# (the light grey of the ground's soft shadow round it: peeled, a pixel or two)
body = ~bg
cross = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
for _ in range(2):
    rim = body & cv2.dilate(bg.astype(np.uint8), cross).astype(bool)
    peel = rim & (lum0 > 225) & (sat0 < 12)
    body &= ~peel; bg |= peel
n, lab, st, _ = cv2.connectedComponentsWithStats(body.astype(np.uint8), connectivity=8)
big = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
body = lab == big
body = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
alpha = cv2.GaussianBlur(body.astype(np.float32), (0, 0), 0.7) * cv2.dilate(body.astype(np.uint8), cross)
ys, xs = np.where(alpha > 0.02)
CROP = (xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3)
x0, y0, x1, y1 = CROP
save(img[y0:y1, x0:x1], alpha[y0:y1, x0:x1], 'body.png')
print('ORIGIN', (int(x0), int(y0)), 'size', (int(x1 - x0), int(y1 - y0)))


# ---- the screen's own drawings (vector, in its ink): its icons, in ink and
# in the paper's light (for a dark tab), and the ginkgo sprig in its corner
INKS = {'ink': '#343534', 'light': '#e8e7e2'}
ICONS = {
    'calendar': '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>'
                '<path d="M7 13.5h2M11 13.5h2M15 13.5h2M7 17h2M11 17h2M15 17h2" stroke-width="1.8"/>',
    'agenda': '<path d="M9 6h12M9 12h12M9 18h12"/><path d="M4 6h1M4 12h1M4 18h1" stroke-width="2.6"/>',
    'tasks': '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M7.5 12.5l3 3 6-7"/>',
    'notes': '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5M9 12h7M9 15.5h7M9 19h4"/>',
    'bell': '<path d="M6 17V11a6 6 0 0112 0v6l1.5 2h-15z"/><path d="M10 21h4"/>',
    'play': '<path d="M7 5l11 7-11 7z" fill="CUR"/>',
    'plus': '<path d="M12 5v14M5 12h14"/>',
}
for name, body in ICONS.items():
    for tone, col in INKS.items():
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="96" height="96" fill="none" '
               f'stroke="{col}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">'
               + body.replace('CUR', col) + '</svg>')
        open(os.path.join(out, f'icon-{name}-{tone}.svg'), 'w').write(svg)

import math


def leaf(px, py, ang, size):
    """a ginkgo leaf: its stalk from (px, py) toward ang, its fan beyond
    (softly waved, notched in its middle), and its fine veins; SVG path data
    for the outline and for the veins"""
    a = math.radians(ang)
    sx, sy = px + math.cos(a) * size * 0.55, py + math.sin(a) * size * 0.55
    stalk = f'M{px:.1f} {py:.1f} Q{(px + sx) / 2 + math.cos(a + 1.2) * 2:.1f} {(py + sy) / 2 + math.sin(a + 1.2) * 2:.1f} {sx:.1f} {sy:.1f} '
    spread = 62
    pts = []
    for i in range(41):
        t = -spread + 2 * spread * i / 40
        r = size * (1 + 0.035 * math.sin(i * 1.3))
        r *= 1 - 0.24 * max(0, 1 - abs(t) / 9)          # the notch
        r *= 0.86 + 0.14 * math.cos(math.radians(t) * 0.9)
        pts.append((sx + math.cos(a + math.radians(t)) * r, sy + math.sin(a + math.radians(t)) * r))
    fan = f'M{sx:.1f} {sy:.1f} ' + ' '.join(f'L{x:.1f} {y:.1f}' for x, y in pts) + ' Z '
    veins = ''
    for t in range(-50, 51, 14):
        r = size * 0.8 * (0.86 + 0.14 * math.cos(math.radians(t) * 0.9))
        veins += f'M{sx:.1f} {sy:.1f} L{sx + math.cos(a + math.radians(t)) * r:.1f} {sy + math.sin(a + math.radians(t)) * r:.1f} '
    return stalk, fan, veins


def bez(t, p0, p1, p2, p3):
    u = 1 - t
    return tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * d for a, b, c, d in zip(p0, p1, p2, p3))


P0, P1, P2, P3 = (10, 158), (70, 140), (120, 100), (178, 40)
stem = f'M{P0[0]} {P0[1]} C {P1[0]} {P1[1]}, {P2[0]} {P2[1]}, {P3[0]} {P3[1]}'
stalks = fans = veins = ''
for t, side, size in [(0.42, -1, 21), (0.55, 1, 22), (0.68, -1, 24), (0.8, 1, 24), (0.9, -1, 25), (1.0, 0, 27)]:
    x, y = bez(t, P0, P1, P2, P3)
    x2, y2 = bez(min(1, t + 0.01), P0, P1, P2, P3) if t < 1 else bez(0.99, P0, P1, P2, P3)
    tang = math.degrees(math.atan2(y2 - y, x2 - x)) if t < 1 else math.degrees(math.atan2(y - y2, x - x2))
    st, fa, ve = leaf(x, y, tang + side * 58, size)
    stalks += st; fans += fa; veins += ve
svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 170" width="660" height="510">'
       '<g fill="none" stroke="#3a3b3a" stroke-linecap="round" stroke-linejoin="round">'
       '<circle cx="118" cy="84" r="72" stroke-width="0.9" stroke-dasharray="1.4 5" opacity="0.55"/>'
       f'<path d="{stem}" stroke-width="1.9"/>'
       f'<path d="{stalks}" stroke-width="1.2"/>'
       f'<path d="{fans}" stroke-width="1.15" fill="#3a3b3a" fill-opacity="0.08"/>'
       f'<path d="{veins}" stroke-width="0.5" opacity="0.7"/>'
       '</g></svg>')
open(os.path.join(out, 'ginkgo.svg'), 'w').write(svg)
