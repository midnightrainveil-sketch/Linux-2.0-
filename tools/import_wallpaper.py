#!/usr/bin/env python3
"""Turn art/wallpaper.webp into the starter plate: the whole sheet, by day
and as a cyanotype by night.

    python3 tools/import_wallpaper.py

The wallpaper is used as drawn, with its own typed header, labels, stamp and
tape, so the shell types nothing over it (meta.json "sheet": true).

  sheet-day.jpg    the sheet, upscaled 2x and toned to the desk's grey paper
  sheet-night.jpg  the same sheet printed as a cyanotype: Prussian-blue paper,
                   the drawing and type in pale cream, the paper's own
                   mottling and specks kept
  meta.json        names and the plate number, for the shell's other cards

The screen crops the sheet to fill (the G14 is 16:10, the art 16:9): a little
of each side goes, never the plant. Requires: python3, numpy, pillow.
"""
import json
import os

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "art", "wallpaper.webp")
OUT = os.path.join(HERE, "..", "dotfiles", ".local", "share", "archive", "plates")
PLATE = "0001-geranium-pratense"
UPSCALE = 2

# the desk's paper (Theme.paperBase is c9c7c3; the reference desk reads about
# cbc9c5 around the plate) and the night sheet's colours (Theme.nite)
DAY_PAPER = np.array([203, 201, 197], np.float32)
NIGHT_PAPER = np.array([0x1c, 0x2f, 0x4d], np.float32)
NIGHT_INK = np.array([0xe6, 0xe1, 0xd6], np.float32)


def main():
    src = Image.open(SRC).convert("RGB")
    big = src.resize((src.width * UPSCALE, src.height * UPSCALE), Image.LANCZOS)
    big = big.filter(ImageFilter.UnsharpMask(radius=1.4, percent=55, threshold=2))
    rgb = np.asarray(big, np.float32)

    # the paper's own colour, everywhere (the ink lifted out of it)
    gray = big.convert("L")
    paper_l = np.asarray(gray.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(24)), np.float32)
    paper_rgb = np.median(rgb.reshape(-1, 3), axis=0)

    # ---- day: tone the sheet so its paper matches the desk
    gain = DAY_PAPER / paper_rgb
    day = np.clip(rgb * gain, 0, 255).astype(np.uint8)

    # ---- night: a cyanotype print of the same sheet
    lum = rgb.mean(axis=2)
    paper_l = np.maximum(paper_l, lum)
    ink = np.clip((paper_l - lum) / np.maximum(paper_l, 1), 0, 1)       # 0 paper .. 1 solid ink
    ink = np.clip(ink * 1.25, 0, 1) ** 0.85
    # the paper's mottling, carried over as a faint unevenness of the blue
    mottle = (paper_l - paper_l.mean()) / 255.0
    base = NIGHT_PAPER[None, None, :] * (1 + 0.9 * mottle[..., None])
    night = base * (1 - ink[..., None]) + NIGHT_INK[None, None, :] * ink[..., None]
    night = np.clip(night, 0, 255).astype(np.uint8)

    folder = os.path.join(OUT, PLATE)
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):
        if name.endswith(".png") or name.startswith("sheet-"):
            os.remove(os.path.join(folder, name))
    Image.fromarray(day).save(os.path.join(folder, "sheet-day.jpg"), quality=90, optimize=True, progressive=True)
    Image.fromarray(night).save(os.path.join(folder, "sheet-night.jpg"), quality=90, optimize=True, progressive=True)

    meta = {
        "number": "0001",
        "region": "FLORA EUROPAEA",
        "latin": "Geranium pratense",
        "authority": "Linnaeus, 1753.",
        "family": "Geraniaceae",
        "common": "European meadow cranesbill.",
        # the whole sheet is the wallpaper: the shell types no labels over it
        "sheet": True,
        "day": "sheet-day.jpg",
        "night": "sheet-night.jpg",
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
    print("plate written:", folder, day.shape[1], "x", day.shape[0])


if __name__ == "__main__":
    main()
