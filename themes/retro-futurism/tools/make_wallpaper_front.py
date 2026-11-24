#!/usr/bin/env python3
# The wallpaper, and over it the window with its glass see-through: she in
# front with a soft hair edge whose colour is hers alone (the old view behind
# her taken back out), and the ceiling lights reflected in the glass kept.
#
#   python3 tools/make_poster.py art/Wallpaper-Extended.jpg poster.png
#   python3 tools/make_wallpaper_front.py poster.png \
#       home/.local/share/ultra/retro-futurism/wallpaper.jpg \
#       home/.local/share/ultra/retro-futurism/wallpaper-front.png [check.png]
#
# wallpaper.jpg is the whole picture (3840 x 2160); wallpaper-front.png only
# the window (PATCH below, in the picture's pixels), laid over it once the
# view outside has been laid over the glass (modules/Backdrop.qml).
# (pip: numpy pillow scipy pymatting)
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from pymatting import estimate_alpha_cf, estimate_foreground_ml

src, outBack, outFront = sys.argv[1:4]
outCheck = sys.argv[4] if len(sys.argv) > 4 else None
full = np.asarray(Image.open(src).convert('RGB')).astype(np.float64)
H0, W0, _ = full.shape

# ---- her mole, a little clearer (as on the lock screen): a soft dark-brown dot
def mole(img, cx, cy, r=3.4, strength=0.7, colour=(82, 40, 27)):
    y0, x0 = int(cy) - 12, int(cx) - 12
    yy, xx = np.mgrid[y0:y0 + 25, x0:x0 + 25]
    a = np.clip((r + 1.2 - np.hypot(xx - cx, yy - cy)) / 2.4, 0, 1) * strength
    img[y0:y0 + 25, x0:x0 + 25] = img[y0:y0 + 25, x0:x0 + 25] * (1 - a[..., None]) + np.array(colour, float) * a[..., None]
mole(full, 2518.3, 496.4)
# ---- the cassette player in her hands, cleaned up (its lettering, keys, label, reels)
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import make_desk_cassette
make_desk_cassette.retouch(full)
Image.fromarray(full.round().astype('uint8')).save(outBack, quality=92, optimize=True, progressive=True)

# ---- the window: the part of the picture the front covers
PATCH = (1540, 60, 3010, 950)                       # x0, y0, x1, y1
X0, Y0, X1, Y1 = PATCH
I = full[Y0:Y1, X0:X1]; H, W, _ = I.shape
R, G, B = I[..., 0], I[..., 1], I[..., 2]
lum = 0.3 * R + 0.59 * G + 0.11 * B
yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
X, Y = xx + X0, yy + Y0                             # picture pixels (centres)

# ---- the glass: its edges as measured on the picture (where the dark seal
# gives way to the glass), its corners rounded; how much of each pixel it
# covers, so its edge is smooth
xL, xR, yB = 1570.5, 2976.5, 916.5
topPts = np.array([(1650, 81.5), (1800, 98.5), (1900, 111.5), (2000, 124.5), (2100, 138.5), (2200, 150.5),
                   (2300, 163.5), (2500, 190.5), (2600, 203.5), (2700, 214.5), (2800, 231.5), (2900, 248.5), (2940, 256.5)])
tc = np.polyfit(topPts[:, 0], topPts[:, 1], 2)
def top(x): return np.polyval(tc, x)
def topSlope(x): return np.polyval(np.polyder(tc), x)
d = np.minimum.reduce([X - xL, xR - X, yB - Y, (Y - top(X)) / np.sqrt(1 + topSlope(X) ** 2)])
for (cxs, side, r) in ((xL, 'top', 80), (xR, 'top', 45), (xL, 'bottom', 134), (xR, 'bottom', 120)):
    cx = cxs + r if cxs == xL else cxs - r
    cy = top(cx) + r * np.sqrt(1 + topSlope(cx) ** 2) if side == 'top' else yB - r
    zone = ((X < cx) if cxs == xL else (X > cx)) & ((Y < cy) if side == 'top' else (Y > cy))
    d = np.where(zone, np.minimum(d, r - np.hypot(X - cx, Y - cy)), d)
