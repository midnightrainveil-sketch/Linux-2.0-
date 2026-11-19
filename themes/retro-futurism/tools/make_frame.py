#!/usr/bin/env python3
# The window frame, from the mock-up (art/WindowFrame.png): its rim cut out
# of the white along its own outline, for a BorderImage that stretches the
# sides and keeps the corners. The outline was measured on the picture:
#   outer edge 20,20 to 1566,971, corners of radius 41
#   inner edge 44,45 to 1542,948, corners of radius 13
# (the rim's outer chrome lip is nearly white itself, so it is cut by shape,
# not by colour). Where the cut's soft edge still holds some white, that
# white is taken back out of the colour.
#   python3 tools/make_frame.py art/WindowFrame.png home/.config/quickshell/assets/frame.png
# In the result: the rim's outer edge 2 px in from the picture's edge, the
# rim 24 px wide, the corners within 56 px.
import sys
from PIL import Image, ImageDraw
import numpy as np
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
X0, Y0, X1, Y1 = 18, 18, 1568, 973
S = 8
m = Image.new('L', ((X1 - X0) * S, (Y1 - Y0) * S), 0); d = ImageDraw.Draw(m)
d.rounded_rectangle([(20 - X0) * S, (20 - Y0) * S, (1566 - X0) * S - 1, (971 - Y0) * S - 1], 41 * S, fill=255)
d.rounded_rectangle([(44 - X0) * S, (45 - Y0) * S, (1542 - X0) * S - 1, (948 - Y0) * S - 1], 13 * S, fill=0)
alpha = np.asarray(m.resize((X1 - X0, Y1 - Y0), Image.LANCZOS)).astype(float) / 255
a = np.asarray(im.crop((X0, Y0, X1, Y1))).astype(float)
# the soft edge blends rim and white: keep the rim's share of the colour
A = np.maximum(alpha, 1e-3)[..., None]
soft = (alpha > 0.02) & (alpha < 0.98)
rgb = np.where(soft[..., None], np.clip((a - (1 - A) * 255) / A, 0, 255), a)
Image.fromarray(np.dstack([rgb, alpha * 255]).astype('uint8'), 'RGBA').save(out, optimize=True)
