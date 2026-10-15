#!/usr/bin/env python3
"""The archive's cursors, from the drawn sheet.

    python3 tools/import_cursors.py [art/cursors/sheet.webp]

(The pointing glove comes from its own drawing, art/cursors/pointer.jpg.)
The sheet is 12 drawings in a 4 x 3 grid on white (pencil, gloved hand,
I-beam, pocket watch, pencil with watch, open glove, gloved fist, compass
star, loupe, no-entry stamp, scale bar, diagonal scale bar). Each is cut out
(the white round it made clear; inside the loupe and the stamp too, so they
do not hide what they point at), drawn down to each cursor size with its
point where you click and a hairline of paper round it (so the thin ones
show on dark ground), and written as an Xcursor theme:

    dotfiles/.local/share/icons/Archive-Cursors/
        index.theme
        cursors/<name>           one file per cursor, every size in it
        cursors/<other names>    links: the names programs ask for

Sizes 24 to 96 (Hyprland picks the one for the size and the screen's scale:
40 at scale 1.5 is 60).
"""
import math
import os
import pathlib
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = ROOT / "art" / "cursors" / "sheet.webp"
THEME = ROOT / "dotfiles" / ".local" / "share" / "icons" / "Archive-Cursors"
SIZES = (24, 32, 40, 48, 60, 64, 80, 96)

# drawings redrawn on their own, used instead of the sheet's: name -> (file,
# its box). The pointing glove, drawn again with a straight finger.
OWN = {
    "glove": ("art/cursors/pointer.jpg", (129, 85, 624, 906)),
}

# measured on the 1254 px sheet: each drawing's box
BOXES = {
    "pencil": (46, 92, 277, 383),
    "glove": (378, 86, 563, 382),
    "ibeam": (738, 133, 811, 356),
    "watch": (964, 81, 1187, 373),
    "pencil-watch": (41, 484, 303, 762),
    "open": (364, 481, 569, 767),
    "fist": (686, 530, 889, 770),
    "star": (967, 498, 1201, 747),
    "loupe": (49, 905, 283, 1138),
    "stamp": (361, 910, 589, 1136),
    "bar": (642, 974, 923, 1081),
    "diagonal": (988, 908, 1212, 1130),
}

# name: (drawing, how big in the cursor box (its longer side), where you click,
#        clear inside too, turn: None | "rot90" | "mirror")
#   click: "tip" (the top-left-most point), "top" (the top-most point), "centre"
CURSORS = {
    "default": ("pencil", 0.92, "tip", False, None),
    "pointer": ("glove", 0.88, "top", False, None),
    "text": ("ibeam", 0.70, "centre", False, None),
    "wait": ("watch", 0.78, "centre", False, None),
    "progress": ("pencil-watch", 0.94, "tip", False, None),
    "grab": ("open", 0.86, "centre", False, None),
    "grabbing": ("fist", 0.78, "centre", False, None),
    "move": ("star", 0.84, "centre", False, None),
    "crosshair": ("loupe", 0.80, "centre", True, None),
    "not-allowed": ("stamp", 0.76, "centre", True, None),
    "ew-resize": ("bar", 0.90, "centre", False, None),
    "ns-resize": ("bar", 0.90, "centre", False, "rot90"),
    "nesw-resize": ("diagonal", 0.86, "centre", False, None),
    "nwse-resize": ("diagonal", 0.86, "centre", False, "mirror"),
}

