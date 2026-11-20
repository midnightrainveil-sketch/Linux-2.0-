#!/usr/bin/env python3
"""The window rim, cut from the taskbar itself (art/TaskbarEg.png).

    python3 tools/make_rim.py art/TaskbarEg.png home/.local/share/ultra/retro-futurism/rim

The taskbar's tube has round ends of exactly the radius the windows' rims
have (49.5 px of the mock-up: 38 at the bar's size), and its rim is as deep
(22 px: 17). So its pixels are laid round the windows as they are, not
imitated: its chrome, its glints, its dark reflections round the bends.

    corner-tl.png ... corner-br.png   a quarter of an end, and a run of the
                                      straight beyond it (its own pixels,
                                      eased into the plain straight)
    top.png, bottom.png               the plain straight (a column, outer
                                      edge at the top / at the bottom)
    left.png, right.png               the middle of an end (a row, outer
                                      edge at the left / at the right)
    bloom-top.png, bloom-bottom.png   a bright spot of the bar's, to lay
                                      here and there along a straight

Pieces are in the mock-up's pixels, transparent inside the rim's inner edge
and outside its outer one (soft, 4 x 4 samples); the chromerim plugin scales
them to the rim's width (plugin:chromerim:width) and lays them round each
window. Its inner lip is kept (the tube closes on it, as it does on the
taskbar's face); DEPTH says how far in the rim goes.
"""
import os
import sys

import numpy as np
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
art = np.asarray(Image.open(src).convert('RGB')).astype(float)

# the tube's outline in the mock-up
X0, X1 = 35.0, 2139.0          # left and right outer edges
Y0, Y1 = 320.0, 419.0          # top and bottom outer edges
R = (Y1 - Y0) / 2              # the ends' radius: 49.5
CL, CR, CY = X0 + R, X1 - R, Y0 + R
DEPTH = 22                     # the rim: 22 px of the mock-up, its lip included
N = 4 * DEPTH                  # a corner piece's side: 4 rims deep exactly, so it scales
                               # to whole pixels whenever the straights do (no step between)
RUN = N - int(np.ceil(R))      # how far a corner piece runs on along the straight
SS = 4


