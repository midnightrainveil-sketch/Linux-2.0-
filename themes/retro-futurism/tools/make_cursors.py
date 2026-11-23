#!/usr/bin/env python3
"""The pointer cursors: an Xcursor theme, "Magnetic88", drawn here as shapes
in the style of their mock-up (art/Cursors.png): warm chrome with a bevelled
edge and a dark outline, sage inlays, a small even shadow.

    python3 tools/make_cursors.py home/.local/share/icons/Magnetic88

Each cursor is drawn on a 32-unit square, at each size (24 to 96 px) four to
six times over and averaged down, so it is sharp at any size: nothing is cut
out of a picture. The busy rings turn (12 frames). The names apps and
toolkits ask for (CSS, the old X11 ones, Qt's and GTK's) are links to the
files. Python only: no xcursorgen needed.
(pip: numpy pillow opencv-python-headless)
"""
import math, os, struct, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[-1]
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, '..', 'home', '.local', 'share', 'fonts', 'retro-futurism', 'Barlow-Bold.ttf')
SIZES = [24, 28, 32, 36, 42, 48, 64, 96]     # (28 at a scale of 1.5 is 42)

# ---------------------------------------------------------------- drawing
class Pen:
    """draws on a mask in the 32-unit square, through a turn, a scale and a
    shift (about the square's middle)"""
    def __init__(self, n, turn=0.0, scale=1.0, shift=(0.0, 0.0), about=(16.0, 16.0)):
        self.n = n
        self.k = n / 32.0
        a = math.radians(turn)
        self.c, self.s = math.cos(a) * scale, math.sin(a) * scale
        self.scale, self.turn, self.about, self.shift = scale, turn, about, shift

    def map(self, x, y):
        ax, ay = self.about
        x, y = x - ax, y - ay
        X = ax + self.c * x - self.s * y + self.shift[0]
        Y = ay + self.s * x + self.c * y + self.shift[1]
        return X * self.k, Y * self.k

    def r(self, r):
        return r * self.scale * self.k

    def poly(self, d, pts, fill=255):
        d.polygon([self.map(x, y) for x, y in pts], fill=fill)

    def circle(self, d, cx, cy, r, fill=255):
        X, Y = self.map(cx, cy); R = self.r(r)
        d.ellipse([X - R, Y - R, X + R, Y + R], fill=fill)

    def capsule(self, d, x0, y0, x1, y1, r, fill=255):
        (X0, Y0), (X1, Y1), R = self.map(x0, y0), self.map(x1, y1), self.r(r)
        dx, dy = X1 - X0, Y1 - Y0
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L * R, dx / L * R
        d.polygon([(X0 + nx, Y0 + ny), (X1 + nx, Y1 + ny), (X1 - nx, Y1 - ny), (X0 - nx, Y0 - ny)], fill=fill)
        for X, Y in ((X0, Y0), (X1, Y1)):
            d.ellipse([X - R, Y - R, X + R, Y + R], fill=fill)

    def rect(self, d, x0, y0, x1, y1, fill=255):
        self.poly(d, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill)

    def sector(self, d, cx, cy, r0, r1, a0, a1, fill=255):
        """a ring's piece, from angle a0 to a1 (degrees, clockwise from 3 o'clock)"""
        m = max(8, int(abs(a1 - a0) / 3))
        outer = [(cx + r1 * math.cos(math.radians(a0 + (a1 - a0) * i / m)), cy + r1 * math.sin(math.radians(a0 + (a1 - a0) * i / m))) for i in range(m + 1)]
        inner = [(cx + r0 * math.cos(math.radians(a1 - (a1 - a0) * i / m)), cy + r0 * math.sin(math.radians(a1 - (a1 - a0) * i / m))) for i in range(m + 1)]
        self.poly(d, outer + inner, fill)

    def text(self, d, cx, cy, txt, h, fill=255):
        font = ImageFont.truetype(FONT, max(4, int(self.r(h) * 1.35)))
        X, Y = self.map(cx, cy)
        d.text((X, Y), txt, font=font, fill=fill, anchor='mm')


