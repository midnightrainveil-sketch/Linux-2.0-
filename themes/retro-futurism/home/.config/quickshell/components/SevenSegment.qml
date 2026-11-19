import QtQuick

// Amber seven-segment digits, as on the Botsync DC-80: "HH:MM", leaning a
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

    // the window's own layout, in picture pixels
    readonly property real cellW: 154
    readonly property real cellH: 77
    readonly property var digitX: [13, 42, 85, 114]     // each digit's lower-left corner
    readonly property real top: 16.5
    readonly property real dw: 24                       // digit width, height, stroke
    readonly property real dh: 45
    readonly property real t: 4.8
    readonly property real lean: 0.2                   // forward lean, as in the picture

    onTextChanged: requestPaint()
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
        const w = dw, h = dh, s = t, half = s / 2, gap = 0.9;
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
        const r = 2.6;
        ctx.beginPath();
        for (const [cx, cy] of [[78.5, top + dh * 0.3], [76.0, top + dh * 0.72]]) {
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
        for (const blur of [9, 3]) {          // a wide glow, then a close one
            ctx.shadowBlur = blur * width / cellW;
            for (let i = 0; i < 4; i++) digit(ctx, digitX[i], chars[i], "on");
            if (colon) colonDots(ctx);
        }
    }
}
