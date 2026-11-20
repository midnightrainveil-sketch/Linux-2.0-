#!/usr/bin/env python3
# python3 tools/make_window_loop.py art/WindowView.png window-view.jpg 420 140
# Make the panorama loop: level the viaduct, then join the right end to
# the left along the cut where they look most alike; then (the last number)
# that many rows more of sky on top, for the wallpaper's tall window: the
# evening sky going on up, a little deeper, its colour along the loop
# carried on (and still a loop).
import sys
from PIL import Image
import numpy as np
src, out, O = sys.argv[1], sys.argv[2], int(sys.argv[3])
SKY = int(sys.argv[4]) if len(sys.argv) > 4 else 0
p = np.asarray(Image.open(src).convert('RGB')).astype(float)
H, W, _ = p.shape
# 1. level: each column moved so the deck's top is at y 408
x = np.arange(W)
deck = 385 + (x - 200) * (47 / 1500)
shift = deck - 408                                  # >0: move the column up
lev = np.empty_like(p)
ys = np.arange(H)
for i in range(W):
    sy = np.clip(ys + shift[i], 0, H - 1)
    y0 = np.floor(sy).astype(int); y1 = np.minimum(y0 + 1, H - 1); f = (sy - y0)[:, None]
    lev[:, i] = p[y0, i] * (1 - f) + p[y1, i] * f
top, bot = 32, H - 32                               # rows left whole after the move
lev = lev[top:bot]; H2 = lev.shape[0]
# 2. the overlap: the last O columns over the first O
A = lev[:, W - O:]                                  # end
B = lev[:, :O]                                      # start
cost = np.sqrt(((A - B) ** 2).sum(2))
# smooth a little, so the cut follows shapes rather than noise
k = np.ones(5) / 5
cost = np.apply_along_axis(lambda r: np.convolve(r, k, 'same'), 1, cost)
# keep the cut away from the overlap's own edges
edge = np.minimum(np.arange(O), O - 1 - np.arange(O))
cost += np.where(edge < 30, (30 - edge) * 8.0, 0)[None, :]
# cheapest top-to-bottom path, one column step a row at most
acc = cost.copy(); back = np.zeros_like(cost, dtype=int)
for y in range(1, H2):
    prev = acc[y - 1]
    l = np.r_[np.inf, prev[:-1]]; r = np.r_[prev[1:], np.inf]
    st = np.stack([l, prev, r]); j = st.argmin(0)
    acc[y] += st[j, np.arange(O)]; back[y] = j - 1
seam = np.zeros(H2, int); seam[-1] = acc[-1].argmin()
for y in range(H2 - 1, 0, -1): seam[y - 1] = seam[y] + back[y, seam[y]]
# blend: the end's pixels left of the cut, the start's right of it, a soft few px
cols = np.arange(O)[None, :]
t = np.clip((cols - seam[:, None]) / 6 + 0.5, 0, 1)[..., None]
mix = A * (1 - t) + B * t
# the loop: start's columns after the overlap, then the end up to the overlap, then the blend
loop = np.concatenate([lev[:, O:W - O], mix], axis=1)
# (the blend's right side is the start's columns 0..O, which follow lev[:, O] seamlessly)
if SKY > 0:
    def blur_x(a, sig):                         # along the loop, round its ends
        r = int(3 * sig); k = np.exp(-np.arange(-r, r + 1) ** 2 / (2 * sig * sig)); k /= k.sum()
        pad = np.concatenate([a[:, -r:], a, a[:, :r]], axis=1)
        return np.stack([np.apply_along_axis(lambda v: np.convolve(v, k, 'valid'), 1, pad[..., c])
                         for c in range(3)], -1)
    band = loop[:24]
    base = blur_x(band.mean(0, keepdims=True), 90)[0]          # the sky's colour along the loop, smooth
    deep = np.array([52.0, 58.0, 84.0])                        # higher up: a deeper evening blue
    t = (np.arange(SKY)[::-1] / SKY)[:, None, None]            # 1 at the top, 0 next to the old sky
    sky = base[None] * (1 - 0.45 * t ** 1.3) + deep[None, None] * (0.45 * t ** 1.3)
    # the old sky's own grain, and next to it the old sky mirrored, fading out
    rng = np.random.default_rng(88)
    hp = band - blur_x(band, 3)
    sky += rng.normal(0, float(hp.std()) * 0.8, sky.shape[:2])[..., None]
    m = min(28, SKY)
    w = np.linspace(1, 0, m)[:, None, None] ** 1.5
    sky[SKY - m:] = sky[SKY - m:] * (1 - w[::-1]) + loop[:m][::-1] * w[::-1]
    loop = np.concatenate([sky, loop], axis=0)
Image.fromarray(np.clip(loop, 0, 255).astype('uint8')).save(out, quality=92)
print('loop width', loop.shape[1], 'height', loop.shape[0], 'seam x range', seam.min(), seam.max())
