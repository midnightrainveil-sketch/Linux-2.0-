import QtQuick
import QtQuick.Effects
import qs.theme
import "Rand.js" as Rand

// A sheet of card stock: slightly irregular cut edge, paper grain and a
// short soft shadow (paper lying on paper). Base of every Index card.
Item {
    id: root

    property color color: Theme.paperCard
    property int seed: 1
    property real jag: 1.4               // edge variation in px (spec: 1-2 px)
    property real lift: 1.0              // 0 = flat, 1 = resting card, >1 = lifted
    property bool grain: true

    Canvas {
        id: sheet
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        property color fill: root.color
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const r = Rand.make(root.seed);
            const w = width, h = height, j = root.jag, step = 9;
            const edge = (x0, y0, x1, y1, inward) => {
                const len = Math.hypot(x1 - x0, y1 - y0);
                const n = Math.max(1, Math.round(len / step));
                for (let i = 1; i <= n; i++) {
                    const t = i / n;
                    const d = r() * j;
                    ctx.lineTo(x0 + (x1 - x0) * t + inward[0] * d, y0 + (y1 - y0) * t + inward[1] * d);
                }
            };
            ctx.beginPath();
            ctx.moveTo(r() * j, r() * j);
            edge(0, 0, w, 0, [0, 1]);
            edge(w, 0, w, h, [-1, 0]);
            edge(w, h, 0, h, [0, -1]);
            edge(0, h, 0, 0, [1, 0]);
            ctx.closePath();
            ctx.fillStyle = fill;
            ctx.fill();
        }

        layer.enabled: root.lift > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            blurMax: 32
            shadowBlur: 0.30 + 0.10 * root.lift
            shadowVerticalOffset: 2 * root.lift
            shadowHorizontalOffset: 0
            shadowOpacity: Math.min(1, 0.55 + 0.45 * root.lift)
        }
    }

    Grain {
        anchors.fill: parent
        anchors.margins: root.jag + 0.5
        visible: root.grain
    }
}
