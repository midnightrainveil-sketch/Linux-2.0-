import QtQuick
import qs.theme

// Viewfinder marks: an L at each corner of the item.
Item {
    id: root
    property real arm: 30
    property real weight: 3
    property color color: Theme.ink
    Repeater {
        model: 4
        Item {
            required property int index
            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index >= 2
            x: atRight ? root.width - root.arm : 0
            y: atBottom ? root.height - root.arm : 0
            width: root.arm; height: root.arm
            Rectangle { x: 0; y: parent.atBottom ? root.arm - root.weight : 0; width: root.arm; height: root.weight; color: root.color }
            Rectangle { x: parent.atRight ? root.arm - root.weight : 0; y: 0; width: root.weight; height: root.arm; color: root.color }
        }
    }
}
