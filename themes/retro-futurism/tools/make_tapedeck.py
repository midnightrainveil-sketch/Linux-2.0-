#!/usr/bin/env python3
"""The cassette player's pictures, from its mock-up (art/CassettePlayerWidget.png).

    python3 tools/make_tapedeck.py art/CassettePlayerWidget.png home/.config/quickshell/widgets/cassette

Makes, in the widget's folder (all in the mock-up's own pixels, from ORIGIN):
    body.png      the player off its white ground, with its window empty
                  (the well behind the glass), its level meter dark, its lamp
                  off, the knob's mark gone, and a dark gap above each key
                  (seen as a key goes down)
    cassette-N.png  the cassette from the window (it goes in and comes out),
                  in each of the vending machine's eight colours (0..7), its
                  tape window emptied (the widget winds the tape across it)
    reel.png      one reel's hub, to turn
    glare.png     the window's glass: two soft streaks, laid over the
                  cassette
    key-*.png     the five keys along the top and the four below the window
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
CROP = (128, 14, 1462, 958)                   # the player, and a margin
ORIGIN = CROP[:2]

# ---- the places (mock-up pixels)
GLASS = (330, 410, 1074, 716, 24)             # the window's glass: x0 y0 x1 y1, corner radius
CASSETTE = (392, 444, 1012, 704, 14)
REELS = [(560, 575), (859, 575)]
TOP_KEYS = {'rec': (361, 184, 462, 260), 'play': (471, 184, 604, 262), 'rew': (610, 184, 724, 262),
            'ff': (740, 184, 862, 262), 'stop': (866, 184, 970, 262)}
KEYS = {'back': (377, 759, 527, 885), 'halt': (542, 759, 692, 885), 'go': (704, 759, 854, 885), 'fwd': (865, 759, 1015, 885)}
METER = (1136, 452, 1306, 514)                # the bars, lit
LAMP = (1143, 610, 19)
MARK = (1210, 186, 1232, 206)                 # the knob's red mark


def rrect(box, r, size=None, scale=4):
    x0, y0, x1, y1 = box
    w, h = (x1 - x0), (y1 - y0)
    m = Image.new('L', (w * scale, h * scale), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * scale - 1, h * scale - 1], r * scale, fill=255)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def sprite(box, name, alpha=None):
    x0, y0, x1, y1 = box
    part = src0[y0:y1, x0:x1]
    a = np.ones(part.shape[:2], np.float32) if alpha is None else alpha
    Image.fromarray(np.dstack([part, a * 255]).clip(0, 255).astype('uint8'), 'RGBA').save(os.path.join(out, name))


def inpaint(mask, r=5):
    global img
    m = (mask > 0).astype(np.uint8) * 255
    img = cv2.inpaint(img.clip(0, 255).astype(np.uint8), m, r, cv2.INPAINT_TELEA).astype(np.float32)


# ---- the moving parts, cut first
gx0, gy0, gx1, gy1, gr = GLASS
cx0, cy0, cx1, cy1, cr = CASSETTE
for name, box in TOP_KEYS.items():
    sprite(box, f'key-{name}.png', rrect(box, 8))
for name, box in KEYS.items():
    sprite(box, f'key-{name}.png', rrect(box, 10))
# the reel's hub: a disc round the first reel's centre (its spokes; the ring
# round it stays with the shell)
x, y = REELS[0]; R = 45
yy, xx = np.mgrid[y - R:y + R, x - R:x + R].astype(np.float32) + 0.5
disc = np.clip(R - np.hypot(xx - x, yy - y), 0, 1)
sprite((x - R, y - R, x + R, y + R), 'reel.png', disc)

# ---- the cassette, in the machine's eight colours: its shell and its two
# stripes tinted, its label, reels and window kept
part = src0[cy0:cy1, cx0:cx1].copy()
ch, cw = part.shape[:2]
alpha = rrect(CASSETTE[:4], cr)
yy, xx = np.mgrid[0:ch, 0:cw].astype(np.float32)
keep = np.zeros((ch, cw), bool)
keep[464 - cy0:517 - cy0, 465 - cx0:941 - cx0] = True                  # the label
for rx, ry in REELS:
    keep |= np.hypot(xx - (rx - cx0), yy - (ry - cy0)) < 61             # the reels and their rings
WIN = (627 - cx0, 534 - cy0, 794 - cx0, 621 - cy0)                      # the tape window
keep[WIN[1] - 3:WIN[3] + 3, WIN[0] - 3:WIN[2] + 3] = True
stripe = (part[..., 0] - part[..., 1] > 45) & ~keep
stripe = cv2.morphologyEx(stripe.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool)
shell = (alpha > 0.5) & ~keep & ~stripe
L = part.mean(2)
d_shell = L / max(1, L[shell].mean())
d_stripe = L / max(1, L[stripe].mean()) if stripe.any() else L
# the tape window emptied: the shell's dark inside, the spools drawn over it
wx0, wy0, wx1, wy1 = WIN
inside = part[wy0:wy1, wx0:wx1]
inside[:] = np.array([24, 22, 21], np.float32) + 6 * np.linspace(1, 0, wy1 - wy0)[:, None, None]
# (shell colour, its sheen kept, stripes' colour) for each of the eight
COLOURS = [
    ((52, 50, 48), 0.0, (176, 52, 44)),       # 0 smoke, red (the player's own)
    ((214, 206, 188), 0.25, (196, 120, 128)),  # 1 cream, blossom
    ((60, 61, 62), 0.1, (214, 203, 180)),      # 2 charcoal, cream waves
    ((196, 116, 44), 0.3, (186, 70, 44)),     # 3 amber, sunset
    ((176, 178, 174), 0.45, (88, 110, 84)),    # 4 clear, green
    ((54, 56, 58), 0.1, (226, 222, 212)),      # 5 charcoal, snow
    ((206, 202, 192), 0.2, (128, 126, 120)),   # 6 cream, grey
    ((46, 46, 46), 0.15, (196, 160, 82)),      # 7 smoke, gold
]
for i, (base, sheen, stripe_c) in enumerate(COLOURS):
    out_ = part.copy()
    if i > 0:
        tint = np.array(base, np.float32) * np.clip(d_shell, 0.4, 1.8)[..., None] ** 0.9
        tint = tint * (1 - sheen) + (part * np.array(base) / 52) .clip(0, 255) * sheen
        out_[shell] = tint[shell]
        st = np.array(stripe_c, np.float32) * np.clip(d_stripe, 0.5, 1.5)[..., None]
        out_[stripe] = st[stripe]
    Image.fromarray(np.dstack([out_, alpha * 255]).clip(0, 255).astype('uint8'), 'RGBA') \
        .save(os.path.join(out, f'cassette-{i}.png'))

# ---- the glass: two soft diagonal streaks, faint
gw, gh = gx1 - gx0, gy1 - gy0
yy, xx = np.mgrid[0:gh, 0:gw].astype(np.float32)
u = xx * 0.5 + yy * 0.866                                               # across the streaks
streak = 0.11 * np.exp(-((u - gw * 0.36) / 26) ** 2) + 0.06 * np.exp(-((u - gw * 0.44) / 9) ** 2) \
    + 0.07 * np.exp(-((u - gw * 0.86) / 34) ** 2)
streak *= rrect(GLASS[:4], gr)
Image.fromarray(np.dstack([np.full((gh, gw, 3), 255, np.float32), streak * 255]).astype('uint8'), 'RGBA') \
    .save(os.path.join(out, 'glare.png'))

# ---- the body
# the window empty: the well behind the glass, dark, a little lighter at its middle
well = rrect(GLASS[:4], gr)
h, w = well.shape
yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
glow = 1 - np.hypot((xx - w / 2) / (w * 0.7), (yy - h / 2) / (h * 0.9)) ** 2
deep = np.array([30, 29, 28], np.float32) + 14 * np.clip(glow, 0, 1)[..., None]
deep += np.random.default_rng(3).normal(0, 1.2, deep.shape[:2])[..., None]
# its inner rim: a shade lighter, as the mock-up's
rim = np.clip(1 - cv2.distanceTransform((well > 0.5).astype(np.uint8), cv2.DIST_L2, 3) / 6, 0, 1)
deep += (rim * 18)[..., None]
reg = img[gy0:gy1, gx0:gx1]
reg[:] = reg * (1 - well[..., None]) + deep * well[..., None]

# the meter dark: its bars taken away into the glass round them
m = np.zeros((H, W), np.uint8)
mx0, my0, mx1, my1 = METER
m[my0:my1, mx0:mx1] = (src0[my0:my1, mx0:mx1, 0] - src0[my0:my1, mx0:mx1, 2] > 40)
m = cv2.dilate(m, np.ones((5, 5), np.uint8), iterations=2)
inpaint(m, 7)
# and its glow on the glass round them gone: the glass evened
reg = img[my0 - 18:my1 + 10, mx0 - 12:mx1 + 12]
reg[:] = cv2.GaussianBlur(reg, (0, 0), 3) * 0.55 + reg * 0.45
reg[:] = np.minimum(reg, np.array([52, 47, 42], np.float32))

# the lamp off: its orange made a dark amber glass
lx, ly, lr = LAMP
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.hypot(xx - lx, yy - ly)
lamp = np.clip(lr + 4 - d, 0, 1)
off = img.mean(2, keepdims=True) * np.array([0.42, 0.30, 0.22]) + np.array([18, 12, 8])
img = img * (1 - lamp[..., None]) + off * lamp[..., None]
# (its glow on the plate round it, gone)
halo = np.clip((lr + 22 - d) / 22, 0, 1) * (d > lr + 3)
plate = cv2.GaussianBlur(img, (0, 0), 6)
warm = np.clip((src0[..., 0] - src0[..., 2]) - 40, 0, 80) / 80
img = img - (img - plate * np.array([0.92, 0.93, 0.95])) * (halo * warm)[..., None]

# the knob's mark gone
m = np.zeros((H, W), np.uint8)
x0, y0, x1, y1 = MARK
m[y0:y1, x0:x1] = 1
inpaint(m, 6)

# a dark gap above each key: what shows as it goes down
for box in list(TOP_KEYS.values()) + list(KEYS.values()):
    x0, y0, x1, y1 = box
    img[y0:y0 + 9, x0 + 4:x1 - 4] = img[y0:y0 + 9, x0 + 4:x1 - 4] * 0.25 + np.array([20, 18, 16]) * 0.75

# ---- off the white: the player by its outline (flood from the corners)
lum0 = src0.mean(2); sat0 = src0.max(2) - src0.min(2)
ground = (lum0 > 235) & (sat0 < 12)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
# (and the ground showing through a loop, as the cable's: any large white patch)
n, lab, stats, _ = cv2.connectedComponentsWithStats(ground.astype(np.uint8), connectivity=4)
for i in range(1, n):
    if stats[i, cv2.CC_STAT_AREA] > 400:
        bg |= lab == i
alpha = np.where(bg, np.clip((245 - lum0) / 245 * 1.4, 0, 0.45), 1.0)
alpha = cv2.GaussianBlur(alpha.astype(np.float32), (0, 0), 0.7)
rgb = np.where(bg[..., None], 0, img)
x0, y0, x1, y1 = CROP
Image.fromarray(np.dstack([rgb, alpha * 255])[y0:y1, x0:x1].clip(0, 255).astype('uint8'), 'RGBA') \
    .save(os.path.join(out, 'body.png'), optimize=True)
print('ORIGIN', ORIGIN, 'size', (x1 - x0, y1 - y0))
