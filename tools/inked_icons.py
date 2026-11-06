"""Folders and files drawn by hand in ink on paper, for the Archive icons
(make_icons.py): a manila folder with its sign inked on the front (a down
arrow for Downloads, a note for Music ...), a cream sheet with a folded
corner and its type typed on it in its colour (PDF in madder, MP3 in ochre,
PNG in sage, PY in ink blue ...). The pen lines bow a little and their
corners are soft, the same on every run (seeded by the icon's name).

Drawn on a 64 x 64 design and scaled; at 24 px and under the drawing is
simpler (no typed tag, a band of the type's colour instead; no sign on a
folder) with a heavier line, so it still reads.
"""
import math
import os
import random
import re

INK = "#4e4a4c"
MADDER, OCHRE, SAGE, BLUE, SOFT, PLAIN = "#864a41", "#9a7d45", "#536758", "#36405a", "#6e6a68", "#3e3d42"
MANILA_BACK, MANILA_FRONT = "#dac498", "#e2cea4"
SHEET, SHEET_FOLD, SHEET_RULE = "#f2ecde", "#ded6c4", "#c8c0b0"
FONT = "'Courier Prime', 'Courier New', monospace"
COLOURS = {"blue", "black", "brown", "cyan", "green", "grey", "indigo", "magenta", "orange", "pink", "red",
           "teal", "violet", "white", "yellow", "deeporange", "paleorange", "carmine", "bluegrey", "darkcyan",
           "nordic", "adwaita", "palebrown", "yaru"}


# ------------------------------------------------------------------ the pen
def _pen(pts, amp, seed, closed=False):
    """A hand-drawn stroke through pts: each line bows a little, the
    corners are rounded a touch; never a tremble."""
    r = random.Random(seed)
    if closed:
        pts = pts + [pts[0]]
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        L = math.hypot(x1 - x0, y1 - y0) or 1
        nx, ny = -(y1 - y0) / L, (x1 - x0) / L
        bow = r.uniform(-amp, amp) * min(1.0, L / 30)
        for i in range(6):
            t = i / 6
            b = math.sin(math.pi * t) * bow
            out.append((x0 + (x1 - x0) * t + nx * b, y0 + (y1 - y0) * t + ny * b))
    out.append(pts[-1])
    for _ in range(2):          # Chaikin: soften the corners
        sm = [out[0]]
        for p, q in zip(out, out[1:]):
            sm.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            sm.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        sm.append(out[-1])
        out = sm
    return "M " + " L ".join("%.2f,%.2f" % p for p in out) + (" Z" if closed else "")


def _stroke(d, w, col=INK, extra=""):
    return ('<path d="%s" style="fill:none;stroke:%s;stroke-width:%.2f;stroke-linecap:round;'
            'stroke-linejoin:round;opacity:0.94%s"/>' % (d, col, w, extra))


def _fill(d, col):
    return '<path d="%s" style="fill:%s"/>' % (d, col)


def _shadow(d):
    return ('<path d="%s" transform="translate(1.1,1.8)" style="fill:#1e1a16;opacity:0.16;filter:url(#s)"/>' % d)


def _svg(size, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 64 64" version="1.1">\n'
            '<defs><filter id="s" x="-20%%" y="-20%%" width="140%%" height="140%%">'
            '<feGaussianBlur stdDeviation="1.3"/></filter></defs>\n%s\n</svg>\n' % (size, size, "\n".join(body)))


def _seed(name):
    return sum(ord(c) * (i + 7) for i, c in enumerate(name))


