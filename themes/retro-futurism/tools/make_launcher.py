#!/usr/bin/env python3
"""The app launcher's pictures, from the mock-up (art/AppLauncherEmpty.png:
the Kairo cartridge launcher with its bays empty and its screen blank).

    python3 tools/make_launcher.py art/AppLauncherEmpty.png home/.config/quickshell/widgets/launcher

Makes, in the widget's folder:
    body.png     the launcher off its white ground (no shadow); its maker's
                 name made KAIRO (on the top plate, and in the footer)
    clamp.png    the parts of the centre slot's clamp that lie in front of
                 the cartridge in it: its two rods and its lower bracket
                 (the bracket's window left open, for the cartridge's contacts)
Both in the mock-up's own pixels, from ORIGIN (printed); widgets/launcher
places everything there.
"""
import os, sys
from collections import deque
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
src0 = np.asarray(Image.open(src).convert('RGB')).astype(float)
img = src0.copy()
H, W, _ = img.shape
rng = np.random.default_rng(5)
FONT = '/usr/share/fonts/opentype/inter/'


def blend_v(x0, y0, x1, y1, grain=1.6):
    """a box refilled column by column from the plate just above to just below"""
    top, bot = img[y0 - 1, x0:x1].copy(), img[y1, x0:x1].copy()
    t = np.linspace(0, 1, y1 - y0 + 2)[1:-1][:, None, None]
    img[y0:y1, x0:x1] = top[None] * (1 - t) + bot[None] * t + rng.normal(0, grain, (y1 - y0, x1 - x0, 1))


def letter(text, font, size, height, shear, ink, x, y, align='left', spacing=0.0):
    """lettering printed on the plate: drawn large, leant, brought down"""
    f = ImageFont.truetype(FONT + font, size * 4)
    lay = Image.new('L', (len(text) * size * 5, size * 7), 0)
    d = ImageDraw.Draw(lay)
    cx = 20
    for ch in text:
        d.text((cx, 20), ch, font=f, fill=255); cx += d.textlength(ch, font=f) + spacing * 4
    lay = lay.crop(lay.getbbox())
    if shear:
        lay = lay.transform((int(lay.width + shear * lay.height), lay.height), Image.AFFINE,
                            (1, shear, -shear * lay.height, 0, 1, 0), Image.BICUBIC)
    lay = lay.resize((round(lay.width * height / lay.height), height), Image.LANCZOS)
    a = np.asarray(lay).astype(float)[..., None] / 255 * 0.93
    if align == 'right':
        x -= lay.width
    reg = img[y:y + height, x:x + lay.width]
    reg[:] = reg * (1 - a) + np.array(ink) * a


# ---- KASETTO -> KAIRO
blend_v(198, 84, 359, 118)
letter('KAIRO', 'Inter-ExtraBold.otf', 46, 26, 0.2, (72, 66, 58), 352, 88, align='right', spacing=1.5)
blend_v(1104, 875, 1384, 901)
letter('KAIRO ELECTRONICS CO., LTD.', 'Inter-Bold.otf', 30, 15, 0, (52, 48, 42), 1108, 881, spacing=0.4)

# ---- off the white, no shadow
lum0 = src0.mean(2); sat0 = src0.max(2) - src0.min(2)
ground = (lum0 > 226) & (sat0 < 22)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for px, py in q: bg[py, px] = True
while q:
    px, py = q.popleft()
    for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
# the shadow on the ground below it: grey (not the warm cream of its metal)
foot = np.zeros((H, W), bool); foot[930:, :] = True
bg |= foot & (lum0 > 150) & (sat0 < 14)
edge = ~bg & (np.asarray(Image.fromarray((bg * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0)
alpha = np.where(bg, 0.0, 1.0)
alpha = np.where(edge, np.clip((255 - lum0) / 70, 0.35, 1), alpha)
ys, xs = np.nonzero(alpha > 0.03)
X0, Y0, X1, Y1 = int(xs.min()) - 2, int(ys.min()) - 2, int(xs.max()) + 3, int(ys.max()) + 3
body = np.dstack([np.where(bg[..., None], 0, img), alpha * 255])
Image.fromarray(body[Y0:Y1, X0:X1].astype('uint8'), 'RGBA').save(os.path.join(out, 'body.png'), optimize=True)

# ---- the clamp's front: the rods and the lower bracket, the bracket's window open
m = Image.new('L', (W * 4, H * 4), 0)
d = ImageDraw.Draw(m)
for r in ((627, 78, 662, 388), (920, 78, 956, 388)):
    d.rounded_rectangle([v * 4 for v in r], 14 * 4, fill=255)
d.rounded_rectangle([616 * 4, 366 * 4, 967 * 4, 478 * 4], 12 * 4, fill=255)
d.rounded_rectangle([686 * 4, 383 * 4, 892 * 4, 436 * 4], 6 * 4, fill=0)
m = np.asarray(m.resize((W, H), Image.LANCZOS)).astype(float) / 255 * alpha
clamp = np.dstack([img, m * 255])
Image.fromarray(clamp[Y0:Y1, X0:X1].astype('uint8'), 'RGBA').save(os.path.join(out, 'clamp.png'), optimize=True)
print('ORIGIN', (X0, Y0), 'size', (X1 - X0, Y1 - Y0))
