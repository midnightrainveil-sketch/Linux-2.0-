#!/usr/bin/env python3
"""Generate the shell's texture and icon assets.

    python3 tools/gen_assets.py

Writes into dotfiles/.config/quickshell/assets/:
  grain-dark.png, grain-light.png   512 px seamless paper-fibre tiles
  icons/*.svg                       margin-sketch line icons (24 grid, 2 px = 1.5 px at 18)
  weather/*.svg                     pencil-shaded weather sketches (64 grid)

Icons are drawn as polylines with a gentle seeded wobble so they read as
ink sketches, not interface glyphs (spec section 9). The shell recolours
them, so the stroke colour here does not matter.
Requires: python3, numpy, pillow.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "dotfiles", ".config", "quickshell", "assets")


# ---------------------------------------------------------------- grain
def seamless_noise(size, rng, scale):
    """Tileable value noise via FFT-filtered white noise."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1
    spectrum = np.fft.fft2(white) * np.exp(-(f * scale) ** 2)
    out = np.real(np.fft.ifft2(spectrum))
    out -= out.mean()
    return out / (out.std() + 1e-9)


def fibres(size, rng, count, length, alpha):
    """Short curved fibres, wrapped at the edges so the tile is seamless."""
    img = Image.new("L", (size, size), 0)
    px = img.load()
    for _ in range(count):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        ang = rng.uniform(0, math.pi)
        a = rng.uniform(alpha * 0.4, alpha)
        n = int(rng.uniform(length * 0.4, length))
        for _ in range(n):
            ang += rng.normal(0, 0.18)
            x += math.cos(ang) * 0.8
            y += math.sin(ang) * 0.8
            xi, yi = int(x) % size, int(y) % size
            px[xi, yi] = min(255, px[xi, yi] + int(a))
    return np.asarray(img, dtype=np.float32) / 255.0


def make_grain():
    size = 512
    rng = np.random.default_rng(42)
    fine = seamless_noise(size, rng, 2.0)
    mid = seamless_noise(size, rng, 9.0)
    blotch = seamless_noise(size, rng, 60.0)
    pyrng = np.random.default_rng(7)

    class R:  # tiny adaptor so fibres() can use numpy's rng like random
        uniform = staticmethod(lambda a, b: pyrng.uniform(a, b))
        normal = staticmethod(lambda m, s: pyrng.normal(m, s))

    fib = fibres(size, R, 900, 40, 90)

    # dark: specks + fibres + very soft blotches; alpha only, black ink
    dark = 0.45 * np.clip(fine, 0, None) + 0.30 * np.clip(mid, 0, None) + 0.08 * (blotch * 0.5 + 0.5) + 1.4 * fib
    dark = np.clip(dark / np.percentile(dark, 99.7), 0, 1)
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[..., 3] = (dark * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(ROOT, "grain-dark.png"), optimize=True)

    # light: brush-coating marks for the cyanotype night sheet
    streak = seamless_noise(size, rng, 4.0)
    streak = np.roll(streak, 0, axis=0)
    light = 0.5 * np.clip(-fine, 0, None) + 0.6 * np.clip(streak, 0, None) + 0.8 * fib
    light = np.clip(light / np.percentile(light, 99.7), 0, 1)
    rgba = np.full((size, size, 4), 255, np.uint8)
    rgba[..., 3] = (light * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(ROOT, "grain-light.png"), optimize=True)


