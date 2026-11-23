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
    wheel-N.png     the wheel's knurled drum turned through one ridge (0..7),
                    to roll it as the choice moves
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



# ---- drawing an empty slot (its own pixels)
SS = 3


def shape(w, h, draw):
    m = Image.new('L', (w * SS, h * SS), 0)
    draw(ImageDraw.Draw(m), SS)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def lay(base, mask, colour):
    a = mask[..., None]
    return base * (1 - a) + colour * a


def shadow(base, mask, dx=3, dy=4, blur=4, depth=0.55):
    sh = cv2.GaussianBlur(np.roll(np.roll(mask, dy, 0), dx, 1), (0, 0), blur)
    return base * (1 - depth * np.clip(sh, 0, 1))[..., None]


def steel(field, lo=60, hi=225, tint=(1.0, 0.985, 0.95)):
    return (lo + (hi - lo) * np.clip(field, 0, 1))[..., None] * np.array(tint, np.float32)


def empty_slot(w, h, rng):
    """a shelf's slot with no cassette: its brushed back wall with vent slots,
    its side walls in shadow, its floor's rubber strip, a spring pusher at the
    back on the left and two rubber stops on the right"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # the back wall: brushed steel, dark; in the shelf above's shadow at its top
    brushed = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), sigmaX=18, sigmaY=0.5)
    v = 40 + 10 * np.clip(yy / (h * 0.75), 0, 1) + 3.5 * brushed
    v *= 0.55 + 0.45 * np.clip(yy / 22, 0, 1) ** 0.8
    slot = v[..., None] * np.array([1.0, 0.97, 0.93], np.float32)
    # its vent slots, pressed into it in a row
    for k in range(9):
        cx = w * 0.56 + (k - 4) * 19
        vm = shape(w, h, lambda d, s, cx=cx: d.rounded_rectangle([(cx - 4.5) * s, h * 0.30 * s, (cx + 4.5) * s, h * 0.50 * s], 3 * s, fill=255))
        rim = np.clip(vm - np.roll(vm, 1, 0), 0, 1)
        inner = 16 + 8 * np.clip((yy - h * 0.30) / (h * 0.2), 0, 1)
        slot = lay(slot, vm, inner[..., None] * np.array([1.0, 0.97, 0.93], np.float32))
        slot = slot + (np.clip(np.roll(vm, -1, 0) - vm, 0, 1) * 18)[..., None] - (rim * 6)[..., None]
    # the floor: its edge seen just over the shelf, a rubber strip along it
    fl = np.clip((yy - (h - 11)) / 3, 0, 1)
    slot = lay(slot, fl, (30 + 18 * np.clip((yy - (h - 11)) / 11, 0, 1))[..., None] * np.array([1.0, 0.98, 0.95], np.float32))
    strip = shape(w, h, lambda d, s: d.rounded_rectangle([40 * s, (h - 9) * s, (w - 40) * s, (h - 4) * s], 2 * s, fill=255))
    slot = lay(slot, strip, np.array([22, 21, 20], np.float32))
    # the spring pusher: a steel plate with its coil to the back wall
    coil_y = h * 0.64
    rod = shape(w, h, lambda d, s: d.rectangle([20 * s, (coil_y - 1) * s, 74 * s, (coil_y + 1) * s], fill=255))
    slot = lay(slot, rod, steel(0.4, 40, 120))
    for k in range(9):
        cx = 24 + k * 5.4
        c_ = shape(w, h, lambda d, s, cx=cx: d.arc([(cx - 2.6) * s, (coil_y - 6) * s, (cx + 2.6) * s, (coil_y + 6) * s], 200, 520, fill=255, width=int(1.1 * s)))
        slot = shadow(slot, c_, 1, 2, 1.5, 0.4)
        slot = lay(slot, c_, steel(0.3 + 0.5 * np.clip(1 - np.abs(yy - coil_y + 3) / 5, 0, 1), 45, 150))
    pl = shape(w, h, lambda d, s: d.rounded_rectangle([74 * s, (h * 0.36) * s, 81 * s, (h - 12) * s], 2 * s, fill=255))
    slot = shadow(slot, pl, 3, 2, 3, 0.6)
    u = (xx - 74) / 7
    slot = lay(slot, pl, steel(0.25 + 0.6 * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 2, 45, 165))
    # the rubber stops on the right
    for sy in (h * 0.42, h * 0.70):
        st = shape(w, h, lambda d, s, sy=sy: d.rounded_rectangle([(w - 30) * s, (sy - 6) * s, (w - 18) * s, (sy + 6) * s], 4 * s, fill=255))
        slot = shadow(slot, st, -2, 2, 2.5, 0.5)
        slot = lay(slot, st, np.array([24, 23, 22], np.float32) + (np.clip(1 - np.abs(yy - sy + 3) / 3, 0, 1) * 16)[..., None])
    # its side walls, in shadow, and the shadow of the shelf above
    side = np.clip(1 - np.minimum(xx, w - 1 - xx) / 16, 0, 1) ** 1.4
    slot *= (1 - 0.6 * side)[..., None]
    slot *= (1 - 0.55 * np.clip(1 - yy / 10, 0, 1) ** 1.5)[..., None]
    return slot + rng.normal(0, 0.7, (h, w))[..., None]


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
    save(part, rrect(x1 - x0, y1 - y0, 5), f'shell-{i}.png')
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

# ---- the wheel: its drum drawn again, a steel cylinder with its knurls,
# turned through one ridge in eight steps (the body gets the first)
WHEEL = (902, 536, 949, 650)                 # the drum, in its recess
KNURL = (911, 941)                           # the knurled band between its rims
x0, y0, x1, y1 = WHEEL
dw, dh = x1 - x0, y1 - y0
yc, R = (y0 + y1) / 2, (y1 - y0) / 2 + 1
D = src0[y0:y1, x0:x1]
light = cv2.GaussianBlur(D, (0, 0), sigmaX=0.6, sigmaY=9)          # the light on it, along it
band = np.zeros(dw, np.float32)
band[KNURL[0] - x0:KNURL[1] - x0] = 1
band = np.convolve(band, np.ones(3) / 3, 'same')[None, :, None]
SS, PITCH = 4, 4.2                                                 # supersampling; the ridges' pitch at the middle
wheel_frames = []
for k in range(8):
    ys = (np.arange(dh * SS) + 0.5) / SS + y0
    th = np.arcsin(np.clip((ys - yc) / R, -0.999, 0.999))
    ph = th * R / PITCH + k / 8
    ridge = (0.5 + 0.5 * np.cos(2 * np.pi * ph)) ** 2.2
    ridge = ridge.reshape(dh, SS).mean(1)
    lit = 0.45 + 0.95 * ridge                                      # groove dark, crest bright
    edge = np.cos(th.reshape(dh, SS).mean(1)) ** 0.6               # darker toward its top and foot
    v = (lit * (0.35 + 0.65 * edge))[:, None, None]
    metal = light * v * 1.05 * np.array([1.0, 0.99, 0.95])
    frame = D * (1 - band) + metal * band
    wheel_frames.append(frame)
    save(frame, np.ones((dh, dw), np.float32), f'wheel-{k}.png')
img[y0:y1, x0:x1] = wheel_frames[0]

# ---- the body
# the shelves bare: each slot as it is with its cassette gone (tray_slot)
rng = np.random.default_rng(5)
for box, *_ in SHELLS:
    x0, y0, x1, y1 = box
    x0 -= 3; x1 += 3; y0 -= 2; y1 += 1
    img[y0:y1, x0:x1] = empty_slot(x1 - x0, y1 - y0, rng)

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
# its outline is a rounded box (85 px corners at the top, 60 at the foot):
# drawn, not found, so its chrome's white edges stay
BODY = (91, 19, 1031, 1351)
def outline(r, scale=4):
    x0, y0, x1, y1 = BODY
    m = Image.new('L', ((x1 - x0) * scale, (y1 - y0) * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, (x1 - x0) * scale - 1, (y1 - y0) * scale - 1], r * scale, fill=255)
    return np.asarray(m.resize((x1 - x0, y1 - y0), Image.LANCZOS)).astype(np.float32) / 255
sil = np.zeros((H, W), np.float32)
mid = (BODY[3] - BODY[1]) // 2
o85, o60 = outline(85), outline(60)
sil[BODY[1]:BODY[3], BODY[0]:BODY[2]] = np.vstack([o85[:mid], o60[mid:]])
alpha = np.where(bg, np.clip((245 - lum0) / 245 * 1.4, 0, 0.45), 1.0)
# under it: its two feet (drawn as their shapes, their own pixels kept), and
# a soft shadow where it stands; the floor's grey and its reflection gone
FEET = [(140, 242), (884, 976)]                  # each foot's span at its top
FOOT_TOP, FOOT_FOOT = 1351, 1377
def feet_shape(scale=4):
    m = Image.new('L', (W * scale, H * scale), 0)
    d = ImageDraw.Draw(m)
    for fx0, fx1 in FEET:
        cut = 11                                 # its foot rounds in
        d.polygon([(fx0 * scale, FOOT_TOP * scale), (fx1 * scale, FOOT_TOP * scale),
                   (fx1 * scale, (FOOT_FOOT - 10) * scale), ((fx1 - cut) * scale, FOOT_FOOT * scale),
                   ((fx0 + cut) * scale, FOOT_FOOT * scale), (fx0 * scale, (FOOT_FOOT - 10) * scale)], fill=255)
        d.ellipse([(fx0) * scale, (FOOT_FOOT - 20) * scale, (fx0 + 2 * cut + 2) * scale, FOOT_FOOT * scale], fill=255)
        d.ellipse([(fx1 - 2 * cut - 2) * scale, (FOOT_FOOT - 20) * scale, fx1 * scale, FOOT_FOOT * scale], fill=255)
    return np.asarray(m.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
feet = feet_shape()
yy_, xx_ = np.mgrid[0:H, 0:W].astype(np.float32)
under = yy_ >= FOOT_TOP
# the shadow: dark, close under the machine, fading down and at its ends
fade_x = np.clip((xx_ - 100) / 60, 0, 1) * np.clip((1022 - xx_) / 60, 0, 1)
contact = 0.55 * np.clip(1 - (yy_ - FOOT_TOP) / 30, 0, 1) ** 1.6 * fade_x
foot_sh = cv2.GaussianBlur(np.roll(feet, 3, 0), (0, 0), 3) * 0.5
shade = np.clip(np.maximum(contact, foot_sh), 0, 0.7) * under
alpha = np.where(under, np.maximum(feet, shade), sil)
img = np.where((under & (feet < 0.5))[..., None], 0, img)
bg = (bg & (sil < 0.5)) | (under & (feet < 0.5))
alpha = cv2.GaussianBlur(alpha.astype(np.float32), (0, 0), 0.7)
rgb = np.where(bg[..., None], 0, img)
ys, xs = np.where(alpha > 0.02)
CROP = (max(0, xs.min() - 4), max(0, ys.min() - 4), min(W, xs.max() + 5), min(H, ys.max() + 5))
x0, y0, x1, y1 = CROP
save(rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1], 'body.png')
print('ORIGIN', (x0, y0), 'size', (x1 - x0, y1 - y0))