def layer(n, pen_args, draw, round_r=0.0):
    """a mask drawn by draw(pen, d); its convex corners rounded by round_r units"""
    m = Image.new('L', (n, n), 0)
    pen = Pen(n, **pen_args)
    draw(pen, ImageDraw.Draw(m))
    a = np.asarray(m) > 127
    if round_r > 0:
        rr = round_r * n / 32
        din = cv2.distanceTransform(a.astype(np.uint8), cv2.DIST_L2, 5)
        core = (din > rr).astype(np.uint8)
        dout = cv2.distanceTransform(1 - core, cv2.DIST_L2, 5)
        a = (dout <= rr) & a | (core > 0)
    return a


# ---------------------------------------------------------------- the materials
LIGHT = np.array([-0.52, -0.72, 0.95]); LIGHT = LIGHT / np.linalg.norm(LIGHT)


def normals(m, depth, ppu, sunk=False):
    """its inside distance (units) and its surface's normal, from a rounded bevel"""
    din = cv2.distanceTransform(m.astype(np.uint8), cv2.DIST_L2, 5) / ppu
    h = np.clip(din / depth, 0, 1)
    h = np.sqrt(1 - (1 - h) ** 2)                     # a round profile, like a tube's
    h = cv2.GaussianBlur(h.astype(np.float32), (0, 0), max(0.6, 0.3 * ppu))
    gy, gx = np.gradient(h * depth * ppu)
    if sunk:
        gx, gy = -gx, -gy
    l = np.sqrt(gx * gx + gy * gy + 1)
    return din, -gx / l, -gy / l, 1 / l               # (nx, ny, nz: ny < 0 faces up)


def shade(m, material, ppu):
    """the colour of mask m in its material (RGB 0..255)"""
    ys = np.where(m.any(1))[0]
    y0, y1 = (ys.min(), ys.max() + 1) if len(ys) else (0, 1)
    t = np.clip((np.arange(m.shape[0])[:, None] - y0) / max(1, y1 - y0), 0, 1) * np.ones_like(m, dtype=np.float32)
    if material == 'chrome':
        din, nx, ny, nz = normals(m, 2.0, ppu)
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        # polished chrome mirrors a room: sky above, a dark horizon across its
        # middle, a lighter floor; its upturned edges catch the sky, its lower
        # ones the dark
        e = 0.5 - 0.85 * ny - 0.38 * (t - 0.5)
        env = np.interp(e, [0, 0.22, 0.4, 0.47, 0.53, 0.62, 0.8, 1.0], [0.5, 0.66, 0.86, 0.6, 0.66, 0.97, 1.0, 1.0])
        v = env * (0.95 - 0.18 * nx)
        v += 0.55 * np.clip((lam - 0.93) / 0.07, 0, 1) ** 1.5       # its glint
        rgb = np.clip(v, 0, 1.1)[..., None] * np.array([248, 244, 234])
        ow, dark = 0.5, np.array([46, 43, 40])
    elif material == 'sage':
        din, nx, ny, nz = normals(m, 1.0, ppu, sunk=True)
        lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
        v = (0.55 + 0.5 * lam) * (1.1 - 0.25 * t)
        rgb = np.clip(v, 0, 1.2)[..., None] * np.array([122, 150, 110])
        # its glaze: a soft light across its upper part
        gl = np.clip(1 - t / 0.42, 0, 1) * np.clip(din / 0.9, 0, 1)
        rgb = rgb + (gl * 0.22)[..., None] * np.array([235, 245, 225])
        ow, dark = 0.4, np.array([34, 46, 32])
    else:                                                          # 'groove': a dark seam
        din = cv2.distanceTransform(m.astype(np.uint8), cv2.DIST_L2, 5) / ppu
        rgb = np.ones(m.shape + (3,)) * np.array([70, 65, 60])
        ow, dark = 0, rgb[0, 0]
    if ow:
        e = np.clip(1 - (din - ow) / 0.35, 0, 1)[..., None]           # the outline
        rgb = rgb * (1 - e) + dark * e
    return rgb.astype(np.float32)


