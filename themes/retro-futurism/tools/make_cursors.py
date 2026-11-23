#!/usr/bin/env python3
"""The pointer cursors, from their mock-up sheet (art/Cursors.png): an Xcursor
theme, "Magnetic88", for Hyprland, the shell and every app.

    python3 tools/make_cursors.py art/Cursors.png home/.local/share/icons/Magnetic88

Each cursor is cut off the sheet's white ground (by its outline, flooded in
from round it, so the chrome's white highlights inside stay; the holes
through a ring are let through), given its hotspot, and written as an Xcursor
file at several sizes (24 to 96 px, for any scale). The busy ring turns (12
frames), the background-work one's small ring too. The names apps and
toolkits ask for (CSS names, the old X11 ones, Qt's and GTK's) are links to
the files. Python only: no xcursorgen needed.
(pip: numpy pillow opencv-python-headless)
"""
import os, struct, sys
import numpy as np, cv2
from PIL import Image
from collections import deque

src, out = sys.argv[1:3]
sheet = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
SIZES = [24, 28, 32, 36, 42, 48, 64, 96]     # (28 at a scale of 1.5 is 42)

# name: (search box on the sheet, hotspot as a fraction of the cut cursor or
# "tip" (its top-left point) or "centre")
CURSORS = {
    # sheet A: everyday
    'default':        ((75, 70, 190, 178), 'tip'),
    'pointer':        ((290, 62, 405, 175), (0.36, 0.03)),
    'text':           ((535, 72, 625, 175), 'centre'),
    'vertical-text':  ((72, 222, 202, 298), 'centre'),
    'wait':           ((288, 203, 412, 308), 'centre'),
    'progress':       ((512, 203, 655, 308), 'tip'),
    'help':           ((78, 333, 208, 430), 'tip'),
    'not-allowed':    ((292, 338, 408, 432), 'centre'),
    'crosshair':      ((518, 333, 642, 432), 'centre'),
    'move':           ((72, 453, 202, 562), 'centre'),
    'grab':           ((286, 453, 404, 560), (0.5, 0.45)),
    'grabbing':       ((516, 463, 640, 558), (0.5, 0.45)),
    # sheet B: resizing and special
    'ew-resize':      ((778, 78, 897, 152), 'centre'),
    'ns-resize':      ((966, 63, 1048, 158), 'centre'),
    'nwse-resize':    ((1122, 68, 1218, 154), 'centre'),
    'nesw-resize':    ((1288, 68, 1382, 154), 'centre'),
    'n-resize':       ((798, 198, 878, 280), (0.5, 0.04)),
    's-resize':       ((962, 198, 1048, 280), (0.5, 0.96)),
    'e-resize':       ((1118, 208, 1218, 270), (0.96, 0.5)),
    'w-resize':       ((1288, 208, 1388, 270), (0.04, 0.5)),
    'ne-resize':      ((798, 316, 888, 394), (0.95, 0.05)),
    'nw-resize':      ((958, 316, 1048, 394), (0.05, 0.05)),
    'se-resize':      ((1128, 316, 1218, 394), (0.95, 0.95)),
    'sw-resize':      ((1292, 316, 1383, 394), (0.05, 0.95)),
    'col-resize':     ((772, 438, 902, 552), 'centre'),
    'row-resize':     ((948, 438, 1062, 554), 'centre'),
    'zoom-in':        ((1102, 438, 1228, 554), (0.36, 0.36)),
    'zoom-out':       ((1272, 438, 1398, 554), (0.36, 0.36)),
    # sheet C: supplementary
    'copy':           ((322, 688, 442, 797), (0.08, 0.08)),
    'alias':          ((532, 688, 668, 797), (0.08, 0.08)),
    'context-menu':   ((758, 693, 892, 794), (0.08, 0.08)),
    'cell':           ((978, 688, 1122, 797), 'centre'),
    'all-scroll':     ((312, 828, 452, 954), 'centre'),
    'no-drop':        ((542, 843, 658, 952), 'centre'),
    'up-arrow':       ((768, 838, 878, 954), (0.5, 0.02)),
    'dnd-move':       ((982, 838, 1118, 954), 'tip'),
}

