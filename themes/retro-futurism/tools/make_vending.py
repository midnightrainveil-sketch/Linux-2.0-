#!/usr/bin/env python3
"""The cassette vending machine's pictures, from its mock-up (art/CassetteVending.png).

    python3 tools/make_vending.py art/CassetteVending.png home/.config/quickshell/widgets/vending

Makes, in the widget's folder (everything in the mock-up's own pixels; the
body starts at ORIGIN):
    body.png        the machine off its white ground, emptied: its shelves bare,
                    their numbers and lamps gone (the widget writes and lights
                    them), its lift's column bare (the carriage is a part of
                    its own), its tray bare and its lamp off, its screen blank
    carriage.png    the lift's carriage, run up and down its column
    motor.png       the column's head, laid over the carriage as it goes up
    clips.png       the tray's two front clips, laid over a dispensed cassette
    shell-N.png     the eight cassettes (0..7), their titles taken off; the
                    widget writes a song's title where each had its own
    shells.json     each shell's size and where its title goes, in what ink
(pip: numpy pillow opencv-python-headless)
"""
import json, os, sys
import numpy as np, cv2
from PIL import Image, ImageDraw
from collections import deque

src, out = sys.argv[1:3]
os.makedirs(out, exist_ok=True)
src0 = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
img = src0.copy()
H, W, _ = img.shape
lum0 = src0.mean(2)

# ---- the places (mock-up pixels)
# the cassettes on the shelves: their box; their title's box (taken off), the
# span a new title may take, its ink
SHELLS = [
    ((204, 177, 540, 276), (248, 194, 396, 219), (250, 438), '#2b2a27'),
    ((204, 297, 540, 386), (248, 311, 377, 333), (250, 442), '#2b2a27'),
    ((204, 410, 540, 501), (294, 421, 481, 446), (286, 472), '#e6dfcd'),
    ((204, 522, 540, 616), (248, 538, 382, 561), (250, 440), '#2b2a27'),
    ((204, 637, 540, 726), (260, 652, 401, 675), (262, 446), '#2b2a27'),
    ((204, 747, 540, 831), (245, 758, 357, 783), (247, 392), '#e6dfcd'),
    ((204, 850, 541, 936), (300, 860, 426, 884), (296, 456), '#3a3936'),
    ((204, 956, 540, 1051), (275, 968, 418, 993), (276, 470), '#e6dfcd'),
]
BAY = (176, 160, 566, 1062)              # the shelves' recess
NUMBERS = (118, 196, 170, 1032)          # the shelves' numbers and lamps, at their left
COLUMN = (578, 860, 815, 1124)           # the carriage, where it rests (and its column there)
MOTOR = (575, 140, 815, 262)             # the column's head
TRAY = (330, 1140, 798, 1276)            # the dispensed cassette's place (its floor)
CLIPS = [(348, 1238, 412, 1278), (714, 1238, 778, 1278)]
TRAY_LAMP = (480, 1120, 592, 1138)
SCREEN = (858, 184, 990, 432, 12)        # the screen's glass: x0 y0 x1 y1, its corners


def rrect(w, h, r, scale=4):
    m = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], r * scale, fill=255)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def save(rgb, a, name):
    Image.fromarray(np.dstack([rgb, a * 255]).clip(0, 255).astype('uint8'), 'RGBA').save(os.path.join(out, name), optimize=True)


def inpaint(region, mask, r=4):
    """inpaint within region (a box) where mask (that box's size) is set"""
    x0, y0, x1, y1 = region
    part = img[y0:y1, x0:x1].clip(0, 255).astype(np.uint8)
    img[y0:y1, x0:x1] = cv2.inpaint(part, (mask > 0).astype(np.uint8) * 255, r, cv2.INPAINT_TELEA).astype(np.float32)


