import QtQuick
import qs.theme

// A round push button standing up out of its socket: a domed cap lit from
// the top left, its shadow on the plate, an engraved sign on it. Pressed,
// it sinks into the socket. For the players: previous, pause / play, next.
//
//   kind: "previous" | "toggle" | "next"     tone: "brass" | "ivory"
Item {
    id: root

    property string kind: "toggle"
    property bool playing: false             // toggle: shows pause while playing
    property string tone: "brass"
    property real size: 30                   // the cap's diameter
    signal clicked()

    readonly property bool down: press.pressed
    width: size + 8
    height: size + 10

    readonly property color body: tone === "brass"
        ? (Theme.night > 0.5 ? "#8d97aa" : "#b49663")
        : (Theme.night > 0.5 ? "#c9cfd8" : "#e8e1d2")
    readonly property color ink: tone === "brass" ? Qt.rgba(0.17, 0.11, 0.05, 0.85) : Qt.rgba(0.14, 0.13, 0.15, 0.85)

    Canvas {
        id: face
        anchors.fill: parent
        property bool down: root.down
        property bool playing: root.playing
        property color body: root.body
        onDownChanged: requestPaint()
        onPlayingChanged: requestPaint()
        onBodyChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const cx = width / 2, cy = root.size / 2 + 4;
            const r = root.size / 2;
            const sink = down ? 1.6 : 0;
            const b = body;
            const shade = (k, a) => Qt.rgba(b.r * k, b.g * k, b.b * k, a === undefined ? 1 : a);
            const lit = (k) => Qt.rgba(b.r + (1 - b.r) * k, b.g + (1 - b.g) * k, b.b + (1 - b.b) * k, 1);

            // the socket it stands in: a dark ring, deepest at the top
            const sock = g.createRadialGradient(cx, cy + 1, r - 1, cx, cy + 1, r + 3.5);
            sock.addColorStop(0, "rgba(0,0,0,0.55)");
            sock.addColorStop(1, "rgba(0,0,0,0.05)");
            g.fillStyle = sock;
            g.beginPath(); g.arc(cx, cy + 1, r + 3.5, 0, Math.PI * 2); g.fill();

            // its shadow, falling down and to the right
            if (!down) {
                g.fillStyle = "rgba(0,0,0,0.30)";
                g.beginPath(); g.ellipse(cx - r + 1.5, cy - r + 3.5, 2 * r, 2 * r); g.fill();
            }

            // the side of the cap (seen as a darker band below the dome)
            g.fillStyle = shade(0.62);
            g.beginPath(); g.arc(cx, cy + sink + 2.2, r, 0, Math.PI * 2); g.fill();

            // the dome, lit from the top left
            const dome = g.createRadialGradient(cx - r * 0.35, cy + sink - r * 0.4, r * 0.1, cx, cy + sink, r);
            dome.addColorStop(0, String(lit(down ? 0.25 : 0.45)));
            dome.addColorStop(0.55, String(b));
            dome.addColorStop(1, String(shade(0.72)));
            g.fillStyle = dome;
            g.beginPath(); g.arc(cx, cy + sink, r, 0, Math.PI * 2); g.fill();
            // a fine rim, and the gleam along the top
            g.strokeStyle = "rgba(0,0,0,0.45)"; g.lineWidth = 1;
            g.beginPath(); g.arc(cx, cy + sink, r - 0.5, 0, Math.PI * 2); g.stroke();
            g.strokeStyle = "rgba(255,255,255,0.45)"; g.lineWidth = 1.2;
            g.beginPath(); g.arc(cx, cy + sink, r - 2, Math.PI * 1.05, Math.PI * 1.6); g.stroke();

            // the engraved sign: dark, with a light edge below it
            const s = r * 0.42;
            const sign = (dy, colour) => {
                g.fillStyle = colour;
                const x0 = cx, y0 = cy + sink + dy;
                const tri = (x, dir) => {
                    g.beginPath();
                    g.moveTo(x - dir * s * 0.55, y0 - s);
                    g.lineTo(x + dir * s * 0.8, y0);
                    g.lineTo(x - dir * s * 0.55, y0 + s);
                    g.closePath(); g.fill();
                };
                if (root.kind === "toggle") {
                    if (playing) { g.fillRect(x0 - s * 0.72, y0 - s, s * 0.5, 2 * s); g.fillRect(x0 + s * 0.22, y0 - s, s * 0.5, 2 * s); }
                    else tri(x0 + s * 0.12, 1);
                } else {
                    const dir = root.kind === "next" ? 1 : -1;
                    tri(x0 - dir * s * 0.4, dir);
                    g.fillRect(x0 + dir * s * 0.62 - s * 0.14, y0 - s, s * 0.28, 2 * s);
                }
            };
            sign(0.8, "rgba(255,255,255,0.35)");
            sign(0, String(root.ink));
        }
    }
    MouseArea {
        id: press
        x: 4; y: 4
        width: root.size; height: root.size
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