# the names asked for, each a link to one of the files above
ALIASES = {
    'default': ['left_ptr', 'arrow', 'top_left_arrow', 'left-arrow', 'x-cursor', 'X_cursor', 'right_ptr', 'draft_large', 'draft_small'],
    'pointer': ['hand', 'hand1', 'hand2', 'pointing_hand', 'e29285e634086352946a0e7090d73106', '9d800788f1b08800ae810202380a0822'],
    'text': ['xterm', 'ibeam'],
    'vertical-text': [],
    'wait': ['watch', 'clock'],
    'progress': ['left_ptr_watch', 'half-busy', '08e8e1c95fe2fc01f976f1e063a24ccd', '3ecb610c1bf2410f44200f48c40d3599', '00000000000000020006000e7e9ffc3f'],
    'help': ['question_arrow', 'whats_this', 'left_ptr_help', 'd9ce0ab605698f320427677b458ad60b', '5c6cd98b3f3ebcb1f9c7f1c204630408'],
    'not-allowed': ['crossed_circle', 'forbidden', 'circle', '03b6e0fcb3499374a867c041f52298f0'],
    'crosshair': ['cross', 'tcross', 'cross_reverse', 'diamond_cross', 'target', 'color-picker'],
    'move': ['fleur', 'size_all', 'pointer-move', '4498f0e0c1937ffe01fd06f973665830', '9081237383d90e509aa00f00170e968f'],
    'grab': ['openhand', 'hand-grab', '5aca4d189052212118709018842178c0', '208530c400c041818281048008011002'],
    'grabbing': ['closedhand', 'dnd-none', 'hand-grabbing', 'fcf21c00b30f7e3f83fe0dfd12e71cff'],
    'ew-resize': ['h_double_arrow', 'sb_h_double_arrow', 'size_hor', 'col-resize-alt', 'e-w-resize', '028006030e0e7ebffc7f7070c0600140', '14fef782d02440884392942c11205230'],
    'ns-resize': ['v_double_arrow', 'sb_v_double_arrow', 'size_ver', 'n-s-resize', '00008160000006810000408080010102', '2870a09082c103050810ffdffffe0204'],
    'nwse-resize': ['size_fdiag', 'bd_double_arrow', 'nw-se-resize', 'c7088f0f3e6c8088236ef8e1e3e70000'],
    'nesw-resize': ['size_bdiag', 'fd_double_arrow', 'ne-sw-resize', 'fcf1c3c7cd4491d801f1e1c78f100000'],
    'n-resize': ['top_side'],
    's-resize': ['bottom_side'],
    'e-resize': ['right_side'],
    'w-resize': ['left_side'],
    'ne-resize': ['top_right_corner'],
    'nw-resize': ['top_left_corner'],
    'se-resize': ['bottom_right_corner'],
    'sw-resize': ['bottom_left_corner'],
    'col-resize': ['split_h', 'sb_h_arrow', '043a9f68147c53184671403ffa811cc5'],
    'row-resize': ['split_v', 'sb_v_arrow', 'c07385c7ba0bd3ef4abb06fa66ccc3f2'],
    'zoom-in': ['zoom_in'],
    'zoom-out': ['zoom_out'],
    'copy': ['dnd-copy', 'copy_drop', '1081e37283d90000800003c07f3ef6bf', '6407b0e94181790501fd1e167b474872'],
    'alias': ['dnd-link', 'link', 'link_drop', '3085a0e285430894940527032f8b26df', '640fb0e74195791501fd1ed57b41487f'],
    'context-menu': [],
    'cell': ['plus'],
    'all-scroll': [],
    'no-drop': ['dnd-no-drop', 'forbidden-drop'],
    'up-arrow': ['center_ptr', 'sb_up_arrow'],
    'dnd-move': ['dnd-ask', 'move_drop', 'dnd_move'],
}


# the cursors with a hole right through them (a ring's middle); in the others
# the white is the chrome's highlight
HOLES = {'wait', 'progress', 'dnd-move'}
# the one drawn partly in thin light lines (its dashed box): not peeled
THIN = {'dnd-move'}


