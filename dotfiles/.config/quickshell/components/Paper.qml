import QtQuick
import QtQuick.Effects
import qs.theme
import "Rand.js" as Rand

// A sheet of card stock: the card's paper with fibre texture, and the same
// torn edge as the windows' (the deckle): its shadow, the torn outline lit
// from the top left, chips and worn corners, drawn by tools/card-frames.cpp
// into frame images that stretch to any size. (The aged edge that lies over
// the card's content is PaperOver, laid on top by IndexCard.) A sheet in
// another colour keeps the older drawn edge below.
Item {
    id: root

    property color color: Theme.paperCard
    readonly property bool framed: Qt.colorEqual(color, Theme.paperCard)
    property int seed: 1
    property real jag: 1.5               // edge variation in px
    property real lift: 1.0              // 0 = flat, 1 = resting card, >1 = lifted
    property bool grain: true

    // ---- the windows' torn edge, under the card (day and night, crossfaded)
    Item {
        visible: root.framed
        anchors.fill: parent
        anchors.margins: -Theme.frameShadow
        CardFrame { anchors.fill: parent; part: "under"; mode: "day"; opacity: 1 - Theme.night; visible: Theme.night < 0.999 }
        CardFrame { anchors.fill: parent; part: "under"; mode: "night"; opacity: Theme.night; visible: Theme.night > 0.001 }
    }

    // ---- the card itself, drawn (a sheet in another colour)
    Canvas {
        id: sheet
        visible: !root.framed
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        property color fill: root.color
        property color rimTop: Theme.rimTop
        property color rimBottom: Theme.rimBottom
        onFillChanged: requestPaint()
        onRimTopChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function outline(r, inset) {
            const w = width, h = height, j = root.jag, step = 7;
            const pts = [];
            const edge = (x0, y0, x1, y1, nx, ny) => {
                const len = Math.hypot(x1 - x0, y1 - y0);
                const n = Math.max(1, Math.round(len / step));
                let off = r() * j;
                for (let i = 0; i < n; i++) {
                    const t = i / n;
                    // a gently wandering cut, with the odd nick in it
                    off = Math.max(0, Math.min(j * 1.6, off * 0.7 + r() * j * 0.6 + (r() < 0.04 ? j * 1.2 : 0)));
                    pts.push([x0 + (x1 - x0) * t + nx * (off + inset), y0 + (y1 - y0) * t + ny * (off + inset)]);
                }
            };
            edge(0.5, 0.5, w - 0.5, 0.5, 0, 1);
            edge(w - 0.5, 0.5, w - 0.5, h - 0.5, -1, 0);
            edge(w - 0.5, h - 0.5, 0.5, h - 0.5, 0, -1);
            edge(0.5, h - 0.5, 0.5, 0.5, 1, 0);
            return pts;
        }

        function path(ctx, pts) {
            ctx.beginPath();
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
            ctx.closePath();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const pts = outline(Rand.make(root.seed), 0);

            // paper
            path(ctx, pts);
            ctx.fillStyle = fill;
            ctx.fill();

            // the cut edge: a thin rim, light at the top, dark at the bottom,
            // drawn piece by piece so its weight wanders like a torn fibre edge
            const r2 = Rand.make(root.seed * 3 + 7);
            ctx.lineCap = "round";
            for (let i = 0; i < pts.length; i++) {
                const a = pts[i], b = pts[(i + 1) % pts.length];
                const t = Math.max(0, Math.min(1, (a[1] / height - 0.82) / 0.18));
                ctx.strokeStyle = Qt.rgba(rimTop.r + (rimBottom.r - rimTop.r) * t,
                                          rimTop.g + (rimBottom.g - rimTop.g) * t,
                                          rimTop.b + (rimBottom.b - rimTop.b) * t, 1);
                ctx.globalAlpha = 0.45 + r2() * 0.55;
                ctx.lineWidth = 0.9 + r2() * 0.9;
                ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
            }
            ctx.globalAlpha = 1;
            // the bottom edge is the card's thickness: a second, darker pass
            ctx.lineWidth = 2.0;
            ctx.strokeStyle = rimBottom;
            ctx.globalAlpha = 0.85;
            ctx.beginPath();
            const bottom = pts.filter(p => p[1] > height - 3);
            if (bottom.length > 1) {
                ctx.moveTo(bottom[0][0], bottom[0][1] - 0.6);
                for (let i = 1; i < bottom.length; i++) ctx.lineTo(bottom[i][0], bottom[i][1] - 0.6);
                ctx.stroke();
            }
            ctx.globalAlpha = 1;

            // a faint light line just inside the cut
            ctx.globalAlpha = 0.45;
            ctx.strokeStyle = Qt.lighter(fill, 1.06);
            ctx.lineWidth = 1;
            path(ctx, outline(Rand.make(root.seed), 1.8));
            ctx.stroke();
            ctx.globalAlpha = 1;
        }

        // a short soft shadow, falling down onto the sheet
        layer.enabled: root.lift > 0 && !root.framed
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            blurMax: 32
            shadowBlur: 0.24 + 0.08 * root.lift
            shadowVerticalOffset: 1.5 + 2 * root.lift
            shadowHorizontalOffset: -0.5
            shadowOpacity: Math.min(1, 0.9 + 0.3 * (root.lift - 1))
        }
    }

    // fibre texture, kept inside the cut edge
    Item {
        anchors.fill: parent
        anchors.margins: root.framed ? 5 : root.jag + 1.5
        visible: root.grain
        clip: true
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../assets/paper-card.png")
            fillMode: Image.Tile
            opacity: Theme.cardTexture
            smooth: false
            asynchronous: true
        }
    }
}