# ---- the shells, their titles taken off
info = []
for i, (box, tbox, span, ink) in enumerate(SHELLS):
    x0, y0, x1, y1 = box
    part = src0[y0:y1, x0:x1].copy()
    tx0, ty0, tx1, ty1 = (tbox[0] - x0, tbox[1] - y0, tbox[2] - x0, tbox[3] - y0)
    t = part[ty0:ty1, tx0:tx1]
    L = t.mean(2)
    ground = cv2.medianBlur(L.astype(np.uint8), 15).astype(np.float32)
    dark = ink.lower() < '#8'                 # dark letters on a light label
    m = (L < ground - 22) if dark else (L > ground + 22)
    m = cv2.dilate(m.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=2)
    t[:] = cv2.inpaint(t.clip(0, 255).astype(np.uint8), m * 255, 4, cv2.INPAINT_TELEA).astype(np.float32)
    save(part, rrect(x1 - x0, y1 - y0, 7), f'shell-{i}.png')
    info.append({'w': x1 - x0, 'h': y1 - y0,
                 'tx': span[0] - x0, 'tw': span[1] - span[0], 'ty': (ty0 + ty1) / 2, 'ink': ink})
json.dump({'shells': info}, open(os.path.join(out, 'shells.json'), 'w'), indent=1)

# ---- the parts that move or lie over others, cut before the body is emptied
x0, y0, x1, y1 = COLUMN
a = np.ones((y1 - y0, x1 - x0), np.float32)
a[:6] *= np.linspace(0, 1, 6)[:, None]                 # its top feathered into the column
xs = np.arange(x0, x1)
a[1100 - y0:, (xs < 598) | (xs > 792)] = 0            # not the tray's frame round its feet
save(src0[y0:y1, x0:x1], a, 'carriage.png')
x0, y0, x1, y1 = MOTOR
a = np.ones((y1 - y0, x1 - x0), np.float32)
a[-8:] *= np.linspace(1, 0, 8)[:, None]
save(src0[y0:y1, x0:x1], a, 'motor.png')
# the clips: the brighter metal of their boxes
cx0, cy0 = CLIPS[0][:2]
cx1, cy1 = CLIPS[1][2:]
clip = np.zeros((cy1 - cy0, cx1 - cx0), np.float32)
for bx0, by0, bx1, by1 in CLIPS:
    clip[by0 - cy0:by1 - cy0, bx0 - cx0:bx1 - cx0] = rrect(bx1 - bx0, by1 - by0, 5)
save(src0[cy0:cy1, cx0:cx1], clip, 'clips.png')

# ---- the body
# the shelves bare: behind each cassette the bay's dark back, shadowed under
# the shelf above
back = np.array([36, 33, 30], np.float32)
rng = np.random.default_rng(5)
for box, *_ in SHELLS:
    x0, y0, x1, y1 = box
    x0 -= 3; x1 += 3; y0 -= 2; y1 += 1
    h, w = y1 - y0, x1 - x0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    shade = 0.72 + 0.28 * np.clip(yy / (h * 0.6), 0, 1)          # darker under the shelf above
    side = 1 - 0.25 * np.abs(xx / w - 0.5) * 2                    # and toward the sides
    fill = back * (shade * side)[..., None] + rng.normal(0, 0.8, (h, w))[..., None]
    # a faint back panel: two seams, as a shelving's back has
    for sx in (0.33, 0.67):
        fill[:, int(w * sx):int(w * sx) + 2] *= 0.7
    img[y0:y1, x0:x1] = fill

# the numbers and lamps gone (the dividing lines kept): what is darker, or
# warmer, than the panel
x0, y0, x1, y1 = NUMBERS
L = lum0[y0:y1, x0:x1]
panel = cv2.blur(cv2.medianBlur(L.astype(np.uint8), 31).astype(np.float32), (9, 9))
warm = (src0[y0:y1, x0:x1, 0] - src0[y0:y1, x0:x1, 2])
ink = (L < panel - 14) | (warm > 40) | (L > panel + 25)
lines = (L < panel - 14).mean(1) > 0.55                      # rows that are a dividing line
ink[lines] = False
ink[np.roll(lines, 1)] = False
ink[np.roll(lines, -1)] = False
ink[:, :6] = False                                           # the panel's edge
inpaint(NUMBERS, cv2.dilate(ink.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=3), 6)
# the lit lamp's glow on the panel
reg = img[y0:y1, x0:x1]
glow = np.clip((src0[y0:y1, x0:x1, 0] - src0[y0:y1, x0:x1, 2] - 28) / 40, 0, 1)
reg[:] = reg * (1 - glow[..., None]) + cv2.GaussianBlur(reg, (0, 0), 12) * glow[..., None]