# the other names programs (GTK, Qt, Firefox, X11, Electron) ask for
ALIASES = {
    "default": ["left_ptr", "arrow", "top_left_arrow", "context-menu", "help", "question_arrow",
                "whats_this", "left_ptr_help", "copy", "alias", "dnd-copy", "dnd-link", "dnd-none",
                "cell", "plus", "vertical-text", "zoom-in", "zoom-out", "center_ptr", "right_ptr",
                "draft", "pencil", "default"],
    "pointer": ["hand1", "hand2", "pointing_hand", "e29285e634086352946a0e7090d73106",
                "9d800788f1b08800ae810202380a0822"],
    "text": ["xterm", "ibeam"],
    "wait": ["watch", "clock"],
    "progress": ["left_ptr_watch", "half-busy", "00000000000000020006000e7e9ffc3f",
                 "08e8e1c95fe2fc01f976f1e063a24ccd", "3ecb610c1bf2410f44200f48c40d3599"],
    "grab": ["openhand", "hand", "5aca4d189052212118709018842178c0", "9141b49c8149039304290b508d208c40"],
    "grabbing": ["closedhand", "dnd-move", "dnd-ask", "fcf21c00b30f7e3f83fe0dfd12e71cff"],
    "move": ["fleur", "all-scroll", "size_all", "4498f0e0c1937ffe01fd06f973665830",
             "9081237383d90e509aa00f00170e968f"],
    "crosshair": ["cross", "tcross", "target", "color-picker", "crosshair"],
    "not-allowed": ["crossed_circle", "forbidden", "no-drop", "circle", "pirate", "X_cursor",
                    "03b6e0fcb3499374a867c041f52298f0"],
    "ew-resize": ["col-resize", "sb_h_double_arrow", "h_double_arrow", "e-resize", "w-resize",
                  "left_side", "right_side", "size_hor", "split_h", "14fef782d02440884392942c11205230",
                  "028006030e0e7ebffc7f7070c0600140"],
    "ns-resize": ["row-resize", "sb_v_double_arrow", "v_double_arrow", "n-resize", "s-resize",
                  "top_side", "bottom_side", "size_ver", "split_v", "2870a09082c103050810ffdffffe0204",
                  "00008160000006810000408080010102"],
    "nesw-resize": ["fd_double_arrow", "ne-resize", "sw-resize", "top_right_corner",
                    "bottom_left_corner", "size_bdiag", "fcf1c3c7cd4491d801f1e1c78f100000"],
    "nwse-resize": ["bd_double_arrow", "nw-resize", "se-resize", "top_left_corner",
                    "bottom_right_corner", "size_fdiag", "c7088f0f3e6c8088236ef8e1e3e70000"],
}


