#!/usr/bin/env python3
"""Draw a theme's shell without Quickshell, to look at it in a container
where the real one cannot be built (docs/harness/build.sh).

    python3 docs/harness/preview.py <theme-id> out.png [step ...]

    steps, run in order before the picture is taken:
        ipc:<target>.<function>     as `qs ipc call <target> <function>`
        notify:<summary>|<body>     a notification arrives (_ for a space)
        key:<text>                  typed into the focused field
        nowindows | idle | notes    no windows open / nothing playing / three sample notes
        wait:<ms>

It runs the shell's own QML in Qt (PySide6: pip install PySide6-Essentials)
with stand-ins for Quickshell's types (docs/harness/standin): fixed readings
for the battery, the player, two open windows. Each layer surface is drawn
by itself and the picture put together here, 1920 x 1200 as on the G14.

It catches QML errors (printed) and shows the layout and the look. It does
NOT show that Quickshell accepts the file: its own types and properties are
only imitated here. Hyprland is not here either.
"""
import json, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from PySide6.QtCore import QSizeF, Signal, QObject, QTimer, QUrl, Slot, Property, QDateTime, Qt, QMetaObject
from PySide6.QtGui import QGuiApplication, QFontDatabase, QImage, QPainter, QColor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow

REPO = Path(__file__).resolve().parents[2]
W, H = 1920, 1200
LAYERS = ["Background", "Bottom", "Windows", "Top", "Overlay", "Lock"]


def prepare(theme, work, flags=()):
    """The theme's home with the machine's, and the shell made loadable."""
    home = work / "home"
    for src in (REPO / "core/home", REPO / "themes" / theme / "home"):
        shutil.copytree(src, home, dirs_exist_ok=True, symlinks=False)
    shell = home / ".config/quickshell"
    for d in [p for p in shell.rglob("*") if p.is_dir()] + [shell]:
        names = sorted(f.stem for f in d.glob("*.qml"))
        lines = [("singleton " if "pragma Singleton" in (d / f"{n}.qml").read_text() else "") + f"{n} 1.0 {n}.qml" for n in names]
        if lines:
            (d / "qmldir").write_text("\n".join(lines) + "\n")
    for f in shell.rglob("*.qml"):
        up = os.path.relpath(shell, f.parent)
        out = []
        root_is_panel = re.search(r"^PanelWindow \{", f.read_text(), re.M) is not None
        for line in f.read_text().split("\n"):
            m = re.match(r"\s*import qs\.([\w.]+)", line)
            if m:
                line = f'import "{up}/{m.group(1).replace(".", "/")}"'
            m = re.match(r"(\s*)WlrLayershell\.(\w+):\s*(.*)", line)
            if m:
                ind, key, val = m.groups()
                if key == "layer":
                    line = f'{ind}_layer: "{val.split(".")[-1]}"'
                elif key == "namespace":
                    line = f"{ind}_namespace: {val}"
                else:
                    continue
            # (a window inside a plain object is never shown offscreen: what
            # the shell wants is kept in _visible, and drawn from that)
            if root_is_panel and re.match(r"    visible:", line):
                line = "    _visible:" + line[len("    visible:"):]
            out.append(line)
        f.write_text("\n".join(out))
    if "notes" in flags:
        own = home / ".config/ultra" / theme
        own.mkdir(parents=True, exist_ok=True)
        (own / "notes.txt").write_text("[x] Edit rain roll\n[ ] Backup photos\n[ ] Plan next shoot\n")
    return home, shell


