import QtQuick
import qs.theme

// A panel: dark, with a hairline frame and a headed top.
Rectangle {
    id: box
    property string title: ""
    default property alias content: body.data
    readonly property alias header: head
    readonly property int headHeight: title === "" ? 0 : 40

    color: Theme.panel
    border.color: Theme.ink
    border.width: Theme.hair

    Item {
        id: head
        visible: box.title !== ""
        width: parent.width
        height: box.headHeight
        Label { x: 18; anchors.verticalCenter: parent.verticalCenter; text: box.title; font.pixelSize: 16; tracking: 1.6 }
        Rectangle { anchors.bottom: parent.bottom; x: 1; width: parent.width - 2; height: Theme.hair; color: Theme.ink; opacity: 0.85 }
    }
    Item {
        id: body
        y: box.headHeight
        width: parent.width
        height: parent.height - box.headHeight
    }
}
