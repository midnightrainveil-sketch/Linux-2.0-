#!/usr/bin/env python3
"""The app cartridges, from the mock-up (art/Cartridges.png: six cartridges,
three rows of label colour: charcoal, cream, sage).

    python3 tools/make_cartridges.py art/Cartridges.png home/.config/quickshell/assets/cartridges

Makes, all 350 x 445, the same frame (the clear case, the gold contacts):
    browser.png  terminal.png  files.png  settings.png  music.png  images.png
                    the six illustrated labels, their numbers erased (the
                    shell writes each cartridge's own)
    blank-charcoal.png  blank-cream.png  blank-sage.png
                    the labels with nothing on them (the art lifted and the
                    plate made anew), for any other app: the shell sets its
                    icon into the plate
Every cartridge is lifted off the white, without its shadow.

In each, in its own pixels: the plate's free middle is about 62-292 x
108-322 (its centre 177, 215); the number sits on the tab at 244-300 x
66-102.
"""
import os, sys
from collections import deque
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
A = np.asarray(Image.open(src).convert('RGB')).astype(float)
rng = np.random.default_rng(11)
W, H = 350, 445
# each cartridge's box in the mock-up (left, top), the grid's columns and rows
COLS, ROWS = (117, 548, 981), (27, 545)
ART = {'browser': (0, 0), 'terminal': (1, 0), 'files': (2, 0),
       'settings': (0, 1), 'music': (1, 1), 'images': (2, 1)}
BLANKS = {'blank-charcoal': 'browser', 'blank-cream': 'settings', 'blank-sage': 'files'}


def crop(c, r):
    x, y = COLS[c], ROWS[r]
    return A[y:y + H, x:x + W].copy()


def fit(part, box, ring=7, deg=2, grain=1.4, radius=8, feather=3):
    """make a box of a plate anew: a smooth fit of the plate's colour taken
    only from a ring just round the box (clean plate, never the art), a fine
    grain; its edge eased in"""
    x0, y0, x1, y1 = box
    X0, Y0, X1, Y1 = x0 - ring, y0 - ring, x1 + ring, y1 + ring
    p = part[Y0:Y1, X0:X1]
    hh, ww = p.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    u, v = xx / ww * 2 - 1, yy / hh * 2 - 1
    terms = [u ** i * v ** j for i in range(deg + 1) for j in range(deg + 1 - i)]
    M = np.stack([t.ravel() for t in terms], 1)
    inner = (xx >= ring) & (xx < ww - ring) & (yy >= ring) & (yy < hh - ring)
    use = ~inner.ravel()
    # leave out what is not plate in the ring itself (lines, marks): keep
    # the pixels near its own middle colour
    lum = p.mean(2).ravel()
    med = np.median(lum[use])
    use &= np.abs(lum - med) < 14
    f = np.zeros_like(p)
    for ch in range(3):
        coef, *_ = np.linalg.lstsq(M[use], p[..., ch].ravel()[use], rcond=None)
        f[..., ch] = (M @ coef).reshape(hh, ww)
    f += rng.normal(0, grain, (hh, ww, 1))
    m = Image.new('L', (ww * 4, hh * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([ring * 4, ring * 4, (ww - ring) * 4 - 1, (hh - ring) * 4 - 1], radius * 4, fill=255)
    m = np.asarray(m.resize((ww, hh), Image.LANCZOS).filter(ImageFilter.GaussianBlur(feather))).astype(float)[..., None] / 255
    p[:] = f * m + p * (1 - m)


def number_off(part):
    """the tab's number: its dark strokes refilled from the tab round them"""
    x0, y0, x1, y1 = 244, 66, 300, 102
    p = part[y0:y1, x0:x1]
    lum = p.mean(2)
    tab = lum > np.percentile(lum, 40)
    mask = ~tab
    mask = np.asarray(Image.fromarray((mask * 255).astype('uint8')).filter(ImageFilter.MaxFilter(5))) > 0
    known = (~mask).astype(float)
    for r in (3, 6, 10, 16):
        k = np.ones(2 * r + 1) / (2 * r + 1)
        def bl(a):
            a = np.apply_along_axis(lambda q: np.convolve(q, k, 'same'), 0, a)
            return np.apply_along_axis(lambda q: np.convolve(q, k, 'same'), 1, a)
        wsum = bl(known)
        est = np.dstack([bl(p[..., c] * known) for c in range(3)]) / np.maximum(wsum, 1e-6)[..., None]
        fillnow = mask & (wsum > 0.05)
        p[fillnow] = est[fillnow] + rng.normal(0, 1.0, (fillnow.sum(), 1))
        known = np.maximum(known, fillnow.astype(float))
        mask = mask & ~fillnow
        if not mask.any():
            break
    if mask.any():                                  # (whatever is left: the tab's own colour)
        p[mask] = np.median(p[~mask], axis=0)


def lift(part):
    """off the white, by every patch of ground that reaches the box's edge;
    the shadow under it goes too"""
    lum = part.mean(2); sat = part.max(2) - part.min(2)
    ground = (lum > 236) & (sat < 14)
    bg = np.zeros(lum.shape, bool)
    q = deque((x, y) for x in range(W) for y in (0, H - 1)) + deque((x, y) for y in range(H) for x in (0, W - 1))
    q = deque(p for p in q if ground[p[1], p[0]])
    for x, y in q: bg[y, x] = True
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True; q.append((nx, ny))
    foot = np.zeros(lum.shape, bool); foot[415:, :] = True
    bg |= foot & (lum > 160) & (sat < 22)
    edge = ~bg & (np.asarray(Image.fromarray((bg * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0)
    alpha = np.where(bg, 0.0, 1.0)
    alpha = np.where(edge, np.clip((255 - lum) / 50, 0.4, 1), alpha)
    return np.dstack([np.where(bg[..., None], 0, part), alpha * 255]).astype('uint8')


parts = {}
for name, (c, r) in ART.items():
    p = crop(c, r)
    number_off(p)
    parts[name] = p
    Image.fromarray(lift(p), 'RGBA').save(os.path.join(out, name + '.png'), optimize=True)

for name, base in BLANKS.items():
    p = parts[base].copy()
    fit(p, (62, 106, 296, 316))
    fit(p, (62, 296, 228, 337), radius=4)         # the art's foot, short of the screw tab and the lines
    fit(p, (198, 296, 250, 317), radius=3)        # and up to the tab's slope
    fit(p, (150, 326, 216, 341), radius=3, feather=1.5)   # the art's soft shadow, over the lines
    fit(p, (216, 306, 245, 327), radius=3, feather=1.5)   # ... and by the tab
    Image.fromarray(lift(p), 'RGBA').save(os.path.join(out, name + '.png'), optimize=True)
print('made', len(ART) + len(BLANKS), 'cartridges of', (W, H))
