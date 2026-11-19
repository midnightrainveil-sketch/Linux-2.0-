#!/usr/bin/env python3
# python3 tools/make_window_loop.py art/WindowView.png window-view.jpg 420
# Make the panorama loop: level the viaduct, then join the right end to
# the left along the cut where they look most alike.
import sys
from PIL import Image
import numpy as np
src, out, O = sys.argv[1], sys.argv[2], int(sys.argv[3])
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
Image.fromarray(np.clip(loop, 0, 255).astype('uint8')).save(out)
print('loop width', loop.shape[1], 'height', loop.shape[0], 'seam x range', seam.min(), seam.max())
