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
CASSETTE = (349, 425, 1061, 706, 16)        # the whole cassette, nearly filling the window
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



# ---- drawing the deck's inside (in the window's own pixels, from x0, y0 of the mock-up)
SS = 3


def shape(w, h, draw):
    """a soft-edged mask: draw(d, s) paints white on a supersampled canvas"""
    m = Image.new('L', (w * SS, h * SS), 0)
    draw(ImageDraw.Draw(m), SS)
    return np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255


def lay(base, mask, colour):
    a = mask[..., None]
    return base * (1 - a) + colour * a


def shadow(base, mask, dx=3, dy=5, blur=5, depth=0.55):
    sh = np.roll(np.roll(mask, dy, 0), dx, 1)
    sh = cv2.GaussianBlur(sh, (0, 0), blur)
    return base * (1 - depth * np.clip(sh, 0, 1))[..., None]


def steel(field, lo=70, hi=225, tint=(1.0, 0.985, 0.95)):
    """a metal's colour from a 0..1 light field"""
    v = lo + (hi - lo) * np.clip(field, 0, 1)
    return v[..., None] * np.array(tint, np.float32)


def paint_deck(w, h, ox, oy):
    rng = np.random.default_rng(11)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    X = lambda x: x - ox
    Y = lambda y: y - oy
    # the floor: dark moulded plastic, lit softly from the top left, in shadow under the rim
    light = 1 - 0.35 * np.hypot((xx - w * 0.38) / w, (yy - h * 0.35) / h) * 1.6
    top = np.clip(yy / 26, 0, 1) ** 0.7
    v = 30 + 13 * light * top
    v = v + rng.normal(0, 1.4, (h, w))
    v = v + cv2.GaussianBlur(rng.normal(0, 3, (h, w)).astype(np.float32), (0, 0), 6)  # its mottling
    deck = v[..., None] * np.array([1.0, 0.97, 0.93], np.float32)

    # its moulding: a raised plate round the spindles, its upper edges catching the light
    def emboss(box, r, up=True, amt=7):
        global_ = shape(w, h, lambda d, s: d.rounded_rectangle([X(box[0]) * s, Y(box[1]) * s, X(box[2]) * s, Y(box[3]) * s], r * s, fill=255))
        edge_hi = np.clip(global_ - np.roll(global_, 2, 0), 0, 1) + 0.6 * np.clip(global_ - np.roll(global_, 2, 1), 0, 1)
        edge_lo = np.clip(global_ - np.roll(global_, -2, 0), 0, 1) + 0.6 * np.clip(global_ - np.roll(global_, -2, 1), 0, 1)
        sgn = 1 if up else -1
        return global_ * sgn * 3 + (edge_hi - edge_lo) * sgn * amt
    deck += emboss((372, 448, 1032, 650), 22)[..., None]
    deck += emboss((612, 520, 808, 628), 10, up=False, amt=6)[..., None]
    # two long ribs above, as moulded plastic has
    for ry in (470, 478):
        rib = shape(w, h, lambda d, s, ry=ry: d.rounded_rectangle([X(640) * s, Y(ry) * s, X(780) * s, Y(ry + 3) * s], 1.5 * s, fill=255))
        deck += (rib * 6)[..., None]

    # the spindles' platters, and the spindles: white nylon hubs with six teeth
    for cx, cy in REELS:
        R = 50
        plat = shape(w, h, lambda d, s: d.ellipse([(X(cx) - R) * s, (Y(cy) - R) * s, (X(cx) + R) * s, (Y(cy) + R) * s], fill=255))
        deck = shadow(deck, plat, 2, 4, 6, 0.5)
        rr = np.hypot(xx - X(cx), yy - Y(cy))
        ang = np.arctan2(yy - Y(cy), xx - X(cx))
        rings = 0.5 + 0.5 * np.cos(rr * 1.6)                                    # its turned rings
        sheen = 0.5 + 0.5 * np.cos(ang + 2.4)                                   # lit from the top left
        pv = 22 + 10 * sheen + 5 * rings * (rr > 20) + 22 * np.clip(1 - np.abs(rr - R + 2) / 2.5, 0, 1) * sheen
        deck = lay(deck, plat, pv[..., None] * np.array([1.0, 0.98, 0.95], np.float32))
        # the hub: a ring, six teeth, the shaft in its middle
        def hub(d, s):
            d.ellipse([(X(cx) - 15) * s, (Y(cy) - 15) * s, (X(cx) + 15) * s, (Y(cy) + 15) * s], fill=255)
            for k in range(6):
                a = k * np.pi / 3 + 0.3
                pts = []
                for (r_, da) in ((13, -0.24), (25, -0.13), (25, 0.13), (13, 0.24)):
                    pts.append(((X(cx) + r_ * np.cos(a + da)) * s, (Y(cy) + r_ * np.sin(a + da)) * s))
                d.polygon(pts, fill=255)
        hm = shape(w, h, hub)
        deck = shadow(deck, hm, 2, 3, 2.5, 0.6)
        hv = 150 + 70 * sheen - 30 * np.clip((rr - 10) / 16, 0, 1)
        deck = lay(deck, hm, hv[..., None] * np.array([0.97, 0.95, 0.9], np.float32))
        hole = shape(w, h, lambda d, s: d.ellipse([(X(cx) - 6) * s, (Y(cy) - 6) * s, (X(cx) + 6) * s, (Y(cy) + 6) * s], fill=255))
        deck = lay(deck, hole, np.array([28, 26, 25], np.float32))
        shaft = shape(w, h, lambda d, s: d.ellipse([(X(cx) - 3.5) * s, (Y(cy) - 3.5) * s, (X(cx) + 3.5) * s, (Y(cy) + 3.5) * s], fill=255))
        deck = lay(deck, shaft, steel(0.3 + 0.7 * sheen))

    # the alignment pins and the floor's screws
    for px, py, r in ((420, 676, 7), (1000, 676, 7)):
        pin = shape(w, h, lambda d, s: d.ellipse([(X(px) - r) * s, (Y(py) - r) * s, (X(px) + r) * s, (Y(py) + r) * s], fill=255))
        deck = shadow(deck, pin, 3, 4, 3, 0.6)
        f = 1 - np.hypot(xx - X(px) + 2.5, yy - Y(py) + 2.5) / (r * 1.6)
        deck = lay(deck, pin, steel(f, 60, 235))
    for sx, sy in ((392, 466), (1012, 466)):
        sc = shape(w, h, lambda d, s: d.ellipse([(X(sx) - 6) * s, (Y(sy) - 6) * s, (X(sx) + 6) * s, (Y(sy) + 6) * s], fill=255))
        f = 1 - np.hypot(xx - X(sx) + 2, yy - Y(sy) + 2) / 10
        deck = lay(deck, sc, steel(f, 45, 150))
        cross = shape(w, h, lambda d, s: (d.line([(X(sx) - 3.5) * s, Y(sy) * s, (X(sx) + 3.5) * s, Y(sy) * s], fill=255, width=int(1.4 * s)),
                                          d.line([X(sx) * s, (Y(sy) - 3.5) * s, X(sx) * s, (Y(sy) + 3.5) * s], fill=255, width=int(1.4 * s))))
        deck = lay(deck, cross * 0.8, np.array([22, 21, 20], np.float32))

    # the head block along the foot: its bracket, then what stands on it
    br = shape(w, h, lambda d, s: d.rounded_rectangle([X(548) * s, Y(662) * s, X(890) * s, Y(730) * s], 9 * s, fill=255))
    deck = shadow(deck, br, 0, -4, 6, 0.45)
    f = 0.25 + 0.25 * np.clip(1 - (yy - Y(662)) / 40, 0, 1) + 0.5 * np.clip(1 - np.abs(yy - Y(664)) / 2.2, 0, 1)
    brushed = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), sigmaX=14, sigmaY=0.6) * 0.18
    deck = lay(deck, br, steel(f + brushed, 30, 120))
    for sx, sy in ((566, 712), (872, 712)):
        sc = shape(w, h, lambda d, s, sx=sx, sy=sy: d.ellipse([(X(sx) - 5) * s, (Y(sy) - 5) * s, (X(sx) + 5) * s, (Y(sy) + 5) * s], fill=255))
        f2 = 1 - np.hypot(xx - X(sx) + 2, yy - Y(sy) + 2) / 8
        deck = lay(deck, sc, steel(f2, 40, 150))
        sl = shape(w, h, lambda d, s, sx=sx, sy=sy: d.line([(X(sx) - 3) * s, (Y(sy) + 1.5) * s, (X(sx) + 3) * s, (Y(sy) - 1.5) * s], fill=255, width=int(1.3 * s)))
        deck = lay(deck, sl * 0.8, np.array([20, 19, 18], np.float32))
    # the erase head and the playback head: chrome blocks, the playback one with its gap
    for box, r in (((590, 654, 632, 700), 7), ((672, 646, 748, 702), 10)):
        hd = shape(w, h, lambda d, s, box=box, r=r: d.rounded_rectangle([X(box[0]) * s, Y(box[1]) * s, X(box[2]) * s, Y(box[3]) * s], r * s, fill=255))
        deck = shadow(deck, hd, 3, 4, 4, 0.6)
        u = (xx - X(box[0])) / (box[2] - box[0])
        vv = (yy - Y(box[1])) / (box[3] - box[1])
        f = 0.35 + 0.45 * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 0.6 + 0.35 * np.exp(-((u - 0.32) / 0.08) ** 2) - 0.3 * np.clip(vv - 0.6, 0, 1)
        deck = lay(deck, hd, steel(f, 55, 235))
    gap = shape(w, h, lambda d, s: d.rectangle([X(709.3) * s, Y(650) * s, X(710.7) * s, Y(698) * s], fill=255))
    deck = lay(deck, gap * 0.85, np.array([30, 28, 26], np.float32))
    face = shape(w, h, lambda d, s: d.rectangle([X(684) * s, Y(646) * s, X(736) * s, Y(651) * s], fill=255))
    deck = lay(deck, face * 0.5, np.array([238, 236, 230], np.float32))
    # the tape guides, the capstan (a thin steel pin) and the pinch roller (black rubber)
    for gx, gy in ((654, 664), (768, 664)):
        g_ = shape(w, h, lambda d, s, gx=gx, gy=gy: d.rounded_rectangle([(X(gx) - 4) * s, Y(gy) * s, (X(gx) + 4) * s, (Y(gy) + 30) * s], 3 * s, fill=255))
        deck = shadow(deck, g_, 2, 3, 2, 0.5)
        u = (xx - X(gx) + 4) / 8
        deck = lay(deck, g_, steel(0.3 + 0.7 * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 2, 60, 230))
    cap = shape(w, h, lambda d, s: d.rounded_rectangle([X(804) * s, Y(640) * s, X(812) * s, Y(704) * s], 3 * s, fill=255))
    deck = shadow(deck, cap, 2, 3, 2.5, 0.55)
    u = (xx - X(804)) / 8
    deck = lay(deck, cap, steel(0.25 + 0.75 * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 3, 70, 245))
    roll = shape(w, h, lambda d, s: d.rounded_rectangle([X(826) * s, Y(640) * s, X(862) * s, Y(706) * s], 9 * s, fill=255))
    deck = shadow(deck, roll, 3, 4, 5, 0.6)
    u = (xx - X(826)) / 36
    rv = 14 + 30 * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 1.5 + 22 * np.exp(-((u - 0.33) / 0.07) ** 2)
    deck = lay(deck, roll, rv[..., None] * np.array([1.0, 0.98, 0.96], np.float32))
    axle = shape(w, h, lambda d, s: d.ellipse([(X(844) - 4) * s, (Y(646) - 3) * s, (X(844) + 4) * s, (Y(646) + 3) * s], fill=255))
    deck = lay(deck, axle, steel(0.6, 80, 200))

    # the shadow the window's rim casts in along its top and left
    occ = np.clip(1 - yy / 30, 0, 1) ** 1.5 * 0.5 + np.clip(1 - xx / 26, 0, 1) ** 1.5 * 0.3
    deck *= (1 - occ)[..., None]
    deck += rng.normal(0, 0.8, (h, w))[..., None]
    return deck


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
# and the streaks' edges, still there: each point against the mean along its
# streak (turned upright, a tall average over a square one)
def along(img, mask, ang=-30, n=121):
    h, w = img.shape
    D = int(np.hypot(h, w)) + 4
    M = cv2.getRotationMatrix2D((w / 2, h / 2), ang, 1); M[:, 2] += (D - w) / 2, (D - h) / 2
    Mi = cv2.invertAffineTransform(M)
    f = mask.astype(np.float32)
    ri = cv2.warpAffine(img * f, M, (D, D)); rf = cv2.warpAffine(f, M, (D, D))
    tall = cv2.blur(ri, (3, n)) / np.maximum(1e-3, cv2.blur(rf, (3, n)))
    square = cv2.blur(ri, (n, n)) / np.maximum(1e-3, cv2.blur(rf, (n, n)))
    ratio = np.where(cv2.blur(rf, (3, n)) > 0.2, tall / np.maximum(1e-3, square), 1)
    back = cv2.warpAffine(ratio.astype(np.float32), Mi, (w, h), borderValue=1)
    return np.clip(back, 0.6, 1.6)
