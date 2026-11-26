#!/usr/bin/env python3
"""Magnetic 88's start-up and shut-down page (Plymouth): its pictures.

    python3 tools/make_splash.py system/plymouth

The night the train runs through: the taskbar's wordmark (/// MAGNETIC 88)
in cream, a chrome line ruled under it, a row of amber LEDs (the volume
indicator's) that a light sweeps along while the machine works, and what is
happening in the control deck's amber lettering (VT323). Drawn for an
1800 px tall screen (the G14); page.script fits them to others.
(pip: numpy pillow)
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
here = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(here, '..', 'home', '.local', 'share', 'fonts', 'retro-futurism')
BARLOW = os.path.join(FONTS, 'Barlow-SemiBold.ttf')
VT = os.path.join(FONTS, 'VT323-Regular.ttf')

CREAM = (233, 227, 213)
AMBER = (255, 180, 68)
AMBER_HOT = (255, 238, 200)
AMBER_OFF = (52, 38, 24)


def spaced(text, font, track):
    """text drawn letter by letter, `track` px between letters: (image, width, height)"""
    widths = [font.getbbox(c)[2] - font.getbbox(c)[0] if c != ' ' else font.getlength(' ') for c in text]
    asc, desc = font.getmetrics()
    w = int(sum(font.getlength(c) for c in text) + track * (len(text) - 1)) + 4
    im = Image.new('L', (w, asc + desc + 4), 0)
    d = ImageDraw.Draw(im)
    x = 2
    for c in text:
        d.text((x, 2), c, font=font, fill=255)
        x += font.getlength(c) + track
    return im.crop(im.getbbox())


def glow(mask, colour, core, radius, strength=1.0, pad=None):
    """a lit shape: its colour, a whiter core, and a soft halo round it"""
    pad = pad if pad is not None else radius * 3
    m = Image.new('L', (mask.width + 2 * pad, mask.height + 2 * pad), 0)
    m.paste(mask, (pad, pad))
    halo = np.asarray(m.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255 * 0.75 * strength
    body = np.asarray(m).astype(np.float32) / 255
    inner = np.asarray(m.filter(ImageFilter.MinFilter(3)) if min(mask.size) > 6 else m).astype(np.float32) / 255
    a = np.clip(np.maximum(halo, body), 0, 1)
    rgb = np.zeros(a.shape + (3,), np.float32)
    rgb[:] = colour
    rgb = rgb * (1 - inner[..., None] * 0.55) + np.array(core, np.float32) * inner[..., None] * 0.55
    return Image.fromarray(np.dstack([rgb, a * 255]).clip(0, 255).astype('uint8'), 'RGBA')


def save(im, name):
    im.save(os.path.join(out, name), optimize=True)


# ---- the wordmark: three slashes and the name, as on the taskbar
font = ImageFont.truetype(BARLOW, 76)
name = spaced('MAGNETIC 88', font, 22)
h = name.height
sl_w, gap = int(h * 0.52), int(h * 0.30)
slashes = Image.new('L', (3 * sl_w + 2 * gap + int(h * 0.5), h), 0)
d = ImageDraw.Draw(slashes)
for i in range(3):
    x = i * (sl_w + gap)
    d.polygon([(x + h * 0.5, 0), (x + h * 0.5 + sl_w * 0.62, 0), (x + sl_w * 0.62, h), (x, h)], fill=255)
mark = Image.new('L', (slashes.width + 46 + name.width, h), 0)
mark.paste(slashes, (0, 0))
mark.paste(name, (slashes.width + 46, 0))
mark = mark.resize((mark.width * 2, mark.height * 2), Image.LANCZOS).resize(mark.size, Image.LANCZOS)
head = Image.new('RGBA', mark.size, CREAM + (0,))
head.putalpha(mark)
save(head, 'heading.png')

# ---- the chrome line under it: bright in the middle, fading to its ends,
# a light edge over a darker one (as the rims)
RW, RH = 760, 4
x = np.linspace(-1, 1, RW)
fade = np.clip(1 - np.abs(x) ** 3, 0, 1)
rows = [(250, 248, 242), (196, 192, 184), (120, 116, 110), (70, 66, 62)]
rule = np.zeros((RH, RW, 4), np.float32)
for y in range(RH):
    rule[y, :, :3] = rows[y]
    rule[y, :, 3] = 255 * fade * (1.0 if y < 2 else 0.8)
save(Image.fromarray(rule.clip(0, 255).astype('uint8'), 'RGBA'), 'rule.png')

# ---- the LEDs: one lit, one unlit (the light sweeps along a row of them)
SW, SH = 34, 12
seg = Image.new('L', (SW, SH), 0)
ImageDraw.Draw(seg).rounded_rectangle([0, 0, SW - 1, SH - 1], 3, fill=255)
save(glow(seg, (255, 160, 40), AMBER_HOT, 7, 1.5, pad=16), 'led-on.png')
off = Image.new('RGBA', (SW + 32, SH + 32), (0, 0, 0, 0))
off.paste(Image.new('RGBA', (SW, SH), AMBER_OFF + (255,)), (16, 16), seg)
save(off, 'led-off.png')

# ---- what is happening, in the deck's amber lettering
vt = ImageFont.truetype(VT, 54)
for which, text in [('boot', 'STARTING UP'), ('shutdown', 'SHUTTING DOWN'),
                    ('reboot', 'RESTARTING'), ('updates', 'INSTALLING UPDATES')]:
    save(glow(spaced(text, vt, 8), AMBER, AMBER_HOT, 6, 0.8, pad=18), f'line-{which}.png')
save(glow(spaced('PASSPHRASE', vt, 8), AMBER, AMBER_HOT, 6, 0.8, pad=18), 'prompt.png')
bullet = Image.new('L', (16, 16), 0)
ImageDraw.Draw(bullet).rectangle([0, 0, 15, 15], fill=255)
save(glow(bullet, AMBER, AMBER_HOT, 4, 0.8, pad=10), 'bullet.png')
print('splash pictures in', out)
