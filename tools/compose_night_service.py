#!/usr/bin/env python3
"""Compartment 19's sheet, laid out loose: the keepsakes spread over the desk
as in the layout study (docs/compartment-19-layout.png), rather than in the
plate's single column.

    python3 tools/compose_night_service.py

Each keepsake is lifted from the 4K plate (art/night-service/wallpaper.webp)
with its own soft shadow (the paper taken out, as ink on a clear sheet; the
plate's typed labels and leader lines left behind), and laid on a fresh
sheet of the plate's own blank paper at the place, size and slant the study
gives it. The heading, the script title and the few small labels are typed
again, in the desk's own faces. Writes art/night-service/composed.webp, from
which import_wallpaper.py makes the day and night sheets.
Requires: numpy, pillow.
"""
import math
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "art", "night-service")
FONTS = os.path.join(HERE, "..", "dotfiles", ".local", "share", "fonts", "archive")
SRC = os.path.join(ART, "wallpaper.webp")
OUT = os.path.join(ART, "composed.webp")

W, H = 3840, 2160          # the composed sheet (16:9, as the plate)
# what the screen shows of it (16:10, cropped at the sides): the study's
# fractions are of this
VIS_X0, VIS_W = (W - H * 16 / 10) / 2, H * 16 / 10

# each keepsake: its box in the plate (px), what of it to keep ("solid": the
# object, its thin label lines left behind; "blue": the stamp's ink only),
# and where it goes: centre (fraction of the screen), width (fraction of the
# screen's width), slant (degrees, counter-clockwise)
ITEMS = [
    ("key", (1380, 140, 2480, 600), "solid", (0.489, 0.172), 0.25, 4),
    ("ticket", (1470, 500, 2450, 1060), "solid", (0.585, 0.338), 0.215, 7, [(1470, 500, 1640, 600), (2370, 640, 2450, 760), (1700, 990, 2450, 1060), (1470, 980, 1700, 1060)]),
    ("flower", (1150, 530, 1510, 1400), "solid", (0.445, 0.548), 0.115, 27, [(1150, 840, 1330, 1060), (1470, 530, 1510, 600)]),
    ("map", (1690, 1000, 2510, 1700), "solid", (0.612, 0.676), 0.188, -3, [(1690, 1000, 2060, 1030), (2460, 1200, 2510, 1360), (1690, 1000, 1720, 1700)]),
    ("sugar", (1320, 1360, 1710, 1700), "solid", (0.366, 0.733), 0.10, 4),
    ("stamp", (1790, 1880, 2300, 2100), "blue", (0.655, 0.868), 0.118, 0),
]


def blank_paper(src):
    """A sheet of the plate's own blank paper: its empty left strip, mirrored
    across and down."""
    strip = src.crop((0, 0, round(src.width * 0.235), src.height)).resize((round(0.235 * W), H), Image.LANCZOS)
    paper = Image.new("RGB", (W, H))
    x, flip = 0, False
    while x < W:
        piece = strip.transpose(Image.FLIP_LEFT_RIGHT) if flip else strip
        paper.paste(piece, (x, 0))
        x += piece.width
        flip = not flip
    return paper


def components(mask):
    """Labels of the 4-connected parts of a boolean array, and their sizes."""
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    sizes = [0]
    cur = 0
    for y in range(h):
        row = mask[y]
        for x in range(w):
            if row[x] and not lab[y, x]:
                cur += 1
                q = deque([(y, x)])
                lab[y, x] = cur
                n = 0
                while q:
                    cy, cx = q.popleft()
                    n += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                            lab[ny, nx] = cur
                            q.append((ny, nx))
                sizes.append(n)
    return lab, sizes