face = (alpha > 0.5) & ~np.zeros_like(keep)
for rx, ry in REELS:
    face &= np.hypot(xx - (rx - cx0), yy - (ry - cy0)) >= 61
face[WIN[1] - 3:WIN[3] + 3, WIN[0] - 3:WIN[2] + 3] = False
lab = np.zeros_like(face); lab[464 - cy0:517 - cy0, 465 - cx0:941 - cx0] = True
for m in (lab, face & ~lab):
    f = m.astype(np.float32)
    loc = cv2.GaussianBlur(L * f, (0, 0), 12) / np.maximum(1e-3, cv2.GaussianBlur(f, (0, 0), 12))
    st = along(L / np.maximum(1, loc), m)
    part[m] = (part / np.maximum(1, st)[..., None])[m]
L = part.mean(2)
# the shell's fine texture (its scratches, its grain) without the broad
# light on it, the glass's streaks among it: each point against the shell
# round it, softly; the stripes the same
def texture(mask, sigma=12):
    f = mask.astype(np.float32)
    local = cv2.GaussianBlur(L * f, (0, 0), sigma) / np.maximum(1e-3, cv2.GaussianBlur(f, (0, 0), sigma))
    return np.clip(L / np.maximum(1, local), 0.3, 2.2) * np.clip(local / max(1, L[mask].mean()), 0.85, 1.15) ** 0.5
