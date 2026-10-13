#!/usr/bin/env python3
"""Draw the starter plate: a pencil study of Geranium pratense.

    python3 tools/gen_plate.py

Writes dotfiles/.local/share/archive/plates/0001-geranium-pratense/:
  ink.png          the drawing as alpha (black + alpha; the shell inks it)
  wash.png         petal mask for the pale blue watercolour wash
  silhouette.png   filled shape for the night cyanotype photogram
  meta.json        names, specimen label, tape strips, scale marks
and updates plates/index.json.

It is procedural, so it is a stand-in, not a botanical illustration. Replace
or extend it with real public-domain plates via `archive-plate import`.
Requires: python3, numpy, pillow.
"""
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 1400, 2560          # final size (aspect matches the plate box on screen)
SS = 2                     # supersampling
OUT = os.path.join(os.path.dirname(__file__), "..", "dotfiles", ".local", "share", "archive", "plates")
PLATE_ID = "0001-geranium-pratense"

rng = random.Random(1753)
nrng = np.random.default_rng(1753)


class Sheet:
    """Accumulates pencil strokes as float ink (0..1+)."""

    def __init__(self):
        self.ink = np.zeros((H * SS, W * SS), np.float32)
        self.wash = Image.new("L", (W * SS, H * SS), 0)
        self.fill = Image.new("L", (W * SS, H * SS), 0)

    def layer(self):
        return Image.new("L", (W * SS, H * SS), 0)

    def add(self, img, strength):
        self.ink += np.asarray(img, np.float32) / 255.0 * strength


S = Sheet()


def P(x, y):
    return (x * SS, y * SS)


