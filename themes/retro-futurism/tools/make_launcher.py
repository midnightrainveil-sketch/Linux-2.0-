#!/usr/bin/env python3
"""The app launcher's pictures, from the mock-up (art/AppLauncherEmpty.png:
the Kairo cartridge launcher with its bays empty and its screen blank).

    python3 tools/make_launcher.py art/AppLauncherEmpty.png home/.config/quickshell/widgets/launcher

Makes, in the widget's folder:
    body.png     the launcher off its white ground (no shadow); its maker's
                 name made KAIRO (on the top plate, and in the footer)
    body.png     (without the slot's lower bracket: what it leaves behind)
    bracket.png  the slot's lower bracket (from 596, 396), its window open
                 for the cartridge's contacts: it carries the cartridge down
    rod-left.png, rod-right.png   a slice of each rod, to stretch
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
# ---- the lifter: its lower bracket, which travels (with the cartridge in
# the slot) down to the taskbar's port and back, and a slice of each rod,
# stretched as the rods run out after it. The bracket (its side posts, its
# upper blocks, its bar and grille: 598-987 x 398-542) is told from what is
# behind it by its light colour; its window (690-895 x 398-458) left open.
BX0, BY0, BX1, BY1 = 596, 396, 990, 545
part = src0[BY0:BY1, BX0:BX1]
lum = part.mean(2)
# what is dark and reaches the box's edge is behind it; the dark inside it
# (its red mark, its grille's slots, its screws) is its own
dark = lum <= 118
hh, ww = dark.shape
out_ = np.zeros_like(dark)
q = deque([(x, y) for x in range(ww) for y in (0, hh - 1) if dark[y, x]] + [(x, y) for y in range(hh) for x in (0, ww - 1) if dark[y, x]])
for x, y in q: out_[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < ww and 0 <= ny < hh and dark[ny, nx] and not out_[ny, nx]:
            out_[ny, nx] = True; q.append((nx, ny))
m = Image.fromarray(((~out_) * 255).astype('uint8')).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
d = ImageDraw.Draw(m)
d.rounded_rectangle([690 - BX0, 398 - BY0, 895 - BX0, 458 - BY0], 6, fill=0)
# (the rail's end caps just at the box's lower corners are not the bracket's)
d.rectangle([0, 125, 27, hh], fill=0); d.rectangle([ww - 27, 125, ww, hh], fill=0)
m = np.asarray(m.filter(ImageFilter.GaussianBlur(0.7))).astype(float)
Image.fromarray(np.dstack([part, m]).astype('uint8'), 'RGBA').save(os.path.join(out, 'bracket.png'), optimize=True)
def strip(x0, x1):
    return np.dstack([src0[200:260, x0:x1], np.full((60, x1 - x0), 255.0)]).astype('uint8')
Image.fromarray(strip(627, 662), 'RGBA').save(os.path.join(out, 'rod-left.png'), optimize=True)
Image.fromarray(strip(920, 956), 'RGBA').save(os.path.join(out, 'rod-right.png'), optimize=True)

# the body without the bracket (what it leaves when it goes down): each row
# carried across from the frame either side of it
x0, x1 = 594, 992
for y in range(394, 548):
    l, r = img[y, x0 - 2:x0].mean(0), img[y, x1:x1 + 2].mean(0)
    t = np.linspace(0, 1, x1 - x0 + 2)[1:-1][:, None]
    img[y, x0:x1] = l * (1 - t) + r * t + rng.normal(0, 1.4, (x1 - x0, 1))
img = np.clip(img, 0, 255)
body = np.dstack([np.where(bg[..., None], 0, img), alpha * 255])
Image.fromarray(body[Y0:Y1, X0:X1].astype('uint8'), 'RGBA').save(os.path.join(out, 'body.png'), optimize=True)
print('ORIGIN', (X0, Y0), 'size', (X1 - X0, Y1 - Y0), 'bracket at', (BX0, BY0))
