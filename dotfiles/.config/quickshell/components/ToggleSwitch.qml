import QtQuick
import qs.theme

// A small brass toggle switch on a plate, as on an old control panel: the
// lever thrown up (on, a lamp lit beside it) or down (off). Flicking it
// swings the lever over with a little snap.
Item {
    id: root
    property bool on: false
    property bool hovered: false
    signal toggled()

    implicitWidth: 34
    implicitHeight: 26

    // the plate, screwed on
    Rectangle {
        id: plate
        anchors.centerIn: parent
        width: 22; height: 24
        radius: 3
        color: Qt.rgba(Theme.paperRaised.r, Theme.paperRaised.g, Theme.paperRaised.b, 1)
        border.width: 1.2
        border.color: root.hovered ? Theme.accent : Theme.soft
        Repeater {
            model: [[3.5, 3.5], [3.5, 17.5]]
            Rectangle {
                required property var modelData
                x: modelData[0]; y: modelData[1]
                width: 3; height: 3; radius: 1.5
                color: Theme.faded
            }
        }
        // the slot the lever moves in
        Rectangle {
            x: 11; y: 5
            width: 4; height: 14; radius: 2
            color: Qt.darker(Theme.paperBase, 1.35)
        }
        // the lever: pivots in the middle of the slot, its knob up or down
        Item {
            id: lever
            x: 13; y: 12
            width: 0; height: 0
            rotation: root.on ? 0 : 180
            Behavior on rotation { NumberAnimation { duration: Theme.dur(170); easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
            Rectangle { x: -1.25; y: -9; width: 2.5; height: 9; radius: 1; color: "#7a6232" }
            Rectangle { x: -3.5; y: -12; width: 7; height: 5; radius: 2.5; color: "#c9a45a"; border.width: 1; border.color: "#6e5426" }
        }
    }
    // a small lamp: lit while on
    Rectangle {
        anchors.left: plate.right
        anchors.leftMargin: 3
        anchors.verticalCenter: plate.verticalCenter
        width: 6; height: 6; radius: 3
        color: root.on ? "#d9a441" : Qt.darker(Theme.paperBase, 1.25)
        border.width: 1
        border.color: Theme.soft
        Behavior on color { ColorAnimation { duration: Theme.dur(200) } }
    }
}