def cut(sheet, box, clear_inside):
    """The drawing on its own: RGBA, the white round it (and inside it, if
    asked) made clear, the edge softened by how white each pixel was."""
    x0, y0, x1, y1 = box
    pad = 8
    im = sheet.crop((x0 - pad, y0 - pad, x1 + pad + 1, y1 + pad + 1))
    a = np.asarray(im).astype(np.float32)
    lo = a.min(axis=2)
    paperish = (lo > 232).astype(np.uint8) * 255
    if clear_inside:
        clear = paperish > 0
    else:
        m = Image.fromarray(paperish, "L").copy()
        w, h = m.size
        for s in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] + [(x, 0) for x in range(0, w, 6)] \
                + [(x, h - 1) for x in range(0, w, 6)] + [(0, y) for y in range(0, h, 6)] + [(w - 1, y) for y in range(0, h, 6)]:
            if m.getpixel(s) == 255:
                ImageDraw.floodfill(m, s, 128)
        clear = np.asarray(m) == 128
    alpha = np.full(lo.shape, 255.0)
    alpha[clear] = 0
    # the fringe next to the clear: as opaque as it is dark
    near = np.asarray(Image.fromarray(clear.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
    fringe = near & ~clear
    alpha[fringe] = np.clip((255 - lo[fringe]) / (255 - 150) * 255, 0, 255)
    rgba = np.dstack([a, alpha]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox())


def straighten_finger(img, until=0.25, fade=0.36):
    """The pointing finger made straight. Above `until` (a fraction of the
    height, where the other fingers begin) each row is redrawn so the finger
    stands plumb over its base with straight, parallel sides: centred on the
    base's middle, and stretched or narrowed to the finger's usual width (the
    rounded tip keeps its own shape). Down to `fade` the correction dies away."""
    a = np.asarray(img).astype(np.float32)
    h, w = a.shape[:2]
    alpha = a[..., 3] > 128
    y_base = int(until * h)
    edges = {}
    for y in range(0, y_base + 1):
        xs = np.nonzero(alpha[y])[0]
        if len(xs):
            edges[y] = (xs.min(), xs.max())
    rows = sorted(edges)
    widths = np.array([edges[y][1] - edges[y][0] for y in rows], np.float32)
    usual = float(np.median(widths[len(widths) // 3:]))
    tip_end = next(y for y, wd in zip(rows, widths) if wd >= 0.92 * usual)
    c0 = (edges[y_base][0] + edges[y_base][1]) / 2
    xs = np.arange(w, dtype=np.float32)
    xs_all = xs
    out = a.copy()

    def resample(y, centre, stretch):
        src = centre + (xs - c0) * stretch
        lo = np.clip(np.floor(src).astype(int), 0, w - 1)
        hi = np.clip(lo + 1, 0, w - 1)
        f = (src - np.floor(src))[:, None]
        row = a[y, lo] * (1 - f) + a[y, hi] * f
        row[(src < 0) | (src > w - 1)] = 0
        return row

    # the tip: a true half-round on the finger's width
    y_top = rows[0]
    radius = usual / 2

    def round_width(y):
        d = radius - (y - y_top + 0.5)
        return 2 * math.sqrt(max(0.0, radius * radius - d * d)) if d > 0 else usual

    last_c, last_s = c0, 1.0
    for y in range(h):
        if y in edges and y <= y_base:
            l, r = edges[y]
            centre = (l + r) / 2
            want = round_width(y) if y < y_top + radius else usual
            stretch = max(0.2, (r - l) / max(1.0, want))
            out[y] = resample(y, centre, stretch)
            last_c, last_s = centre, stretch
        elif y_base < y < fade * h:
            t = (y - y_base) / (fade * h - y_base)
            k = 1 - t * t * (3 - 2 * t)
            out[y] = resample(y, c0 + (last_c - c0) * k, 1 + (last_s - 1) * k)
    # below the other fingertips the finger's left side still runs on down
    # to the palm: drawn plumb too, by moving only the row's left part
    a2 = out.copy()
    left0 = edges[y_base][0]
    al2 = a2[..., 3] > 128
    for y in range(y_base + 1, int(fade * h)):
        xs = np.nonzero(al2[y])[0]
        if not len(xs) or xs.min() < left0 - 3:
            break                                   # the palm swells out here
        l = xs.min()
        if l == left0:
            continue
        # columns left of the finger's middle: [l, c0] drawn onto [left0, c0]
        src = c0 - (c0 - xs_all) * (c0 - l) / max(1.0, c0 - left0)
        part = xs_all < c0
        lo = np.clip(np.floor(src).astype(int), 0, w - 1)
        hi = np.clip(lo + 1, 0, w - 1)
        f = (src - np.floor(src))[:, None]
        row = a2[y, lo] * (1 - f) + a2[y, hi] * f
        row[src < 0] = 0
        out[y, part] = row[part]
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def bigger_cuff(img, top, scale=1.22, angle=0.0):
    """The cuff (the picture below the row `top`, a fraction of its height,
    just above the cuff's top edge) drawn `scale` times bigger, hanging from
    the same place at the wrist. `angle`: how far the cuff is turned
    (degrees, anticlockwise), so a tilted one is enlarged along itself."""
    if angle:
        turned = img.rotate(-angle, expand=True, resample=Image.Resampling.BICUBIC)
        big = bigger_cuff(turned, top, scale)
        back = big.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
        return back.crop(back.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox())
    w, h = img.size
    y0 = int(top * h)
    band = img.crop((0, y0, w, h))
    bw, bh = round(w * scale), round((h - y0) * scale)
    band = band.resize((bw, bh), Image.Resampling.LANCZOS)
    W, H = max(w, bw), y0 + bh
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(img.crop((0, 0, w, y0 + 1)), ((W - w) // 2, 0))
    canvas.alpha_composite(band, ((W - bw) // 2, y0))
    return canvas


# the drawings, touched up: the pointing finger stood straight, the cuffs a
# size bigger (the row just above each cuff's top edge, as a fraction of the
# drawing's height; the fist's cuff is turned 14 degrees)
TOUCH_UP = {
    "open": lambda im: bigger_cuff(im, 0.81),
    "fist": lambda im: bigger_cuff(im, 0.71, angle=-14),
}


def point_of(img, how):
    a = np.asarray(img.getchannel("A")) > 120
    ys, xs = np.nonzero(a)
    if how == "tip":
        i = np.argmin(xs + ys)
        return xs[i], ys[i]
    if how == "top":
        top = ys.min()
        row = xs[ys <= top + 3]
        return row.mean(), top
    return img.width / 2, img.height / 2


def render(img, how, frac, n):
    """img drawn into an n x n cursor; returns (RGBA, hot x, hot y)."""
    scale = frac * n / max(img.width, img.height)
    w, h = max(1, round(img.width * scale)), max(1, round(img.height * scale))
    # down in two steps (a box filter first) so the outline keeps its weight
    small = img.resize((w * 2, h * 2), Image.Resampling.BOX).resize((w, h), Image.Resampling.LANCZOS)
    small = small.filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=1))
    px, py = point_of(img, how)
    px, py = px * scale, py * scale
    canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    if how == "tip":
        ox, oy = round(n * 0.04 - px), round(n * 0.04 - py)
    elif how == "top":
        ox, oy = round(n / 2 - px), round(n * 0.03 - py)
    else:
        ox, oy = round((n - w) / 2), round((n - h) / 2)
    canvas.alpha_composite(small, (max(0, ox), max(0, oy)))
    # a hairline of paper round it, so the thin ones show on dark ground too
    rim = canvas.getchannel("A").point(lambda v: 255 if v > 60 else 0).filter(ImageFilter.MaxFilter(3))
    halo = Image.new("RGBA", (n, n), (0xF4, 0xF1, 0xEA, 0))
    halo.putalpha(rim.point(lambda v: v * 200 // 255))
    halo.alpha_composite(canvas)
    canvas = halo
    hx, hy = min(n - 1, max(0, round(px + max(0, ox)))), min(n - 1, max(0, round(py + max(0, oy))))
    if how == "centre":
        hx, hy = n // 2, n // 2
    return canvas, hx, hy


def xcursor(frames):
    """frames: [(nominal size, RGBA image, hot x, hot y)] -> Xcursor file bytes."""
    head = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(frames))
    toc, chunks = [], []
    pos = 16 + 12 * len(frames)
    for size, img, hx, hy in frames:
        a = np.asarray(img).astype(np.uint32)
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        # premultiplied ARGB, as libXcursor wants it
        r, g, b = r * al // 255, g * al // 255, b * al // 255
        argb = (al << 24) | (r << 16) | (g << 8) | b
        chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, size, 1, img.width, img.height, hx, hy, 0) \
            + argb.astype("<u4").tobytes()
        toc.append(struct.pack("<III", 0xFFFD0002, size, pos))
        chunks.append(chunk)
        pos += len(chunk)
    return head + b"".join(toc) + b"".join(chunks)


def main():
    src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else SHEET
    sheet = Image.open(src).convert("RGB")
    out = THEME / "cursors"
    if out.exists():
        for f in out.iterdir():
            f.unlink()
    out.mkdir(parents=True, exist_ok=True)
    cuts = {}
    previews = []
    for name, (drawing, frac, how, clear, turn) in CURSORS.items():
        key = (drawing, clear)
        if key not in cuts:
            if drawing in OWN:
                path, box = OWN[drawing]
                cuts[key] = cut(Image.open(ROOT / path).convert("RGB"), box, clear)
            else:
                cuts[key] = cut(sheet, BOXES[drawing], clear)
            if drawing in TOUCH_UP:
                cuts[key] = TOUCH_UP[drawing](cuts[key])
        img = cuts[key]
        if turn == "rot90":
            img = img.rotate(90, expand=True)
        elif turn == "mirror":
            img = img.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        frames = []
        for n in SIZES:
            c, hx, hy = render(img, how, frac, n)
            frames.append((n, c, hx, hy))
        (out / name).write_bytes(xcursor(frames))
        previews.append((name, frames))
        for alias in ALIASES.get(name, []):
            if alias != name:
                os.symlink(name, out / alias)
    (THEME / "index.theme").write_text(
        "[Icon Theme]\nName=Archive-Cursors\nComment=The archive's pencil, gloves and instruments\n"
        "Inherits=Adwaita\n")
    print("cursors:", out.relative_to(ROOT), len(CURSORS), "drawn,",
          sum(len(v) for v in ALIASES.values()), "names")
    return previews


if __name__ == "__main__":
    main()