d_shell = texture(shell)
streaks = along(d_shell, shell)
d_shell = d_shell / np.maximum(1, streaks)
d_stripe = texture(stripe, 6) if stripe.any() else L
# the tape window emptied: the shell's dark inside, the spools drawn over it
wx0, wy0, wx1, wy1 = WIN
inside = part[wy0:wy1, wx0:wx1]
inside[:] = np.array([24, 22, 21], np.float32) + 6 * np.linspace(1, 0, wy1 - wy0)[:, None, None]
# (shell colour, its sheen kept, stripes' colour) for each of the eight
COLOURS = [
    ((50, 48, 46), 0.0, (176, 52, 44)),       # 0 smoke, red (the player's own)
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
    if True:
        tint = np.array(base, np.float32) * np.clip(d_shell, 0.4, 1.8)[..., None] ** 0.9
        tint = tint * (1 - sheen) + (np.array(base, np.float32) * d_shell[..., None] * 1.08).clip(0, 255) * sheen
        out_[shell] = tint[shell]
        st = np.array(stripe_c, np.float32) * np.clip(d_stripe, 0.5, 1.5)[..., None]
        out_[stripe] = st[stripe]
    Image.fromarray(np.dstack([out_, alpha * 255]).clip(0, 255).astype('uint8'), 'RGBA') \
        .save(os.path.join(out, f'cassette-{i}.png'))

# ---- the glass: two soft diagonal streaks, faint
gw, gh = gx1 - gx0, gy1 - gy0
yy, xx = np.mgrid[0:gh, 0:gw].astype(np.float32)
u = xx * 0.866 + yy * 0.5                                               # across the streaks
streak = 0.11 * np.exp(-((u - gw * 0.36) / 26) ** 2) + 0.06 * np.exp(-((u - gw * 0.44) / 9) ** 2) \
    + 0.07 * np.exp(-((u - gw * 0.86) / 34) ** 2)
streak *= rrect(GLASS[:4], gr)
Image.fromarray(np.dstack([np.full((gh, gw, 3), 255, np.float32), streak * 255]).astype('uint8'), 'RGBA') \
    .save(os.path.join(out, 'glare.png'))

# ---- the body
# the window empty: the deck's inside as it is with no cassette in it (the
# cassette, in, covers it nearly all): its moulded floor, the two spindles on
# their platters, the alignment pins, and along its foot the head block (erase
# head, playback head, guides, capstan and pinch roller)
well = rrect(GLASS[:4], gr)
h, w = well.shape
deck = paint_deck(w, h, gx0, gy0)
# its inner rim: a shade lighter, as the mock-up's
rim = np.clip(1 - cv2.distanceTransform((well > 0.5).astype(np.uint8), cv2.DIST_L2, 3) / 6, 0, 1)
deck += (rim * 18)[..., None]
reg = img[gy0:gy1, gx0:gx1]
reg[:] = reg * (1 - well[..., None]) + deck * well[..., None]

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
