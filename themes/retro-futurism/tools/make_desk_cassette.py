#!/usr/bin/env python3
"""The cassette player in her hands (the wallpaper), cleaned up: the picture's
made-up lettering painted out and written again, its keys' symbols drawn
clean, its cassette given a label.

    python3 tools/make_desk_cassette.py wallpaper.jpg wallpaper.jpg \
        home/.local/share/ultra/retro-futurism/cassette

Its reels are drawn again too (a brown tape pack round a cream six-toothed
hub), and with a cassette folder given, written as the two reels that turn
(home-reel-l/r.png, in place of those tools/make_cassette.py cuts).

tools/make_wallpaper_front.py calls retouch() on the picture before it is
saved, so this runs once whenever the wallpaper is made; on its own it is for
the wallpaper as it is (once: it is not to be run twice on the same file).
Everything in the picture's own pixels (3840 x 2160).
(pip: numpy pillow opencv-python-headless)
"""
import os, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, '..', 'home', '.local', 'share', 'fonts', 'retro-futurism')
INK = np.array([72, 64, 57], np.float64)          # its printing: a warm dark grey
SS = 6                                            # (drawn this many times larger, then averaged down)


def paint_out(img, box, darker=22, grow=2, r=4):
    """what is darker than the surface round it, in box, painted over"""
    x0, y0, x1, y1 = box
    part = img[y0:y1, x0:x1].clip(0, 255).astype(np.uint8)
    L = part.mean(2).astype(np.float32)
    surface = cv2.GaussianBlur(cv2.dilate(L, np.ones((9, 9), np.uint8)), (0, 0), 3)
    m = (L < surface - darker).astype(np.uint8)
    m = cv2.dilate(m, np.ones((3, 3), np.uint8), iterations=grow)
    img[y0:y1, x0:x1] = cv2.inpaint(part, m * 255, r, cv2.INPAINT_TELEA).astype(np.float64)


TILT = 2.8          # the player leans this many degrees clockwise (its window's and keys' edges)


def stamp(img, box, draw, colour=INK, strength=0.9, soft=0.45, relief=True, turn=TILT, pad=10):
    """draw(d, s) paints the mark (white) on a canvas the size of box, s times
    larger; it is turned with the player (about the box's middle) and laid on
    the picture in colour, printed a touch into the surface (a faint light
    edge below it)"""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    c = Image.new('L', (w * SS, h * SS), 0)
    draw(ImageDraw.Draw(c), SS)
    big = Image.new('L', ((w + 2 * pad) * SS, (h + 2 * pad) * SS), 0)
    big.paste(c, (pad * SS, pad * SS))
    if turn:
        big = big.rotate(-turn, resample=Image.BICUBIC)
    a = np.asarray(big.resize((w + 2 * pad, h + 2 * pad), Image.LANCZOS)).astype(np.float32) / 255
    a = cv2.GaussianBlur(a, (0, 0), soft)
    reg = img[y0 - pad:y1 + pad, x0 - pad:x1 + pad]
    if relief:
        lit = np.clip(np.roll(a, 1, 0) - a, 0, 1)[..., None] * 0.22
        reg[:] = reg + (255 - reg) * lit
    a = (a * strength)[..., None]
    reg[:] = reg * (1 - a) + colour * a


def font(name, px):
    return ImageFont.truetype(os.path.join(FONTS, name), px)


def spaced(d, x, y, text, f, spacing, fill=255):
    """text with its letters spread (x, y: its left, its middle)"""
    for ch in text:
        d.text((x, y), ch, font=f, fill=fill, anchor='lm')
        x += d.textlength(ch, font=f) + spacing
    return x


def width(text, f, spacing):
    d = ImageDraw.Draw(Image.new('L', (1, 1)))
    return sum(d.textlength(ch, font=f) for ch in text) + spacing * (len(text) - 1)


