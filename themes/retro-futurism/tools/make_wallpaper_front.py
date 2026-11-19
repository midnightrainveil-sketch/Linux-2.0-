#!/usr/bin/env python3
# The wallpaper with the window's glass see-through, her kept in front with a
# soft, colour-clean edge, and the reflected ceiling lights kept on the glass.
#   python3 tools/make_wallpaper_front.py art/Retro-Futuristic-Wallpaper.png \
#       home/.local/share/ultra/retro-futurism/wallpaper-front.png check.png
# A soft, clean edge for her against the glass: for each pixel near her
# outline, how much of it is her (alpha) and what colour she is there, with
# the old view behind her taken back out.
import sys
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
from collections import deque
src, outFront, outCheck = sys.argv[1:4]   # front (with the reflections), a check picture
im = Image.open(src).convert('RGB'); full = np.asarray(im).astype(float)
# her mole, a little clearer (as on the lock screen): a soft dark-brown dot
def mole(img, cx, cy, r=2.1, strength=0.85, colour=(82, 40, 27)):
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    a = np.clip((r + 0.8 - np.hypot(xx - cx, yy - cy)) / 1.6, 0, 1) * strength
    img[:] = img * (1 - a[..., None]) + np.array(colour, float) * a[..., None]
mole(full, 1136.4, 161.2)
X0, Y0, X1, Y1 = 560, 0, 1440, 440                 # the window, and a margin
I = full[Y0:Y1, X0:X1]; H, W, _ = I.shape
R, G, B = I[..., 0], I[..., 1], I[..., 2]
lum = 0.3 * R + 0.59 * G + 0.11 * B
yy, xx = np.mgrid[0:H, 0:W]

# ---- the glass and her, as before (a hard mask to start from)
gm = Image.new('L', (W, H), 0)
ImageDraw.Draw(gm).rounded_rectangle([592 - X0, -40, 1400 - X0, 403], 34, fill=255)
glass = np.asarray(gm) > 127
body = Image.new('L', (W, H), 0)
ImageDraw.Draw(body).polygon([(x + 540 - X0, y) for x, y in [(465, 125), (495, 35), (610, 30), (705, 110),
    (725, 265), (690, 325), (900, 320), (900, 445), (430, 445), (465, 375), (460, 200)]], fill=255)
body = np.asarray(body) > 127
warm = (R - B) > 4
region = glass & warm & ((lum < 105) | body)
girl = np.zeros((H, W), bool); sx, sy = 1150 - X0, 230
q = deque([(sx, sy)]); girl[sy, sx] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
        if 0 <= nx < W and 0 <= ny < H and region[ny, nx] and not girl[ny, nx]:
            girl[ny, nx] = True; q.append((nx, ny))
girl = np.asarray(Image.fromarray((girl*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))) > 127

def grow(m, n):  return np.asarray(Image.fromarray((m*255).astype('uint8')).filter(ImageFilter.MaxFilter(n))) > 127
def shrink(m, n): return np.asarray(Image.fromarray((m*255).astype('uint8')).filter(ImageFilter.MinFilter(n))) > 127
def blur(a, s):
    r = int(3 * s); k = np.exp(-np.arange(-r, r + 1)**2 / (2 * s * s)); k /= k.sum()
    a = np.apply_along_axis(lambda v: np.convolve(v, k, 'same'), 0, a)
    return np.apply_along_axis(lambda v: np.convolve(v, k, 'same'), 1, a)
def local_mean(img, m, s):            # average colour of the masked pixels nearby
    w = blur(m.astype(float), s)
    return np.dstack([blur(img[..., c] * m, s) for c in range(3)]) / np.maximum(w, 1e-4)[..., None], w

# ---- the three zones: surely her, surely glass, and the edge between
inGlass = glass & ~shrink(glass, 5)                 # (the frame's own edge is not hers)
fg = shrink(girl, 5) | (girl & ~glass)
bg = glass & ~grow(girl, 7)
edge = ~fg & ~bg & glass
Fc, _ = local_mean(I, fg, 3.0)                      # her colour nearby
Bc, _ = local_mean(I, bg, 5.0)                      # the old view's colour nearby

# alpha: where the pixel lies between the view's colour and hers
d = Fc - Bc
alpha = ((I - Bc) * d).sum(2) / np.maximum((d * d).sum(2), 40.0)
alpha = np.clip(alpha, 0, 1)
alpha = np.where(fg, 1.0, np.where(bg, 0.0, alpha))
alpha = np.where(glass, alpha, 1.0)
# a breath of smoothing along the edge only, against stair steps
sm = blur(alpha, 0.7)
alpha = np.where(edge, sm, alpha)

# ---- small islands that are not her (lights, bits of cloud): out
solid = (alpha > 0.5) & glass
lab = np.zeros((H, W), int); n = 0; sizes = [0]
for y0 in range(H):
    for x0 in np.nonzero(solid[y0] & (lab[y0] == 0))[0]:
        n += 1; sizes.append(0); q = deque([(x0, y0)]); lab[y0, x0] = n
        while q:
            x, y = q.popleft(); sizes[n] += 1
            for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                if 0 <= nx < W and 0 <= ny < H and solid[ny, nx] and lab[ny, nx] == 0:
                    lab[ny, nx] = n; q.append((nx, ny))
big = int(np.argmax(sizes))
islands = (lab > 0) & (lab != big)
small = np.isin(lab, [i for i in range(1, n + 1) if i != big and sizes[i] < 60])
around = grow(small, 5) & glass & ~grow(lab == big, 3)
alpha = np.where(around, 0.0, alpha)

# ---- her colour on the edge, with the old view taken back out
a3 = alpha[..., None]
F = (I - (1 - a3) * Bc) / np.maximum(a3, 0.08)
F = np.where(a3 < 0.15, Fc, F)                      # faint wisps: her nearby colour
F = np.clip(F, 0, 255)
col = np.where((edge & glass)[..., None], F, I)

# ---- the ceiling lights reflected in the glass: kept, over the view
refl = glass & (alpha < 0.5) & (lum > 165) & ((R - B) > 40)
ra = blur(grow(refl, 3).astype(float), 1.2) * 0.85
ra = np.where(glass & (alpha < 0.5), ra, 0.0)
col = col * (alpha / np.maximum(alpha + ra * (1 - alpha), 1e-4))[..., None] + \
      I * (ra * (1 - alpha) / np.maximum(alpha + ra * (1 - alpha), 1e-4))[..., None]
alpha = alpha + ra * (1 - alpha)
a3 = alpha[..., None]

out = full.copy(); A = np.ones(full.shape[:2])
out[Y0:Y1, X0:X1] = col; A[Y0:Y1, X0:X1] = alpha
Image.fromarray(np.dstack([out, A * 255]).astype('uint8'), 'RGBA').save(outFront)
chk = out[Y0:Y1, X0:X1] * a3 + np.array([255, 150, 70]) * (1 - a3)
Image.fromarray(chk.astype('uint8')).save(outCheck)
print('islands removed', int(small.sum()), 'edge px', int(edge.sum()))