d = d + 1.2                                         # (a touch under the seal: no sliver of the old glass left)
glassCov = np.clip(d + 0.5, 0, 1)                  # 1 inside, 0 outside, soft between
glass = glassCov > 0.5
inside = d > 1.5                                    # wholly glass

# ---- her: what is dark and warm, or within the rough shape of her body,
# joined to her face (a hard mask to start from)
def poly(pts):
    from PIL import ImageDraw
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon([(x - X0, y - Y0) for x, y in pts], fill=255)
    return np.asarray(m) > 127
# (the old picture's body outline, carried over: this picture is that one
# scaled 1.742 and moved 539.2, 215.8, its window and her the same)
body = poly([((x + 540) * 1.742 + 539.2, y * 1.742 + 215.8) for x, y in [(465, 125), (495, 35), (610, 30),
    (705, 110), (725, 265), (690, 325), (900, 320), (900, 445), (430, 445), (465, 375), (460, 200)]])
# (left of her face, above her coat, she is only hair: the lit train
# windows there are the view's)
body &= ~((X < 2200) & (Y < 860))
warm = (R - B) > 4
region = glass & warm & ((lum < 105) | body)
lab, _ = ndi.label(region)
girl = lab == lab[int(616 - Y0), int(2542 - X0)]
girl = ndi.binary_closing(girl, iterations=2) & glass
# (holes in her filled: small ones, and dark ones, her hair where it is cool
# in colour; the glass seen between her hair and her coat kept)
holes, nh = ndi.label(ndi.binary_fill_holes(girl) & ~girl)
idx = np.arange(1, nh + 1)
hs = ndi.sum(np.ones_like(lum), holes, index=idx)
hl = ndi.median(lum, holes, index=idx)
hb = ndi.median(B - R, holes, index=idx)
girl |= np.isin(holes, [i for i, s_, l_, b_ in zip(idx, hs, hl, hb) if l_ < 70 or (s_ < 300 and b_ < 6)])
girl &= ~(((B - R) > 12) & (lum > 65))             # (her hair is never the sky's blue)

def disk(r): return np.hypot(*np.mgrid[-r:r + 1, -r:r + 1]) <= r
def grow(m, r): return ndi.binary_dilation(m, structure=disk(r))
def shrink(m, r): return ndi.binary_erosion(m, structure=disk(r))

# ---- the three zones: surely her, surely the glass, and the edge between
# (wider where hair meets the glass than where her cheek or coat does)
hairy = grow((lum < 90) & girl, 3)
herOrFrame = girl | ~glass                          # (the glass's edge does not thin her)
fg = (shrink(herOrFrame, 4) & ~(hairy & ~shrink(herOrFrame, 9))) | ~glass
bg = inside & ~grow(girl, 6) & ~(grow(girl, 16) & grow(hairy & girl, 16))
# the clear sky glimpsed between her strands: glass, wherever it is
sky = inside & ((B - R) > 16) & (lum > 78) & ~shrink(herOrFrame, 9)
bg |= sky
# and on the edge, what is plainly the view, not her: its cool colours, and
# left of her (where she is only dark hair) anything light
onlyHair = ((X < 2200) & (Y < 860)) | ((X < 2080) & (Y < 916))
view = ((B - R) > 6) & (lum > 50) & (lum < 140) | (onlyHair & (lum > 88))
# her loose strands: thin and darker than what is round them, near her (the
# matte decides how much of each is hair)
lumAround = ndi.grey_closing(lum, size=(9, 9))
strand = (lumAround - lum > 14) & (lum < 88) & grow(girl, 60) & inside & ~shrink(herOrFrame, 3)
strand = ndi.binary_opening(strand, structure=np.ones((1, 1)))
bg |= inside & view & ~fg
bg &= ~grow(strand, 2)
trimap = np.where(fg, 1.0, np.where(bg, 0.0, 0.5))
# the glass's own rim (not her): glass where it is not near her
trimap = np.where(glass & ~inside & ~grow(girl, 3), 0.0, trimap)

if outCheck and len(sys.argv) > 5 and sys.argv[5] == 'trimap':
    Image.fromarray((np.dstack([trimap] * 3) * 255).astype('uint8')).save(outCheck)
    sys.exit(0)

