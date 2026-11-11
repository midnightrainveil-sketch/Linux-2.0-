#!/usr/bin/env python3
"""Compartment 19's sheet, laid out loose: the keepsakes spread over the desk
as in the layout study (docs/compartment-19-layout.webp), rather than in the
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
FONTS = os.path.join(HERE, "..", "home", ".local", "share", "fonts", "archive")
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
    ("ticket", (1470, 500, 2450, 1060), "solid", (0.585, 0.338), 0.215, 7, [(1470, 500, 1640, 600), (2370, 640, 2450, 760)]),
    ("flower", (1150, 530, 1510, 1400), "thin", (0.445, 0.548), 0.115, 27, [(1150, 840, 1330, 1060), (1470, 530, 1510, 600)]),
    ("map", (1690, 1000, 2510, 1700), "solid", (0.612, 0.676), 0.188, -3, []),
    ("sugar", (1320, 1360, 1710, 1700), "plain", (0.366, 0.733), 0.10, 4),
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
    """The keepsake in `box`, cut out along its own outline (the plate's
    labels, leader lines and anything in `erase` left behind), with a fresh
    soft shadow of its own: never the plate's shadow, so no hard edges."""
    crop = src.crop(box)
    a = np.asarray(crop).astype(np.float32)
    p = paper_rgb[None, None, :]
    diff = np.abs(a - p).max(axis=2)
    for ex0, ey0, ex1, ey1 in erase:
        diff[max(0, ey0 - box[1]):max(0, ey1 - box[1]), max(0, ex0 - box[0]):max(0, ex1 - box[0])] = 0
    if how == "blue":
        blue = (a[..., 2] - a[..., 0]) - (p[0, 0, 2] - p[0, 0, 0])
        alpha = np.clip((blue - 6) / 30, 0, 1) * np.clip((diff - 10) / 40, 0, 1)
        col = np.clip(p + (a - p) / np.maximum(alpha, 0.2)[..., None], 0, 255)
        out = Image.fromarray(np.dstack([col, alpha * 255]).astype(np.uint8), "RGBA")
        return out.crop(out.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
    # the object: the biggest solid part, its holes filled
    k = 3
    # (a shadow on the paper is the paper, darker and no warmer: not the object)
    lum = a.mean(axis=2)
    plum = float(p.mean())
    warm = (a[..., 0] - a[..., 2]) - (p[0, 0, 0] - p[0, 0, 2])
    shadowy = (lum < plum - 4) & (np.abs(warm) < 9) & (diff < 60)
    obj = (diff > 16) & ~shadowy if how == "solid" else diff > 16
    small = Image.fromarray((obj * 255).astype(np.uint8)).resize((crop.width // k, crop.height // k), Image.BILINEAR)
    solid = np.asarray(small.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))) > 110
    lab, sizes = components(solid)
    part = lab == int(np.argmax(sizes))
    close = 5 if how == "thin" else 13     # (heals nicks the shadow test bit out of an edge)
    part = np.asarray(Image.fromarray((part * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(close)).filter(ImageFilter.MinFilter(close))) > 0
    outside, _ = components(~part)
    edge = set(outside[0].tolist()) | set(outside[-1].tolist()) | set(outside[:, 0].tolist()) | set(outside[:, -1].tolist())
    part = ~np.isin(outside, list(edge - {0}))
    if how == "plain":
        # (a wrapped lump, open where its tape crosses it: filled to its outline)
        rows = np.where(part.any(axis=1))[0]
        filled = part.copy()
        for y in rows:
            xs = np.where(part[y])[0]
            filled[y, xs.min():xs.max() + 1] = True
        part = filled
    # back to full size: a clean, slightly softened edge just inside the drawn one
    mask = Image.fromarray((part * 255).astype(np.uint8)).resize(crop.size, Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.6))
    m = np.clip((np.asarray(mask).astype(np.float32) - (60 if how == "thin" else 150)) / 90, 0, 1)
    if how == "thin":
        # a stem and leaves: the paper between them shows through
        m = m * np.clip((diff - 6) / 40, 0, 1)
    out = Image.fromarray(np.dstack([a, m * 255]).astype(np.uint8), "RGBA")
    out = out.crop(out.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox())
    # its shadow: soft, a little down and to the right
    pad = 40
    sh = Image.new("L", (out.width + 2 * pad, out.height + 2 * pad))
    sh.paste(out.getchannel("A"), (pad + 6, pad + 10))
    sh = sh.filter(ImageFilter.GaussianBlur(11)).point(lambda v: int(v * 0.32))
    canvas = Image.new("RGBA", sh.size, (30, 26, 22, 0))
    canvas.putalpha(sh)
    canvas.alpha_composite(out, (pad, pad))
    return canvas


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