# ------------------------------------------------------------------ signs on folders
def _sign(kind, cx, cy, s, w):
    p = []
    if kind == "doc":
        for i in range(3):
            p.append("M %.2f,%.2f L %.2f,%.2f" % (cx - s, cy - s * 0.6 + i * s * 0.6, cx + s * (0.9 if i < 2 else 0.35), cy - s * 0.6 + i * s * 0.6))
    elif kind == "down":
        p.append("M %.2f,%.2f L %.2f,%.2f" % (cx, cy - s, cx, cy + s * 0.45))
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.6, cy - s * 0.05, cx, cy + s * 0.5, cx + s * 0.6, cy - s * 0.05))
        p.append("M %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.8, cy + s, cx + s * 0.8, cy + s))
    elif kind == "note":
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.1, cy + s * 0.55, cx - s * 0.1, cy - s, cx + s * 0.6, cy - s * 0.65))
        return "".join(_stroke(d, w, MADDER) for d in p) + \
            '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" style="fill:%s"/>' % (cx - s * 0.42, cy + s * 0.58, s * 0.36, s * 0.3, MADDER)
    elif kind == "pic":
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f L %.2f,%.2f Z" % (cx - s, cy - s * 0.75, cx + s, cy - s * 0.75, cx + s, cy + s * 0.75, cx - s, cy + s * 0.75))
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx - s, cy + s * 0.55, cx - s * 0.25, cy - s * 0.1, cx + s * 0.2, cy + s * 0.35, cx + s * 0.5, cy + s * 0.05, cx + s, cy + s * 0.5))
    elif kind == "home":
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx - s, cy - s * 0.05, cx, cy - s, cx + s, cy - s * 0.05))
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.7, cy - s * 0.3, cx - s * 0.7, cy + s * 0.85, cx + s * 0.7, cy + s * 0.85, cx + s * 0.7, cy - s * 0.3))
    elif kind == "video":
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f Z" % (cx - s * 0.6, cy - s * 0.8, cx + s * 0.85, cy, cx - s * 0.6, cy + s * 0.8))
    elif kind == "desk":
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f L %.2f,%.2f Z" % (cx - s, cy - s * 0.7, cx + s, cy - s * 0.7, cx + s, cy + s * 0.4, cx - s, cy + s * 0.4))
        p.append("M %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.4, cy + s * 0.85, cx + s * 0.4, cy + s * 0.85))
    elif kind == "share":
        for dx, dy in ((-0.7, 0), (0.6, -0.65), (0.6, 0.65)):
            p.append("M %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.7, cy, cx + dx * s, cy + dy * s))
    elif kind == "star":
        pts = []
        for i in range(10):
            a = -math.pi / 2 + i * math.pi / 5
            r = s if i % 2 == 0 else s * 0.45
            pts.append("%.2f,%.2f" % (cx + math.cos(a) * r, cy + math.sin(a) * r))
        p.append("M " + " L ".join(pts) + " Z")
    elif kind == "code":
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx - s * 0.35, cy - s * 0.7, cx - s, cy, cx - s * 0.35, cy + s * 0.7))
        p.append("M %.2f,%.2f L %.2f,%.2f L %.2f,%.2f" % (cx + s * 0.35, cy - s * 0.7, cx + s, cy, cx + s * 0.35, cy + s * 0.7))
    return "".join(_stroke(d, w, MADDER) for d in p)


FOLDER_SIGNS = [
    (("documents", "document", "text", "templates", "template"), "doc"),
    (("download", "downloads"), "down"),
    (("music", "sound", "audio"), "note"),
    (("pictures", "picture", "images", "image", "photo", "photos", "camera"), "pic"),
    (("home",), "home"),
    (("videos", "video", "movies"), "video"),
    (("desktop",), "desk"),
    (("publicshare", "public", "share", "remote", "network"), "share"),
    (("favorites", "bookmark", "important", "starred"), "star"),
    (("development", "projects", "git", "github", "gitlab", "script", "code"), "code"),
]


def folder_sign(name):
    words = [w for w in re.split(r"[-_.]", name.lower()) if w and w not in COLOURS and w not in ("folder", "user", "open", "drag", "accept")]
    for keys, kind in FOLDER_SIGNS:
        if any(w in keys for w in words):
            return kind
    return None


LEATHER_BACK, LEATHER, STRAP, BRASS, LABEL = "#a8774e", "#c08a5c", "#7d5233", "#c9a45a", "#efe6d2"
# which folder: "folder" (manila, the Archive) or "suitcase" (Night Service);
# archive-icons sets it from the theme of the session (theme.json "flavour")
FOLDERS = os.environ.get("ARCHIVE_FOLDERS", "folder")


