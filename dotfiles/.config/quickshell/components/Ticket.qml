import QtQuick
import QtQuick.Effects
import qs.theme

// A ticket stub, as on the title bars: a card in its colour, edged in white,
// notched at the sides, a dashed tear line across its stub and a typed label.
// `lifted` (0 to 1) picks it up: it rises, turns a little and its shadow
// spreads.
Item {
    id: root

    property color fill: Theme.ticketPlain
    property color edge: Theme.ticketEdge
    property color labelColor: Theme.ticketEdge
    property string label: ""
    property real lifted: 0

    implicitWidth: 38
    implicitHeight: 25

    Item {
        id: body
        anchors.fill: parent
        transform: [
            Translate { y: -2.5 * root.lifted },
            Rotation { origin.x: root.width / 2; origin.y: root.height / 2; angle: -7 * root.lifted }
        ]

        Canvas {
            id: card
            anchors.fill: parent
            anchors.margins: -2
            property color fill: root.fill
            property color edge: root.edge
            onFillChanged: requestPaint()
            onEdgeChanged: requestPaint()
            onWidthChanged: requestPaint()

            // the outline grown by g: a rounded card with a round notch cut
            // from the middle of each short side
            function shape(ctx, g) {
                const x0 = 2 - g, y0 = 2 - g, w = root.width + 2 * g, h = root.height + 2 * g;
                const r = 1.6 + g, nr = root.height * 0.16 - g, cy = 2 + root.height / 2;
                ctx.beginPath();
                ctx.moveTo(x0 + r, y0);
                ctx.lineTo(x0 + w - r, y0);
                ctx.arc(x0 + w - r, y0 + r, r, -Math.PI / 2, 0);
                ctx.lineTo(x0 + w, cy - nr);
                ctx.arc(x0 + w, cy, nr, -Math.PI / 2, Math.PI / 2, true);
                ctx.lineTo(x0 + w, y0 + h - r);
                ctx.arc(x0 + w - r, y0 + h - r, r, 0, Math.PI / 2);
                ctx.lineTo(x0 + r, y0 + h);
                ctx.arc(x0 + r, y0 + h - r, r, Math.PI / 2, Math.PI);
                ctx.lineTo(x0, cy + nr);
                ctx.arc(x0, cy, nr, Math.PI / 2, Math.PI * 1.5, true);
                ctx.lineTo(x0, y0 + r);
                ctx.arc(x0 + r, y0 + r, r, Math.PI, Math.PI * 1.5);
                ctx.closePath();
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = edge;
                shape(ctx, 1.2);
                ctx.fill();
                ctx.fillStyle = fill;
                shape(ctx, 0);
                ctx.fill();
                // the tear line across the stub
                const plain = Qt.colorEqual(fill, Theme.ticketPlain);
                ctx.strokeStyle = plain ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(edge.r, edge.g, edge.b, 0.75);
                ctx.lineWidth = 0.8;
                const tx = Math.round(2 + root.width * 0.26) + 0.5;
                for (let j = 0; j < 4; j++) {
                    const y = 2 + 2 + j * (root.height - 4) / 3.6;
                    ctx.beginPath(); ctx.moveTo(tx, y); ctx.lineTo(tx, y + 2); ctx.stroke();
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                blurMax: 16
                shadowBlur: 0.25 + 0.3 * root.lifted
                shadowVerticalOffset: 1.6 + 2.4 * root.lifted
                shadowHorizontalOffset: 1 + 1.2 * root.lifted
                shadowOpacity: 0.7 + 0.3 * root.lifted
            }
        }

        Text {
            x: root.width * 0.62 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.labelColor
            font.family: Theme.typewriter
            font.pixelSize: 13
            font.bold: true
        }
    }
}
