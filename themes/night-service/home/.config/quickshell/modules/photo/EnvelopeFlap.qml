import QtQuick

// The envelope's flap: a triangle hinged on the envelope's top edge.
// angle 0: folded down over the pocket; 180: standing open above it (we
// then see its inside, a shade darker).
Canvas {
    id: root

    property color paper: "#e2ddd3"
    property real angle: 0
    readonly property bool open: angle > 90

    width: parent.width
    height: parent.height * 0.56
    onPaperChanged: requestPaint()
    onOpenChanged: requestPaint()

    transform: Rotation {
        origin.x: 0
        origin.y: 0
        axis { x: 1; y: 0; z: 0 }
        angle: root.angle
    }

    onPaint: {
        const g = getContext("2d");
        g.reset();
        const w = width, h = height;
        const outline = () => {
            g.beginPath();
            g.moveTo(0.5, 0.5);
            g.lineTo(w * 0.5 - 14, h - 6);
            g.quadraticCurveTo(w * 0.5, h + 1, w * 0.5 + 14, h - 6);
            g.lineTo(w - 0.5, 0.5);
        };
        g.fillStyle = paper;
        if (!open) {
            // folded down: its edges cast a little shadow on the pocket
            g.shadowColor = "rgba(0,0,0,0.28)";
            g.shadowBlur = 6;
            g.shadowOffsetY = 2;
        }
        outline();
        g.closePath();
        g.fill();
        g.shadowColor = "transparent";
        if (open) {
            // its inside, a shade darker, the gummed strip along the edge
            g.fillStyle = "rgba(0,0,0,0.12)";
            g.fill();
            g.strokeStyle = "rgba(120,100,60,0.2)";
            g.lineWidth = 7;
            g.beginPath();
            g.moveTo(14, 7); g.lineTo(w * 0.5, h - 13); g.lineTo(w - 14, 7);
            g.stroke();
        }
        g.strokeStyle = "rgba(0,0,0,0.3)";
        g.lineWidth = 1;
        outline();
        g.stroke();
    }
}
