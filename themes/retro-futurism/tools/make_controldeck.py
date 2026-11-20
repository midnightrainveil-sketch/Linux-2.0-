#!/usr/bin/env python3
"""The control deck's pictures, from the mock-up itself (art/ControlDeck.png).

    python3 tools/make_controldeck.py art/ControlDeck.png home/.config/quickshell/widgets/controls

Makes, in the widget's folder:
    deck.png        the deck lifted off its white ground (its shadow kept),
                    everything that changes erased: the screen's text, the
                    switches' knobs and lamps, the buttons, the faders' and
                    the lock's thumbs, the read-outs' figures, the labels the
                    widget writes itself
    key-up.png      a round button, up      (from BALANCED)
    key-lit.png     a round button, lit     (from QUIET)
    rate-up.png     a refresh button, up    (from 60 Hz, its label erased)
    rate-lit.png    a refresh button, lit   (from AUTO, its label erased)
    knob.png        a switch's knob
    fill-end.png, fill-mid.png   the blue it uncovers (its end, a column to stretch)
    fader.png       a fader's thumb
    tab.png         the lock slider's thumb
and prints where things are (the mock-up's pixels; deck.png starts at
ORIGIN), which Main.qml uses.

Everything erased is filled from what lies round it (a normalised blur:
each missing pixel takes the weighted colour of the known ones near it), so
the screen's glow and the plates' shading run on unbroken.
"""
import os, sys
from collections import deque
from PIL import Image, ImageDraw
import numpy as np

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
img = np.asarray(Image.open(src).convert('RGB')).astype(float)
H, W, _ = img.shape
rng = np.random.default_rng(7)

ORIGIN = (50, 28)                   # deck.png's top-left in the mock-up
CROP = (50, 28, 1612, 948)


# ---- filling -------------------------------------------------------------
def blur(a, r):
    """three box blurs of radius r ~ a gaussian; a is 2-D or 3-D"""
    for _ in range(3):
        for ax in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)], mode='edge'), axis=ax)
            if ax == 0:
                a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
            else:
                a = (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)
    return a


def fill(mask, r=10, grain=1.0, box=None):
    """refill the pixels under mask from those round them: the colour of the
    known pixels near each, reaching further out where there are none near"""
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return
    span = max(xs.max() - xs.min(), ys.max() - ys.min())
    pad = int(span + 8 * r)
    x0, y0 = max(0, xs.min() - pad), max(0, ys.min() - pad)
    x1, y1 = min(W, xs.max() + pad), min(H, ys.max() + pad)
    m = mask[y0:y1, x0:x1]
    known = (~m).astype(float)
    part = img[y0:y1, x0:x1]
    est = np.zeros(part.shape); done = np.zeros(m.shape)
    rr = max(2, r // 3)
    while rr < 4 * span + 4 * r and done.min() < 1:
        wsum = blur(known, rr)
        e = blur(part * known[..., None], rr) / np.maximum(wsum, 1e-6)[..., None]
        take = np.clip(wsum * 4, 0, 1) * (1 - done)          # where this radius has enough to go on
        est += e * take[..., None]; done += take
        rr *= 2
    est = est / np.maximum(done, 1e-6)[..., None]
    est += rng.normal(0, grain, est.shape[:2])[..., None]
    part[m] = est[m]


def across(x0, y0, x1, y1, axis, grain=0.8):
    """refill a box from its two clean edges: 'v' blends each column from the
    row above the box to the row below (plates shaded top to bottom); 'h'
    each row from the column left of it to the one right (tracks)"""
    x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
    if axis == 'v':
        top, bot = img[y0 - 1, x0:x1].copy(), img[y1, x0:x1].copy()
        t = np.linspace(0, 1, y1 - y0 + 2)[1:-1][:, None, None]
        img[y0:y1, x0:x1] = top[None] * (1 - t) + bot[None] * t
    else:
        left, right = img[y0:y1, x0 - 1].copy(), img[y0:y1, x1].copy()
        t = np.linspace(0, 1, x1 - x0 + 2)[1:-1][None, :, None]
        img[y0:y1, x0:x1] = left[:, None] * (1 - t) + right[:, None] * t
    img[y0:y1, x0:x1] += rng.normal(0, grain, (y1 - y0, x1 - x0, 1))


def smooth_glass(x0, y0, x1, y1):
    """the screen's glass made anew: its own glow, no marks on it"""
    part = img[y0:y1, x0:x1]
    lum = part.mean(2)
    # what is plain glass: not much darker than the glass round it
    base = blur(lum, 30)
    clean = (lum > base - 4).astype(float)
    for _ in range(2):
        model = blur(part * clean[..., None], 22) / np.maximum(blur(clean, 22), 1e-6)[..., None]
        clean = (lum > model.mean(2) - 4).astype(float)
    part[:] = model + rng.normal(0, 0.7, model.shape[:2])[..., None]


def slot_empty(sx):
    """a switch's slot with nothing in it: each row of its free right end,
    carried along; its left end the right end mirrored"""
    for y in range(206, 255):
        rowv = img[y, sx + 105:sx + 136].mean(0)
        img[y, sx + 11:sx + 137] = rowv
        img[y, sx + 3:sx + 11] = img[y, sx + 140:sx + 132:-1]
    img[206:255, sx + 3:sx + 137] += rng.normal(0, 0.8, (49, 134, 1))


def rect(x0, y0, x1, y1):
    m = np.zeros((H, W), bool)
    m[int(y0):int(y1), int(x0):int(x1)] = True
    return m


def darker_than(m, v):
    return m & (img.mean(2) < v)


def grow(m, n):
    from PIL import ImageFilter
    return np.asarray(Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.MaxFilter(2 * n + 1))) > 0


