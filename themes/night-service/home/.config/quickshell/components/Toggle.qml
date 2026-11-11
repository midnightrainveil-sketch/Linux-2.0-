import QtQuick
import qs.theme

// Toggle as a typed form (section 8): "ON  OFF" side by side. The hovered
// word gets a pencil underline; the chosen word is circled in accent.ink.
// Works for any set of words: set `options` and `current`.
Row {
    id: root

    property var options: ["ON", "OFF"]
    property int current: checked ? 0 : 1
    property bool checked: false
    property bool available: true
    signal picked(int index)
    signal toggled(bool on)

    spacing: 14

    Repeater {
        model: root.options

        Item {
            id: option
            required property int index
            required property string modelData
            readonly property bool chosen: root.current === index

            width: word.implicitWidth + 12
            height: Theme.rowHeight - 6

            InkText {
                id: word
                anchors.centerIn: parent
                text: option.modelData
                font.pixelSize: Theme.sizeData
                color: !root.available ? Theme.faded : option.chosen ? Theme.accent : Theme.soft
                Behavior on color { ColorAnimation { duration: Theme.durFocus } }
            }

            // pencil underline on hover
            Rule {
                visible: hover.containsMouse && !option.chosen && root.available
                anchors.left: word.left
                anchors.right: word.right
                anchors.top: word.bottom
                anchors.topMargin: -1
                height: implicitHeight
                weight: 1
                color: Theme.faded
                seed: option.index + 40
            }

            PencilRing {
                anchors.fill: parent
                anchors.margins: -2
                visible: option.chosen && root.available
                seed: option.index + 9
                progress: option.chosen ? 1 : 0
                Behavior on progress { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.Bezier; easing.bezierCurve: Theme.place } }
            }

            // disabled: a single pencil strike-through
            Rule {
                visible: !root.available
                anchors.verticalCenter: word.verticalCenter
                anchors.left: word.left
                anchors.right: word.right
                height: implicitHeight
                weight: 1
                color: Theme.faded
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.available
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.picked(option.index);
                    if (root.options.length === 2) root.toggled(option.index === 0);
                }
            }
        }
    }
}
