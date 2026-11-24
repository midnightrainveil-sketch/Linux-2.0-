#!/usr/bin/env python3
"""The taskbar's cartridge port, its bezel made polished chrome: drawn here
(a rounded chrome lip round the dark mouth, two domed screws) and laid over
the bar's own picture by modules/Taskbar.qml.

    python3 tools/make_port_chrome.py home/.config/quickshell/assets/taskbar

Writes port-chrome.png: the bezel, 4x, for the left end's pixels 82,36 to
220,77 (left.png's own scale: the bar's 780 x 128 left end).
(pip: numpy pillow opencv-python-headless)
"""
import os, sys
import numpy as np, cv2
from PIL import Image, ImageDraw

out = sys.argv[1]
K = 4                                         # drawn at 4x
X0, Y0, X1, Y1 = 82, 36, 220, 77              # the sprite, in left.png px
OUTER = (83.5, 37.0, 218.5, 75.5, 5.5)        # the bezel's outer edge (x0 y0 x1 y1 r)
INNER = (94.0, 41.2, 208.0, 69.6, 2.5)        # the mouth
SCREWS = [(89.0, 56.0), (213.0, 56.0)]

W, H = (X1 - X0) * K, (Y1 - Y0) * K


def rr(box):
    x0, y0, x1, y1, r = box
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([(x0 - X0) * K, (y0 - Y0) * K, (x1 - X0) * K, (y1 - Y0) * K], r * K, fill=255)
    return np.asarray(m) > 127


ring = rr(OUTER) & ~rr(INNER)
# a rounded profile across the ring: from its distance to either edge
d_out = cv2.distanceTransform((~rr(OUTER)).astype(np.uint8) ^ 1, cv2.DIST_L2, 5)
d_in = cv2.distanceTransform(rr(INNER).astype(np.uint8) ^ 1, cv2.DIST_L2, 5)
d_out = cv2.distanceTransform(rr(OUTER).astype(np.uint8), cv2.DIST_L2, 5)
d_in = cv2.distanceTransform((~rr(INNER)).astype(np.uint8), cv2.DIST_L2, 5)
t = np.clip(d_out / np.maximum(d_out + d_in, 1e-3), 0, 1)            # 0 at the outer edge, 1 at the mouth
h = np.sin(np.pi * t)                                                   # its height: a rounded lip
h = cv2.GaussianBlur(h.astype(np.float32), (0, 0), 1.2)
gy, gx = np.gradient(h * 9.0)
l = np.sqrt(gx * gx + gy * gy + 1)
nx, ny = -gx / l, -gy / l                                               # ny < 0: facing up

# polished chrome mirrors a room: the sky above (bright), a dark horizon,
# a lighter floor; its upturned faces the sky, its lower ones the floor
e = 0.5 - 0.95 * ny
env = np.interp(e, [0, 0.22, 0.4, 0.47, 0.53, 0.62, 0.8, 1.0], [0.5, 0.68, 0.86, 0.46, 0.74, 0.97, 1.0, 1.0])
v = env * (0.92 - 0.12 * nx)
light = np.array([-0.45, -0.75, 0.9]); light /= np.linalg.norm(light)
lam = np.clip(nx * light[0] + ny * light[1] + (1 / l) * light[2], 0, 1)
v += 0.5 * np.clip((lam - 0.94) / 0.06, 0, 1) ** 1.4                    # glints
rgb = np.clip(v, 0, 1.08)[..., None] * np.array([246, 243, 236])
# a fine dark line at both edges (where it meets the plate, and the mouth)
edge = np.clip(1 - np.minimum(d_out, d_in) / (0.9 * K), 0, 1)[..., None]
rgb = rgb * (1 - 0.6 * edge) + np.array([60, 57, 52]) * 0.6 * edge

# the screws: chrome domes with a slot
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
alpha = ring.astype(np.float32)
for sx, sy in SCREWS:
    cx, cy, R = (sx - X0) * K, (sy - Y0) * K, 2.6 * K
    r = np.hypot(xx - cx, yy - cy)
    inside = r < R
    dome = np.sqrt(np.clip(1 - (r / R) ** 2, 0, 1))
    sv = 0.45 + 0.55 * np.clip(1 - np.hypot(xx - cx + R * 0.35, yy - cy + R * 0.4) / (R * 1.1), 0, 1) ** 1.3
    sc = (sv * (0.7 + 0.3 * dome))[..., None] * np.array([240, 238, 232])
    sc = sc * (1 - 0.5 * np.clip((r - R + 0.8 * K) / (0.8 * K), 0, 1))[..., None]
    rgb = np.where(inside[..., None], sc, rgb)
    slot = inside & (np.abs((xx - cx) * 0.7 - (yy - cy) * 0.7) < 0.35 * K) & (r < R * 0.75)
    rgb = np.where(slot[..., None], np.array([70, 66, 60]), rgb)
    alpha = np.maximum(alpha, np.clip(R + 0.5 - r, 0, 1))

rgba = np.dstack([rgb, cv2.GaussianBlur(alpha, (0, 0), 0.6) * 255]).clip(0, 255).astype('uint8')
Image.fromarray(rgba, 'RGBA').save(os.path.join(out, 'port-chrome.png'), optimize=True)
print('port-chrome.png', W, H)
