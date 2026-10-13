import QtQuick
import qs.theme
import "Rand.js" as Rand

// A hand-ruled line: 1.5 px with a tiny wobble (±0.5 px drift).
// Horizontal by default; set `vertical: true` for column rules.
Canvas {
    id: root

    property bool vertical: false
    property color color: Theme.ruleInk
    property real weight: Theme.rule
    property real drift: 0.5
    property int seed: 7

    implicitWidth: vertical ? weight + 2 * drift + 1 : 100
    implicitHeight: vertical ? 100 : weight + 2 * drift + 1
    renderStrategy: Canvas.Cooperative

    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = Rand.make(seed);
        const pts = vertical
            ? Rand.wobble(r, width / 2, 0, width / 2, height, drift, 14)
            : Rand.wobble(r, 0, height / 2, width, height / 2, drift, 14);
        ctx.strokeStyle = color;
        ctx.lineWidth = weight;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        ctx.moveTo(pts[0][0], pts[0][1]);
        for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
        ctx.stroke();
    }
}
