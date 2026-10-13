#!/usr/bin/env python3
"""Turn art/wallpaper.webp into the starter plate (0001, Geranium pratense).

    python3 tools/import_wallpaper.py

The generated wallpaper is a whole sheet with the plant in the centre third,
but it also carries typed labels, a stamp and scale marks, and some of that
text says "Herbarium", which the spec keeps off the screen. So only the plant
column is kept. The text inside it is painted out, and the drawing becomes the
usual plate layers. The shell then types its own live labels around it.

  ink.png          the pencil drawing as alpha (graphite by day, cream at night)
  silhouette.png   the filled plant, printed as a photogram at night
  meta.json        names, specimen label, tape strips, scale marks, plate box
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "art", "wallpaper.webp")
OUT = os.path.join(HERE, "..", "dotfiles", ".local", "share", "archive", "plates")
PLATE = "0001-geranium-pratense"

# in source pixels (1672 x 941)
CROP = (630, 55, 1120, 895)                       # the plant and its detail studies
TEXT = [                                          # typed text inside or near the crop
    (630, 0, 830, 86),                            # FLORA EUROPAEA / Herbarium.
    (1075, 0, 1200, 72),                          # Tab. XLVII.
    (1065, 445, 1110, 475),                       # 1:1
    (1080, 575, 1125, 605),                       # 2:1
    (1060, 680, 1105, 710),                       # 2:1
    (905, 730, 1180, 875),                        # the specimen label box
    (560, 645, 770, 790),                         # Latin name and authority
]
UPSCALE = 2


def main():
    src = Image.open(SRC).convert("RGB")
    sw, sh = src.size

    # paint the text out with the surrounding paper
    gray = src.convert("L")
    paper = gray.filter(ImageFilter.MaxFilter(21)).filter(ImageFilter.GaussianBlur(25))
    mask = Image.new("L", src.size, 0)
    d = ImageDraw.Draw(mask)
    for box in TEXT:
        d.rectangle(box, fill=255)
    clean = Image.composite(paper, gray, mask)

    # the plant column, upscaled so the lines stay fine on a 2880 px panel
    col = clean.crop(CROP)
    col = col.resize((col.width * UPSCALE, col.height * UPSCALE), Image.LANCZOS)
    col = col.filter(ImageFilter.UnsharpMask(radius=1.6, percent=60, threshold=2))
    g = np.asarray(col, np.float32) / 255
    bg = np.asarray(col.filter(ImageFilter.MaxFilter(25)).filter(ImageFilter.GaussianBlur(30)), np.float32) / 255
    bg = np.maximum(bg, g)
    ink = np.clip((bg - g) / np.maximum(bg, 0.2), 0, 1)
    ink = np.clip((ink - 0.10) / 0.58, 0, 1) ** 0.85

    # silhouette: the drawing thickened and softened, a photogram's glow
    sil = Image.fromarray(((ink > 0.25) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(3))

    folder = os.path.join(OUT, PLATE)
    os.makedirs(folder, exist_ok=True)
    for name in ("ink.png", "wash.png", "silhouette.png"):
        p = os.path.join(folder, name)
        if os.path.exists(p):
            os.remove(p)

    def alpha_png(a, name):
        img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)) if isinstance(a, np.ndarray) else a
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        out.putalpha(img)
        out.save(os.path.join(folder, name), optimize=True)

    alpha_png(ink, "ink.png")
    alpha_png(sil, "silhouette.png")

    x0, y0, x1, y1 = CROP
    cw, ch = x1 - x0, y1 - y0

    def rel(x, y):
        return round((x - x0) / cw, 3), round((y - y0) / ch, 3)

    tapes = []          # the tape strips are part of the drawing itself
    marks = []
    for (x, y), text in (((1072, 450), "1:1"), ((1086, 580), "2:1"), ((1066, 685), "2:1")):
        mx, my = rel(x, y)
        marks.append({"text": text, "x": mx, "y": my})

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
        # where the plant sat on the 16:9 source sheet, as fractions of the screen
        "box": [round(x0 / sw, 4), round(y0 / sh, 4), round(x1 / sw, 4), round(y1 / sh, 4)],
        "wash": False,
        "silhouette": True,
        "tapes": tapes,
        "marks": marks,
    }
    with open(os.path.join(folder, "meta.json"), "w") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")

    index_path = os.path.join(OUT, "index.json")
    index = json.load(open(index_path)) if os.path.exists(index_path) else []
    if PLATE not in index:
        index.append(PLATE)
    with open(index_path, "w") as f:
        json.dump(sorted(index), f, indent=2)
        f.write("\n")
    print("plate written:", folder, ink.shape)


if __name__ == "__main__":
    main()
