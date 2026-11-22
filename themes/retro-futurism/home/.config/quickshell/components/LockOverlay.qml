import QtQuick
import QtQuick.Effects
import qs.services

// The lock screen's layer, flat on the glass, see-through, over the
// platform: the departure board up in the sky (the time, your desk's
// departure and its status, what is playing; components/DepartureBoard.qml)
// and along the foot a smoked strip with the machine's state (the
// notifications waiting, Wi-Fi, the battery) and how to get in. Drawn at
// 1920 px wide and scaled with the screen (s). The strip and the shade
// step back while the pass is out (woken); the board stays, its status
// following the pass.
//
//   LockOverlay { anchors.fill: parent; s: ...; now: tick.date; status: "ON TIME"; woken: 0 }
Item {
    id: hud

    property real s: 1
    property date now: new Date()
    property string status: "ON TIME"
    property real woken: 0

    readonly property color ink: "#fff6ea"                 // a warm white
    readonly property color dim: Qt.rgba(1, 0.965, 0.92, 0.62)
    readonly property color rust: "#d9703f"
    readonly property string face: "Barlow"

    // ---- shade along the foot, so the strip reads on the picture (the
    // board has its own smoked glass)
    Rectangle {
        y: parent.height * 0.72; width: parent.width; height: parent.height * 0.28
        opacity: 1 - hud.woken
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.035, 0.02, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.035, 0.02, 0.5) }
        }
    }

    // ---- the board, up in the sky over the city
    DepartureBoard {
        // (clear of the pass, which drops in the middle)
        anchors.right: parent.right; anchors.rightMargin: 44 * hud.s
        anchors.top: parent.top; anchors.topMargin: 48 * hud.s
        s: hud.s * 0.96
        now: hud.now
        status: hud.status
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0.03, 0.02, 0.02, 0.5)
            shadowBlur: 0.8
            shadowVerticalOffset: 3 * hud.s
        }
    }

    // ---- the strip along the foot
    Rectangle {
        id: strip
        opacity: 1 - hud.woken
        visible: opacity > 0.01
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 48 * hud.s
        width: Math.min(parent.width - 96 * hud.s, row.implicitWidth + 64 * hud.s)
        height: 60 * hud.s
        radius: 10 * hud.s
        color: Qt.rgba(0.08, 0.05, 0.035, 0.42)
        border.color: Qt.rgba(1, 0.96, 0.9, 0.18); border.width: 1
        // an inner line, as a tape deck's panel has
        Rectangle {
            anchors.fill: parent; anchors.margins: 4 * hud.s
            radius: 7 * hud.s
            color: "transparent"
            border.color: Qt.rgba(1, 0.96, 0.9, 0.09); border.width: 1
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 26 * hud.s

            // the brand, as on the taskbar
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * hud.s
                Text {
                    text: "///"; color: hud.rust
                    font.family: hud.face; font.weight: Font.ExtraBold; font.italic: true; font.pixelSize: 20 * hud.s
                }
                Text {
                    text: "MAGNETIC 88"; color: hud.ink
                    font.family: hud.face; font.weight: Font.ExtraBold; font.italic: true
                    font.pixelSize: 19 * hud.s; font.letterSpacing: 3 * hud.s
                }
            }
            Sep {}

            // how to get in
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * hud.s
                // a padlock, drawn
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * hud.s; height: 22 * hud.s
                    Rectangle {
                        x: 3.5 * hud.s; width: 11 * hud.s; height: 14 * hud.s; radius: 5.5 * hud.s
                        color: "transparent"; border.color: hud.ink; border.width: 2 * hud.s
                    }
                    Rectangle { y: 9 * hud.s; width: parent.width; height: 13 * hud.s; radius: 2.5 * hud.s; color: hud.ink }
                }
                Text {
                    id: hint
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PRESS ANY KEY TO UNLOCK"; color: hud.ink
                    font.family: hud.face; font.weight: Font.DemiBold
                    font.pixelSize: 20 * hud.s; font.letterSpacing: 3.5 * hud.s
                    SequentialAnimation on opacity {
                        running: hud.visible; loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }

            component Sep: Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 26 * hud.s; color: Qt.rgba(1, 0.96, 0.9, 0.25)
            }

            // the notifications waiting
            Sep { visible: Notifs.count > 0 }
            Row {
                visible: Notifs.count > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * hud.s
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bell"; size: 18 * hud.s; color: hud.ink; weight: 2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.count; color: hud.dim
                    font.family: hud.face; font.weight: Font.DemiBold; font.pixelSize: 20 * hud.s
                }
            }

            // Wi-Fi and the battery
            Sep { visible: Net.wifiOn || Net.wired || Power.present }
            Row {
                visible: Net.wifiOn || Net.wired
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * hud.s
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 4 * hud.s; height: (6 + index * 4) * hud.s; radius: 1
                        color: Net.wired || (Net.online && Net.signal * 4 > index + 0.25) ? hud.ink : Qt.rgba(1, 0.96, 0.9, 0.28)
                    }
                }
            }
            Row {
                visible: Power.present
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * hud.s
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * hud.s; height: 15 * hud.s
                    Rectangle {
                        width: 27 * hud.s; height: parent.height; radius: 3.5 * hud.s
                        color: "transparent"; border.color: hud.ink; border.width: 1.6 * hud.s
                        Rectangle {
                            x: 3 * hud.s; y: 3 * hud.s; height: parent.height - 6 * hud.s; radius: 1.5 * hud.s
                            width: Math.max(0, (parent.width - 6 * hud.s) * Power.percent / 100)
                            color: Power.charging ? "#8fd18a" : hud.ink
                        }
                    }
                    Rectangle { x: 27.5 * hud.s; y: 4.5 * hud.s; width: 2.5 * hud.s; height: 6 * hud.s; radius: 1; color: hud.ink }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Power.percent + "%"; color: hud.dim
                    font.family: hud.face; font.weight: Font.DemiBold; font.pixelSize: 20 * hud.s
                }
            }
        }
    }
}