def suitcase(name, size):
    """A 1930s leather suitcase, as drawn in a catalogue: shaded leather,
    a stitched edge, darker leather corner guards, a sewn handle on brass
    loops, two brass catches on the lid's seam; the folder's sign on a
    travel label pasted on its front. Fine lines, little wobble."""
    small = size <= 24
    seed = _seed(name)
    uid = "s%d" % (seed % 100000)
    w = 2.4 if small else 1.15
    line = "#3b2a20"
    opened = "-open" in name or "drag-accept" in name
    out = ['<defs><linearGradient id="%s" x1="0" y1="0" x2="0" y2="1">'
           '<stop offset="0" stop-color="#9c7150"/><stop offset="0.55" stop-color="#8a6043"/>'
           '<stop offset="1" stop-color="#6e4a33"/></linearGradient>'
           '<linearGradient id="%sh" x1="0" y1="0" x2="0" y2="1">'
           '<stop offset="0" stop-color="#5e4030"/><stop offset="1" stop-color="#3f2a1f"/></linearGradient></defs>' % (uid, uid)]
    x0, y0, x1, y1, r = 5.0, 21.0, 59.0, 54.0, 3.2
    body = "M %.1f,%.1f L %.1f,%.1f Q %.1f,%.1f %.1f,%.1f L %.1f,%.1f Q %.1f,%.1f %.1f,%.1f L %.1f,%.1f Q %.1f,%.1f %.1f,%.1f L %.1f,%.1f Q %.1f,%.1f %.1f,%.1f Z" % (
        x0 + r, y0, x1 - r, y0, x1, y0, x1, y0 + r, x1, y1 - r, x1, y1, x1 - r, y1,
        x0 + r, y1, x0, y1, x0, y1 - r, x0, y0 + r, x0, y0, x0 + r, y0)
    out.append(_shadow(body))
    # the handle: sewn leather on two brass loops
    if not small:
        out.append('<path d="M 25,21 L 25,17.6 M 39,21 L 39,17.6" style="stroke:%s;stroke-width:2.2;stroke-linecap:round"/>' % BRASS)
    out.append('<path d="M 23.4,18.6 C 23.4,12.6 40.6,12.6 40.6,18.6 L 37.8,18.6 C 37.8,15.6 26.2,15.6 26.2,18.6 Z" style="fill:url(#%sh);stroke:%s;stroke-width:%.2f;stroke-linejoin:round"/>' % (uid, line, w * 0.8))
    if opened:   # the lid lifted a little: the lining shows
        out.append('<path d="M 6,21 L 58,21 L 56,16.4 L 8,16.4 Z" style="fill:#d9c8a6;stroke:%s;stroke-width:%.2f;stroke-linejoin:round"/>' % (line, w * 0.8))
    out.append('<path d="%s" style="fill:url(#%s)"/>' % (body, uid))
    if not small:
        # the stitched edge, just inside
        out.append('<rect x="7.2" y="23.2" width="49.6" height="28.6" rx="2" style="fill:none;stroke:#e2cfae;stroke-opacity:0.55;stroke-width:0.6;stroke-dasharray:1.3 1.1"/>')
        # corner guards: darker leather, rivets
        for cx, cy, sx, sy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
            g = 6.4
            out.append('<path d="M %.1f,%.1f L %.1f,%.1f Q %.1f,%.1f %.1f,%.1f L %.1f,%.1f Z" style="fill:#52372a;fill-opacity:0.9"/>' % (
                cx, cy + sy * g, cx, cy + sy * 2.6, cx, cy, cx + sx * 2.6, cy, cx + sx * g, cy))
            out.append('<circle cx="%.1f" cy="%.1f" r="0.55" style="fill:%s"/>' % (cx + sx * 2.4, cy + sy * 2.4, BRASS))
    # the lid's seam, with a lit edge under it
    out.append('<path d="M 5,28.4 L 59,28.4" style="stroke:%s;stroke-width:%.2f"/>' % (line, w * 0.8))
    if not small:
        out.append('<path d="M 6,29.4 L 58,29.4" style="stroke:#c9a47e;stroke-opacity:0.45;stroke-width:0.6"/>')
    # two brass catches on the seam
    for cx in (17, 47):
        if small:
            out.append('<rect x="%.1f" y="26.6" width="4" height="4" style="fill:%s"/>' % (cx - 2, BRASS))
        else:
            out.append('<rect x="%.1f" y="25.6" width="5.6" height="6.2" rx="0.8" style="fill:%s;stroke:#6e5426;stroke-width:0.6"/>' % (cx - 2.8, BRASS))
            out.append('<circle cx="%.1f" cy="29.6" r="0.75" style="fill:#4a3818"/>' % cx)
    out.append('<path d="%s" style="fill:none;stroke:%s;stroke-width:%.2f;stroke-linejoin:round"/>' % (body, line, w))
    kind = folder_sign(name) if not small else None
    if kind:
        # a travel label pasted a little askew
        out.append('<g transform="rotate(-5 32 42)"><rect x="23" y="34.6" width="18" height="14.6" rx="1.4" style="fill:%s;stroke:#8c6b4a;stroke-width:0.7"/>'
                   '<rect x="24.2" y="35.8" width="15.6" height="12.2" rx="0.8" style="fill:none;stroke:%s;stroke-opacity:0.6;stroke-width:0.5"/>' % (LABEL, MADDER))
        out.append(_sign(kind, 32, 42, 4.6, 1.3) + '</g>')
    return _svg(size, out)


