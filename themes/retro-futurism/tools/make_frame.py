#!/usr/bin/env python3
# The window frame, from the mock-up (art/WindowFrame.png): its rim cut out
# of the white (inside and outside made clear), for a BorderImage that
# stretches the sides and keeps the corners.
#   python3 tools/make_frame.py art/WindowFrame.png home/.config/quickshell/assets/frame.png
# In the result: the rim's outer edge 2 px in from the picture's edge, the
# rim 24 px wide, the corners within 56 px.
import sys
from PIL import Image, ImageDraw
import numpy as np
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
X0, Y0, X1, Y1 = 18, 18, 1568, 973
S = 4
m = Image.new('L', ((X1 - X0) * S, (Y1 - Y0) * S), 0); d = ImageDraw.Draw(m)
d.rounded_rectangle([(20 - X0) * S, (20 - Y0) * S, (1566 - X0) * S, (971 - Y0) * S], 26 * S, fill=255)
d.rounded_rectangle([(44 - X0) * S, (44.5 - Y0) * S, (1542 - X0) * S, (946.5 - Y0) * S], 12 * S, fill=0)
m = m.resize((X1 - X0, Y1 - Y0), Image.LANCZOS)
rgb = im.crop((X0, Y0, X1, Y1))
rgb.putalpha(m)
rgb.save(out, optimize=True)
print(rgb.size)
