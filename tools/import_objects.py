#!/usr/bin/env python3
"""Turn the phonograph and typewriter artwork into the shell's assets.

    python3 tools/import_objects.py

    art/phonograph/turntable.webp   the turntable deck from straight above,
                                    square, the plinth filling the frame
    art/phonograph/tonearm.webp     the tone arm from above, horizontal, on white
    art/typewriter/typewriter.webp  the typewriter from the front, on white

Writes dotfiles/.config/quickshell/assets/phonograph/turntable.jpg and
tonearm.png, and assets/typewriter/typewriter.png: toned to sit on the
pencil-and-grey desk like the drawer, the white keyed out (a grey shadow
on the white kept as a soft transparent shadow). The frames are kept as
they are, so the places measured on the originals (printed below, and
written into Turntable.qml and Typewriter.qml) still hold.
"""
import pathlib

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art"
ASSETS = ROOT / "dotfiles" / ".config" / "quickshell" / "assets"

WOOD_TONE = dict(saturation=0.72, contrast=0.9, lift=8)
BRASS_TONE = dict(saturation=0.7, contrast=0.92, lift=4)
ENAMEL_TONE = dict(saturation=0.78, contrast=0.92, lift=6)


def tone(img, saturation, contrast, lift):
    """Less colour, a little less contrast, a little lighter (alpha kept)."""
    a = np.asarray(img).astype(np.float32)
    rgb = a[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    rgb = lum[..., None] + (rgb - lum[..., None]) * saturation
    mean = lum.mean()
    rgb = mean + (rgb - mean) * contrast + lift
    a[..., :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(a.astype(np.uint8), img.mode)


def keyed(path, floor=None):
    """The object on white: the white around it (reached from the frame's
    edges, so the chrome's highlights stay) made transparent; its grey
    shadow on the white kept as a soft dark shadow. Below `floor` (a row),
    where it stands, any plain grey reached from the white is shadow too."""
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    lo, hi = a.min(axis=2), a.max(axis=2)
    lum = a.mean(axis=2)
    paper = (lo > 190) & (hi - lo < 22)
    if floor is not None:
        below = np.zeros_like(paper)
        below[floor:] = True
        paper |= below & (lum > 100) & (hi - lo < 14)
    paper = paper.astype(np.uint8) * 255
    mask = Image.fromarray(paper, "L").copy()   # (a copy: fromarray may share the read-only buffer)
    w, h = mask.size
    seeds = [(x, 0) for x in range(0, w, 4)] + [(x, h - 1) for x in range(0, w, 4)] \
        + [(0, y) for y in range(0, h, 4)] + [(w - 1, y) for y in range(0, h, 4)]
    for s in seeds:
        if mask.getpixel(s) == 255:
            ImageDraw.floodfill(mask, s, 128)
    around = np.asarray(mask) == 128
    alpha = np.full(lum.shape, 255.0)
    shade = np.clip((250 - lum) / 110, 0, 1) * 0.7
    alpha[around] = shade[around] * 255
    rgb = a.astype(np.float32)
    rgb[around] = (22, 20, 18)
    out = np.dstack([rgb, alpha]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def turntable():
    src = Image.open(ART / "phonograph" / "turntable.webp").convert("RGB")
    out = tone(src, **WOOD_TONE).resize((1140, 1140), Image.Resampling.LANCZOS)
    dst = ASSETS / "phonograph" / "turntable.jpg"
    dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, quality=90)
    # measured on the 1254 px original: the spindle (552, 582), the felt
    # 452 px round it, the arm's mount (1093, 183), the knob (1120, 1060)
    # r 48, the brass plate (50, 50)-(237, 152)
    print("turntable:", dst.relative_to(ROOT))


def tonearm():
    img = tone(keyed(ART / "phonograph" / "tonearm.webp"), **BRASS_TONE)
    # 2000 x 500, pivot (383, 200), stylus (1770, 240): kept at 0.447
    out = img.resize((894, 224), Image.Resampling.LANCZOS)
    dst = ASSETS / "phonograph" / "tonearm.png"
    out.save(dst, optimize=True)
    print("tone arm:", dst.relative_to(ROOT))


def typewriter():
    img = tone(keyed(ART / "typewriter" / "typewriter.webp", floor=930), **ENAMEL_TONE)
    dst = ASSETS / "typewriter" / "typewriter.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst, optimize=True)
    # measured on the 1586 x 992 original: keys QWERTYUIOP x 388..1192 at
    # y 557, ASDFGHJKL 420..1153 at 641, ZXCVBNM 455..1017 at 722, r 34;
    # the space bar (402, 785)-(1180, 840); the type guide (782, 200); the
    # platen's top y 95
    print("typewriter:", dst.relative_to(ROOT))


if __name__ == "__main__":
    turntable()
    tonearm()
    typewriter()