# ---- the matte, where she meets the glass: closed-form matting over the
# part of the window round her
unk = trimap == 0.5
ys, xs = np.nonzero(grow(unk, 24))
cy0, cy1, cx0, cx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
img01 = I[cy0:cy1, cx0:cx1] / 255.0
tri = trimap[cy0:cy1, cx0:cx1]
print('matting', cx1 - cx0, 'x', cy1 - cy0, 'unknown', int(unk.sum()), flush=True)
a = estimate_alpha_cf(img01, tri, laplacian_kwargs={'epsilon': 1e-6}, cg_kwargs={'maxiter': 4000})
alpha = trimap.copy(); alpha[cy0:cy1, cx0:cx1] = np.clip(a, 0, 1)
alpha = np.where(trimap == 1.0, 1.0, np.where(trimap == 0.0, 0.0, alpha))

# ---- islands that are not her (lit windows, bits of cloud): out; what
# lies right by her stays (a strand the matte broke)
lab, n = ndi.label((alpha > 0.5) & glass)
herLab = lab[int(616 - Y0), int(2542 - X0)]
near = np.unique(lab[grow(lab == herLab, 6)])
small = (lab > 0) & ~np.isin(lab, near)
alpha = np.where(grow(small, 4) & glass & ~grow(lab == herLab, 2), 0.0, alpha)
# faint haze the matting leaves out on the open glass: nothing
alpha = np.where(alpha < 0.03, 0.0, alpha)

# ---- her colour where she is see-through, the view behind taken out
F = estimate_foreground_ml(img01, np.clip(alpha[cy0:cy1, cx0:cx1], 0, 1)) * 255.0
col = I.copy()
edge = (alpha < 1) & glass
sub = col[cy0:cy1, cx0:cx1]
sub[:] = np.where(edge[cy0:cy1, cx0:cx1, None], F, sub)

# ---- the ceiling lights reflected in the glass: kept, over the view
refl = glass & (alpha < 0.5) & (lum > 165) & ((R - B) > 40)
# (only the long strips of the lights: the city's lit windows are small, and
# go by with the view)
rl, rn = ndi.label(grow(refl, 2))
rs = ndi.sum(np.ones_like(lum), rl, index=np.arange(1, rn + 1))
refl &= np.isin(rl, [i + 1 for i in range(rn) if rs[i] > 1500])
ra = ndi.gaussian_filter(grow(refl, 2).astype(float), 2.0) * 0.85
ra = np.where(glass & (alpha < 0.5), ra, 0.0)
ag = alpha + ra * (1 - alpha)
col = (col * alpha[..., None] + I * (ra * (1 - alpha))[..., None]) / np.maximum(ag, 1e-4)[..., None]

# ---- all together: glass where it is glass, the picture elsewhere; and a
# faint shadow of the seal just inside it, the view lies a little behind
A = (1 - glassCov) + glassCov * ag
C = ((1 - glassCov)[..., None] * I + (glassCov * ag)[..., None] * col) / np.maximum(A, 1e-4)[..., None]
sh = 0.28 * np.exp(-np.maximum(d, 0) / 3.5) * glassCov * (1 - ag)
seal = np.array([34.0, 28.0, 24.0])
A2 = A + sh * (1 - A)
C = (C * A[..., None] + seal * (sh * (1 - A))[..., None]) / np.maximum(A2, 1e-4)[..., None]
A = A2
Image.fromarray(np.dstack([np.clip(C, 0, 255), np.clip(A, 0, 1) * 255]).round().astype('uint8'), 'RGBA') \
    .save(outFront, optimize=True)
if outCheck:
    chk = C * A[..., None] + np.array([255, 150, 70]) * (1 - A[..., None])
    Image.fromarray(np.clip(chk, 0, 255).astype('uint8')).save(outCheck)
    Image.fromarray((np.dstack([trimap] * 3) * 255).astype('uint8')).save(outCheck.replace('.png', '-trimap.png'))
print('patch', PATCH, 'glass', (xL, round(top(xL + 80), 1), xR, yB), 'top', np.round(tc, 8).tolist(),
      'islands removed', int(small.sum()))
