import QtQuick
import QtQuick.Effects

// Amber seven-segment digits, as on the Suisei DC-80: "HH:MM", leaning a
// little forward, the unlit segments faintly there behind the lit ones.
// Drawn in its own units (a cell of 154 x 77, the clock's window in the
// lock picture); the item may be any size.
//
// Built to cost little: each digit is its own canvas and is drawn again only
// when that digit changes (a minute's turn redraws one); the colon is two
// plain shapes (its blink redraws nothing); the glow is one pass on the
// GPU over all of it, not a blur in the canvas.
Item {
    id: face

    property string text: "88:88"
    property bool colon: true
    property color lit: "#ffb04c"
    property color glow: "#ff8a1e"
    property color unlit: Qt.rgba(1, 0.62, 0.25, 0.07)

    // its layout, in its own units (by default the lock screen clock's
    // window, in picture pixels); the item may be any size
    property real cellW: 154
    property real cellH: 77
    property var digitX: [13, 42, 85, 114]              // each digit's lower-left corner
    property real digitTop: 16.5
    property real dw: 24                                // digit width, height, stroke
    property real dh: 45
    property real t: 4.8
    property real gap: 0.9                              // between one segment and the next
    property real tv: 0                                 // the uprights' thickness (0: as t)
    property real chamfer: 1                            // the ends: 1 pointed, less blunt
    property bool miter: false                          // mitred joints instead (a real tube's)
    property real lean: 0.2                             // forward lean, as in the picture
    property real colonX: 78.5                          // the colon's upper and lower dot
    property real colonX2: 76
    property real dotR: 2.6
    property bool dotSquare: false                      // the colon's dots square (rounded)
    property real glowWide: 9                           // the glow's reach, in these units
    property real glowNear: 3                           // (kept for the clocks that set it)
    // a lit face on each segment, as on a real tube: a brighter core, darker
    // edges, a fine grain (off: flat, as on the lock screen's little clock)
    property bool relief: false
    property color faceCore: "#ffbd46"
    property color faceEdge: "#f29a22"
    property color grainLight: Qt.rgba(1, 0.97, 0.85, 0.22)
    property color grainDark: Qt.rgba(1, 0.75, 0.35, 0.18)
    property real grainSize: 1.3

    readonly property real k: width / cellW              // units to pixels
    readonly property string chars: (text.replace(":", "") + "    ").slice(0, 4)

    // segments a..g of each digit
    readonly property var segs: ({
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
        " ": "", "-": "g"
    })

    function segment(ctx, x, y, name) {
        // an eight-sided slab: bars t thick, uprights tv; the corners cut by
        // chamfer of half the thickness (1: pointed ends, as on the lock
        // screen; less: blunt slabs)
        const w = dw, h = dh, hb = t / 2, hv = (tv > 0 ? tv : t) / 2, g = face.gap, mid = h / 2;
        function oct(x0, y0, x1, y1, cx, cy) {
            ctx.moveTo(x0, y0 + cy); ctx.lineTo(x0 + cx, y0); ctx.lineTo(x1 - cx, y0); ctx.lineTo(x1, y0 + cy);
            ctx.lineTo(x1, y1 - cy); ctx.lineTo(x1 - cx, y1); ctx.lineTo(x0 + cx, y1); ctx.lineTo(x0, y1 - cy);
            ctx.closePath();
        }
        if (miter) {
            // mitred: each bar a trapezoid, wide on the outside, its ends cut
            // to meet the next along a diagonal gap
            const v = 2 * hv, yc = y + mid;
            const P = pts => { ctx.moveTo(pts[0][0], pts[0][1]); for (const q of pts.slice(1)) ctx.lineTo(q[0], q[1]); ctx.closePath(); };
            // the outer corners left open: a bar's outer edge stops short
            // (cb), an upright's too (cv)
            const cb = 0.25 * v, cv = 0.25 * t;
            switch (name) {
            case "a": P([[x + cb + g, y], [x + w - cb - g, y], [x + w - v - g, y + t], [x + v + g, y + t]]); break;
            case "d": P([[x + v + g, y + h - t], [x + w - v - g, y + h - t], [x + w - cb - g, y + h], [x + cb + g, y + h]]); break;
            case "g": P([[x + g, yc], [x + v + g, yc - hb], [x + w - v - g, yc - hb], [x + w - g, yc],
                         [x + w - v - g, yc + hb], [x + v + g, yc + hb]]); break;
            case "f": P([[x, y + cv + g], [x + v, y + t + g], [x + v, yc - hb - g], [x, yc - g]]); break;
            case "e": P([[x, yc + g], [x + v, yc + hb + g], [x + v, y + h - t - g], [x, y + h - cv - g]]); break;
            case "b": P([[x + w, y + cv + g], [x + w, yc - g], [x + w - v, yc - hb - g], [x + w - v, y + t + g]]); break;
            case "c": P([[x + w, yc + g], [x + w, y + h - cv - g], [x + w - v, y + h - t - g], [x + w - v, yc + hb + g]]); break;
            }
            return;
        }
        const cb = chamfer * hb, cv = chamfer * hv;
        function hor(yc) { oct(x + g, yc - hb, x + w - g, yc + hb, Math.min(cb, hb), cb); }
        function ver(xc, y0, y1) { oct(xc - hv, y0 + g, xc + hv, y1 - g, cv, Math.min(cv, hv)); }
        switch (name) {
        case "a": hor(y + hb); break;
        case "g": hor(y + mid); break;
        case "d": hor(y + h - hb); break;
        case "f": ver(x + hv, y + hb, y + mid); break;
        case "b": ver(x + w - hv, y + hb, y + mid); break;
        case "e": ver(x + hv, y + mid, y + h - hb); break;
        case "c": ver(x + w - hv, y + mid, y + h - hb); break;
        }
    }

    function digit(ctx, x, ch, which) {
        const on = segs[ch] ?? "";
        ctx.beginPath();
        for (const n of "abcdefg")
            if ((which === "on") === (on.indexOf(n) >= 0)) segment(ctx, x, digitTop, n);
        ctx.fill();
    }

    // a segment's box: [horizontal, x0, y0, x1, y1]
    function segBox(x, y, name) {
        const w = dw, h = dh, hb = t / 2, sv = tv > 0 ? tv : t, mid = h / 2;
        switch (name) {
        case "a": return [true, x, y, x + w, y + t];
        case "g": return [true, x, y + mid - hb, x + w, y + mid + hb];
        case "d": return [true, x, y + h - t, x + w, y + h];
        case "f": return [false, x, y, x + sv, y + mid];
        case "b": return [false, x + w - sv, y, x + w, y + mid];
        case "e": return [false, x, y + mid, x + sv, y + h];
        default:  return [false, x + w - sv, y + mid, x + w, y + h];
        }
    }
    // the lit segments' faces, each its own: shaded across, and a grain that
    // stays put from one paint to the next
    function faces(ctx, x, ch, seed) {
        const on = segs[ch] ?? "";
        for (const n of "abcdefg") {
            if (on.indexOf(n) < 0) continue;
            const b = segBox(x, digitTop, n);
            const g = b[0] ? ctx.createLinearGradient(0, b[2], 0, b[4]) : ctx.createLinearGradient(b[1], 0, b[3], 0);
            g.addColorStop(0, faceEdge); g.addColorStop(0.42, faceCore);
            g.addColorStop(0.58, faceCore); g.addColorStop(1, faceEdge);
            ctx.save();
            ctx.beginPath(); segment(ctx, x, digitTop, n); ctx.clip();
            ctx.fillStyle = g;
            ctx.fillRect(b[1] - 2, b[2] - 2, b[3] - b[1] + 4, b[4] - b[2] + 4);
            let r = (seed * 7919 + n.charCodeAt(0) * 131) % 2147483647 + 1;
            const next = () => { r = (r * 16807) % 2147483647; return r / 2147483647; };
            const count = Math.round((b[3] - b[1]) * (b[4] - b[2]) / 22);
            for (let i = 0; i < count; i++) {
                const px = b[1] + next() * (b[3] - b[1]), py = b[2] + next() * (b[4] - b[2]);
                ctx.fillStyle = next() < 0.5 ? grainLight : grainDark;
                ctx.fillRect(px, py, grainSize, grainSize);
            }
            ctx.restore();
        }
    }

    // ---- what glows: the four digits and the colon, through one glow
    Item {
        id: glowing
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: face.glow
            shadowOpacity: 0.95
            shadowBlur: 1.0
            blurMax: Math.max(4, Math.min(64, Math.round(face.glowWide * face.k * 1.6)))
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Repeater {
            model: 4
            Canvas {
                id: digitCanvas
                required property int index
                anchors.fill: parent
                readonly property string ch: face.chars[index]
                renderStrategy: Canvas.Cooperative
                onChChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections {
                    target: face
                    function onLitChanged() { digitCanvas.requestPaint(); }
                    function onReliefChanged() { digitCanvas.requestPaint(); }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);
                    ctx.scale(face.k, height / face.cellH);
                    const base = face.digitTop + face.dh;
                    ctx.transform(1, 0, -face.lean, 1, face.lean * base, 0);
                    const x = face.digitX[index];
                    ctx.fillStyle = face.unlit;
                    face.digit(ctx, x, ch, "off");
                    ctx.fillStyle = face.lit;
                    face.digit(ctx, x, ch, "on");
                    if (face.relief) face.faces(ctx, x, ch, index + 1);
                }
            }
        }

        // the colon: two dots, lit or not (nothing is drawn again as it blinks)
        Repeater {
            model: [[face.colonX, 0.3], [face.colonX2, 0.72]]
            Rectangle {
                required property var modelData
                readonly property real cy: face.digitTop + face.dh * modelData[1]
                // (leant as the digits are: about their baseline)
                readonly property real cx: modelData[0] - face.lean * (cy - face.digitTop - face.dh)
                x: (cx - face.dotR) * face.k
                y: (cy - face.dotR) * face.height / face.cellH
                width: 2 * face.dotR * face.k
                height: 2 * face.dotR * face.height / face.cellH
                radius: face.dotSquare ? width * 0.125 : width / 2
                color: face.colon ? face.lit : face.unlit
                antialiasing: true
            }
        }
    }
}
