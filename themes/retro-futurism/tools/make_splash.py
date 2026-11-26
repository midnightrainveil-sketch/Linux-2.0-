#!/usr/bin/env python3
"""Magnetic 88's start-up and shut-down page (Plymouth): its pictures.

    python3 tools/make_splash.py system/plymouth

The lock screen goes on: the station platform at dusk (her waiting while
the machine starts; the platform empty once she has gone, as it shuts
down), and in front of it the access pass, its screen lit in the lock
screen's glowing lettering with what is happening: SYSTEM SHUTDOWN, from
the desktop session to power off, a row of lights that a glow runs along,
SHUTTING DOWN. page.script lays them out and moves them.

    bg-boot.png, bg-shutdown.png   the platform (lock.jpg, lock-boarded.jpg),
                                   darkened round the middle
    device.png, shadow.png         the pass (assets/pass.png) and its shadow
    face-<mode>.png                its screen's words, glowing, per mode
                                   (boot, shutdown, reboot, updates)
    label-progress.png, label-key.png   above the row of lights
    dot-on.png, dot-off.png, pulse.png  the lights, and the status lamp

The pass and its words are in its own pixels (1162 x 1201, as
components/PassDevice.qml has it: the mock-up's less 38, 26).
(pip: numpy pillow)
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.join(here, '..', 'home')
FONTS = os.path.join(HOME, '.local', 'share', 'fonts', 'retro-futurism')
ART = os.path.join(HOME, '.local', 'share', 'ultra', 'retro-futurism')
PASS = os.path.join(HOME, '.config', 'quickshell', 'assets', 'pass.png')
JP = next((f for f in ['/usr/share/fonts/opentype/ipafont-gothic/ipagp.ttf',
                       '/usr/share/fonts/truetype/fonts-japanese-gothic.ttf'] if os.path.exists(f)), None)

INK = (242, 248, 255)
DW, DH = 1162, 1201


def ax(x): return x - 38
def ay(y): return y - 26


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f'Barlow-{weight}.ttf'), size)


def save(im, name):
    im.save(os.path.join(out, name), optimize=True)


# ------------------------------------------------------------------ the platform
def platform(src, name):
    im = Image.open(os.path.join(ART, src)).convert('RGB')
    im = im.filter(ImageFilter.GaussianBlur(1.2))           # (a little out of focus, behind the pass)
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    # darker round the middle (where the pass stands) and toward the edges
    r = np.sqrt(((xx - w / 2) / (w * 0.62)) ** 2 + ((yy - h / 2) / (h * 0.62)) ** 2)
    shade = 0.74 - 0.18 * np.clip(r - 0.35, 0, 1) - 0.10 * np.exp(-r * r * 3.0)
    a = a * shade[..., None]
    q = Image.fromarray(a.clip(0, 255).astype('uint8')).quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    save(q, name)


platform('lock.jpg', 'bg-boot.png')
platform('lock-boarded.jpg', 'bg-shutdown.png')

# ------------------------------------------------------------------ the pass and its shadow
dev = Image.open(PASS).convert('RGBA')
save(dev, 'device.png')
al = dev.getchannel('A').resize((DW // 4, DH // 4), Image.LANCZOS)
pad = 40
sh = Image.new('L', (al.width + 2 * pad, al.height + 2 * pad), 0)
sh.paste(al, (pad, pad + 6))
sh = sh.filter(ImageFilter.GaussianBlur(12)).point(lambda v: int(v * 0.85))
shadow = Image.new('RGBA', sh.size, (4, 3, 2, 0))
shadow.putalpha(sh)
save(shadow, 'shadow.png')        # (a quarter size: page.script scales it up; it starts 160 px up and left of the pass)


# ------------------------------------------------------------------ glowing words
def lit(mask):
    """the lock screen's glow: an ice-white core, a near halo, a wide pale-blue one"""
    m = np.asarray(mask).astype(np.float32) / 255
    near = np.asarray(mask.filter(ImageFilter.GaussianBlur(5))).astype(np.float32) / 255
    wide = np.asarray(mask.filter(ImageFilter.GaussianBlur(16))).astype(np.float32) / 255
    a = np.clip(np.maximum(m, np.maximum(near * 1.1, wide * 0.85)), 0, 1)
    col = np.zeros(m.shape + (3,), np.float32)
    col[:] = (198, 227, 255)
    col = col * (1 - np.clip(near * 1.4, 0, 1))[..., None] + np.array((230, 244, 255), np.float32) * np.clip(near * 1.4, 0, 1)[..., None]
    col = col * (1 - m[..., None]) + np.array(INK, np.float32) * m[..., None]
    return Image.fromarray(np.dstack([col, a * 255]).clip(0, 255).astype('uint8'), 'RGBA')


def text(d, xy, s, f, track=0.0):
    x, y = xy
    for c in s:
        d.text((x, y), c, font=f, fill=255)
        x += f.getlength(c) + track


def slashes(d, x0, y, w, h, gap, lean, n=3):
    for i in range(n):
        x = x0 + i * gap
        d.polygon([(x + lean, y), (x + lean + w, y), (x + w, y + h), (x, y + h)], fill=255)