def retouch(img):
    """img: the wallpaper as a float array (H, W, 3), changed in place"""
    # ---- the plate above the window: its lettering
    paint_out(img, (2334, 1436, 2478, 1462), darker=20, grow=2)
    def name(d, s):
        f = font('Barlow-SemiBold.ttf', 15 * s)
        sp = 2.6 * s
        x = (140 * s - width('MAGNETIC 88', f, sp)) / 2
        spaced(d, x, 13.6 * s, 'MAGNETIC 88', f, sp)
    stamp(img, (2336, 1436, 2476, 1464), name)

    # ---- the stripes beside it: five clean slanted bars
    paint_out(img, (2484, 1437, 2574, 1467), darker=16, grow=2, r=4)
    def stripes(d, s):
        for i in range(5):
            bx = 4 + i * 15.5
            d.polygon([((bx) * s, 24 * s), ((bx + 8) * s, 24 * s), ((bx + 20) * s, 6 * s), ((bx + 12) * s, 6 * s)], fill=255)
    stamp(img, (2486, 1437, 2572, 1467), stripes, colour=np.array([74, 67, 60]), strength=0.9, soft=0.6)

    # ---- the made-up mark under the window: written as a word
    paint_out(img, (2340, 1538, 2392, 1556), darker=18, grow=2)
    def stereo(d, s):
        f = font('Barlow-Medium.ttf', 8 * s)
        spaced(d, 1 * s, 7 * s, 'STEREO', f, 1.4 * s)
    stamp(img, (2344, 1540, 2392, 1554), stereo, colour=np.array([196, 186, 168]), strength=0.75, relief=False)

    # ---- the keys' symbols: painted out, drawn clean (each key a little
    # lower than the one before, as they lie)
    keys = [(2372, 1598), (2422, 1602), (2472, 1604.5), (2525, 1607)]
    for cx, cy in keys:
        paint_out(img, (int(cx) - 15, int(cy) - 10, int(cx) + 15, int(cy) + 10), darker=26, grow=1, r=3)
    def tri(d, s, x, y, w, h, left=False):
        if left:
            d.polygon([((x + w) * s, y * s), ((x + w) * s, (y + h) * s), (x * s, (y + h / 2) * s)], fill=255)
        else:
            d.polygon([(x * s, y * s), (x * s, (y + h) * s), ((x + w) * s, (y + h / 2) * s)], fill=255)
    def back(d, s):
        tri(d, s, 2.5, 4.5, 8.5, 11, True); tri(d, s, 10.5, 4.5, 8.5, 11, True)
    def halt(d, s):
        d.rounded_rectangle([5 * s, 5 * s, 15 * s, 15 * s], 1 * s, fill=255)
    def go(d, s):
        tri(d, s, 6.5, 4, 9.5, 12)
    def fwd(d, s):
        tri(d, s, 2, 4.5, 8.5, 11); tri(d, s, 10, 4.5, 8.5, 11)
    for (cx, cy), draw in zip(keys, (back, halt, go, fwd)):
        stamp(img, (int(round(cx)) - 10, int(round(cy)) - 10, int(round(cx)) + 10, int(round(cy)) + 10), draw,
              colour=np.array([60, 55, 50]), strength=0.92, soft=0.5)

    # ---- the cassette's label: a band of colour along its foot, a side, a
    # line written by hand (a title, in pencil)
    x0, y0, x1, y1 = 2384, 1479, 2521, 1499
    def band(d, s):
        d.rectangle([0, 15.5 * s, (x1 - x0) * s, 18.5 * s], fill=255)
    stamp(img, (x0, y0, x1, y1), band, colour=np.array([168, 84, 58]), strength=0.7, soft=0.4, relief=False)
    def side(d, s):
        f = font('Barlow-Bold.ttf', 10 * s)
        d.text((4 * s, 7.5 * s), 'A', font=f, fill=255, anchor='lm')
        f2 = font('Barlow-Medium.ttf', 8 * s)
        spaced(d, 18 * s, 7.8 * s, 'NIGHT TRAIN', f2, 1.2 * s)
    stamp(img, (x0, y0, x1, y1), side, colour=np.array([58, 50, 44]), strength=0.95, soft=0.35, relief=False)

    # ---- the two mushy shapes on its right panel, below its lamp: two small
    # round buttons
    paint_out(img, (2590, 1566, 2618, 1612), darker=16, grow=2, r=5)
    for bx, by in ((2603.5, 1576.5), (2603.5, 1598.5)):
        def btn(d, s, bx=bx, by=by):
            c = 10
            d.ellipse([(c - 5.2) * s, (c - 5.2) * s, (c + 5.2) * s, (c + 5.2) * s], fill=255)
        box = (int(bx) - 10, int(by) - 10, int(bx) + 10, int(by) + 10)
        stamp(img, box, btn, colour=np.array([70, 62, 56]), strength=0.9, soft=0.5)
        def cap(d, s):
            d.ellipse([(10 - 3.8) * s, (10 - 3.8) * s, (10 + 3.8) * s, (10 + 3.8) * s], fill=255)
        stamp(img, box, cap, colour=np.array([200, 190, 172]), strength=0.95, soft=0.5, relief=False)
        def shine(d, s):
            d.ellipse([(10 - 2.6) * s, (10 - 3) * s, (10 + 0.4) * s, (10 - 0.6) * s], fill=255)
        stamp(img, box, shine, colour=np.array([240, 234, 222]), strength=0.7, soft=0.6, relief=False)

    # ---- its reels
    # (the old reel painted out first, from the shell round it)
    for cx, cy in REELS:
        x0, y0 = int(cx) - 30, int(cy) - 30
        part = img[y0:y0 + 60, x0:x0 + 60].clip(0, 255).astype(np.uint8)
        yy, xx = np.mgrid[0:60, 0:60]
        m = (np.hypot(xx + x0 + 0.5 - cx, yy + y0 + 0.5 - cy) < 22.5) & (yy + y0 >= 1500)
        img[y0:y0 + 60, x0:x0 + 60] = cv2.inpaint(part, m.astype(np.uint8) * 255, 6, cv2.INPAINT_TELEA).astype(np.float64)
    for cx, cy in REELS:
        draw_reel(img, cx, cy)
    return img