def render(layers, size, ss):
    """layers: [(material, draw, pen_args, round_r)] -> RGBA image size x size"""
    n = size * ss
    ppu = n / 32
    rgb = np.zeros((n, n, 3), np.float32)
    a = np.zeros((n, n), np.float32)
    for material, draw, pen_args, rr in layers:
        m = layer(n, pen_args, draw, rr)
        c = shade(m, material, ppu)
        if material == 'groove':
            ma = m.astype(np.float32) * 0.85 * (a > 0)
        else:
            ma = m.astype(np.float32)
        rgb = rgb * (1 - ma[..., None]) + c * ma[..., None]
        a = a + ma * (1 - a)
    # its shadow: down and a little right, soft, even
    sh = np.roll(np.roll(a, int(round(1.0 * ppu)), 0), int(round(0.6 * ppu)), 1)
    sh = cv2.GaussianBlur(sh, (0, 0), 0.9 * ppu) * 0.38
    A = a + sh * (1 - a)
    pre = np.dstack([rgb * a[..., None], A * 255])                 # premultiplied (the shadow black)
    small = cv2.resize(pre, (size, size), interpolation=cv2.INTER_AREA)
    al = small[..., 3:4] / 255
    col = small[..., :3] / np.maximum(al, 1e-4)
    return Image.fromarray(np.dstack([col, al * 255]).clip(0, 255).astype('uint8'), 'RGBA')


# ---------------------------------------------------------------- the cursors
def L(material, draw, rr=0.45, **pen):
    return (material, draw, pen, rr)


ARROW = [(3, 2), (3, 25.5), (8.8, 20.4), (12.8, 29), (17.2, 27.1), (13.3, 18.6), (20.8, 18.4)]


def arrow(**pen):
    return [L('chrome', lambda p, d: p.poly(d, ARROW), 0.7, **pen),
            L('sage', lambda p, d: p.poly(d, [(5.8, 9), (5.8, 20.3), (15.3, 16.6)]), 0.6, **pen)]


SMALL = dict(scale=0.76, about=(3, 2))          # the arrow beside a sign


def half_ellipse(cx, cy, rx, ry):
    """an ellipse's lower half (the hands' sage crescent)"""
    return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in range(0, 181, 6)]


def pointer():
    def body(p, d):
        p.capsule(d, 12.5, 4.2, 12.5, 17, 2.7)
        for x, y0, r in ((17.3, 11.5, 2.4), (21.6, 12.6, 2.3), (25.4, 14.2, 2.1)):
            p.capsule(d, x, y0, x, 18.5, r)
        p.rect(d, 9.8, 15, 27.5, 23.5)
        p.capsule(d, 14, 23.5, 23.2, 23.5, 5)
        p.capsule(d, 7.2, 17.5, 11, 23, 2.5)
    def seams(p, d):
        for x, y0, y1 in ((14.95, 12.6, 18), (19.45, 13.4, 18.2), (23.5, 15, 18.6)):
            p.capsule(d, x, y0, x, y1, 0.32)
    return [L('chrome', body, 0.8), L('groove', seams, 0),
            L('sage', lambda p, d: p.poly(d, half_ellipse(18.6, 21.6, 6.1, 4.6)), 0.6)]


def open_hand():
    def body(p, d):
        for x, y0, r in ((10.5, 7.6, 2.4), (15, 4.8, 2.5), (19.4, 5.3, 2.5), (23.6, 8.2, 2.3)):
            p.capsule(d, x, y0, x, 16, r)
        p.rect(d, 8.2, 13.5, 26, 22)
        p.capsule(d, 12.8, 23, 21.4, 23, 5.3)
        p.capsule(d, 5, 15.5, 9.6, 21.5, 2.4)
    def seams(p, d):
        for x, y0, y1 in ((12.75, 11, 16.6), (17.2, 9, 16.4), (21.5, 10, 16.6)):
            p.capsule(d, x, y0, x, y1, 0.32)
    return [L('chrome', body, 0.8), L('groove', seams, 0),
            L('sage', lambda p, d: p.poly(d, half_ellipse(17.1, 21.6, 6.2, 4.5)), 0.6)]