class Harness(QObject):
    notify = Signal(str, str)

    def __init__(self, home, shell, flags):
        super().__init__()
        self.home, self.shell, self.flags = home, shell, flags

    @Slot(result="QVariant")
    def now(self):
        return QDateTime.currentDateTime()

    @Slot(str, result=str)
    def env(self, name):
        return {"HOME": str(self.home), "USER": "misaki"}.get(name, "")

    @Slot(str)
    def note(self, text):
        print("  ·", text)

    @Slot(str, result="QVariant")
    def readFile(self, path):
        p = Path(path.replace("file://", ""))
        return p.read_text() if p.is_file() else None

    @Slot(str, result=str)
    def run(self, command):
        cmd = json.loads(command)
        name = Path(cmd[0]).name if cmd else ""
        if name == "ultra-vitals":
            return "12 5.1 33 41"
        if name == "ultra-brightness":
            return "50"
        if name == "ultra-screenshot":
            return "11"
        if name == "sh" and "ultra-theme list" in cmd[-1]:
            tool = [sys.executable, str(REPO / "core/home/.local/bin/ultra-theme")]
            return subprocess.run(tool + ["list"], capture_output=True, text=True).stdout.strip() + "\nviewfinder\n"
        return ""

    def _get(self, key):
        return getattr(self, key)

    screenW = Property(int, lambda self: W, constant=True)
    screenH = Property(int, lambda self: H, constant=True)
    shellDir = Property(str, lambda self: str(self.shell), constant=True)
    playing = Property(bool, lambda self: "idle" not in self.flags, constant=True)

    @Property("QVariantList", constant=True)
    def windows(self):
        if "nowindows" in self.flags:
            return []
        return [
            {"address": "0x1", "title": "foot", "class": "viewfinder.desk", "at": [262, 176], "size": [412, 266], "fullscreen": 0, "hidden": False, "mapped": True},
            {"address": "0x2", "title": "Files", "class": "org.gnome.Nautilus", "at": [698, 176], "size": [406, 266], "fullscreen": 0, "hidden": False, "mapped": True},
        ]

    @Property("QVariantList", constant=True)
    def apps(self):
        names = [("foot", "Foot", "Terminal emulator"), ("org.gnome.Nautilus", "Files", "Access and organise files"),
                 ("firefox", "Firefox", "Browse the World Wide Web"), ("code", "Visual Studio Code", "Code editing. Redefined."),
                 ("org.gnome.TextEditor", "Text Editor", "Edit text files"), ("org.gnome.gThumb", "gThumb", "View and organise your images"),
                 ("btop", "btop++", "Resource monitor"), ("org.pulseaudio.pavucontrol", "Volume Control", "Adjust the volume level"),
                 ("viewfinder-themes", "Themes", "Choose the desktop theme"), ("rviz2", "RViz", "ROS visualisation")]
        return [{"id": i, "name": n, "comment": c, "genericName": "", "keywords": [], "categories": [], "noDisplay": False,
                 "runInTerminal": False, "command": [i]} for i, n, c in names]


def place(win):
    """Where a layer surface lies on the screen."""
    plain = lambda v: v.toVariant() if hasattr(v, "toVariant") else v
    top, bottom, left, right = [bool(v) for v in plain(win.property("_edges"))]
    mt, mb, ml, mr = [float(v) for v in plain(win.property("_margins"))]
    w, h = win.width(), win.height()
    x = ml if left else W - w - mr if right else (W - w) / 2
    y = mt if top else H - h - mb if bottom else (H - h) / 2
    return int(x), int(y)


def size(win):
    """A layer surface's size: between the edges it is fixed to, else its own."""
    plain = lambda v: v.toVariant() if hasattr(v, "toVariant") else v
    top, bottom, left, right = [bool(v) for v in plain(win.property("_edges"))]
    mt, mb, ml, mr = [float(v) for v in plain(win.property("_margins"))]
    iw, ih = win.property("implicitWidth"), win.property("implicitHeight")
    win.setWidth(int(W - ml - mr if left and right else max(1, iw or 1)))
    win.setHeight(int(H - mt - mb if top and bottom else max(1, ih or 1)))


