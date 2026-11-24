#!/usr/bin/env python3
"""The gold contacts, polished: on every app cartridge, and in the taskbar's
port (as its chrome bezel is: tools/make_port_chrome.py, run first).

    python3 tools/make_gold.py home/.config/quickshell/assets

Each contact is found on its picture (the four gold pads at a cartridge's
foot; the four in the port's mouth) and drawn again as polished gold plate:
it mirrors the room as the chrome does (a bright sky at its top edge, a dark
horizon across it, a warm floor), its edges bevelled, a fine dark rim.
The cartridges are changed in place (run again, it finds and redraws the
same pads); the port's go into port-chrome.png.
(pip: numpy pillow opencv-python-headless)
"""
import glob, os, sys
import numpy as np, cv2
from PIL import Image, ImageDraw

assets = sys.argv[1]
SS = 4

# the room in the gold, top to bottom: (where, colour)
STOPS = [(0.00, (255, 240, 182)), (0.10, (246, 206, 112)), (0.30, (255, 226, 140)), (0.46, (214, 160, 62)),
         (0.56, (132, 86, 22)), (0.70, (196, 140, 48)), (0.86, (232, 186, 92)), (1.00, (150, 100, 30))]


def pad(w, h, r):
    """a polished gold pad, w x h px, its corners r: RGBA float"""
    W, H = w * SS, h * SS
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], r * SS, fill=255)
    a = np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    t = yy / h
    # the bevel: near its edges the plate turns, toward the sky above, the floor below
    din = cv2.distanceTransform((a > 0.5).astype(np.uint8), cv2.DIST_L2, 3)
    bev = np.clip(1 - din / max(1.5, min(w, h) * 0.18), 0, 1)
    t = np.where(yy < h / 2, t - 0.25 * bev, t + 0.25 * bev).clip(0, 1)
    pos = np.array([p for p, _ in STOPS]); cols = np.array([c for _, c in STOPS], np.float32)
    rgb = np.stack([np.interp(t, pos, cols[:, k]) for k in range(3)], -1)
    # a soft glint at the upper left, and the brushed grain across it
    g = np.exp(-(((xx - w * 0.3) / (w * 0.22)) ** 2 + ((yy - h * 0.2) / (h * 0.12)) ** 2))
    rgb += g[..., None] * 40
    rng = np.random.default_rng(w * 31 + h)
    rgb *= (1 + 0.025 * cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), sigmaX=3, sigmaY=0.4))[..., None]
    # its fine dark rim
    rim = np.clip(1 - din / 1.2, 0, 1)[..., None]
    rgb = rgb * (1 - 0.55 * rim) + np.array([70, 44, 10]) * 0.55 * rim
    return np.dstack([rgb.clip(0, 255), a * 255])


def find_pads(rgba, box, min_area, min_h):
    a = rgba.astype(int)
    x0, y0, x1, y1 = box
    r = a[y0:y1, x0:x1]
    gold = ((r[..., 0] - r[..., 2] > 40) & (r[..., 0] > 110) & (r[..., 1] > 80)).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(gold, 8)
    return sorted((st[i, 0] + x0, st[i, 1] + y0, st[i, 2], st[i, 3]) for i in range(1, n)
                  if st[i, 4] >= min_area and st[i, 3] >= min_h)


def lay(dst, x, y, p):
    h, w = p.shape[:2]
    al = p[..., 3:4] / 255
    reg = dst[y:y + h, x:x + w]
    reg[..., :3] = reg[..., :3] * (1 - al) + p[..., :3] * al


# ---- the cartridges
n = 0
for path in sorted(glob.glob(os.path.join(assets, 'cartridges', '*.png'))):
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32)
    pads = find_pads(im, (95, 365, 260, 440), 700, 32)
    for x, y, w, h in pads:
        # (a pixel beyond what was found: the old pad's soft edge too)
        lay(im, x - 1, y - 1, pad(w + 2, h + 2, 3))
    Image.fromarray(im.clip(0, 255).astype('uint8'), 'RGBA').save(path, optimize=True)
    n += len(pads)

# ---- the port: into its chrome sprite (4x, from left.png's 82, 36)
left = np.asarray(Image.open(os.path.join(assets, 'taskbar', 'left.png')).convert('RGBA')).astype(np.float32)
pads = find_pads(left, (95, 45, 210, 72), 60, 6)
sprite_p = os.path.join(assets, 'taskbar', 'port-chrome.png')
sp = np.asarray(Image.open(sprite_p).convert('RGBA')).astype(np.float32)
for x, y, w, h in pads:
    p = pad((w + 1) * 4, (h + 1) * 4, 6)
    al = p[..., 3:4] / 255
    X, Y = (x - 82) * 4 - 2, (y - 36) * 4 - 2
    reg = sp[Y:Y + p.shape[0], X:X + p.shape[1]]
    reg[..., :3] = reg[..., :3] * (1 - al) + p[..., :3] * al
    reg[..., 3:4] = np.maximum(reg[..., 3:4], p[..., 3:4])
Image.fromarray(sp.clip(0, 255).astype('uint8'), 'RGBA').save(sprite_p, optimize=True)
print(n, 'cartridge contacts,', len(pads), 'in the port')
