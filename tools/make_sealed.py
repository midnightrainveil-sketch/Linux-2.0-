#!/usr/bin/env python3
"""The lock screen's seal with its ribbon, as one picture.

    python3 tools/make_sealed.py

Two tails of silk ribbon run out from under the wax seal
(assets/seal/seal.png) and down, each lying in a soft ripple, cut in a V
with a few loose threads, a sheen along its length, the fine lengthways weave and a
soft shadow on the paper. The seal is laid over them, and the whole is one
picture (assets/seal/sealed.png), so when the seal is broken (WaxSeal.qml)
every fragment carries its own piece of wax and ribbon together.

Drawn on a 240 x 240 unit square (the seal's centre at 120, 120; its wax
58 units across the radius), at 4 px a unit. Requires: numpy, pillow.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "dotfiles", ".config", "quickshell", "assets", "seal")
U = 4                       # pixels a unit
SIZE = 240
SS = 2                      # drawn at twice that, then reduced: smooth edges
PX = U * SS
SILK = np.array([0x34, 0x40, 0x5e], np.float32)     # the theme's ink blue (Theme.accent)
BACKSIDE = SILK * 0.62


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def tail(side, rnd):
    """One tail: its centre line, half-width, twist and the V cut, as
    functions of t (0 under the seal, 1 at the cut)."""
    sx, sy = 120 + side * 6, 112                 # out from under the wax
    ex, ey = 120 + side * (78 + rnd.uniform(-4, 4)), 232 + rnd.uniform(-3, 1)
    bend = side * rnd.uniform(6, 10)
    peak = rnd.uniform(0.66, 0.72)

    def centre(t):
        x = sx + (ex - sx) * t + bend * math.sin(math.pi * t) * (1 - 0.4 * t)
        y = sy + (ey - sy) * (t ** 0.92)
        return x, y

    def twist(t):
        # a soft ripple in the silk, as it lies on the paper
        return math.pi * 0.3 * math.exp(-((t - peak) / 0.16) ** 2)

    return centre, twist


def draw_ribbon():
    W = SIZE * PX
    img = np.zeros((W, W, 4), np.float32)
    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    rnd = random.Random(1907)
    half = 12.5                                   # half the ribbon's width, in units
    steps_t, steps_u = 420, 46
    for side in (-1, 1):
        centre, twist = tail(side, rnd)
        sheen_phase = rnd.uniform(0, 6)
        for i in range(steps_t):
            t0, t1 = i / steps_t, (i + 1) / steps_t
            (x0, y0), (x1, y1) = centre(t0), centre(t1)
            dx, dy = x1 - x0, y1 - y0
            L = math.hypot(dx, dy) or 1
            nx, ny = -dy / L, dx / L
            th = twist((t0 + t1) / 2)
            c = math.cos(th)
            wv = half * max(0.3, abs(c))         # foreshortened as it turns
            front = c >= 0
            for j in range(steps_u):
                u0, u1 = -1 + 2 * j / steps_u, -1 + 2 * (j + 1) / steps_u
                um = (u0 + u1) / 2
                # the V cut: the middle of the end cut back into the ribbon
                if t1 > 1 - 0.085 * (1 - abs(um)):
                    continue
                # light: the silk curls a little across its width, the sheen
                # runs along it and wanders, the far side dull and dark
                curl = 1 - 0.35 * um * um
                if front:
                    sheen = 0.55 * math.exp(-((um - 0.35 * math.sin(6 * t0 + sheen_phase)) / 0.22) ** 2)
                    lum = (0.62 + 0.38 * c) * curl + sheen * c
                    base = SILK
                else:
                    lum = (0.55 + 0.25 * -c) * curl
                    base = BACKSIDE
                # the fold's crease catches the light where it turns
                crease = 0.0
                lum += crease
                weave = 1 + 0.05 * math.sin(um * 78) + 0.03 * math.sin(um * 191 + t0 * 40)
                edge = 0.82 if abs(um) > 0.9 else 1.0          # the selvage, a touch darker
                col = np.clip(base * lum * weave * edge + 255 * 0.06 * crease, 0, 255)
                pts = []
                for (tt, uu) in ((t0, u0), (t1, u0), (t1, u1), (t0, u1)):
                    (cx, cy) = centre(tt)
                    ww = half * max(0.3, abs(math.cos(twist(tt))))
                    pts.append(((cx + nx * uu * ww) * PX, (cy + ny * uu * ww) * PX))
                d.polygon(pts, fill=tuple(int(v) for v in col) + (255,))
        # a few loose threads at the cut
        for k in range(5):
            um = rnd.uniform(-0.8, 0.8)
            tt = 1 - 0.085 * (1 - abs(um))
            (cx, cy) = centre(tt)
            (px, py) = centre(tt - 0.01)
            ang = math.atan2(cy - py, cx - px) + rnd.uniform(-0.5, 0.5)
            ln = rnd.uniform(2.0, 4.5)
            x0, y0 = cx + (-(cy - py)) * 0 + um * half * 0.95 * (-(cy - py)) / (math.hypot(cx - px, cy - py) or 1), cy + um * half * 0.95 * (cx - px) / (math.hypot(cx - px, cy - py) or 1)
            d.line([(x0 * PX, y0 * PX), ((x0 + math.cos(ang) * ln) * PX, (y0 + math.sin(ang) * ln) * PX)],
                   fill=tuple(int(v) for v in SILK * 0.9) + (220,), width=max(1, int(0.35 * PX)))
    return canvas


def main():
    seal = Image.open(os.path.join(ASSETS, "seal.png")).convert("RGBA")
    ribbon = draw_ribbon()
    W = SIZE * PX
    # the ribbon's shadow on the paper
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    a = ribbon.split()[3].filter(ImageFilter.GaussianBlur(2.2 * PX)).point(lambda v: int(v * 0.32))
    shadow.paste((20, 14, 12, 255), (int(1.6 * PX), int(3.0 * PX)), a)
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(ribbon)
    # the seal over it: its square is 2.6 x the wax's radius (WaxSeal.qml)
    S = int(58 * 2.6 * PX)
    big = seal.resize((S, S), Image.LANCZOS)
    out.alpha_composite(big, ((W - S) // 2, (W - S) // 2))
    out = out.resize((SIZE * U, SIZE * U), Image.LANCZOS)
    path = os.path.join(ASSETS, "sealed.png")
    out.save(path, optimize=True)
    print("sealed:", os.path.normpath(path), out.size)


if __name__ == "__main__":
    main()
