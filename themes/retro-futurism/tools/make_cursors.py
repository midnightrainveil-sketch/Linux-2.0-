#!/usr/bin/env python3
"""The pointer cursors: Bibata Modern Ice (github.com/ful1e5/Bibata_Cursor,
GPL-3.0), recoloured to Magnetic 88's cream with a warm dark outline, as the
Xcursor theme "Magnetic88".

    curl -LO https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz
    tar xf Bibata-Modern-Ice.tar.xz
    python3 tools/make_cursors.py Bibata-Modern-Ice home/.local/share/icons/Magnetic88

Every image of every cursor has its greys mapped from dark to light onto the
theme's ink to its cream (their see-through edges kept). Sizes 24 to 64 px
are kept (28, the theme's size, is 42 on the G14's 1.5 scale); the busy
cursors keep every second frame at twice the delay, so they turn at the same
speed in half the space. The names that link to each file are kept as they
are. Python only. (pip: numpy)
"""
import os, shutil, struct, sys
import numpy as np

src, out = sys.argv[1:3]
KEEP = {24, 28, 32, 40, 48, 56, 64}
INK = np.array([44, 40, 36], np.float32)          # the outline: warm near-black
CREAM = np.array([242, 234, 217], np.float32)     # the fill: the theme's cream


def read(path):
    b = open(path, 'rb').read()
    magic, hlen, ver, n = struct.unpack('<4sIII', b[:16])
    assert magic == b'Xcur', path
    images = []
    for i in range(n):
        typ, sub, pos = struct.unpack('<III', b[16 + 12 * i:28 + 12 * i])
        if typ != 0xfffd0002:
            continue
        _, _, size, _, w, h, xh, yh, delay = struct.unpack('<IIIIIIIII', b[pos:pos + 36])
        px = np.frombuffer(b[pos + 36:pos + 36 + w * h * 4], '<u4').reshape(h, w)
        images.append([size, w, h, xh, yh, delay, px])
    return images


def recolour(px):
    """premultiplied ARGB: its grey (dark to light) onto ink to cream"""
    a = ((px >> 24) & 255).astype(np.float32)
    rgb = np.dstack([(px >> 16) & 255, (px >> 8) & 255, px & 255]).astype(np.float32)
    rgb = rgb * 255 / np.maximum(a, 1)[..., None]                  # straight colour
    t = (rgb.mean(2, keepdims=True) / 255).clip(0, 1)
    rgb = INK + (CREAM - INK) * t
    rgb = rgb * (a / 255)[..., None]                               # premultiplied again
    r, g, bl = (rgb[..., i].round().clip(0, 255).astype(np.uint32) for i in range(3))
    return (a.astype(np.uint32) << 24) | (r << 16) | (g << 8) | bl


def write(path, images):
    chunks = []
    for size, w, h, xh, yh, delay, px in images:
        body = struct.pack('<IIIIIIIII', 36, 0xfffd0002, size, 1, w, h, xh, yh, delay) + px.astype('<u4').tobytes()
        chunks.append((size, body))
    data = struct.pack('<4sIII', b'Xcur', 16, 0x10000, len(chunks))
    pos = 16 + 12 * len(chunks)
    for size, body in chunks:
        data += struct.pack('<III', 0xfffd0002, size, pos)
        pos += len(body)
    data += b''.join(body for _, body in chunks)
    open(path, 'wb').write(data)


sd, od = os.path.join(src, 'cursors'), os.path.join(out, 'cursors')
shutil.rmtree(od, ignore_errors=True)
os.makedirs(od)
files = links = 0
for name in sorted(os.listdir(sd)):
    p = os.path.join(sd, name)
    if os.path.islink(p):
        os.symlink(os.readlink(p), os.path.join(od, name))
        links += 1
        continue
    images = [im for im in read(p) if im[0] in KEEP]
    by_size = {}
    for im in images:
        by_size.setdefault(im[0], []).append(im)
    kept = []
    for size in sorted(by_size):
        frames = by_size[size]
        if len(frames) > 1:                                        # animated: every second frame
            frames = frames[::2]
            for f in frames:
                f[5] *= 2
        for f in frames:
            f[6] = recolour(f[6])
        kept += frames
    write(os.path.join(od, name), kept)
    files += 1

with open(os.path.join(out, 'index.theme'), 'w') as fh:
    fh.write('[Icon Theme]\nName=Magnetic88\n'
             'Comment=Magnetic 88: Bibata Modern Ice (ful1e5, GPL-3.0) in cream and warm ink\n'
             'Inherits=Adwaita\n')
lic = os.path.join(os.path.dirname(os.path.abspath(src)), 'LICENSE')
if os.path.exists(lic):
    shutil.copy(lic, os.path.join(out, 'LICENSE'))
print(files, 'cursors,', links, 'names linked')
