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

# gold plate from dark to light: warm brown shadow, gold, a pale near-white
# highlight (gold's highlights are yellow-white, never pure white)
RAMP = [(0.00, (74, 50, 20)), (0.22, (132, 94, 40)), (0.45, (186, 142, 68)), (0.65, (219, 180, 104)),
        (0.82, (240, 214, 150)), (1.00, (252, 242, 212))]


def field(w, h, seed):
    """what a row of flat polished contacts mirrors, over the whole row (so
    one soft reflection runs across all of them, as it does on real plate):
    brighter toward the top, a broad diagonal sheen, a slower one, and a
    faint cloudiness; 0..1"""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xx / max(w, h), yy / h
    f = 0.62 - 0.28 * v
    d = u * 0.55 + v * 0.85                                               # along the sheen, up to the right
    f += 0.30 * np.exp(-((d - 0.55) / 0.11) ** 2) + 0.12 * np.exp(-((d - 0.95) / 0.2) ** 2)
    f -= 0.16 * np.exp(-((d - 0.78) / 0.08) ** 2)                         # (a darker reflection beside it)
    f += 0.22 * np.exp(-((d - 0.52) / 0.028) ** 2)                        # (a crisp highlight within the sheen)
    cloud = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0), max(2, min(w, h) * 0.08))
    f += 0.025 * cloud / max(1e-3, cloud.std())
    return f.clip(0, 1)


def gold(f):
    pos = np.array([p for p, _ in RAMP]); cols = np.array([c for _, c in RAMP], np.float32)
    return np.stack([np.interp(f, pos, cols[:, k]) for k in range(3)], -1)


def pad(fld, w, h, r, shade_top=True):
    """one contact, w x h px, cut from the row's field fld (its own w x h
    part): the plate, its bevelled edges (light above and left, dark below and
    right), the shadow of the slot's lip over its top, a brushed grain"""
    W, H = w * SS, h * SS
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], r * SS, fill=255)
    a = np.asarray(m.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) + 0.5
    f = fld.copy()
    rng = np.random.default_rng(w * 31 + h * 7 + int(fld.sum() * 10) % 997)
    long_y = h >= w
    grain = cv2.GaussianBlur(rng.normal(0, 1, (h, w)).astype(np.float32), (0, 0),
                             sigmaX=0.4 if long_y else max(1.5, w * 0.08), sigmaY=max(1.5, h * 0.08) if long_y else 0.4)
    f = f + 0.008 * grain                                                  # (barely: polished plate)
    e = max(1.0, min(w, h) * 0.07)                                         # the bevel's width
    top = np.clip(1 - (yy - 0.5) / e, 0, 1); left = np.clip(1 - (xx - 0.5) / e, 0, 1)
    bot = np.clip(1 - (h - yy - 0.5) / e, 0, 1); right = np.clip(1 - (w - xx - 0.5) / e, 0, 1)
    f = f + 0.22 * np.maximum(top, left * 0.7) - 0.3 * np.maximum(bot, right * 0.6)
    rgb = gold(f.clip(0, 1))
    if shade_top:                                                          # the slot's lip shades its top
        ao = 0.28 * np.exp(-yy / max(1.5, h * 0.16))
        rgb *= (1 - ao)[..., None]
    rim = np.clip(1 - np.minimum(np.minimum(xx, w - xx), np.minimum(yy, h - yy)) / 0.9, 0, 1)[..., None]
    rgb = rgb * (1 - 0.45 * rim) + np.array([58, 38, 12]) * 0.45 * rim
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
    if pads:
        X0 = min(p[0] for p in pads) - 1; Y0 = min(p[1] for p in pads) - 1
        X1 = max(p[0] + p[2] for p in pads) + 1; Y1 = max(p[1] + p[3] for p in pads) + 1
        fld = field(X1 - X0, Y1 - Y0, sum(map(ord, os.path.basename(path))) % 1000)
        for x, y, w, h in pads:
            # (a pixel beyond what was found: the old pad's soft edge too)
            px, py, pw, ph = x - 1, y - 1, w + 2, h + 2
            lay(im, px, py, pad(fld[py - Y0:py - Y0 + ph, px - X0:px - X0 + pw], pw, ph, 2.5))
    Image.fromarray(im.clip(0, 255).astype('uint8'), 'RGBA').save(path, optimize=True)
    n += len(pads)

# ---- the port: into its chrome sprite (4x, from left.png's 82, 36)
left = np.asarray(Image.open(os.path.join(assets, 'taskbar', 'left.png')).convert('RGBA')).astype(np.float32)
pads = find_pads(left, (95, 45, 210, 72), 60, 6)
sprite_p = os.path.join(assets, 'taskbar', 'port-chrome.png')
sp = np.asarray(Image.open(sprite_p).convert('RGBA')).astype(np.float32)
X0 = (min(p[0] for p in pads) - 82) * 4 - 2; Y0 = (min(p[1] for p in pads) - 36) * 4 - 2
fld = field((max(p[0] + p[2] for p in pads) - 82) * 4 + 6 - X0, (max(p[1] + p[3] for p in pads) - 36) * 4 + 6 - Y0, 7)
for x, y, w, h in pads:
    pw, ph = (w + 1) * 4, (h + 1) * 4
    X, Y = (x - 82) * 4 - 2, (y - 36) * 4 - 2
    p = pad(fld[Y - Y0:Y - Y0 + ph, X - X0:X - X0 + pw], pw, ph, 5)
    al = p[..., 3:4] / 255
    reg = sp[Y:Y + p.shape[0], X:X + p.shape[1]]
    reg[..., :3] = reg[..., :3] * (1 - al) + p[..., :3] * al
    reg[..., 3:4] = np.maximum(reg[..., 3:4], p[..., 3:4])
Image.fromarray(sp.clip(0, 255).astype('uint8'), 'RGBA').save(sprite_p, optimize=True)
print(n, 'cartridge contacts,', len(pads), 'in the port')