def cut(box, holes=False, peel=True):
    """the cursor in box off the white: RGBA, at the sheet's size"""
    x0, y0, x1, y1 = box
    part = sheet[y0:y1, x0:x1]
    L = part.mean(2)
    sat = part.max(2) - part.min(2)
    h, w = L.shape

    def flood(free):
        """what of free is reached from the box's edge"""
        got = np.zeros((h, w), bool)
        q = deque([(x, y) for x in range(w) for y in (0, h - 1) if free[y, x]] +
                  [(x, y) for y in range(h) for x in (0, w - 1) if free[y, x]])
        for x, y in q: got[y, x] = True
        while q:
            x, y = q.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and free[ny, nx] and not got[ny, nx]:
                    got[ny, nx] = True; q.append((nx, ny))
        return got

    # its body: what is darker or more coloured than the sheet, closed; all
    # it encloses (its highlights) is it
    core = (L < (226 if not peel else 214)) | (sat > 22)        # (the thin-lined ones: their faint lines too)
    core = cv2.morphologyEx(core.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool)
    outside = flood(~core)
    outer = outside.copy()                        # (round it, not through it)
    if holes:
        # a ring's middle: an enclosed patch of the sheet's own white
        white = (L > 246) & (sat < 10)
        n, lab, st, _ = cv2.connectedComponentsWithStats((~core).astype(np.uint8), connectivity=4)
        for i in range(1, n):
            m = lab == i
            if not outside[m].any() and (white & m).sum() > 60:
                outside |= m
    body = ~outside
    # its rim peeled: the sheet's soft shadow runs nearly as dark as its
    # chrome close to it, so a pixel or three of it came along; light grey
    # pixels on the rim go, a layer at a time, until its dark outline
    shadowy = (L > 150) & (sat < 28)
    cross = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
    for _ in range(3 if peel else 0):
        rim = body & cv2.dilate(outer.astype(np.uint8), cross).astype(bool)
        body &= ~(rim & shadowy)
        outer |= rim & shadowy
    outside |= ~body & ~outside & cv2.dilate(outside.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
    n, lab, st, _ = cv2.connectedComponentsWithStats(body.astype(np.uint8), connectivity=8)
    keep = np.zeros((h, w), bool)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] > 40:
            keep |= lab == i

    # its edge: the outermost pixels are its outline mixed with the sheet's
    # white; each is taken apart into the outline's colour (from just inside)
    # and how much of it covers the pixel
    k3 = np.ones((3, 3), np.uint8)
    inner = cv2.erode(keep.astype(np.uint8), k3, iterations=2).astype(bool)
    band = cv2.dilate(keep.astype(np.uint8), k3).astype(bool) & ~inner
    filled = cv2.inpaint(part.clip(0, 255).astype(np.uint8), band.astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA).astype(np.float32)
    Lf = filled.mean(2)
    cover = np.clip((252 - L) / np.maximum(252 - Lf, 30), 0, 1)
    a = np.where(inner, 1.0, np.where(band, cover, 0.0)).astype(np.float32)
    colour = np.where(inner[..., None], part, filled)

    # (no shadow here: a clean, even one is drawn at each size, see shaped())
    alpha = a
    ys, xs = np.where(alpha > 0.04)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    rgba = np.dstack([colour, alpha * 255])[by0:by1, bx0:bx1]
    return Image.fromarray(rgba.clip(0, 255).astype('uint8'), 'RGBA')


def hotspot(im, spec):
    w, h = im.size
    if spec == 'centre':
        return w / 2, h / 2
    if spec == 'tip':
        a = np.asarray(im)[..., 3]
        ys, xs = np.where(a > 128)
        i = np.argmin(xs + ys)                      # the point nearest the top left
        return float(xs[i]), float(ys[i])
    return spec[0] * w, spec[1] * h


def turn(im, deg):
    """turned about its middle, its colours kept off its clear edges"""
    return im.convert('RGBa').rotate(-deg, resample=Image.BICUBIC, center=(im.width / 2, im.height / 2)).convert('RGBA')


def shaped(f, k, size):
    """f scaled by k (its colours kept off its clear edges), its edge made
    crisp, and a small even shadow laid under it (down and a little right)"""
    fw, fh = max(1, round(f.width * k)), max(1, round(f.height * k))
    small = np.asarray(f.convert('RGBa').resize((fw, fh), Image.LANCZOS)).astype(np.float32) / 255
    a = small[..., 3]
    # crisp: the edge's soft ramp narrowed (its colour, premultiplied, with it)
    a2 = np.clip((a - 0.10) / 0.78, 0, 1)
    rgb = small[..., :3] * (a2 / np.maximum(a, 1e-4))[..., None]
    s = size / 32
    pad = max(2, round(2 * s))
    A = np.zeros((fh + 2 * pad, fw + 2 * pad), np.float32)
    C = np.zeros((fh + 2 * pad, fw + 2 * pad, 3), np.float32)
    A[pad:pad + fh, pad:pad + fw] = a2
    C[pad:pad + fh, pad:pad + fw] = rgb
    dx, dy = max(1, round(0.6 * s)), max(1, round(1.0 * s))
    sh = np.roll(np.roll(A, dy, 0), dx, 1)
    sh = cv2.GaussianBlur(sh, (0, 0), max(0.6, 0.8 * s)) * 0.36
    out_a = A + sh * (1 - A)
    out_c = C / np.maximum(out_a, 1e-4)[..., None]                    # (the shadow is black)
    im = np.dstack([out_c * 255, out_a * 255]).clip(0, 255).astype('uint8')
    return Image.fromarray(im, 'RGBA'), pad