# ---------------------------------------------------------------- sketch helpers
class Pen:
    """Collects wobbly polylines and writes an SVG."""

    def __init__(self, grid, width, seed, wobble):
        self.grid, self.width, self.wobble = grid, width, wobble
        self.rng = random.Random(seed)
        self.paths = []  # (d, width, opacity, fill)
        self.hidden = None  # optional f(x, y) -> True where a nearer shape covers the drawing

    def _jitter(self, pts, closed=False):
        out, off = [], 0.0
        n = len(pts)
        for i, (x, y) in enumerate(pts):
            off = off * 0.55 + self.rng.uniform(-1, 1) * self.wobble
            # normal direction
            x0, y0 = pts[max(0, i - 1)]
            x1, y1 = pts[min(n - 1, i + 1)]
            dx, dy = x1 - x0, y1 - y0
            l = math.hypot(dx, dy) or 1
            nx, ny = -dy / l, dx / l
            k = 0.35 if (not closed and (i == 0 or i == n - 1)) else 1
            out.append((x + nx * off * k, y + ny * off * k))
        return out

    def line(self, pts, width=None, opacity=1.0, closed=False, step=1.0, fill=False):
        dense = []
        seq = pts + ([pts[0]] if closed else [])
        for (x0, y0), (x1, y1) in zip(seq, seq[1:]):
            l = math.hypot(x1 - x0, y1 - y0)
            k = max(1, int(l / step))
            for i in range(k):
                t = i / k
                dense.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
        dense.append(seq[-1])
        dense = self._jitter(dense, closed)
        runs = [dense]
        if self.hidden is not None:
            runs, cur = [], []
            for pt in dense:
                if self.hidden(*pt):
                    if len(cur) > 1:
                        runs.append(cur)
                    cur = []
                else:
                    cur.append(pt)
            if len(cur) > 1:
                runs.append(cur)
            closed = False
        for run in runs:
            d = "M" + " L".join(f"{x:.2f},{y:.2f}" for x, y in run) + (" Z" if closed else "")
            self.paths.append((d, width or self.width, opacity, fill))

    def arc(self, cx, cy, rx, ry, a0, a1, **kw):
        n = max(6, int(abs(a1 - a0) * max(rx, ry) / 0.9))
        pts = [(cx + rx * math.cos(a0 + (a1 - a0) * i / n), cy + ry * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]
        self.line(pts, **kw)

    def circle(self, cx, cy, r, **kw):
        # start at a random angle and overshoot a touch: a hand-closed loop
        a0 = self.rng.uniform(0, 2 * math.pi)
        self.arc(cx, cy, r, r, a0, a0 + 2 * math.pi + 0.25, **kw)

    def dot(self, cx, cy, r, opacity=1.0):
        self.paths.append((f"M{cx - r:.2f},{cy:.2f} a{r},{r} 0 1,0 {2 * r},0 a{r},{r} 0 1,0 {-2 * r},0", 0, opacity, True))

    def svg(self):
        body = []
        for d, w, o, fill in self.paths:
            if fill:
                body.append(f'<path d="{d}" fill="#000" fill-opacity="{o:.2f}" stroke="none"/>')
            else:
                body.append(f'<path d="{d}" fill="none" stroke="#000" stroke-opacity="{o:.2f}" '
                            f'stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')
        g = self.grid
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {g} {g}" width="{g}" height="{g}">\n  '
                + "\n  ".join(body) + "\n</svg>\n")


def save(folder, name, pen):
    os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
    with open(os.path.join(ROOT, folder, name + ".svg"), "w") as f:
        f.write(pen.svg())


# ---------------------------------------------------------------- line icons (24 grid)
def icon(name, seed, draw):
    p = Pen(24, 1.9, seed, 0.18)
    draw(p)
    save("icons", name, p)


def sprig(p, big=False):
    # a lavender-like sprig: curved stem, paired leaflets, a few florets on top
    stem = [(12.6 + 1.8 * math.sin(t * 1.2) * (1 - t), 22.5 - t * 20) for t in [i / 20 for i in range(21)]]
    p.line(stem, width=1.6)
    for i in range(6):
        t = 0.18 + i * 0.12
        x = 12.6 + 1.8 * math.sin(t * 1.2) * (1 - t)
        y = 22.5 - t * 20
        s = 3.2 - i * 0.32
        side = 1 if i % 2 == 0 else -1
        p.line([(x, y), (x + side * s * 0.55, y - s * 0.55), (x + side * s, y - s * 1.1)], width=1.3)
        p.line([(x, y), (x - side * s * 0.5, y - s * 0.45), (x - side * s * 0.85, y - s * 0.95)], width=1.3)
    for j in range(4):
        y = 4.2 + j * 1.7
        p.circle(12.2 + (0.9 if j % 2 else -0.9), y, 0.75, width=1.1)


def screen(p, night=False):
    p.line([(3, 4.5), (21, 4.3), (21.2, 15.6), (2.8, 15.8)], closed=True)
    p.line([(12, 16), (12, 19.6)])
    p.line([(7.8, 20), (16.3, 19.8)])
    if night:
        p.arc(12, 10, 3.4, 3.4, math.radians(60), math.radians(300), width=1.4)
        p.arc(13.6, 9.2, 2.6, 2.6, math.radians(90), math.radians(270), width=1.2)


