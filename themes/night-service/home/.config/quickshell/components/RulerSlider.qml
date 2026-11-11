import QtQuick
import qs.theme

// Slider as a ruler (section 8): 1 px rule.faint line, ticks every 10 %,
// numbered at 0 / 50 / 100. The filled part is a 3 px accent.ink line and
// the knob is a small graphite triangle marker above the ruler.
Item {
    id: root

    property real value: 0.5            // 0..1
    property bool numbered: true
    property bool interactive: true
    property bool eased: true           // eases to a new value; off when the value moves by itself
    signal moved(real value)

    implicitWidth: 240
    implicitHeight: numbered ? 34 : 22

    readonly property bool hovered: mouse.containsMouse
    readonly property real trackY: 12
    readonly property color tickColor: hovered ? Theme.ruleInk : Theme.ruleFaint

    // the ruler line
    Rectangle {
        x: 0; y: root.trackY
        width: root.width; height: 1
        color: root.tickColor
        Behavior on color { ColorAnimation { duration: Theme.durFocus } }
    }

    // ticks every 10 %
    Repeater {
        model: 11
        Rectangle {
            required property int index
            readonly property bool major: index % 5 === 0
            x: Math.round(index / 10 * (root.width - 1))
            y: root.trackY
            width: 1
            height: major ? 7 : 4
            color: root.tickColor
            Behavior on color { ColorAnimation { duration: Theme.durFocus } }
        }
    }

    // 0 / 50 / 100
    Repeater {
        model: root.numbered ? [0, 50, 100] : []
        InkText {
            required property int modelData
            bleed: false
            text: String(modelData)
            color: Theme.faded
            font.pixelSize: 9
            y: root.trackY + 9
            x: Math.min(root.width - width, Math.max(0, modelData / 100 * root.width - width / 2))
        }
    }

    // filled part
    Rectangle {
        x: 0
        y: root.trackY - 1
        width: Math.max(0, root.value * root.width)
        height: 3
        color: Theme.accent
        Behavior on width { enabled: root.eased && !mouse.pressed; NumberAnimation { duration: Theme.durFocus; easing.type: Easing.Bezier; easing.bezierCurve: Theme.place } }
    }

    // knob: graphite triangle marker above the ruler
    Canvas {
        id: knob
        width: 11; height: 8
        x: root.value * root.width - width / 2
        y: root.trackY - height - 2
        property color c: Theme.graphite
        onCChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = c;
            ctx.beginPath();
            ctx.moveTo(0.5, 0.5); ctx.lineTo(width - 0.5, 0.8); ctx.lineTo(width / 2, height - 0.3);
            ctx.closePath();
            ctx.fill();
        }
        Behavior on x { enabled: root.eased && !mouse.pressed; NumberAnimation { duration: Theme.durFocus; easing.type: Easing.Bezier; easing.bezierCurve: Theme.place } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -4
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function apply(x) {
            const v = Math.max(0, Math.min(1, x / root.width));
            root.value = v;
            root.moved(v);
        }
        onPressed: e => apply(e.x)
        onPositionChanged: e => { if (pressed) apply(e.x); }
        onWheel: e => {
            const v = Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)));
            root.value = v;
            root.moved(v);
        }
    }
}
