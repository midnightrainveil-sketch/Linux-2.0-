import QtQuick
import QtQuick.Effects
import qs.theme

// A compact cassette, seen from above (100 x 64 mm, drawn to `width`):
// charcoal shell lit from the top, five screws, the raised strip along the
// bottom with its tape openings, a paper label (a madder band: ARCHIVE,
// C-60, side A; the title typed on its line) and, through the window, the
// two reels of brown tape. While it plays the hubs turn, and the tape winds
// from the left reel to the right as the song goes on (`progress`, 0 to 1).
Item {
    id: root

    property string title: ""
    property real progress: 0.2
    property bool playing: false

    implicitWidth: 150
    height: width * 0.64
    readonly property real u: width / 100

    // ------------------------------------------------ the shell and the label
    Canvas {
        id: shell
        anchors.fill: parent
        property string title: root.title
        onTitleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const u = root.u, W = width, H = height;
            const rr = (x, y, w, h, r) => {
                g.beginPath();
                g.moveTo(x + r, y); g.lineTo(x + w - r, y); g.arcTo(x + w, y, x + w, y + r, r);
                g.lineTo(x + w, y + h - r); g.arcTo(x + w, y + h, x + w - r, y + h, r);
                g.lineTo(x + r, y + h); g.arcTo(x, y + h, x, y + h - r, r);
                g.lineTo(x, y + r); g.arcTo(x, y, x + r, y, r);
                g.closePath();
            };
            // the shell: lit along the top, darker toward the bottom
            const body = g.createLinearGradient(0, 0, 0, H);
            body.addColorStop(0, "#56545a");
            body.addColorStop(0.5, "#3a383d");
            body.addColorStop(1, "#2a292d");
            g.fillStyle = body;
            rr(0.5, 0.5, W - 1, H - 1, 3 * u); g.fill();
            g.strokeStyle = "#1e1d21"; g.lineWidth = 0.5 * u; g.stroke();
            g.strokeStyle = "rgba(255,255,255,0.10)"; g.lineWidth = 0.35 * u;
            rr(0.9 * u, 0.9 * u, W - 1.8 * u, H - 1.8 * u, 2.4 * u); g.stroke();

            // the raised strip along the bottom, with its openings
            g.fillStyle = "#2c2b2f";
            g.beginPath();
            g.moveTo(18 * u, H - 0.6 * u); g.lineTo(24 * u, H - 12 * u);
            g.lineTo(76 * u, H - 12 * u); g.lineTo(82 * u, H - 0.6 * u);
            g.closePath(); g.fill();
            g.strokeStyle = "rgba(255,255,255,0.12)"; g.lineWidth = 0.4 * u;
            g.beginPath(); g.moveTo(24 * u, H - 12 * u); g.lineTo(76 * u, H - 12 * u); g.stroke();
            g.fillStyle = "#121114";
            for (const x of [30, 50, 70]) g.fillRect((x - 3) * u, H - 6 * u, 6 * u, 3 * u);
            for (const x of [26.5, 73.5]) { g.beginPath(); g.arc(x * u, H - 6.9 * u, 1.6 * u, 0, Math.PI * 2); g.fill(); }
            // the tape's path past the heads
            g.strokeStyle = "#5c3e2c"; g.lineWidth = 0.7 * u;
            g.beginPath(); g.moveTo(24 * u, H - 2.6 * u); g.lineTo(76 * u, H - 2.6 * u); g.stroke();

            // five screws
            for (const [x, y] of [[3.5, 3.5], [96.5, 3.5], [3.5, 60.5], [96.5, 60.5], [50, 58.5]]) {
                const cx = x * u, cy = y * u, r = 1.5 * u;
                g.fillStyle = "#7c7a7e";
                g.beginPath(); g.arc(cx, cy, r, 0, Math.PI * 2); g.fill();
                g.strokeStyle = "#1e1d21"; g.lineWidth = 0.3 * u; g.stroke();
                g.strokeStyle = "#2c2b2f"; g.lineWidth = 0.4 * u;
                g.beginPath(); g.moveTo(cx - r * 0.7, cy - r * 0.7); g.lineTo(cx + r * 0.7, cy + r * 0.7);
                g.moveTo(cx - r * 0.7, cy + r * 0.7); g.lineTo(cx + r * 0.7, cy - r * 0.7); g.stroke();
            }

            // the label
            const lx = 6 * u, ly = 5 * u, lw = 88 * u, lh = 39 * u;
            g.fillStyle = "#e8e0ce";
            rr(lx, ly, lw, lh, 1.2 * u); g.fill();
            g.save(); rr(lx, ly, lw, lh, 1.2 * u); g.clip();
            g.fillStyle = "#96624f";
            g.fillRect(lx, ly, lw, 6 * u);
            g.fillStyle = "#aa8c52";
            g.fillRect(lx, ly + 6.6 * u, lw, 0.7 * u);
            g.restore();
            g.fillStyle = "#f0e8d8";
            g.font = "bold " + Math.round(3.6 * u) + "px '" + Theme.typewriter + "'";
            g.textBaseline = "middle";
            g.fillText("ARCHIVE", lx + 2 * u, ly + 3.1 * u);
            g.fillText("A", lx + lw - 5 * u, ly + 3.1 * u);
            g.font = Math.round(2.8 * u) + "px '" + Theme.typewriter + "'";
            g.fillText("C-60", lx + lw - 16 * u, ly + 3.2 * u);
            // the writing lines, the title typed on the first
            g.strokeStyle = "#b4aa98"; g.lineWidth = 0.25 * u;
            for (let i = 0; i < 2; i++) {
                const y = ly + 12.5 * u + i * 4.2 * u;
                g.beginPath(); g.moveTo(lx + 3 * u, y); g.lineTo(lx + lw - 3 * u, y); g.stroke();
            }
            g.fillStyle = "#4e4b50";
            g.font = Math.round(3.1 * u) + "px '" + Theme.typewriter + "'";
            g.textBaseline = "alphabetic";
            let t = title || "no recording";
            while (t.length > 3 && g.measureText(t).width > lw - 7 * u) t = t.slice(0, -2) + "…";
            g.fillText(t, lx + 3.5 * u, ly + 11.8 * u);

            // the window
            g.fillStyle = "#1c1b1f";
            rr(22 * u, 22 * u, 56 * u, 15 * u, 5 * u); g.fill();
        }
    }

    // ------------------------------------------------ the reels, in the window
    Item {
        id: window_
        x: 22 * root.u
        y: 22 * root.u
        width: 56 * root.u
        height: 15 * root.u
        clip: true

        Repeater {
            model: 2
            Canvas {
                id: reel
                required property int index
                // the tape wound on it: full on the left at the start
                readonly property real full: index === 0 ? 1 - root.progress : root.progress
                readonly property real radius: Math.round((5.2 + 8.5 * full) * 4) / 4
                width: 28 * root.u
                height: 28 * root.u
                x: (index === 0 ? 13 : 43) * root.u - width / 2
                y: 7.5 * root.u - height / 2
                onRadiusChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    const u = root.u, c = width / 2, R = radius * u;
                    g.fillStyle = "#5c3e2c";
                    g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.fill();
                    g.strokeStyle = "rgba(140,100,72,0.35)"; g.lineWidth = 0.6;
                    for (let r = 5.6 * u; r < R; r += 1.3 * u) { g.beginPath(); g.arc(c, c, r, 0, Math.PI * 2); g.stroke(); }
                    // the white hub and its teeth
                    g.fillStyle = "#dedad2";
                    g.beginPath(); g.arc(c, c, 5 * u, 0, Math.PI * 2); g.fill();
                    g.fillStyle = "#1c1b1f";
                    g.beginPath(); g.arc(c, c, 2.6 * u, 0, Math.PI * 2); g.fill();
                    g.strokeStyle = "#dedad2"; g.lineWidth = 0.8 * u;
                    for (let t = 0; t < 6; t++) {
                        const a = t * Math.PI / 3;
                        g.beginPath();
                        g.moveTo(c + Math.cos(a) * 1.4 * u, c + Math.sin(a) * 1.4 * u);
                        g.lineTo(c + Math.cos(a) * 2.6 * u, c + Math.sin(a) * 2.6 * u);
                        g.stroke();
                    }
                }
                RotationAnimation on rotation {
                    running: root.playing && root.visible
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 2600
                }
            }
        }
    }
    // the window's rounded ends and the glint on its clear plastic
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const u = root.u, x = 22 * u, y = 22 * u, w = 56 * u, h = 15 * u, r = 5 * u;
            // the label's paper round the window's rounded ends
            g.fillStyle = "#e8e0ce";
            g.beginPath();
            g.rect(x - 0.5, y - 0.5, w + 1, h + 1);
            g.moveTo(x + r, y); g.lineTo(x + w - r, y); g.arcTo(x + w, y, x + w, y + r, r);
            g.lineTo(x + w, y + h - r); g.arcTo(x + w, y + h, x + w - r, y + h, r);
            g.lineTo(x + r, y + h); g.arcTo(x, y + h, x, y + h - r, r);
            g.lineTo(x, y + r); g.arcTo(x, y, x + r, y, r);
            g.closePath();
            g.fillRule = Qt.OddEvenFill;
            g.fill();
            g.fillRule = Qt.WindingFill;
            g.strokeStyle = "#141316"; g.lineWidth = 0.4 * u;
            g.beginPath();
            g.moveTo(x + r, y); g.lineTo(x + w - r, y); g.arcTo(x + w, y, x + w, y + r, r);
            g.lineTo(x + w, y + h - r); g.arcTo(x + w, y + h, x + w - r, y + h, r);
            g.lineTo(x + r, y + h); g.arcTo(x, y + h, x, y + h - r, r);
            g.lineTo(x, y + r); g.arcTo(x, y, x + r, y, r);
            g.stroke();
            g.fillStyle = "rgba(255,255,255,0.16)";
            g.beginPath();
            g.moveTo(x + 8 * u, y); g.lineTo(x + 16 * u, y); g.lineTo(x + 6 * u, y + h); g.lineTo(x - 2 * u, y + h);
            g.closePath();
            g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip();
            g.beginPath();
            g.moveTo(x + 8 * u, y); g.lineTo(x + 16 * u, y); g.lineTo(x + 6 * u, y + h); g.lineTo(x - 2 * u, y + h);
            g.closePath(); g.fill();
            g.restore();
        }
    }

    // it lies on the card: a short soft shadow
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.shadow
        blurMax: 24
        shadowBlur: 0.35
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 1.5
        shadowOpacity: 0.9
    }
}