def frames_of(name, im):
    """an animated cursor's frames (the busy ring turning), else just it"""
    if name == 'wait':
        return [turn(im, k * 30) for k in range(12)]
    if name == 'progress':
        # its small ring, at the lower right, turning; the arrow still
        a = np.asarray(im)
        w, h = im.size
        rx0, ry0 = int(w * 0.52), int(h * 0.40)
        ring = im.crop((rx0, ry0, w, h))
        base = Image.fromarray(a.copy()); base.paste((0, 0, 0, 0), (rx0, ry0, w, h))
        # what of the arrow lay in that corner, kept
        arrow = Image.fromarray(a.copy())
        frames = []
        for k in range(12):
            f = base.copy()
            r = turn(ring, k * 30)
            f.alpha_composite(r, (rx0, ry0))
            frames.append(f)
        return frames
    return [im]


def xcursor(images):
    """images: [(size, xhot, yhot, delay, RGBA Image)] -> Xcursor bytes"""
    chunks = []
    for size, xh, yh, delay, im in images:
        w, h = im.size
        a = np.asarray(im).astype(np.uint32)
        # premultiplied ARGB, little-endian
        alpha = a[..., 3]
        r = a[..., 0] * alpha // 255; g = a[..., 1] * alpha // 255; b = a[..., 2] * alpha // 255
        argb = (alpha << 24) | (r << 16) | (g << 8) | b
        body = struct.pack('<IIIIIIIII', 36, 0xfffd0002, size, 1, w, h, xh, yh, delay) + argb.astype('<u4').tobytes()
        chunks.append((size, body))
    header = 16
    toc = 12 * len(chunks)
    pos = header + toc
    out_ = struct.pack('<4sIII', b'Xcur', 16, 0x10000, len(chunks))
    for size, body in chunks:
        out_ += struct.pack('<III', 0xfffd0002, size, pos)
        pos += len(body)
    for _, body in chunks:
        out_ += body
    return out_


cursors_dir = os.path.join(out, 'cursors')
os.makedirs(cursors_dir, exist_ok=True)
previews = []
for name, (box, spec) in CURSORS.items():
    im = cut(box, name in HOLES, name not in THIN)
    hx, hy = hotspot(im, spec)
    frames = frames_of(name, im)
    images = []
    for size in SIZES:
        # each fits a size x size square (with room for its shadow), placed
        # so its hotspot stays where it is
        room = max(2, round(2 * size / 32)) + max(1, round(size / 32))
        k = (size - room) / max(im.size)
        for f in frames:
            small, pad = shaped(f, k, size)
            fw, fh = small.size
            canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            if spec == 'centre':
                ox, oy = (size - fw) // 2, (size - fh) // 2
            else:
                ox, oy = 0, 0
            canvas.alpha_composite(small, (ox, oy)) if ox >= 0 and oy >= 0 else canvas.paste(small, (ox, oy))
            xh = min(size - 1, max(0, round(ox + pad + hx * k)))
            yh = min(size - 1, max(0, round(oy + pad + hy * k)))
            images.append((size, xh, yh, 60 if len(frames) > 1 else 0, canvas))
    with open(os.path.join(cursors_dir, name), 'wb') as fh:
        fh.write(xcursor(images))
    for alias in ALIASES.get(name, []):
        p = os.path.join(cursors_dir, alias)
        if os.path.lexists(p):
            os.remove(p)
        os.symlink(name, p)
    previews.append((name, im, (hx, hy)))

with open(os.path.join(out, 'index.theme'), 'w') as fh:
    fh.write('[Icon Theme]\nName=Magnetic88\nComment=Magnetic 88: chrome and sage cursors\nInherits=Adwaita\n')

# a contact sheet of what was cut, each with its hotspot marked (for a look)
if os.environ.get('CURSOR_SHEET'):
    cell = 140
    cols = 9
    rows = (len(previews) + cols - 1) // cols
    cs = Image.new('RGBA', (cols * cell, rows * cell), (58, 54, 50, 255))
    from PIL import ImageDraw
    d = ImageDraw.Draw(cs)
    for i, (name, im, (hx, hy)) in enumerate(previews):
        k = min(1, 110 / max(im.size))
        s = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        x, y = (i % cols) * cell + 15, (i // cols) * cell + 10
        cs.alpha_composite(s, (x, y))
        d.ellipse([x + hx * k - 3, y + hy * k - 3, x + hx * k + 3, y + hy * k + 3], outline=(255, 40, 40, 255), width=2)
        d.text((x, y + 116), name, fill=(230, 230, 230, 255))
    cs.save(os.environ['CURSOR_SHEET'])
print(len(CURSORS), 'cursors,', sum(len(v) for v in ALIASES.values()), 'names linked')