def speaker(p, waves=1, muted=False):
    p.line([(3, 9.2), (7, 9), (12, 4.8), (12.2, 19.2), (7, 15.1), (3.1, 14.9)], closed=True)
    if muted:
        p.line([(15.5, 9.5), (20.5, 14.5)])
        p.line([(20.5, 9.5), (15.5, 14.5)])
        return
    for w in range(waves):
        r = 3.4 + w * 3.4
        p.arc(12.5, 12, r, r, math.radians(-48), math.radians(48))


def wifi(p, state="on"):
    o = 1.0 if state == "on" else 0.35
    for i, r in enumerate((4.2, 8.2, 12.2)):
        p.arc(12, 19.5, r, r, math.radians(-138), math.radians(-42), opacity=o)
    p.dot(12, 19.2, 1.35, opacity=1.0 if state == "on" else 0.5)
    if state == "off":
        p.line([(4, 4), (20, 21)])


def record(p):
    p.circle(12, 12, 9)
    p.circle(12, 12, 3)
    p.dot(12, 12, 0.9)
    p.arc(12, 12, 6, 6, math.radians(200), math.radians(260), width=1.1, opacity=0.6)


# ---------------------------------------------------------------- weather (64 grid, pencil shading)
def weather(name, seed, draw):
    p = Pen(64, 2.2, seed, 0.35)
    draw(p)
    save("weather", name, p)


CLOUD = [(18, 38, 9), (26, 26, 11), (40, 25, 12), (50, 36, 9)]
CLOUD_BASE = 45.5


def _upper_intersection(c0, c1):
    (x0, y0, r0), (x1, y1, r1) = c0, c1
    d = math.hypot(x1 - x0, y1 - y0)
    a = (r0 * r0 - r1 * r1 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, r0 * r0 - a * a))
    mx, my = x0 + a * (x1 - x0) / d, y0 + a * (y1 - y0) / d
    pts = [(mx + h * (y1 - y0) / d, my - h * (x1 - x0) / d), (mx - h * (y1 - y0) / d, my + h * (x1 - x0) / d)]
    return min(pts, key=lambda q: q[1])


def cloud_hidden(ox, oy, s, margin=1.6):
    """True for points inside the cloud (plus a little margin)."""
    def f(x, y):
        x, y = (x - ox) / s, (y - oy) / s
        if 16 <= x <= 52 and 30 <= y <= CLOUD_BASE + margin:
            return True
        return any(math.hypot(x - cx, y - cy) < r + margin for cx, cy, r in CLOUD)
    return f


def cloud(p, ox=0.0, oy=0.0, s=1.0, shade=True):
    def T(x, y):
        return (ox + x * s, oy + y * s)

    def ang(c, q):
        return math.atan2(q[1] - c[1], q[0] - c[0])

    joins = [_upper_intersection(CLOUD[i], CLOUD[i + 1]) for i in range(len(CLOUD) - 1)]
    # where the first and last bumps meet the flat base
    c0, cl = CLOUD[0], CLOUD[-1]
    dy0 = min(c0[2] * 0.95, CLOUD_BASE - c0[1])
    dyl = min(cl[2] * 0.95, CLOUD_BASE - cl[1])
    start = (c0[0] - math.sqrt(c0[2] ** 2 - dy0 ** 2), c0[1] + dy0)
    end = (cl[0] + math.sqrt(cl[2] ** 2 - dyl ** 2), cl[1] + dyl)
    entries = [start] + joins
    exits = joins + [end]
    pts = []
    for c, a, b in zip(CLOUD, entries, exits):
        a0, a1 = ang(c, a), ang(c, b)
        while a1 <= a0:
            a1 += 2 * math.pi
        n = max(8, int((a1 - a0) * c[2] / 1.2))
        for i in range(n + 1):
            t = a0 + (a1 - a0) * i / n
            pts.append(T(c[0] + c[2] * math.cos(t), c[1] + c[2] * math.sin(t)))
    pts.append(T(start[0] + 1, CLOUD_BASE + 0.6))
    p.line(pts, closed=True, step=0.9)
    if shade:
        # diagonal hatching in the lower belly of the cloud
        for i in range(12):
            x = 14 + i * 3.1
            p.line([T(x + 2, CLOUD_BASE - 0.8), T(x + 8, 37 - (i % 3))], width=1.0, opacity=0.45)
        for i in range(7):
            x = 18 + i * 4.4
            p.line([T(x, CLOUD_BASE - 0.8), T(x + 4, 40)], width=0.9, opacity=0.35)


