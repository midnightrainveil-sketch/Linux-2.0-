import QtQuick
import qs.theme
import "Rand.js" as Rand

// A player sign drawn in pen on the card, like the plates in the wallpaper:
// a wavering outline, filled in with a few hatched strokes. Pause / play is
// ringed in a loose pencilled circle. On the pointer the ink darkens; held,
// it turns the accent and shifts a hair, as if pressed into the paper.
//
//   kind: "previous" | "toggle" | "next"
Item {
    id: root

    property string kind: "toggle"
    property bool playing: false            // toggle: shows pause while playing
    property real size: 24
    property int seed: 41
    signal clicked()

    width: size
    height: size

    readonly property color ink: press.pressed ? Theme.accent
                               : press.containsMouse ? Theme.graphite : Theme.soft

    Canvas {
        id: pen
        anchors.fill: parent
        anchors.topMargin: press.pressed ? 0.8 : 0
        renderStrategy: Canvas.Cooperative
        property color ink: root.ink
        property bool playing: root.playing
        onInkChanged: requestPaint()
        onPlayingChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const g = getContext("2d");
            g.reset();
            const r = Rand.make(root.seed + (root.playing ? 7 : 0));
            const w = width, c = w / 2;
            g.strokeStyle = ink;
            g.lineCap = "round";
            g.lineJoin = "round";

            // a wavering line through the points (closed: back to the first)
            const line = (pts, closed, weight) => {
                g.lineWidth = weight;
                g.beginPath();
                const all = closed ? pts.concat([pts[0]]) : pts;
                for (let i = 0; i + 1 < all.length; i++) {
                    const seg = Rand.wobble(r, all[i][0], all[i][1], all[i + 1][0], all[i + 1][1], 0.35, 4);
                    if (i === 0) g.moveTo(seg[0][0], seg[0][1]);
                    for (let k = 1; k < seg.length; k++) g.lineTo(seg[k][0], seg[k][1]);
                }
                g.stroke();
            };
            // hatching across a shape, upright strokes from x0 to x1, kept
            // inside by top(x) / bottom(x)
            const hatch = (x0, x1, top, bottom, n) => {
                for (let i = 1; i < n; i++) {
                    const x = x0 + (x1 - x0) * i / n + (r() - 0.5) * 0.4;
                    const t = top(x) + 0.9, b = bottom(x) - 0.9;
                    if (b - t > 0.8) line([[x + 0.3, t], [x - 0.3, b]], false, 0.75);
                }
            };
            // a triangle pointing dir (1 right, -1 left) with its tip at x
            const tri = (tipX, dir, h, len) => {
                const back = tipX - dir * len;
                line([[back, c - h], [tipX, c], [back, c + h]], true, 1.15);
                const lo = Math.min(back, tipX), hi = Math.max(back, tipX);
                const half = x => h * Math.abs(tipX - x) / len;
                hatch(lo, hi, x => c - half(x), x => c + half(x), 4);
            };

            const s = w * (root.kind === "toggle" ? 0.2 : 0.24);
            if (root.kind === "toggle") {
                // the loose pencilled ring, not quite closed
                g.globalAlpha = 0.55;
                g.lineWidth = 0.9;
                g.beginPath();
                const start = -2.2 + r() * 0.3, turns = Math.PI * 2 * 0.94;
                for (let i = 0; i <= 40; i++) {
                    const a = start + turns * i / 40;
                    const rad = c - 1.3 + (r() - 0.5) * 0.5 + 0.4 * Math.sin(a * 3);
                    const x = c + rad * Math.cos(a), y = c + rad * Math.sin(a);
                    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
                }
                g.stroke();
                g.globalAlpha = 1;
                if (root.playing) {
                    for (const x of [c - s * 0.85, c + s * 0.25]) {
                        line([[x, c - s], [x + s * 0.6, c - s], [x + s * 0.6, c + s], [x, c + s]], true, 1.15);
                        hatch(x, x + s * 0.6, () => c - s, () => c + s, 2);
                    }
                } else {
                    tri(c + s * 1.0, 1, s, s * 1.65);
                }
            } else {
                const dir = root.kind === "next" ? 1 : -1;
                tri(c + dir * s * 0.55, dir, s, s * 1.4);
                const bar = c + dir * s * 0.95;
                line([[bar, c - s], [bar + (r() - 0.5) * 0.4, c + s]], false, 1.5);
            }
        }
    }

    MouseArea {
        id: press
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
