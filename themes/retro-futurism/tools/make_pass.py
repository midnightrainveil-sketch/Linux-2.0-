#!/usr/bin/env python3
"""The access pass on the lock screen, from the mock-up (art/Login0.png, the
device with nothing on its screen; art/Login1.png shows what goes on it).

    python3 tools/make_pass.py art/Login0.png home/.config/quickshell/assets/pass.png

Lifts the device off its white: every patch of the ground, found by colour
and size, made clear; no shadow. Prints ORIGIN, where pass.png starts in the
mock-up (modules/Lock.qml places what it draws in the mock-up's pixels).
"""
import sys
from collections import deque
from PIL import Image, ImageFilter
import numpy as np

src, out = sys.argv[1], sys.argv[2]
a = np.asarray(Image.open(src).convert('RGB')).astype(float)
H, W, _ = a.shape
lum = a.mean(2); sat = a.max(2) - a.min(2)
ground = (lum > 238) & (sat < 10)
bg = np.zeros((H, W), bool)
q = deque([(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)])
for x, y in q: bg[y, x] = True
while q:
    x, y = q.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if 0 <= nx < W and 0 <= ny < H and ground[ny, nx] and not bg[ny, nx]:
            bg[ny, nx] = True; q.append((nx, ny))
# the ground's faint grey just at the device's foot (a shadow) goes too
near = np.asarray(Image.fromarray((bg * 255).astype('uint8')).filter(ImageFilter.MaxFilter(9))) > 0
bg |= near & (lum > 225) & (sat < 10)
edge = ~bg & (np.asarray(Image.fromarray((bg * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0)
alpha = np.where(bg, 0.0, 1.0)
alpha = np.where(edge, np.clip((255 - lum) / 60, 0.3, 1), alpha)
ys, xs = np.nonzero(alpha > 0.02)
X0, Y0, X1, Y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
rgb = np.where(bg[..., None], 0, a)
Image.fromarray(np.dstack([rgb, alpha * 255])[Y0:Y1, X0:X1].astype('uint8'), 'RGBA').save(out, optimize=True)
print('ORIGIN', (int(X0), int(Y0)), 'size', (int(X1 - X0), int(Y1 - Y0)))