def closed_hand():
    def body(p, d):
        for x in (10.6, 15, 19.4, 23.7):
            p.circle(d, x, 13.2, 2.7)
        p.rect(d, 7.9, 13.2, 26.4, 21.5)
        p.capsule(d, 12.6, 22.2, 21.7, 22.2, 5.5)
        p.capsule(d, 5.8, 16, 9.4, 20.4, 2.3)
    def seams(p, d):
        for x in (12.8, 17.2, 21.55):
            p.capsule(d, x, 11.6, x, 15.4, 0.32)
    return [L('chrome', body, 0.8), L('groove', seams, 0),
            L('sage', lambda p, d: p.poly(d, half_ellipse(17.1, 20.8, 6.2, 4.4)), 0.6)]


def ibeam(**pen):
    def body(p, d):
        p.capsule(d, 10.8, 5, 21.2, 5, 2)
        p.capsule(d, 10.8, 27, 21.2, 27, 2)
        p.rect(d, 14.2, 5, 17.8, 27)
    return [L('chrome', body, 0.6, **pen),
            L('sage', lambda p, d: p.rect(d, 15.3, 8.5, 16.7, 23.5), 0.5, **pen)]


def ring(cx, cy, r_out, r_in, s0, s1, turn, width=38):
    """a busy ring: chrome, with six sage pieces turning"""
    def body(p, d):
        p.circle(d, cx, cy, r_out)
        p.circle(d, cx, cy, r_in, fill=0)
    def pieces(p, d):
        for i in range(6):
            a = turn + i * 60
            p.sector(d, cx, cy, s0, s1, a, a + width)
    return [L('chrome', body, 0.4), L('sage', pieces, 0.35)]


def not_allowed():
    def body(p, d):
        p.circle(d, 16, 16, 13)
        p.circle(d, 16, 16, 9.8, fill=0)
        p.capsule(d, 9.3, 9.3, 22.7, 22.7, 1.9)
    return [L('sage', lambda p, d: p.circle(d, 16, 16, 10.2), 0), L('chrome', body, 0.4)]


def crosshair():
    def body(p, d):
        for a in ((3, 16, 12, 16), (20, 16, 29, 16), (16, 3, 16, 12), (16, 20, 16, 29)):
            p.capsule(d, *a, 1.5)
        p.circle(d, 16, 16, 4.2)
        p.circle(d, 16, 16, 2.4, fill=0)
    def inlay(p, d):
        for a in ((4.6, 16, 10.6, 16), (21.4, 16, 27.4, 16), (16, 4.6, 16, 10.6), (16, 21.4, 16, 27.4)):
            p.capsule(d, *a, 0.5)
        p.circle(d, 16, 16, 1.6)
    return [L('chrome', body, 0.3), L('sage', inlay, 0)]


def four_way(stub=None):
    """move (stub None: a cross through) or all-scroll (short stubs and a ball)"""
    def body(p, d):
        if stub is None:
            p.capsule(d, 6, 16, 26, 16, 1.8); p.capsule(d, 16, 6, 16, 26, 1.8)
        else:
            for a in ((16, 7, 16, 11.5), (16, 25, 16, 20.5), (7, 16, 11.5, 16), (25, 16, 20.5, 16)):
                p.capsule(d, *a, 1.6)
            p.circle(d, 16, 16, 3.6)
        p.poly(d, [(16, 1.8), (10.8, 7.8), (21.2, 7.8)])
        p.poly(d, [(16, 30.2), (10.8, 24.2), (21.2, 24.2)])
        p.poly(d, [(1.8, 16), (7.8, 10.8), (7.8, 21.2)])
        p.poly(d, [(30.2, 16), (24.2, 10.8), (24.2, 21.2)])
    def inlay(p, d):
        if stub is None:
            p.capsule(d, 6.5, 16, 25.5, 16, 0.6); p.capsule(d, 16, 6.5, 16, 25.5, 0.6)
        else:
            for a in ((16, 6, 16, 11), (16, 26, 16, 21), (6, 16, 11, 16), (26, 16, 21, 16)):
                p.capsule(d, *a, 0.6)
    return [L('chrome', body, 0.5), L('sage', inlay, 0)]


