import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The top line: the camera (takes a screenshot) and its frame counter, the
// date between two ticks, the network, the weather and the time.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barTop
    exclusiveZone: Theme.barTop
    WlrLayershell.namespace: "viewfinder-bar"
    color: Theme.bar

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.hair; color: Theme.ink }

    // ---- left: click the camera for an area, right-click for the screen
    Row {
        x: 36
        height: parent.height - 1
        spacing: 26
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "camera"
            size: 28
            color: cameraMouse.containsMouse ? Theme.accent : Theme.ink
            MouseArea {
                id: cameraMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => Shots.take(e.button === Qt.RightButton ? "screen" : "region")
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "Frame " + String(Shots.frame).padStart(2, "0") + " / 36"
            font.pixelSize: 19
            tracking: 2.2
        }
    }

    // ---- middle: [ 11 NOV WED ] between two ticks
    Rectangle { x: Math.round(parent.width * 0.375); anchors.verticalCenter: parent.verticalCenter; width: 1; height: 22; color: Theme.ink }
    Rectangle { x: Math.round(parent.width * 0.625); anchors.verticalCenter: parent.verticalCenter; width: 1; height: 22; color: Theme.ink }
    Label {
        anchors.centerIn: parent
        text: "[ " + Clock.day + " ]"
        font.pixelSize: 19
        tracking: 2.6
    }

    // ---- right
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 36
        height: parent.height - 1
        spacing: 22
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Net.wired ? "wired" : (Net.ssid !== "" ? "wifi" : "wifi-off")
            size: 24
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Weather.ready
            size: 26
            name: {
                switch (Weather.icon) {
                case "clear": return "sun";
                case "clear-night": case "partly-night": return "moon";
                case "rain": case "storm": return "rain";
                case "snow": return "snow";
                default: return "cloud";
                }
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Clock.time
            font.pixelSize: 19
            tracking: 2.2
        }
    }
}
