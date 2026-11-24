#!/usr/bin/env python3
"""The file icons (art/FileIcons.png): an icon theme, "Magnetic88-Files",
for Files and every program's file dialogs.

    python3 tools/make_file_icons.py art/FileIcons.png home/.local/share/icons/Magnetic88-Files

Each of the sheet's twenty icons is cut off its white ground (its edge where
its outline is, the sheet's soft shadow under it made a real one, see-through)
and written square at 24 to 256 px; the names programs ask for (a file's
type: text-plain, application-pdf, image-png ...; the places: folder,
folder-download ...) are links to them. Everything else (the programs' own
icons) comes from Papirus, which it inherits.
(pip: numpy pillow opencv-python-headless)
"""
import os, sys
import numpy as np, cv2
from PIL import Image
from collections import deque

src, out = sys.argv[1:3]
sheet = np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
SIZES = [24, 32, 48, 64, 96, 128, 256]

# each icon: its box on the sheet (above its label), its file name
ICONS = [
    ((80, 30, 270, 281), 'txt'), ((348, 30, 538, 281), 'md'), ((580, 30, 828, 281), 'pdf'),
    ((864, 30, 1080, 281), 'docx'), ((1112, 58, 1360, 281), 'csv'),
    ((46, 336, 292, 551), 'zip'), ((324, 334, 562, 551), 'archive'), ((584, 330, 826, 551), 'image'),
    ((851, 330, 1090, 551), 'svg'), ((1113, 332, 1362, 551), 'audio'),
    ((33, 620, 335, 810), 'video'), ((362, 606, 580, 810), 'code'), ((621, 592, 790, 810), 'data'),
    ((830, 608, 1059, 810), 'exe'), ((1090, 610, 1375, 810), 'folder'),
    ((30, 855, 307, 1063), 'folder-open'), ((327, 876, 572, 1063), 'downloads'), ((582, 876, 828, 1063), 'documents'),
    ((837, 874, 1088, 1063), 'pictures'), ((1094, 869, 1375, 1063), 'projects'),
]

