import QtQuick

// Amber seven-segment digits, as on the Suisei DC-80: "HH:MM", leaning a
// little forward, the unlit segments faintly there behind the lit ones.
// Drawn in its own units (a cell of 154 x 77, the clock's window in the
// lock picture); the item may be any size.
Canvas {
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
    property real top: 16.5
    property real dw: 24                                // digit width, height, stroke
    property real dh: 45
    property real t: 4.8
    property real gap: 0.9                              // between one segment and the next
    property real lean: 0.2                             // forward lean, as in the picture
    property real colonX: 78.5                          // the colon's upper and lower dot
    property real colonX2: 76
    property real dotR: 2.6
    property real glowWide: 9                           // the glow, in these units
    property real glowNear: 3

    onTextChanged: requestPaint()
    onLitChanged: requestPaint()
    onColonChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // segments a..g of each digit
    readonly property var segs: ({
        "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
        "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
        " ": "", "-": "g"
    })

    function segment(ctx, x, y, name) {
        // a long hexagon, horizontal (a, g, d) or upright (b, c, e, f)
        const w = dw, h = dh, s = t, half = s / 2, gap = face.gap;
        const mid = h / 2;
        function hor(x0, yc, len) {
            ctx.moveTo(x0 + gap, yc);
            ctx.lineTo(x0 + gap + half, yc - half);
            ctx.lineTo(x0 + len - gap - half, yc - half);
            ctx.lineTo(x0 + len - gap, yc);
            ctx.lineTo(x0 + len - gap - half, yc + half);
            ctx.lineTo(x0 + gap + half, yc + half);
            ctx.closePath();
        }
        function ver(xc, y0, len) {
            ctx.moveTo(xc, y0 + gap);
            ctx.lineTo(xc + half, y0 + gap + half);
            ctx.lineTo(xc + half, y0 + len - gap - half);
            ctx.lineTo(xc, y0 + len - gap);
            ctx.lineTo(xc - half, y0 + len - gap - half);
            ctx.lineTo(xc - half, y0 + gap + half);
            ctx.closePath();
        }
        switch (name) {
        case "a": hor(x, y + half, w); break;
        case "g": hor(x, y + mid, w); break;
        case "d": hor(x, y + h - half, w); break;
        case "f": ver(x + half, y + half, mid - half); break;
        case "b": ver(x + w - half, y + half, mid - half); break;
        case "e": ver(x + half, y + mid, mid - half); break;
        case "c": ver(x + w - half, y + mid, mid - half); break;
        }
    }

    function digit(ctx, x, ch, which) {
        const on = segs[ch] ?? "";
        ctx.beginPath();
        for (const n of "abcdefg")
            if ((which === "on") === (on.indexOf(n) >= 0)) segment(ctx, x, top, n);
        ctx.fill();
    }

    function colonDots(ctx) {
        const r = dotR;
        ctx.beginPath();
        for (const [cx, cy] of [[colonX, top + dh * 0.3], [colonX2, top + dh * 0.72]]) {
            ctx.moveTo(cx + r, cy);
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
        }
        ctx.fill();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ctx.scale(width / cellW, height / cellH);
        // lean forward about the digits' baseline
        const base = top + dh;
        ctx.transform(1, 0, -lean, 1, lean * base, 0);

        const chars = (text.replace(":", "") + "    ").slice(0, 4);

        ctx.fillStyle = unlit;
        for (let i = 0; i < 4; i++) digit(ctx, digitX[i], chars[i], "off");
        if (!colon) colonDots(ctx);

        ctx.fillStyle = lit;
        ctx.shadowColor = glow;
        for (const blur of [glowWide, glowNear]) {          // a wide glow, then a close one
            ctx.shadowBlur = blur * width / cellW;
            for (let i = 0; i < 4; i++) digit(ctx, digitX[i], chars[i], "on");
            if (colon) colonDots(ctx);
        }
    }
}