def folder(name, size):
    """A manila folder, drawn in ink; its sign inked on the front."""
    if FOLDERS == "suitcase":
        return suitcase(name, size)
    small = size <= 24
    seed = _seed(name)
    amp = 0.7 if small else 1.1
    w = 3.0 if small else 1.6
    opened = "-open" in name or "drag-accept" in name
    back = [(7, 53.5), (7, 14.5), (25, 14.5), (29.5, 19.5), (57, 19.5), (57, 53.5)]
    front_top = 30 if opened else 26
    front = [(7 if not opened else 4, front_top), (57 if not opened else 60, front_top), (57, 53.5), (7, 53.5)]
    body = []
    outline = _pen(back, amp, seed, closed=True)
    body.append(_shadow(outline))
    body.append(_fill(outline, MANILA_BACK))
    if opened:   # a sheet stands up out of the open folder
        sheet = _pen([(14, 10), (48, 10), (48, 40), (14, 40)], amp * 0.7, seed + 5, closed=True)
        body.append(_fill(sheet, SHEET))
        body.append(_stroke(sheet, w * 0.8))
    f = _pen(front, amp, seed + 1, closed=True)
    body.append(_fill(f, MANILA_FRONT))
    body.append(_stroke(outline, w))
    body.append(_stroke(_pen([front[0], front[1]], amp, seed + 2), w))
    if opened:
        body.append(_stroke(f, w))
    kind = folder_sign(name) if not small else None
    if kind:
        body.append(_sign(kind, 32, 40.5, 7.2, 1.7))
    return _svg(size, body)