REELS = [(2404.0, 1517.5), (2501.5, 1523.0)]      # where they turn (tools/make_cassette.py)
REEL_R = 18.6                                     # the tape pack's edge (the label in front of it)


def reel_layer(cx, cy, n=56):
    """the reel drawn on an n x n square round (cx, cy): RGB and its cover"""
    k = SS
    yy, xx = (np.mgrid[0:n * k, 0:n * k].astype(np.float64) + 0.5) / k - n / 2
    ox, oy = cx - np.floor(cx), cy - np.floor(cy)       # (its centre between pixels)
    xx -= ox - 0.5; yy -= oy - 0.5
    r = np.hypot(xx, yy)
    th = np.arctan2(yy, xx)
    col = np.zeros(r.shape + (3,))
    a = np.clip((REEL_R + 0.5 - r) * k / 1.5, 0, 1)
    # the tape pack: brown, its wound rings, darker at its edge, a soft light
    # from the upper left across it
    rings = 0.5 + 0.5 * np.sin(r * 5.3) * np.sin(r * 1.7 + 0.6)
    light = 0.5 + 0.5 * np.cos(th + 2.35)
    v = 0.8 + 0.08 * rings + 0.12 * light - 0.25 * np.clip((r - 15.5) / 3, 0, 1)
    col[:] = (np.array([122, 82, 54]) * v[..., None])
    # its inner edge, where the tape meets the hub: a dark line
    col *= (1 - 0.4 * np.clip(1 - np.abs(r - 8.4) / 0.8, 0, 1))[..., None]
    # the hub: cream plastic, six teeth inward round its dark spindle hole
    hub = r < 8.1
    hv = 0.82 + 0.12 * light - 0.14 * np.clip((r - 5.5) / 3, 0, 1)
    col[hub] = (np.array([206, 194, 172]) * hv[..., None])[hub]
    tooth = (np.cos(6 * th) > 0.55) & (r > 2.9) & (r < 4.8)
    hole = (r < 4.8) & ~tooth
    col[hole] = np.array([46, 38, 32])
    col[(r < 1.2)] = np.array([110, 102, 92])            # the spindle's end
    rgb = cv2.resize(col.astype(np.float32), (n, n), interpolation=cv2.INTER_AREA)
    cover = cv2.resize(a.astype(np.float32), (n, n), interpolation=cv2.INTER_AREA)
    rgb = cv2.GaussianBlur(rgb, (0, 0), 0.6)
    return rgb, cover


def draw_reel(img, cx, cy, n=56):
    rgb, a = reel_layer(cx, cy, n)
    x0, y0 = int(np.floor(cx)) - n // 2, int(np.floor(cy)) - n // 2
    reg = img[y0:y0 + n, x0:x0 + n]
    reg[:] = reg * (1 - a[..., None]) + rgb * a[..., None]


def write_reels(img, folder, size=50):
    """the reels that turn: each a disc of the picture round its centre"""
    for (cx, cy), side in zip(REELS, 'lr'):
        x0, y0 = cx - size / 2, cy - size / 2
        M = np.float32([[1, 0, -x0], [0, 1, -y0]])
        part = cv2.warpAffine(img.astype(np.float32), M, (size, size), flags=cv2.INTER_LINEAR)
        yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) + 0.5
        a = np.clip(REEL_R + 0.6 - np.hypot(xx - size / 2, yy - size / 2), 0, 1)
        Image.fromarray(np.dstack([part, a * 255]).round().clip(0, 255).astype('uint8'), 'RGBA') \
            .save(os.path.join(folder, f'home-reel-{side}.png'))


if __name__ == '__main__':
    src, out = sys.argv[1:3]
    img = np.asarray(Image.open(src).convert('RGB')).astype(np.float64)
    retouch(img)
    if len(sys.argv) > 3:
        write_reels(img, sys.argv[3])
    Image.fromarray(img.round().clip(0, 255).astype('uint8')).save(out, quality=92, optimize=True, progressive=True)
