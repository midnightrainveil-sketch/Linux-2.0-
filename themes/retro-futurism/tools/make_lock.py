#!/usr/bin/env python3
# The lock screen's pictures: the platform with her waiting (lock.jpg), the
# same platform once she has boarded (lock-boarded.jpg: the lock fades to it
# as you are let in), and the glows the shell lays on it (lock/: the
# signal's green and red, the train's headlights).
#   python3 tools/make_lock.py art home/.local/share/ultra/retro-futurism
# (pip: numpy pillow)
import os, sys
import numpy as np
from PIL import Image

art, out = sys.argv[1:3]
os.makedirs(os.path.join(out, 'lock'), exist_ok=True)
for src, dst in (('Lock-Platform.webp', 'lock.jpg'), ('Lock-Platform-Empty.webp', 'lock-boarded.jpg')):
    Image.open(os.path.join(art, src)).convert('RGB').save(os.path.join(out, dst), quality=95, subsampling=0)


def glow(name, rgb, core=0.16, size=128):
    """a light: a bright core, a soft halo falling away round it"""
    yy, xx = np.mgrid[0:size, 0:size] + 0.5
    r = np.hypot(xx - size / 2, yy - size / 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** 2.2 * 0.75 + np.clip((core - r) / core, 0, 1) * 0.6
    a = np.clip(a, 0, 1)
    # the core whiter than the halo
    w = np.clip((core * 1.4 - r) / (core * 1.4), 0, 1)[..., None]
    col = np.array(rgb, float) * (1 - w) + np.array([255, 250, 235.0]) * w
    Image.fromarray(np.dstack([col, a * 255]).round().astype('uint8'), 'RGBA').save(os.path.join(out, 'lock', name))


glow('glow-green.png', (110, 235, 140))
glow('glow-red.png', (255, 80, 60))
glow('glow-warm.png', (255, 205, 140), core=0.1)
print('lock pictures and glows written')