def jitter_path(pts, amp, step=6.0):
    """Densify and add a smooth random walk perpendicular to the path."""
    dense = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        l = math.hypot(x1 - x0, y1 - y0)
        k = max(1, int(l / step))
        for i in range(k):
            t = i / k
            dense.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
    dense.append(pts[-1])
    out, off = [], 0.0
    for i, (x, y) in enumerate(dense):
        a = dense[max(0, i - 1)]
        b = dense[min(len(dense) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1
        off = off * 0.8 + rng.uniform(-1, 1) * amp
        out.append((x - dy / l * off, y + dx / l * off))
    return out


def pencil(pts, width=2.2, passes=3, strength=0.55, amp=0.8, layer=None):
    """A pencil line: a few jittered passes, each a little different."""
    img = layer or S.layer()
    d = ImageDraw.Draw(img)
    for _ in range(passes):
        q = jitter_path(pts, amp)
        w = max(1, int(width * SS * rng.uniform(0.75, 1.15)))
        d.line([P(x, y) for x, y in q], fill=255, width=w, joint="curve")
    if layer is None:
        S.add(img, strength / passes * 2.3)
    return img


def bezier(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return out


def hatch(mask_poly, angle, spacing, strength=0.25, length=None):
    """Parallel shading strokes clipped to a polygon."""
    layer = S.layer()
    d = ImageDraw.Draw(layer)
    xs = [p[0] for p in mask_poly]
    ys = [p[1] for p in mask_poly]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    diag = math.hypot(x1 - x0, y1 - y0)
    ca, sa = math.cos(angle), math.sin(angle)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    k = -diag / 2
    while k < diag / 2:
        # a line perpendicular offset k from the centre
        px, py = cx - sa * k, cy + ca * k
        half = (length or diag) / 2 * rng.uniform(0.6, 1.0)
        a = (px - ca * half, py - sa * half)
        b = (px + ca * half, py + sa * half)
        q = jitter_path([a, b], 0.4, 10)
        d.line([P(x, y) for x, y in q], fill=255, width=max(1, int(1.1 * SS)))
        k += spacing * rng.uniform(0.8, 1.25)
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).polygon([P(x, y) for x, y in mask_poly], fill=255)
    clipped = Image.fromarray((np.asarray(layer, np.float32) * np.asarray(mask, np.float32) / 255).astype(np.uint8))
    S.add(clipped, strength)


def fill_shape(poly, wash=False):
    ImageDraw.Draw(S.fill).polygon([P(x, y) for x, y in poly], fill=255)
    if wash:
        ImageDraw.Draw(S.wash).polygon([P(x, y) for x, y in poly], fill=255)


# ---------------------------------------------------------------- organs
def stem(points, width):
    """A stem drawn as two edge lines plus faint shading along one side."""
    left, right = [], []
    for i, (x, y) in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(len(points) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l, dx / l
        w = width * (1 - 0.35 * i / len(points))
        left.append((x + nx * w / 2, y + ny * w / 2))
        right.append((x - nx * w / 2, y - ny * w / 2))
    pencil(left, 2.0, 2, 0.55, 0.5)
    pencil(right, 2.0, 2, 0.45, 0.5)
    # shading: short ticks inside the right edge
    for i in range(0, len(points) - 1, 2):
        x, y = right[i]
        lx, ly = points[i]
        pencil([(x, y), (x + (lx - x) * 0.6, y + (ly - y) * 0.6 - 3)], 1.0, 1, 0.18, 0.2)
    fill_shape(left + right[::-1])


def lobe_outline(base, angle, length, width, teeth=5):
    """One deeply cut leaf lobe, with incised teeth towards the tip."""
    ca, sa = math.cos(angle), math.sin(angle)
    left, right = [], []
    n = 26
    for i in range(n + 1):
        t = i / n
        w = width * (math.sin(math.pi * min(1, t * 1.05)) ** 0.9) * (0.35 + 0.65 * t) / 1.0
        # teeth: a sawtooth in the outer half
        if t > 0.35:
            tooth = (i % 3 == 0) * width * 0.22 * (1 - t * 0.6)
            w += tooth
        cx, cy = base[0] + ca * length * t, base[1] + sa * length * t
        left.append((cx - sa * w, cy + ca * w))
        right.append((cx + sa * w, cy - ca * w))
    tip = (base[0] + ca * length * 1.04, base[1] + sa * length * 1.04)
    return left + [tip] + right[::-1]


def leaf(base, size, angle, lobes=7, spread=2.6, shade=True):
    """Palmately divided geranium leaf, seen from above."""
    polys = []
    for k in range(lobes):
        t = k / (lobes - 1) - 0.5
        a = angle + t * spread + rng.uniform(-0.06, 0.06)
        L = size * (1 - abs(t) * 0.75) * rng.uniform(0.92, 1.05)
        poly = lobe_outline(base, a, L, size * 0.13 * (1 - abs(t) * 0.4))
        polys.append((poly, a, L))
    for poly, a, L in polys:
        pencil(poly + [poly[0]], 1.7, 2, 0.6, 0.6)
        fill_shape(poly)
        # midrib and a few side veins
        tip = (base[0] + math.cos(a) * L * 0.92, base[1] + math.sin(a) * L * 0.92)
        pencil([base, tip], 1.2, 1, 0.35, 0.4)
        for j in range(3):
            t = 0.35 + j * 0.18
            px, py = base[0] + math.cos(a) * L * t, base[1] + math.sin(a) * L * t
            for side in (-1, 1):
                b = a + side * 0.6
                pencil([(px, py), (px + math.cos(b) * L * 0.12, py + math.sin(b) * L * 0.12)], 0.9, 1, 0.22, 0.2)
        if shade:
            hatch(poly, a + 0.9, 7.5, 0.22, L * 0.35)


def petal(center, angle, r0, R, width):
    pts = []
    n = 22
    for i in range(n + 1):
        t = i / n                          # around the petal outline
        th = angle + (t - 0.5) * width
        # obovate: round end, narrow claw
        f = math.sin(math.pi * t)
        r = r0 + (R - r0) * (0.55 + 0.45 * f ** 0.6) * (0.92 + 0.08 * math.cos(6 * math.pi * t))
        if t < 0.08 or t > 0.92:
            r = r0 + (r - r0) * 0.4
        pts.append((center[0] + math.cos(th) * r, center[1] + math.sin(th) * r))
    return [center] + pts + [center]


def flower(center, R, rot=0.0, squash=1.0, tilt=0.0):
    """Five-petalled flower; squash < 1 shows it turned away from the viewer."""
    cx, cy = center

    def tf(p):
        x, y = p[0] - cx, p[1] - cy
        y *= squash
        ct, st = math.cos(tilt), math.sin(tilt)
        return (cx + x * ct - y * st, cy + x * st + y * ct)

    for k in range(5):
        a = rot + k * 2 * math.pi / 5 + rng.uniform(-0.08, 0.08)
        poly = [tf(p) for p in petal(center, a, R * 0.12, R * rng.uniform(0.92, 1.06), 1.15)]
        pencil(poly, 1.6, 2, 0.55, 0.5)
        fill_shape(poly, wash=True)
        # veins: the dark lines of a meadow cranesbill petal
        for v in (-0.22, -0.1, 0.0, 0.1, 0.22):
            p0 = tf((cx + math.cos(a + v * 0.3) * R * 0.15, cy + math.sin(a + v * 0.3) * R * 0.15))
            p1 = tf((cx + math.cos(a + v) * R * 0.78, cy + math.sin(a + v) * R * 0.78))
            pencil([p0, p1], 0.9, 1, 0.28, 0.3)
    # centre: stamens as small dots
    d = S.layer()
    dd = ImageDraw.Draw(d)
    for k in range(10):
        a = k * math.pi / 5 + rot
        x, y = tf((cx + math.cos(a) * R * 0.11, cy + math.sin(a) * R * 0.11))
        dd.ellipse([P(x - 2.4, y - 2.4), P(x + 2.4, y + 2.4)], fill=255)
    S.add(d, 0.7)


def bud(base, tip_angle, length, width):
    ca, sa = math.cos(tip_angle), math.sin(tip_angle)
    pts = []
    for i in range(25):
        t = i / 24
        w = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.3 * t)
        pts.append((base[0] + ca * length * t - sa * w, base[1] + sa * length * t + ca * w))
    for i in range(24, -1, -1):
        t = i / 24
        w = width * math.sin(math.pi * t) ** 0.8 * (1 - 0.3 * t)
        pts.append((base[0] + ca * length * t + sa * w, base[1] + sa * length * t - ca * w))
    pencil(pts, 1.5, 2, 0.55, 0.4)
    fill_shape(pts)
    # sepal lines
    for v in (-0.5, 0, 0.5):
        pencil([base, (base[0] + ca * length * 0.9 - sa * width * v, base[1] + sa * length * 0.9 + ca * width * v)], 0.9, 1, 0.3, 0.3)
    hatch(pts, tip_angle + 0.8, 5, 0.25)


def capsule(base, length):
    """The beak-like seed head that gives cranesbills their name."""
    x, y = base
    pencil([(x, y), (x + 2, y - length)], 1.6, 2, 0.6, 0.3)
    pencil([(x - 5, y - 4), (x - 1, y - length * 0.95)], 1.1, 1, 0.4, 0.3)
    pencil([(x + 6, y - 4), (x + 3, y - length * 0.95)], 1.1, 1, 0.4, 0.3)
    for k in range(5):
        a = math.pi / 2 + (k - 2) * 0.55
        pencil([(x, y), (x + math.cos(a) * 18, y + math.sin(a) * 14)], 1.2, 1, 0.45, 0.3)
    fill_shape([(x - 7, y), (x + 8, y), (x + 3, y - length), (x - 1, y - length)])


# ---------------------------------------------------------------- composition
def main():
    # main stem: from the bottom, gently S-curved, up to the flower clusters
    main_stem = bezier((560, 2540), (600, 2000), (500, 1500), (600, 900), 70)
    stem(main_stem, 15)

    # second, thinner stem rising to the right cluster
    s2 = bezier((560, 1500), (640, 1300), (760, 1050), (780, 620), 50)
    stem(s2, 10)
    s3 = bezier((600, 900), (590, 760), (540, 600), (470, 430), 40)
    stem(s3, 9)
    s4 = bezier((600, 900), (650, 760), (700, 560), (720, 380), 40)
    stem(s4, 8)

    # leaves: the large one low on the left (as on the reference plate), others smaller
    leaf_stalk = bezier((548, 1480), (470, 1420), (380, 1350), (300, 1300), 30)
    stem(leaf_stalk, 7)
    leaf((300, 1300), 300, math.radians(-150), 7, 2.9)

    l2 = bezier((590, 1150), (650, 1120), (720, 1110), (780, 1070), 20)
    stem(l2, 6)
    leaf((780, 1070), 170, math.radians(-20), 7, 2.7)

    l3 = bezier((660, 1300), (720, 1290), (780, 1310), (840, 1290), 16)
    stem(l3, 5)
    leaf((840, 1290), 120, math.radians(10), 5, 2.4)

    l4 = bezier((560, 1900), (480, 1880), (420, 1860), (380, 1830), 18)
    stem(l4, 6)
    leaf((380, 1830), 150, math.radians(-160), 7, 2.6)

    # flowers and buds at the top: a loose cluster, some turned away
    flower((470, 395), 118, rot=0.3)
    flower((735, 330), 104, rot=1.1, squash=0.75, tilt=0.3)
    flower((800, 590), 92, rot=0.6, squash=0.55, tilt=-0.4)
    flower((350, 600), 88, rot=2.0, squash=0.6, tilt=0.5)
    flower((610, 205), 76, rot=0.2, squash=0.5, tilt=-0.2)
    s5 = bezier((520, 760), (470, 700), (420, 650), (360, 605), 20)
    stem(s5, 5)
    s6 = bezier((640, 700), (640, 520), (625, 360), (612, 240), 30)
    stem(s6, 5)
    bud((585, 520), math.radians(-100), 64, 17)
    pencil(bezier((598, 660), (594, 610), (590, 560), (586, 525), 10), 2.0, 2, 0.5, 0.3)
    bud((662, 455), math.radians(-60), 52, 14)
    pencil(bezier((642, 600), (650, 540), (656, 500), (662, 460), 10), 1.8, 2, 0.5, 0.3)
    bud((910, 700), math.radians(-20), 44, 12)
    pencil(bezier((770, 820), (830, 780), (870, 730), (910, 700), 10), 1.6, 2, 0.5, 0.3)

    # ---- detail studies on the right: flower 1:1, bud 2:1, capsule 2:1
    flower((1235, 800), 80, rot=0.9)
    pencil(bezier((1235, 880), (1236, 920), (1238, 960), (1240, 990), 10), 2.0, 2, 0.5, 0.3)
    bud((1240, 1390), math.radians(-90), 110, 30)
    pencil(bezier((1240, 1390), (1240, 1420), (1241, 1450), (1242, 1480), 8), 2.4, 2, 0.5, 0.3)
    capsule((1240, 1820), 150)
    pencil(bezier((1240, 1820), (1241, 1850), (1242, 1880), (1243, 1900), 8), 2.4, 2, 0.5, 0.3)

    # ---- paper tooth: break the strokes up like graphite on cold-press paper
    tooth = nrng.random((H * SS, W * SS)).astype(np.float32)
    tooth = np.asarray(Image.fromarray((tooth * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255
    ink = np.clip(S.ink, 0, 1.25) / 1.25
    ink = np.clip(ink * (0.62 + 0.55 * tooth), 0, 1) ** 0.9

    alpha = Image.fromarray((ink * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
    rgba = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rgba.putalpha(alpha)

    folder = os.path.join(OUT, PLATE_ID)
    os.makedirs(folder, exist_ok=True)
    rgba.save(os.path.join(folder, "ink.png"), optimize=True)

    def mask_png(img, name, blur):
        m = img.filter(ImageFilter.GaussianBlur(blur * SS)).resize((W, H), Image.LANCZOS)
        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        out.putalpha(m)
        out.save(os.path.join(folder, name), optimize=True)

    # watercolour: a soft, slightly offset wash that does not stay inside the lines
    wash = S.wash.filter(ImageFilter.MaxFilter(5)).transform(S.wash.size, Image.AFFINE, (1, 0, -6, 0, 1, 4))
    mask_png(wash, "wash.png", 3.0)
    mask_png(S.fill.filter(ImageFilter.MaxFilter(9)), "silhouette.png", 1.0)

    meta = {
        "number": "0001",
        "region": "FLORA EUROPAEA",
        "subtitle": "Archivum.",
        "latin": "Geranium pratense",
        "authority": "Linnaeus, 1753.",
        "family": "Geraniaceae",
        "common": "European meadow cranesbill.",
        "label": {
            "loc": "Northern Europe.",
            "hab": "Meadows and field margins.",
            "leg": "E. K. Vestergaard",
            "det": "A. Holmgren",
            "dat": "14 VI 1921."
        },
        "box": [0.375, 0.06, 0.665, 0.95],
        "wash": True,
        "silhouette": True,
        "tapes": [
            {"x": 0.40, "y": 0.355, "w": 0.13, "angle": 8},
            {"x": 0.39, "y": 0.62, "w": 0.12, "angle": -4},
            {"x": 0.41, "y": 0.86, "w": 0.13, "angle": 5}
        ],
        "marks": [
            {"text": "1:1", "x": 0.925, "y": 0.35},
            {"text": "2:1", "x": 0.925, "y": 0.58},
            {"text": "2:1", "x": 0.925, "y": 0.75}
        ]
    }
    with open(os.path.join(folder, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")

    index_path = os.path.join(OUT, "index.json")
    index = []
    if os.path.exists(index_path):
        with open(index_path) as f:
            index = json.load(f)
    if PLATE_ID not in index:
        index.append(PLATE_ID)
    with open(index_path, "w") as f:
        json.dump(sorted(index), f, indent=2)
        f.write("\n")
    print("plate written to", os.path.normpath(folder))


if __name__ == "__main__":
    main()