def double_arrow(turn):
    def body(p, d):
        p.poly(d, [(2, 16), (9.6, 8.6), (9.6, 23.4)])
        p.poly(d, [(30, 16), (22.4, 8.6), (22.4, 23.4)])
        p.rect(d, 8, 13.9, 24, 18.1)
    return [L('chrome', body, 0.55, turn=turn),
            L('sage', lambda p, d: p.rect(d, 6, 15.1, 26, 16.9), 0.5, turn=turn)]


def single_arrow(turn):
    def body(p, d):
        p.poly(d, [(16, 2.2), (6.5, 12.6), (25.5, 12.6)])
        p.rect(d, 12.6, 11.5, 19.4, 28.5)
    def inlay(p, d):
        p.poly(d, [(16, 6.4), (10.4, 11.3), (21.6, 11.3)])
        p.rect(d, 14.9, 10.5, 17.1, 26.5)
    return [L('chrome', body, 0.6, turn=turn), L('sage', inlay, 0.4, turn=turn)]


def split(turn):
    def body(p, d):
        p.rect(d, 14.3, 3, 17.7, 29)
        p.poly(d, [(2, 16), (8, 10.6), (8, 21.4)]); p.rect(d, 7, 14.3, 12.6, 17.7)
        p.poly(d, [(30, 16), (24, 10.6), (24, 21.4)]); p.rect(d, 19.4, 14.3, 25, 17.7)
    def inlay(p, d):
        p.rect(d, 15.35, 5, 16.65, 27)
        p.rect(d, 5.5, 15.4, 12, 16.6); p.rect(d, 20, 15.4, 26.5, 16.6)
    return [L('chrome', body, 0.6, turn=turn), L('sage', inlay, 0.4, turn=turn)]


def zoom(plus):
    def body(p, d):
        p.circle(d, 13, 13, 10.8)
        p.circle(d, 13, 13, 7.6, fill=0)
        p.capsule(d, 20.4, 20.4, 27.6, 27.6, 2.8)
    def sign(p, d):
        p.capsule(d, 9.4, 13, 16.6, 13, 1.25)
        if plus:
            p.capsule(d, 13, 9.4, 13, 16.6, 1.25)
    return [L('sage', lambda p, d: p.circle(d, 13, 13, 8.0), 0), L('chrome', body, 0.4), L('chrome', sign, 0)]


def copy():
    return [L('chrome', lambda p, d: p.rect(d, 11, 4, 27.5, 20.5), 3),
            L('sage', lambda p, d: p.rect(d, 23.2, 7.5, 25.2, 17.5), 0.6),
            L('chrome', lambda p, d: p.rect(d, 4.5, 10.5, 21, 27), 3)]


def alias():
    def curve(p, d):
        pts = [(21 + 13 * math.cos(math.radians(a)), 27 + 13 * math.sin(math.radians(a))) for a in range(180, 271, 6)]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            p.capsule(d, x0, y0, x1, y1, 1.8)
        p.poly(d, [(27.5, 14), (20.6, 8.4), (20.6, 19.6)])
    return [L('chrome', lambda p, d: p.rect(d, 10.5, 4, 28, 21.5), 3), L('sage', curve, 0.4)]


def context_menu():
    def inlay(p, d):
        for y in (11, 16, 21):
            p.circle(d, 8.8, y, 1.35)
            p.rect(d, 12, y - 1.05, 24.2, y + 1.05)
    return [L('chrome', lambda p, d: p.rect(d, 4, 6, 28, 26), 3.2), L('sage', inlay, 0.5)]


