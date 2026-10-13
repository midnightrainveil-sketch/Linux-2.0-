import QtQuick
import qs.theme
import qs.services
import "Rand.js" as Rand

// Rubber stamp impression (section 7). Two kinds:
//   oval: double ring, archive name around the edge, number in the middle
//   box:  double-ruled rectangle with one word (RECEIVED, ADMITTED, URGENT...)
// Random rotation in [-8°, +8°], 75-85 % opacity, uneven ink.
// Call press() to make it land: scale 1.12 -> 1.0 and darken, 90 ms.
Item {
    id: root

    property string kind: "oval"
    property string ring: Settings.archiveStamp      // oval: text around the top
    property string number: ""                       // oval: centre, e.g. "42817"
    property string footer: Clock.yearNumeral        // oval: text around the bottom
    property string word: "RECEIVED"                 // box
    property string sub: ""                          // box: small line under the word
    property color ink: Theme.accent
    property int seed: 3

    readonly property real _angle: Rand.make(seed)() * 16 - 8
    readonly property real _opacity: 0.75 + Rand.make(seed + 99)() * 0.10

    implicitWidth: kind === "oval" ? 132 : Math.max(96, wordMetrics.width + 34)
    implicitHeight: kind === "oval" ? 84 : (sub === "" ? 34 : 46)
    rotation: _angle
    opacity: _opacity

    function press(): void { landing.restart(); }

    TextMetrics {
        id: wordMetrics
        font.family: Theme.typewriter
        font.pixelSize: 15
        font.bold: true
        font.letterSpacing: 2
        text: root.word
    }

    Canvas {
        id: impression
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        property color c: root.ink
        onCChanged: requestPaint()
        onWidthChanged: requestPaint()

        function arcText(ctx, text, cx, cy, rx, ry, centreAngle, top) {
            ctx.save();
            const chars = text.split("");
            const spread = Math.min(Math.PI * 0.95, chars.length * 0.155);
            for (let i = 0; i < chars.length; i++) {
                const t = chars.length === 1 ? 0.5 : i / (chars.length - 1);
                const a = top ? centreAngle - spread / 2 + spread * t
                              : centreAngle + spread / 2 - spread * t;
                const x = cx + rx * Math.cos(a), y = cy + ry * Math.sin(a);
                ctx.save();
                ctx.translate(x, y);
                ctx.rotate(top ? a + Math.PI / 2 : a - Math.PI / 2);
                ctx.fillText(chars[i], 0, 0);
                ctx.restore();
            }
            ctx.restore();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const r = Rand.make(root.seed * 7 + 1);
            ctx.strokeStyle = c;
            ctx.fillStyle = c;
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            if (root.kind === "oval") {
                const cx = w / 2, cy = h / 2;
                ctx.lineWidth = 2.2;
                ctx.beginPath(); ctx.ellipse(1.5, 1.5, w - 3, h - 3); ctx.stroke();
                ctx.lineWidth = 1.1;
                ctx.beginPath(); ctx.ellipse(7, 7, w - 14, h - 14); ctx.stroke();
                ctx.font = "bold 9px '" + Theme.typewriter + "'";
                arcText(ctx, root.ring, cx, cy, w / 2 - 14, h / 2 - 13.5, -Math.PI / 2, true);
                ctx.font = "8px '" + Theme.typewriter + "'";
                arcText(ctx, root.footer, cx, cy, w / 2 - 14, h / 2 - 13.5, Math.PI / 2, false);
                ctx.font = "bold 12px '" + Theme.typewriter + "'";
                ctx.fillText(root.number === "" ? "" : "No. " + root.number, cx, cy + 1);
                // a tiny sprig, the archive's mark
                ctx.lineWidth = 0.9;
                ctx.beginPath();
                ctx.moveTo(cx + 34, cy + 14); ctx.quadraticCurveTo(cx + 38, cy + 4, cx + 36, cy - 6);
                for (let i = 0; i < 4; i++) {
                    const yy = cy + 10 - i * 4.5;
                    ctx.moveTo(cx + 36.5, yy); ctx.lineTo(cx + 40, yy - 3);
                    ctx.moveTo(cx + 36, yy); ctx.lineTo(cx + 32.5, yy - 2.5);
                }
                ctx.stroke();
            } else {
                ctx.lineWidth = 2.2;
                ctx.strokeRect(1.5, 1.5, w - 3, h - 3);
                ctx.lineWidth = 1;
                ctx.strokeRect(5, 5, w - 10, h - 10);
                ctx.font = "bold 15px '" + Theme.typewriter + "'";
                const spaced = root.word.split("").join(String.fromCharCode(0x200A));
                ctx.fillText(spaced, w / 2, root.sub === "" ? h / 2 + 1 : h / 2 - 5);
                if (root.sub !== "") {
                    ctx.font = "9px '" + Theme.typewriter + "'";
                    ctx.fillText(root.sub, w / 2, h / 2 + 11);
                }
            }

            // uneven ink: knock small specks and a few scuffs out of the impression
            ctx.globalCompositeOperation = "destination-out";
            for (let i = 0; i < (w * h) / 26; i++) {
                ctx.globalAlpha = 0.25 + r() * 0.75;
                const s = 0.4 + r() * 1.3;
                ctx.fillRect(r() * w, r() * h, s, s);
            }
            ctx.globalAlpha = 0.35;
            for (let i = 0; i < 3; i++) {
                const x = r() * w, y = r() * h;
                ctx.beginPath();
                ctx.ellipse(x, y, 10 + r() * 22, 3 + r() * 6);
                ctx.fill();
            }
            ctx.globalAlpha = 1;
            ctx.globalCompositeOperation = "source-over";
        }
    }

    SequentialAnimation {
        id: landing
        ParallelAnimation {
            NumberAnimation { target: root; property: "scale"; from: 1.12; to: 1.0; duration: Theme.durStamp; easing.type: Easing.Bezier; easing.bezierCurve: Theme.lift }
            NumberAnimation { target: root; property: "opacity"; from: root._opacity * 0.55; to: Math.min(1, root._opacity + 0.12); duration: Theme.durStamp; easing.type: Easing.Bezier; easing.bezierCurve: Theme.lift }
        }
        NumberAnimation { target: root; property: "opacity"; to: root._opacity; duration: 400 }
    }
}