# ------------------------------------------------------------------ typed sheets
EXACT = {
    "pdf": ("PDF", MADDER), "zip": ("ZIP", SOFT), "x-zip": ("ZIP", SOFT), "x-zip-compressed": ("ZIP", SOFT),
    "x-7z-compressed": ("7Z", SOFT), "x-rar": ("RAR", SOFT), "vnd.rar": ("RAR", SOFT), "gzip": ("GZ", SOFT),
    "x-gzip": ("GZ", SOFT), "x-tar": ("TAR", SOFT), "x-compressed-tar": ("TGZ", SOFT), "x-bzip": ("BZ2", SOFT),
    "x-bzip-compressed-tar": ("TBZ", SOFT), "x-xz": ("XZ", SOFT), "x-xz-compressed-tar": ("TXZ", SOFT),
    "zstd": ("ZST", SOFT), "x-zstd-compressed-tar": ("TZST", SOFT), "x-archive": ("AR", SOFT),
    "json": ("JSON", BLUE), "xml": ("XML", BLUE), "x-python": ("PY", BLUE), "x-python3": ("PY", BLUE),
    "x-shellscript": ("SH", PLAIN), "x-sh": ("SH", PLAIN), "javascript": ("JS", BLUE), "x-javascript": ("JS", BLUE),
    "typescript": ("TS", BLUE), "x-typescript": ("TS", BLUE), "x-csrc": ("C", BLUE), "x-c": ("C", BLUE),
    "x-c++src": ("C++", BLUE), "x-chdr": ("H", BLUE), "x-c++hdr": ("H", BLUE), "x-java": ("JAVA", BLUE),
    "x-rust": ("RS", BLUE), "rust": ("RS", BLUE), "x-go": ("GO", BLUE), "x-lua": ("LUA", BLUE), "x-ruby": ("RB", BLUE),
    "x-php": ("PHP", BLUE), "x-perl": ("PL", BLUE), "x-qml": ("QML", BLUE), "x-cmake": ("CMK", BLUE),
    "x-makefile": ("MAKE", BLUE), "x-yaml": ("YAML", BLUE), "yaml": ("YAML", BLUE), "toml": ("TOML", BLUE),
    "x-toml": ("TOML", BLUE), "x-sql": ("SQL", BLUE), "sql": ("SQL", BLUE),
    "markdown": ("MD", PLAIN), "x-markdown": ("MD", PLAIN), "html": ("HTML", OCHRE), "css": ("CSS", OCHRE),
    "plain": ("TXT", PLAIN), "x-log": ("LOG", PLAIN), "csv": ("CSV", SAGE), "x-csv": ("CSV", SAGE),
    "rtf": ("RTF", MADDER), "epub+zip": ("EPUB", MADDER), "x-iso9660-image": ("ISO", SOFT),
    "x-cd-image": ("ISO", SOFT), "x-executable": ("BIN", SOFT), "x-sharedlib": ("LIB", SOFT),
    "x-object": ("OBJ", SOFT), "x-deb": ("DEB", SOFT), "x-rpm": ("RPM", SOFT), "x-msi": ("MSI", SOFT),
    "x-ms-dos-executable": ("EXE", SOFT), "x-msdownload": ("EXE", SOFT), "x-appimage": ("APP", SOFT),
    "x-desktop": ("APP", SOFT), "x-bittorrent": ("TOR", SOFT), "x-trash": ("DEL", SOFT),
    "png": ("PNG", SAGE), "jpeg": ("JPG", SAGE), "jpg": ("JPG", SAGE), "gif": ("GIF", SAGE), "svg+xml": ("SVG", SAGE),
    "svg": ("SVG", SAGE), "webp": ("WEBP", SAGE), "bmp": ("BMP", SAGE), "tiff": ("TIFF", SAGE), "x-xcf": ("XCF", SAGE),
    "heic": ("HEIC", SAGE), "avif": ("AVIF", SAGE), "x-icon": ("ICO", SAGE), "vnd.microsoft.icon": ("ICO", SAGE),
    "mpeg": ("MP3", OCHRE), "mp3": ("MP3", OCHRE), "x-mp3": ("MP3", OCHRE), "flac": ("FLAC", OCHRE), "x-flac": ("FLAC", OCHRE),
    "ogg": ("OGG", OCHRE), "x-vorbis+ogg": ("OGG", OCHRE), "wav": ("WAV", OCHRE), "x-wav": ("WAV", OCHRE),
    "aac": ("AAC", OCHRE), "x-aac": ("AAC", OCHRE), "mp4": ("MP4", BLUE), "x-m4a": ("M4A", OCHRE), "opus": ("OPUS", OCHRE),
    "x-matroska": ("MKV", BLUE), "webm": ("WEBM", BLUE), "quicktime": ("MOV", BLUE), "x-msvideo": ("AVI", BLUE),
}
BY_WORD = [
    (("spreadsheet", "excel", "ms-excel", "calc", "spreadsheetml"), ("XLS", SAGE)),
    (("presentation", "powerpoint", "presentationml", "impress"), ("PPT", OCHRE)),
    (("msword", "wordprocessingml", "opendocument.text", "word", "writer", "document"), ("DOC", MADDER)),
    (("font", "ttf", "otf", "woff"), ("FONT", PLAIN)),
]
CATEGORY = {"image": ("IMG", SAGE), "audio": ("AUD", OCHRE), "video": ("VID", BLUE), "text": ("TXT", PLAIN),
            "font": ("FONT", PLAIN), "package": ("PKG", SOFT), "x": ("FILE", SOFT), "application": ("FILE", SOFT)}