def cell():
    def body(p, d):
        for (x, y, dx, dy) in ((3, 3, 1, 1), (29, 3, -1, 1), (3, 29, 1, -1), (29, 29, -1, -1)):
            p.capsule(d, x, y, x + 5.5 * dx, y, 1.1)
            p.capsule(d, x, y, x, y + 5.5 * dy, 1.1)
        for x in (8, 16.6):
            for y in (8, 16.6):
                p.rect(d, x, y, x + 7.4, y + 7.4)
    def inlay(p, d):
        for x in (8, 16.6):
            for y in (8, 16.6):
                p.rect(d, x + 1.7, y + 1.7, x + 5.7, y + 5.7)
    return [L('chrome', body, 1.0), L('sage', inlay, 0.6)]


def no_drop():
    def x(p, d):
        p.capsule(d, 11, 11, 21, 21, 1.7); p.capsule(d, 21, 11, 11, 21, 1.7)
    def seam(p, d):
        p.circle(d, 16, 16, 10.4); p.circle(d, 16, 16, 9.8, fill=0)
    return [L('chrome', lambda p, d: p.circle(d, 16, 16, 13), 0), L('groove', seam, 0), L('sage', x, 0)]


def up_arrow():
    def body(p, d):
        p.poly(d, [(16, 2), (3.5, 15.5), (28.5, 15.5)])
        p.rect(d, 10.8, 14.5, 21.2, 29.5)
    def inlay(p, d):
        p.poly(d, [(16, 7.4), (9.4, 13.8), (22.6, 13.8)])
        p.rect(d, 13.6, 12.8, 18.4, 27)
    return [L('chrome', body, 1.0), L('sage', inlay, 0.6)]


def dashed_box():
    def dash(p, d):
        x0, y0, x1, y1 = 17.5, 17.5, 29.5, 29.5
        for a, b in ((x0, x1), ):
            pass
        step, seg = 3.0, 1.7
        t = x0
        while t < x1 - 0.5:
            for (ax, ay, bx, by) in ((t, y0, min(t + seg, x1), y0), (t, y1, min(t + seg, x1), y1),
                                     (x0, t, x0, min(t + seg, y1)), (x1, t, x1, min(t + seg, y1))):
                p.capsule(d, ax, ay, bx, by, 0.6)
            t += step
    return [L('chrome', dash, 0)]


def help_sign():
    return [L('chrome', lambda p, d: p.circle(d, 23.4, 23.4, 7.4), 0),
            L('sage', lambda p, d: p.circle(d, 23.4, 23.4, 5.6), 0),
            L('chrome', lambda p, d: p.text(d, 23.4, 23.6, '?', 7.6), 0)]


def turned(pt, turn):
    a = math.radians(turn)
    x, y = pt[0] - 16, pt[1] - 16
    return 16 + math.cos(a) * x - math.sin(a) * y, 16 + math.sin(a) * x + math.cos(a) * y


TIP = (3.5, 2.8)
SINGLE = {'n': 0, 'ne': 45, 'e': 90, 'se': 135, 's': 180, 'sw': 225, 'w': 270, 'nw': 315}