def sprite(box, radius, name, erase=None):
    """a part cut out with a rounded edge; erase: boxes inside it to refill first"""
    x0, y0, x1, y1 = box
    keep = img.copy()
    if erase:
        for e in erase:
            fill(grow(darker_than(rect(*e), 120), 1) | rect(*e) & False, r=6, grain=0.6)
    part = img[y0:y1, x0:x1].copy()
    img[:] = keep
    S = 4
    m = Image.new('L', ((x1 - x0) * S, (y1 - y0) * S), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, (x1 - x0) * S - 1, (y1 - y0) * S - 1], radius * S, fill=255)
    m = np.asarray(m.resize((x1 - x0, y1 - y0), Image.LANCZOS))
    Image.fromarray(np.dstack([np.clip(part, 0, 255), m]).astype('uint8'), 'RGBA').save(os.path.join(out, name))


# ---- the moving parts, cut before anything is erased ----------------------
sprite((1235, 376, 1381, 445), 32, 'key-up.png')                  # BALANCED
sprite((1061, 375, 1207, 445), 32, 'key-lit.png')                 # QUIET
# the refresh buttons have their labels on them: erased inside the sprite
sprite((158, 604, 312, 677), 34, 'rate-up.png', erase=[(190, 622, 282, 660)])
sprite((510, 604, 666, 677), 34, 'rate-lit.png', erase=[(545, 622, 632, 660)])
sprite((1131, 206, 1197, 254), 7, 'knob.png')
# the blue under a switch's knob when it is ON: its rounded left end, and a
# column of its middle to stretch to wherever the knob is
sprite((1104, 207, 1118, 251), 0, 'fill-end.png')
sprite((1121, 207, 1122, 251), 0, 'fill-mid.png')
sprite((447, 761, 524, 836), 8, 'fader.png')
sprite((1117, 604, 1167, 642), 9, 'tab.png')

# ---- the deck: erase what the widget draws -------------------------------
# the screen: its glass made anew, with nothing on it
smooth_glass(212, 176, 959, 497)
# the switches: knob, blue fill, lamp and ON / OFF
for sx in (1100, 1372):
    slot_empty(sx)
    across(sx - 27, 209, sx - 11, 251, 'h')                    # its lamp
    across(sx + 4, 263, sx + 142, 301, 'v')                    # ON / OFF
# the power-mode buttons, their labels and the line under QUIET; PROFILE
across(1050, 369, 1561, 499, 'v')
across(1226, 326, 1384, 369, 'v')
# the refresh buttons and their label
across(152, 597, 674, 686, 'v')
across(162, 561, 542, 603, 'v')
# the lock's thumb (along its track), and its label
across(1111, 600, 1172, 654, 'h')
across(832, 561, 1100, 603, 'v')
# the faders' thumbs, along their tracks (volume at 485, light at 1177)
across(442, 756, 529, 858, 'h')
across(1134, 756, 1221, 858, 'h')
across(1094, 714, 1312, 758, 'v')                              # LIGHT (and room for BRIGHTNESS)


# the ticks, from the volume track's clean right-hand stretch (one with its
# short mark above, for the middle; one without, for the ends); both tracks
# get the same
TY0, TY1 = 771, 827                                              # a track's inside, within its border


def tick_at(x, clean):
    prof = img[TY0:TY1, clean].mean(1)
    return img[TY0:TY1, x - 4:x + 5] - prof[:, None]


TICK_FULL = tick_at(610, np.r_[585:600, 620:635])
TICK_END = tick_at(646, np.r_[620:635, 655:668])


def rebuild_track(x0, x1, first, last, clean):
    """a fader's track made anew, evenly: its plain inside (the mean of a
    clean stretch between two ticks) along its whole straight, and 13 ticks
    at even steps from the first to the last. The thumb's place had been
    smeared over, and the art's ticks were unevenly spaced to begin with."""
    prof = img[TY0:TY1, clean].mean(1)
    img[TY0:TY1, x0:x1] = prof[:, None]
    for i in range(13):
        x = int(round(first + i * (last - first) / 12))
        img[TY0:TY1, x - 4:x + 5] += TICK_END if i in (0, 12) else TICK_FULL
    img[TY0:TY1, x0:x1] += rng.normal(0, 0.6, (TY1 - TY0, x1 - x0, 1))


rebuild_track(241, 673, 253, 646, np.r_[585:600, 620:635])                      # VOLUME
rebuild_track(963, 1383, 977, 1364, np.r_[1298:1314, 1336:1352])                # BRIGHTNESS
for bx0, bx1 in ((702, 790), (1433, 1523)):                    # the read-outs
    across(bx0 + 7, 775, bx1 - 7, 821, 'h', grain=0.5)

# ---- off the white: the deck by its outline, the shadow under it ----------
lum = img.mean(2)
src0 = np.asarray(Image.open(src).convert('RGB')).astype(float)
lum0 = src0.mean(2); sat0 = src0.max(2) - src0.min(2)
ground = (lum0 > 160) & (sat0 < 14)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
shadow = np.clip((247 - lum0) / 247 * 1.4, 0, 0.6)
alpha = np.where(bg, shadow, 1.0)
rgb = np.where(bg[..., None], 0, img)
x0, y0, x1, y1 = CROP
deck = np.dstack([np.clip(rgb, 0, 255), alpha * 255])[y0:y1, x0:x1].astype('uint8')
Image.fromarray(deck, 'RGBA').save(os.path.join(out, 'deck.png'), optimize=True)
print('ORIGIN', ORIGIN, 'size', (x1 - x0, y1 - y0))
