#!/usr/bin/env python3
"""Make the "Archive" icon theme: Papirus, in aged inks on old paper.

    python3 tools/make_icons.py [papirus dir] [output dir]

Every Papirus icon is kept and recoloured, so nothing goes missing:

  * apps, files, devices ...  muted (about 40 % of their colour), tinted
                              towards sepia, whites turned cream: still
                              recognisable, but printed rather than lit
  * folders                   manila: the blue Papirus folders become
                              buff card, like the archive's own folders
  * symbolic icons            their greys, warmed a touch

Papirus's links are kept as links, its index.theme renamed, and the theme
falls back to Papirus for anything it does not have. The default output is
~/.local/share/icons/Archive (archive-icons runs this; setup.sh too).
"""
import colorsys
import os
import re
import shutil
import sys
from concurrent.futures import ProcessPoolExecutor

SRC = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/icons/Papirus"
DST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
    os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "icons", "Archive")

HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")

# warm paper: what pure white becomes, and the tint mixed into everything
PAPER = (236, 229, 214)
MANILA_HUE = 38 / 360


def parse(h):
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def clamp(v):
    return max(0, min(255, int(round(v))))


def sepia(rgb, amount):
    """Mix towards a sepia print of the same lightness."""
    r, g, b = rgb
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    tone = (lum * 1.07 + 6, lum * 0.99 + 2, lum * 0.84)
    return tuple(c * (1 - amount) + t * amount for c, t in zip(rgb, tone))


def muted(rgb):
    r, g, b = (c / 255 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    s *= 0.42
    l = 0.06 + l * 0.88                     # no pure black, no pure white
    out = [c * 255 for c in colorsys.hls_to_rgb(h, l, s)]
    out = sepia(out, 0.22)
    # whites and near-whites become the paper itself
    lum = 0.299 * out[0] + 0.587 * out[1] + 0.114 * out[2]
    if lum > 205:
        k = (lum - 205) / 50
        out = [c * (1 - k) + p * k for c, p in zip(out, PAPER)]
    return tuple(clamp(c) for c in out)


def manila(rgb):
    r, g, b = (c / 255 for c in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < 0.12:                            # the folder's paper and greys
        return muted(rgb)
    # the blue body: buff card, a little lighter, a little colour
    l = min(0.86, 0.10 + l * 0.95)
    s = 0.30 + 0.10 * s
    out = [c * 255 for c in colorsys.hls_to_rgb(MANILA_HUE, l, s)]
    return tuple(clamp(c) for c in sepia(out, 0.12))


def symbolic(rgb):
    return tuple(clamp(c) for c in sepia(rgb, 0.18))


def recolour(text, fn):
    return HEX.sub(lambda m: "#%02x%02x%02x" % fn(parse(m.group(1))), text)


def kind(rel):
    parts = rel.split(os.sep)
    name = parts[-1]
    if parts[0] == "symbolic":
        return symbolic
    if len(parts) >= 3 and parts[-2] == "places" and (name.startswith("folder") or name.startswith("user-")):
        return manila
    return muted


def work(rel):
    src = os.path.join(SRC, rel)
    dst = os.path.join(DST, rel)
    try:
        with open(src, encoding="utf-8") as f:
            text = f.read()
        text = recolour(text, kind(rel))
        with open(dst, "w", encoding="utf-8") as f:
            f.write(text)
    except (UnicodeDecodeError, OSError):
        shutil.copy2(src, dst)


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"make_icons: no Papirus at {SRC} (sudo pacman -S papirus-icon-theme)")
    if os.path.isdir(DST):
        shutil.rmtree(DST)
    os.makedirs(DST)

    svgs = []
    for root, dirs, files in os.walk(SRC):
        rel_root = os.path.relpath(root, SRC)
        out_root = os.path.join(DST, rel_root) if rel_root != "." else DST
        for d in list(dirs):
            p = os.path.join(root, d)
            if os.path.islink(p):           # a linked folder (the @2x ones): keep the link
                os.symlink(os.readlink(p), os.path.join(out_root, d))
                dirs.remove(d)
            else:
                os.makedirs(os.path.join(out_root, d), exist_ok=True)
        for name in files:
            p = os.path.join(root, name)
            rel = os.path.normpath(os.path.join(rel_root, name))
            if os.path.islink(p):
                os.symlink(os.readlink(p), os.path.join(DST, rel))
            elif name.endswith(".svg"):
                svgs.append(rel)
            elif name not in ("icon-theme.cache", "index.theme"):
                shutil.copy2(p, os.path.join(DST, rel))

    with ProcessPoolExecutor() as pool:
        list(pool.map(work, svgs, chunksize=256))

    with open(os.path.join(SRC, "index.theme"), encoding="utf-8") as f:
        index = f.read()
    index = re.sub(r"^Name=.*$", "Name=Archive", index, count=1, flags=re.M)
    index = re.sub(r"^Comment=.*$", "Comment=Papirus in aged inks on old paper (archive theme)", index, count=1, flags=re.M)
    index = re.sub(r"^Inherits=(.*)$", r"Inherits=Papirus,\1", index, count=1, flags=re.M)
    with open(os.path.join(DST, "index.theme"), "w", encoding="utf-8") as f:
        f.write(index)
    print(f"icons: {len(svgs)} recoloured into {DST}")


if __name__ == "__main__":
    main()
