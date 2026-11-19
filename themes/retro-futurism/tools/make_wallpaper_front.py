#!/usr/bin/env python3
# python3 tools/make_wallpaper_front.py art/Retro-Futuristic-Wallpaper.png front.png reflections.png check.png
# (then lay reflections.png over front.png: wallpaper-front.png)
# The wallpaper with the window's glass made see-through, the girl kept in
# front of it, and the glass's reflections kept apart (a layer of their own).
import sys
from PIL import Image, ImageFilter, ImageDraw
import numpy as np
from collections import deque
src, outFront, outRefl, outCheck = sys.argv[1:5]
im = Image.open(src).convert('RGB'); a = np.asarray(im).astype(float)
H, W, _ = a.shape
R, G, B = a[..., 0], a[..., 1], a[..., 2]
lum = 0.3 * R + 0.59 * G + 0.11 * B
# the glass: a rounded rectangle inside the frame's rubber seal
gx0, gy0, gx1, gy1, rad = 592, 0, 1400, 403, 34
gm = Image.new('L', (W, H), 0)
ImageDraw.Draw(gm).rounded_rectangle([gx0, gy0 - 40, gx1, gy1], rad, fill=255)
glass = np.asarray(gm) > 127
# warm pixels: her hair, skin, headphones, coat (the view is cool); some clouds
# and lights are warm too, but they are islands apart from her
warm = (R - B) > 4
# her: the warm region joined to her face, inside the glass
seed = (1150, 230)
girl = np.zeros((H, W), bool)
q = deque([seed]); girl[seed[1], seed[0]] = True
# hair (dark and warm) may spread anywhere; the bright warm parts (face,
# headphones, coat) only near her body, so lit clouds and windows stay out
body = Image.new('L', (W, H), 0)
ox = 540
ImageDraw.Draw(body).polygon([(x + ox, y) for x, y in [(465, 125), (495, 35), (610, 30), (705, 110),
    (725, 265), (690, 325), (900, 320), (900, 445), (430, 445), (465, 375), (460, 200)]], fill=255)
body = np.asarray(body) > 127
region = glass & warm & ((lum < 105) | body)
while q:
    x, y = q.popleft()
    for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
        if 0 <= nx < W and 0 <= ny < H and region[ny, nx] and not girl[ny, nx]:
            girl[ny, nx] = True; q.append((nx, ny))
# close little holes in her (glints in the hair, lit windows seen between strands)
gi = Image.fromarray((girl * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
girl = np.asarray(gi) > 127
# soft edge for hair strands: how warm a pixel is decides how much of her it is
soft = np.clip(((R - B) + 6) / 14, 0, 1)
edge = (np.asarray(gi.filter(ImageFilter.MaxFilter(5))) > 127) & ~girl
alpha_girl = np.where(girl, 1.0, np.where(edge, soft, 0.0))
# the reflections: the ceiling lights mirrored at the top of the glass
refl = glass & ~girl & (lum > 165) & ((R - B) > 40)
ri = Image.fromarray((refl * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
ralpha = np.asarray(ri).astype(float) / 255 * 0.85
# front: everything opaque except the glass that is not her
alpha = np.where(glass, alpha_girl, 1.0)
front = np.dstack([a, alpha * 255]).astype('uint8')
Image.fromarray(front, 'RGBA').save(outFront)
rl = np.dstack([a, ralpha * 255]).astype('uint8')
Image.fromarray(rl, 'RGBA').save(outRefl)
# a check picture: the see-through part bright green
chk = a.copy(); t = (1 - alpha)[..., None]
chk = chk * (1 - t) + np.array([40, 255, 90]) * t
Image.fromarray(chk.astype('uint8')).crop((540, 0, 1440, 440)).save(outCheck)
print('girl px', int(girl.sum()), 'reflection px', int(refl.sum()))
