#!/usr/bin/env python3
"""Make the "Archive" icon theme: Papirus, in aged inks on old paper.

    python3 tools/make_icons.py [papirus dir] [output dir]

Every Papirus icon is kept and recoloured, so nothing goes missing:

  * apps, files, devices ...  muted (about 40 % of their colour), tinted
                              towards sepia, whites turned cream: still
                              recognisable, but printed rather than lit
  * folders                   envelopes: each Papirus folder is redrawn as a
                              kraft envelope torn open along the top, a
                              letter showing (pulled further out when the
                              folder is open), its glyph inked on the front
                              like a stamp (anything not laid out like a
                              Papirus folder is just turned manila)
  * symbolic icons            their greys, warmed a touch

Papirus's links are kept as links, its index.theme renamed, and the theme
falls back to Papirus for anything it does not have. The default output is
~/.local/share/icons/Archive (archive-icons runs this; setup.sh too).
"""
import colorsys
import os
import random
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


# ------------------------------------------------------------------ envelopes
KRAFT_BACK = "#b59a6d"      # the back, seen above the pocket: torn open
KRAFT = "#cbb48e"           # the pocket
FLAP_SIDE = "#c2a882"
FLAP_FOOT = "#d2bd99"
CREASE = "#9c8259"
LETTER = "#ece6da"
LETTER_LINE = "#bfb196"

ELEMENT = re.compile(r"<(rect|path|circle|ellipse|g)\b[^>]*?/>|<g\b.*?</g>", re.S)
NUM = re.compile(r"(-?\d+(?:\.\d+)?)")


def attr(el, name):
    m = re.search(r'\b%s="([^"]*)"' % name, el)
    return m.group(1) if m else None


def rect_of(el):
    try:
        return tuple(float(attr(el, k)) for k in ("x", "y", "width", "height"))
    except (TypeError, ValueError):
        return None


def envelope(text, name):
    """A Papirus folder redrawn as a torn-open envelope, or None when the
    file is not laid out like one: shadow, back, shadow, paper, front,
    highlight, then the glyph."""
    full = [m.group(0) for m in ELEMENT.finditer(text)]
    if len(full) < 6:
        return None
    paper, front, light = full[3], full[4], full[5]
    if not (paper.startswith("<rect") and front.startswith("<rect") and "#e4e4e4" in paper.lower()
            and "opacity:0.1" in light.replace(" ", "")):
        return None
    P, F = rect_of(paper), rect_of(front)
    if not P or not F:
        return None
    ys = [float(y) for _, y in re.findall(r"(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)", attr(full[1], "d") or "")]
    if not ys:
        return None
    top = min(ys)
    m = re.search(r'<svg\b[^>]*?\bwidth="([\d.]+)"', text)
    size = float(m.group(1)) if m else 64
    fx, fy, fw, fh = F
    s = fw / 56                                  # the 64 px design's scale
    small = size <= 24
    rnd = random.Random(name)
    glyph = "".join(full[6:])

    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%g" height="%g" version="1">' % (size, size)]
    out.append(full[0])                          # its shadow on the desk
    def torn(y0, amp, n):
        """A torn edge across the envelope's width, left to right."""
        pts = []
        for i in range(n + 1):
            jag = rnd.uniform(-1, 1) * amp if 0 < i < n else rnd.uniform(0, 0.5) * amp
            pts.append((fx + fw * i / n, y0 + jag))
        return pts

    def path(pts):
        return " L ".join("%.2f,%.2f" % p for p in pts)

    teeth = max(6, int(round(fw / (3.0 * s))))
    amp = max(0.45, 1.0 * s)
    # the back, torn open along the top
    back = torn(top + (fy - top) * 0.32, amp, teeth)
    out.append('<path style="fill:%s" d="M %.2f,%.2f L %s L %.2f,%.2f Z"/>'
               % (KRAFT_BACK, fx, fy + fh, path(back), fx + fw, fy + fh))
    # the letter inside, pulled further out when open
    opened = "-open" in name or "drag-accept" in name
    lx, lw = fx + fw * 0.14, fw * 0.72
    ly = max(0.5, top + (fy - top) * (-0.15 if opened else 0.08))
    out.append('<rect style="fill:%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.2f"/>'
               % (LETTER, lx, ly, lw, fy + fh * 0.5 - ly, 0.4 * s))
    if not small:                                # a few lines of handwriting
        for i in range(3):
            y = ly + (2.6 + 2.4 * i) * s
            if y > fy - 1.2 * s:
                break
            w = lw * (0.72 - 0.16 * i) * rnd.uniform(0.85, 1.0)
            out.append('<rect style="fill:%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f"/>'
                       % (LETTER_LINE, lx + 3 * s, y, w, max(0.5, 0.7 * s)))
    # the pocket, its top torn too
    cx, apex = fx + fw / 2, fy + fh * 0.5
    r = 1.2 * s                                  # envelopes have sharper corners than folders
    edge = torn(fy + amp * 0.6, amp * 0.9, teeth + 3)
    bottom = fy + fh
    out.append('<path style="fill:%s" d="M %.2f,%.2f L %s L %.2f,%.2f Q %.2f,%.2f %.2f,%.2f L %.2f,%.2f Q %.2f,%.2f %.2f,%.2f Z"/>'
               % (KRAFT, fx, bottom - r, path(edge), fx + fw, bottom - r,
                  fx + fw, bottom, fx + fw - r, bottom, fx + r, bottom, fx, bottom, fx, bottom - r))
    if small:
        out.append('<path style="fill:none;stroke:%s;stroke-width:%.2f;opacity:0.7" d="M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f"/>'
                   % (CREASE, max(0.5, 0.9 * s), fx + 0.5, bottom - 0.5, cx, apex, fx + fw - 0.5, bottom - 0.5))
    else:
        flap_top = fy + 2.2 * amp
        out.append('<path style="fill:%s" d="M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f Z"/>'
                   % (FLAP_SIDE, fx, flap_top, cx - 4 * s, apex, fx, bottom - 0.6 * s))
        out.append('<path style="fill:%s" d="M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f Z"/>'
                   % (FLAP_SIDE, fx + fw, flap_top, cx + 4 * s, apex, fx + fw, bottom - 0.6 * s))
        out.append('<path style="fill:%s;stroke:%s;stroke-width:%.2f;stroke-linejoin:round" d="M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f Z"/>'
                   % (FLAP_FOOT, CREASE, 0.45 * s, fx + 0.4 * s, bottom - 0.4 * s, cx, apex - 1.5 * s, fx + fw - 0.4 * s, bottom - 0.4 * s))
        # the paper's fibres, light along the tear
        out.append('<path style="fill:none;stroke:%s;stroke-width:%.2f;stroke-linejoin:round;opacity:0.8" d="M %s"/>'
                   % (LETTER, 0.55 * s, path(edge)))
    # the glyph, inked on like a stamp
    out.append(recolour(glyph, manila))
    out.append("</svg>")
    return "\n".join(out)


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
        fn = kind(rel)
        env = envelope(text, os.path.basename(rel)) if fn is manila else None
        text = env if env else recolour(text, fn)
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