def rule(d, x, y, w):
    d.rectangle([x, y, x + w, y + 2], fill=235)


def face(title, sub, message, frm, to, status):
    m = Image.new('L', (DW, DH), 0)
    d = ImageDraw.Draw(m)
    # header: the mark (a cassette's E, leaning), マグネティック88
    X, Y = ax(193), ay(188)
    def bar(y, x0, x1, h):
        d.polygon([(X + x0 + 14, Y + y), (X + x1 + 14, Y + y), (X + x1, Y + y + h), (X + x0, Y + y + h)], fill=255)
    bar(0, 52, 152, 12); bar(18, 26, 128, 12); bar(36, 0, 140, 12)
    d.polygon([(X + 70, Y), (X + 84, Y), (X + 56, Y + 48), (X + 42, Y + 48)], fill=255)
    d.rectangle([ax(375), ay(194), ax(375) + 2, ay(194) + 40], fill=255)
    if JP:
        text(d, (ax(410), ay(192)), 'マグネティック88', ImageFont.truetype(JP, 34), 6)
    # what it is
    text(d, (ax(184), ay(262)), title, font('SemiBold', 48), 2.9)
    text(d, (ax(186), ay(328)), sub, font('Medium', 25), 6.4)
    rule(d, ax(187), ay(377), 526)
    slashes(d, ax(733), ay(366), 9, 15, 21, 9)
    # the message
    text(d, (ax(186), ay(424)), 'MESSAGE', font('Medium', 25), 6)
    text(d, (ax(188), ay(462)), message, font('Medium', 52), 1.4)
    rule(d, ax(191), ay(548), 590)
    # from, to
    text(d, (ax(190), ay(584)), 'FROM', font('Medium', 25), 6)
    text(d, (ax(538), ay(584)), 'TO', font('Medium', 25), 6)
    fv = font('SemiBold', 42)
    for i, line in enumerate(frm):
        text(d, (ax(192), ay(616) + i * 42), line, fv, 0.7)
    for i, line in enumerate(to):
        text(d, (ax(538), ay(616) + i * 42), line, fv, 0.7)
    ay_ = ay(660)                                           # the arrow
    d.rectangle([ax(452), ay_, ax(500), ay_ + 3], fill=255)
    d.polygon([(ax(490), ay_ - 11), (ax(506), ay_ + 1), (ax(490), ay_ + 14)], fill=255)
    rule(d, ax(191), ay(746), 590)
    rule(d, ax(191), ay(999), 590)
    # what it is doing (its lamp: pulse.png, beside it) and the ticket
    text(d, (ax(261), ay(1060)), status, font('Medium', 33), 3)
    d.rectangle([ax(678), ay(1046), ax(678) + 2, ay(1046) + 57], fill=255)
    text(d, (ax(733), ay(1042)), 'TKT No.', font('Medium', 25), 3)
    text(d, (ax(733), ay(1070)), 'M88-000088', font('Medium', 26), 3)
    slashes(d, ax(1022), ay(1053), 14, 40, 30, 22)
    return lit(m)


MODES = {
    'boot':     ('SYSTEM START-UP', 'NOW BOARDING', 'WELCOME ABOARD', ['POWER', 'OFF'], ['LOCK', 'SCREEN'], 'STARTING UP'),
    'shutdown': ('SYSTEM SHUTDOWN', 'END OF THE LINE', 'SEE YOU SOON', ['DESKTOP', 'SESSION'], ['POWER', 'OFF'], 'SHUTTING DOWN'),
    'reboot':   ('SYSTEM RESTART', 'NEXT TRAIN', 'BACK IN A MOMENT', ['DESKTOP', 'SESSION'], ['LOCK', 'SCREEN'], 'RESTARTING'),
    'updates':  ('SYSTEM UPDATE', 'MAINTENANCE STOP', 'PLEASE STAND BY', ['SYSTEM', 'UPDATE'], ['RESTART', ''], 'UPDATING'),
}
for mode, words in MODES.items():
    save(face(*words), f'face-{mode}.png')


# ------------------------------------------------------------------ the row of lights, its label, the lamp
def small(draw):
    m = Image.new('L', (120, 120), 0)
    draw(ImageDraw.Draw(m))
    return lit(m)


for name, label in [('label-progress.png', 'PROGRESS'), ('label-key.png', 'DISK KEY')]:
    m = Image.new('L', (420, 80), 0)
    text(ImageDraw.Draw(m), (30, 24), label, font('Medium', 25), 6)
    save(lit(m), name)
save(small(lambda d: d.ellipse([47, 47, 73, 73], fill=255)), 'dot-on.png')
off = Image.new('RGBA', (120, 120), (0, 0, 0, 0))
ImageDraw.Draw(off).ellipse([47, 47, 73, 73], outline=INK + (110,), width=3)
save(off, 'dot-off.png')
save(small(lambda d: d.ellipse([45, 45, 75, 75], fill=255)), 'pulse.png')
print('splash pictures in', out)