# the names asked for, by icon (mimetypes/ and places/)
MIME = {
    'txt': ['text-plain', 'text-x-generic', 'text-x-log', 'text-x-readme', 'application-x-zerosize'],
    'md': ['text-markdown', 'text-x-markdown', 'text-x-rst', 'text-org'],
    'pdf': ['application-pdf', 'application-x-pdf', 'application-postscript', 'image-x-eps'],
    'docx': ['x-office-document', 'application-msword', 'application-rtf', 'text-rtf',
             'application-vnd.openxmlformats-officedocument.wordprocessingml.document',
             'application-vnd.oasis.opendocument.text', 'application-epub+zip', 'x-office-presentation',
             'application-vnd.openxmlformats-officedocument.presentationml.presentation',
             'application-vnd.oasis.opendocument.presentation', 'application-vnd.ms-powerpoint'],
    'csv': ['text-csv', 'text-x-csv', 'text-tab-separated-values', 'x-office-spreadsheet', 'application-vnd.ms-excel',
            'application-vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application-vnd.oasis.opendocument.spreadsheet',
            'application-x-sqlite3', 'application-vnd.sqlite3'],
    'zip': ['application-zip', 'application-x-zip', 'application-x-zip-compressed', 'package-x-generic',
            'application-java-archive', 'application-x-java-archive'],
    'archive': ['application-x-tar', 'application-x-compressed-tar', 'application-x-7z-compressed',
                'application-x-bzip-compressed-tar', 'application-x-xz-compressed-tar', 'application-x-zstd-compressed-tar',
                'application-x-lzma-compressed-tar', 'application-x-rar', 'application-vnd.rar', 'application-gzip',
                'application-x-gzip', 'application-x-bzip', 'application-x-bzip2', 'application-x-xz', 'application-zstd',
                'application-x-archive', 'application-x-cd-image', 'application-x-iso9660-image', 'application-vnd.debian.binary-package',
                'application-x-rpm', 'application-x-xz-compressed-tar', 'application-x-arch-package'],
    'image': ['image-x-generic', 'image-png', 'image-jpeg', 'image-webp', 'image-gif', 'image-bmp', 'image-tiff',
              'image-heif', 'image-heic', 'image-avif', 'image-x-icon', 'image-vnd.microsoft.icon', 'image-x-xcf', 'image-jxl'],
    'svg': ['image-svg+xml', 'image-svg+xml-compressed', 'application-x-krita', 'application-illustrator'],
    'audio': ['audio-x-generic', 'audio-mpeg', 'audio-mp3', 'audio-flac', 'audio-x-flac', 'audio-ogg', 'audio-x-vorbis+ogg',
              'audio-x-opus+ogg', 'audio-opus', 'audio-x-wav', 'audio-wav', 'audio-mp4', 'audio-aac', 'audio-x-m4a',
              'audio-x-ms-wma', 'audio-x-aiff', 'audio-midi', 'audio-x-mpegurl', 'audio-x-scpls'],
    'video': ['video-x-generic', 'video-mp4', 'video-x-matroska', 'video-webm', 'video-quicktime', 'video-x-msvideo',
              'video-mpeg', 'video-ogg', 'video-x-flv', 'video-3gpp', 'video-x-ms-wmv', 'application-x-matroska'],
    'code': ['text-x-script', 'text-x-python', 'text-x-python3', 'text-x-csrc', 'text-x-chdr', 'text-x-c++src', 'text-x-c++hdr',
             'text-x-c', 'text-x-java', 'text-x-rust', 'text-x-go', 'text-x-lua', 'text-x-qml', 'text-x-makefile', 'text-x-cmake',
             'text-html', 'text-css', 'text-x-scss', 'text-x-sass', 'text-javascript', 'application-javascript', 'application-x-javascript',
             'application-typescript', 'text-x-typescript', 'application-x-shellscript', 'text-x-shellscript', 'application-x-perl',
             'application-x-php', 'application-x-ruby', 'text-x-patch', 'text-x-diff', 'application-xml', 'text-xml',
             'application-x-ipynb+json', 'text-x-kotlin', 'text-x-swift', 'text-x-csharp', 'text-x-dart', 'text-x-zig',
             'application-x-desktop', 'text-x-sql', 'application-sql'],
    'data': ['application-json', 'text-x-json', 'application-x-yaml', 'application-yaml', 'text-x-yaml', 'text-yaml',
             'application-toml', 'text-x-toml', 'application-x-toml', 'text-x-ini', 'application-x-ini', 'text-x-dockerfile',
             'application-x-ndjson', 'application-geo+json'],
    'exe': ['application-x-executable', 'application-x-sharedlib', 'application-x-object', 'application-x-msdownload',
            'application-x-ms-dos-executable', 'application-vnd.microsoft.portable-executable', 'application-x-appimage',
            'application-x-msi', 'application-x-pie-executable', 'application-x-firmware', 'application-x-shared-library-la'],
}
PLACES = {
    'folder': ['folder', 'inode-directory', 'folder-music', 'folder-videos', 'folder-publicshare', 'folder-templates',
               'folder-remote', 'folder-saved-search', 'folder-recent', 'folder-new', 'folder-visiting', 'folder-copy',
               'network-workgroup', 'folder-cloud', 'folder-important'],
    'folder-open': ['folder-open', 'folder-drag-accept', 'inode-directory-open'],
    'downloads': ['folder-download', 'folder-downloads'],
    'documents': ['folder-documents', 'folder-text'],
    'pictures': ['folder-pictures', 'folder-images', 'folder-camera', 'folder-photos'],
    'projects': ['folder-development', 'folder-projects', 'folder-code', 'folder-git', 'folder-github', 'folder-gitlab'],
}


def flood(free):
    h, w = free.shape
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


