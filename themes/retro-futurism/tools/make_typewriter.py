#!/usr/bin/env python3
"""The research station (the typewriter), from its mock-up (art/Typewriter.png).

    python3 tools/make_typewriter.py art/Typewriter.png home/.config/quickshell/widgets/typewriter

Makes (all in the mock-up's own pixels):
    body.png      the machine off its white ground, its tablet and its
                  carriage taken out (the rails carried on behind it); starts
                  at BODY_ORIGIN
    tablet.png    the tablet in its slot, its e-ink screen blank (the widget
                  writes on it): drawn stretched (its frame kept, its middle
                  longer) when it is pulled out; starts at TABLET_ORIGIN
    carriage.png  the carriage, run along its rails as one types; starts at
                  CARRIAGE_ORIGIN
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

TABLET = (152, 12, 1384, 373, 60)          # its frame: x0 y0 x1 y1 (its foot in the slot), corner radius
PAPER = (213, 103, 1322, 361, 14)          # its screen, in the picture
CARRIAGE = [(749, 368, 792, 400, 6), (702, 393, 824, 462, 8), (744, 455, 797, 489, 4)]


def rrect(w, h, r, scale=4, corners=(True, True, True, True)):
    m = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], r * scale, fill=255, corners=corners)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def save(rgb, a, name):
    Image.fromarray(np.dstack([rgb, a * 255]).clip(0, 255).astype('uint8'), 'RGBA').save(os.path.join(out, name), optimize=True)


# ---- the carriage, cut; the rails behind it carried on from their left
cx0 = min(b[0] for b in CARRIAGE); cy0 = min(b[1] for b in CARRIAGE)
cx1 = max(b[2] for b in CARRIAGE); cy1 = max(b[3] for b in CARRIAGE)
ca = np.zeros((cy1 - cy0, cx1 - cx0), np.float32)
for x0, y0, x1, y1, r in CARRIAGE:
    ca[y0 - cy0:y1 - cy0, x0 - cx0:x1 - cx0] = np.maximum(ca[y0 - cy0:y1 - cy0, x0 - cx0:x1 - cx0], rrect(x1 - x0, y1 - y0, r))
save(src0[cy0:cy1, cx0:cx1], ca, 'carriage.png')
w = cx1 - cx0
behind = src0[cy0:cy1, cx0 - w:cx0].copy()
# (below the rails, the feed's plate and the gear track: from just right of it)
lo = 455 - cy0
behind[lo:] = src0[cy0 + lo:cy1, cx0 + 64:cx1 + 64]
img[cy0:cy1, cx0:cx1] = img[cy0:cy1, cx0:cx1] * (1 - ca[..., None]) + behind * ca[..., None]

# ---- the tablet: its screen blank (the paper's light painted in from round
# what was written, and its grain)
x0, y0, x1, y1, r = PAPER
P = src0[y0:y1, x0:x1]
L = P.mean(2)
h, w = L.shape
paper_l = cv2.GaussianBlur(cv2.dilate(L, np.ones((31, 31), np.uint8)), (0, 0), 9)
ink = cv2.dilate((L < paper_l - 24).astype(np.uint8), np.ones((5, 5), np.uint8), iterations=2).astype(bool)
f = 6
small = cv2.resize(P, (w // f, h // f), interpolation=cv2.INTER_AREA)
mask = (cv2.resize(ink.astype(np.float32), (w // f, h // f), interpolation=cv2.INTER_AREA) > 0).astype(np.uint8)
mask = cv2.dilate(mask, np.ones((3, 3), np.uint8))
ey = np.minimum(np.arange(h // f), h // f - 1 - np.arange(h // f))[:, None]
ex = np.minimum(np.arange(w // f), w // f - 1 - np.arange(w // f))[None, :]
mask[np.minimum(ex, ey) < 2] = 1
light = cv2.inpaint(small.clip(0, 255).astype(np.uint8), mask * 255, 6, cv2.INPAINT_TELEA).astype(np.float32)
light = cv2.GaussianBlur(light, (0, 0), 2.5)
# (its light smooth, nothing of what was written left in it, as it is
# stretched when pulled out: a profile down it times one across it)
rows = cv2.GaussianBlur(light.mean(1, keepdims=True), (0, 0), sigmaX=0.1, sigmaY=6)
cols = cv2.GaussianBlur(light.mean(0, keepdims=True), (0, 0), sigmaX=8, sigmaY=0.1)
light = rows * (cols / cols.mean(1, keepdims=True))
fit = cv2.resize(light, (w, h), interpolation=cv2.INTER_CUBIC)
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
grain = np.random.default_rng(12).normal(0, 1.4, (h, w))[..., None]
blank = fit + grain
inner = np.clip((edge - 5) / 4, 0, 1)[..., None]
inside = rrect(w, h, r)[..., None]
paper = P * (1 - inside * inner) + blank * inside * inner

tx0, ty0, tx1, ty1, tr = TABLET
tab = src0[ty0:ty1, tx0:tx1].copy()
tab[y0 - ty0:y1 - ty0, x0 - tx0:x1 - tx0] = paper
ta = rrect(tx1 - tx0, ty1 - ty0, tr, corners=(True, True, False, False))

# ---- the body: off the white (flood from the corners), the tablet's place
# let through
lum0, sat0 = src0.mean(2), src0.max(2) - src0.min(2)
ground = (lum0 > 243) & (sat0 < 10)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
body = ~bg
cross = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
for _ in range(2):
    rim = body & cv2.dilate(bg.astype(np.uint8), cross).astype(bool)
    peel = rim & (lum0 > 222) & (sat0 < 12)
    body &= ~peel; bg |= peel
n, lab, st, _ = cv2.connectedComponentsWithStats(body.astype(np.uint8), connectivity=8)
body = lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
body = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
alpha = cv2.GaussianBlur(body.astype(np.float32), (0, 0), 0.7) * cv2.dilate(body.astype(np.uint8), cross)
# (the tablet: its rounded box, less the white ground round its corners)
ground_soft = cv2.GaussianBlur(bg.astype(np.float32), (0, 0), 0.7)
ta = ta * (1 - ground_soft[ty0:ty1, tx0:tx1])
save(tab, ta, 'tablet.png')
hole = np.zeros((H, W), np.float32)
hole[ty0:ty1, tx0:tx1] = rrect(tx1 - tx0, ty1 - ty0, tr, corners=(True, True, False, False))
alpha = alpha * (1 - hole)
ys, xs = np.where(alpha > 0.02)
bx0, by0, bx1, by1 = xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3
save(img[by0:by1, bx0:bx1], alpha[by0:by1, bx0:bx1], 'body.png')
print('BODY_ORIGIN', (int(bx0), int(by0)), 'size', (int(bx1 - bx0), int(by1 - by0)))
print('TABLET_ORIGIN', (tx0, ty0), 'size', (tx1 - tx0, ty1 - ty0))
print('CARRIAGE_ORIGIN', (cx0, cy0), 'size', (cx1 - cx0, cy1 - cy0))

# ---- the screen's icons (vector, in its ink, and in the paper's light for a dark chip)
INKS = {'ink': '#2f302f', 'light': '#e8e7e2'}
ICONS = {
    'search': '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5l5 5"/>',
    'stack': '<path d="M12 3l9 4.5-9 4.5-9-4.5z"/><path d="M3 12l9 4.5 9-4.5M3 16.5l9 4.5 9-4.5"/>',
    'notes': '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5M9 12h7M9 15.5h7M9 19h4"/>',
    'archive': '<rect x="3" y="7" width="18" height="13" rx="1.5"/><path d="M6 7V4.5h12V7"/><circle cx="12" cy="13" r="2.6"/><path d="M5.5 10h2"/>',
    'export': '<path d="M3 8v12h16v-5"/><path d="M3 8h5l2-3h5"/><path d="M11 13l8-8M14 5h5v5"/>',
    'source': '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5M9 13h7M9 17h7"/>',
}
for name, body in ICONS.items():
    for tone, col in INKS.items():
        open(os.path.join(out, f'icon-{name}-{tone}.svg'), 'w').write(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="96" height="96" fill="none" '
            f'stroke="{col}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">{body}</svg>')
