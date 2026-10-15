#!/usr/bin/env python3
"""The desk terminal's six ink swatches, chalked on.

    python3 tools/chalk_swatches.py

Writes dotfiles/.config/fastfetch/chalk-day.six and chalk-night.six: one
strip of six squares in the palette slots 16-21 of foot.ini (day and night),
as sixel graphics, which foot shows inline. Each square is rubbed on like
chalk: diagonal strokes, the paper showing through in the grain, a ragged
edge, a stroke or two overshooting. The paper itself stays transparent.

The square is SIZE px, about four cells by two of the desk terminal's type
(Courier Prime 10 at scale 1.5).
"""
import math
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "dotfiles" / ".config" / "fastfetch"

SIZE = 46
GAP = 24
INKS = {
    "day": ["545356", "6b6a6e", "737176", "626a78", "848991", "7f8796"],
    "night": ["e6e1d6", "c9ccd2", "aeb5c2", "8e9cb3", "a9c4e4", "7c93b8"],
}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def smooth_noise(r, n):
    """n values drifting smoothly (a few random knots, interpolated)."""
    knots = [r.uniform(-1, 1) for _ in range(n // 6 + 3)]
    out = []
    for i in range(n):
        t = i / 6
        k = int(t)
        f = t - k
        f = f * f * (3 - 2 * f)
        out.append(knots[k] * (1 - f) + knots[k + 1] * f)
    return out


def swatch(seed):
    """SIZE x SIZE of 0 (paper), 1 (chalk), 2 (heavier chalk)."""
    r = random.Random(seed)
    s = SIZE
    # the edges, drawn by hand: each wanders in and out a little
    top, bottom = smooth_noise(r, s), smooth_noise(r, s)
    left, right = smooth_noise(r, s), smooth_noise(r, s)
    angle = r.uniform(0.55, 0.85)               # the strokes' slant
    ca, sa = math.cos(angle), math.sin(angle)
    phase = r.uniform(0, 6.3)
    grid = [[0] * s for _ in range(s)]
    for y in range(s):
        for x in range(s):
            inside = (y > 2 + 2.2 * top[x] and y < s - 3 + 2.2 * bottom[x]
                      and x > 2 + 2.2 * left[y] and x < s - 3 + 2.2 * right[y])
            # the strokes: bands across the slant, pressed harder and lighter
            u = x * ca + y * sa
            band = 0.5 + 0.5 * math.sin(u * 0.9 + phase + 0.6 * math.sin(u * 0.13))
            if inside:
                p = 0.62 + 0.3 * band
                if r.random() < p:
                    grid[y][x] = 2 if r.random() < 0.35 * band else 1
            else:
                # chalk dust and a stroke running past the edge
                d = min(abs(y - 2), abs(y - (s - 3)), abs(x - 2), abs(x - (s - 3)))
                if d < 3 and r.random() < 0.18 * band:
                    grid[y][x] = 1
    return grid


def sixel(pixels, palette):
    """pixels: rows of palette indices (None = transparent)."""
    h, w = len(pixels), len(pixels[0])
    out = ['\x1bP0;1;0q"1;1;%d;%d' % (w, h)]
    for i, (cr, cg, cb) in enumerate(palette):
        out.append("#%d;2;%d;%d;%d" % (i, cr * 100 // 255, cg * 100 // 255, cb * 100 // 255))
    for band in range(0, h, 6):
        rows = pixels[band:band + 6]
        first = True
        for ci in range(len(palette)):
            cols = []
            used = False
            for x in range(w):
                bits = 0
                for k, row in enumerate(rows):
                    if row[x] == ci:
                        bits |= 1 << k
                used |= bits != 0
                cols.append(chr(63 + bits))
            if not used:
                continue
            # run-length: !<n><char>
            line, i = [], 0
            while i < w:
                j = i
                while j < w and cols[j] == cols[i]:
                    j += 1
                n = j - i
                line.append(("!%d%s" % (n, cols[i])) if n > 3 else cols[i] * n)
                i = j
            out.append(("" if first else "$") + "#%d" % ci + "".join(line))
            first = False
        out.append("-")
    out.append("\x1b\\")
    return "".join(out)


def strip(inks):
    w = 6 * SIZE + 5 * GAP
    pixels = [[None] * w for _ in range(SIZE)]
    palette = []
    for k, ink in enumerate(inks):
        base = rgb(ink)
        light = tuple(min(255, int(c * 1.0 + (255 - c) * 0.10)) for c in base)
        heavy = tuple(int(c * 0.86) for c in base)
        palette += [light, heavy]
        g = swatch(1009 + 31 * k)
        x0 = k * (SIZE + GAP)
        for y in range(SIZE):
            for x in range(SIZE):
                if g[y][x]:
                    pixels[y][x0 + x] = 2 * k + (g[y][x] - 1)
    return sixel(pixels, palette)


if __name__ == "__main__":
    for mode, inks in INKS.items():
        dst = OUT / ("chalk-%s.six" % mode)
        dst.write_text(strip(inks))
        print("chalk:", dst.relative_to(ROOT))