def px(x, y):
    """the mock-up's colour at a point (bilinear)"""
    x = np.clip(x - 0.5, 0, art.shape[1] - 1.001)
    y = np.clip(y - 0.5, 0, art.shape[0] - 1.001)
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    a = art[y0, x0] * (1 - fx) + art[y0, x0 + 1] * fx
    b = art[y0 + 1, x0] * (1 - fx) + art[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def column(x0, x1, y_of_depth):
    """a plain profile: the mean over a stretch of the straight, by depth"""
    return np.array([np.mean([px(x + 0.5, y_of_depth(d)) for x in range(x0, x1)], axis=0) for d in range(DEPTH)])


def row(y0, y1, x_of_depth):
    return np.array([np.mean([px(x_of_depth(d), y + 0.5) for y in range(y0, y1)], axis=0) for d in range(DEPTH)])


# the plain straights (the bar's middle, away from the ends' glints) and the
# middle of each end (its leftmost, rightmost point), by depth from outside
TOP = column(1060, 1141, lambda d: Y0 + d + 0.5)
BOTTOM = column(1060, 1141, lambda d: Y1 - d - 0.5)
LEFT = row(int(CY) - 3, int(CY) + 4, lambda d: X0 + d + 0.5)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def corner(right, foot):
    """a corner piece, as it lies (its outer corner at its outer corner)"""
    rgb = np.zeros((N, N, 3))
    alpha = np.zeros((N, N))
    straight = BOTTOM if foot else TOP
    side = LEFT
    cx = CR if right else CL
    for j in range(N):
        for i in range(N):
            # (i, j) from the piece's outer corner, inwards
            cov = 0
            for sj in range(SS):
                for si in range(SS):
                    u, v = i + (si + 0.5) / SS, j + (sj + 0.5) / SS
                    if u < R and v < R:
                        d = R - np.hypot(R - u, R - v)
                    elif v < R:
                        d = v
                    elif u < R:
                        d = u
                    else:
                        continue
                    cov += 0 <= d < DEPTH
            if cov == 0:
                continue
            alpha[j, i] = cov / SS / SS
            u, v = i + 0.5, j + 0.5
            mx = X1 - u if right else X0 + u          # the mock-up point
            my = Y1 - v if foot else Y0 + v
            if u < R and v < R:
                rgb[j, i] = px(mx, my)
            elif v < R:
                # along the straight: the end's own pixels, easing into the plain straight
                w = smooth((u - R) / RUN)
                rgb[j, i] = px(mx, my) * (1 - w) + straight[min(DEPTH - 1, int(v))] * w
            else:
                rgb[j, i] = side[min(DEPTH - 1, int(u))]
    img = np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype('uint8')
    if right:
        img = img[:, ::-1]
    if foot:
        img = img[::-1]
    return Image.fromarray(img, 'RGBA')


def strip(profile, vertical, flip):
    p = profile[::-1] if flip else profile
    a = np.concatenate([np.clip(p, 0, 255), np.full((DEPTH, 1), 255.0)], axis=1).astype('uint8')
    img = a.reshape(DEPTH, 1, 4) if vertical else a.reshape(1, DEPTH, 4)
    return Image.fromarray(img, 'RGBA')


# (the right-hand pieces are the left end's, mirrored: the bar's right end
# has an orange accent on its face that reaches into the rim's lip)
tl, bl = corner(False, False), corner(False, True)
tl.save(os.path.join(out, 'corner-tl.png'))
tl.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(out, 'corner-tr.png'))
bl.save(os.path.join(out, 'corner-bl.png'))
bl.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(out, 'corner-br.png'))
strip(TOP, True, False).save(os.path.join(out, 'top.png'))
strip(BOTTOM, True, True).save(os.path.join(out, 'bottom.png'))
strip(LEFT, False, False).save(os.path.join(out, 'left.png'))
strip(LEFT, False, True).save(os.path.join(out, 'right.png'))


# ---- bright spots: two of the bar's own flares, where its bright band
# blooms white and the dark reflection under it washes out (its top run at
# x 1016, its bottom run at 1017), each eased into the plain straight at both
# ends so it can be laid anywhere along a window's edge
BLOOM = 128                    # a spot's length, in the pieces' pixels
FADE = 30                      # how far each end eases into the plain straight


def bloom(cx, foot):
    rgb = np.zeros((DEPTH, BLOOM, 3))
    straight = BOTTOM if foot else TOP
    for i in range(BLOOM):
        w = min(smooth(i / FADE), smooth((BLOOM - 1 - i) / FADE))    # 0 at the ends, 1 in the middle
        x = cx - BLOOM / 2 + i + 0.5
        for d in range(DEPTH):
            y = Y1 - d - 0.5 if foot else Y0 + d + 0.5
            ww = w if d < DEPTH - 5 else 0                            # (the inner lip stays plain)
            rgb[d, i] = px(x, y) * ww + straight[d] * (1 - ww)
    if foot:
        rgb = rgb[::-1]
    img = np.dstack([np.clip(rgb, 0, 255), np.full((DEPTH, BLOOM), 255.0)]).astype('uint8')
    return Image.fromarray(img, 'RGBA')


bloom(1016, False).save(os.path.join(out, 'bloom-top.png'))
bloom(1017, True).save(os.path.join(out, 'bloom-bottom.png'))

with open(os.path.join(out, 'rim.txt'), 'w') as f:
    # what the plugin needs to scale them: the rim's depth and a corner's side, in the pieces' pixels
    f.write(f'depth {DEPTH}\ncorner {N}\nradius {R}\nbloom {BLOOM}\n')
print('rim pieces in', out, '- depth', DEPTH, 'corner', N)