def sun(p, cx=32, cy=32, r=10, rays=True):
    p.circle(cx, cy, r)
    for i in range(10):
        a = i * math.pi / 5 + 0.15
        p.line([(cx + (r + 4) * math.cos(a), cy + (r + 4) * math.sin(a)),
                (cx + (r + 9) * math.cos(a), cy + (r + 9) * math.sin(a))], width=1.8)
    for i in range(6):  # shading on the lower right of the disc
        a = math.radians(20 + i * 14)
        p.line([(cx + (r - 2) * math.cos(a), cy + (r - 2) * math.sin(a)),
                (cx + (r - 6) * math.cos(a + 0.5), cy + (r - 6) * math.sin(a + 0.5))], width=1.0, opacity=0.4)


def moon(p, cx=30, cy=30, r=12):
    p.arc(cx, cy, r, r, math.radians(40), math.radians(320))
    p.arc(cx + 7, cy - 3, r * 0.82, r * 0.82, math.radians(95), math.radians(262))
    for i in range(6):
        y = cy - 6 + i * 3
        p.line([(cx - r + 3, y), (cx - r + 7.5, y - 2.5)], width=1.0, opacity=0.4)


def main():
    os.makedirs(ROOT, exist_ok=True)
    make_grain()

    icon("sprig", 1, sprig)
    icon("screen", 2, screen)
    icon("screen-night", 3, lambda p: screen(p, True))
    icon("speaker", 4, lambda p: speaker(p, 1))
    icon("speaker-loud", 5, lambda p: speaker(p, 2))
    icon("speaker-muted", 6, lambda p: speaker(p, 0, True))
    icon("wifi", 7, lambda p: wifi(p, "on"))
    icon("wifi-none", 8, lambda p: wifi(p, "none"))
    icon("wifi-off", 9, lambda p: wifi(p, "off"))
    icon("record", 10, record)

    weather("overcast", 21, lambda p: cloud(p, 0, 2))
    weather("clear", 22, lambda p: sun(p))
    weather("clear-night", 23, lambda p: moon(p))

    def partly(p):
        p.hidden = cloud_hidden(6, 10, 0.85)
        sun(p, 22, 22, 8)
        p.hidden = None
        cloud(p, 6, 10, 0.85)
    weather("partly", 24, partly)

    def partly_night(p):
        p.hidden = cloud_hidden(6, 10, 0.85)
        moon(p, 22, 20, 9)
        p.hidden = None
        cloud(p, 6, 10, 0.85)
    weather("partly-night", 25, partly_night)

    def fog(p):
        cloud(p, 0, -6, 1.0, shade=False)
        for i, (x0, x1) in enumerate([(10, 52), (16, 56), (8, 46)]):
            p.line([(x0, 46 + i * 5), (x1, 45.5 + i * 5)], width=1.8, opacity=0.8)
    weather("fog", 26, fog)

    def rain(p):
        cloud(p, 0, -6)
        for i in range(6):
            x = 18 + i * 6
            p.line([(x, 46), (x - 3, 55 - (i % 2) * 2)], width=1.6)
    weather("rain", 27, rain)

    def snow(p):
        cloud(p, 0, -6)
        for i, (x, y) in enumerate([(20, 50), (32, 54), (44, 50), (26, 58), (38, 59)]):
            for a in (0, 60, 120):
                r = math.radians(a)
                p.line([(x - 2.4 * math.cos(r), y - 2.4 * math.sin(r)), (x + 2.4 * math.cos(r), y + 2.4 * math.sin(r))], width=1.2)
    weather("snow", 28, snow)

    def storm(p):
        cloud(p, 0, -6)
        p.line([(34, 42), (28, 51), (34, 50.5), (29, 60)], width=2.0)
        p.line([(20, 46), (18, 52)], width=1.4)
        p.line([(46, 46), (44, 52)], width=1.4)
    weather("storm", 29, storm)

    print("assets written to", os.path.normpath(ROOT))


if __name__ == "__main__":
    main()
