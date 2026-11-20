#!/usr/bin/env python3
# The wallpaper's second poster, printed again with its own picture (the
# picture's outpainting had copied the first one into it): Mt. Fuji under a
# striped sun, a bullet train on the line below, in the first poster's own
# inks (rust, the paper's cream, three greys), on its paper: the light, the
# shadows of the frame and the grain of the poster as it hangs there are
# kept, only the print changes.
#   python3 tools/make_poster.py art/Wallpaper-Extended.jpg poster.png [check.png]
# (pip: numpy pillow opencv-python-headless scipy)
import sys
import numpy as np, cv2
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, binary_erosion

src, out = sys.argv[1:3]
check = sys.argv[3] if len(sys.argv) > 3 else None
img = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
H, W, _ = img.shape

# ---- the print, flat, in its own square: the frame's opening (in the 3840 x
# 2160 picture; it hangs a little turned, so a quad), and the print laid
# square in Wc x Hc
Q = np.float32([[773, 100], [1171, 123], [1171, 637], [777, 627]])
Wc, Hc = 400, 530
Hm = cv2.getPerspectiveTransform(np.float32([[0, 0], [Wc, 0], [Wc, Hc], [0, Hc]]), Q)
rect = cv2.warpPerspective(img, Hm, (Wc, Hc), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
                           borderMode=cv2.BORDER_REPLICATE)

# ---- its inks: the colours the old print is made of, and which is where
px = rect.reshape(-1, 3)
crit = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 60, 0.1)
cv2.setRNGSeed(88)
_, lab, inks = cv2.kmeans(px, 5, None, crit, 6, cv2.KMEANS_PP_CENTERS)
lab = lab.reshape(Hc, Wc)
# (rust: the one far redder than it is green; the rest by lightness)
rust_i = int(np.argmax(inks[:, 0] - inks[:, 1]))
rest = sorted([i for i in range(5) if i != rust_i], key=lambda i: inks[i].sum())
ink = {'rust': inks[rust_i], 'dark': inks[rest[0]], 'mid': inks[rest[1]],
       'light': inks[rest[2]], 'cream': inks[rest[3]]}
print('inks', {k: tuple(int(c) for c in v) for k, v in ink.items()})

# ---- the paper as it hangs there: how much lighter or darker each place is
# than its ink (the light on the wall, the frame's shadow), from the inside of
# each patch of ink, spread smoothly over the rest
ratio = np.zeros_like(rect); wsum = np.zeros((Hc, Wc), np.float32)
for i in range(5):
    m = binary_erosion(lab == i, iterations=4)
    ratio += np.where(m[..., None], rect / np.maximum(inks[i], 1), 0)
    wsum += m
sig = 22
shade = np.dstack([gaussian_filter(ratio[..., c], sig) for c in range(3)]) / \
        np.maximum(gaussian_filter(wsum, sig), 1e-4)[..., None]
# the grain: the paper's fine texture where the old print is one flat ink
flat = binary_erosion(lab == rest[3], iterations=4)
resid = (rect - np.dstack([gaussian_filter(rect[..., c], 1.6) for c in range(3)])).mean(2)
grain_sd = float(resid[flat].std())
print('grain sd', round(grain_sd, 2))

# ---- the new print, drawn four times over and taken down (smooth edges)
SS = 4
def P(*pts): return [(x * SS, y * SS) for x, y in pts]
art = Image.new('RGB', (Wc * SS, Hc * SS), tuple(int(c) for c in ink['cream']))
d = ImageDraw.Draw(art)
def C(n): return tuple(int(round(c)) for c in ink[n])

# the sun, low behind the summit, with the cream slices of a retro sunset
# through its lower half, and two long flat clouds across it
cx, cy, r = 204, 212, 112
d.ellipse(P((cx - r, cy - r), (cx + r, cy + r)), fill=C('rust'))
for y, t in ((252, 5), (274, 7), (298, 9)):
    d.rectangle(P((cx - r - 2, y), (cx + r + 2, y + t)), fill=C('cream'))
d.rounded_rectangle(P((34, 156), (178, 166)), 5 * SS, fill=C('light'))
d.rounded_rectangle(P((232, 186), (368, 194)), 4 * SS, fill=C('light'))

# the mountain: a plateau of a summit, slopes steep at the top and spreading
# at the foot
top, foot = 262, 440
def slope(x0, x1, n=80):
    return [(x0 + (x1 - x0) * u, top + (foot - top) * u ** 0.6) for u in np.linspace(0, 1, n)]
