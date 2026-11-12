import QtQuick
import qs.theme

// A ruled line with ticks and a marker: drag, click or scroll.
Item {
    id: root
    property real value: 0                 // 0..1
    property int ticks: 9
    property bool triangle: false          // a pointer under the line (the light scale)
    signal moved(real v)

    implicitHeight: 24

    Rectangle { y: Math.round(root.height / 2); width: parent.width; height: Theme.hair; color: Theme.ink }
    Repeater {
        model: root.ticks
        Rectangle {
            required property int index
            x: Math.round(index * (root.width - 1) / (root.ticks - 1))
            y: Math.round(root.height / 2) - (index % 2 === 0 ? 5 : 3)
            width: 1
            height: index % 2 === 0 ? 10 : 6
            color: Theme.ink
        }
    }
    Rectangle {
        visible: !root.triangle
        x: Math.round(root.value * (root.width - 5))
        y: Math.round(root.height / 2) - 6
        width: 5; height: 13
        color: Theme.ink
    }
    Canvas {
        visible: root.triangle
        x: Math.round(root.value * (root.width - 1)) - 6
        y: Math.round(root.height / 2) + 2
        width: 13; height: 9
        onPaint: {
            const c = getContext("2d");
            c.reset();
            c.fillStyle = Theme.ink;
            c.beginPath(); c.moveTo(6.5, 0); c.lineTo(13, 9); c.lineTo(0, 9); c.closePath(); c.fill();
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        function at(mx) { root.moved(Math.max(0, Math.min(1, (mx - 6) / root.width))); }
        onPressed: e => at(e.x)
        onPositionChanged: e => { if (pressed) at(e.x); }
        onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