def cut(box):
    x0, y0, x1, y1 = box
    part = sheet[y0:y1, x0:x1]
    L = part.mean(2)
    sat = part.max(2) - part.min(2)
    h, w = L.shape
    # its body: everything inside its outline (the clear case's grey edges
    # and the darker parts, closed); the white within (its highlights, its
    # clear plastic) is it
    core = (L < 226) | (sat > 18)
    core = cv2.morphologyEx(core.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))).astype(bool)
    outside = flood(~core)
    body = ~outside
    # the sheet's soft shadow under it, grey, clung to its foot: peeled
    shadowy = (L > 196) & (sat < 16)
    cross = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
    outer = outside.copy()
    for _ in range(4):
        rim = body & cv2.dilate(outer.astype(np.uint8), cross).astype(bool)
        peel = rim & shadowy
        body &= ~peel; outer |= peel
    n, lab, st, _ = cv2.connectedComponentsWithStats(body.astype(np.uint8), connectivity=8)
    body = lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
    body = cv2.morphologyEx(body.astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))).astype(bool)
    body = cv2.GaussianBlur(body.astype(np.float32), (0, 0), 1.0) > 0.5
    # its edge a pixel's soft step; its colour there from just inside
    din = cv2.distanceTransform(body.astype(np.uint8), cv2.DIST_L2, 5)
    dout = cv2.distanceTransform((~body).astype(np.uint8), cv2.DIST_L2, 5)
    a = np.clip(0.5 + np.where(body, din - 0.5, 0.5 - dout), 0, 1).astype(np.float32)
    edge = (a > 0) & (din < 2.5)
    fill = cv2.inpaint(part.clip(0, 255).astype(np.uint8), edge.astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA).astype(np.float32)
    colour = np.where((din >= 2.5)[..., None], part, fill)
    # the shadow: the sheet's own, made dark and see-through
    shade = np.clip((250 - L) / 110, 0, 0.42) * (~body)
    shade = cv2.GaussianBlur(shade.astype(np.float32), (0, 0), 1.2)
    alpha = a + shade * (1 - a)
    colour = colour * (a / np.maximum(alpha, 1e-3))[..., None]
    rgba = np.dstack([colour, alpha * 255]).clip(0, 255).astype('uint8')
    ys, xs = np.where(alpha > 0.03)
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], 'RGBA')


def square(im, size):
    """on a square, its longer side 92% of it, at its foot's middle"""
    k = size * 0.92 / max(im.size)
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    small = im.convert('RGBa').resize((w, h), Image.LANCZOS).convert('RGBA')
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    c.alpha_composite(small, ((size - w) // 2, (size - h) // 2))
    return c


os.makedirs(out, exist_ok=True)
cuts = {name: cut(box) for box, name in ICONS}
dirs = []
for size in SIZES:
    for ctx, table in (('mimetypes', MIME), ('places', PLACES)):
        d = os.path.join(out, f'{size}x{size}', ctx)
        os.makedirs(d, exist_ok=True)
        dirs.append((f'{size}x{size}/{ctx}', size, ctx))
        for name, names in table.items():
            square(cuts[name], size).save(os.path.join(d, f'mg-{name}.png'), optimize=True)
            for n in names:
                p = os.path.join(d, n + '.png')
                if os.path.lexists(p):
                    os.remove(p)
                os.symlink(f'mg-{name}.png', p)

ctx_name = {'mimetypes': 'MimeTypes', 'places': 'Places'}
with open(os.path.join(out, 'index.theme'), 'w') as f:
    f.write('[Icon Theme]\nName=Magnetic88-Files\nComment=Magnetic 88: its file icons, Papirus for the rest\n'
            'Inherits=Papirus,Adwaita,hicolor\nDirectories=' + ','.join(d for d, _, _ in dirs) + '\n\n')
    for d, size, ctx in dirs:
        f.write(f'[{d}]\nSize={size}\nContext={ctx_name[ctx]}\nType=Fixed\n\n')

if os.environ.get('ICON_SHEET'):
    cell = 150
    o = Image.new('RGBA', (5 * cell * 2, 4 * cell), (0, 0, 0, 255))
    for i, (_, name) in enumerate(ICONS):
        for j, bg in enumerate(((215, 214, 209, 255), (46, 44, 42, 255))):
            t = Image.new('RGBA', (cell, cell), bg)
            t.alpha_composite(square(cuts[name], 140), (5, 5))
            o.paste(t, (((i % 5) * 2 + j) * cell, (i // 5) * cell))
    o.convert('RGB').save(os.environ['ICON_SHEET'])
print(len(ICONS), 'icons,', sum(len(v) for v in MIME.values()) + sum(len(v) for v in PLACES.values()), 'names')
