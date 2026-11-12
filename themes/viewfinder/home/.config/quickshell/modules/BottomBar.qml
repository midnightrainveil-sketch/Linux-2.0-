import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The readout under the frame: the launcher, the machine (processor,
// memory, temperature), the light and the volume, the battery, power.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.barBottom
    exclusiveZone: Theme.barBottom
    WlrLayershell.namespace: "viewfinder-bar"
    color: Theme.bar

    Rectangle { width: parent.width; height: Theme.hair; color: Theme.ink }

    component Sep: Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 26; color: Theme.ink }
    component Reading: Row {
        id: reading
        property string icon: ""
        property string word: ""
        property string value: ""
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14
        Icon { anchors.verticalCenter: parent.verticalCenter; name: reading.icon; size: 26 }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label { text: reading.word; font.pixelSize: 14 }
            Label { text: reading.value; font.pixelSize: 14; caps: false }
        }
    }

    // ---- left: the launcher and the machine
    Row {
        x: 36
        y: 1
        height: parent.height - 1
        spacing: 30
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "aperture"
            size: 28
            color: menuMouse.containsMouse || Panels.open === "launcher" ? Theme.accent : Theme.ink
            MouseArea {
                id: menuMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("launcher")
            }
        }
        Sep {}
        Reading { icon: "cpu"; word: "CPU"; value: Vitals.cpu + "%" }
        Sep {}
        Reading { icon: "mem"; word: "Mem"; value: Vitals.memory.toFixed(1) + "G" }
        Sep {}
        Reading { icon: "temp"; word: "Temp"; value: Vitals.temperature > 0 ? Vitals.temperature + "°C" : "--" }
    }

    // ---- middle: the light, as stops either side of the middle; the volume
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 1
        height: parent.height - 1
        spacing: 34
        Sep {}
        Item {
            width: 250
            height: parent.height
            Repeater {
                model: ["-2", "-1", "0", "+1", "+2"]
                Label {
                    required property string modelData
                    required property int index
                    x: Math.round(index * (light.width - 1) / 4 - width / 2) + light.x
                    y: 4
                    text: modelData
                    font.pixelSize: 12
                    tracking: 0
                }
            }
            Slide {
                id: light
                x: 4
                y: 14
                width: parent.width - 8
                ticks: 9
                triangle: true
                value: Brightness.percent / 100
                onMoved: v => Brightness.set(Math.round(v * 100))
            }
            Label { anchors.horizontalCenter: parent.horizontalCenter; y: 38; text: "Light"; font.pixelSize: 12 }
        }
        Sep {}
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Audio.muted ? "mute" : "speaker"
            size: 28
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleMute() }
        }
        Item {
            width: 210
            height: parent.height
            Slide {
                y: 11
                width: parent.width
                ticks: 9
                value: Audio.volume
                opacity: Audio.muted ? 0.45 : 1
                onMoved: v => Audio.setVolume(v)
            }
            Label { anchors.horizontalCenter: parent.horizontalCenter; y: 38; text: "Vol"; font.pixelSize: 12 }
        }
        Sep {}
    }

    // ---- right: the battery, and the power menu
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 36
        y: 1
        height: parent.height - 1
        spacing: 22
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 28; height: 28
            visible: Power.present
            Icon { name: "battery"; size: 28 }
            Icon { visible: Power.charging; name: "bolt"; size: 14; x: 7; y: 9 }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.present
            text: Power.percent + "%"
            font.pixelSize: 16
            color: Power.low ? Theme.warn : Theme.ink
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.present
            width: 132; height: 14
            color: "transparent"
            border.color: Theme.ink
            border.width: 1
            Rectangle {
                x: 2; y: 2
                height: parent.height - 4
                width: Math.round((parent.width - 4) * Power.percent / 100)
                color: Power.low ? Theme.warn : Theme.ink
            }
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Power.present
            text: "Mains"
            font.pixelSize: 16
        }
        Sep {}
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "power"
            size: 26
            color: powerMouse.containsMouse || Panels.open === "power" ? Theme.accent : Theme.ink
            MouseArea {
                id: powerMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("power")
            }
        }
    }
}