# name: (layers for frame k, hotspot in units, frames)
CURSORS = {
    'default':       (lambda k: arrow(), TIP, 1),
    'pointer':       (lambda k: pointer(), (12.5, 1.9), 1),
    'text':          (lambda k: ibeam(), (16, 16), 1),
    'vertical-text': (lambda k: ibeam(turn=90), (16, 16), 1),
    'wait':          (lambda k: ring(16, 16, 13, 6.8, 8.4, 11.6, k * 5), (16, 16), 12),
    'progress':      (lambda k: arrow(**SMALL) + ring(24, 24, 7, 3.4, 4.4, 6.1, k * 5, 34), TIP, 12),
    'help':          (lambda k: arrow(**SMALL) + help_sign(), TIP, 1),
    'not-allowed':   (lambda k: not_allowed(), (16, 16), 1),
    'crosshair':     (lambda k: crosshair(), (16, 16), 1),
    'move':          (lambda k: four_way(), (16, 16), 1),
    'grab':          (lambda k: open_hand(), (16, 15), 1),
    'grabbing':      (lambda k: closed_hand(), (16, 16), 1),
    'ew-resize':     (lambda k: double_arrow(0), (16, 16), 1),
    'ns-resize':     (lambda k: double_arrow(90), (16, 16), 1),
    'nwse-resize':   (lambda k: double_arrow(45), (16, 16), 1),
    'nesw-resize':   (lambda k: double_arrow(-45), (16, 16), 1),
    'col-resize':    (lambda k: split(0), (16, 16), 1),
    'row-resize':    (lambda k: split(90), (16, 16), 1),
    'zoom-in':       (lambda k: zoom(True), (13, 13), 1),
    'zoom-out':      (lambda k: zoom(False), (13, 13), 1),
    'copy':          (lambda k: copy(), (5, 11), 1),
    'alias':         (lambda k: alias(), (8, 26), 1),
    'context-menu':  (lambda k: context_menu(), (4.5, 6.5), 1),
    'cell':          (lambda k: cell(), (16, 16), 1),
    'all-scroll':    (lambda k: four_way(stub=True), (16, 16), 1),
    'no-drop':       (lambda k: no_drop(), (16, 16), 1),
    'up-arrow':      (lambda k: up_arrow(), (16, 2.6), 1),
    'dnd-move':      (lambda k: arrow(**SMALL) + dashed_box(), TIP, 1),
}
for d, t in SINGLE.items():
    CURSORS[d + '-resize'] = ((lambda t: lambda k: single_arrow(t))(t), turned((16, 2.8), t), 1)


# the names asked for, each a link to one of the files above
ALIASES = {
    'default': ['left_ptr', 'arrow', 'top_left_arrow', 'left-arrow', 'x-cursor', 'X_cursor', 'right_ptr', 'draft_large', 'draft_small'],
    'pointer': ['hand', 'hand1', 'hand2', 'pointing_hand', 'e29285e634086352946a0e7090d73106', '9d800788f1b08800ae810202380a0822'],
    'text': ['xterm', 'ibeam'],
    'vertical-text': [],
    'wait': ['watch', 'clock'],
    'progress': ['left_ptr_watch', 'half-busy', '08e8e1c95fe2fc01f976f1e063a24ccd', '3ecb610c1bf2410f44200f48c40d3599', '00000000000000020006000e7e9ffc3f'],
    'help': ['question_arrow', 'whats_this', 'left_ptr_help', 'd9ce0ab605698f320427677b458ad60b', '5c6cd98b3f3ebcb1f9c7f1c204630408'],
    'not-allowed': ['crossed_circle', 'forbidden', 'circle', '03b6e0fcb3499374a867c041f52298f0'],
    'crosshair': ['cross', 'tcross', 'cross_reverse', 'diamond_cross', 'target', 'color-picker'],
    'move': ['fleur', 'size_all', 'pointer-move', '4498f0e0c1937ffe01fd06f973665830', '9081237383d90e509aa00f00170e968f'],
    'grab': ['openhand', 'hand-grab', '5aca4d189052212118709018842178c0', '208530c400c041818281048008011002'],
    'grabbing': ['closedhand', 'dnd-none', 'hand-grabbing', 'fcf21c00b30f7e3f83fe0dfd12e71cff'],
    'ew-resize': ['h_double_arrow', 'sb_h_double_arrow', 'size_hor', 'col-resize-alt', 'e-w-resize', '028006030e0e7ebffc7f7070c0600140', '14fef782d02440884392942c11205230'],
    'ns-resize': ['v_double_arrow', 'sb_v_double_arrow', 'size_ver', 'n-s-resize', '00008160000006810000408080010102', '2870a09082c103050810ffdffffe0204'],
    'nwse-resize': ['size_fdiag', 'bd_double_arrow', 'nw-se-resize', 'c7088f0f3e6c8088236ef8e1e3e70000'],
    'nesw-resize': ['size_bdiag', 'fd_double_arrow', 'ne-sw-resize', 'fcf1c3c7cd4491d801f1e1c78f100000'],
    'n-resize': ['top_side'],
    's-resize': ['bottom_side'],
    'e-resize': ['right_side'],
    'w-resize': ['left_side'],
    'ne-resize': ['top_right_corner'],
    'nw-resize': ['top_left_corner'],
    'se-resize': ['bottom_right_corner'],
    'sw-resize': ['bottom_left_corner'],
    'col-resize': ['split_h', 'sb_h_arrow', '043a9f68147c53184671403ffa811cc5'],
    'row-resize': ['split_v', 'sb_v_arrow', 'c07385c7ba0bd3ef4abb06fa66ccc3f2'],
    'zoom-in': ['zoom_in'],
    'zoom-out': ['zoom_out'],
    'copy': ['dnd-copy', 'copy_drop', '1081e37283d90000800003c07f3ef6bf', '6407b0e94181790501fd1e167b474872'],
    'alias': ['dnd-link', 'link', 'link_drop', '3085a0e285430894940527032f8b26df', '640fb0e74195791501fd1ed57b41487f'],
    'context-menu': [],
    'cell': ['plus'],
    'all-scroll': [],
    'no-drop': ['dnd-no-drop', 'forbidden-drop'],
    'up-arrow': ['center_ptr', 'sb_up_arrow'],
    'dnd-move': ['dnd-ask', 'move_drop', 'dnd_move'],
}