left = slope(176, -40)
right = slope(230, 440)
crown = [(184, 260), (194, 262), (204, 259.5), (214, 261.5), (223, 260)]
d.polygon(P(*(left[::-1] + crown + right + [(440, 480), (-40, 480)])), fill=C('mid'))
# the sun's side of it a shade lighter: from the summit down a ridge that
# spreads as the slopes do
ridge = [(205 + 95 * u, top + (foot - top) * u ** 0.6) for u in np.linspace(0, 1, 80)]
d.polygon(P(*([right[0]] + right + ridge[::-1] + [(214, 261.5), (223, 260)])), fill=C('light'))
# its snow: the paper left bare, run down the gullies in streaks of
# different lengths
def at(side, y):                      # where a slope is at height y
    pts = np.array(side); return float(np.interp(y, pts[:, 1], pts[:, 0]))
yl, yr = 296, 300
# (x, how far down) for each streak, left to right, and the notches between
streaks = [(171, 318), (182, 336), (193, 312), (203, 346), (214, 320), (224, 338), (235, 312)]
notch = 297
foot_pts = [(at(left, yl), yl)]
for i, (x, y) in enumerate(streaks):
    w = 4.2
    foot_pts += [(x - w, notch + 4), (x - w * 0.6, (notch + y) / 2), (x, y), (x + w * 0.6, (notch + y) / 2), (x + w, notch + 4)]
foot_pts += [(at(right, yr), yr)]
d.polygon(P(*([left[0]] + crown + [right[0]] + [p for p in right if p[1] < yr] + foot_pts[::-1]
              + [p for p in left if p[1] < yl][::-1])), fill=C('cream'))

# the land below, and the line on its viaduct
land = [(x, 452 + 6 * np.sin(x / 47.0) + 4 * np.sin(x / 19.0 + 1)) for x in np.linspace(-10, 410, 80)]
d.polygon(P(*(land + [(410, 490), (-10, 490)])), fill=C('dark'))
d.rectangle(P((-10, 428), (410, 434)), fill=C('dark'))                 # the deck
for x in range(22, 410, 64):                                           # its piers
    d.polygon(P((x - 5, 434), (x + 5, 434), (x + 7, 470), (x - 7, 470)), fill=C('dark'))
# the bullet train, nose first to the left, running out of the picture
ty, th = 408, 20
nose = [(52 + 46 * (1 - np.cos(a)) , ty + th - th * np.sin(a) ** 0.55) for a in np.linspace(0, np.pi / 2, 30)]
body = [(98, ty), (410, ty), (410, ty + th)] + [(52, ty + th)] + nose[1:]
d.polygon(P(*body), fill=C('light'))
d.polygon(P((84, ty + 4), (410, ty + 4), (410, ty + 9), (78, ty + 9)), fill=C('dark'))      # the windows
for x in range(140, 410, 54):                                         # the cars' joints
    d.rectangle(P((x, ty + 1), (x + 1.4, ty + th)), fill=C('mid'))
d.polygon(P((58, ty + th - 4), (410, ty + th - 4), (410, ty + th - 1), (54, ty + th - 1)), fill=C('rust'))
# the paper's margin at its foot, as on the first poster
d.rectangle(P((-10, 490), (410, 540)), fill=C('cream'))
new = np.asarray(art.resize((Wc, Hc), Image.BOX)).astype(np.float32)

# ---- printed on the paper there: its light and shadow, its grain
rng = np.random.default_rng(88)
g = gaussian_filter(rng.normal(0, 1, (Hc, Wc)), 0.6)
g *= grain_sd / max(g.std(), 1e-6)
newp = new * shade + g[..., None]

# ---- back into the frame, as it hangs
warped = cv2.warpPerspective(newp, Hm, (W, H), flags=cv2.INTER_LINEAR)
cover = cv2.warpPerspective(np.ones((Hc * 4, Wc * 4), np.float32),
                            Hm @ np.diag([0.25, 0.25, 1]).astype(np.float64), (W, H), flags=cv2.INTER_AREA)
cover = np.clip(cover, 0, 1)[..., None]
res = img * (1 - cover) + warped * cover
Image.fromarray(np.clip(res, 0, 255).round().astype('uint8')).save(out)
if check:
    x0, y0 = int(Q[:, 0].min()) - 40, int(Q[:, 1].min()) - 40
    x1, y1 = int(Q[:, 0].max()) + 40, int(Q[:, 1].max()) + 40
    Image.fromarray(np.clip(res[y0:y1, x0:x1], 0, 255).astype('uint8')).save(check)
