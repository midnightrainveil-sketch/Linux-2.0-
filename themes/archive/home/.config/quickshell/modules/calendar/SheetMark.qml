import QtQuick
import qs.theme
import qs.components

// "Year ⌜⌟" / "Month ⌟⌜": a typed word and four pencilled corner marks, the
// way a sheet is marked up for enlargement (corners out) or reduction
// (corners in). Click to change the ledger's size.
Item {
    id: root

    property string word: "Year"
    property bool enlarge: true
    signal clicked()

    readonly property color ink: hover.containsMouse ? Theme.graphite : Theme.faded
    implicitWidth: label.implicitWidth + 7 + 14
    implicitHeight: 18

    InkText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text: root.word
        font.pixelSize: Theme.sizeSmall - 1
        color: root.ink
    }
    Canvas {
        id: corners
        width: 14; height: 14
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        property color ink: root.ink
        onInkChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.strokeStyle = ink;
            g.lineWidth = 1.3;
            g.lineCap = "round";
            g.lineJoin = "round";
            const a = 1.2, b = 12.8, l = 4.4;
            // each corner: a tick along both edges, pointing out (enlarge) or in
            const c = [[a, a, 1, 1], [b, a, -1, 1], [a, b, 1, -1], [b, b, -1, -1]];
            for (const [x, y, sx, sy] of c) {
                g.beginPath();
                if (root.enlarge) {
                    g.moveTo(x + sx * l, y); g.lineTo(x, y); g.lineTo(x, y + sy * l);
                } else {
                    const ix = x + sx * l, iy = y + sy * l;
                    g.moveTo(x + sx * l, y); g.lineTo(ix, iy); g.lineTo(x, y + sy * l);
                }
                g.stroke();
            }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