def tag_for(name):
    """The type typed on a sheet, and its colour, from a mimetype icon's name
    (image-png, application-pdf, text-x-python, x-office-spreadsheet ...)."""
    base = name[:-4] if name.endswith(".svg") else name
    if base.startswith("x-office-"):
        rest = base[len("x-office-"):]
        for keys, tag in BY_WORD:
            if any(k in rest for k in keys):
                return tag
        return ("DOC", MADDER)
    cat, _, sub = base.partition("-")
    if sub in EXACT:
        return EXACT[sub]
    for keys, tag in BY_WORD:
        if any(k in sub for k in keys):
            return tag
    if sub.endswith("-generic") or sub in ("generic", "x-generic"):
        return CATEGORY.get(cat, ("FILE", SOFT))
    # anything else: its own short name, when it is short enough to type
    short = sub.split(".")[-1].split("+")[0]
    short = short[2:] if short.startswith("x-") else short
    if re.fullmatch(r"[a-z0-9]{1,4}", short or ""):
        return (short.upper(), CATEGORY.get(cat, ("FILE", SOFT))[1])
    for keys, tag in ((("sound", "audio", "music"), ("AUD", OCHRE)), (("video", "movie"), ("VID", BLUE)),
                      (("image", "picture", "photo", "drawing"), ("IMG", SAGE)),
                      (("compressed", "archive", "disk", "squashfs"), ("ARC", SOFT)),
                      (("template",), ("DOC", MADDER)), (("calendar", "vcard", "contact"), ("CAL", PLAIN))):
        if any(k in base for k in keys):
            return tag
    return CATEGORY.get(cat, ("FILE", SOFT))


def sheet(name, size):
    """A cream sheet, drawn in ink, its corner folded; its type typed on it."""
    small = size <= 24
    seed = _seed(name)
    amp = 0.6 if small else 1.1
    w = 3.0 if small else 1.6
    tag, col = tag_for(name)
    page = [(15, 6), (40, 6), (50, 16), (50, 58), (15, 58)]
    outline = _pen(page, amp, seed, closed=True)
    body = [_shadow(outline), _fill(outline, SHEET)]
    fold = _pen([(40, 6), (40, 16), (50, 16)], amp * 0.6, seed + 1, closed=True)
    body.append(_fill(fold, SHEET_FOLD))
    if small:
        # a band of the type's colour instead of its letters
        body.append('<rect x="15" y="38" width="35" height="11" style="fill:%s;opacity:0.9"/>' % col)
    else:
        for i in range(3):
            y = 46 + i * 3.6
            body.append('<path d="M 21,%.1f L %.1f,%.1f" style="stroke:%s;stroke-width:1.1;stroke-linecap:round"/>'
                        % (y, 44 - i * 5.5, y, SHEET_RULE))
        fs = {1: 13.5, 2: 13.5, 3: 12.5, 4: 10}.get(len(tag), 8.5)
        body.append('<text x="32.5" y="32" text-anchor="middle" dominant-baseline="middle" '
                    'style="font-family:%s;font-weight:bold;font-size:%.1fpx;fill:%s;letter-spacing:0.2px">%s</text>'
                    % (FONT, fs, col, tag.replace("&", "&amp;").replace("+", "&#43;")))
    body.append(_stroke(outline, w))
    body.append(_stroke(_pen([(40, 6), (40, 16), (50, 16)], amp * 0.6, seed + 2), w * 0.85))
    return _svg(size, body)
