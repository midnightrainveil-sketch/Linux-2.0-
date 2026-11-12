import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The film strip down the left edge: one frame for each workspace. The
// one in view has the white frame; a workspace with windows on it is
// exposed, an empty one is still dark. Click a frame, or scroll.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    anchors { left: true }
    implicitWidth: Theme.edge + Theme.stripWidth
    implicitHeight: 800
    exclusiveZone: Theme.edge + Theme.stripWidth
    WlrLayershell.namespace: "viewfinder-strip"
    color: "transparent"

    readonly property int holes: 22                     // each side's column of sprocket holes

    Rectangle {
        id: film
        x: Theme.edge
        width: Theme.stripWidth
        height: parent.height
        color: Theme.panel
        border.color: Theme.ink
        border.width: 1

        Rectangle { x: win.holes; width: 1; height: parent.height; color: Theme.ink; opacity: 0.9 }
        Rectangle { x: parent.width - win.holes - 1; width: 1; height: parent.height; color: Theme.ink; opacity: 0.9 }
        Repeater {
            model: 2 * Math.floor((film.height - 10) / 24)
            Rectangle {
                required property int index
                readonly property int row: Math.floor(index / 2)
                x: index % 2 === 0 ? 6 : film.width - 6 - width
                y: 9 + row * 24
                width: 10; height: 13
                radius: 2
                color: "transparent"
                border.color: Theme.ink
                border.width: 1.2
            }
        }

        Column {
            x: win.holes + 1
            width: film.width - 2 * win.holes - 2
            height: film.height
            Repeater {
                model: Hypr.ids
                Item {
                    id: frame
                    required property int modelData
                    required property int index
                    readonly property bool active: Hypr.activeId === modelData
                    readonly property bool occupied: Hypr.state[modelData]?.occupied ?? false
                    readonly property bool urgent: Hypr.state[modelData]?.urgent ?? false
                    width: parent.width
                    height: film.height / Hypr.ids.length

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        source: Settings.art + "/frame-" + ((frame.modelData - 1) % 5 + 1) + ".jpg"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: frame.active ? 1 : frame.occupied ? 0.85 : 0.28
                        Behavior on opacity { NumberAnimation { duration: Theme.fade } }
                    }
                    Rectangle { visible: frame.index > 0; width: parent.width; height: 1; color: Theme.ink; opacity: 0.9 }
                    Label {
                        x: 10; y: 8
                        text: String(frame.modelData).padStart(2, "0")
                        font.pixelSize: 16
                        tracking: 1.5
                        style: Text.Outline
                        styleColor: "#000000"
                        color: frame.urgent ? Theme.accent : Theme.ink
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: frame.active
                        color: "transparent"
                        border.color: Theme.ink
                        border.width: 2.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hypr.workspace(frame.modelData)
                    }
                }
            }
        }
        WheelHandler { onWheel: e => Hypr.relativeWorkspace(e.angleDelta.y > 0 ? -1 : 1) }
    }
}