def xcursor(images):
    """images: [(size, xhot, yhot, delay, RGBA Image)] -> Xcursor bytes"""
    chunks = []
    for size, xh, yh, delay, im in images:
        w, h = im.size
        a = np.asarray(im).astype(np.uint32)
        # premultiplied ARGB, little-endian
        alpha = a[..., 3]
        r = a[..., 0] * alpha // 255; g = a[..., 1] * alpha // 255; b = a[..., 2] * alpha // 255
        argb = (alpha << 24) | (r << 16) | (g << 8) | b
        body = struct.pack('<IIIIIIIII', 36, 0xfffd0002, size, 1, w, h, xh, yh, delay) + argb.astype('<u4').tobytes()
        chunks.append((size, body))
    header = 16
    toc = 12 * len(chunks)
    pos = header + toc
    out_ = struct.pack('<4sIII', b'Xcur', 16, 0x10000, len(chunks))
    for size, body in chunks:
        out_ += struct.pack('<III', 0xfffd0002, size, pos)
        pos += len(body)
    for _, body in chunks:
        out_ += body
    return out_


# ---------------------------------------------------------------- writing them
cursors_dir = os.path.join(out, 'cursors')
os.makedirs(cursors_dir, exist_ok=True)
for name, (make, (hx, hy), nframes) in CURSORS.items():
    images = []
    for size in SIZES:
        ss = 6 if size <= 36 else 4
        for k in range(nframes):
            im = render(make(k), size, ss)
            xh = min(size - 1, max(0, round(hx * size / 32)))
            yh = min(size - 1, max(0, round(hy * size / 32)))
            images.append((size, xh, yh, 70 if nframes > 1 else 0, im))
    with open(os.path.join(cursors_dir, name), 'wb') as fh:
        fh.write(xcursor(images))
    for alias_ in ALIASES.get(name, []):
        p = os.path.join(cursors_dir, alias_)
        if os.path.lexists(p):
            os.remove(p)
        os.symlink(name, p)

with open(os.path.join(out, 'index.theme'), 'w') as fh:
    fh.write('[Icon Theme]\nName=Magnetic88\nComment=Magnetic 88: chrome and sage cursors\nInherits=Adwaita\n')
print(len(CURSORS), 'cursors,', sum(len(v) for v in ALIASES.values()), 'names linked')