# the column bare: the column above, carried down over where the carriage was
x0, y0, x1, y1 = COLUMN
img[y0:y1, x0:x1] = src0[y0 - 270:y1 - 270, x0:x1]
fade = np.linspace(0, 1, 24)[:, None, None]                  # (eased in from the row above)
img[y0:y0 + 24, x0:x1] = src0[y0 - 1:y0, x0:x1] * (1 - fade) + img[y0:y0 + 24, x0:x1] * fade
img[1100:y1, 598:793] = img[1100:y1, 598:793] * 0.35        # its foot, in the tray's shadow

# the tray bare: its floor, from its two sides across
x0, y0, x1, y1 = TRAY
left = src0[y0:y1, x0 - 6:x0].mean(1)
right = src0[y0:y1, x1:x1 + 6].mean(1)
t = np.linspace(0, 1, x1 - x0)[None, :, None]
floor = left[:, None] * (1 - t) + right[:, None] * t
floor = cv2.GaussianBlur(floor, (0, 0), 3)
floor += rng.normal(0, 1.0, floor.shape[:2])[..., None]
# a soft shadow along its back (under the frame)
yy = np.arange(y1 - y0, dtype=np.float32)[:, None, None]
floor *= 0.62 + 0.38 * np.clip(yy / 40, 0, 1)
img[y0:y1, x0:x1] = floor
# its lamp off
x0, y0, x1, y1 = TRAY_LAMP
reg = img[y0:y1, x0:x1]
hot = np.clip((src0[y0:y1, x0:x1].mean(2) - 70) / 120, 0, 1)
reg[:] = reg * (1 - hot[..., None]) + np.array([46, 42, 38]) * hot[..., None]
# and its glow on the frame and the floor below it
x0, x1 = 430, 650
reg = img[1105:1170, x0:x1]
warm = np.clip((reg[..., 0] - reg[..., 2] - 30) / 60, 0, 1)
reg[:] = reg - (reg - reg.mean(2, keepdims=True) * np.array([1.02, 1.0, 0.97])) * warm[..., None] * 0.8

# the screen blank: its e-ink paper, a little darker toward its edges
x0, y0, x1, y1, r = SCREEN
h, w = y1 - y0, x1 - x0
m = rrect(w, h, r)
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
v = 1 - 0.07 * (np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) ** 2)
paper = np.array([214, 214, 206], np.float32) * v[..., None] + rng.normal(0, 1.1, (h, w))[..., None]
inner = cv2.erode((m > 0.5).astype(np.uint8), np.ones((5, 5), np.uint8))
inner = cv2.GaussianBlur(inner.astype(np.float32), (0, 0), 1.2)
reg = img[y0:y1, x0:x1]
reg[:] = reg * (1 - inner[..., None]) + paper * inner[..., None]

# ---- off the white: the machine by its outline (flood from the corners)
sat0 = src0.max(2) - src0.min(2)
ground = (lum0 > 238) & (sat0 < 12)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
# (and the floor's light shadow under it, between its feet)
xs_ = np.arange(W)
floor = np.zeros((H, W), bool)
floor[1346:] = True
floor[:, ((xs_ >= 136) & (xs_ <= 245)) | ((xs_ >= 876) & (xs_ <= 985))] = False
bg |= floor & (sat0 < 16) & (lum0 > 140)
# (and the ground showing through a loop, as the cable's: any large white patch)
n, lab, stats, _ = cv2.connectedComponentsWithStats(ground.astype(np.uint8), connectivity=4)
for i in range(1, n):
    if stats[i, cv2.CC_STAT_AREA] > 400:
        bg |= lab == i
alpha = np.where(bg, np.clip((245 - lum0) / 245 * 1.4, 0, 0.45), 1.0)
alpha = cv2.GaussianBlur(alpha.astype(np.float32), (0, 0), 0.7)
rgb = np.where(bg[..., None], 0, img)
ys, xs = np.where(alpha > 0.02)
CROP = (max(0, xs.min() - 4), max(0, ys.min() - 4), min(W, xs.max() + 5), min(H, ys.max() + 5))
x0, y0, x1, y1 = CROP
save(rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1], 'body.png')
print('ORIGIN', (x0, y0), 'size', (x1 - x0, y1 - y0))