def main():
    theme, out, steps = sys.argv[1], sys.argv[2], sys.argv[3:]
    work = Path(tempfile.mkdtemp(prefix="preview-"))
    home, shell = prepare(theme, work, set(steps))
    app = QGuiApplication(sys.argv[:1])
    for f in (home / ".local/share/fonts").rglob("*.[to]tf"):
        QFontDatabase.addApplicationFont(str(f))
    engine = QQmlApplicationEngine()
    harness = Harness(home, shell, set(steps))
    engine.rootContext().setContextProperty("harness", harness)
    engine.addImportPath(str(Path(__file__).parent / "standin"))
    problems = []
    engine.warnings.connect(lambda ws: problems.extend(w.toString() for w in ws))
    engine.load(QUrl.fromLocalFile(str(shell / "shell.qml")))
    if not engine.rootObjects():
        print("the shell did not load"); print("\n".join(problems)); sys.exit(1)
    root = engine.rootObjects()[0]

    def spin(ms):
        # (never shown, a window's content keeps no size of its own)
        for w in app.allWindows():
            if w.objectName() == "panel":
                size(w)
                w.contentItem().setSize(QSizeF(w.width(), w.height()))
        QTimer.singleShot(ms, app.quit); app.exec()

    spin(300)
    spin(2500)
    for s in steps:
        kind, _, arg = s.partition(":")
        if kind == "ipc":
            target, _, fn = arg.partition(".")
            for h in root.findChildren(QObject, "ipc"):
                if h.property("target") == target:
                    QMetaObject.invokeMethod(h, fn)
        elif kind == "notify":
            summary, _, body = arg.partition("|")
            harness.notify.emit(summary.replace("_", " "), body.replace("_", " "))
        elif kind == "key":
            from PySide6.QtGui import QKeyEvent
            from PySide6.QtCore import QEvent
            for w in app.allWindows():
                item = w.activeFocusItem() if hasattr(w, "activeFocusItem") else None
                if item is not None and w.property("_visible") and w.property("_layer") in ("Overlay", "Lock"):
                    for ch in arg:
                        app.sendEvent(w, QKeyEvent(QEvent.KeyPress, 0, Qt.NoModifier, ch))
        elif kind == "wait":
            spin(int(arg))
        spin(200)
        spin(400)
    spin(600)
    # (a window never shown lays its content out only when drawn: draw the
    # small ones first, so that a surface sized by its content has its size)
    for _ in range(2):
        for w in app.allWindows():
            if w.objectName() == "panel" and w.property("_visible") and w.width() * w.height() < 600000:
                w.grabWindow()
                size(w)
                w.contentItem().setSize(QSizeF(w.width(), w.height()))
        app.processEvents()

    canvas = QImage(W, H, QImage.Format_ARGB32_Premultiplied)
    canvas.fill(QColor("#000000"))
    p = QPainter(canvas)
    panels = [w for w in app.allWindows() if w.property("_visible") and w.objectName() == "panel"]
    if os.environ.get("PREVIEW_DEBUG"):
        for w in app.allWindows():
            print("   window", w.property("implicitWidth"), w.property("implicitHeight"), w.objectName(), w.property("_visible"), w.width(), w.height(), w.property("_layer"), w.property("_namespace"))
    for layer in LAYERS:
        if layer == "Windows":
            for w in harness.windows:      # stand-ins for the open programs
                x, y = w["at"]; ww, hh = w["size"]
                p.fillRect(x, y, ww, hh, QColor(12, 11, 12, 236))
                p.setPen(QColor("#f2efed")); p.drawRect(x, y, ww - 1, hh - 1)
            continue
        for w in panels:
            if (w.property("_layer") or "Top") != layer:
                continue
            x, y = place(w)
            p.drawImage(x, y, w.grabWindow())
    p.end()
    canvas.save(out)
    print("picture:", out)
    seen = sorted(set(problems))
    print("QML warnings: %d" % len(seen))
    for w in seen:
        print("  " + w.replace(str(work), ""))
    shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