def lift(src, box, how, paper_rgb, erase=()):
    """The keepsake in `box`, its paper made clear (ink on a clear sheet: each
    pixel keeps what, over the paper, gives what was drawn), its shadow kept
    as a soft dark."""
    crop = src.crop(box)
    a = np.asarray(crop).astype(np.float32)
    p = paper_rgb[None, None, :]
    # how far from the paper, at most, each pixel had to be darkened or coloured
    diff = np.abs(a - p).max(axis=2)
    alpha = np.clip((diff - 7) / 70, 0, 1)
    if how == "blue":
        blue = (a[..., 2] - a[..., 0]) - (p[0, 0, 2] - p[0, 0, 0])
        keep = blue > 8
        keep = np.asarray(Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))) > 0
    else:
        # the object: the biggest solid part (thin lines and type broken off
        # first, then the part grown back over its own edge and shadow)
        k = 4
        small = Image.fromarray(((diff > 18) * 255).astype(np.uint8)).resize((crop.width // k, crop.height // k), Image.BILINEAR)
        solid = np.asarray(small.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))) > 120
        # (its outline closed, so a pale object's middle counts as inside it)
        solid = np.asarray(Image.fromarray((solid * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))) > 0
        lab, sizes = components(solid)
        biggest = int(np.argmax(sizes))
        part = lab == biggest
        outside, _ = components(~part)
        edge = set(outside[0].tolist()) | set(outside[-1].tolist()) | set(outside[:, 0].tolist()) | set(outside[:, -1].tolist())
        part = ~np.isin(outside, list(edge - {0}))
        body = Image.fromarray((part * 255).astype(np.uint8))
        # inside the object: as drawn, solid; round it: its shadow, as a soft dark
        solid_in = np.asarray(body.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1)).resize(crop.size, Image.BILINEAR)).astype(np.float32) / 255
        keep_small = body.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(2))
        keep = np.asarray(keep_small.resize(crop.size, Image.BILINEAR)).astype(np.float32) / 255
        alpha = np.maximum(alpha, solid_in)
    alpha = alpha * keep
    # never a hard cut at the box's edge
    hh, ww = alpha.shape
    ramp = 24.0
    yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float32)
    alpha *= np.clip(np.minimum.reduce([xx, yy, ww - 1 - xx, hh - 1 - yy]) / ramp, 0, 1)
    for ex0, ey0, ex1, ey1 in erase:
        alpha[max(0, ey0 - box[1]):max(0, ey1 - box[1]), max(0, ex0 - box[0]):max(0, ex1 - box[0])] = 0
    safe = np.maximum(alpha, 1e-3)[..., None]
    col = np.clip(p + (a - p) / safe, 0, 255)
    rgba = np.dstack([col, alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())


def at(fx, fy):
    return VIS_X0 + fx * VIS_W, fy * H


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def typed(d, xy, text, size, fill=(46, 44, 48), spacing=0.0, face="CourierPrime-Regular.ttf", anchor="la"):
    f = font(face, size)
    if spacing:
        x, y = xy
        step = [f.getlength(c) + size * spacing for c in text]
        if anchor[0] == "m":
            x -= (sum(step) - size * spacing) / 2
        for c, s in zip(text, step):
            d.text((x, y), c, font=f, fill=fill, anchor="l" + anchor[1])
            x += s
    else:
        d.text(xy, text, font=f, fill=fill, anchor=anchor)


def main():
    src = Image.open(SRC).convert("RGB")
    paper_rgb = np.median(np.asarray(src.crop((40, 40, 600, 2100))).reshape(-1, 3).astype(np.float32), axis=0)
    sheet = blank_paper(src).convert("RGBA")
    for item in ITEMS:
        name, box, how, (fx, fy), fw, slant = item[:6]
        piece = lift(src, box, how, paper_rgb, item[6] if len(item) > 6 else ())
        k = fw * VIS_W / piece.width
        piece = piece.resize((round(piece.width * k), round(piece.height * k)), Image.LANCZOS)
        if slant:
            piece = piece.rotate(slant, resample=Image.BICUBIC, expand=True)
        cx, cy = at(fx, fy)
        sheet.alpha_composite(piece, (round(cx - piece.width / 2), round(cy - piece.height / 2)))
        print("keepsake:", name, piece.size)

    d = ImageDraw.Draw(sheet)
    ink, soft = (40, 38, 42), (78, 74, 76)
    # ---- the heading: a fleuron, the name spaced out, a rule each side of the line under it
    cx, y = at(0.5, 0.0)
    fy = H * 0.036
    d.polygon([(cx, fy - 13), (cx + 13, fy), (cx, fy + 13), (cx - 13, fy)], outline=soft, width=3)
    d.ellipse([cx - 4, fy - 4, cx + 4, fy + 4], fill=soft)
    typed(d, (cx, H * 0.062), "COMPARTMENT 19", 74, fill=ink, spacing=0.32, anchor="mm")
    sub = "Vienna — Venice  ·  June 1931"
    typed(d, (cx, H * 0.092), sub, 40, fill=soft, face="CourierPrime-Italic.ttf", spacing=0.12, anchor="mm")
    half = font("CourierPrime-Italic.ttf", 40).getlength(sub) * 1.12 / 2 + 30
    for sgn in (-1, 1):
        x0 = cx + sgn * half
        d.line([(x0, H * 0.092), (x0 + sgn * 230, H * 0.092)], fill=soft, width=3)
    d.line([(cx - 330, H * 0.036), (cx - 50, H * 0.036)], fill=soft, width=2)
    d.line([(cx + 50, H * 0.036), (cx + 330, H * 0.036)], fill=soft, width=2)

    # ---- the script title and its typed lines
    x, y = at(0.35, 0.80)
    typed(d, (x, y), "Vienna — Venice", 118, fill=ink, face="PinyonScript-Regular.ttf")
    d.line([(x + 6, y + 150), (x + 760, y + 150)], fill=soft, width=3)
    typed(d, (x + 14, y + 172), "Night train, 14–15 June 1931.", 44, fill=ink)
    typed(d, (x + 14, y + 228), "Compartment 19, lower berth.", 44, fill=ink)

    # ---- a few small labels, with their leader lines
    def label(fx, fy, lines, to):
        lx, ly = at(fx, fy)
        for i, s in enumerate(lines):
            typed(d, (lx, ly + i * 34), s, 30, fill=soft)
        tx, ty = at(*to)
        d.line([(lx + 4, ly + len(lines) * 34 + 6), (tx, ty)], fill=soft, width=2)
    label(0.335, 0.47, ["Alpine", "wildflower", "(pressed)"], (0.405, 0.512))
    label(0.44, 0.745, ["Sugar cube", "(wrapped)"], (0.41, 0.74))
    label(0.618, 0.495, ["Route map", "(Vienna – Venice)"], (0.63, 0.545))

    sheet.convert("RGB").save(OUT, quality=94, method=6)
    print("composed:", os.path.normpath(OUT), sheet.size)


if __name__ == "__main__":
    main()
